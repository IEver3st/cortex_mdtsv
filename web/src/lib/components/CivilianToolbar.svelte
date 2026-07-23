<script>
  import { User } from '@lucide/svelte';
  import { mdtStore } from '../stores/mdt.svelte.js';
  import { getGreeting } from '../utils/helpers.js';

  const citySeal = `${import.meta.env.BASE_URL}LosSantosSeal.webp`;

  let greeting = $derived(getGreeting());
  let civ = $derived(mdtStore.civilian);
  let displayName = $derived(
    civ.firstName && civ.lastName
      ? `${civ.firstName} ${civ.lastName}`
      : 'Citizen'
  );
</script>

<header class="toolbar">
  <div class="toolbar-left">
    <div class="brand-lockup" aria-hidden="true">
      <img
        class="brand-image"
        src={citySeal}
        alt=""
      />
    </div>

    <div class="dept-info">
      <span class="dept-name">Los Santos City Hall</span>
      <span class="dept-short font-mono">CIVILIAN SERVICES PORTAL</span>
    </div>
  </div>

  <div class="toolbar-right">
    <div class="officer-info">
      <span class="officer-greeting">{greeting},</span>
      <span class="officer-name">{displayName}</span>
    </div>

    <div class="avatar-ring-wrap">
      <div class="avatar-ring">
        <div class="avatar-inner">
          <div class="avatar-placeholder">
            <User size="100%" />
          </div>
        </div>
      </div>
    </div>
  </div>
</header>

<style>
  .toolbar {
    height: var(--mdt-toolbar-height);
    min-height: var(--mdt-toolbar-height);
    background: var(--mdt-toolbar);
    border-bottom: 1px solid transparent;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 calc(16px * var(--mdt-scale));
    gap: calc(12px * var(--mdt-scale));
    z-index: 10;
    transition: padding 0.35s cubic-bezier(0.16, 1, 0.3, 1);
    position: relative;
  }

  .toolbar-left {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    min-width: 0;
  }

  .brand-lockup {
    display: flex;
    align-items: center;
    flex-shrink: 0;
  }

  .brand-image {
    display: block;
    object-fit: contain;
    flex-shrink: 0;
    width: calc(34px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
  }

  .dept-info {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .dept-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    line-height: 1.2;
    letter-spacing: 0.01em;
  }

  .dept-short {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.08em;
    text-transform: uppercase;
    line-height: 1.3;
  }

  .toolbar-right {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .officer-info {
    display: flex;
    align-items: baseline;
    gap: calc(5px * var(--mdt-scale));
    text-align: right;
  }

  .officer-greeting {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-weight: 400;
  }

  .officer-name {
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-accent);
    font-weight: 600;
    white-space: nowrap;
  }

  /* ── Avatar Ring ─────────────────────────────── */
  .avatar-ring-wrap {
    flex-shrink: 0;
  }

  .avatar-ring {
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    border-radius: 50%;
    border: 2px solid var(--mdt-accent);
    background: var(--mdt-surface-2);
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 0 10px var(--mdt-accent-glow);
    transition: border-color 0.3s ease, box-shadow 0.3s ease;
  }

  .avatar-inner {
    width: calc(29px * var(--mdt-scale));
    height: calc(29px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-3);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .avatar-placeholder {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

</style>
