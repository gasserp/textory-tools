<script lang="ts">
  import { onMount } from "svelte";
  import { closeOverlays } from "../lib/overlay.svelte";

  let dialogEl: HTMLDivElement | undefined = $state();

  const bindings: [string, string][] = [
    ["ctrl+k", "command palette"],
    ["/", "focus search"],
    ["?", "this help"],
    ["esc", "close overlay / clear search"],
    ["up / down", "navigate palette results"],
    ["enter", "run selected command / open snippet"],
    ["#tag", "search: filter to snippets with tag"],
    ["@category", "search: filter to snippets in category"],
    ["space", "toggle selection for multi-delete"],
    ["paste", "create a new snippet from clipboard"],
  ];

  onMount(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    dialogEl?.focus();
    return () => previousFocus?.focus();
  });

  function onKeydown(e: KeyboardEvent): void {
    if (e.key === "Escape") {
      e.preventDefault();
      closeOverlays();
    } else if (e.key === "Tab") {
      e.preventDefault();
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="overlay-backdrop" onclick={closeOverlays}>
  <div
    class="help"
    bind:this={dialogEl}
    role="dialog"
    aria-modal="true"
    aria-label="Keyboard shortcuts"
    tabindex="-1"
    onkeydown={onKeydown}
    onclick={(e) => e.stopPropagation()}
  >
    <h2>keyboard shortcuts</h2>
    <dl>
      {#each bindings as [key, desc] (key)}
        <div class="row">
          <dt>{key}</dt>
          <dd>{desc}</dd>
        </div>
      {/each}
    </dl>
    <p class="hint">esc to close</p>
  </div>
</div>

<style>
  .overlay-backdrop {
    position: fixed;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.5);
    z-index: 100;
  }

  .help {
    width: min(420px, 90vw);
    background: var(--bg-raised);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: var(--sp-3) var(--sp-4);
  }

  h2 {
    margin: 0 0 var(--sp-3);
    font-size: 1em;
    color: var(--accent);
  }

  dl {
    margin: 0;
  }

  .row {
    display: flex;
    justify-content: space-between;
    gap: var(--sp-3);
    padding: var(--sp-1) 0;
    border-bottom: 1px dotted var(--border);
  }

  .row:last-child {
    border-bottom: none;
  }

  dt {
    color: var(--accent);
  }

  dd {
    margin: 0;
    color: var(--fg-dim);
  }

  .hint {
    margin: var(--sp-3) 0 0;
    color: var(--fg-dim);
    font-size: 0.85em;
    text-align: center;
  }
</style>
