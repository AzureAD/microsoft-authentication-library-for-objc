const base = "/password-manager-resources";

async function loadJSON(name) {
  const response = await fetch(`${base}/${name}.json`, { credentials: "omit" });
  if (!response.ok) throw new Error(`Unable to load ${name} resource (${response.status})`);
  return response.json();
}

export async function loadApplePasswordManagerResources() {
  const [passwordRules, shared, historical, changeURLs, append2FA, appIDs, thirdParty] = await Promise.all([
    loadJSON("password-rules"),
    loadJSON("shared-credentials"),
    loadJSON("shared-credentials-historical"),
    loadJSON("change-password-URLs"),
    loadJSON("websites-that-append-2fa-to-password"),
    loadJSON("apple-appIDs-to-domains-shared-credentials"),
    loadJSON("websites-that-ask-for-credentials-for-other-services-when-embedded-as-third-party")
  ]);
  return { passwordRules, shared, historical, changeURLs, append2FA, appIDs, thirdParty };
}

function normalizeHost(value) {
  try {
    const host = new URL(value.includes("://") ? value : `https://${value}`).hostname.toLowerCase();
    return host && !host.includes("..") ? host.replace(/^\.+|\.+$/g, "") : null;
  } catch {
    return null;
  }
}

function domainMatches(host, domain) {
  return host === domain || host.endsWith(`.${domain}`);
}

export function passwordRuleFor(resources, hostOrURL) {
  const host = normalizeHost(hostOrURL);
  if (!host) return null;
  const match = Object.keys(resources.passwordRules)
    .filter(domain => domainMatches(host, domain))
    .sort((a, b) => b.length - a.length)[0];
  if (!match) return null;
  const rule = resources.passwordRules[match];
  if (rule["exact-domain-match-only"] === true && host !== match) return null;
  return rule["password-rules"] ?? null;
}

export function changePasswordURLFor(resources, hostOrURL) {
  const host = normalizeHost(hostOrURL);
  if (!host) return null;
  const match = Object.keys(resources.changeURLs)
    .filter(domain => domainMatches(host, domain))
    .sort((a, b) => b.length - a.length)[0];
  return match ? resources.changeURLs[match] : null;
}

export function relatedCredentialDomainsFor(resources, hostOrURL) {
  const host = normalizeHost(hostOrURL);
  if (!host) return [];
  return resources.shared.find(group => group.shared.includes(host))?.shared ?? [];
}

export function historicallyRelatedCredentialDomainsFor(resources, hostOrURL) {
  const host = normalizeHost(hostOrURL);
  if (!host) return [];
  return resources.historical.find(group => group.shared.includes(host))?.shared ?? [];
}

export function requiresAppendingOneTimeCode(resources, hostOrURL) {
  const host = normalizeHost(hostOrURL);
  return !!host && resources.append2FA.some(domain => domainMatches(host, domain));
}

export function mayRequestThirdPartyCredentials(resources, hostOrURL) {
  const host = normalizeHost(hostOrURL);
  return !!host && resources.thirdParty.some(domain => domainMatches(host, domain));
}

export function sharedDomainsForAppID(resources, appIdentifier) {
  return resources.appIDs[appIdentifier] ?? [];
}

// Shared-domain mappings are suggestion context only. Never automatically
// submit a credential to a domain other than the credential's saved origin.
