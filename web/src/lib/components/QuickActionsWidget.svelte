<script>
  import { portal } from '../actions/portal.js';
  import { dashboardLayout } from '../stores/dashboardLayout.svelte.js';
  import {
    Zap,
    Settings2,
    SlidersHorizontal,
    ChevronUp,
    ChevronDown,
    X,
    RotateCcw,
    Car,
    MapPin,
    Navigation,
    Siren,
    Shield,
    AlertTriangle,
    FileText,
    Plus,
  } from '@lucide/svelte';
  import {
    quickActionsStore,
    QUICK_ACTION_CATALOG,
  } from '../stores/quickActions.svelte.js';

  const ICONS = {
    Car,
    MapPin,
    Navigation,
    Siren,
    Shield,
    AlertTriangle,
    FileText,
  };

  let qa = quickActionsStore;
  let settingsOpen = $state(false);
  let addSelect = $state('');

  let rows = $derived(qa.order.map((id) => qa.getDef(id)).filter(Boolean));
  let pool = $derived(QUICK_ACTION_CATALOG.filter((a) => !qa.order.includes(a.id)));

  function iconFor(id) {
    const def = qa.getDef(id);
    const I = def ? ICONS[def.icon] : FileText;
    return I || FileText;
  }

  async function onRun(id) {
    await qa.runAction(id);
  }

  function onAddSelected() {
    if (!addSelect) return;
    qa.addToOrder(addSelect);
    addSelect = pool.filter((p) => p.id !== addSelect)[0]?.id || '';
  }
</script>

<div class="panel quick-actions-panel">
  <div class="panel-header">
    <div class="panel-title-row">
      <Zap size={13} class="panel-icon" />
      <h2 class="panel-title">Quick Actions</h2>
    </div>
    <div class="qa-header-actions">
      <button
        type="button"
        class="qa-header-btn"
        onclick={() => dashboardLayout.openCustomizer()}
        title="Dashboard layout & widgets"
        aria-label="Customize dashboard layout"
      >
        <SlidersHorizontal size={14} />
      </button>
      <button
        type="button"
        class="qa-header-btn"
        onclick={() => (settingsOpen = true)}
        title="Configure quick actions & hotkeys"
        aria-label="Quick actions settings"
      >
        <Settings2 size={15} />
      </button>
    </div>
  </div>

  <div class="qa-grid">
    {#each rows as def (def.id)}
      {@const Icon = iconFor(def.id)}
      {@const hk = qa.hotkeys[def.id]}
      <button type="button" class="qa-tile" onclick={() => onRun(def.id)} title={def.description}>
        <div class="qa-ico" aria-hidden="true">
          <Icon size="100%" />
        </div>
        <div class="qa-tile-main">
          <span class="qa-label">{def.label}</span>
          {#if hk}
            <span class="qa-hk font-mono">{hk}</span>
          {/if}
        </div>
      </button>
    {:else}
      <div class="qa-grid-empty">No actions — open settings to add.</div>
    {/each}
  </div>
</div>

{#if settingsOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="qa-overlay"
    use:portal
    onclick={(e) => e.target === e.currentTarget && (settingsOpen = false)}
    role="presentation"
  >
    <div class="qa-modal" role="dialog" aria-modal="true" aria-label="Quick actions settings">
      <div class="qa-modal-head">
        <div>
          <h3 class="qa-modal-title">Quick Actions</h3>
          <p class="qa-modal-sub">Reorder, hotkeys (e.g. Ctrl+Alt+1), add/remove from bar.</p>
        </div>
        <button type="button" class="qa-icon-btn" onclick={() => (settingsOpen = false)} title="Close">
          <X size={15} />
        </button>
      </div>

      <div class="qa-modal-body">
        <div class="qa-add-row">
          <select class="qa-select font-mono" bind:value={addSelect}>
            <option value="">Add to bar…</option>
            {#each pool as p (p.id)}
              <option value={p.id}>{p.label}</option>
            {/each}
          </select>
          <button type="button" class="qa-add-btn" disabled={!addSelect} onclick={onAddSelected}>
            <Plus size={14} />
            Add
          </button>
        </div>

        <div class="qa-rows">
          {#each qa.order as id, idx (id)}
            {@const def = qa.getDef(id)}
            {#if def}
              <div class="qa-config-row">
                <div class="qa-config-main">
                  <span class="qa-config-label">{def.label}</span>
                  <span class="qa-config-desc">{def.description}</span>
                </div>
                <div class="qa-reorder">
                  <button
                    type="button"
                    class="qa-mini"
                    disabled={idx === 0}
                    onclick={() => qa.moveInOrder(id, -1)}
                    title="Move up"
                  >
                    <ChevronUp size={14} />
                  </button>
                  <button
                    type="button"
                    class="qa-mini"
                    disabled={idx >= qa.order.length - 1}
                    onclick={() => qa.moveInOrder(id, 1)}
                    title="Move down"
                  >
                    <ChevronDown size={14} />
                  </button>
                </div>
                <input
                  class="qa-hotkey-input font-mono"
                  type="text"
                  placeholder="Hotkey"
                  value={qa.hotkeys[id] || ''}
                  oninput={(e) => qa.setHotkey(id, e.currentTarget.value)}
                />
                <button type="button" class="qa-remove" onclick={() => qa.removeFromOrder(id)} title="Remove from bar">
                  Remove
                </button>
              </div>
            {/if}
          {/each}
        </div>
      </div>

      <div class="qa-modal-foot">
        <button type="button" class="qa-reset" onclick={() => qa.resetLayout()}>
          <RotateCcw size={13} />
          Reset defaults
        </button>
        <button type="button" class="qa-done" onclick={() => (settingsOpen = false)}>Done</button>
      </div>
    </div>
  </div>
{/if}

<svelte:window
  onkeydown={(e) => {
    if (e.key === 'Escape' && settingsOpen) {
      settingsOpen = false;
    }
  }}
/>

<style>
  .quick-actions-panel {
    display: flex;
    flex-direction: column;
    min-height: 0;
    container-type: inline-size;
    container-name: qa;
  }

  /* Dashboard .panel-header is scoped to Dashboard.svelte — child component needs own row layout */
  .quick-actions-panel .panel-header {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    padding: 0 0 calc(3px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border-2) 70%, transparent);
    flex-shrink: 0;
    gap: calc(6px * var(--mdt-scale));
    flex-wrap: nowrap;
    min-height: calc(28px * var(--mdt-scale));
  }

  .quick-actions-panel .panel-title-row {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: nowrap;
    min-width: 0;
  }

  .quick-actions-panel .panel-title {
    margin: 0;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-dim);
    text-transform: uppercase;
    letter-spacing: 0.07em;
  }

  .quick-actions-panel :global(.panel-title-row svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .qa-header-actions {
    display: flex;
    align-items: center;
    gap: calc(2px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .qa-header-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    padding: 0;
    border: none;
    background: transparent;
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition:
      color 0.15s ease,
      transform 0.12s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .qa-header-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .qa-header-btn:hover {
    color: var(--mdt-accent);
    background: transparent;
    box-shadow: none;
  }

  .qa-header-btn:active {
    transform: scale(0.96);
  }

  .qa-grid {
    display: grid;
    width: 100%;
    box-sizing: border-box;
    grid-template-columns: repeat(
      auto-fit,
      minmax(min(100%, calc(76px * var(--mdt-scale))), 1fr)
    );
    gap: calc(4px * var(--mdt-scale));
    padding: calc(2px * var(--mdt-scale)) calc(4px * var(--mdt-scale)) 0;
    align-items: stretch;
  }

  .qa-grid-empty {
    grid-column: 1 / -1;
    margin: 0;
    padding: calc(8px * var(--mdt-scale)) 0;
    text-align: center;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-style: italic;
  }

  @container qa (max-width: 320px) {
    .qa-grid {
      grid-template-columns: 1fr;
    }
  }

  .qa-tile {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    min-height: calc(34px * var(--mdt-scale));
    min-width: 0;
    width: 100%;
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    cursor: pointer;
    text-align: center;
    font: inherit;
    color: var(--mdt-text);
    transition:
      background 0.15s ease,
      border-color 0.15s ease,
      box-shadow 0.15s ease;
  }

  .qa-tile:hover {
    background: var(--mdt-surface-3);
    border-color: color-mix(in srgb, var(--mdt-accent) 28%, var(--mdt-border));
    box-shadow: 0 0 0 1px color-mix(in srgb, var(--mdt-accent) 14%, transparent);
  }

  .qa-tile-main {
    flex: 0 1 auto;
    min-width: 0;
    max-width: 100%;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: calc(1px * var(--mdt-scale));
    line-height: 1.15;
  }

  .qa-ico {
    flex-shrink: 0;
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0.92;
  }

  .qa-ico :global(svg) {
    width: 100%;
    height: 100%;
  }

  .qa-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    line-height: 1.25;
    max-width: 100%;
    overflow: hidden;
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
    white-space: normal;
    word-break: break-word;
  }

  .qa-hk {
    font-size: calc(8px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.03em;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  @container qa (max-width: 160px) {
    .qa-tile {
      padding-inline: calc(5px * var(--mdt-scale));
      gap: calc(4px * var(--mdt-scale));
    }

    .qa-ico {
      width: calc(14px * var(--mdt-scale));
      height: calc(14px * var(--mdt-scale));
    }

    .qa-label {
      font-size: calc(9px * var(--mdt-scale));
    }
  }

  .qa-overlay {
    position: fixed;
    inset: 0;
    z-index: 10000;
    background: rgba(0, 0, 0, 0.55);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: calc(16px * var(--mdt-scale));
  }

  .qa-modal {
    width: min(calc(440px * var(--mdt-scale)), 100%);
    max-height: min(80vh, calc(560px * var(--mdt-scale)));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border-2);
    border-radius: calc(10px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow:
      0 0 0 1px rgba(0, 255, 204, 0.06),
      0 calc(20px * var(--mdt-scale)) calc(40px * var(--mdt-scale)) rgba(0, 0, 0, 0.55);
  }

  .qa-modal-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
  }

  .qa-modal-title {
    margin: 0;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 700;
  }

  .qa-modal-sub {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.35;
  }

  .qa-icon-btn {
    border: none;
    background: transparent;
    color: var(--mdt-text-muted);
    cursor: pointer;
    padding: calc(4px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
  }

  .qa-icon-btn:hover {
    color: var(--mdt-text);
    background: var(--mdt-surface-3);
  }

  .qa-modal-body {
    padding: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }

  .qa-add-row {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
  }

  .qa-select {
    flex: 1;
    min-width: 0;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-size: calc(11px * var(--mdt-scale));
  }

  .qa-add-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 40%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-accent) 8%, var(--mdt-surface-2));
    color: var(--mdt-accent);
    font: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
  }

  .qa-add-btn:disabled {
    opacity: 0.45;
    cursor: default;
  }

  .qa-rows {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .qa-config-row {
    display: grid;
    grid-template-columns: 1fr auto minmax(calc(100px * var(--mdt-scale)), 1.1fr) auto;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
    padding: calc(10px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface-2);
  }

  @media (max-width: 520px) {
    .qa-config-row {
      grid-template-columns: 1fr;
    }
  }

  .qa-config-main {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .qa-config-label {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
  }

  .qa-config-desc {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.3;
  }

  .qa-reorder {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .qa-mini {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(26px * var(--mdt-scale));
    height: calc(22px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-3);
    color: var(--mdt-text-dim);
    cursor: pointer;
    padding: 0;
  }

  .qa-mini:disabled {
    opacity: 0.35;
    cursor: default;
  }

  .qa-mini:hover:not(:disabled) {
    color: var(--mdt-accent);
  }

  .qa-hotkey-input {
    width: 100%;
    min-width: 0;
    padding: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-bg);
    color: var(--mdt-text);
    font-size: calc(10px * var(--mdt-scale));
  }

  .qa-remove {
    border: none;
    background: transparent;
    color: var(--mdt-text-muted);
    font-size: calc(10px * var(--mdt-scale));
    cursor: pointer;
    text-decoration: underline;
    text-underline-offset: 2px;
    white-space: nowrap;
  }

  .qa-remove:hover {
    color: var(--mdt-error);
  }

  .qa-modal-foot {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
  }

  .qa-reset {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    border: none;
    background: transparent;
    color: var(--mdt-text-muted);
    font: inherit;
    font-size: calc(11px * var(--mdt-scale));
    cursor: pointer;
  }

  .qa-reset:hover {
    color: var(--mdt-text);
  }

  .qa-done {
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-accent) 12%, var(--mdt-surface-2));
    color: var(--mdt-accent);
    font: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
  }
</style>
