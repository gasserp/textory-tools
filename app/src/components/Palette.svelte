<script lang="ts">
  import { onMount } from "svelte";
  import Fuse from "fuse.js";
  import { getCommands, type Command } from "../lib/commands";
  import { closeOverlays } from "../lib/overlay.svelte";

  const commands = getCommands();
  const fuse = new Fuse(commands, {
    keys: [
      { name: "title", weight: 0.6 },
      { name: "keywords", weight: 0.4 },
    ],
    threshold: 0.35,
    ignoreLocation: true,
  });

  let query = $state("");
  let selected = $state(0);
  let inputEl: HTMLInputElement | undefined = $state();

  const filtered = $derived.by(() => {
    const q = query.trim();
    if (q === "") return commands;
    return fuse.search(q).map((r) => r.item);
  });

  $effect(() => {
    if (selected > filtered.length - 1) selected = Math.max(0, filtered.length - 1);
  });

  onMount(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    inputEl?.focus();
    return () => previousFocus?.focus();
  });

  function run(cmd: Command): void {
    closeOverlays();
    cmd.run();
  }

  function onKeydown(e: KeyboardEvent): void {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      selected = Math.min(selected + 1, filtered.length - 1);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      selected = Math.max(selected - 1, 0);
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (filtered[selected]) run(filtered[selected]);
    } else if (e.key === "Escape") {
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
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="palette"
    role="dialog"
    aria-modal="true"
    aria-label="Command palette"
    tabindex="-1"
    onclick={(e) => e.stopPropagation()}
  >
    <div class="prompt-row">
      <span class="prompt">&gt;</span>
      <input
        bind:this={inputEl}
        bind:value={query}
        onkeydown={onKeydown}
        type="text"
        autocomplete="off"
        spellcheck="false"
        aria-label="Command"
      />
    </div>
    <ul class="results">
      {#each filtered as cmd, i (cmd.id)}
        <li>
          <button
            class:selected={i === selected}
            onclick={() => run(cmd)}
            onmouseenter={() => (selected = i)}
          >
            {cmd.title}
          </button>
        </li>
      {:else}
        <li class="empty">no matches</li>
      {/each}
    </ul>
  </div>
</div>

<style>
  .overlay-backdrop {
    position: fixed;
    inset: 0;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding-top: 15vh;
    background: rgba(0, 0, 0, 0.5);
    z-index: 100;
  }

  .palette {
    width: min(560px, 90vw);
    background: var(--bg-raised);
    border: 1px solid var(--border);
    border-radius: var(--radius);
  }

  .prompt-row {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    padding: var(--sp-2) var(--sp-3);
    border-bottom: 1px solid var(--border);
  }

  .prompt {
    color: var(--accent);
  }

  input {
    flex: 1;
    background: transparent;
    border: none;
    color: var(--fg);
    font: inherit;
  }

  .results {
    list-style: none;
    margin: 0;
    padding: var(--sp-1);
    max-height: 50vh;
    overflow-y: auto;
  }

  .results button {
    display: block;
    width: 100%;
    text-align: left;
    background: transparent;
    border: 1px solid transparent;
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
    cursor: pointer;
  }

  .results button.selected {
    border-color: var(--accent);
    background: var(--bg);
    color: var(--accent);
  }

  .results .empty {
    padding: var(--sp-1) var(--sp-2);
    color: var(--fg-dim);
  }
</style>
