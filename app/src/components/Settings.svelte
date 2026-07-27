<script lang="ts">
  import { onMount } from "svelte";
  import { closeOverlays } from "../lib/overlay.svelte";
  import { session, saveAnthropicKey, deleteAnthropicKey, setAutoClassify, generateCliToken, regenerateCliToken, revokeCliToken, setPassword, clearPassword, disableTwoFactor, regenerateRecoveryCodes, enrollTwoFactor, activateTwoFactor, replaceTwoFactor, activateReplacement } from "../lib/stores.svelte";
  import { currentCapabilities } from "../lib/capabilities";
  import { reauthKind, reauthLabel, reauthPayload } from "../lib/reauth";
  import { showToast } from "../lib/toast.svelte";
  import { copyPlain } from "../lib/clipboard";
  import TwoFactorSetup from "./TwoFactorSetup.svelte";

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
  let mfaCode = $state("");
  let mfaBusy = $state(false);
  let freshRecoveryCodes: string[] = $state([]);
  // "enroll" and "replace" both mount TwoFactorSetup; they differ only in endpoints.
  let factorFlow: "none" | "enroll" | "replace" = $state("none");
  let rotateCode = $state("");
  // True while TwoFactorSetup has recovery codes on screen. Closing the overlay then
  // destroys the only copy the user will ever be shown, and the previous set has
  // already been invalidated server-side.
  let factorCodesVisible = $state(false);
  // Proof of identity for the credential-minting actions. Kept per-action rather than
  // shared so that typing a code for one does not silently authorise another.
  let cliReauth = $state("");
  let setPasswordReauth = $state("");
  let removePasswordReauth = $state("");

  const MIN_PASSWORD_LENGTH = 10;
  const passwordTooShort = $derived(
    passwordValue.length > 0 && passwordValue.length < MIN_PASSWORD_LENGTH,
  );
  const mfaSupported = $derived(currentCapabilities().mfa !== "unsupported");
  const mfaRequired = $derived(currentCapabilities().mfa === "required");
  const mfaEnabled = $derived(session.user?.mfaEnabled ?? false);
  const recoveryRemaining = $derived(session.user?.recoveryCodesRemaining);

  const hasKey = $derived(session.user?.hasAnthropicKey ?? false);
  const autoClassify = $derived(session.user?.autoClassify ?? false);
  const hasCliToken = $derived(session.user?.cliTokenCreatedAt != null);
  const cliTokenCreatedAt = $derived(session.user?.cliTokenCreatedAt);
  const hasPassword = $derived(session.user?.hasPassword ?? false);

  /**
   * What the server will accept as proof for a credential change: a code when a factor
   * is active, otherwise the current password, otherwise nothing (a GitHub-SSO account
   * with neither has no second thing to prove).
   */
  const proof = $derived(reauthKind(session.user));
  const proofLabel = $derived(reauthLabel(proof));
  const needsProof = $derived(proof !== "none");

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

  async function mintToken(regenerating: boolean): Promise<void> {
    if (cliGenerating || (needsProof && !cliReauth.trim())) return;
    cliGenerating = true;
    try {
      const mint = regenerating ? regenerateCliToken : generateCliToken;
      const response = await mint(reauthPayload(proof, cliReauth));
      cliToken = response.token;
      cliReauth = "";
      showToast(regenerating ? "token regenerated" : "token generated");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "generate failed");
    } finally {
      cliGenerating = false;
    }
  }

  const generateToken = () => mintToken(false);
  const regenerateToken = () => mintToken(true);

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

  async function regenerateCodes(): Promise<void> {
    const entered = mfaCode.replace(/\s/g, "");
    if (!entered || mfaBusy) return;
    mfaBusy = true;
    try {
      freshRecoveryCodes = await regenerateRecoveryCodes(entered);
      mfaCode = "";
      showToast("recovery codes regenerated");
    } catch {
      showToast("invalid code");
    } finally {
      mfaBusy = false;
    }
  }

  async function turnOffTwoFactor(): Promise<void> {
    const entered = mfaCode.replace(/\s/g, "");
    if (!entered || mfaBusy) return;
    mfaBusy = true;
    try {
      await disableTwoFactor(entered);
      mfaCode = "";
      showToast("two-factor disabled");
    } catch {
      showToast("invalid code");
    } finally {
      mfaBusy = false;
    }
  }

  async function savePassword(): Promise<void> {
    if (!passwordUsername.trim() || !passwordValue.trim() || passwordSaving) return;
    if (needsProof && !setPasswordReauth.trim()) return;
    if (passwordValue.length < MIN_PASSWORD_LENGTH) {
      showToast(`password must be at least ${MIN_PASSWORD_LENGTH} characters`);
      return;
    }
    passwordSaving = true;
    try {
      await setPassword(
        passwordUsername.trim(),
        passwordValue,
        reauthPayload(proof, setPasswordReauth),
      );
      passwordUsername = "";
      passwordValue = "";
      setPasswordReauth = "";
      // Every other session was just invalidated, so say so — otherwise the user
      // discovers it when their phone signs itself out.
      showToast("password configured — other sessions signed out");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "save failed");
    } finally {
      passwordSaving = false;
    }
  }

  async function removePassword(): Promise<void> {
    if (passwordRemoving) return;
    if (needsProof && !removePasswordReauth.trim()) return;
    passwordRemoving = true;
    try {
      await clearPassword(reauthPayload(proof, removePasswordReauth));
      removePasswordReauth = "";
      showToast("password removed");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "delete failed");
    } finally {
      passwordRemoving = false;
    }
  }

  /**
   * Rotating to a new authenticator. Two steps: prove the current factor to get a
   * pending secret, then prove the new one to swap it in. The old factor stays valid
   * throughout, so a mistyped key is recoverable instead of a lockout.
   */
  function startRotation(): Promise<{ secret: string; otpauthUri: string; expiresIn: number }> {
    return replaceTwoFactor(rotateCode.replace(/\s/g, ""));
  }

  function beginFactorFlow(flow: "enroll" | "replace"): void {
    if (flow === "replace" && !rotateCode.trim()) return;
    freshRecoveryCodes = [];
    factorFlow = flow;
  }

  function endFactorFlow(): void {
    factorFlow = "none";
    factorCodesVisible = false;
    rotateCode = "";
    mfaCode = "";
  }

  /**
   * A failed start has no useful retry: the code the user already submitted is either
   * wrong or spent (the server records accepted codes to block replay), and a TOTP
   * code expires within a step anyway. Drop back to the input so they can enter a
   * fresh one.
   *
   * Enrolment has no such input — its start takes no code — so it keeps the retry.
   */
  function onFactorStartFailed(message: string): void {
    if (factorFlow !== "replace") return;
    factorFlow = "none";
    factorCodesVisible = false;
    rotateCode = "";
    showToast(message === "invalid code" ? "invalid code — enter a fresh one" : message);
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

  /** Recovery codes on screen — closing now loses them for good. */
  const dismissBlocked = $derived(factorCodesVisible || freshRecoveryCodes.length > 0);

  function tryClose(): void {
    if (dismissBlocked) {
      showToast("save your recovery codes first");
      return;
    }
    closeOverlays();
  }

  /**
   * Keeps focus inside the dialog without disabling Tab.
   *
   * The previous handler swallowed Tab entirely, which made every control in here
   * unreachable by keyboard — including, since this change, the whole two-factor
   * setup flow.
   */
  function trapFocus(e: KeyboardEvent): void {
    const focusable = dialogEl?.querySelectorAll<HTMLElement>(
      'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
    );
    if (!focusable || focusable.length === 0) return;

    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    const active = document.activeElement;

    if (e.shiftKey && (active === first || active === dialogEl)) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && active === last) {
      e.preventDefault();
      first.focus();
    }
  }

  function onKeydown(e: KeyboardEvent): void {
    if (e.key === "Escape") {
      e.preventDefault();
      // Shell registers a global Escape -> closeOverlays on window. Without stopping
      // propagation here the event reaches it after tryClose() has declined, and the
      // overlay closes anyway — taking the recovery codes with it. preventDefault
      // alone does not help: that binding does not check defaultPrevented.
      e.stopPropagation();
      tryClose();
    } else if (e.key === "Tab") {
      trapFocus(e);
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="overlay-backdrop" onclick={tryClose}>
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
      {#if needsProof}
        <p class="hint">
          a cli token bypasses two-factor authentication by design, so minting one needs
          your {proofLabel}.
        </p>
      {/if}
      {#if needsProof}
        <div class="field">
          <input
            bind:value={cliReauth}
            type={proof === "code" ? "text" : "password"}
            inputmode={proof === "code" ? "numeric" : undefined}
            autocomplete={proof === "code" ? "one-time-code" : "current-password"}
            placeholder={proofLabel}
            spellcheck="false"
            aria-label={proofLabel}
            disabled={cliGenerating || cliRevoking}
          />
        </div>
      {/if}
      <div class="field">
        {#if hasCliToken}
          <button onclick={regenerateToken} disabled={cliGenerating || cliRevoking || (needsProof && !cliReauth.trim())}>[ regenerate ]</button>
          <button onclick={revokeToken} disabled={cliGenerating || cliRevoking}>[ revoke ]</button>
        {:else}
          <button onclick={generateToken} disabled={cliGenerating || (needsProof && !cliReauth.trim())}>[ generate token ]</button>
        {/if}
      </div>
      {#if hasCliToken}
        <p class="hint">regenerating will invalidate the previous token</p>
      {/if}
    {/if}

    {#if mfaSupported}
      <div class="row">
        <span>two-factor authentication</span>
        <span class="status" class:ok={mfaEnabled} class:missing={!mfaEnabled}>
          {mfaEnabled ? "enabled ✓" : "not set up"}
        </span>
      </div>

      {#if factorFlow !== "none"}
        <TwoFactorSetup
          title={factorFlow === "replace" ? "move to a new authenticator" : "set up two-factor authentication"}
          start={factorFlow === "replace" ? startRotation : enrollTwoFactor}
          finish={factorFlow === "replace" ? activateReplacement : activateTwoFactor}
          onDone={endFactorFlow}
          onCancel={endFactorFlow}
          onStartFailed={onFactorStartFailed}
          bind:codesVisible={factorCodesVisible}
        />
      {:else if mfaEnabled}
        {#if recoveryRemaining != null}
          <p class="hint">{recoveryRemaining} recovery code{recoveryRemaining === 1 ? "" : "s"} remaining</p>
        {/if}

        {#if freshRecoveryCodes.length > 0}
          <p class="hint warning">shown once only — save these now</p>
          <ul class="codes">
            {#each freshRecoveryCodes as recoveryCode (recoveryCode)}
              <li>{recoveryCode}</li>
            {/each}
          </ul>
          <div class="field">
            <button onclick={() => copyPlain(freshRecoveryCodes.join("\n"))}>[ copy ]</button>
            <button onclick={() => (freshRecoveryCodes = [])}>[ done ]</button>
          </div>
        {:else}
          <p class="hint">enter a current authenticator or recovery code to make changes</p>
          <div class="field">
            <!-- Not maxlength=7: recovery codes are valid here too (contract §2.4) and
                 are far longer, so a numeric-width cap would silently make them
                 untypeable. The extra headroom over the code length also means a
                 pasted code with a stray space is not truncated before the handler
                 strips it. -->
            <input
              bind:value={mfaCode}
              type="text"
              autocomplete="one-time-code"
              maxlength="40"
              placeholder="000000"
              spellcheck="false"
              aria-label="Authenticator or recovery code"
              disabled={mfaBusy}
            />
            <button onclick={regenerateCodes} disabled={!mfaCode.trim() || mfaBusy}>[ new recovery codes ]</button>
          </div>
          {#if !mfaRequired}
            <div class="field">
              <button onclick={turnOffTwoFactor} disabled={!mfaCode.trim() || mfaBusy}>[ disable 2fa ]</button>
            </div>
          {:else}
            <p class="hint">two-factor authentication is required and cannot be disabled</p>
          {/if}

          <p class="hint">
            got a new phone? rotate without losing access — the current authenticator
            keeps working until the new one is confirmed.
          </p>
          <div class="field">
            <!-- No numeric inputmode: the audience for rotation includes people whose
                 phone is gone, and the server accepts a recovery code here too. -->
            <input
              bind:value={rotateCode}
              type="text"
              autocomplete="one-time-code"
              maxlength="40"
              placeholder="current authenticator or recovery code"
              spellcheck="false"
              aria-label="Current authenticator or recovery code"
              disabled={mfaBusy}
            />
            <button onclick={() => beginFactorFlow("replace")} disabled={!rotateCode.trim() || mfaBusy}>
              [ new authenticator ]
            </button>
          </div>
        {/if}
      {:else}
        <p class="hint">
          {mfaRequired
            ? "required — set this up now, or you will be prompted at next sign-in"
            : "protects your account even if your password is stolen"}
        </p>
        <div class="field">
          <button onclick={() => beginFactorFlow("enroll")}>[ set up 2fa ]</button>
        </div>
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
        placeholder="password (min {MIN_PASSWORD_LENGTH} chars)"
        autocomplete="new-password"
        spellcheck="false"
        aria-label="Password"
        disabled={passwordSaving || passwordRemoving}
      />
    </div>
    {#if needsProof}
      <div class="field">
        <input
          bind:value={setPasswordReauth}
          type={proof === "code" ? "text" : "password"}
          inputmode={proof === "code" ? "numeric" : undefined}
          autocomplete={proof === "code" ? "one-time-code" : "current-password"}
          placeholder={proofLabel}
          spellcheck="false"
          aria-label="Confirm with {proofLabel}"
          disabled={passwordSaving || passwordRemoving}
        />
      </div>
    {/if}
    <div class="field">
      <button onclick={savePassword} disabled={!passwordUsername.trim() || passwordTooShort || !passwordValue.trim() || passwordSaving || passwordRemoving || (needsProof && !setPasswordReauth.trim())}>
        {hasPassword ? "[ update ]" : "[ set ]"}
      </button>
    </div>
    {#if passwordTooShort}
      <p class="hint warning">password must be at least {MIN_PASSWORD_LENGTH} characters</p>
    {/if}
    <p class="hint">changing this signs out every other session</p>
    {#if hasPassword}
      {#if needsProof}
        <div class="field">
          <input
            bind:value={removePasswordReauth}
            type={proof === "code" ? "text" : "password"}
            inputmode={proof === "code" ? "numeric" : undefined}
            autocomplete={proof === "code" ? "one-time-code" : "current-password"}
            placeholder={proofLabel}
            spellcheck="false"
            aria-label="Confirm removal with {proofLabel}"
            disabled={passwordSaving || passwordRemoving}
          />
        </div>
      {/if}
      <div class="field">
        <button onclick={removePassword} disabled={passwordSaving || passwordRemoving || (needsProof && !removePasswordReauth.trim())}>[ remove password ]</button>
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

  .codes {
    display: grid;
    grid-template-columns: repeat(2, max-content);
    gap: var(--sp-1) var(--sp-3);
    margin: var(--sp-2) 0 0;
    padding: var(--sp-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    list-style: none;
    font-family: monospace;
  }
</style>
