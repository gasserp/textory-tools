import type { MeUser } from "./stores.svelte";

/**
 * What the server will accept as proof of identity for a credential change.
 *
 * The API's rule (docs/AUTH_CONTRACT.md §4, `requireFreshAuth`) is: an authenticator
 * or recovery code when a factor is active, otherwise the current password when one is
 * set, otherwise nothing — a GitHub-SSO account with neither has no second thing to
 * prove, and the SWA session it already presented is the only credential there is.
 *
 * Never password-only when a factor is active: that is what stops an XSS in a
 * logged-in tab from quietly swapping the victim's factor for the attacker's.
 */
export type ReauthKind = "code" | "password" | "none";

export type ReauthPayload = { code?: string; password?: string };

export function reauthKind(user: MeUser | null): ReauthKind {
  if (user?.mfaEnabled) return "code";
  if (user?.hasPassword) return "password";
  return "none";
}

/** Whether the user has to type something before an action can proceed. */
export function reauthRequired(user: MeUser | null): boolean {
  return reauthKind(user) !== "none";
}

/**
 * Builds the request body fragment for a re-auth challenge.
 *
 * Codes are stripped of whitespace because authenticator apps render them as
 * "123 456" and people paste what they see. Passwords are passed through untouched —
 * leading or trailing spaces are legitimate password characters.
 */
export function reauthPayload(kind: ReauthKind, value: string): ReauthPayload {
  if (kind === "code") return { code: value.replace(/\s/g, "") };
  if (kind === "password") return { password: value };
  return {};
}

export function reauthLabel(kind: ReauthKind): string {
  return kind === "code" ? "authenticator or recovery code" : "current password";
}
