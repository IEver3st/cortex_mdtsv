<script>
  import { dashboardLayout, WIDGET_DEFS } from '../stores/dashboardLayout.svelte.js';
  import { LayoutDashboard, Eye, EyeOff, RotateCcw, X, Check, Grip } from '@lucide/svelte';

  let layout = dashboardLayout;

  const GROUPS = [
    { id: 'header', label: 'Header Row', icon: '▬' },
    { id: 'left', label: 'Left Column', icon: '▧' },
    { id: 'right', label: 'Right Column', icon: '▨' },
  ];

  function groupWidgets(groupId) {
    return WIDGET_DEFS.filter((w) => w.group === groupId);
  }

  function handleOverlayClick(e) {
    if (e.target === e.currentTarget) {
      layout.closeCustomizer();
    }
  }

  function handleKeydown(e) {
    if (e.key === 'Escape') layout.closeCustomizer();
  }

  let visibleCount = $derived(
    WIDGET_DEFS.filter((w) => layout.isVisible(w.id)).length
  );
</script>

<svelte:window onkeydown={handleKeydown} />

{#if layout.customizerOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="customizer-overlay" onclick={handleOverlayClick}>
    <div class="customizer-panel" role="dialog" aria-label="Dashboard Customizer" aria-modal="true">

      <!-- Header -->
      <div class="cust-header">
        <div class="cust-header-left">
          <div class="cust-icon-wrap">
            <LayoutDashboard size="100%" />
          </div>
          <div class="cust-title-block">
            <h2 class="cust-title">Customize Dashboard</h2>
            <p class="cust-subtitle">
              <span class="cust-count font-mono">{visibleCount}</span> of
              <span class="font-mono">{WIDGET_DEFS.length}</span> widgets visible
            </p>
          </div>
        </div>
        <div class="cust-header-actions">
          <button class="cust-reset-btn" onclick={() => layout.resetToDefaults()} title="Reset to defaults">
            <RotateCcw size={13} />
            <span>Reset</span>
          </button>
          <button class="cust-close-btn" onclick={() => layout.closeCustomizer()} title="Close">
            <X size={15} />
          </button>
        </div>
      </div>

      <!-- Widget Groups -->
      <div class="cust-body">
        {#each GROUPS as group (group.id)}
          {@const widgets = groupWidgets(group.id)}
          {#if widgets.length > 0}
            <div class="cust-group">
              <div class="cust-group-label">
                <span class="group-icon">{group.icon}</span>
                <span>{group.label}</span>
              </div>
              <div class="cust-widget-list">
                {#each widgets as widget (widget.id)}
                  {@const active = layout.isVisible(widget.id)}
                  <button
                    class="cust-widget-row"
                    class:active
                    class:disabled={widget.alwaysVisible}
                    onclick={() => !widget.alwaysVisible && layout.toggle(widget.id)}
                    title={widget.alwaysVisible ? 'This widget is always shown' : (active ? 'Click to hide' : 'Click to show')}
                  >
                    <div class="widget-toggle-indicator" class:on={active}>
                      {#if active}
                        <Check size={10} strokeWidth={3} />
                      {:else}
                        <span class="toggle-dash"></span>
                      {/if}
                    </div>
                    <div class="widget-row-info">
                      <span class="widget-row-label">{widget.label}</span>
                      <span class="widget-row-desc">{widget.description}</span>
                    </div>
                    <div class="widget-visibility-icon" class:visible={active}>
                      {#if active}
                        <Eye size={13} />
                      {:else}
                        <EyeOff size={13} />
                      {/if}
                    </div>
                  </button>
                {/each}
              </div>
            </div>
          {/if}
        {/each}
      </div>

      <!-- Footer -->
      <div class="cust-footer">
        <span class="cust-footer-note">Changes apply instantly and persist across sessions.</span>
        <button class="cust-done-btn" onclick={() => layout.closeCustomizer()}>
          <Check size={13} />
          Done
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .customizer-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.55);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    animation: overlayIn 0.18s ease forwards;
  }

  @keyframes overlayIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  .customizer-panel {
    width: calc(420px * var(--mdt-scale));
    max-height: calc(580px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border-2);
    border-radius: calc(10px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: panelIn 0.22s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    box-shadow:
      0 0 0 1px rgba(0, 255, 204, 0.06),
      0 calc(24px * var(--mdt-scale)) calc(48px * var(--mdt-scale)) rgba(0, 0, 0, 0.55);
  }

  @keyframes panelIn {
    from { opacity: 0; transform: scale(0.96) translateY(calc(-8px * var(--mdt-scale))); }
    to { opacity: 1; transform: scale(1) translateY(0); }
  }

  /* ── Header ─── */
  .cust-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(16px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
    background: var(--mdt-surface-2);
  }

  .cust-header-left {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .cust-icon-wrap {
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    background: var(--mdt-accent-dim);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 22%, transparent);
    border-radius: calc(8px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--mdt-accent);
    padding: calc(7px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .cust-icon-wrap :global(svg) {
    width: 100%;
    height: 100%;
  }

  .cust-title-block {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .cust-title {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    line-height: 1;
  }

  .cust-subtitle {
    font-size: calc(10.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1;
  }

  .cust-count {
    color: var(--mdt-accent);
    font-weight: 700;
  }

  .cust-header-actions {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .cust-reset-btn {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border);
    border-radius: calc(20px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-size: calc(10px * var(--mdt-scale));
    font-family: inherit;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease, background 0.15s ease;
  }

  .cust-reset-btn :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .cust-reset-btn:hover {
    color: var(--mdt-warning);
    border-color: color-mix(in srgb, var(--mdt-warning) 30%, transparent);
    background: rgba(251, 191, 36, 0.07);
  }

  .cust-close-btn {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease;
  }

  .cust-close-btn :global(svg) {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
  }

  .cust-close-btn:hover {
    color: var(--mdt-error);
    border-color: color-mix(in srgb, var(--mdt-error) 30%, transparent);
  }

  /* ── Body ─── */
  .cust-body {
    flex: 1;
    overflow-y: auto;
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
  }

  .cust-group {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .cust-group-label {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(9.5px * var(--mdt-scale));
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.09em;
    color: var(--mdt-text-muted);
    padding-left: calc(2px * var(--mdt-scale));
  }

  .group-icon {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0.6;
  }

  .cust-widget-list {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  /* ── Widget Row ─── */
  .cust-widget-row {
    display: flex;
    align-items: center;
    gap: calc(11px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    transition: background 0.15s ease, border-color 0.15s ease;
    width: 100%;
  }

  .cust-widget-row:hover:not(.disabled) {
    background: var(--mdt-surface-3);
    border-color: var(--mdt-border-2);
  }

  .cust-widget-row.active {
    border-color: color-mix(in srgb, var(--mdt-accent) 18%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-accent) 3%, var(--mdt-surface-2));
  }

  .cust-widget-row.active:hover:not(.disabled) {
    background: color-mix(in srgb, var(--mdt-accent) 6%, var(--mdt-surface-2));
  }

  .cust-widget-row.disabled {
    cursor: default;
    opacity: 0.55;
  }

  /* Toggle indicator box */
  .widget-toggle-indicator {
    width: calc(18px * var(--mdt-scale));
    height: calc(18px * var(--mdt-scale));
    flex-shrink: 0;
    border-radius: calc(4px * var(--mdt-scale));
    border: 1.5px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.15s ease, border-color 0.15s ease;
  }

  .widget-toggle-indicator.on {
    background: var(--mdt-accent);
    border-color: var(--mdt-accent);
    color: var(--mdt-bg);
  }

  .widget-toggle-indicator :global(svg) {
    width: calc(10px * var(--mdt-scale));
    height: calc(10px * var(--mdt-scale));
  }

  .toggle-dash {
    display: block;
    width: calc(8px * var(--mdt-scale));
    height: calc(1.5px * var(--mdt-scale));
    background: var(--mdt-border-2);
    border-radius: 1px;
  }

  .widget-row-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .widget-row-label {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    line-height: 1;
  }

  .widget-row-desc {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.3;
  }

  .widget-visibility-icon {
    flex-shrink: 0;
    color: var(--mdt-border-2);
    transition: color 0.15s ease;
    display: flex;
    align-items: center;
  }

  .widget-visibility-icon :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .widget-visibility-icon.visible {
    color: var(--mdt-accent);
  }

  /* ── Footer ─── */
  .cust-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    flex-shrink: 0;
  }

  .cust-footer-note {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.3;
    flex: 1;
    min-width: 0;
  }

  .cust-done-btn {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    background: var(--mdt-accent);
    border: none;
    border-radius: var(--mdt-radius);
    color: var(--mdt-bg);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 700;
    font-family: inherit;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
    flex-shrink: 0;
    letter-spacing: 0.03em;
  }

  .cust-done-btn :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .cust-done-btn:hover {
    opacity: 0.88;
  }

  .cust-done-btn:active {
    transform: scale(0.96);
  }

  /* Scrollbar */
  .cust-body::-webkit-scrollbar {
    width: calc(4px * var(--mdt-scale));
  }
  .cust-body::-webkit-scrollbar-track {
    background: transparent;
  }
  .cust-body::-webkit-scrollbar-thumb {
    background: var(--mdt-border-2);
    border-radius: 2px;
  }

  :global(.font-mono) {
    font-family: 'Share Tech Mono', monospace;
  }
</style>
