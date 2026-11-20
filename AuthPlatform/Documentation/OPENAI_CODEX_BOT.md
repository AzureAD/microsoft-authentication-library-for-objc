# OpenAI Codex implementation bot

This repository can run the OpenAI Codex agent from GitHub Actions to implement scoped engineering tasks.

## One-time setup

1. Create an OpenAI API key in the OpenAI API platform.
2. In GitHub, open **Settings → Secrets and variables → Actions → New repository secret**.
3. Add the secret named `OPENAI_API_KEY`. Never put the key in source code, an iOS app, a checked-in `.env` file, or a workflow input.
4. Ensure GitHub Actions is enabled and the workflow token is permitted to write to the feature branch. If branch protection blocks bot pushes, use a dedicated bot branch and PR instead of weakening protection.

The OpenAI API key is a server-side API credential. It is not the same as the `OPENAI_CLIENT_SECRET` used for Sign in with ChatGPT (OIDC). OIDC authenticates end users; the API key authorizes model requests.

## Run the bot

### From the Actions tab

1. Open **Actions → OpenAI Codex implementation bot → Run workflow**.
2. Select `feature/secure-auth-platform-vapor`.
3. Enter a bounded implementation task, such as: `Inspect the failing AuthPlatform CI run, fix the first root cause, and run the server tests. Do not weaken tests.`
4. Start the workflow and review its logs and resulting commit.

### From PR #4

Add the label `codex-implement` to PR #4. The workflow runs only for same-repository PRs. The bot works on the PR's existing head branch and posts its summary as a PR comment.

## Guardrails

- The Codex action uses a workspace permission profile and drops sudo on the macOS runner.
- The task is limited to the checked-out repository. The prompt prohibits changes to Apple's upstream repository and MSAL upstream SDK source.
- The workflow runs `swift test --package-path AuthPlatform/Server` and `git diff --check` before committing.
- It never merges or deploys. Existing CI workflows run again after the bot pushes.
- Tests and security checks must not be disabled or weakened to obtain a passing result.
- A task that fails validation is not committed by this workflow.
- Review every generated diff and CI run before merging.

## Important

This workflow is not active until the repository secret `OPENAI_API_KEY` is configured. GitHub does not allow a workflow to read a secret value back through the API, so configure it in repository settings.
