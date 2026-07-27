<script lang="ts">
  import { session } from "../lib/stores.svelte";
  import { currentCapabilities } from "../lib/capabilities";
  import { openSettings } from "../lib/overlay.svelte";

  /**
   * Nudges users to enrol before 2FA becomes mandatory.
   *
   * The point of the staged rollout is that people enrol on their own terms rather
   * than all hitting the wall at once on the day enforcement flips. Without an actual
   * prompt, "voluntary enrolment" produces zero enrolled users.
   *
   * Dismissal is per browser session, not permanent: this needs to still be there
   * tomorrow if it was ignored today, and a permanently dismissible warning about a
   * deadline is just a hidden one.
   */
  const DISMISS_KEY = "textory:enroll-banner-dismissed";

  let dismissed = $state(read());

  function read(): boolean {
    try {
      return sessionStorage.getItem(DISMISS_KEY) === "1";
    } catch {
      // Private mode / storage disabled — showing the banner is the safe default.
      return false;
    }
  }

  function dismiss(): void {
    dismissed = true;
    try {
      sessionStorage.setItem(DISMISS_KEY, "1");
    } catch {
      // Dismissal just won't persist; the in-memory flag still hides it for now.
    }
  }

  const mfa = $derived(currentCapabilities().mfa);
  // Only while it is still optional: once required, the wall does the talking, and a
  // banner on a screen the user can already use would be describing the wrong state.
  const visible = $derived(!dismissed && mfa === "optional" && session.user?.mfaEnabled !== true);
</script>

{#if visible}
  <div class="banner" role="status">
    <span>
      two-factor authentication is not set up. it will be required soon — setting it up
      now avoids being interrupted later.
    </span>
    <span class="actions">
      <button onclick={openSettings}>[ set up ]</button>
      <button class="link" onclick={dismiss} aria-label="Dismiss">[ later ]</button>
    </span>
  </div>
{/if}

<style>
  .banner {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: var(--sp-2);
    margin-bottom: var(--sp-2);
    padding: var(--sp-1) var(--sp-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg-dim);
    font-size: 0.85em;
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
    padding: 0 var(--sp-1);
    cursor: pointer;
  }

  button:hover {
    border-color: var(--accent);
    color: var(--accent);
  }

  button.link {
    border-color: transparent;
    padding: 0;
    color: var(--fg-dim);
  }
</style>
