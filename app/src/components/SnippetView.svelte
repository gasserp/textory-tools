<script lang="ts">
  import { onMount } from "svelte";
  import { getSnippet } from "../lib/snippets.svelte";
  import { viewState, showList, showEdit } from "../lib/view.svelte";
  import { render } from "../lib/markdown";
  import { copyPlain, copyRich } from "../lib/clipboard";
  import { registerKey } from "../lib/keys";
  import { session } from "../lib/stores.svelte";
  import { classifyState, runClassify } from "../lib/classify.svelte";

  const snippet = $derived(viewState.selectedId ? getSnippet(viewState.selectedId) : undefined);
  const html = $derived(snippet ? render(snippet.content) : "");
  const hasKey = $derived(session.user?.hasAnthropicKey ?? false);
  const classifying = $derived(!!snippet && classifyState.inFlightId === snippet.id);

  onMount(() => {
    const active = () => viewState.mode === "view" && !!snippet;
    const unregisters = [
      registerKey({ key: "Escape", when: () => viewState.mode === "view", run: showList }),
      registerKey({ key: "e", when: active, run: () => showEdit(snippet!.id) }),
      registerKey({ key: "c", when: active, run: () => copyPlain(snippet!.content) }),
      registerKey({ key: "c", shift: true, when: active, run: () => copyRich(snippet!.content) }),
    ];
    return () => unregisters.forEach((unregister) => unregister());
  });
</script>

{#if snippet}
  <div class="snippet-view">
    <div class="header">
      <h1>{snippet.title}</h1>
      <div class="actions">
        <button onclick={() => copyRich(snippet.content)}>[ copy ]</button>
        <button onclick={() => copyPlain(snippet.content)}>[ copy raw ]</button>
        <button onclick={() => showEdit(snippet.id)}>[ edit ]</button>
        <button
          onclick={() => runClassify(snippet.id)}
          disabled={!hasKey || classifying}
          title={hasKey ? undefined : "configure an Anthropic API key in settings first"}
        >
          [ classify ]
        </button>
        <button onclick={showList}>[ back ]</button>
      </div>
    </div>
    {#if classifying}
      <div class="status-line">// classifying…</div>
    {/if}
    {#if !hasKey}
      <div class="hint">no Anthropic API key configured — set one in settings to enable classification</div>
    {/if}
    {#if snippet.category}
      <div class="category">// category: {snippet.category}</div>
    {/if}
    {#if snippet.tags.length}
      <div class="tags">{snippet.tags.map((t) => `#${t}`).join(" ")}</div>
    {/if}
    {#if snippet.summary}
      <div class="summary">// summary: {snippet.summary}</div>
    {/if}
    <div class="content">{@html html}</div>
  </div>
{:else}
  <p>snippet not found</p>
{/if}

<style>
  .snippet-view {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
  }

  .header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--sp-3);
    border-bottom: 1px solid var(--border);
    padding-bottom: var(--sp-2);
  }

  h1 {
    margin: 0;
    font-size: 1.1em;
  }

  .actions {
    display: flex;
    gap: var(--sp-2);
    flex-shrink: 0;
  }

  .actions button {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
    cursor: pointer;
  }

  .actions button:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent);
  }

  .actions button:disabled {
    color: var(--fg-dim);
    cursor: not-allowed;
  }

  .category {
    color: var(--fg-dim);
  }

  .tags {
    color: var(--accent);
  }

  .summary {
    color: var(--fg-dim);
    font-style: italic;
  }

  .status-line {
    color: var(--accent);
  }

  .hint {
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  .content {
    line-height: 1.5;
  }

  .content :global(pre) {
    background: var(--bg-raised);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: var(--sp-2);
    overflow-x: auto;
  }

  .content :global(code) {
    font-family: var(--font-mono);
  }

  .content :global(:not(pre) > code) {
    background: var(--bg-raised);
    border-radius: var(--radius);
    padding: 0 4px;
  }

  .content :global(blockquote) {
    border-left: 2px solid var(--border);
    margin: 0;
    padding-left: var(--sp-3);
    color: var(--fg-dim);
  }

  .content :global(a) {
    color: var(--accent);
  }
</style>
