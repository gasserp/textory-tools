# Auth contract: web password login + mandatory 2FA

This document specifies the API contract the **closed-source backend**
(`gasserp/textory`) must implement for web username/password login with mandatory
TOTP two-factor authentication, and records the threat model behind each requirement.

The clients in this repo implement their half of this contract. **Until the backend
implements its half, the feature is inert** — see [Capability detection](#capability-detection).

> **The security of this feature lives almost entirely in the backend.** The client
> can present a second factor; only the server can *require* one. Nothing in this
> repo enforces 2FA.

---

## 1. Capability detection

```http
GET /api/auth/capabilities            # unauthenticated, no side effects
200 { "webPasswordLogin": boolean, "mfa": "unsupported" | "optional" | "required" }
```

The client treats a 404, a network error, or a malformed body as
`{ webPasswordLogin: false, mfa: "unsupported" }` and falls back to today's
GitHub-SSO-only behaviour. **Errors are never cached** — only successful responses are,
for the lifetime of the page.

Why this exists: a client that renders a 2FA wall while the API still serves every
session to anyone is *worse* than shipping nothing, because it looks like protection
that is not there. Capability detection makes the server — the only party that can
enforce anything — decide when the UI appears.

This is not a security control and is not relied on as one. An attacker who could
suppress `/api/auth/capabilities` (TLS MITM or XSS) has already won by other means;
all they achieve is a degraded UI against a still-enforcing server.

---

## 2. Endpoints

### 2.1 Web login (cookie-issuing)

```http
POST /api/auth/web/login          { username, password }
200  { "status": "mfa_required", "challenge": "<opaque>", "expiresIn": 300 }
401  { "error": "invalid credentials" }
```

- **Never returns a bearer token in the body.** Web sessions are cookies only.
- Requires same-origin proof (§3.2). Reject otherwise.
- Returns `mfa_required` for **every valid credential pair, from day one** — never a
  per-account branch. A response that differs by whether the account has 2FA is a
  clean oracle for "which accounts are worth attacking".
- `401` bodies and response *timing* must be identical for unknown-user and
  wrong-password (perform dummy KDF work for unknown users).

### 2.2 Web second factor (cookie-issuing)

```http
POST /api/auth/web/2fa/verify     { challenge, code }
200  { "user": … }
     Set-Cookie: __Host-txs=…; HttpOnly; Secure; SameSite=Strict; Path=/
401  { "error": "invalid code" }
429  { "error": "too many attempts" }
```

`code` is a 6-digit TOTP **or** a recovery code.

### 2.3 Native second factor (token-issuing)

```http
POST /api/auth/2fa/verify         { challenge, code }
200  { "token": "txs_…", "user": … }
```

Native clients (Tauri, SwiftUI, CLI) cannot use cookies and send no browser `Origin`.
Without this route there is **no path by which a native client can ever satisfy 2FA** —
which would mean either that native password login bypasses 2FA forever, or that it
breaks entirely at enforcement. Both are unacceptable.

### 2.4 Enrolment

```http
POST /api/auth/2fa/enroll         → 200 { secret, otpauthUri, expiresIn }
POST /api/auth/2fa/activate       { code } → 200 { recoveryCodes: string[] }
POST /api/auth/2fa/disable        { code, password? }
POST /api/settings/2fa/recovery-codes    → 200 { recoveryCodes: string[] }
```

- **Two-step by design.** `/enroll` creates a *pending* factor; only `/activate` with a
  valid code makes it live. Enrolling on a displayed secret alone locks out any user
  whose authenticator is mistyped or clock-skewed.
- The secret is returned **only** while pending, never re-displayed after activation.
  Pending enrolments are single-use and expire in 10 minutes.
- **`/activate` must mark the current session `mfaSatisfied: true` and rotate it.**
  Otherwise a user who just proved a code stays walled until they log out and back in.
- **`/enroll` requires fresh re-authentication when a factor is already active** (or is
  simply forbidden — disable first). Without this, an XSS in a logged-in tab silently
  swaps the victim's TOTP factor for one the attacker controls.
- **`/disable` accepts a fresh TOTP/recovery code *or* a password.** Password alone is
  not enough: every current web user signed in via GitHub SSO and has no password
  (`hasPassword` unset), so a password-only disable is unusable for the entire existing
  user base.
- **`/settings/2fa/recovery-codes` requires fresh re-authentication.** Recovery codes
  are 2FA-equivalent secrets; without re-auth an XSS can rotate them (locking the user
  out of their saved copies) and read the new ones.

### 2.5 Logout

```http
POST /api/auth/logout
200  Set-Cookie: __Host-txs=; Max-Age=0        + server-side session revocation
```

The cookie clear is not sufficient on its own — the session must be revoked server-side.

### 2.6 `/api/me` additions

```jsonc
{ …, "mfaEnabled": boolean, "mfaSatisfied": boolean, "recoveryCodesRemaining": number }
```

### 2.7 Legacy routes

`POST /api/auth/login` and `POST /api/auth/register` keep returning `{ token, user }`
**until native clients ship updates**. See [Rollout](#6-rollout) — changing their shape
early bricks every installed iOS/macOS and desktop app.

The clients in this repo now decode both shapes: `apple/Textory/Textory/Models.swift`
has `LoginResponse`, a sum type over `{ token, user }` and
`{ status: "mfa_required", challenge, expiresIn }`, and the shared web/desktop store
branches on the same distinction (`app/src/lib/stores.svelte.ts`). That closes the
*source* half of the constraint only. The sequencing in [Rollout](#6-rollout) still
holds, because what breaks at `MFA_MODE=required` is whatever build a user has
**installed** — landing this code is step 3's precondition, not step 3.

`/api/auth/register` is unchanged and still returns `{ token, user }` unconditionally:
a brand-new account has no factor, so there is nothing to challenge.

`/api/auth/register` creates an account with **no** TOTP factor, so there is nothing to
challenge. It must return a session that is `mfaSatisfied: false` and therefore walled
to the allowlist in §4, forcing enrolment as the account's first act.

---

## 3. Session and request security

### 3.1 Cookies

`__Host-txs` — `HttpOnly; Secure; SameSite=Strict; Path=/`, with an explicit lifetime
(absolute expiry *and* idle timeout).

The `__Host-` prefix makes the browser *enforce* `Secure`, `Path=/`, and the absence of
a `Domain` attribute, structurally preventing a subdomain from shadowing the session
cookie.

Web sessions must never receive a bearer token in a response body. An XSS on
`textory.dev` — where the app runs `marked`, `highlight.js` and `dompurify` over
snippet content — would otherwise exfiltrate a permanent credential. This is why
web-vs-native issuance is decided by **separate endpoints**, never by a field in the
request body: a body field is attacker-controlled, so an XSS would simply request the
token flavour.

### 3.2 CSRF

1. **Primary: validate `Origin` (with `Sec-Fetch-Site` as a secondary signal) on every
   mutating request that is authenticated by a cookie.**
   - Scope this to **cookie-authenticated requests only**. Native clients (Tauri's Rust
     HTTP plugin, `URLSession`, Go) send neither header, and requests authenticated by
     `x-textory-token` are CSRF-immune by construction — an attacker cannot set a custom
     header cross-origin.
   - Covers both `__Host-txs` and SWA `StaticWebAppsAuthCookie` sessions. This matters:
     Azure controls the `SameSite` attribute on its own auth cookie, so `SameSite` alone
     protects password sessions and does nothing for the GitHub-SSO sessions that are
     currently 100% of web users.
   - Verified: `Referrer-Policy: no-referrer` (shipped at
     `app/public/staticwebapp.config.json:5`) does **not** strip the `Origin` header from
     same-origin `fetch()` POSTs. The Fetch spec's null-origin downgrade applies only
     when request mode is not `"cors"`, and `fetch()` defaults to `"cors"`. Confirmed
     empirically in Chromium.
2. **`/api/*` must emit no `Access-Control-Allow-Origin`, and never
   `Access-Control-Allow-Credentials: true`.** Native clients are not CORS-bound, so the
   API needs no CORS headers at all. Reflective-origin-with-credentials would collapse
   the entire model.
3. Clients send a constant `x-textory-csrf: 1` header on cookie-authenticated mutations.
   A custom header cannot be set on a cross-origin request without a preflight, which a
   no-CORS API denies.
   *(A signed double-submit cookie was considered and rejected as redundant: the attack
   it defends — a related-domain attacker writing the cookie — is already structurally
   blocked by the `__Host-` prefix.)*
4. `SameSite=Strict` on `__Host-txs`. Free, and it does not break the SSO redirect:
   `/login` → `/.auth/login/github` → `/` is a top-level navigation onto the static
   shell, which needs no cookie; the SPA's subsequent same-site XHR carries it.

### 3.3 Credential precedence

The API will accept three credential sources: SWA's `x-ms-client-principal`,
`x-textory-token`, and the `__Host-txs` cookie.

**Do not blanket-reject requests carrying more than one.** A user who signed in via
GitHub SSO and later uses password login has *both* cookies attached by the browser
automatically, on every request — a blanket reject is an unrecoverable lockout with no
user-visible cause (and `/.auth/logout` is not reliably reachable, see §5).

Required precedence:

| Present | Behaviour |
|---|---|
| `__Host-txs` + `x-ms-client-principal` | `__Host-txs` wins; ignore the SWA principal |
| `x-textory-token` + either cookie | Reject — a browser should not be sending a bearer token |
| One source | Use it |

A successful `/api/auth/web/login` supersedes any existing SWA principal.

### 3.4 Brute force, replay, timing

- Per-challenge attempt cap (5), then the challenge is invalidated.
- Per-account and per-IP rate limits on `/auth/*/login` and both verify routes.
- Consumed `(userId, code, timeStep)` recorded and rejected on reuse.
- ±1 time step of drift only.
- Constant-time comparison for codes and CSRF values.
- The login challenge is single-use, ≤5 minutes, and accepted by the verify routes
  **only** — no other endpoint may accept it, and it is not a session.

### 3.5 Recovery codes

10 single-use codes, ≥128 bits of entropy each, shown exactly once.

Hash with **SHA-256, looked up by code prefix — not the password KDF.** Ten Argon2
evaluations per failed attempt is a CPU-amplification DoS against your own API, and
high-entropy random codes gain nothing from a slow KDF.

---

## 4. The MFA authorisation gate

This is the actual enforcement mechanism. Everything else is presentation.

A session whose account has no active TOTP factor is `mfaSatisfied: false` and is
authorised for **only**:

```
GET  /api/me
POST /api/signup
POST /api/auth/2fa/enroll
POST /api/auth/2fa/activate
POST /api/auth/logout
```

Every other route returns `403 { "error": "mfa required" }`.

`/api/signup` is in the allowlist deliberately: without it an unregistered password user
is trapped behind the MFA wall with no way to request access.

### Routes that mint 2FA-bypassing credentials

- **`POST /api/settings/password`** currently takes `{ username, password }` with **no
  current password**. Under cookie auth that is an account-takeover primitive: set a
  password on a GitHub-SSO account and own it permanently. Require re-authentication and
  invalidate all other sessions on change.
- **`POST /api/settings/cli-token`** mints a permanent bearer token that bypasses 2FA by
  design. Mintable only from an `mfaSatisfied` session, with re-authentication.
- **CLI tokens must be scoped** to snippet CRUD and `/api/me`, and rejected on all
  `/api/auth/*` and `/api/settings/*` routes, so a token leaked via shell history cannot
  touch account security.

---

## 5. Known defects in the current implementation

Fix alongside this work:

- **Web logout does not log you out.** `app/src/lib/commands.ts` navigates to `/logout`
  → `/.auth/logout`, which clears the SWA cookie only. A `__Host-txs` session survives:
  the user clicks sign out, lands on `/`, and is still authenticated for API calls. The
  client fix is in this repo; the server must honour §2.5.
- **`/api/settings/password` requires no current password** (§4).

---

## 6. Rollout

Azure Static Web Apps exposes **no AMR/MFA claim** in `x-ms-client-principal`, so the
API cannot verify whether a GitHub SSO session used 2FA. GitHub does not universally
require it. Therefore SSO sessions must be `mfaSatisfied: false`.

**Consequence: every existing user is force-enrolled into TOTP at their next login.**
This is the largest user-visible effect of this change.

1. **`mfa: "optional"`** — server support ships; Settings offers voluntary enrolment.
   No wall.
2. **Announce a date.** Unenrolled users see a dismissible banner.
3. **Ship native client updates** (Apple, desktop) that understand the challenge
   flow via §2.3, and give users time to install them. The CLI needs no update: it
   authenticates with a `txt_` token and never posts a password, and CLI tokens are
   exempt from the gate by design (§4).
4. **`mfa: "required"`** — the wall becomes blocking, and legacy `/api/auth/login` may
   start returning challenges.

Step 4 before step 3 breaks password login on iOS, macOS, and desktop.

---

## 7. Deliberately out of scope

- **"Remember this device"** — a second long-lived credential and a second bypass path.
- **WebAuthn / passkeys** — phishing-resistant and strictly better than TOTP, but a much
  larger change. Worth doing next.
- **SMS / email OTP** — phishable and SIM-swappable. Rejected, not deferred.
