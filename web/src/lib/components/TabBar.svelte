<script>
  import { X, Plus, Pin, PinOff, Copy, ArrowRight, XCircle, RotateCcw } from 'lucide-svelte';
  import { tabsStore } from '../stores/tabs.svelte.js';

  let tabs = $derived(tabsStore.tabs);
  let activeTabId = $derived(tabsStore.activeTabId);

  let contextMenu = $state(null);
  let dragIdx = $state(null);
  let dragOverIdx = $state(null);
  let tabBarEl = $state(null);

  function handleTabClick(tabId, e) {
    if (e.button === 1) {
      e.preventDefault();
      tabsStore.closeTab(tabId);
      return;
    }
    tabsStore.activateTab(tabId);
  }

  function handleClose(tabId, e) {
    e.stopPropagation();
    tabsStore.closeTab(tabId);
  }

  function handleNewTab() {
    tabsStore.openTab('dashboard', { forceNew: true });
  }

  function handleContextMenu(tab, e) {
    e.preventDefault();
    e.stopPropagation();
    const rect = tabBarEl?.getBoundingClientRect();
    contextMenu = {
      tab,
      x: e.clientX - (rect?.left || 0),
      y: e.clientY - (rect?.top || 0),
    };
  }

  function closeContextMenu() {
    contextMenu = null;
  }

  function ctxAction(action) {
    if (!contextMenu) return;
    const tab = contextMenu.tab;
    switch (action) {
      case 'close':
        tabsStore.closeTab(tab.id);
        break;
      case 'close-others':
        tabsStore.closeOtherTabs(tab.id);
        break;
      case 'close-right':
        tabsStore.closeTabsToRight(tab.id);
        break;
      case 'pin':
        tabsStore.pinTab(tab.id);
        break;
      case 'unpin':
        tabsStore.unpinTab(tab.id);
        break;
      case 'duplicate':
        tabsStore.duplicateTab(tab.id);
        break;
      case 'reopen':
        tabsStore.reopenLastClosed();
        break;
    }
    closeContextMenu();
  }

  function handleDragStart(idx, e) {
    dragIdx = idx;
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', String(idx));
  }

  function handleDragOver(idx, e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    dragOverIdx = idx;
  }

  function handleDragEnd() {
    if (dragIdx !== null && dragOverIdx !== null && dragIdx !== dragOverIdx) {
      tabsStore.moveTab(dragIdx, dragOverIdx);
    }
    dragIdx = null;
    dragOverIdx = null;
  }

  function handleDragLeave() {
    dragOverIdx = null;
  }

  $effect(() => {
    function onClickAway(e) {
      if (contextMenu && tabBarEl && !tabBarEl.contains(e.target)) {
        closeContextMenu();
      }
    }
    window.addEventListener('mousedown', onClickAway);
    return () => window.removeEventListener('mousedown', onClickAway);
  });
</script>

<div class="tab-bar-wrap" bind:this={tabBarEl}>
  <div class="tab-bar-track">
    <div class="tab-bar-scroll">
      {#each tabs as tab, idx (tab.id)}
        {@const Icon = tab.icon}
        {@const isActive = tab.id === activeTabId}
        {@const isDragOver = dragOverIdx === idx && dragIdx !== idx}
        <button
          class="tab"
          class:active={isActive}
          class:pinned={tab.pinned}
          class:drag-over={isDragOver}
          draggable="true"
          onmousedown={(e) => handleTabClick(tab.id, e)}
          oncontextmenu={(e) => handleContextMenu(tab, e)}
          ondragstart={(e) => handleDragStart(idx, e)}
          ondragover={(e) => handleDragOver(idx, e)}
          ondragend={handleDragEnd}
          ondragleave={handleDragLeave}
          title={tab.label}
        >
          <span class="tab-icon" class:active-icon={isActive}>
            <Icon size="100%" />
          </span>

          {#if !tab.pinned}
            <span class="tab-label" class:active-label={isActive}>
              {tab.label}
            </span>
          {/if}

          {#if tab.closable && !tab.pinned}
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <span
              class="tab-close"
              onmousedown={(e) => handleClose(tab.id, e)}
              title="Close tab"
              role="button"
              tabindex="-1"
            >
              <X size="100%" />
            </span>
          {/if}

          {#if isActive}
            <div class="tab-active-edge"></div>
          {/if}
        </button>
      {/each}
    </div>

    <button
      class="tab-new"
      onclick={handleNewTab}
      title="New Tab"
    >
      <Plus size="100%" />
    </button>
  </div>

  <div class="tab-bar-border"></div>

  {#if contextMenu}
    <div
      class="ctx-menu"
      style="left: {contextMenu.x}px; top: {contextMenu.y}px;"
    >
      {#if !contextMenu.tab.pinned}
        <button class="ctx-item" onclick={() => ctxAction('pin')}>
          <Pin size={12} strokeWidth={2} />
          <span>Pin Tab</span>
        </button>
      {:else if contextMenu.tab.id !== 'tab_dashboard'}
        <button class="ctx-item" onclick={() => ctxAction('unpin')}>
          <PinOff size={12} strokeWidth={2} />
          <span>Unpin Tab</span>
        </button>
      {/if}

      <button class="ctx-item" onclick={() => ctxAction('duplicate')}>
        <Copy size={12} strokeWidth={2} />
        <span>Duplicate Tab</span>
      </button>

      <div class="ctx-divider"></div>

      {#if contextMenu.tab.closable}
        <button class="ctx-item" onclick={() => ctxAction('close')}>
          <X size={12} strokeWidth={2} />
          <span>Close</span>
        </button>
      {/if}

      <button class="ctx-item" onclick={() => ctxAction('close-others')}>
        <XCircle size={12} strokeWidth={2} />
        <span>Close Others</span>
      </button>

      <button class="ctx-item" onclick={() => ctxAction('close-right')}>
        <ArrowRight size={12} strokeWidth={2} />
        <span>Close to Right</span>
      </button>

      {#if tabsStore.recentlyClosed.length > 0}
        <div class="ctx-divider"></div>
        <button class="ctx-item" onclick={() => ctxAction('reopen')}>
          <RotateCcw size={12} strokeWidth={2} />
          <span>Reopen Closed Tab</span>
        </button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .tab-bar-wrap {
    position: relative;
    z-index: 8;
    flex-shrink: 0;
  }

  .tab-bar-track {
    display: flex;
    align-items: flex-end;
    background: var(--mdt-toolbar);
    padding: 0 calc(6px * var(--mdt-scale));
    gap: calc(1px * var(--mdt-scale));
    height: calc(36px * var(--mdt-scale));
  }

  .tab-bar-scroll {
    display: flex;
    align-items: flex-end;
    gap: calc(1px * var(--mdt-scale));
    overflow-x: auto;
    overflow-y: hidden;
    flex: 1;
    min-width: 0;
    scrollbar-width: none;
  }

  .tab-bar-scroll::-webkit-scrollbar {
    display: none;
  }

  .tab-bar-border {
    height: calc(1px * var(--mdt-scale));
    background: var(--mdt-border);
  }

  /* ─── Individual Tab ─── */

  .tab {
    position: relative;
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    min-width: 0;
    max-width: calc(200px * var(--mdt-scale));
    border: none;
    border-radius: calc(6px * var(--mdt-scale)) calc(6px * var(--mdt-scale)) 0 0;
    background: transparent;
    color: var(--mdt-text-muted);
    font-family: inherit;
    font-size: calc(11.5px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.15s cubic-bezier(0.16, 1, 0.3, 1),
                color 0.15s cubic-bezier(0.16, 1, 0.3, 1);
    white-space: nowrap;
    flex-shrink: 0;
    user-select: none;
  }

  .tab:hover {
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
  }

  .tab.active {
    background: var(--mdt-bg);
    color: var(--mdt-text);
    z-index: 2;
  }

  .tab.pinned {
    max-width: calc(38px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    justify-content: center;
  }

  .tab.drag-over {
    border-left: calc(2px * var(--mdt-scale)) solid var(--mdt-accent);
  }

  /* ─── Tab Icon ─── */

  .tab-icon {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0.55;
    transition: opacity 0.15s ease, color 0.15s ease;
  }

  .tab:hover .tab-icon {
    opacity: 0.75;
  }

  .active-icon {
    opacity: 1;
    color: var(--mdt-accent);
  }

  /* ─── Tab Label ─── */

  .tab-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
    line-height: 1;
  }

  .active-label {
    color: var(--mdt-text);
  }

  /* ─── Close Button ─── */

  .tab-close {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--mdt-text-muted);
    border-radius: calc(3px * var(--mdt-scale));
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.1s ease, background 0.1s ease, color 0.1s ease;
    padding: 0;
    margin-left: calc(2px * var(--mdt-scale));
  }

  .tab:hover .tab-close {
    opacity: 0.6;
  }

  .tab-close:hover {
    opacity: 1 !important;
    background: rgba(248, 113, 113, 0.15);
    color: var(--mdt-error);
  }

  /* ─── Active Edge (bottom accent line) ─── */

  .tab-active-edge {
    position: absolute;
    bottom: 0;
    left: calc(8px * var(--mdt-scale));
    right: calc(8px * var(--mdt-scale));
    height: calc(2px * var(--mdt-scale));
    background: var(--mdt-accent);
    border-radius: calc(1px * var(--mdt-scale)) calc(1px * var(--mdt-scale)) 0 0;
    box-shadow: 0 0 calc(6px * var(--mdt-scale)) var(--mdt-accent-glow);
  }

  /* ─── New Tab Button ─── */

  .tab-new {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border: none;
    border-radius: calc(5px * var(--mdt-scale));
    background: transparent;
    color: var(--mdt-text-muted);
    cursor: pointer;
    flex-shrink: 0;
    margin-bottom: calc(2px * var(--mdt-scale));
    margin-left: calc(2px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale));
    transition: background 0.15s ease, color 0.15s ease;
  }

  .tab-new:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .tab-new:active {
    transform: scale(0.93);
  }

  /* ─── Context Menu ─── */

  .ctx-menu {
    position: absolute;
    z-index: 100;
    min-width: calc(180px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border-2);
    border-radius: var(--mdt-radius);
    box-shadow: 0 calc(8px * var(--mdt-scale)) calc(24px * var(--mdt-scale)) rgba(0, 0, 0, 0.5);
    animation: ctxIn 0.12s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .ctx-item {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: none;
    border-radius: var(--mdt-radius-sm);
    background: transparent;
    color: var(--mdt-text-dim);
    font-family: inherit;
    font-size: calc(11.5px * var(--mdt-scale));
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
    white-space: nowrap;
    text-align: left;
  }

  .ctx-item:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .ctx-divider {
    height: calc(1px * var(--mdt-scale));
    background: var(--mdt-border);
    margin: calc(3px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
  }

  @keyframes ctxIn {
    from {
      opacity: 0;
      transform: scale(0.95) translateY(calc(-4px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: scale(1) translateY(0);
    }
  }
</style>
