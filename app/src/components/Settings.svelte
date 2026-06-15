<script lang="ts">
  import { onMount } from "svelte";
  import { closeOverlays } from "../lib/overlay.svelte";
  import { session, saveAnthropicKey, deleteAnthropicKey, setAutoClassify, generateCliToken, regenerateCliToken, revokeCliToken, setPassword, clearPassword } from "../lib/stores.svelte";
  import { showToast } from "../lib/toast.svelte";
  import { copyPlain } from "../lib/clipboard";

  let dialogEl: HTMLDivElement | undefined = $state();
  let inputEl: HTMLInputElement | undefined = $state();
  let key = $state("");
  let saving = $state(false);
  let deleting = $state(false);
  let autoClassifying = $state(false);
  let cliToken = $state("");
  let cliGenerating = $state(false);
  let cliRevoking = $state(false);
  let passwordUsername = $state("");
  let passwordValue = $state("");
  let passwordSaving = $state(false);
  let passwordRemoving = $state(false);

  const hasKey = $derived(session.user?.hasAnthropicKey ?? false);
  const autoClassify = $derived(session.user?.autoClassify ?? false);
  const hasCliToken = $derived(session.user?.cliTokenCreatedAt != null);
  const cliTokenCreatedAt = $derived(session.user?.cliTokenCreatedAt);
  const hasPassword = $derived(session.user?.hasPassword ?? false);

  onMount(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    dialogEl?.focus();
    return () => previousFocus?.focus();
  });

  async function save(): Promise<void> {
    if (!key.trim() || saving) return;
    saving = true;
    try {
      await saveAnthropicKey(key.trim());
      key = "";
      showToast("api key saved");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "save failed");
    } finally {
      saving = false;
    }
  }

  async function remove(): Promise<void> {
    if (deleting) return;
    deleting = true;
    try {
      await deleteAnthropicKey();
      showToast("api key removed");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "delete failed");
    } finally {
      deleting = false;
    }
  }

  async function toggleAutoClassify(): Promise<void> {
    if (autoClassifying) return;
    autoClassifying = true;
    try {
      await setAutoClassify(!autoClassify);
    } catch (e) {
      showToast(e instanceof Error ? e.message : "save failed");
    } finally {
      autoClassifying = false;
    }
  }

  async function generateToken(): Promise<void> {
    if (cliGenerating) return;
    cliGenerating = true;
    try {
      const response = await generateCliToken();
      cliToken = response.token;
      showToast("token generated");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "generate failed");
    } finally {
      cliGenerating = false;
    }
  }

  async function regenerateToken(): Promise<void> {
    if (cliGenerating) return;
    cliGenerating = true;
    try {
      const response = await regenerateCliToken();
      cliToken = response.token;
      showToast("token regenerated");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "regenerate failed");
    } finally {
      cliGenerating = false;
    }
  }

  async function revokeToken(): Promise<void> {
    if (cliRevoking) return;
    cliRevoking = true;
    try {
      await revokeCliToken();
      cliToken = "";
      showToast("token revoked");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "revoke failed");
    } finally {
      cliRevoking = false;
    }
  }

  async function savePassword(): Promise<void> {
    if (!passwordUsername.trim() || !passwordValue.trim() || passwordSaving) return;
    passwordSaving = true;
    try {
      await setPassword(passwordUsername.trim(), passwordValue);
      passwordUsername = "";
      passwordValue = "";
      showToast("password configured");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "save failed");
    } finally {
      passwordSaving = false;
    }
  }

  async function removePassword(): Promise<void> {
    if (passwordRemoving) return;
    passwordRemoving = true;
    try {
      await clearPassword();
      showToast("password removed");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "delete failed");
    } finally {
      passwordRemoving = false;
    }
  }

  function formatDate(dateString: string): string {
    try {
      const date = new Date(dateString);
      return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch {
      return dateString;
    }
  }

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
    class="settings"
    bind:this={dialogEl}
    role="dialog"
    aria-modal="true"
    aria-label="Settings"
    tabindex="-1"
    onkeydown={onKeydown}
    onclick={(e) => e.stopPropagation()}
  >
    <h2>settings</h2>

    <div class="row">
      <span>anthropic api key</span>
      <span class="status" class:ok={hasKey} class:missing={!hasKey}>
        key: {hasKey ? "configured ✓" : "not set"}
      </span>
    </div>

    <div class="field">
      <input
        bind:this={inputEl}
        bind:value={key}
        type="password"
        placeholder="sk-ant-..."
        autocomplete="off"
        spellcheck="false"
        aria-label="Anthropic API key"
      />
      <button onclick={save} disabled={!key.trim() || saving}>[ save ]</button>
      <button onclick={remove} disabled={!hasKey || deleting}>[ delete ]</button>
    </div>

    <p class="hint">
      classification uses claude-haiku-4-5 at your own cost via your Anthropic account. your key is encrypted at
      rest and never sent back to the browser.
    </p>
    <p class="hint">classification calls are sent to anthropic with your key — usage is billed to your anthropic account.</p>

    <label class="row checkbox">
      <span>auto-classify new snippets</span>
      <input type="checkbox" checked={autoClassify} disabled={autoClassifying} onchange={toggleAutoClassify} />
    </label>
    <p class="hint">when enabled, newly saved snippets are classified in the background using your Anthropic key.</p>
    <p class="hint">auto-classify runs an llm call (your cost) on every new snippet.</p>

    <div class="row">
      <span>cli token</span>
      {#if hasCliToken && cliTokenCreatedAt}
        <span class="status ok">created {formatDate(cliTokenCreatedAt)}</span>
      {:else}
        <span class="status missing">not set</span>
      {/if}
    </div>

    {#if cliToken}
      <p class="hint warning">token shown once only — save it now</p>
      <div class="field">
        <input
          type="text"
          value={cliToken}
          readonly
          spellcheck="false"
          aria-label="CLI token"
          class="monospace"
        />
        <button onclick={() => copyPlain(cliToken)} aria-label="Copy token">[ copy ]</button>
      </div>
    {:else}
      <p class="hint">token for the txt command-line tool</p>
      <div class="field">
        {#if hasCliToken}
          <button onclick={regenerateToken} disabled={cliGenerating || cliRevoking}>[ regenerate ]</button>
          <button onclick={revokeToken} disabled={cliGenerating || cliRevoking}>[ revoke ]</button>
        {:else}
          <button onclick={generateToken} disabled={cliGenerating}>[ generate token ]</button>
        {/if}
      </div>
      {#if hasCliToken}
        <p class="hint">regenerating will invalidate the previous token</p>
      {/if}
    {/if}

    <div class="row">
      <span>password login</span>
      <span class="status" class:ok={hasPassword} class:missing={!hasPassword}>
        {hasPassword ? "configured ✓" : "not set"}
      </span>
    </div>

    <p class="hint">set a username and password to sign in without GitHub</p>
    <div class="field">
      <input
        bind:value={passwordUsername}
        type="text"
        placeholder="username"
        autocomplete="off"
        spellcheck="false"
        aria-label="Username"
        disabled={passwordSaving || passwordRemoving}
      />
    </div>
    <div class="field">
      <input
        bind:value={passwordValue}
        type="password"
        placeholder="password (min 10 chars)"
        autocomplete="off"
        spellcheck="false"
        aria-label="Password"
        disabled={passwordSaving || passwordRemoving}
      />
      <button onclick={savePassword} disabled={!passwordUsername.trim() || !passwordValue.trim() || passwordSaving || passwordRemoving}>
        {hasPassword ? "[ update ]" : "[ set ]"}
      </button>
    </div>
    {#if hasPassword}
      <div class="field">
        <button onclick={removePassword} disabled={passwordSaving || passwordRemoving}>[ remove password ]</button>
      </div>
    {/if}

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

  .settings {
    width: min(480px, 90vw);
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

  .row {
    display: flex;
    justify-content: space-between;
    gap: var(--sp-3);
    padding: var(--sp-1) 0;
  }

  .status.ok {
    color: var(--ok);
  }

  .status.missing {
    color: var(--fg-dim);
  }

  .row.checkbox {
    align-items: center;
    cursor: pointer;
  }

  .row.checkbox input {
    cursor: pointer;
  }

  .field {
    display: flex;
    gap: var(--sp-2);
    margin-top: var(--sp-2);
  }

  .field input {
    flex: 1;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
  }

  .field button {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
    cursor: pointer;
  }

  .field button:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent);
  }

  .field button:disabled {
    color: var(--fg-dim);
    cursor: not-allowed;
  }

  .hint {
    margin: var(--sp-3) 0 0;
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  .hint.warning {
    color: var(--warning, #ff9500);
  }

  .hint:last-child {
    text-align: center;
  }

  .monospace {
    font-family: monospace;
  }
</style>
