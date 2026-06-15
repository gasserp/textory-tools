import { apiFetch } from "./api";
import type { UserStatus } from "./stores.svelte";

export type AdminUser = {
  id: string;
  githubLogin: string;
  status: UserStatus;
  role: "user" | "admin";
  quotaBytes: number;
  usedBytes: number;
  plan: "beta";
  createdAt: string;
};

export const adminState = $state<{ users: AdminUser[]; loaded: boolean }>({
  users: [],
  loaded: false,
});

export async function loadAdminUsers(): Promise<void> {
  adminState.users = await apiFetch<AdminUser[]>("/manage/users");
  adminState.loaded = true;
}

export async function setUserStatus(id: string, status: "approved" | "rejected"): Promise<void> {
  const updated = await apiFetch<AdminUser>(`/manage/users/${id}`, {
    method: "PUT",
    body: JSON.stringify({ status }),
  });
  adminState.users = adminState.users.map((u) => (u.id === id ? updated : u));
}

export async function setUserQuota(id: string, quotaBytes: number): Promise<void> {
  const updated = await apiFetch<AdminUser>(`/manage/users/${id}`, {
    method: "PUT",
    body: JSON.stringify({ quotaBytes }),
  });
  adminState.users = adminState.users.map((u) => (u.id === id ? updated : u));
}
