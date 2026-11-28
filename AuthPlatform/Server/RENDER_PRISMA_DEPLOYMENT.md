# AuthPlatform free Render + Prisma Postgres test deployment

This is an isolated, non-production deployment of the Swift/Vapor authentication
service. It uses Render's free Docker web service and a claimed Prisma Postgres
Free database. Do not use real user accounts, production OAuth clients, or
production secrets.

## Free-tier constraints

- Render Free web services sleep after 15 minutes without inbound traffic and
  can take about a minute to wake. The instance has an ephemeral filesystem,
  can restart, and does not provide shell access or one-off jobs.
- Render's free web-service allowance is 750 instance hours per workspace per
  calendar month, shared across its free services.
- Prisma Postgres Free currently includes 2 GB storage, 200,000 operations per
  month, and up to 50 databases. A database created in the Console or claimed
  within 24 hours has no automatic time limit. Free databases have no backups.
- These limits are suitable for development and synthetic test data only, not
  production authentication.

Check current limits before creating resources:
- https://render.com/docs/free
- https://www.prisma.io/postgres/free-postgresql-hosting

## 1. Create and claim the Prisma Postgres database

1. Open https://console.prisma.io/ and sign in or create an account.
2. Create a PostgreSQL database in the Free workspace.
3. Choose `us-west-1` (San Francisco), which is the closest available Prisma
   Postgres region to Render's Oregon region.
4. If using the temporary `npx create-db` flow, claim the database within
   24 hours so it is retained in your workspace.
5. Open the database's connection details and select the **direct** PostgreSQL
   connection string, not the pooled/PgBouncer URL. The Vapor service runs Fluent
   migrations at startup; Prisma documents direct connections for migrations
   because pooled connections can cause migration lock/prepared-statement
   failures.
6. Keep the connection string private. Do not commit it, paste it into issues,
   or send it in chat. It should use PostgreSQL URL syntax and TLS
   (`sslmode=require`).

Prisma connection guidance:
https://www.prisma.io/docs/postgres/database/connecting-to-your-database

## 2. Create the Render service from this Blueprint

1. Open https://dashboard.render.com/ and connect the GitHub account that can
   access `dabelstech-creator/microsoft-authentication-library-for-objc`.
2. Choose **New → Blueprint** and select this repository.
3. Select branch `feature/secure-auth-platform-vapor`, where `render.yaml`
   lives. Review the Blueprint before applying it.
4. The Blueprint creates `authplatform-test` as a Free Docker web service in
   Oregon. It uses:
   - Dockerfile: `AuthPlatform/Server/Dockerfile`
   - Docker build context: `AuthPlatform/Server`
   - Health check: `/health`
5. When prompted for `DATABASE_URL`, paste the Prisma **direct** connection
   string into Render's secret/environment-variable field. Do not add it to
   the repository or Blueprint YAML.
6. Deploy and wait for the first build to complete.

Render Docker/Blueprint documentation:
- https://render.com/docs/docker
- https://render.com/docs/blueprint-spec

## 3. Database migrations

Render Free web services do not support paid-plan pre-deploy commands or
one-off jobs. The Dockerfile therefore runs:

```sh
/app/App migrate --yes
```

before starting the Vapor server on every container start. Fluent tracks
completed migrations, so already-applied migrations are skipped. Keep this
single-instance test service pointed at its dedicated test database.

The application reads Render's injected `PORT` environment variable and binds
to `0.0.0.0`.

## 4. Verify the deployment

Render assigns an HTTPS hostname based on the service name. Find the exact
hostname on the service's dashboard, then run:

```sh
curl --fail https://YOUR-RENDER-HOST.onrender.com/health
curl --fail https://YOUR-RENDER-HOST.onrender.com/v1/auth/capabilities
```

The health response should report `status: ok`. The capabilities endpoint
should list the configured authentication methods. The first request after an
idle period may be slow while the free service wakes.

Review Render deploy logs for migration and startup errors. Never share logs
that contain environment values, tokens, email addresses, or connection URLs.

## 5. Optional integrations (not required for the first free smoke test)

Only configure these after the core service and database work:

- `RESEND_API_KEY`, `AUTH_EMAIL_FROM`, `AUTH_PUBLIC_URL` for email
  verification and password recovery.
- `WEBAUTHN_RP_ID`, `WEBAUTHN_RP_NAME`, `WEBAUTHN_ORIGIN` for passkeys.
- Microsoft and OpenAI OIDC client settings using dedicated test registrations
  and exact callback URLs.

Add these as Render environment variables/secrets in the service dashboard.
Do not put secret values in `render.yaml`. Third-party email delivery and
identity-provider services may have their own eligibility, quotas, or charges;
they are not included in the $0 hosting claim.

## Safety and cleanup

- Synthetic accounts and test-only credentials only.
- Do not use this environment as a production login service.
- Prisma Free has no backups; export any test data you need before deleting it.
- Delete the Render service and Prisma database when the test is complete.
- The previous Fly.io configuration remains in the repository as an unused
  alternative; this deployment path uses Render and Prisma only.
