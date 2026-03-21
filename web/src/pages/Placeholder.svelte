<script>
  let { title = 'Page' } = $props();
</script>

<div class="placeholder">
  <div class="placeholder-inner">
    <svg class="placeholder-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
      <rect x="3" y="3" width="18" height="18" rx="3" />
      <line x1="9" y1="3" x2="9" y2="21" />
      <line x1="3" y1="9" x2="21" y2="9" />
    </svg>
    <h2 class="placeholder-title">{title}</h2>
    <p class="placeholder-desc">This module is under development.</p>
  </div>
</div>

<style>
  .placeholder {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .placeholder-inner {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    opacity: 0.4;
  }

  .placeholder-icon {
    width: calc(48px * var(--mdt-scale));
    height: calc(48px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .placeholder-title {
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
  }

  .placeholder-desc {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
</style>
