<script>
  import { ChevronDown } from '@lucide/svelte';
  import { onDestroy } from 'svelte';

  /**
   * @typedef {{ value: string, label?: string }} MdtSelectOption
   */

  let {
    options = /** @type {MdtSelectOption[]} */ ([]),
    value = $bindable(''),
    placeholder = 'Select…',
    disabled = false,
    compact = false,
    id: domId = undefined,
  } = $props();

  let open = $state(false);
  let rootEl = $state(null);
  let menuEl = $state(null);
  let menuStyle = $state('');

  const instanceId = Math.random().toString(36).slice(2);
  let listId = $derived(domId ? `${domId}-list` : `mdt-select-list-${instanceId}`);
  let btnId = $derived(domId ? `${domId}-btn` : `mdt-select-btn-${instanceId}`);

  let displayLabel = $derived.by(() => {
    const hit = options.find((o) => o.value === value);
    if (hit?.label) return hit.label;
    if (hit && hit.value) return hit.value;
    if (value) return value;
    return placeholder;
  });

  let showPlaceholderTone = $derived(value === '' || value == null);

  function placeMenu() {
    const trigger = rootEl?.querySelector?.('.mdt-select-trigger');
    if (!trigger || !menuEl) return;
    const r = trigger.getBoundingClientRect();
    const gap = 4;
    const maxH = 280;
    let top = r.bottom + gap;
    const estH = Math.min(menuEl.scrollHeight || maxH, maxH);
    if (top + estH > window.innerHeight - 8) {
      top = Math.max(8, r.top - gap - estH);
    }
    menuStyle = `top:${top}px;left:${r.left}px;width:${r.width}px;max-height:${maxH}px`;
  }

  function onWinChange() {
    if (open) placeMenu();
  }

  $effect(() => {
    if (!open) return;
    placeMenu();
    const ro = typeof ResizeObserver !== 'undefined' && menuEl ? new ResizeObserver(() => placeMenu()) : null;
    if (ro && menuEl) ro.observe(menuEl);
    window.addEventListener('resize', onWinChange);
    return () => {
      window.removeEventListener('resize', onWinChange);
      ro?.disconnect();
    };
  });

  $effect(() => {
    if (!open) return;
    function onDoc(e) {
      if (rootEl?.contains(e.target) || menuEl?.contains(e.target)) return;
      open = false;
    }
    function onKey(e) {
      if (e.key === 'Escape') open = false;
    }
    document.addEventListener('click', onDoc, true);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('click', onDoc, true);
      document.removeEventListener('keydown', onKey);
    };
  });

  function toggle(e) {
    e?.stopPropagation?.();
    if (disabled) return;
    open = !open;
    if (open) queueMicrotask(() => placeMenu());
  }

  function pick(opt, e) {
    e?.stopPropagation?.();
    value = opt.value;
    open = false;
  }

  onDestroy(() => {
    window.removeEventListener('resize', onWinChange);
  });
</script>

<div
  class="mdt-select"
  class:mdt-select-open={open}
  class:mdt-select-disabled={disabled}
  class:mdt-select-compact={compact}
  bind:this={rootEl}
>
  <button
    type="button"
    id={btnId}
    class="mdt-select-trigger"
    aria-haspopup="listbox"
    aria-expanded={open}
    aria-controls={listId}
    {disabled}
    onclick={toggle}
  >
    <span class="mdt-select-value" class:muted={showPlaceholderTone}>{displayLabel}</span>
    <span class="mdt-select-chevron-wrap" aria-hidden="true">
      <ChevronDown size={compact ? 14 : 16} strokeWidth={2} />
    </span>
  </button>

  {#if open}
    <div
      bind:this={menuEl}
      class="mdt-select-menu"
      id={listId}
      role="listbox"
      tabindex="-1"
      style={menuStyle}
    >
      {#each options as opt (opt.value + (opt.label || ''))}
        <button
          type="button"
          class="mdt-select-option"
          class:selected={value === opt.value}
          role="option"
          aria-selected={value === opt.value}
          onclick={(e) => pick(opt, e)}
        >
          {opt.label ?? opt.value}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .mdt-select {
    position: relative;
    width: 100%;
    font: inherit;
  }

  .mdt-select-trigger {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    min-height: calc(44px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
    font: inherit;
    cursor: pointer;
    text-align: left;
    transition: border-color 0.12s ease, box-shadow 0.12s ease;
  }

  .mdt-select-compact .mdt-select-trigger {
    min-height: calc(38px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
  }

  .mdt-select-trigger:hover:not(:disabled) {
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border-2));
  }

  .mdt-select-open .mdt-select-trigger {
    border-color: color-mix(in srgb, var(--mdt-accent) 55%, transparent);
    box-shadow: 0 0 0 1px color-mix(in srgb, var(--mdt-accent) 35%, transparent);
  }

  .mdt-select-disabled .mdt-select-trigger {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .mdt-select-value {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .mdt-select-value.muted {
    color: var(--mdt-text-muted);
  }

  .mdt-select-chevron-wrap {
    flex-shrink: 0;
    display: flex;
    opacity: 0.55;
    transition: transform 0.14s ease;
  }

  .mdt-select-open .mdt-select-chevron-wrap {
    transform: rotate(180deg);
  }

  .mdt-select-menu {
    position: fixed;
    z-index: 12000;
    margin: 0;
    padding: calc(4px * var(--mdt-scale));
    list-style: none;
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    box-shadow:
      0 calc(12px * var(--mdt-scale)) calc(40px * var(--mdt-scale)) rgba(0, 0, 0, 0.55),
      0 0 0 1px rgba(0, 0, 0, 0.35);
    overflow-y: auto;
    overscroll-behavior: contain;
  }

  .mdt-select-option {
    display: block;
    width: 100%;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: 0;
    border-radius: calc(8px * var(--mdt-scale));
    background: transparent;
    color: var(--mdt-text);
    font: inherit;
    text-align: left;
    cursor: pointer;
  }

  .mdt-select-option:hover,
  .mdt-select-option:focus-visible {
    outline: none;
    background: color-mix(in srgb, var(--mdt-accent) 18%, var(--mdt-surface-2));
    color: var(--mdt-text);
  }

  .mdt-select-option.selected {
    background: color-mix(in srgb, var(--mdt-accent) 28%, var(--mdt-surface-2));
    color: var(--mdt-text);
  }
</style>
