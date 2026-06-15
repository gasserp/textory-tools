<script lang="ts">
  import { passwordLogin, passwordRegister } from "../lib/stores.svelte";
  import { showToast } from "../lib/toast.svelte";

  let mode: "login" | "register" = $state("login");
  let username = $state("");
  let password = $state("");
  let submitting = $state(false);

  async function submit(): Promise<void> {
    if (!username.trim() || !password || submitting) return;
    submitting = true;
    try {
      if (mode === "login") {
        await passwordLogin(username.trim().toLowerCase(), password);
      } else {
        await passwordRegister(username.trim().toLowerCase(), password);
      }
    } catch (e) {
      showToast(e instanceof Error ? e.message : "sign in failed");
    } finally {
      submitting = false;
    }
  }

  function toggleMode(): void {
    mode = mode === "login" ? "register" : "login";
  }

  function onKeydown(e: KeyboardEvent): void {
    if (e.key === "Enter") {
      e.preventDefault();
      submit();
    }
  }
</script>

<div class="login">
  <p class="hint">{mode === "login" ? "sign in" : "create an account"}</p>

  <div class="field">
    <label for="login-username">username</label>
    <input
      id="login-username"
      bind:value={username}
      type="text"
      autocomplete="username"
      spellcheck="false"
      onkeydown={onKeydown}
    />
  </div>

  <div class="field">
    <label for="login-password">password</label>
    <input
      id="login-password"
      bind:value={password}
      type="password"
      autocomplete={mode === "login" ? "current-password" : "new-password"}
      spellcheck="false"
      onkeydown={onKeydown}
    />
  </div>

  <div class="actions">
    <button onclick={submit} disabled={!username.trim() || !password || submitting}>
      [ {mode === "login" ? "sign in" : "register"} ]
    </button>
    <button class="link" onclick={toggleMode} disabled={submitting}>
      [ {mode === "login" ? "need an account? register" : "have an account? sign in"} ]
    </button>
  </div>

  {#if mode === "register"}
    <p class="hint">beta access is admin-approved — registering creates a pending account.</p>
  {/if}
</div>

<style>
  .login {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    max-width: 320px;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
  }

  .field label {
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  .field input {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
  }

  .actions {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--sp-2);
    margin-top: var(--sp-2);
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

  .actions button.link {
    border-color: transparent;
    padding: 0;
    color: var(--fg-dim);
  }

  .actions button.link:hover:not(:disabled) {
    color: var(--accent);
  }

  .hint {
    margin: 0;
    color: var(--fg-dim);
    font-size: 0.85em;
  }
</style>
