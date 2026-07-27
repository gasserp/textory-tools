<script lang="ts">
  import { onMount } from "svelte";
  import {
    activateTwoFactor,
    completeMfaEnrollment,
    enrollTwoFactor,
    loadSession,
    logout,
    requestAccess,
    session,
  } from "./lib/stores.svelte";
  import { currentCapabilities } from "./lib/capabilities";
  import { isNative } from "./lib/runtime";
  import Shell from "./components/Shell.svelte";
  import Terms from "./components/Terms.svelte";
  import Privacy from "./components/Privacy.svelte";
  import Login from "./components/Login.svelte";
  import TwoFactorSetup from "./components/TwoFactorSetup.svelte";
  import TwoFactorStepUp from "./components/TwoFactorStepUp.svelte";
  import EnrollBanner from "./components/EnrollBanner.svelte";
  import Main from "./Main.svelte";

  let showTerms = $state(false);
  let showPrivacy = $state(false);
  let acceptedTerms = $state(false);

  // On the web the password form appears only once the API says it can issue a cookie
  // session for one. Until then this is exactly today's GitHub-SSO-only screen.
  const showPasswordLogin = $derived(isNative || currentCapabilities().webPasswordLogin);
  // Password sessions aren't cleared by the SWA /logout redirect, so they need a real
  // sign-out control of their own.
  const showLogout = $derived(isNative || currentCapabilities().webPasswordLogin);

  /**
   * The server says a factor already exists, so this tab's `me` was stale and the user
   * belongs on the step-up screen, not enrolment. Refreshing re-evaluates the branch
   * above; without it the retry button re-requests enrolment and 409s forever.
   */
  async function onEnrollStartFailed(message: string): Promise<void> {
    if (message === "2fa already enabled") await loadSession();
  }

  onMount(loadSession);
</script>

<Shell>
  {#if session.status === "loading"}
    <p>textory ▌</p>
  {:else if session.status === "anonymous" || session.status === "mfa_challenge"}
    <p>textory ▌</p>
    {#if showPasswordLogin}
      <Login />
    {/if}
    {#if !isNative && session.status === "anonymous"}
      <a href="/login">[ sign in with github ]</a>
    {/if}
  {:else if session.status === "mfa_enrollment"}
    <!-- Must precede "approved": otherwise an unenrolled user just reloads into the app. -->
    {#if session.user?.mfaEnabled}
      <!-- Already has a factor, this session just hasn't proved it (every GitHub-SSO
           session, always). Sending them to enrolment would dead-end: /2fa/enroll
           refuses while a factor is active. -->
      <TwoFactorStepUp />
    {:else}
      <TwoFactorSetup
        title="two-factor authentication required"
        start={enrollTwoFactor}
        finish={activateTwoFactor}
        onDone={completeMfaEnrollment}
        onCancel={logout}
        cancelLabel="sign out"
        onStartFailed={onEnrollStartFailed}
      />
    {/if}
  {:else if session.status === "unregistered"}
    <p>textory ▌ — a fast, console-style snippet manager. beta access is admin-approved.</p>
    <p>
      <button onclick={() => (showTerms = !showTerms)}>[ {showTerms ? "hide" : "view"} terms ]</button>
      <button onclick={() => (showPrivacy = !showPrivacy)}>[ {showPrivacy ? "hide" : "view"} privacy ]</button>
    </p>
    {#if showTerms}
      <Terms />
    {/if}
    {#if showPrivacy}
      <Privacy />
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
    {#if showLogout}
      <button onclick={logout}>[ log out ]</button>
    {/if}
  {:else if session.status === "rejected"}
    <p>access denied</p>
    {#if showLogout}
      <button onclick={logout}>[ log out ]</button>
    {/if}
  {:else if session.status === "approved"}
    {#if isNative}
      <div class="native-bar">
        <button onclick={logout}>[ log out ]</button>
      </div>
    {/if}
    <EnrollBanner />
    <Main />
  {:else}
    <!-- Catch-all: an unrecognised status must not render a blank page. -->
    <p>textory ▌</p>
    <p>unexpected session state — please reload.</p>
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
