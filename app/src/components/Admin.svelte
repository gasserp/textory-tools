<script lang="ts">
  import { onMount } from "svelte";
  import { adminState, loadAdminUsers, setUserStatus, setUserQuota, type AdminUser } from "../lib/admin.svelte";
  import { session } from "../lib/stores.svelte";
  import { closeOverlays } from "../lib/overlay.svelte";
  import { showToast } from "../lib/toast.svelte";

  let dialogEl: HTMLDivElement | undefined = $state();
  let quotaEdits = $state<Record<string, string>>({});
  let busy = $state<string | null>(null);

  onMount(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    dialogEl?.focus();
    loadAdminUsers().catch((e) => showToast(e instanceof Error ? e.message : "failed to load users"));
    return () => previousFocus?.focus();
  });

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleDateString();
  }

  function quotaKb(bytes: number): number {
    return Math.round(bytes / 1024);
  }

  function quotaInputValue(user: AdminUser): string {
    return quotaEdits[user.id] ?? String(quotaKb(user.quotaBytes));
  }

  async function approve(user: AdminUser): Promise<void> {
    busy = user.id;
    try {
      await setUserStatus(user.id, "approved");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "approve failed");
    } finally {
      busy = null;
    }
  }

  async function reject(user: AdminUser): Promise<void> {
    busy = user.id;
    try {
      await setUserStatus(user.id, "rejected");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "reject failed");
    } finally {
      busy = null;
    }
  }

  async function saveQuota(user: AdminUser): Promise<void> {
    const raw = quotaEdits[user.id];
    if (raw === undefined) return;
    const kb = Number(raw);
    if (!Number.isFinite(kb)) {
      showToast("quota must be a number");
      return;
    }
    const bytes = Math.round(kb * 1024);
    busy = user.id;
    try {
      await setUserQuota(user.id, bytes);
      const { [user.id]: _removed, ...rest } = quotaEdits;
      quotaEdits = rest;
    } catch (e) {
      showToast(e instanceof Error ? e.message : "quota update failed");
    } finally {
      busy = null;
    }
  }

  function onQuotaKeydown(e: KeyboardEvent, user: AdminUser): void {
    if (e.key === "Enter") {
      e.preventDefault();
      saveQuota(user);
    }
  }

  function onKeydown(e: KeyboardEvent): void {
    if (e.key === "Escape") {
      e.preventDefault();
      closeOverlays();
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="overlay-backdrop" onclick={closeOverlays}>
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="admin"
    bind:this={dialogEl}
    role="dialog"
    aria-modal="true"
    aria-label="Admin"
    tabindex="-1"
    onkeydown={onKeydown}
    onclick={(e) => e.stopPropagation()}
  >
    <h2>admin: users</h2>

    {#if !adminState.loaded}
      <p class="hint">loading...</p>
    {:else}
      <div class="table">
        <div class="row header">
          <span class="col-login">login</span>
          <span class="col-status">status</span>
          <span class="col-quota">used / quota (kb)</span>
          <span class="col-created">created</span>
          <span class="col-actions">actions</span>
        </div>
        {#each adminState.users as user (user.id)}
          <div class="row" class:pending={user.status === "pending"}>
            <span class="col-login">{user.githubLogin}{#if user.role === "admin"}<span class="role"> [admin]</span>{/if}</span>
            <span class="col-status">{user.status}</span>
            <span class="col-quota">
              {quotaKb(user.usedBytes)} /
              <input
                class="quota-input"
                type="number"
                min="1"
                value={quotaInputValue(user)}
                oninput={(e) => (quotaEdits = { ...quotaEdits, [user.id]: (e.target as HTMLInputElement).value })}
                onkeydown={(e) => onQuotaKeydown(e, user)}
                onblur={() => saveQuota(user)}
                disabled={busy === user.id}
                aria-label={`quota for ${user.githubLogin} in KB`}
              />
            </span>
            <span class="col-created">{formatDate(user.createdAt)}</span>
            <span class="col-actions">
              <button
                onclick={() => approve(user)}
                disabled={busy === user.id || user.status === "approved" || (user.id === session.user?.id)}
              >[ approve ]</button>
              <button
                onclick={() => reject(user)}
                disabled={busy === user.id || user.status === "rejected" || (user.id === session.user?.id)}
              >[ reject ]</button>
            </span>
          </div>
        {:else}
          <div class="empty">no users</div>
        {/each}
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

  .admin {
    width: min(820px, 95vw);
    max-height: 85vh;
    overflow-y: auto;
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

  .table {
    display: flex;
    flex-direction: column;
  }

  .row {
    display: grid;
    grid-template-columns: 1.5fr 1fr 1.5fr 1fr 1.5fr;
    gap: var(--sp-2);
    align-items: center;
    padding: var(--sp-1) var(--sp-2);
    border-bottom: 1px dotted var(--border);
    font-size: 0.9em;
  }

  .row.header {
    color: var(--fg-dim);
    border-bottom: 1px solid var(--border);
    font-size: 0.85em;
  }

  .row.pending {
    background: color-mix(in srgb, var(--accent) 12%, transparent);
    border-left: 2px solid var(--accent);
  }

  .role {
    color: var(--fg-dim);
    font-size: 0.85em;
  }

  .quota-input {
    width: 5em;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: 0 var(--sp-1);
  }

  .col-actions {
    display: flex;
    gap: var(--sp-1);
  }

  .col-actions button {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--fg);
    font: inherit;
    padding: 0 var(--sp-1);
    cursor: pointer;
  }

  .col-actions button:hover:not(:disabled) {
    border-color: var(--accent);
    color: var(--accent);
  }

  .col-actions button:disabled {
    color: var(--fg-dim);
    cursor: not-allowed;
  }

  .hint {
    margin: var(--sp-3) 0 0;
    color: var(--fg-dim);
    font-size: 0.85em;
    text-align: center;
  }

  .empty {
    color: var(--fg-dim);
    padding: var(--sp-2);
    text-align: center;
  }
</style>
