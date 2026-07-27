import { fetch as tauriFetch } from "@tauri-apps/plugin-http";
import { showToast } from "./toast.svelte";
import { apiBase, getToken, isNative } from "./runtime";

/** Native builds use the Tauri HTTP plugin (request runs in Rust, not subject to webview CORS). */
const doFetch: typeof fetch = isNative ? tauriFetch : fetch;

type AuthErrorHandler = (status: 401 | 403, error?: string) => void;

let onAuthError: AuthErrorHandler | undefined;

/** Registered by stores.svelte.ts to flip session state without a circular import. */
export function setAuthErrorHandler(handler: AuthErrorHandler): void {
  onAuthError = handler;
}

export type ApiInit = RequestInit & {
  /**
   * Skip the global auth-error handler for this request.
   *
   * The handler maps 401 to `session.status = "anonymous"`. That is right for ordinary
   * API calls but wrong for the auth endpoints themselves: a mistyped TOTP digit
   * returns 401 from the 2FA verify routes, and letting it through would wipe the
   * session, tear down the challenge UI and drop the in-memory challenge — restarting
   * the whole login over one wrong digit.
   */
  skipAuthHandler?: boolean;
};

export async function apiFetch<T>(path: string, init?: ApiInit): Promise<T> {
  const { skipAuthHandler, ...requestInit } = init ?? {};
  let res: Response;
  try {
    // Callers may override Content-Type, but not the credential/CSRF headers below —
    // hence the spread of caller headers *first*.
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...(requestInit.headers as Record<string, string> | undefined),
    };
    if (isNative) {
      const token = getToken();
      if (token) headers["x-textory-token"] = token;
    } else {
      // Browser sessions are cookie-authenticated, so they need CSRF protection. A
      // custom header can't be set cross-origin without a preflight, which the API
      // (which sends no CORS headers) denies. The server also validates Origin.
      headers["x-textory-csrf"] = "1";
    }
    res = await doFetch(`${apiBase}/api${path}`, { ...requestInit, headers });
  } catch (e) {
    showToast("✗ offline?");
    throw e;
  }

  const body = await res.json().catch(() => undefined);
  if (!res.ok) {
    if ((res.status === 401 || res.status === 403) && !skipAuthHandler) {
      onAuthError?.(res.status, body?.error);
    }
    throw new Error(body?.error ?? res.statusText);
  }
  return body as T;
}
