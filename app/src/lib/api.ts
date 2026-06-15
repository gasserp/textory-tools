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

export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (isNative) {
      const token = getToken();
      if (token) headers["x-textory-token"] = token;
    }
    res = await doFetch(`${apiBase}/api${path}`, {
      ...init,
      headers: { ...headers, ...init?.headers },
    });
  } catch (e) {
    showToast("✗ offline?");
    throw e;
  }

  const body = await res.json().catch(() => undefined);
  if (!res.ok) {
    if (res.status === 401 || res.status === 403) onAuthError?.(res.status, body?.error);
    throw new Error(body?.error ?? res.statusText);
  }
  return body as T;
}
