# AuthPlatform isolated test subject

This deployment is for validation only. It must use a dedicated Fly app and a
dedicated PostgreSQL database. Do not point it at production data, production
credentials, or a production OAuth tenant.

## 1. Create the isolated Fly app

Install and authenticate the Fly CLI, then run:

```sh
fly auth login
fly apps create dabelstech-authplatform-test
```

The app is configured for the Johannesburg region (`jnb`) and exposes HTTPS
on port 8080. Rename the `app` value in `fly.toml` if that name is unavailable.

## 2. Configure test-only secrets

Provision a separate PostgreSQL database first. Then set its connection URL:

```sh
fly secrets set DATABASE_URL='postgresql://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require' \
  --app dabelstech-authplatform-test
```

For email-verification and password-recovery tests, configure a test-only Resend
key and sender plus the public HTTPS URL:

```sh
fly secrets set RESEND_API_KEY='TEST_RESEND_KEY' \
  AUTH_EMAIL_FROM='AuthPlatform Test <no-reply@example.test>' \
  AUTH_PUBLIC_URL='https://dabelstech-authplatform-test.fly.dev' \
  --app dabelstech-authplatform-test
```

Set WebAuthn values only after selecting the final test hostname:

```sh
fly secrets set WEBAUTHN_RP_ID='dabelstech-authplatform-test.fly.dev' \
  WEBAUTHN_RP_NAME='AuthPlatform Test' \
  WEBAUTHN_ORIGIN='https://dabelstech-authplatform-test.fly.dev' \
  --app dabelstech-authplatform-test
```

Microsoft and OpenAI OIDC credentials are optional for the initial smoke test.
Use dedicated test client registrations and exact callback URLs before enabling
those providers. Never paste secrets into source files or commit them.

## 3. Deploy

From `AuthPlatform/Server`:

```sh
fly deploy --config fly.toml --dockerfile Dockerfile --app dabelstech-authplatform-test
```

The Fly release command is intentionally not configured to migrate automatically.
Run migrations explicitly after verifying the database target:

```sh
fly ssh console --app dabelstech-authplatform-test -C '/app/App migrate --yes'
```

## 4. Smoke test

```sh
curl --fail https://dabelstech-authplatform-test.fly.dev/health
```

Then exercise registration, email verification, login, refresh-token rotation,
logout, password recovery, passkey registration/assertion, and OAuth callbacks
using synthetic test accounts only. Confirm rate limits and audit events using
the test database.

## Safety and cleanup

- Use synthetic accounts and non-production secrets only.
- Do not use a real personal password or a production Microsoft/OpenAI client.
- Keep the Fly app private to the test workflow where possible; do not advertise
  it as a production login portal.
- Review logs for accidental credential or token disclosure.
- Delete the Fly app and its dedicated database when testing is complete:
  `fly apps destroy dabelstech-authplatform-test`.
