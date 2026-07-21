# AGENTS.md

General information about the project is located in the README.md file.

## Application Creation Guidance

### MSAL Application Configuration for Apple Devices

When creating a new application with MSAL authentication, users need to select a tenant configuration:

- **Workforce** (default): For organizational identities
  - Follow the instructions detailed under `.clinerules/01-Workforce-tenant-configuration.md`
- **External**: For customer/partner identities
  - Follow the instructions detailed under `.clinerules/02-External-tenant-configuration.md`

#### Key Differences Summary: Workforce vs. External Tenants

| Aspect | Workforce Tenant | External Tenant |
|--------|----------------|------------------|
| **Target Users** | Employees, internal users | Customers, partners, citizens |
| **Registration** | Admin-managed accounts | Self-service sign-up |
| **User Flows** | Standard authentication | Customizable sign-up/sign-in flows |
| **Branding** | Corporate branding | Fully customizable for customer UX |
| **Identity Providers** | Typically organizational only | Social providers supported |
| **Tenant Configuration** | Same, but different context | "Accounts in this organizational directory only" |
| **Authority Endpoint** | Uses tenant ID or common | Uses tenant subdomain |
| **Use Cases** | Enterprise apps, B2E scenarios | Consumer apps, B2C scenarios |

## Build and test guidelines

AI agents MUST build and run tests using the build/test configuration already set up in Xcode — i.e. the schemes defined in `MSAL.xcworkspace`, driven through `build.py` (e.g. `./build.py --targets iosFramework macFramework`). Always use `MSAL.xcworkspace`, never open or build `MSAL.xcodeproj` directly, and do not invent ad-hoc `xcodebuild` invocations, schemes, or configurations that diverge from the ones configured in the workspace. If a build/test run needs a specific simulator, select an available one via the `IOS_SIM_DEVICE` / `IOS_SIM_OS` environment variables (consumed by `build.py`) rather than changing the scheme or configuration.

## MSAL API usage

Sample code snippets for both Swift & Objective-C can be found in the file `.clinerules/03-MSAL-API-usage.md`

## Code style guidelines

Code style guidelines that AI agents MUST follow when working with this repository can be found in the file `.clinerules/04-Code-style-guidelines.md`

For Swift code under `MSAL/src/native_auth` (including V2 / server-driven flows), follow the **Swift Style (native_auth)** section of that file: match the existing V1 native auth formatting, keep changed files SwiftLint-clean (`MSAL/.swiftlint.yml`), wrap long calls/declarations to ≤150 columns (one argument per line) rather than suppressing `line_length`, and prefer `// swiftlint:disable:next function_body_length` / `cyclomatic_complexity` over refactoring long orchestration methods.

## Feature flag guidelines

Feature flag guidance for AI agents when implementing new features for MSAL library are defined in the file `.clinerules/05-Feature-gating.md`

## Customer Communication

When interacting with users across **any channel** (GitHub issues, web chat, agent sessions), AI agents should follow these guidelines: `.clinerules/06-Customer-communication-guidelines.md`
