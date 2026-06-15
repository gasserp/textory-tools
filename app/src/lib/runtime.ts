const TOKEN_KEY = "textory_token";

declare global {
  interface Window {
    __TAURI__?: unknown;
  }
}

/** True when running inside the native (Tauri) wrapper, or forced via VITE_NATIVE=1 for dev/testing. */
export const isNative: boolean =
  import.meta.env.VITE_NATIVE === "1" || (typeof window !== "undefined" && "__TAURI__" in window);

/** Base URL prefixed to API paths. Browser mode uses relative `/api` (same-origin, cookie auth). */
export const apiBase: string = isNative ? (import.meta.env.VITE_API_BASE ?? "") : "";

function hasLocalStorage(): boolean {
  try {
    return typeof localStorage !== "undefined";
  } catch {
    return false;
  }
}

export function getToken(): string | null {
  if (!hasLocalStorage()) return null;
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setToken(token: string): void {
  if (!hasLocalStorage()) return;
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    // ignore
  }
}

export function clearToken(): void {
  if (!hasLocalStorage()) return;
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {
    // ignore
  }
}
