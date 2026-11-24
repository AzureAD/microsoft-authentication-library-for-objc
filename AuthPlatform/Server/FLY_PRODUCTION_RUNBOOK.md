# AuthPlatform production deployment on Fly.io

This runbook replaces the expired Railway deployment path. WorkOS remains the
identity provider; Fly.io runs the Swift/Vapor API; PostgreSQL stores identity,
session, audit, passkey, and encrypted-vault records.

## 1. Create the production app and database

From the repository's `AuthPlatform/Server` directory, authenticate to Fly.io
and create the app named in `fly.toml`:

```sh
fly auth login
fly apps create dabelstech-authplatform-prod
```

Create a production PostgreSQL cluster in the Johannesburg region (`jnb`) using
Fly Managed Postgres, then attach it to this app. Attaching the cluster should
provision the app's `DATABASE_URL` secret; do not paste the database password
into source control, workflow files, or chat.

Do not reuse a test database or the removed Railway Postgres service. The old
Railway service was previously marked removed and its recoverability was not
established. Treat it as unavailable unless the provider confirms a recoverable
backup.

## 2. Configure application secrets

Set the production WorkOS credentials and provider secrets in Fly.io, not in
GitHub source or the iOS app. At minimum, configure:

- `WORKOS_CLIENT_ID`
- `WORKOS_API_KEY` (server-only secret)
- `WORKOS_ISSUER`
- `WORKOS_JWKS_URL`
- `RESEND_API_KEY` and `AUTH_EMAIL_FROM` if email verification/reset is enabled
- Microsoft OIDC client ID, tenant ID, and client secret if Microsoft login is enabled
- OpenAI OIDC client ID and client secret if that provider is enabled

Configure the following non-secret environment values in Fly.io:

- `HOST=0.0.0.0`
- `PORT=8080`
- `AUTH_PUBLIC_URL=https://auth.moredesa.com`
- `WEBAUTHN_RP_ID=auth.moredesa.com`
- `WEBAUTHN_RP_NAME=AuthPlatform`
- `WEBAUTHN_ORIGIN=https://auth.moredesa.com`
- `WORKOS_REDIRECT_URI=authplatform://auth/callback`
- `MICROSOFT_TENANT_ID=common` unless the production tenant is restricted
- The matching production OIDC redirect URIs registered with each identity provider

Use the exact issuer, JWKS URL, client IDs, callback URLs, and domains from the
production WorkOS/provider dashboards. Do not copy test-tenant credentials.

## 3. Configure the domain and HTTPS

After the Fly app exists, attach `auth.moredesa.com` to the app and complete the
DNS validation requested by Fly.io. Verify the HTTPS certificate before
registering the production callback URLs with WorkOS and other providers.

The app's `/health` endpoint checks PostgreSQL readiness. `/live` reports
process liveness only.

## 4. Configure GitHub deployment access

Create a Fly deploy token scoped to this app and add it to GitHub repository
Settings → Secrets and variables → Actions as `FLY_API_TOKEN`. Never commit
the token or print it in logs.

Configure the GitHub `production` environment with required reviewers and
restrict deployments to the repository's default branch. The
`.github/workflows/fly-production-deploy.yml` workflow is manual-only and
runs the Swift/Vapor build and PostgreSQL integration tests before deploying.

The Fly app must already exist and have a working `DATABASE_URL` before the
workflow is dispatched. The Fly release command runs Fluent migrations once
before the new release receives traffic.

## 5. Validate before opening production traffic

- Confirm the GitHub Swift/Vapor PostgreSQL integration workflow passes.
- Confirm the manual Fly deploy completes and all Fly HTTP health checks pass.
- Verify `GET /health` returns database readiness and `GET /live` returns
  process liveness.
- Verify WorkOS token verification, user profile lookup, identity linking,
  session exchange, and refresh-token rotation against the production tenant.
- Verify email delivery, Microsoft/OpenAI OIDC callbacks (if enabled), and
  WebAuthn relying-party origin/domain configuration.
- Enable database backups and complete a restore drill in a separate database.
  Record recovery point and recovery time objectives.
- Verify encrypted vault payloads remain opaque to the server and that
  recovery, deletion propagation, pagination, and multi-device conflict
  behavior pass end-to-end tests.
- Complete physical iPhone AutoFill, shared Keychain, passkey, and recovery
  tests before releasing the iOS app.

Do not treat a green container build or `/health` response as proof that all
production release gates are complete.
