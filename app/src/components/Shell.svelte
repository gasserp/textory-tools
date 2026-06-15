<script lang="ts">
  import { onMount } from "svelte";
  import { session } from "../lib/stores.svelte";
  import { registerKey } from "../lib/keys";
  import { overlay, togglePalette, openHelp, closeOverlays } from "../lib/overlay.svelte";
  import { themeState } from "../lib/theme.svelte";
  import { toastState } from "../lib/toast.svelte";
  import Palette from "./Palette.svelte";
  import Help from "./Help.svelte";
  import Admin from "./Admin.svelte";
  import Settings from "./Settings.svelte";

  let { children } = $props();

  onMount(() => {
    const unregisters = [
      registerKey({ key: "k", ctrl: true, allowInInput: true, run: togglePalette }),
      registerKey({ key: "?", run: openHelp }),
      registerKey({
        key: "Escape",
        run: closeOverlays,
        when: () => overlay.palette || overlay.help || overlay.admin || overlay.settings,
      }),
    ];
    return () => unregisters.forEach((unregister) => unregister());
  });
</script>

<div class="shell">
  <header class="shell-header">
    <span class="brand">textory</span>
    <span class="status">
      {#if session.user}<span class="login">{session.user.githubLogin}</span>{/if}
      <span class="theme">{themeState.current}</span>
    </span>
  </header>

  <main class="shell-main">
    {@render children?.()}
  </main>

  <footer class="shell-footer">
    <span>/ search &middot; ctrl+k opens palette &middot; ? help</span>
  </footer>

  {#if toastState.current}
    <div class="toast" role="status" aria-live="polite">{toastState.current.text}</div>
  {/if}
</div>

{#if overlay.palette}
  <Palette />
{/if}

{#if overlay.help}
  <Help />
{/if}

{#if overlay.admin}
  <Admin />
{/if}

{#if overlay.settings}
  <Settings />
{/if}

<style>
  .shell {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  .shell-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--sp-3);
    padding: var(--sp-2) var(--sp-3);
    border-bottom: 1px solid var(--border);
  }

  .brand::before {
    content: "> ";
    color: var(--accent);
  }

  .status {
    display: flex;
    align-items: center;
    gap: var(--sp-3);
    color: var(--fg-dim);
  }

  .theme {
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 0 var(--sp-1);
  }

  .shell-main {
    flex: 1;
    padding: var(--sp-3);
  }

  .shell-footer {
    padding: var(--sp-2) var(--sp-3);
    border-top: 1px solid var(--border);
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  .toast {
    position: fixed;
    left: 50%;
    bottom: var(--sp-4);
    transform: translateX(-50%);
    background: var(--bg-raised);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: var(--sp-1) var(--sp-3);
  }
</style>
