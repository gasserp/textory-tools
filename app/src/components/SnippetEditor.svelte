<script lang="ts">
  import { onMount } from "svelte";
  import { getSnippet, createSnippet, updateSnippet } from "../lib/snippets.svelte";
  import { session } from "../lib/stores.svelte";
  import { viewState, showList, showView, takePendingContent } from "../lib/view.svelte";
  import { render } from "../lib/markdown";
  import { registerKey } from "../lib/keys";
  import { showToast } from "../lib/toast.svelte";
  import { runClassify } from "../lib/classify.svelte";

  const existing = viewState.mode === "edit" && viewState.selectedId ? getSnippet(viewState.selectedId) : undefined;

  let title = $state(existing?.title ?? "");
  let content = $state(existing?.content ?? takePendingContent() ?? "");
  let tagsInput = $state(existing?.tags.join(", ") ?? "");
  let saving = $state(false);
  let previewHtml = $state(existing ? render(existing.content) : "");

  function deriveTitle(text: string): string {
    const firstLine = text.split("\n").find((line) => line.trim().length > 0) ?? "";
    const cleaned = firstLine.trim().replace(/^#+\s*/, "");
    return (cleaned || "untitled").slice(0, 200);
  }

  const effectiveTitle = $derived(existing ? title : deriveTitle(content));

  const tags = $derived(
    tagsInput
      .split(/[,\s]+/)
      .map((t) => t.trim())
      .filter(Boolean),
  );

  const contentBytes = $derived(new TextEncoder().encode(content).length);
  const quotaBytes = $derived(session.user?.quotaBytes ?? 0);
  const usedBytes = $derived(session.user?.usedBytes ?? 0);
  const existingBytes = $derived(existing?.contentBytes ?? 0);
  const bytesAfterSave = $derived(usedBytes - existingBytes + contentBytes);

  const titleValid = $derived(effectiveTitle.length >= 1 && effectiveTitle.length <= 200);
  const contentValid = $derived(content.length >= 1 && content.length <= 32768);
  const tagsValid = $derived(tags.length <= 20 && tags.every((t) => t.length <= 40));
  const withinQuota = $derived(bytesAfterSave <= quotaBytes);
  const canSave = $derived(titleValid && contentValid && tagsValid && withinQuota && !saving);

  const dirty = $derived(
    title !== (existing?.title ?? "") ||
      content !== (existing?.content ?? "") ||
      tagsInput !== (existing?.tags.join(", ") ?? ""),
  );

  $effect(() => {
    if (!existing) return;
    const md = content;
    const timer = setTimeout(() => {
      previewHtml = render(md);
    }, 150);
    return () => clearTimeout(timer);
  });

  async function save(): Promise<void> {
    if (!canSave) return;
    saving = true;
    try {
      const saved = existing
        ? await updateSnippet(existing.id, { title: effectiveTitle, content, tags })
        : await createSnippet({ title: effectiveTitle, content, tags });
      if (!existing && session.user?.autoClassify && session.user?.hasAnthropicKey) {
        void runClassify(saved.id);
      }
      showView(saved.id);
    } catch (e) {
      showToast(e instanceof Error ? e.message : "save failed");
    } finally {
      saving = false;
    }
  }

  function cancel(): void {
    if (dirty && !confirm("discard changes?")) return;
    if (existing) showView(existing.id);
    else showList();
  }

  onMount(() => {
    const active = () => viewState.mode === "edit" || viewState.mode === "new";
    const unregisters = [
      registerKey({ key: "s", ctrl: true, allowInInput: true, when: active, run: save }),
      registerKey({ key: "Escape", allowInInput: true, when: active, run: cancel }),
    ];
    return () => unregisters.forEach((unregister) => unregister());
  });
</script>

<div class="snippet-editor">
  <div class="fields">
    {#if existing}
      <label class="field-title">
        <span>title</span>
        <input bind:value={title} maxlength="200" autocomplete="off" spellcheck="false" />
      </label>
    {/if}
    <label class="field-tags">
      <span>tags</span>
      <input bind:value={tagsInput} placeholder="comma or space separated" autocomplete="off" spellcheck="false" />
    </label>
  </div>

  {#if tags.length}
    <div class="chips">
      {#each tags as tag (tag)}<span class="chip">#{tag}</span>{/each}
    </div>
  {/if}

  {#if existing}
    <div class="split">
      <textarea bind:value={content} spellcheck="false" aria-label="content"></textarea>
      <div class="preview">{@html previewHtml}</div>
    </div>
  {:else}
    <textarea class="full" bind:value={content} spellcheck="false" aria-label="content"></textarea>
  {/if}

  <div class="status-bar">
    {#if existing}
      <span class:invalid={!titleValid}>title {title.length}/200</span>
    {/if}
    <span class:invalid={!contentValid}>content {content.length}/32768</span>
    <span class:invalid={!tagsValid}>tags {tags.length}/20</span>
    <span class:invalid={!withinQuota}>{quotaBytes - bytesAfterSave} bytes remaining</span>
    <span class="spacer"></span>
    <button onclick={save} disabled={!canSave}>[ save ]</button>
    <button onclick={cancel}>[ cancel ]</button>
  </div>
</div>

<style>
  .snippet-editor {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    height: 100%;
  }

  .fields {
    display: flex;
    gap: var(--sp-3);
  }

  .fields label {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    color: var(--fg-dim);
  }

  .field-title {
    flex: 2;
  }

  .field-tags {
    flex: 1;
  }

  .fields input {
    flex: 1;
    background: var(--bg-raised);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
  }

  .chips {
    display: flex;
    gap: var(--sp-1);
    flex-wrap: wrap;
  }

  .chip {
    color: var(--accent);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0 var(--sp-1);
    font-size: 0.85em;
  }

  .split {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--sp-2);
    flex: 1;
    min-height: 50vh;
  }

  textarea,
  .preview {
    background: var(--bg-raised);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: var(--sp-2);
    overflow: auto;
  }

  textarea {
    color: var(--fg);
    font: inherit;
    resize: none;
  }

  textarea.full {
    flex: 1;
    min-height: 50vh;
  }

  .preview {
    line-height: 1.5;
  }

  .preview :global(pre) {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: var(--sp-2);
    overflow-x: auto;
  }

  .preview :global(:not(pre) > code) {
    background: var(--bg);
    border-radius: var(--radius);
    padding: 0 4px;
  }

  .status-bar {
    display: flex;
    align-items: center;
    gap: var(--sp-3);
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  .spacer {
    flex: 1;
  }

  .invalid {
    color: var(--danger);
  }

  .status-bar button {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
    cursor: pointer;
  }

  .status-bar button:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent);
  }

  .status-bar button:disabled {
    color: var(--fg-dim);
    cursor: not-allowed;
  }
</style>
