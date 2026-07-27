import { apiFetch } from "./api";

export type MfaMode = "unsupported" | "optional" | "required";

export type Capabilities = {
  /** Whether the API can issue a cookie session from username/password on the web. */
  webPasswordLogin: boolean;
  mfa: MfaMode;
};

/**
 * What we assume when the server hasn't told us otherwise: today's behaviour exactly.
 * No password form, no 2FA wall.
 */
const UNSUPPORTED: Capabilities = { webPasswordLogin: false, mfa: "unsupported" };

let cached: Capabilities | undefined;

function isMfaMode(value: unknown): value is MfaMode {
  return value === "unsupported" || value === "optional" || value === "required";
}

/**
 * Ask the API what auth features it supports.
 *
 * The 2FA enforcement gate lives in the backend (see docs/AUTH_CONTRACT.md); this only
 * decides whether the *UI* appears. Rendering a 2FA wall against a server that still
 * serves every session to anyone would be worse than shipping nothing — it looks like
 * protection that isn't there. So a server that doesn't answer gets today's UI.
 *
 * Only successful responses are cached: caching an error would latch "unsupported" for
 * the life of the page, leaving a walled user staring at raw 403s instead of the
 * enrolment screen.
 */
export async function loadCapabilities(): Promise<Capabilities> {
  if (cached) return cached;
  try {
    const body = await apiFetch<Partial<Capabilities>>("/auth/capabilities", {
      skipAuthHandler: true,
    });
    cached = {
      webPasswordLogin: body?.webPasswordLogin === true,
      mfa: isMfaMode(body?.mfa) ? body.mfa : "unsupported",
    };
    return cached;
  } catch {
    return UNSUPPORTED;
  }
}

/** Last known capabilities, without triggering a fetch. */
export function currentCapabilities(): Capabilities {
  return cached ?? UNSUPPORTED;
}

/** Test seam / logout reset. */
export function resetCapabilities(): void {
  cached = undefined;
}
