<script lang="ts">
  import { onMount } from "svelte";
  import { snippetsState, deleteSnippet, type SnippetDoc } from "../lib/snippets.svelte";
  import { session } from "../lib/stores.svelte";
  import { registerKey, isTextInput } from "../lib/keys";
  import { viewState, showView, showEdit, showNew, showNewWithContent } from "../lib/view.svelte";
  import { copyPlain, copyRich } from "../lib/clipboard";
  import { searchState, focusSearch } from "../lib/search.svelte";
  import { searchSnippets } from "../lib/search";
  import Search from "./Search.svelte";

  const items = $derived(searchState.query.trim() === "" ? snippetsState.items : searchSnippets(searchState.query));

  let selected = $state(0);
  let confirmDeleteId = $state<string | null>(null);
  let confirmDeleteMulti = $state(false);
  let markedIds = $state<Set<string>>(new Set());
  let listEl: HTMLDivElement | undefined = $state();

  $effect(() => {
    if (selected > items.length - 1) selected = Math.max(0, items.length - 1);
  });

  $effect(() => {
    void searchState.query;
    selected = 0;
  });

  function current(): SnippetDoc | undefined {
    return items[selected];
  }

  function moveSelection(delta: number): void {
    if (items.length === 0) return;
    selected = Math.min(Math.max(0, selected + delta), items.length - 1);
  }

  function select(i: number): void {
    selected = i;
  }

  function toggleMark(): void {
    const item = current();
    if (!item) return;
    const next = new Set(markedIds);
    if (next.has(item.id)) next.delete(item.id);
    else next.add(item.id);
    markedIds = next;
  }

  function startDelete(): void {
    if (markedIds.size > 0) confirmDeleteMulti = true;
    else if (current()) confirmDeleteId = current()!.id;
  }

  function cancelDelete(): void {
    confirmDeleteId = null;
    confirmDeleteMulti = false;
  }

  async function confirmDelete(): Promise<void> {
    if (confirmDeleteMulti) {
      const ids = Array.from(markedIds);
      confirmDeleteMulti = false;
      markedIds = new Set();
      await Promise.all(ids.map((id) => deleteSnippet(id)));
      return;
    }
    if (!confirmDeleteId) return;
    const id = confirmDeleteId;
    confirmDeleteId = null;
    await deleteSnippet(id);
    if (markedIds.has(id)) {
      const next = new Set(markedIds);
      next.delete(id);
      markedIds = next;
    }
  }

  function onPaste(e: ClipboardEvent): void {
    if (viewState.mode !== "list" || confirmDeleteId || confirmDeleteMulti) return;
    if (isTextInput(e.target)) return;
    const text = e.clipboardData?.getData("text");
    if (!text) return;
    e.preventDefault();
    showNewWithContent(text);
  }

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleString();
  }

  function formatQuota(used: number, quota: number): string {
    const barLen = 10;
    const filled = quota > 0 ? Math.min(barLen, Math.round((used / quota) * barLen)) : 0;
    const bar = "▓".repeat(filled) + "░".repeat(barLen - filled);
    const usedKb = Math.round(used / 1024);
    const quotaKb = Math.round(quota / 1024);
    return `${bar} ${usedKb}/${quotaKb} KB`;
  }

  onMount(() => {
    const active = () => viewState.mode === "list" && !confirmDeleteId && !confirmDeleteMulti;
    const confirming = () => viewState.mode === "list" && (!!confirmDeleteId || confirmDeleteMulti);
    const unregisters = [
      registerKey({ key: "/", when: active, run: focusSearch }),
      registerKey({ key: "j", when: active, run: () => moveSelection(1) }),
      registerKey({ key: "ArrowDown", when: active, run: () => moveSelection(1) }),
      registerKey({ key: "k", when: active, run: () => moveSelection(-1) }),
      registerKey({ key: "ArrowUp", when: active, run: () => moveSelection(-1) }),
      registerKey({ key: "Enter", when: () => active() && !!current(), run: () => showView(current()!.id) }),
      registerKey({ key: "n", when: active, run: showNew }),
      registerKey({ key: "e", when: () => active() && !!current(), run: () => showEdit(current()!.id) }),
      registerKey({ key: " ", when: () => active() && !!current(), run: toggleMark }),
      registerKey({ key: "d", when: () => active() && (!!current() || markedIds.size > 0), run: startDelete }),
      registerKey({ key: "c", when: () => active() && !!current(), run: () => copyPlain(current()!.content) }),
      registerKey({ key: "c", shift: true, when: () => active() && !!current(), run: () => copyRich(current()!.content) }),
      registerKey({ key: "y", when: confirming, run: confirmDelete }),
      registerKey({ key: "n", when: confirming, run: cancelDelete }),
      registerKey({ key: "Escape", when: confirming, run: cancelDelete }),
    ];
    window.addEventListener("paste", onPaste);
    return () => {
      window.removeEventListener("paste", onPaste);
      unregisters.forEach((unregister) => unregister());
    };
  });
</script>

<Search
  onEnter={() => current() && showView(current()!.id)}
  onClear={() => listEl?.focus()}
/>

{#if confirmDeleteMulti}
  <div class="confirm-bar">delete {markedIds.size} selected snippet{markedIds.size === 1 ? "" : "s"}? [y/n]</div>
{/if}

<!-- svelte-ignore a11y_no_noninteractive_tabindex -->
<div class="snippet-list" bind:this={listEl} tabindex="-1" role="listbox" aria-label="Snippets">
  {#each items as item, i (item.id)}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="row"
      class:selected={i === selected}
      class:marked={markedIds.has(item.id)}
      role="option"
      aria-selected={i === selected}
      tabindex="-1"
      onclick={() => select(i)}
      ondblclick={() => showView(item.id)}
    >
      <div class="row-main">
        <span class="mark">{markedIds.has(item.id) ? "[x]" : "[ ]"}</span>
        <span class="title">{item.title}</span>
        {#if item.tags.length}
          <span class="tags">{item.tags.map((t) => `#${t}`).join(" ")}</span>
        {/if}
        {#if item.category}<span class="category">[{item.category}]</span>{/if}
        <span class="updated">{formatDate(item.updatedAt)}</span>
      </div>
      {#if item.summary}
        <div class="summary">{item.summary}</div>
      {/if}
      {#if confirmDeleteId === item.id}
        <div class="confirm">delete "{item.title}"? [y/n]</div>
      {/if}
    </div>
  {:else}
    <div class="empty">
      {#if searchState.query.trim() !== ""}
        no matches
      {:else}
        no snippets yet — press <kbd>n</kbd> to create one, or paste text
      {/if}
    </div>
  {/each}
</div>

{#if session.user}
  <div class="quota">{formatQuota(session.user.usedBytes, session.user.quotaBytes)}</div>
{/if}

<style>
  .snippet-list {
    display: flex;
    flex-direction: column;
  }

  .row {
    padding: var(--sp-1) var(--sp-2);
    border-bottom: 1px dotted var(--border);
    cursor: pointer;
  }

  .row.selected {
    background: var(--bg-raised);
    border-left: 2px solid var(--accent);
  }

  .mark {
    flex-shrink: 0;
    color: var(--fg-dim);
  }

  .row.marked .mark {
    color: var(--accent);
  }

  .row-main {
    display: flex;
    align-items: baseline;
    gap: var(--sp-2);
    overflow: hidden;
  }

  .title {
    flex-shrink: 0;
  }

  .tags,
  .category {
    color: var(--accent);
    flex-shrink: 0;
  }

  .updated {
    margin-left: auto;
    color: var(--fg-dim);
    font-size: 0.85em;
    flex-shrink: 0;
  }

  .summary {
    color: var(--fg-dim);
    font-size: 0.85em;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .confirm {
    color: var(--danger);
    font-size: 0.85em;
  }

  .confirm-bar {
    color: var(--danger);
    font-size: 0.85em;
    padding: var(--sp-1) var(--sp-2);
    border-bottom: 1px dotted var(--border);
  }

  .empty {
    color: var(--fg-dim);
    padding: var(--sp-2);
  }

  .quota {
    margin-top: var(--sp-3);
    color: var(--fg-dim);
    font-size: 0.85em;
  }
</style>
