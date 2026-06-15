<script lang="ts">
  import { searchState, registerSearchInput, clearSearch } from "../lib/search.svelte";

  let { onEnter, onClear }: { onEnter: () => void; onClear: () => void } = $props();

  let inputEl: HTMLInputElement | undefined = $state();

  $effect(() => {
    registerSearchInput(inputEl);
    return () => registerSearchInput(undefined);
  });

  function onKeydown(e: KeyboardEvent): void {
    if (e.key === "Enter") {
      e.preventDefault();
      onEnter();
    } else if (e.key === "Escape") {
      e.preventDefault();
      clearSearch();
      onClear();
    }
  }
</script>

<div class="search-bar" class:active={searchState.active}>
  <span class="prompt">/</span>
  <input
    bind:this={inputEl}
    bind:value={searchState.query}
    onkeydown={onKeydown}
    onfocus={() => (searchState.active = true)}
    onblur={() => (searchState.active = false)}
    type="text"
    autocomplete="off"
    spellcheck="false"
    placeholder="search… #tag @category"
    aria-label="Search snippets"
  />
  {#if searchState.active}<span class="caret">▌</span>{/if}
</div>

<style>
  .search-bar {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    padding: var(--sp-1) var(--sp-2);
    margin-bottom: var(--sp-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
  }

  .search-bar.active {
    border-color: var(--accent);
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

  .caret {
    color: var(--accent);
    animation: blink 1s step-end infinite;
  }

  @keyframes blink {
    50% {
      opacity: 0;
    }
  }
</style>
