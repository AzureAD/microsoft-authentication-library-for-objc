# AuthPlatform deployment on Render

## Status and target

Render is the selected host for a no-credit-card validation deployment. Its official Docker hosting offer states that free Docker web services require no credit card. The free web service has 750 instance-hours per workspace/month, sleeps after 15 minutes idle, can restart at any time, and has an ephemeral filesystem. Free Render Postgres expires after 30 days and has no backups. Therefore this configuration is for deployment and integration validation only; do not store real user vault data or treat it as production.

The GitHub repository and branch are preserved:
- Repository: `dabelstech-creator/microsoft-authentication-library-for-objc`
- Branch: `feature/secure-auth-platform-vapor`
- Blueprint: `render.yaml`
- Dockerfile: `AuthPlatform/Server/Dockerfile`
- Docker context: `AuthPlatform/Server`

WorkOS remains the identity provider. Render hosts the Vapor API. PostgreSQL remains the persistence layer.

## Create the service

1. Sign in to Render using the GitHub account that can access the repository.
2. Open https://dashboard.render.com/blueprints and choose **New Blueprint Instance**.
3. Connect `dabelstech-creator/microsoft-authentication-library-for-objc`.
4. Select branch `feature/secure-auth-platform-vapor`; Render reads the root `render.yaml`.
5. Review the service. It must show `authplatform-api`, Docker runtime, Free plan, Ohio region, and the exact Dockerfile/context paths above.
6. Keep the plan set to **Free**. Do not add a payment method or upgrade.
7. Blueprint creation will prompt for secret values marked `sync: false`. Do not paste secrets into GitHub or commit them. Configure `DATABASE_URL` from a PostgreSQL provider that meets the project's retention and no-card requirements. Configure WorkOS values from the WorkOS dashboard.
8. Create the Blueprint only after all required secret values are available. Confirm the dashboard shows Free before proceeding.
9. Wait for the image build and deploy. Confirm `GET /live` and `GET /health` return success. The latter performs a PostgreSQL readiness query.

## Database and data-safety gate

Do not use Render's Free PostgreSQL database for real vault data: it expires 30 days after creation, has no backups, and becomes inaccessible after expiry. Use it only for disposable integration tests if explicitly chosen. Before any real user data is stored, select a database with durable retention, backups/restore, TLS, and a documented no-card signup path. Keep the database connection string in Render's secret environment variables only.

## Runtime and release gates

- The API must bind to `0.0.0.0` and Render's `PORT` (configured to 10000).
- The app currently requires `DATABASE_URL` at startup and has Fluent migrations registered. Verify the migration execution path before relying on schema creation; do not assume registering migrations automatically applies them.
- Confirm all required WorkOS issuer/JWKS settings and WebAuthn RP ID/origin match the final HTTPS hostname.
- Email verification/password reset require `RESEND_API_KEY`, `AUTH_EMAIL_FROM`, and `AUTH_PUBLIC_URL`.
- Run the current GitHub Actions Swift/Vapor build and tests, then verify the deployed health endpoints and PostgreSQL integration behavior.
- Complete sync versioning, conflict resolution, pagination, deletion propagation, multi-device tests, physical iPhone AutoFill/shared Keychain/passkey/recovery tests, backups/restore, monitoring, and code-owner approvals before production.

## Cost controls

Remain on Render's Free service. Do not add a card, paid database, persistent disk, worker, or paid compute. If Render asks for payment or displays a charge, stop. The free service is a preview/validation environment, not a production guarantee.
