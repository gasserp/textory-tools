<script lang="ts">
  import { logout, stepUpTwoFactor } from "../lib/stores.svelte";
  import { showToast } from "../lib/toast.svelte";

  /**
   * The wall for a user who has already enrolled but whose session has not proved it.
   *
   * This is what GitHub SSO users see once 2FA is enforced. Azure exposes no MFA claim,
   * so an SSO session is never `mfaSatisfied` no matter how the user signed in to
   * GitHub. Without this screen they would land on the enrolment flow, which refuses
   * because a factor is already active — a lockout with no way out.
   */
  let code = $state("");
  let usingRecoveryCode = $state(false);
  let submitting = $state(false);

  async function submit(): Promise<void> {
    // Authenticator apps render codes as "123 456".
    const entered = code.replace(/\s/g, "");
    if (!entered || submitting) return;
    submitting = true;
    try {
      await stepUpTwoFactor(entered);
      code = "";
    } catch (e) {
      const message = e instanceof Error ? e.message : "";
      showToast(message === "too many attempts" ? message : "invalid code");
    } finally {
      submitting = false;
    }
  }
</script>

<form class="stepup" onsubmit={(e) => { e.preventDefault(); submit(); }}>
  <h2>two-factor authentication required</h2>
  <p>
    {usingRecoveryCode
      ? "enter a recovery code."
      : "enter the 6-digit code from your authenticator to continue."}
  </p>

  <div class="field">
    <label for="stepup-code">{usingRecoveryCode ? "recovery code" : "code"}</label>
    <!-- svelte-ignore a11y_autofocus -->
    <input
      id="stepup-code"
      bind:value={code}
      type="text"
      inputmode={usingRecoveryCode ? "text" : "numeric"}
      autocomplete="one-time-code"
      maxlength={usingRecoveryCode ? 40 : 7}
      spellcheck="false"
      disabled={submitting}
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
    <button type="button" class="link" onclick={logout} disabled={submitting}>[ sign out ]</button>
  </div>

  <p class="hint">
    lost your authenticator and your recovery codes? an administrator has to reset the
    factor on your account.
  </p>
</form>

<style>
  .stepup {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    max-width: 420px;
  }

  h2 {
    margin: 0;
    font-size: 1em;
    color: var(--accent);
  }

  p {
    margin: 0;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: var(--sp-1);
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
    flex-wrap: wrap;
    gap: var(--sp-2);
  }

  button {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: var(--sp-1) var(--sp-2);
    cursor: pointer;
  }

  button:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent);
  }

  button:disabled {
    color: var(--fg-dim);
    cursor: not-allowed;
  }

  button.link {
    border-color: transparent;
    padding: 0;
    color: var(--fg-dim);
  }

  .hint {
    color: var(--fg-dim);
    font-size: 0.85em;
  }
</style>
