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

## MSAL API usage

Sample code snippets for both Swift & Objective-C can be found in the file `.clinerules/03-MSAL-API-usage.md`

## Code style guidelines

Code style guidelines that AI agents MUST follow when working with this repository can be found in the file `.clinerules/04-Code-style-guidelines.md`

## Feature flag guidelines

Feature flag guidance for AI agents when implementing new features for MSAL library are defined in the file `.clinerules/05-Feature-gating.md`

## Customer Communication

When interacting with users across **any channel** (GitHub issues, web chat, agent sessions), AI agents should follow these guidelines: `.clinerules/06-Customer-communication-guidelines.md`
