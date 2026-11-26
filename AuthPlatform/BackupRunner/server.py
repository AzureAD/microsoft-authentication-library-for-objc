#!/usr/bin/env python3
"""Authenticated, single-execution HTTP trigger for the backup container."""
import hmac
import json
import os
import subprocess
import threading
import urllib.parse
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = os.environ.get("BACKUP_TRIGGER_TOKEN", "")
state = {"status": "idle", "result": None}
lock = threading.Lock()

EXPECTED_TABLES = (
    "users",
    "passkey_credentials",
    "auth_sessions",
    "oauth_accounts",
    "audit_events",
    "refresh_token_records",
    "one_time_auth_tokens",
    "auth_rate_limits",
    "passkey_challenges",
    "oidc_login_transactions",
    "encrypted_vault_items",
)

def run_backup():
    try:
        completed = subprocess.run(
            ["python3", "/backup/backup_once.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=int(os.environ.get("BACKUP_TIMEOUT_SECONDS", "3600")),
            check=False,
        )
        try:
            result = json.loads(completed.stdout.strip().splitlines()[-1])
        except Exception:
            result = {"status": "failed", "error": "No safe diagnostic record from backup process"}
        with lock:
            if completed.returncode == 0 and result.get("status") == "uploaded_encrypted_archive":
                state["status"] = "succeeded"
                state["result"] = result
            else:
                state["status"] = "failed"
                state["result"] = result if result.get("status") == "failed" else {
                    "status": "failed", "error": "Backup process failed; safe diagnostic unavailable"
                }
    except Exception as exc:
        with lock:
            state["status"] = "failed"
            state["result"] = {"status": "failed", "error_type": type(exc).__name__}

def source_table_counts():
    """Return exact aggregate counts for a fixed allowlist; never return row data."""
    database_url = os.environ.get("DATABASE_URL", "")
    parsed = urllib.parse.urlparse(database_url)
    if parsed.scheme not in ("postgres", "postgresql") or not parsed.hostname:
        raise ValueError("database_configuration_invalid")

    pg_env = os.environ.copy()
    pg_env.update({
        "PGHOST": parsed.hostname,
        "PGPORT": str(parsed.port or 5432),
        "PGDATABASE": urllib.parse.unquote(parsed.path.lstrip("/")),
        "PGUSER": urllib.parse.unquote(parsed.username or ""),
        "PGPASSWORD": urllib.parse.unquote(parsed.password or ""),
        "PGCONNECT_TIMEOUT": "10",
        "PGOPTIONS": "-c default_transaction_read_only=on -c statement_timeout=15000",
    })
    query_params = urllib.parse.parse_qs(parsed.query)
    if query_params.get("sslmode"):
        pg_env["PGSSLMODE"] = query_params["sslmode"][0]

    values = ", ".join("('%s')" % name for name in EXPECTED_TABLES)
    sql = f"""
        WITH expected(table_name) AS (VALUES {values})
        SELECT COALESCE(
            json_agg(
                json_build_object(
                    'table', e.table_name,
                    'exists', to_regclass(format('%I.%I', 'public', e.table_name)) IS NOT NULL,
                    'row_count',
                    CASE
                        WHEN to_regclass(format('%I.%I', 'public', e.table_name)) IS NULL
                        THEN NULL
                        ELSE (
                            xpath(
                                '/row/c/text()',
                                query_to_xml(
                                    format('SELECT count(*) AS c FROM %I.%I', 'public', e.table_name),
                                    false, true, ''
                                )
                            )
                        )[1]::text::bigint
                    END
                ) ORDER BY e.table_name
            ),
            '[]'::json
        )
        FROM expected AS e
    """
    completed = subprocess.run(
        ["psql", "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--tuples-only",
         "--no-align", "--command", sql],
        env=pg_env,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=25,
        check=True,
    )
    result = json.loads(completed.stdout.strip())
    if not isinstance(result, list) or len(result) != len(EXPECTED_TABLES):
        raise ValueError("unexpected_count_result")
    return {
        "status": "ok",
        "source": "production_database",
        "read_only": True,
        "count_type": "exact",
        "tables": result,
    }

def verify_postgres_connection():
    """Run a minimal read-only connectivity probe; do not inspect application data."""
    database_url = os.environ.get("DATABASE_URL", "")
    parsed = urllib.parse.urlparse(database_url)
    if parsed.scheme not in ("postgres", "postgresql") or not parsed.hostname:
        raise ValueError("database_configuration_invalid")
    pg_env = os.environ.copy()
    pg_env.update({
        "PGHOST": parsed.hostname,
        "PGPORT": str(parsed.port or 5432),
        "PGDATABASE": urllib.parse.unquote(parsed.path.lstrip("/")),
        "PGUSER": urllib.parse.unquote(parsed.username or ""),
        "PGPASSWORD": urllib.parse.unquote(parsed.password or ""),
        "PGCONNECT_TIMEOUT": "10",
        "PGOPTIONS": "-c default_transaction_read_only=on -c statement_timeout=5000",
    })
    params = urllib.parse.parse_qs(parsed.query)
    if params.get("sslmode"):
        pg_env["PGSSLMODE"] = params["sslmode"][0]
    completed = subprocess.run(
        ["psql", "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--tuples-only",
         "--no-align", "--command", "SELECT 1"],
        env=pg_env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        text=True, timeout=15, check=True,
    )
    if completed.stdout.strip() != "1":
        raise ValueError("database_probe_unexpected_result")
    return True

def verify_dropbox_access():
    """Verify read-only folder metadata access; never upload, create, or modify files."""
    token = os.environ.get("DROPBOX_ACCESS_TOKEN", "")
    if not token:
        raise ValueError("dropbox_token_missing")
    destination = os.environ.get("DROPBOX_DEST", "/AuthPlatform Backups").rstrip("/")
    if not destination.startswith("/"):
        raise ValueError("dropbox_destination_invalid")
    payload = json.dumps({
        "path": destination,
        "recursive": False,
        "limit": 1,
    }).encode("utf-8")
    request = urllib.request.Request(
        "https://api.dropboxapi.com/2/files/list_folder",
        data=payload,
        headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError:
        raise ValueError("dropbox_folder_metadata_check_failed") from None
    if not isinstance(result, dict) or not isinstance(result.get("entries"), list):
        raise ValueError("dropbox_folder_metadata_unexpected_response")
    return True

def verify_integrations():
    verify_postgres_connection()
    verify_dropbox_access()
    return {
        "status": "ok",
        "postgresql": "connected",
        "dropbox": "authenticated_folder_read",
        "read_only": True,
        "backup_started": False,
    }

class Handler(BaseHTTPRequestHandler):
    def send_json(self, code, payload):
        body = json.dumps(payload, sort_keys=True).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def authorized(self):
        if len(TOKEN) < 32:
            self.send_json(503, {"error": "backup_trigger_not_configured"})
            return False
        supplied = self.headers.get("Authorization", "")
        expected = "Bearer " + TOKEN
        if not hmac.compare_digest(supplied.encode("utf-8"), expected.encode("utf-8")):
            self.send_json(401, {"error": "unauthorized"})
            return False
        return True

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"service": "authplatform-backup-runner", "status": "ready"})
        elif self.path == "/status":
            # Keep the public status endpoint metadata-free.
            with lock:
                self.send_json(200, {"status": state["status"]})
        elif self.path == "/verify":
            if not self.authorized():
                return
            try:
                self.send_json(200, verify_integrations())
            except Exception:
                # Never expose database, Dropbox, or credential diagnostics.
                self.send_json(502, {"error": "integration_verification_failed",
                                     "read_only": True, "backup_started": False})
        elif self.path == "/source-counts":
            if not self.authorized():
                return
            try:
                self.send_json(200, source_table_counts())
            except Exception:
                # Suppress database/driver diagnostics; they can contain connection details.
                self.send_json(502, {"error": "source_count_query_failed"})
        else:
            self.send_json(404, {"error": "not_found"})

    def do_POST(self):
        if self.path != "/run":
            self.send_json(404, {"error": "not_found"})
            return
        if not self.authorized():
            return
        with lock:
            if state["status"] != "idle":
                self.send_json(409, {"error": "one_time_execution_already_started",
                                     "status": state["status"]})
                return
            state["status"] = "running"
            state["result"] = None
        threading.Thread(target=run_backup, daemon=True).start()
        self.send_json(202, {"status": "accepted", "message": "One-time backup started"})

    def log_message(self, fmt, *args):
        return

port = int(os.environ.get("PORT", "10000"))
ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
