<script lang="ts">
  import type { EnrollResponse } from "../lib/stores.svelte";
  import { showToast } from "../lib/toast.svelte";
  import { copyPlain } from "../lib/clipboard";

  /**
   * Shared by three flows that are the same six steps with different endpoints:
   * the enrolment wall, voluntary enrolment from Settings, and moving to a new
   * authenticator. The caller supplies start/finish so this component never has to
   * know which it is — and so the "save your recovery codes" screen, the part that
   * locks people out when it is skipped, cannot be forgotten by one of them.
   */
  let {
    title,
    start,
    finish,
    onDone,
    onCancel,
    cancelLabel = "cancel",
    onStartFailed,
    codesVisible = $bindable(false),
  }: {
    title: string;
    start: () => Promise<EnrollResponse>;
    finish: (code: string) => Promise<string[]>;
    onDone: () => void;
    onCancel?: () => void;
    cancelLabel?: string;
    /**
     * Called instead of rendering the retry screen when start() fails. Retrying is
     * useless where the caller's input is already spent — a TOTP code that has been
     * submitted once is either wrong or claimed in the server's replay ledger, so the
     * caller needs to collect a fresh one.
     */
    onStartFailed?: (message: string) => void;
    /**
     * Lets a host block its own dismiss affordances while the codes are on screen.
     * The component hides its cancel button then, but an overlay that closes on Esc
     * or a backdrop click would still discard codes that are the account's only way
     * back in — and by this point the previous set is already invalid server-side.
     */
    codesVisible?: boolean;
  } = $props();

  let secret = $state("");
  let otpauthUri = $state("");
  let qrPath = $state("");
  let qrSize = $state(0);
  let code = $state("");
  let recoveryCodes: string[] = $state([]);
  let acknowledged = $state(false);
  let loading = $state(true);
  let submitting = $state(false);

  const showingCodes = $derived(recoveryCodes.length > 0);

  $effect(() => {
    codesVisible = showingCodes;
  });

  /**
   * Build an SVG path from the QR matrix.
   *
   * The `d` string is derived from booleans, never from the secret as text, so there is
   * no `{@html}` and nothing for a sanitizer to get wrong. Rendering locally also keeps
   * the TOTP seed off any third party — a QR-image service would be handed the seed
   * outright (and both CSPs block it anyway).
   *
   * QUIET_ZONE is 4 modules per the QR spec; uqr defaults to 1, which many scanners
   * reject.
   */
  const QUIET_ZONE = 4;

  function buildPath(matrix: boolean[][]): string {
    let d = "";
    for (let y = 0; y < matrix.length; y++) {
      for (let x = 0; x < matrix[y].length; x++) {
        if (matrix[y][x]) d += `M${x + QUIET_ZONE} ${y + QUIET_ZONE}h1v1h-1z`;
      }
    }
    return d;
  }

  async function begin(): Promise<void> {
    loading = true;
    try {
      const response = await start();
      if (!response?.secret || !response?.otpauthUri) throw new Error("could not start setup");
      secret = response.secret;
      otpauthUri = response.otpauthUri;
      // Lazy so the encoder lands in its own chunk rather than the main bundle.
      const { encode } = await import("uqr");
      const qr = encode(response.otpauthUri, { border: 0 });
      qrSize = qr.size + QUIET_ZONE * 2;
      qrPath = buildPath(qr.data);
    } catch (e) {
      const message = e instanceof Error ? e.message : "could not start setup";
      showToast(message);
      onStartFailed?.(message);
    } finally {
      loading = false;
    }
  }

  async function confirm(): Promise<void> {
    const entered = code.replace(/\s/g, "");
    if (!entered || submitting) return;
    submitting = true;
    try {
      const issued = await finish(entered);
      if (!Array.isArray(issued) || issued.length === 0) {
        throw new Error("two-factor is enabled, but the recovery codes could not be shown — generate a new set in settings");
      }
      recoveryCodes = issued;
      // The pending secret is dead once activated; don't keep it around.
      secret = "";
      otpauthUri = "";
      qrPath = "";
      code = "";
    } catch (e) {
      // Only a genuine rejection is "invalid code". Anything else (notably the
      // codes-missing case above) would otherwise send the user round a retry loop
      // that cannot succeed, because the factor is already active.
      const message = e instanceof Error ? e.message : "";
      showToast(message.includes("recovery codes") ? message : "invalid code");
    } finally {
      submitting = false;
    }
  }

  function download(): void {
    const blob = new Blob([recoveryCodes.join("\n") + "\n"], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "textory-recovery-codes.txt";
    a.click();
    URL.revokeObjectURL(url);
  }

  begin();
</script>

<div class="setup">
  <h2>{title}</h2>

  {#if showingCodes}
    <p>save these recovery codes. each works once, and they are the only way back in if you lose your authenticator.</p>
    <p class="hint warning">shown once — they will not be displayed again.</p>

    <ul class="codes">
      {#each recoveryCodes as recoveryCode (recoveryCode)}
        <li>{recoveryCode}</li>
      {/each}
    </ul>

    <div class="actions">
      <button onclick={() => copyPlain(recoveryCodes.join("\n"))}>[ copy ]</button>
      <button onclick={download}>[ download ]</button>
    </div>
    <p class="hint">
      copying or downloading leaves these codes in your clipboard history or your downloads folder in
      plain text — treat them like a password and move them somewhere safe.
    </p>

    <p class="accept">
      <label>
        <input type="checkbox" bind:checked={acknowledged} />
        I have saved my recovery codes
      </label>
    </p>
    <div class="actions">
      <button disabled={!acknowledged} onclick={() => { recoveryCodes = []; onDone(); }}>[ continue ]</button>
    </div>
  {:else if loading}
    <p>setting up…</p>
  {:else if secret}
    <p>scan this with your authenticator app, then enter the code it shows.</p>

    {#if qrPath}
      <!-- Forced dark-on-light: `currentColor` would invert the QR in the dark themes,
           and inverted codes are rejected by many scanners. -->
      <svg
        class="qr"
        viewBox="0 0 {qrSize} {qrSize}"
        width="200"
        height="200"
        shape-rendering="crispEdges"
        role="img"
        aria-label="Authenticator setup QR code"
      >
        <rect width={qrSize} height={qrSize} fill="#ffffff" />
        <path d={qrPath} fill="#000000" />
      </svg>
    {/if}

    <p class="hint">or enter this key manually:</p>
    <div class="field">
      <input type="text" value={secret} readonly spellcheck="false" class="monospace" aria-label="Setup key" />
      <button onclick={() => copyPlain(secret)}>[ copy ]</button>
    </div>

    <form class="field" onsubmit={(e) => { e.preventDefault(); confirm(); }}>
      <input
        bind:value={code}
        type="text"
        inputmode="numeric"
        autocomplete="one-time-code"
        maxlength="7"
        placeholder="000000"
        spellcheck="false"
        aria-label="Verification code"
      />
      <button type="submit" disabled={!code.trim() || submitting}>[ verify ]</button>
    </form>
  {:else}
    <p>could not start two-factor setup.</p>
    <div class="actions">
      <button onclick={begin}>[ retry ]</button>
    </div>
  {/if}

  {#if !showingCodes && onCancel}
    <div class="actions">
      <button class="link" onclick={onCancel}>[ {cancelLabel} ]</button>
    </div>
  {/if}
</div>

<style>
  .setup {
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

  .qr {
    align-self: flex-start;
    border: var(--sp-1) solid #ffffff;
    border-radius: var(--radius);
  }

  .codes {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--sp-1) var(--sp-3);
    margin: 0;
    padding: var(--sp-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    list-style: none;
    font-family: monospace;
  }

  .codes li {
    overflow-wrap: anywhere;
  }

  .field {
    display: flex;
    gap: var(--sp-2);
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

  .actions {
    display: flex;
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

  .accept label {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    cursor: pointer;
  }

  .hint {
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  .hint.warning {
    color: var(--warning, #ff9500);
  }

  .monospace {
    font-family: monospace;
  }
</style>
