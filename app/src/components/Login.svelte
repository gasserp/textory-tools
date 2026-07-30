<script lang="ts">
  import { clearChallenge, passwordLogin, passwordRegister, session, verifyTwoFactor } from "../lib/stores.svelte";
  import { isNative } from "../lib/runtime";
  import { showToast } from "../lib/toast.svelte";

  let mode: "login" | "register" = $state("login");
  let username = $state("");
  let password = $state("");
  let code = $state("");
  let usingRecoveryCode = $state(false);
  let submitting = $state(false);

  // Registration creates an account with no second factor and, on the web, would need
  // the terms checkbox the unregistered flow already shows. Web users register through
  // GitHub SSO + request access.
  const canRegister = isNative;
  const awaitingCode = $derived(session.status === "mfa_challenge");

  /**
   * One string for every authentication failure. The server's own error text is
   * discarded: distinguishing "no such user" from "wrong password" — or a valid
   * username from an invalid one — hands out an account-enumeration oracle.
   */
  const GENERIC_AUTH_ERROR = "invalid username or password";

  async function submitCredentials(): Promise<void> {
    if (!username.trim() || !password || submitting) return;
    submitting = true;
    try {
      if (mode === "login") {
        await passwordLogin(username.trim().toLowerCase(), password);
      } else {
        await passwordRegister(username.trim().toLowerCase(), password);
      }
      password = "";
    } catch {
      showToast(GENERIC_AUTH_ERROR);
    } finally {
      submitting = false;
    }
  }

  async function submitCode(): Promise<void> {
    // Authenticator apps render codes as "123 456".
    const entered = code.replace(/\s/g, "");
    if (!entered || submitting) return;
    submitting = true;
    try {
      await verifyTwoFactor(entered);
      code = "";
    } catch (e) {
      // "too many attempts" and an expired challenge are actionable and leak nothing;
      // anything else collapses to the generic string.
      const message = e instanceof Error ? e.message : "";
      const safe = message === "too many attempts" || message === "challenge expired";
      showToast(safe ? message : "invalid code");
      if (message === "challenge expired") cancelChallenge();
    } finally {
      submitting = false;
    }
  }

  function cancelChallenge(): void {
    clearChallenge();
    code = "";
    password = "";
    usingRecoveryCode = false;
    session.status = "anonymous";
  }

  function toggleMode(): void {
    mode = mode === "login" ? "register" : "login";
    password = "";
  }
</script>

{#if awaitingCode}
  <form class="login" onsubmit={(e) => { e.preventDefault(); submitCode(); }}>
    <p class="hint">
      {usingRecoveryCode ? "enter a recovery code" : "enter the 6-digit code from your authenticator"}
    </p>
    <p class="hint">
      not enrolled in two-factor yet? enter anything here to continue to setup.
    </p>

    <div class="field">
      <label for="login-code">{usingRecoveryCode ? "recovery code" : "code"}</label>
      <!-- Recovery maxlength is 40, not 32: a code is exactly 32 chars, so a 32 cap
           truncates a paste carrying a leading or trailing space before submitCode()
           strips it — the user then sees "invalid code" for a code that was right. -->
      <!-- svelte-ignore a11y_autofocus -->
      <input
        id="login-code"
        bind:value={code}
        type="text"
        inputmode={usingRecoveryCode ? "text" : "numeric"}
        autocomplete="one-time-code"
        maxlength={usingRecoveryCode ? 40 : 7}
        spellcheck="false"
        autofocus
      />
    </div>

    <div class="actions">
      <button type="submit" disabled={!code.trim() || submitting}>[ verify ]</button>
      <button
        type="button"
        class="link"
        onclick={() => { usingRecoveryCode = !usingRecoveryCode; code = ""; }}
        disabled={submitting}
      >
        [ {usingRecoveryCode ? "use an authenticator code" : "use a recovery code instead"} ]
      </button>
      <button type="button" class="link" onclick={cancelChallenge} disabled={submitting}>[ cancel ]</button>
    </div>
  </form>
{:else}
  <form class="login" onsubmit={(e) => { e.preventDefault(); submitCredentials(); }}>
    <p class="hint">{mode === "login" ? "sign in" : "create an account"}</p>

    <div class="field">
      <label for="login-username">username</label>
      <input
        id="login-username"
        bind:value={username}
        type="text"
        autocomplete="username"
        spellcheck="false"
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
      />
    </div>

    <div class="actions">
      <button type="submit" disabled={!username.trim() || !password || submitting}>
        [ {mode === "login" ? "sign in" : "register"} ]
      </button>
      {#if canRegister}
        <button type="button" class="link" onclick={toggleMode} disabled={submitting}>
          [ {mode === "login" ? "need an account? register" : "have an account? sign in"} ]
        </button>
      {/if}
    </div>

    {#if mode === "register"}
      <p class="hint">beta access is admin-approved — registering creates a pending account.</p>
    {/if}
  </form>
{/if}

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
