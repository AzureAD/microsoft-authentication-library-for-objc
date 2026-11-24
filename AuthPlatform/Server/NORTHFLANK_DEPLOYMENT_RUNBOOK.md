# AuthPlatform deployment on Northflank

## Deployment target

Northflank Developer Sandbox is the initial no-payment validation target. The signed-in account dashboard was inspected on 2026-11-24 and showed the **Free / Developer Sandbox** plan active, no payment method on file, and no payment method required for the current plan. Do not add a card, enable paid billing, or upgrade. If Northflank presents a billing or paid-plan requirement at any provisioning step, stop and report it rather than proceeding.

The existing Northflank team project is named `Default`. It is empty: no services, jobs, addons/databases, secrets, volumes, or deployments exist. The account has already used its one free-project allocation, so use this existing project; do not create another project. Account-level quota counters and plan resource allowances are distinct. Confirm the selected service's estimated cost/allowance in the UI before creation and keep the smallest viable instance and one replica.

WorkOS remains the identity provider. Northflank runs the Swift/Vapor API. PostgreSQL is the persistence layer.

## GitHub connection prerequisite

The current Northflank VCS integration exposes the GitHub account/namespace `hundredlino`, but the target repository is `dabelstech-creator/microsoft-authentication-library-for-objc` and was not visible through that connection during inspection. The GitHub provider page has a `View all` linked-accounts control; add/authorize the GitHub identity that can access `dabelstech-creator` there. Do not disconnect the existing `hundredlino` integration. Do not deploy until the exact target repository and branch are visible in Northflank.

## Create the API service

1. Use the existing `Default` project and select a region available on the Free plan.
2. Confirm the repository `dabelstech-creator/microsoft-authentication-library-for-objc` is visible through the GitHub integration.
3. Create a **Combined** service named `authplatform-api`, tracking `feature/secure-auth-platform-vapor` for initial validation only.
4. Select **Dockerfile** as the build type.
5. Set the Dockerfile path to `AuthPlatform/Server/Dockerfile` and build context to `AuthPlatform/Server`.
6. Configure a public HTTP port matching the server's container port 8080 and enable HTTPS/TLS.
7. Configure a health check using `GET /health`. The endpoint checks PostgreSQL readiness; `GET /live` checks process liveness.
8. Use the smallest available compute profile and one replica. Do not enable paid add-ons, autoscaling, or additional replicas.
9. Keep automatic deployment enabled only for the feature branch during validation. Production must track a reviewed release branch after merge.

Northflank's combined service supports Git-based builds and custom Dockerfiles. See https://northflank.com/docs/v1/application/getting-started/build-and-deploy-your-code.

## Database

Do not provision a PostgreSQL addon until the dashboard confirms it is included in the Free plan without payment or upgrade. The inspected account had zero addons/databases. If a free Northflank PostgreSQL addon is not available, pause deployment and evaluate an external PostgreSQL provider only after verifying its current free-tier limits, billing requirements, connection limits, backups, and data-retention terms.

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
- Use a production hosting plan with documented uptime and resource guarantees; Developer Sandbox is for validation, not production.
- Configure automated database backups and prove a restore.
- Verify WorkOS JWT/JWKS validation, identity linking, session exchange, and refresh-token rotation.
- Complete pagination, versioning, conflict resolution, deletion propagation, and multi-device synchronization.
- Verify encrypted vault data remains opaque to the server.
- Complete physical iPhone AutoFill, shared Keychain, passkey, and recovery tests.
- Configure custom domain, HTTPS, monitoring, alerting, and incident recovery.
- Obtain required code-owner approvals.

## Cost control

This project must remain on the no-payment path. The inspected account currently has no payment method and the Developer Sandbox dashboard says none is required. Do not add a payment method, enable paid billing, or upgrade. Before creating each resource, verify that it fits the active Free plan and does not display a charge, paid-only requirement, or billing prompt. Stop if any step requires payment. Keep compute at the minimum viable size, one replica, and no paid add-ons. Free-tier availability and quotas can change; re-check the dashboard before provisioning.
