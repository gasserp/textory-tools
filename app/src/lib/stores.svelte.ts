import { apiFetch, setAuthErrorHandler } from "./api";
import { clearToken, setToken } from "./runtime";

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
};

type MeResponse = { status: "unregistered" } | MeUser;

export type SessionStatus = "loading" | "anonymous" | "unregistered" | UserStatus;

export const session = $state<{ status: SessionStatus; user: MeUser | null }>({
  status: "loading",
  user: null,
});

setAuthErrorHandler((status, error) => {
  if (status === 401) {
    session.status = "anonymous";
    session.user = null;
  } else if (status === 403 && error === "pending approval") {
    session.status = "pending";
  } else if (status === 403 && error === "rejected") {
    session.status = "rejected";
  }
});

export async function loadSession(): Promise<void> {
  try {
    const me = await apiFetch<MeResponse>("/me");
    if (me.status === "unregistered") {
      session.status = "unregistered";
      session.user = null;
    } else {
      session.status = me.status;
      session.user = me;
    }
  } catch {
    session.status = "anonymous";
    session.user = null;
  }
}

type AuthResponse = { token: string; user: MeUser };

export async function passwordLogin(username: string, password: string): Promise<void> {
  const { token, user } = await apiFetch<AuthResponse>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ username, password }),
  });
  setToken(token);
  session.status = user.status;
  session.user = user;
}

export async function passwordRegister(username: string, password: string): Promise<void> {
  const { token, user } = await apiFetch<AuthResponse>("/auth/register", {
    method: "POST",
    body: JSON.stringify({ username, password, acceptTerms: true }),
  });
  setToken(token);
  session.status = user.status;
  session.user = user;
}

export async function logout(): Promise<void> {
  try {
    await apiFetch<{ ok: true }>("/auth/logout", { method: "POST" });
  } catch {
    // best-effort
  }
  clearToken();
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

export async function generateCliToken(): Promise<CliTokenResponse> {
  const response = await apiFetch<CliTokenResponse>("/settings/cli-token", {
    method: "POST",
  });
  if (session.user) session.user.cliTokenCreatedAt = response.createdAt;
  return response;
}

export async function regenerateCliToken(): Promise<CliTokenResponse> {
  const response = await apiFetch<CliTokenResponse>("/settings/cli-token", {
    method: "POST",
  });
  if (session.user) session.user.cliTokenCreatedAt = response.createdAt;
  return response;
}

export async function revokeCliToken(): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/cli-token", { method: "DELETE" });
  if (session.user) session.user.cliTokenCreatedAt = null;
}

export async function setPassword(username: string, password: string): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/password", {
    method: "PUT",
    body: JSON.stringify({ username, password }),
  });
  if (session.user) session.user.hasPassword = true;
}

export async function clearPassword(): Promise<void> {
  await apiFetch<{ ok: true }>("/settings/password", { method: "DELETE" });
  if (session.user) session.user.hasPassword = false;
}
