import { apiFetch, setAuthErrorHandler } from "./api";
import { clearToken, isNative, setToken } from "./runtime";
import { currentCapabilities, loadCapabilities, resetCapabilities } from "./capabilities";
import type { ReauthPayload } from "./reauth";

export type UserStatus = "pending" | "approved" | "rejected";

export type MeUser = {
  id: string;
  githubLogin: string;
  status: UserStatus;
  role: "user" | "admin";
  quotaBytes: number;
  usedBytes: number;
  plan: "beta";
  hasAnthropicKey: boolean;
  hasPassword?: boolean;
  autoClassify?: boolean;
  createdAt: string;
  termsAcceptedAt?: string;
  termsVersion?: string;
  cliTokenCreatedAt?: string | null;
  mfaEnabled?: boolean;
  /** Whether *this session* has satisfied 2FA. Absent on servers without 2FA support. */
  mfaSatisfied?: boolean;
  recoveryCodesRemaining?: number;
};

type MeResponse = { status: "unregistered" } | MeUser;

export type SessionStatus =
  | "loading"
  | "anonymous"
  /** Password accepted, awaiting the second factor. Not a session. */
  | "mfa_challenge"
  /** Signed in but 2FA is required and not yet set up — the app is walled off. */
  | "mfa_enrollment"
  | "unregistered"
  | UserStatus;

export const session = $state<{ status: SessionStatus; user: MeUser | null }>({
  status: "loading",
  user: null,
});

/**
 * Derive the session status, applying the 2FA wall.
 *
 * Fail-closed *relative to a server that has declared 2FA required*: if the server says
 * `mfa: "required"` then anything other than an explicit `mfaSatisfied === true` walls
 * the user, so an absent or malformed field can't open the gate. When the server hasn't
 * declared 2FA required, this is a no-op — a strict check there would wall every user
 * the moment this merges, against a backend that has no enrolment endpoints yet.
 */
function statusFor(me: MeUser): SessionStatus {
  const mfaRequired = currentCapabilities().mfa === "required";
  if (mfaRequired && me.mfaSatisfied !== true) return "mfa_enrollment";
  return me.status;
}

setAuthErrorHandler((status, error) => {
  if (status === 401) {
    session.status = "anonymous";
    session.user = null;
  } else if (status === 403 && error === "pending approval") {
    session.status = "pending";
  } else if (status === 403 && error === "rejected") {
    session.status = "rejected";
  } else if (status === 403 && error === "mfa required") {
    // The server flipped to enforcing while this tab was open. Without this the app
    // would just spray 403 toasts over a screen the user can no longer use.
    session.status = "mfa_enrollment";
    // `session.user` is from before the flip, so `mfaEnabled` may be stale and decide
    // the wrong wall — enrolment for someone who already has a factor is a dead end.
    // /me is on the server's allowlist, so this cannot 403 back into here.
    void refreshUser();
  }
});

let refreshingUser = false;

/** Re-reads /me without touching session.status. Guarded against re-entry. */
async function refreshUser(): Promise<void> {
  if (refreshingUser) return;
  refreshingUser = true;
  try {
    const me = await apiFetch<MeResponse>("/me", { skipAuthHandler: true });
    if (me.status !== "unregistered") session.user = me;
  } catch {
    // Best-effort: the wall is already up, and a failed refresh just leaves the
    // status quo rather than making things worse.
  } finally {
    refreshingUser = false;
  }
}

export async function loadSession(): Promise<void> {
  await loadCapabilities();
  try {
    const me = await apiFetch<MeResponse>("/me");
    if (me.status === "unregistered") {
      session.status = "unregistered";
      session.user = null;
    } else {
      session.status = statusFor(me);
      session.user = me;
    }
  } catch {
    session.status = "anonymous";
    session.user = null;
  }
}

type AuthResponse = { token: string; user: MeUser };
type ChallengeResponse = { status: "mfa_required"; challenge: string; expiresIn: number };

/**
 * The pending 2FA challenge. Module-local rather than in `session` only for hygiene —
 * it is not a security boundary (same heap, equally reachable from XSS). What makes the
 * challenge safe is server-side: single-use, <=5 min, and accepted by the verify routes
 * and nothing else.
 */
let pendingChallenge: string | undefined;

export function clearChallenge(): void {
  pendingChallenge = undefined;
}

function applyAuth(token: string, user: MeUser): void {
  setToken(token);
  session.status = statusFor(user);
  session.user = user;
}

/**
 * Step 1 of login: verify the password. Deliberately does not produce a session — the
 * server returns only a short-lived challenge. If this returned a usable session, 2FA
 * would be decorative: anyone with the password could just skip the second call.
 */
export async function passwordLogin(username: string, password: string): Promise<void> {
  const path = isNative ? "/auth/login" : "/auth/web/login";
  const response = await apiFetch<ChallengeResponse | AuthResponse>(path, {
    method: "POST",
    body: JSON.stringify({ username, password }),
    skipAuthHandler: true,
  });

  if ("challenge" in response) {
    pendingChallenge = response.challenge;
    session.status = "mfa_challenge";
    session.user = null;
    return;
  }

  // Legacy server without 2FA (native only — the web login route is cookie-only and
  // never returns a token).
  applyAuth(response.token, response.user);
}

/** Step 2 of login: the second factor. `code` is a TOTP code or a recovery code. */
export async function verifyTwoFactor(code: string): Promise<void> {
  if (!pendingChallenge) throw new Error("challenge expired");
  const path = isNative ? "/auth/2fa/verify" : "/auth/web/2fa/verify";
  const response = await apiFetch<AuthResponse | { user: MeUser }>(path, {
    method: "POST",
    body: JSON.stringify({ challenge: pendingChallenge, code }),
    skipAuthHandler: true,
  });
  pendingChallenge = undefined;

  if ("token" in response) {
    applyAuth(response.token, response.user);
  } else {
    // Web: the session is an HttpOnly cookie, nothing to store.
    session.status = statusFor(response.user);
    session.user = response.user;
  }
}

/**
 * Native-only (see Login.svelte). A new account has no second factor yet, so there is
 * nothing to challenge — `applyAuth` routes it straight into the enrolment wall when
 * the server requires 2FA.
 */
export async function passwordRegister(username: string, password: string): Promise<void> {
  const { token, user } = await apiFetch<AuthResponse>("/auth/register", {
    method: "POST",
    body: JSON.stringify({ username, password, acceptTerms: true }),
    skipAuthHandler: true,
  });
  applyAuth(token, user);
}

export type EnrollResponse = { secret: string; otpauthUri: string; expiresIn: number };

export async function enrollTwoFactor(): Promise<EnrollResponse> {
  return apiFetch<EnrollResponse>("/auth/2fa/enroll", { method: "POST" });
}

/**
 * Confirm enrolment with a live code. The server activates the factor, marks this
 * session `mfaSatisfied` and rotates it, so the user is let through without re-login.
 */
export async function activateTwoFactor(code: string): Promise<string[]> {
  const { recoveryCodes } = await apiFetch<{ recoveryCodes: string[] }>("/auth/2fa/activate", {
    method: "POST",
    body: JSON.stringify({ code }),
    skipAuthHandler: true,
  });
  if (session.user) {
    session.user.mfaEnabled = true;
    session.user.mfaSatisfied = true;
    session.user.recoveryCodesRemaining = recoveryCodes.length;
  }
  // `session.status` is deliberately NOT updated here. Lifting the wall now would
  // unmount the enrolment component and the user would never see the recovery codes
  // below — locking them out for good if they later lose their authenticator. The
  // caller lifts it via completeMfaEnrollment() once the codes are acknowledged.
  return recoveryCodes;
}

/** Lift the 2FA wall after the user confirms they've saved their recovery codes. */
export function completeMfaEnrollment(): void {
  if (session.user) session.status = statusFor(session.user);
}

/**
 * Prove a second factor for a session that already authenticated some other way.
 *
 * GitHub SSO is the case this exists for: Azure exposes no MFA claim, so an SSO
 * session is never `mfaSatisfied` and the enrolment routes are the only ones open to
 * it. A user who already enrolled would be walled forever with nothing to click —
 * `/auth/2fa/enroll` refuses while a factor is active. Here the SSO session is the
 * first factor and the code is the second; the server replies with a cookie session
 * that supersedes the SWA principal.
 */
export async function stepUpTwoFactor(code: string): Promise<void> {
  const { user } = await apiFetch<{ user: MeUser }>("/auth/web/2fa/step-up", {
    method: "POST",
    body: JSON.stringify({ code }),
    skipAuthHandler: true,
  });
  session.status = statusFor(user);
  session.user = user;
}

/**
 * Step 1 of moving to a new authenticator: prove the *current* factor, get a new
 * pending secret. The existing factor keeps working until step 2 lands, so a mistyped
 * key or a clock-skewed phone is recoverable rather than a lockout.
 */
export async function replaceTwoFactor(code: string): Promise<EnrollResponse> {
  return apiFetch<EnrollResponse>("/auth/2fa/replace", {
    method: "POST",
    body: JSON.stringify({ code }),
    skipAuthHandler: true,
  });
}

/** Step 2: prove the *new* factor. Swaps it in and invalidates every other session. */
export async function activateReplacement(code: string): Promise<string[]> {
  const { recoveryCodes } = await apiFetch<{ recoveryCodes: string[] }>(
    "/auth/2fa/replace/activate",
    { method: "POST", body: JSON.stringify({ code }), skipAuthHandler: true },
  );
  if (session.user) {
    session.user.mfaEnabled = true;
    session.user.mfaSatisfied = true;
    session.user.recoveryCodesRemaining = recoveryCodes.length;
  }
  return recoveryCodes;
}

/** Re-auth is a fresh code, or a password for accounts that have one. */
export async function disableTwoFactor(code: string, password?: string): Promise<void> {
  await apiFetch<{ ok: true }>("/auth/2fa/disable", {
    method: "POST",
    body: JSON.stringify(password ? { code, password } : { code }),
    skipAuthHandler: true,
  });
  if (session.user) {
    session.user.mfaEnabled = false;
    session.user.recoveryCodesRemaining = 0;
  }
}

export async function regenerateRecoveryCodes(code: string): Promise<string[]> {
  const { recoveryCodes } = await apiFetch<{ recoveryCodes: string[] }>(
    "/settings/2fa/recovery-codes",
    { method: "POST", body: JSON.stringify({ code }), skipAuthHandler: true },
  );
  if (session.user) session.user.recoveryCodesRemaining = recoveryCodes.length;
  return recoveryCodes;
}

export async function logout(): Promise<void> {
  try {
    await apiFetch<{ ok: true }>("/auth/logout", { method: "POST" });
  } catch {
    // best-effort
  }
  clearToken();
  clearChallenge();
  resetCapabilities();
  session.status = "anonymous";
  session.user = null;
}

export async function requestAccess(): Promise<void> {
  const me = await apiFetch<MeUser>("/signup", {
    method: "POST",
    body: JSON.stringify({ acceptTerms: true }),
  });
  session.status = me.status;
  session.user = me;
}

export async function saveAnthropicKey(key: string): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/anthropic-key", {
    method: "PUT",
    body: JSON.stringify({ key }),
  });
  if (session.user) session.user.hasAnthropicKey = true;
}

export async function deleteAnthropicKey(): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/anthropic-key", { method: "DELETE" });
  if (session.user) session.user.hasAnthropicKey = false;
}

export async function setAutoClassify(enabled: boolean): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/auto-classify", {
    method: "PUT",
    body: JSON.stringify({ enabled }),
  });
  if (session.user) session.user.autoClassify = enabled;
}

export type CliTokenResponse = {
  token: string;
  createdAt: string;
};

/**
 * A CLI token bypasses 2FA by design, so the server only mints one from a session
 * that has satisfied a second factor, and only with fresh re-authentication.
 */
export async function generateCliToken(reauth: ReauthPayload): Promise<CliTokenResponse> {
  const response = await apiFetch<CliTokenResponse>("/settings/cli-token", {
    method: "POST",
    body: JSON.stringify(reauth),
    skipAuthHandler: true,
  });
  if (session.user) session.user.cliTokenCreatedAt = response.createdAt;
  return response;
}

export async function regenerateCliToken(reauth: ReauthPayload): Promise<CliTokenResponse> {
  return generateCliToken(reauth);
}

export async function revokeCliToken(): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/cli-token", { method: "DELETE" });
  if (session.user) session.user.cliTokenCreatedAt = null;
}

/**
 * Set or change the account password.
 *
 * The re-auth password is sent as `currentPassword`: `password` is already taken by
 * the new value, and conflating the two would let the new password authorise its own
 * change.
 *
 * Changing the password invalidates every other session, so anything else signed in
 * as this user is signed out.
 */
export async function setPassword(
  username: string,
  password: string,
  reauth: ReauthPayload,
): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/password", {
    method: "PUT",
    body: JSON.stringify({
      username,
      password,
      ...(reauth.code !== undefined ? { code: reauth.code } : {}),
      ...(reauth.password !== undefined ? { currentPassword: reauth.password } : {}),
    }),
    skipAuthHandler: true,
  });
  if (session.user) session.user.hasPassword = true;
}

export async function clearPassword(reauth: ReauthPayload): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/password", {
    method: "DELETE",
    body: JSON.stringify(reauth),
    skipAuthHandler: true,
  });
  if (session.user) session.user.hasPassword = false;
}
