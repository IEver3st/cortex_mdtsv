<script>
  import {
    LayoutGrid,
    UserCircle,
    Car,
    FileText,
    ScrollText,
    Settings,
    Menu,
    LogOut
  } from 'lucide-svelte';
  import { mdtStore } from '../stores/mdt.svelte.js';

  const NAV_ITEMS = [
    { id: 'civ-dashboard', label: 'Dashboard',    icon: LayoutGrid },
    { id: 'civ-identity',  label: 'My Identity',  icon: UserCircle },
    { id: 'civ-vehicles',  label: 'My Vehicles',  icon: Car },
    { id: 'civ-records',   label: 'My Records',   icon: FileText },
    { id: 'civ-services',  label: 'City Services', icon: ScrollText },
  ];

  const BOTTOM_ITEMS = [
    { id: 'civ-settings', label: 'Settings', icon: Settings },
  ];

  function handleLogout() {
    mdtStore.logout();
  }

  let collapsed = $derived(mdtStore.sidebarCollapsed);
  let active = $derived(mdtStore.activePage);

  function navigate(pageId) {
    mdtStore.activePage = pageId;
  }
</script>

<aside class="sidebar" class:collapsed>
  <button class="nav-item toggle-btn" onclick={() => mdtStore.toggleSidebar()} title={collapsed ? 'Expand' : 'Collapse'}>
    <span class="nav-icon" class:rotated={!collapsed}>
      <Menu size="100%" />
    </span>
    {#if !collapsed}
      <span class="nav-label">Menu</span>
    {/if}
  </button>

  <div class="nav-divider"></div>

  <nav class="nav-main">
    {#each NAV_ITEMS as item (item.id)}
      {@const Icon = item.icon}
      <button
        class="nav-item"
        class:active={active === item.id}
        onclick={() => navigate(item.id)}
        title={collapsed ? item.label : ''}
      >
        <span class="nav-icon">
          <Icon size="100%" />
        </span>
        {#if !collapsed}
          <span class="nav-label">{item.label}</span>
        {/if}
        {#if active === item.id}
          <div class="active-indicator"></div>
        {/if}
      </button>
    {/each}
  </nav>

  <div class="nav-bottom">
    <div class="nav-divider"></div>
    {#each BOTTOM_ITEMS as item (item.id)}
      {@const Icon = item.icon}
      <button
        class="nav-item"
        class:active={active === item.id}
        onclick={() => navigate(item.id)}
        title={collapsed ? item.label : ''}
      >
        <span class="nav-icon">
          <Icon size="100%" />
        </span>
        {#if !collapsed}
          <span class="nav-label">{item.label}</span>
        {/if}
        {#if active === item.id}
          <div class="active-indicator"></div>
        {/if}
      </button>
    {/each}

    <button
      class="nav-item nav-item-logout"
      onclick={handleLogout}
      title={collapsed ? 'Logout' : ''}
    >
      <span class="nav-icon">
        <LogOut size="100%" />
      </span>
      {#if !collapsed}
        <span class="nav-label">Logout</span>
      {/if}
    </button>
  </div>
</aside>

<style>
  .sidebar {
    width: var(--mdt-sidebar-expanded);
    min-width: var(--mdt-sidebar-expanded);
    height: 100%;
    background: var(--mdt-sidebar);
    border-right: 1px solid var(--civ-border, var(--mdt-border));
    display: flex;
    flex-direction: column;
    padding: calc(8px * var(--mdt-scale)) 0;
    transition: width 0.35s cubic-bezier(0.16, 1, 0.3, 1),
                min-width 0.35s cubic-bezier(0.16, 1, 0.3, 1);
    overflow: hidden;
    z-index: 5;
  }

  .sidebar.collapsed {
    width: var(--mdt-sidebar-width);
    min-width: var(--mdt-sidebar-width);
  }

  .nav-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    overflow-y: auto;
    overflow-x: hidden;
    padding: 0 calc(6px * var(--mdt-scale));
  }

  .nav-bottom {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    padding: 0 calc(6px * var(--mdt-scale));
  }

  .nav-item {
    position: relative;
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: none;
    background: transparent;
    color: var(--mdt-text-dim);
    cursor: pointer;
    white-space: nowrap;
    overflow: hidden;
    transition: background 0.15s ease, color 0.15s ease;
    font-family: inherit;
    font-size: calc(13px * var(--mdt-scale));
    width: 100%;
    text-align: left;
  }

  .nav-item:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .nav-item.active {
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    color: var(--civ-accent, var(--mdt-accent));
  }

  .nav-icon {
    width: calc(20px * var(--mdt-scale));
    height: calc(20px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .nav-icon.rotated {
    transform: rotate(90deg);
  }

  .nav-label {
    opacity: 1;
    transition: opacity 0.2s ease;
    font-weight: 500;
  }

  .nav-divider {
    height: 1px;
    background: var(--civ-border, var(--mdt-border));
    margin: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
  }

  .toggle-btn {
    margin: 0 calc(6px * var(--mdt-scale));
  }

  .active-indicator {
    position: absolute;
    left: 0;
    top: 25%;
    bottom: 25%;
    width: calc(3px * var(--mdt-scale));
    border-radius: 0 999px 999px 0;
    background: var(--civ-accent, var(--mdt-accent));
    box-shadow: 0 0 8px var(--civ-accent-glow, var(--mdt-accent-glow));
  }

  .collapsed .nav-item {
    justify-content: center;
    padding: calc(10px * var(--mdt-scale));
  }

  .collapsed .nav-label {
    display: none;
  }

  .collapsed .active-indicator {
    left: 0;
  }

  .nav-item-logout {
    color: var(--mdt-text-muted);
  }

  .nav-item-logout:hover {
    background: rgba(248, 113, 113, 0.10);
    color: var(--mdt-error);
  }
</style>
