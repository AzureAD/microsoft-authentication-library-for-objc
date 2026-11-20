# Shared web portal

The web client is a separate deployable frontend that consumes the Swift Vapor API. It must not implement password verification, token signing, Microsoft client-secret exchange, or WebAuthn verification in browser code.

## Required browser behavior
- Use authorization-code flow with PKCE for OIDC sign-in.
- Prefer server-managed sessions in Secure, HttpOnly, SameSite cookies.
- Use CSRF tokens for state-changing cookie-authenticated requests.
- Use WebAuthn browser APIs only to create/get credential responses; send those responses to the server for verification.
- Do not persist access tokens, refresh tokens, passwords, or provider secrets in localStorage/sessionStorage.
- Restrict CORS to explicitly configured portal origins.


## Apple Password AutoFill compatibility

Static Apple Password Manager Resources snapshots are published under `public/password-manager-resources/`. Import `apple-password-manager-resources.js` in the portal to resolve site-specific password rules and change-password URLs.

Example:

```js
import {
  loadApplePasswordManagerResources,
  passwordRuleFor,
  changePasswordURLFor
} from "./apple-password-manager-resources.js";

const resources = await loadApplePasswordManagerResources();
const rules = passwordRuleFor(resources, window.location.hostname);
const passwordInput = document.querySelector('input[autocomplete="new-password"]');
if (passwordInput && rules) passwordInput.setAttribute("passwordrules", rules);

const changePasswordURL = changePasswordURLFor(resources, window.location.hostname);
```

Use semantic autocomplete values on every form: `username`, `current-password`, `new-password`, and `one-time-code`. Only apply password rules for the exact site where the rule resolver returns a match. Shared credential relationships may inform a user-reviewed suggestion but must never be used to auto-submit credentials to another domain.

The snapshot is intentionally static and version-controlled. Refresh both the iOS and web copies with `scripts/sync-apple-password-manager-resources.sh` and review changes before committing.
