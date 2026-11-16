const CLIENT_ID = "YOUR_CLIENT_ID";
const TENANT = "common";

const msalInstance = new msal.PublicClientApplication({
  auth: {
    clientId: CLIENT_ID,
    authority: "https://login.microsoftonline.com/" + TENANT,
    redirectUri: window.location.origin + "/",
  },
  cache: { cacheLocation: "localStorage" },
});

const statusEl = document.getElementById("status");
const signinBtn = document.getElementById("signin");
const signoutBtn = document.getElementById("signout");
const claimsEl = document.getElementById("claims");

function render(account) {
  if (account) {
    statusEl.textContent = "Signed in as " + account.username;
    claimsEl.textContent = JSON.stringify(account.idTokenClaims || {}, null, 2);
    claimsEl.hidden = false;
    signinBtn.hidden = true;
    signoutBtn.hidden = false;
  } else {
    statusEl.textContent = "Not signed in";
    claimsEl.hidden = true;
    signinBtn.hidden = false;
    signoutBtn.hidden = true;
  }
}

signinBtn.onclick = () => msalInstance.loginRedirect({ scopes: ["openid", "profile", "User.Read"] });
signoutBtn.onclick = () => msalInstance.logoutRedirect({ account: msalInstance.getAllAccounts()[0] });

msalInstance.handleRedirectPromise()
  .then((result) => render(result ? result.account : msalInstance.getAllAccounts()[0]))
  .catch((e) => { statusEl.textContent = "Error: " + e.message; signinBtn.hidden = false; });

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js");
}
