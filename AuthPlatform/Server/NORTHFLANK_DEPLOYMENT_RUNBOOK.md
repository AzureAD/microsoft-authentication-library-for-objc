# AuthPlatform deployment on Northflank

## Deployment target

Northflank Developer Sandbox is the initial replacement for Fly.io. Its published free allowance currently includes up to $20/month of resource usage, two services, two jobs, and one addon. Northflank requires a payment method to create resources and explicitly says the Sandbox tier is for testing and should not be used for production applications. Do not treat this allowance as unlimited or production hosting.

WorkOS remains the identity provider. Northflank runs the Swift/Vapor API. PostgreSQL is the persistence layer.

## Create the API service

1. Sign in to Northflank and select the Developer Sandbox plan.
2. Create a project in a region available to your account.
3. Connect the GitHub repository `dabelstech-creator/microsoft-authentication-library-for-objc`.
4. Create a **Combined** service named `authplatform-api`, tracking `feature/secure-auth-platform-vapor` for initial validation only.
5. Select **Dockerfile** as the build type.
6. Set the Dockerfile path to `AuthPlatform/Server/Dockerfile` and build context to `AuthPlatform/Server`.
7. Configure a public HTTP port matching the server's container port 8080 and enable HTTPS/TLS.
8. Configure a health check using `GET /health`. The endpoint checks PostgreSQL readiness; `GET /live` checks process liveness.
9. Keep automatic deployment enabled only for the feature branch during validation. Production must track a reviewed release branch after merge.

Northflank's combined service supports Git-based builds and custom Dockerfiles. See https://northflank.com/docs/v1/application/getting-started/build-and-deploy-your-code.

## Database

Use the Northflank project database addon if the selected Sandbox plan exposes a suitable PostgreSQL addon within its resource allowance. Otherwise use a separate PostgreSQL provider with an explicitly verified free tier. Do not assume a free database is durable, backed up, or included without checking the live plan.

Set `DATABASE_URL` as a secret in the Northflank service. Use TLS settings required by the selected database provider. Run migrations as a controlled release step using a direct database connection where required; do not run concurrent migrations from every application replica.

## Runtime configuration

Configure secrets through Northflank's secret management. Never commit values to this repository or paste them into chat.

Required values depend on enabled routes and providers; at minimum review:
- `DATABASE_URL`
- `WORKOS_CLIENT_ID`
- `WORKOS_API_KEY`
- `WORKOS_ISSUER`
- `WORKOS_JWKS_URL`
- `AUTH_PUBLIC_URL` (set to the final HTTPS API hostname)
- `WEBAUTHN_RP_ID` (the final registered domain)
- `WEBAUTHN_RP_NAME=AuthPlatform`
- `WEBAUTHN_ORIGIN` (the exact HTTPS origin)
- `WORKOS_REDIRECT_URI=authplatform://auth/callback`
- Email and external OIDC provider secrets only when those features are enabled.

Use production tenant values from the WorkOS/provider dashboards. Do not substitute development credentials.

## Release gates

A successful container build is not production readiness. Before production:
- Use a production hosting plan with documented uptime and resource guarantees; Northflank says Sandbox should not be used for production.
- Configure automated database backups and prove a restore.
- Verify WorkOS JWT/JWKS validation, identity linking, session exchange, and refresh-token rotation.
- Complete pagination, versioning, conflict resolution, deletion propagation, and multi-device synchronization.
- Verify encrypted vault data remains opaque to the server.
- Complete physical iPhone AutoFill, shared Keychain, passkey, and recovery tests.
- Configure custom domain, HTTPS, monitoring, alerting, and incident recovery.
- Obtain required code-owner approvals.

## Cost control

The Sandbox allowance is a monthly resource allowance, not a promise that every possible workload is free. Northflank's documentation says a payment method is required to create resources. Set billing alerts, start with minimum viable compute, and do not add paid resources without reviewing their cost. If the project must remain strictly no-card/no-billing, do not provision Northflank; evaluate self-hosted infrastructure or a provider whose current terms meet that requirement.
