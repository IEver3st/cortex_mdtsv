<script>
  /**
   * Sliding toggle; pairs with <label for={id}> on setting row.
   */
  let {
    id,
    checked = false,
    disabled = false,
    onCheckedChange,
  } = $props();
</script>

<div class="mdt-switch" class:mdt-switch--disabled={disabled}>
  <input
    {id}
    type="checkbox"
    class="mdt-switch-input"
    {checked}
    {disabled}
    onchange={(e) => onCheckedChange?.(e.currentTarget.checked)}
  />
  <span class="mdt-switch-track" aria-hidden="true">
    <span class="mdt-switch-thumb"></span>
  </span>
</div>

<style>
  .mdt-switch {
    --sw-w: calc(38px * var(--mdt-scale, 1));
    --sw-h: calc(20px * var(--mdt-scale, 1));
    --sw-pad: calc(2px * var(--mdt-scale, 1));
    position: relative;
    width: var(--sw-w);
    height: var(--sw-h);
    flex-shrink: 0;
  }

  .mdt-switch-input {
    position: absolute;
    inset: 0;
    margin: 0;
    opacity: 0;
    cursor: pointer;
    z-index: 2;
    width: 100%;
    height: 100%;
  }

  .mdt-switch--disabled .mdt-switch-input {
    cursor: not-allowed;
  }

  .mdt-switch-track {
    display: block;
    width: 100%;
    height: 100%;
    border-radius: 999px;
    background: var(--mdt-surface-3);
    box-shadow:
      inset 0 1px 2px rgba(0, 0, 0, 0.35),
      inset 0 0 0 1px var(--mdt-border);
    transition:
      background 0.2s cubic-bezier(0.4, 0, 0.2, 1),
      box-shadow 0.2s ease;
  }

  .mdt-switch-thumb {
    position: absolute;
    top: var(--sw-pad);
    left: var(--sw-pad);
    width: calc(var(--sw-h) - 2 * var(--sw-pad));
    height: calc(var(--sw-h) - 2 * var(--sw-pad));
    border-radius: 50%;
    background: linear-gradient(165deg, #f8fafc 0%, #c8d0dc 100%);
    box-shadow:
      0 1px 3px rgba(0, 0, 0, 0.45),
      0 0 0 1px rgba(255, 255, 255, 0.12) inset;
    transition:
      transform 0.22s cubic-bezier(0.4, 0, 0.2, 1),
      box-shadow 0.2s ease;
    pointer-events: none;
  }

  /* ON = same token as Appearance accent (data-theme on :root sets --mdt-accent) */
  .mdt-switch-input:checked + .mdt-switch-track {
    background: var(--mdt-accent);
    box-shadow:
      inset 0 1px 2px rgba(0, 0, 0, 0.2),
      inset 0 -1px 1px rgba(255, 255, 255, 0.14),
      0 0 0 1px rgba(0, 0, 0, 0.32),
      0 0 calc(10px * var(--mdt-scale, 1)) var(--mdt-accent-glow);
  }

  .mdt-switch-input:checked + .mdt-switch-track .mdt-switch-thumb {
    transform: translateX(calc(var(--sw-w) - var(--sw-h)));
    box-shadow:
      0 1px 4px rgba(0, 0, 0, 0.45),
      0 0 0 1px rgba(255, 255, 255, 0.35) inset;
  }

  .mdt-switch-input:focus-visible + .mdt-switch-track {
    outline: 2px solid var(--mdt-accent);
    outline-offset: 2px;
  }

  .mdt-switch--disabled .mdt-switch-track {
    opacity: 0.45;
  }

  .mdt-switch--disabled .mdt-switch-thumb {
    background: var(--mdt-surface-2);
  }
</style>
