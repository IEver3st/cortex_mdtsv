<script>
  import { onMount } from 'svelte';
  import { mdtStore } from './lib/stores/mdt.svelte.js';
  import { themeStore } from './lib/stores/theme.svelte.js';
  import { tabsStore } from './lib/stores/tabs.svelte.js';
  import { hotkeysStore } from './lib/stores/hotkeys.svelte.js';
  import { onNuiMessages, setUiScale, isEnvBrowser, nuiPost } from './lib/utils/nui.js';

  import Bezel from './lib/components/Bezel.svelte';
  import Toolbar from './lib/components/Toolbar.svelte';
  import Sidebar from './lib/components/Sidebar.svelte';
  import TabBar from './lib/components/TabBar.svelte';
  import PeekZone from './lib/components/PeekZone.svelte';

  import Login from './pages/Login.svelte';
  import Dashboard from './pages/Dashboard.svelte';
  import Citizens from './pages/Citizens.svelte';
  import Vehicles from './pages/Vehicles.svelte';
  import Reports from './pages/Reports.svelte';
  import Cases from './pages/Cases.svelte';
  import Evidence from './pages/Evidence.svelte';
  import Bolos from './pages/Bolos.svelte';
  import Warrants from './pages/Warrants.svelte';
  import Units from './pages/Units.svelte';
  import Settings from './pages/Settings.svelte';
  import Placeholder from './pages/Placeholder.svelte';

  import CivilianLogin from './pages/CivilianLogin.svelte';
  import CivilianDashboard from './pages/CivilianDashboard.svelte';
  import CivilianIdentity from './pages/CivilianIdentity.svelte';
  import CivilianVehicles from './pages/CivilianVehicles.svelte';
  import CivilianRecords from './pages/CivilianRecords.svelte';
  import CivilianServices from './pages/CivilianServices.svelte';
  import CivilianSidebar from './lib/components/CivilianSidebar.svelte';
  import CivilianToolbar from './lib/components/CivilianToolbar.svelte';

  let visible = $derived(mdtStore.visible);
  let peeking = $derived(mdtStore.peeking);
  let loggedIn = $derived(mdtStore.loggedIn);
  let mode = $derived(mdtStore.mode);
  let isCivilian = $derived(mode === 'civilian');

  let tabActivePage = $derived(tabsStore.activePage);
  let civActivePage = $derived(mdtStore.activePage);

  const CIV_PAGE_LABELS = {
    'civ-dashboard': 'Dashboard',
    'civ-identity': 'My Identity',
    'civ-vehicles': 'My Vehicles',
    'civ-records': 'My Records',
    'civ-services': 'City Services',
    'civ-settings': 'Settings',
  };

  $effect(() => {
    if (isCivilian) {
      document.documentElement.setAttribute('data-mode', 'civilian');
    } else {
      document.documentElement.removeAttribute('data-mode');
    }
  });

  function matchesHotkey(e, binding) {
    if (!binding) return false;
    const ctrl = binding.includes('Ctrl');
    const shift = binding.includes('Shift');
    const alt = binding.includes('Alt');
    const parts = binding.split('+');
    const key = parts[parts.length - 1];

    if (ctrl !== (e.ctrlKey || e.metaKey)) return false;
    if (shift !== e.shiftKey) return false;
    if (alt !== e.altKey) return false;

    if (key === 'Tab') return e.key === 'Tab';
    if (key === 'W' || key === 'w') return e.key.toLowerCase() === 'w';
    if (key === 'T' || key === 't') return e.key.toLowerCase() === 't';
    if (key === 'Z' || key === 'z') return e.key.toLowerCase() === 'z';
    if (/^[1-9]$/.test(key)) return e.key === key;
    return e.key === key;
  }

  onMount(() => {
    setUiScale();
    window.addEventListener('resize', setUiScale);

    if (isEnvBrowser()) {
      mdtStore.visible = true;
    }

    const cleanup = onNuiMessages({
      'cortex_mdt:show': (data) => {
        mdtStore.visible = true;
        if (data?.mode === 'civilian') {
          mdtStore.mode = 'civilian';
          mdtStore.activePage = 'civ-dashboard';
          if (data?.civilian) mdtStore.civilian = data.civilian;
        } else {
          mdtStore.mode = 'pd';
          if (data?.officer) {
            const savedCallsign = mdtStore.settings.callsign;
            mdtStore.officer = savedCallsign
              ? { ...data.officer, callsign: savedCallsign }
              : data.officer;
          }
          if (mdtStore.sessionLoggedIn) {
            mdtStore.loggedIn = true;
          } else {
            tabsStore.reset();
          }
        }
      },
      'cortex_mdt:hide': () => {
        mdtStore.visible = false;
      },
      'cortex_mdt:updateOfficer': (data) => {
        if (data) mdtStore.officer = data;
      },
    });

    function handleKeydown(e) {
      if (!mdtStore.visible) return;

      if (e.key === 'Escape') {
        mdtStore.visible = false;
        mdtStore.mode = 'pd';
        nuiPost('cortex_mdt:close');
        return;
      }

      if (!mdtStore.loggedIn || isCivilian) return;

      const bindings = hotkeysStore.bindings;

      if (matchesHotkey(e, bindings.nextTab)) {
        e.preventDefault();
        tabsStore.nextTab();
        return;
      }
      if (matchesHotkey(e, bindings.prevTab)) {
        e.preventDefault();
        tabsStore.prevTab();
        return;
      }
      if (matchesHotkey(e, bindings.closeTab)) {
        e.preventDefault();
        tabsStore.closeTab(tabsStore.activeTabId);
        return;
      }
      if (matchesHotkey(e, bindings.newTab)) {
        e.preventDefault();
        tabsStore.openTab('dashboard', { forceNew: true });
        return;
      }
      if (matchesHotkey(e, bindings.reopenTab)) {
        e.preventDefault();
        tabsStore.reopenLastClosed();
        return;
      }

      if ((e.ctrlKey || e.metaKey) && !e.shiftKey && !e.altKey && /^[1-9]$/.test(e.key)) {
        e.preventDefault();
        const idx = parseInt(e.key) - 1;
        tabsStore.goToTab(idx);
        return;
      }
    }

    window.addEventListener('keydown', handleKeydown);

    return () => {
      cleanup();
      window.removeEventListener('resize', setUiScale);
      window.removeEventListener('keydown', handleKeydown);
    };
  });
</script>

<PeekZone />

{#if visible}
  <div class="mdt-root" class:peeking>
    <Bezel>
      {#if isCivilian}
        {#if !loggedIn}
          <CivilianLogin />
        {:else}
          <CivilianToolbar />
          <div class="mdt-body">
            <CivilianSidebar />
            <main class="mdt-content">
              {#if civActivePage === 'civ-dashboard'}
                <CivilianDashboard />
              {:else if civActivePage === 'civ-identity'}
                <CivilianIdentity />
              {:else if civActivePage === 'civ-vehicles'}
                <CivilianVehicles />
              {:else if civActivePage === 'civ-records'}
                <CivilianRecords />
              {:else if civActivePage === 'civ-services'}
                <CivilianServices />
              {:else if civActivePage === 'civ-settings'}
                <Settings />
              {:else}
                <Placeholder title={CIV_PAGE_LABELS[civActivePage] || 'Unknown'} />
              {/if}
            </main>
          </div>
        {/if}
      {:else}
        {#if !loggedIn}
          <Login />
        {:else}
          <Toolbar />
          <TabBar />
          <div class="mdt-body">
            <Sidebar />
            <main class="mdt-content">
              {#if tabActivePage === 'dashboard'}
                <Dashboard />
              {:else if tabActivePage === 'citizens'}
                <Citizens />
              {:else if tabActivePage === 'vehicles'}
                <Vehicles />
              {:else if tabActivePage === 'reports'}
                <Reports />
              {:else if tabActivePage === 'cases'}
                <Cases />
              {:else if tabActivePage === 'evidence'}
                <Evidence />
              {:else if tabActivePage === 'bolos'}
                <Bolos />
              {:else if tabActivePage === 'warrants'}
                <Warrants />
              {:else if tabActivePage === 'units'}
                <Units />
              {:else if tabActivePage === 'settings'}
                <Settings />
              {:else}
                <Placeholder title={tabsStore.PAGE_META[tabActivePage]?.label || 'Unknown'} />
              {/if}
            </main>
          </div>
        {/if}
      {/if}
    </Bezel>
  </div>
{/if}

<style>
  .mdt-root {
    position: fixed;
    inset: 0;
    z-index: 9999;
    opacity: 1;
    transition: opacity 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    animation: mdtEnter 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .mdt-root.peeking {
    opacity: 0.15;
    transition: opacity 0.6s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .mdt-body {
    flex: 1;
    display: flex;
    overflow: hidden;
  }

  .mdt-content {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    background: var(--mdt-bg);
  }

  @keyframes mdtEnter {
    from {
      opacity: 0;
      transform: scale(0.97);
    }
    to {
      opacity: 1;
      transform: scale(1);
    }
  }
</style>
