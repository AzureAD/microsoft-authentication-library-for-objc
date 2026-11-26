# AuthPlatform one-time encrypted backup runner

This is a free Render Web Service with a single authenticated trigger. It is not a scheduled job; the trigger is accepted only once per container lifetime.

## Required Render runtime secrets

Set these directly in the Render Web Service environment settings. Never commit them or paste them into chat.

- `DATABASE_URL`: PostgreSQL **Internal Database URL** for `sign-trigger-passkeys`.
- `DROPBOX_ACCESS_TOKEN`: short-lived Dropbox OAuth token with only `files.content.write` and `files.metadata.read` scopes. Do not grant sharing scopes.
- `BACKUP_ENCRYPTION_PASSPHRASE`: unique random passphrase of at least 24 characters; store separately from the backup.
- `BACKUP_TRIGGER_TOKEN`: separate random bearer token of at least 32 characters; store in a password manager.
- Optional `DROPBOX_DEST`: defaults to `/AuthPlatform Backups`.
- Optional `BACKUP_FILENAME`: defaults to `authplatform-production-one-time.dump.gpg`.

Use the Free plan in Oregon, matching the database. No database credentials or tokens belong in GitHub.

## Dropbox app setup

The staging folder was created at the Dropbox account root (`/AuthPlatform Backups`). Configure the Dropbox app for Full Dropbox access, but grant only `files.content.write` and `files.metadata.read` OAuth scopes. Do not grant sharing scopes. Generate a short-lived token for the one-time run and revoke it after upload.

## GitHub Actions manual trigger

The repository workflow is `.github/workflows/authplatform-one-time-encrypted-backup.yml`.
It is deliberately manual-only (`workflow_dispatch`) and requires the operator to select
`confirm_backup=yes`. It checks that `GET /status` is idle, sends exactly one
authenticated `POST /run`, polls for completion, and validates the returned upload
metadata without printing credentials.

Before the workflow can run:

1. In the repository, open **Settings → Secrets and variables → Actions**.
2. Create a repository secret named exactly `BACKUP_TRIGGER_TOKEN`.
3. Set its value to the same token configured as the Render runner's
   `BACKUP_TRIGGER_TOKEN`. Enter it directly into GitHub; never commit it or paste it
   into chat.
4. Ensure the workflow file is present on the repository's default branch. GitHub's
   manual workflow dispatch requires that.
5. Open **Actions → AuthPlatform One-Time Encrypted Backup → Run workflow** and select
   `yes` only when explicitly ready to start the production export.

The workflow secret is separate from the Render runtime secrets. It contains only the
trigger bearer token; the database URL, Dropbox token, and encryption passphrase remain
configured in Render and are not copied into GitHub.

## Read-only integration verification

After deploying the Runner, an operator can call `GET /verify` with the
`BACKUP_TRIGGER_TOKEN` bearer token. It performs only PostgreSQL `SELECT 1`
with read-only transaction settings and a Dropbox `files/list_folder` metadata
request against `DROPBOX_DEST`. It does not create, upload, delete, or modify
files and does not start a backup. The Dropbox token therefore needs
`files.metadata.read` in addition to the backup upload scope.

The public `/status` endpoint returns only the current execution state; it does
not expose backup result metadata. `/source-counts` and `/run` remain
authenticated. `/health` is a liveness check, not an integration check.

## Authenticated source count endpoint

`GET /source-counts` requires the same `Authorization: Bearer <BACKUP_TRIGGER_TOKEN>`
header as the backup trigger. It returns exact aggregate row counts and existence flags
for the fixed 11-table application allowlist used by the isolated restore validation.
It does not accept SQL, schema names, or table names from the request and never returns
records or credentials. The query runs with PostgreSQL's read-only transaction setting
and a 15-second statement timeout. Failures return a generic error without database
diagnostics. Responses are marked `Cache-Control: no-store`.

Example response shape (counts shown here are illustrative only):

```json
{
  "status": "ok",
  "source": "production_database",
  "read_only": true,
  "count_type": "exact",
  "tables": [
    {"table": "users", "exists": true, "row_count": 0}
  ]
}
```

## One-time execution

1. Configure all secrets above in the Render service Environment page.
2. Deploy and wait for `/health` to return ready.
3. Send one HTTPS POST to `/run` with header `Authorization: Bearer <BACKUP_TRIGGER_TOKEN>`. Never put the token in a URL or chat.
4. Poll `/status` until it reports `succeeded` or `failed`.
5. Download the encrypted `.gpg` file from Dropbox to the iPhone and move it into `iCloud Drive/AuthPlatform Backups/`.
6. Revoke the Dropbox token, remove the trigger token and passphrase from Render, then suspend or delete the runner service.

The fixed Dropbox filename uses add-only upload with strict conflict handling to prevent a second successful upload under a different filename.

## Safety properties

- `pg_dump` is read-only and does not apply migrations.
- The source-count endpoint uses fixed table identifiers, exact aggregate counts, and read-only database settings.
- Custom-format archive is inspected with `pg_restore --list` before encryption.
- GPG symmetric AES-256 encryption occurs before any network upload.
- Dropbox upload uses the content API only; no shared link is created.
- Plaintext is held in an ephemeral container directory and removed when the process exits.
- The service does not log request headers, tokens, passphrases, database URLs, or subprocess stderr.
- A successful upload and archive listing are not a restore test. Restore validation must occur against an isolated, disposable PostgreSQL instance, never production.

## Decryption

```sh
gpg --output authplatform-production.dump --decrypt authplatform-production-one-time.dump.gpg
pg_restore --list authplatform-production-one-time.dump.gpg
```

GPG prompts for the passphrase. Do not store it alongside the encrypted dump.
