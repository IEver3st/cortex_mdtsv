<script>
  import { onMount } from 'svelte';
  import { Video, Power, Trash2, Radio } from '@lucide/svelte';

  let {
    camera,
    disabled = false,
    canManage = false,
    onView = () => {},
    onToggle = () => {},
    onRemove = () => {},
  } = $props();

  let tick = $state(Date.now());
  let previewLoadedFor = $state(null);

  let previewUrl = $derived.by(() => {
    if (!camera?.image) return null;
    const sep = String(camera.image).includes('?') ? '&' : '?';
    return `${camera.image}${sep}v=${tick}`;
  });

  let previewShow = $derived(previewUrl && previewLoadedFor === previewUrl);

  let camHue = $derived.by(() => {
    let h = 0;
    const s = String(camera.id || camera.label || 'x');
    for (let i = 0; i < s.length; i++) h = (h + s.charCodeAt(i) * (i + 1)) % 360;
    return h;
  });

  onMount(() => {
    let cancelled = false;
    let initialTimer = 0;
    let nextTimer = 0;

    function scheduleNextRefresh() {
      const ms = 180000 + Math.random() * 120000;
      nextTimer = window.setTimeout(() => {
        if (cancelled) return;
        tick = Date.now();
        scheduleNextRefresh();
      }, ms);
    }

    initialTimer = window.setTimeout(() => {
      if (cancelled) return;
      tick = Date.now();
      scheduleNextRefresh();
    }, Math.random() * 90000);

    return () => {
      cancelled = true;
      clearTimeout(initialTimer);
      clearTimeout(nextTimer);
    };
  });
</script>

<article class="cctv-card" class:offline={camera.isOnline === false}>
  <button
    type="button"
    class="card-preview"
    onclick={() => onView(camera.id)}
    disabled={disabled || camera.isOnline === false}
    aria-label="View {camera.label} feed"
  >
    {#if previewUrl}
      <img
        class="preview-photo"
        class:preview-hidden={!previewShow}
        src={previewUrl}
        alt=""
        loading="lazy"
        decoding="async"
        onload={() => { previewLoadedFor = previewUrl; }}
        onerror={() => { previewLoadedFor = null; }}
      />
    {/if}
    <div class="preview-fallback" class:preview-hide={previewShow} style="--preview-h: {camHue}">
      <span class="preview-initials font-mono">{String(camera.label || '?').slice(0, 2).toUpperCase()}</span>
    </div>
    <div class="preview-scanlines"></div>
    <div class="preview-gradient"></div>
    <div class="preview-hud">
      <span class="hud-label font-mono">CAM {String(camera.id).slice(-6).toUpperCase()}</span>
      <span class="hud-preview-badge">
        <span class="preview-dot" class:offline={camera.isOnline === false}></span>
        {camera.isOnline === false ? 'OFFLINE' : 'LIVE'}
      </span>
    </div>
    <div class="preview-bottom">
      <span class="hud-ts font-mono">{camera.isOnline === false ? 'No signal' : 'Still · ~2–3 min'}</span>
      <span class="hud-viewers font-mono">{camera.viewerCount || 0} watching</span>
    </div>
  </button>

  <div class="card-body">
    <div class="camera-row">
      <div class="camera-avatar">
        <span class="camera-avatar-initials font-mono">{String(camera.label || '?').slice(0, 2).toUpperCase()}</span>
      </div>
      <div class="camera-info">
        <span class="camera-name">{camera.label}</span>
        <span class="camera-meta font-mono">{camera.type || 'Unknown'} · {camera.model}</span>
      </div>
      <div class="camera-status">
        <span class="status-dot" class:offline={camera.isOnline === false}></span>
        <span class="status-text" class:offline={camera.isOnline === false}>
          {camera.isOnline === false ? 'Offline' : 'Online'}
        </span>
      </div>
    </div>

    <div class="card-actions">
      <button class="btn-open" onclick={() => onView(camera.id)} disabled={disabled || camera.isOnline === false}>
        <Video size={14} />
        Watch Feed
      </button>
      {#if canManage}
        <button
          class="action-icon"
          class:active={camera.isOnline === false}
          onclick={() => onToggle(camera)}
          disabled={disabled}
          title={camera.isOnline === false ? 'Bring Online' : 'Take Offline'}
        >
          <Power size={14} />
        </button>
        <button
          class="action-icon danger"
          onclick={() => onRemove(camera)}
          disabled={disabled}
          title="Delete"
        >
          <Trash2 size={14} />
        </button>
      {/if}
    </div>
  </div>
</article>

<style>
  .cctv-card {
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    background: var(--mdt-surface);
    overflow: hidden;
    transition: border-color 0.2s ease, transform 0.15s ease;
    animation: cardSlideIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    opacity: 0;
  }

  .cctv-card:hover {
    border-color: var(--mdt-border-2);
    transform: translateY(calc(-2px * var(--mdt-scale)));
  }

  .cctv-card.offline {
    opacity: 0.82;
  }

  .cctv-card.offline .preview-photo {
    filter: saturate(0.6) contrast(1.02) brightness(0.88);
  }

  /* ── Preview ── */
  .card-preview {
    position: relative;
    height: calc(158px * var(--mdt-scale));
    background: var(--mdt-bg);
    overflow: hidden;
    border: none;
    padding: 0;
    cursor: pointer;
    width: 100%;
    display: block;
  }

  .card-preview:disabled {
    cursor: not-allowed;
    opacity: 0.7;
  }

  .preview-photo {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
    filter: saturate(0.88) contrast(1.06) brightness(0.92);
    transform: scale(1.02);
    z-index: 1;
  }

  .preview-hidden {
    opacity: 0;
  }

  .preview-fallback {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background:
      radial-gradient(ellipse at 30% 20%, hsl(var(--preview-h) 45% 42% / 0.38), transparent 55%),
      linear-gradient(165deg, var(--mdt-surface) 0%, var(--mdt-bg) 100%);
    z-index: 0;
  }

  .preview-hide {
    visibility: hidden;
  }

  .preview-initials {
    font-size: calc(36px * var(--mdt-scale));
    font-weight: 700;
    color: rgba(255, 255, 255, 0.2);
    letter-spacing: 0.12em;
  }

  .preview-scanlines {
    position: absolute;
    inset: 0;
    background: repeating-linear-gradient(
      to bottom,
      transparent,
      transparent 2px,
      rgba(255, 255, 255, 0.015) 2px,
      rgba(255, 255, 255, 0.015) 4px
    );
    pointer-events: none;
    z-index: 2;
  }

  .preview-gradient {
    position: absolute;
    inset: 0;
    background: linear-gradient(to bottom, transparent 50%, rgba(0, 0, 0, 0.6));
    pointer-events: none;
    z-index: 2;
  }

  .preview-hud {
    position: absolute;
    top: calc(8px * var(--mdt-scale));
    left: calc(10px * var(--mdt-scale));
    right: calc(10px * var(--mdt-scale));
    display: flex;
    justify-content: space-between;
    align-items: center;
    z-index: 3;
    pointer-events: none;
  }

  .hud-label {
    font-size: calc(9px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.35);
    letter-spacing: 0.1em;
  }

  .hud-preview-badge {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-accent);
    font-weight: 700;
    letter-spacing: 0.08em;
    font-family: 'Share Tech Mono', monospace;
  }

  .preview-dot {
    width: calc(5px * var(--mdt-scale));
    height: calc(5px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-accent);
    opacity: 0.85;
    animation: pulse-dot 2s ease-in-out infinite;
  }

  .preview-dot.offline {
    background: var(--mdt-error);
    animation: none;
    opacity: 1;
  }

  .preview-bottom {
    position: absolute;
    bottom: calc(8px * var(--mdt-scale));
    left: calc(10px * var(--mdt-scale));
    right: calc(10px * var(--mdt-scale));
    display: flex;
    justify-content: space-between;
    z-index: 3;
    pointer-events: none;
  }

  .hud-ts,
  .hud-viewers {
    font-size: calc(9px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.3);
    letter-spacing: 0.04em;
  }

  /* ── Card Body ── */
  .card-body {
    padding: calc(12px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .camera-row {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
  }

  .camera-avatar {
    width: calc(36px * var(--mdt-scale));
    height: calc(36px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--mdt-text-muted);
    overflow: hidden;
  }

  .camera-avatar-initials {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-dim);
    letter-spacing: 0.04em;
  }

  .camera-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .camera-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .camera-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .camera-status {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    flex-shrink: 0;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
  }

  .status-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-success);
    flex-shrink: 0;
  }

  .status-dot.offline {
    background: var(--mdt-error);
  }

  .status-text {
    color: var(--mdt-success);
    letter-spacing: 0.03em;
    text-transform: uppercase;
  }

  .status-text.offline {
    color: var(--mdt-error);
  }

  /* ── Actions ── */
  .card-actions {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .btn-open {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: none;
    border-radius: var(--mdt-radius);
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .btn-open :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .btn-open:hover { opacity: 0.9; }
  .btn-open:active { transform: scale(0.96); }
  .btn-open:disabled { opacity: 0.4; cursor: not-allowed; }

  .action-icon {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease, background 0.15s ease;
    padding: calc(6px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .action-icon::after {
    content: '';
    position: absolute;
    inset: calc(-4px * var(--mdt-scale));
  }

  .action-icon:hover { color: var(--mdt-text); border-color: var(--mdt-border-2); }
  .action-icon.active { color: var(--mdt-warning); border-color: color-mix(in srgb, var(--mdt-warning) 30%, transparent); background: color-mix(in srgb, var(--mdt-warning) 10%, var(--mdt-surface-2)); }
  .action-icon.danger:hover { color: var(--mdt-error); border-color: color-mix(in srgb, var(--mdt-error) 30%, transparent); }
  .action-icon:disabled { opacity: 0.4; cursor: not-allowed; }

  @keyframes cardSlideIn {
    from { opacity: 0; transform: translateY(calc(10px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes pulse-dot {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }

  .font-mono {
    font-family: 'Share Tech Mono', ui-monospace, monospace;
  }
</style>
