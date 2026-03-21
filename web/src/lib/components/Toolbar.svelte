<script>
  import { User } from 'lucide-svelte';
  import { mdtStore } from '../stores/mdt.svelte.js';
  import { getDepartmentBrand } from '../utils/branding.js';
  import { getGreeting, getInitialLastName } from '../utils/helpers.js';

  let greeting = $derived(getGreeting());
  let displayName = $derived(
    getInitialLastName(mdtStore.officer.firstName, mdtStore.officer.lastName)
  );
  let rank = $derived(mdtStore.officer.rank);
  let departmentKey = $derived(mdtStore.officer.departmentKey);
  let department = $derived(mdtStore.officer.department);
  let departmentShort = $derived(mdtStore.officer.departmentShort);
  let avatar = $derived(mdtStore.officer.avatar || mdtStore.settings.avatarUrl);
  let collapsed = $derived(mdtStore.sidebarCollapsed);
  let brand = $derived(getDepartmentBrand({ departmentKey, department, departmentShort }));
</script>

<header class="toolbar" class:collapsed>
  <div class="toolbar-left">
    <div class="brand-lockup" aria-hidden="true">
      <img
        class="brand-image"
        class:brand-image-logo={brand.variant === 'logo'}
        class:brand-image-seal={brand.variant === 'seal'}
        src={brand.src}
        alt=""
      />
    </div>

    <div class="dept-info">
      <span class="dept-name">{department}</span>
      <span class="dept-short font-mono">{departmentShort} - CORTEX MDT</span>
    </div>
  </div>

  <div class="toolbar-right">
    <div class="officer-info">
      <span class="officer-greeting">{greeting},</span>
      <span class="officer-name">{rank} {displayName}</span>
    </div>

    <button class="avatar-btn" title="Profile">
      {#if avatar}
        <img class="avatar-img" src={avatar} alt="Avatar" />
      {:else}
        <div class="avatar-placeholder">
            <User size="100%" />
          </div>
      {/if}
    </button>
  </div>
</header>

<style>
  .toolbar {
    height: var(--mdt-toolbar-height);
    min-height: var(--mdt-toolbar-height);
    background: var(--mdt-toolbar);
    border-bottom: 1px solid var(--mdt-border);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 calc(16px * var(--mdt-scale));
    gap: calc(12px * var(--mdt-scale));
    z-index: 10;
    transition: padding 0.35s cubic-bezier(0.16, 1, 0.3, 1);
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
  }

  .brand-image-logo {
    width: calc(44px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
  }

  .brand-image-seal {
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
    color: var(--mdt-text);
    font-weight: 600;
    white-space: nowrap;
  }

  .avatar-btn {
    width: calc(34px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
    border-radius: 50%;
    border: 2px solid var(--mdt-border-2);
    background: var(--mdt-surface-2);
    cursor: pointer;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: border-color 0.2s ease, transform 0.15s ease;
    padding: 0;
    flex-shrink: 0;
  }

  .avatar-btn:hover {
    border-color: var(--mdt-accent);
    transform: scale(1.05);
  }

  .avatar-btn:active {
    transform: scale(0.97);
  }

  .avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 50%;
  }

  .avatar-placeholder {
    width: calc(18px * var(--mdt-scale));
    height: calc(18px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .collapsed .dept-info {
    display: none;
  }
</style>
