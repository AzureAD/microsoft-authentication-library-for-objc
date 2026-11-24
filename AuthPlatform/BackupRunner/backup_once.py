#!/usr/bin/env python3
"""One-shot encrypted PostgreSQL export to a private Dropbox folder.

Required runtime secrets:
  DATABASE_URL
  DROPBOX_ACCESS_TOKEN (scoped to files.content.write + files.metadata.read)
  BACKUP_ENCRYPTION_PASSPHRASE (strong, unique; store separately from backup)

The script never prints connection strings, tokens, or passphrases.
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DROPBOX_DEST = os.environ.get("DROPBOX_DEST", "/AuthPlatform Backups").rstrip("/")
CHUNK = 8 * 1024 * 1024

def required(name):
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value

def api_request(url, token, body=None, headers=None, data=None):
    h = {"Authorization": f"Bearer {token}"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=data if data is not None else body, headers=h,
                                 method="POST")
    try:
        with urllib.request.urlopen(req, timeout=180) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        # Do not include response body: provider errors may contain sensitive metadata.
        raise RuntimeError(f"Dropbox API request failed (HTTP {exc.code})") from None

def dropbox_upload(path, token, local_file):
    size = local_file.stat().st_size
    with local_file.open("rb") as stream:
        first = stream.read(CHUNK)
        if size <= CHUNK:
            result = api_request(
                "https://content.dropboxapi.com/2/files/upload", token, data=first,
                headers={
                    "Content-Type": "application/octet-stream",
                    "Dropbox-API-Arg": json.dumps({"path": path, "mode": "add",
                        "autorename": False, "mute": True, "strict_conflict": True})
                })
            return json.loads(result.decode("utf-8"))

        session = json.loads(api_request(
            "https://content.dropboxapi.com/2/files/upload_session/start", token,
            data=first, headers={"Content-Type": "application/octet-stream",
                                 "Dropbox-API-Arg": json.dumps({"close": False})}
        ).decode("utf-8"))
        session_id = session["session_id"]
        offset = len(first)
        while offset < size:
            chunk = stream.read(CHUNK)
            if not chunk:
                raise RuntimeError("Unexpected end of encrypted archive during upload")
            if offset + len(chunk) < size:
                api_request("https://content.dropboxapi.com/2/files/upload_session/append_v2",
                    token, data=chunk, headers={"Content-Type":"application/octet-stream",
                    "Dropbox-API-Arg": json.dumps({"cursor":{"session_id":session_id,
                        "offset":offset},"close":False})})
                offset += len(chunk)
            else:
                result = api_request(
                    "https://content.dropboxapi.com/2/files/upload_session/finish", token,
                    data=chunk, headers={"Content-Type":"application/octet-stream",
                    "Dropbox-API-Arg": json.dumps({"cursor":{"session_id":session_id,
                        "offset":offset},"commit":{"path":path,"mode":"add",
                        "autorename":False,"mute":True,"strict_conflict":True}})})
                return json.loads(result.decode("utf-8"))
    raise RuntimeError("Dropbox upload did not complete")

def main():
    database_url = required("DATABASE_URL")
    token = required("DROPBOX_ACCESS_TOKEN")
    passphrase = required("BACKUP_ENCRYPTION_PASSPHRASE")
    if len(passphrase) < 24:
        raise RuntimeError("BACKUP_ENCRYPTION_PASSPHRASE must be at least 24 characters")
    if not DROPBOX_DEST.startswith("/"):
        raise RuntimeError("DROPBOX_DEST must be an absolute Dropbox path")

    final_name = os.environ.get("BACKUP_FILENAME", "authplatform-production-one-time.dump.gpg")
    if "/" in final_name or "\\" in final_name or not final_name.endswith(".dump.gpg"):
        raise RuntimeError("BACKUP_FILENAME must be a simple .dump.gpg filename")
    remote_path = f"{DROPBOX_DEST}/{final_name}"

    with tempfile.TemporaryDirectory(prefix="authplatform-backup-") as tmp:
        plain = Path(tmp) / "production.dump"
        encrypted = Path(tmp) / final_name

        # Parse DATABASE_URL into libpq environment variables so the secret URI
        # itself is not exposed in the pg_dump process argument list.
        parsed = urllib.parse.urlparse(database_url)
        if parsed.scheme not in ("postgres", "postgresql") or not parsed.hostname:
            raise RuntimeError("DATABASE_URL must be a valid PostgreSQL URL")
        query = urllib.parse.parse_qs(parsed.query)
        pg_env = os.environ.copy()
        pg_env.update({
            "PGHOST": parsed.hostname,
            "PGPORT": str(parsed.port or 5432),
            "PGDATABASE": urllib.parse.unquote(parsed.path.lstrip("/")),
            "PGUSER": urllib.parse.unquote(parsed.username or ""),
            "PGPASSWORD": urllib.parse.unquote(parsed.password or ""),
        })
        if query.get("sslmode"):
            pg_env["PGSSLMODE"] = query["sslmode"][0]
        subprocess.run(["pg_dump", "--format=custom", "--no-owner", "--no-acl",
                        "--file", str(plain)],
                       env=pg_env, check=True, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE)

        if not plain.is_file() or plain.stat().st_size == 0:
            raise RuntimeError("pg_dump produced an empty archive")

        listing = subprocess.run(["pg_restore", "--list", str(plain)],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
        if not listing.strip():
            raise RuntimeError("pg_restore found no archive entries")

        # Symmetric OpenPGP encryption; passphrase is sent over stdin, not argv.
        subprocess.run(["gpg", "--batch", "--yes", "--pinentry-mode", "loopback",
                        "--passphrase-fd", "0", "--symmetric", "--cipher-algo", "AES256",
                        "--output", str(encrypted), str(plain)],
                       input=(passphrase + "\n").encode("utf-8"),
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)

        if not encrypted.is_file() or encrypted.stat().st_size == 0:
            raise RuntimeError("Encryption did not produce an archive")
        hasher = hashlib.sha256()
        with encrypted.open("rb") as encrypted_stream:
            for block in iter(lambda: encrypted_stream.read(1024 * 1024), b""):
                hasher.update(block)
        digest = hasher.hexdigest()
        metadata = dropbox_upload(remote_path, token, encrypted)

        if metadata.get("path_lower", "").lower() != remote_path.lower():
            raise RuntimeError("Dropbox returned an unexpected destination path")
        print(json.dumps({
            "status": "uploaded_encrypted_archive",
            "destination": metadata.get("path_display", remote_path),
            "encrypted_bytes": encrypted.stat().st_size,
            "sha256": digest,
            "dropbox_content_hash": metadata.get("content_hash"),
            "plaintext_removed": True,
            "archive_structure_checked": True,
            "restore_test": "not_performed"
        }, sort_keys=True))

if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        # Do not print subprocess stderr; it can contain connection details.
        print(f"Backup failed in subprocess (exit {exc.returncode}); sensitive output suppressed.",
              file=sys.stderr)
        sys.exit(1)
    except Exception as exc:
        # Runtime errors are intentionally generic and avoid dumping secrets.
        print(f"Backup failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(1)
