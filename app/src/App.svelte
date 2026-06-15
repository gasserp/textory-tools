<script lang="ts">
  import { onMount } from "svelte";
  import { loadSession, logout, requestAccess, session } from "./lib/stores.svelte";
  import { isNative } from "./lib/runtime";
  import Shell from "./components/Shell.svelte";
  import Terms from "./components/Terms.svelte";
  import Login from "./components/Login.svelte";
  import Main from "./Main.svelte";

  let showTerms = $state(false);
  let acceptedTerms = $state(false);

  onMount(loadSession);
</script>

<Shell>
  {#if session.status === "loading"}
    <p>textory ▌</p>
  {:else if session.status === "anonymous"}
    <p>textory ▌</p>
    {#if isNative}
      <Login />
    {:else}
      <a href="/login">[ sign in with github ]</a>
    {/if}
  {:else if session.status === "unregistered"}
    <p>textory ▌ — a fast, console-style snippet manager. beta access is admin-approved.</p>
    <p>
      <button onclick={() => (showTerms = !showTerms)}>[ {showTerms ? "hide" : "view"} terms ]</button>
    </p>
    {#if showTerms}
      <Terms />
    {/if}
    <p class="accept">
      <label>
        <input type="checkbox" bind:checked={acceptedTerms} />
        I have read and accept the Terms of Use &amp; Acceptable Use Policy
      </label>
    </p>
    <button onclick={requestAccess} disabled={!acceptedTerms}>[ request access ]</button>
  {:else if session.status === "pending"}
    <p>access requested — awaiting approval</p>
    {#if isNative}
      <button onclick={logout}>[ log out ]</button>
    {/if}
  {:else if session.status === "rejected"}
    <p>access denied</p>
    {#if isNative}
      <button onclick={logout}>[ log out ]</button>
    {/if}
  {:else if session.status === "approved"}
    {#if isNative}
      <div class="native-bar">
        <button onclick={logout}>[ log out ]</button>
      </div>
    {/if}
    <Main />
  {/if}
</Shell>

<style>
  .accept {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
  }

  .accept label {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    cursor: pointer;
  }

  .accept input {
    cursor: pointer;
  }

  .native-bar {
    display: flex;
    justify-content: flex-end;
    padding: var(--sp-1) var(--sp-2);
  }

  .native-bar button {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg-dim);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
    cursor: pointer;
  }

  .native-bar button:hover {
    border-color: var(--accent);
    color: var(--accent);
  }
</style>
