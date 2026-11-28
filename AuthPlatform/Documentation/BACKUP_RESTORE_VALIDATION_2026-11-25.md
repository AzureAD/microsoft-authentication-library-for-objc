# AuthPlatform encrypted backup and isolated restore validation

**Phase status: COMPLETE — isolated restore and production row-count parity verified**  
**Evidence date:** 2026-11-25 UTC  
**Repository branch:** `dabelstech-creator-patch-1`

## Backup artifact

- Dropbox archive: `/AuthPlatform Backups/authplatform-production-one-time-20261124-2320.dump.gpg`
- Size: 4,377 bytes
- SHA-256: `8a4d60dd4496e01711a01a9245c9322aa71fd3b5c96cb22198e33b5b0ccafaff`
- Dropbox content hash: `e1234a2d8d187744ab1fe833b0f3fcb9223046d5a5b51b3076b89bf2c6d509ab`
- Backup workflow run: [45512980524](https://github.com/dabelstech-creator/microsoft-authentication-library-for-objc/actions/runs/45512980524)
- Encryption and Dropbox credentials are intentionally not recorded here.

## Isolated restore evidence

- Workflow: `.github/workflows/authplatform-isolated-restore-test.yml`
- Successful run: [45519281619](https://github.com/dabelstech-creator/microsoft-authentication-library-for-objc/actions/runs/45519281619)
- Restore target: disposable PostgreSQL 18 database/container `restore_validation`; production database was not used as a restore target.
- Result: 11/11 expected application tables present; 0 missing.
- Restored database objects: 12.
- Public indexes: 22.
- Public constraints: 92, including 12 primary keys, 8 foreign keys, and 10 unique constraints.
- Workflow emitted `PRODUCTION_DATABASE_TOUCHED=false`.
- The workflow excludes proprietary `prisma_postgres` extension TOC entries unavailable in stock PostgreSQL. This remains a documented portability limitation, not a production restore test.

## Production source-count evidence

- Workflow: `.github/workflows/authplatform-source-counts.yml`
- Successful read-only run: [45522094873](https://github.com/dabelstech-creator/microsoft-authentication-library-for-objc/actions/runs/45522094873)
- Endpoint result: `status=ok`, `read_only=true`, `count_type=exact`, source `production_database`.
- All 11 allowlisted tables exist in production.
- Exact production row counts:
  - `auth_rate_limits`: 3
  - `users`, `passkey_credentials`, `auth_sessions`, `oauth_accounts`, `audit_events`, `refresh_token_records`, `one_time_auth_tokens`, `passkey_challenges`, `oidc_login_transactions`, `encrypted_vault_items`: 0 each.
- These counts match the recorded isolated-restore baseline: 3 rows in `auth_rate_limits`, 0 in each of the other 10 tables.

## Validation conclusion

The encrypted archive was successfully restored into an isolated PostgreSQL 18 target, all 11 expected application tables were present, and the exact production table counts match the isolated restore baseline. **The isolated restore validation phase is complete.**

This conclusion is limited to the tested archive, allowlisted tables, object checks, and row-count parity. Equal row counts do not establish byte-for-byte record equality or complete schema equivalence. The proprietary Prisma Postgres extension limitation remains. This phase completion does not constitute overall AuthPlatform production approval and does not authorize restoring into production.

## Reproduction links

- [Encrypted backup workflow](https://github.com/dabelstech-creator/microsoft-authentication-library-for-objc/actions/runs/45512980524)
- [Isolated restore validation](https://github.com/dabelstech-creator/microsoft-authentication-library-for-objc/actions/runs/45519281619)
- [Production source-count verification](https://github.com/dabelstech-creator/microsoft-authentication-library-for-objc/actions/runs/45522094873)
