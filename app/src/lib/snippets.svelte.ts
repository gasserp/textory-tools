import { apiFetch } from "./api";
import { loadSession } from "./stores.svelte";

export type SnippetDoc = {
  id: string;
  userId: string;
  title: string;
  content: string;
  contentBytes: number;
  category?: string;
  tags: string[];
  summary?: string;
  createdAt: string;
  updatedAt: string;
};

export type SnippetInput = { title: string; content: string; tags?: string[] };

export const snippetsState = $state<{ items: SnippetDoc[]; loaded: boolean }>({
  items: [],
  loaded: false,
});

export async function loadSnippets(): Promise<void> {
  snippetsState.items = await apiFetch<SnippetDoc[]>("/snippets");
  snippetsState.loaded = true;
}

export async function createSnippet(input: SnippetInput): Promise<SnippetDoc> {
  const created = await apiFetch<SnippetDoc>("/snippets", {
    method: "POST",
    body: JSON.stringify(input),
  });
  snippetsState.items = [created, ...snippetsState.items];
  await loadSession();
  return created;
}

export async function updateSnippet(id: string, input: SnippetInput): Promise<SnippetDoc> {
  const updated = await apiFetch<SnippetDoc>(`/snippets/${id}`, {
    method: "PUT",
    body: JSON.stringify(input),
  });
  snippetsState.items = snippetsState.items.map((s) => (s.id === id ? updated : s));
  await loadSession();
  return updated;
}

export async function deleteSnippet(id: string): Promise<void> {
  await apiFetch<void>(`/snippets/${id}`, { method: "DELETE" });
  snippetsState.items = snippetsState.items.filter((s) => s.id !== id);
  await loadSession();
}

export function getSnippet(id: string): SnippetDoc | undefined {
  return snippetsState.items.find((s) => s.id === id);
}

export async function classifySnippet(id: string, overwriteTags = false): Promise<SnippetDoc> {
  const updated = await apiFetch<SnippetDoc>(`/snippets/${id}/classify`, {
    method: "POST",
    body: JSON.stringify({ overwriteTags }),
  });
  snippetsState.items = snippetsState.items.map((s) => (s.id === id ? updated : s));
  return updated;
}
