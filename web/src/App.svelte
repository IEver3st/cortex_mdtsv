<script>
  import { onMount, tick } from 'svelte';
  import { cubicOut } from 'svelte/easing';
  import { fade } from 'svelte/transition';
  import { mdtStore } from './lib/stores/mdt.svelte.js';
  import { themeStore } from './lib/stores/theme.svelte.js';
  import { tabsStore } from './lib/stores/tabs.svelte.js';
  import { hotkeysStore, normalizeHotkeyBinding } from './lib/stores/hotkeys.svelte.js';
  import { onNuiMessages, setUiScale, isEnvBrowser, nuiPost } from './lib/utils/nui.js';
  import { playMdtSound } from './lib/utils/mdtSounds.js';
  import { dataStore } from './lib/stores/data.svelte.js';
  import { findQuickActionForHotkeyEvent, quickActionsStore } from './lib/stores/quickActions.svelte.js';

  import Bezel from './lib/components/Bezel.svelte';
  import Toolbar from './lib/components/Toolbar.svelte';
  import Sidebar from './lib/components/Sidebar.svelte';
  import TabBar from './lib/components/TabBar.svelte';
  import PeekZone from './lib/components/PeekZone.svelte';
  import Login from './pages/Login.svelte';
  import Dashboard from './pages/Dashboard.svelte';
  import Dispatch from './pages/Dispatch.svelte';
  import Citizens from './pages/Citizens.svelte';
  import Vehicles from './pages/Vehicles.svelte';
  import Reports from './pages/Reports.svelte';
  import Cases from './pages/Cases.svelte';
  import Evidence from './pages/Evidence.svelte';
  import CCTV from './pages/CCTV.svelte';
  import Bodycams from './pages/Bodycams.svelte';
  import Bolos from './pages/Bolos.svelte';
  import Warrants from './pages/Warrants.svelte';
  import Units from './pages/Units.svelte';
  import Roster from './pages/Roster.svelte';
  import Settings from './pages/Settings.svelte';
  import Weapons from './pages/Weapons.svelte';
  import Leaderboard from './pages/Leaderboard.svelte';
  import Charges from './pages/Charges.svelte';
  import FTO from './pages/FTO.svelte';
  import SOPs from './pages/SOPs.svelte';
  import Command from './pages/Command.svelte';
  import Placeholder from './pages/Placeholder.svelte';

  import CivilianLogin from './pages/CivilianLogin.svelte';
  import CivilianDashboard from './pages/CivilianDashboard.svelte';
  import CivilianIdentity from './pages/CivilianIdentity.svelte';
  import CivilianVehicles from './pages/CivilianVehicles.svelte';
  import CivilianRecords from './pages/CivilianRecords.svelte';
  import CivilianServices from './pages/CivilianServices.svelte';
  import CivilianSidebar from './lib/components/CivilianSidebar.svelte';
  import CivilianToolbar from './lib/components/CivilianToolbar.svelte';
  import CitationView from './lib/components/CitationView.svelte';
  import ComplaintForm from './lib/components/ComplaintForm.svelte';

  let visible = $derived(mdtStore.visible);
  let peeking = $derived(mdtStore.peeking);
  let loggedIn = $derived(mdtStore.loggedIn);
  let mode = $derived(mdtStore.mode);
  let isCivilian = $derived(mode === 'civilian');

  let tabActivePage = $derived(tabsStore.activePage);
  let civActivePage = $derived(mdtStore.activePage);
  let cctvFeedActive = $derived(tabActivePage === 'cctv' && !!dataStore.activeCameraFeed);
  let bodycamFeedActive = $derived(tabActivePage === 'bodycams' && !!dataStore.activeBodycamFeed);
  let cameraFeedActive = $derived(cctvFeedActive || bodycamFeedActive);
  let complaintOpen = $state(false);
  let complaintDefaults = $state({ reporterName: '' });
  let complaintReturnFocus = null;

  async function closeComplaintUi() {
    if (!complaintOpen) return;
    const returnFocus = complaintReturnFocus;
    complaintOpen = false;
    complaintReturnFocus = null;
    await tick();
    if (returnFocus?.isConnected) returnFocus.focus?.();
  }

  const CIV_PAGE_LABELS = {
    'civ-dashboard': 'Dashboard',
    'civ-identity': 'My Identity',
    'civ-vehicles': 'My Vehicles',
    'civ-records': 'My Records',
    'civ-services': 'City Services',
    'civ-settings': 'Settings',
  };

  /** Post-login: opacity-only on authed root (fly + dual fades on huge DOM = jank). */
  const mainFadeIn = { duration: 150, easing: cubicOut };
  const mainFadeSkip = { duration: 0, easing: cubicOut };
  let mainFadeParams = $derived(mdtStore.pendingAuthedIntro ? mainFadeIn : mainFadeSkip);

  $effect(() => {
    if (!loggedIn || !mdtStore.pendingAuthedIntro) return;
    const t = setTimeout(() => mdtStore.clearAuthedIntro(), mainFadeIn.duration + 40);
    return () => clearTimeout(t);
  });

  $effect(() => {
    if (isCivilian) {
      document.documentElement.setAttribute('data-mode', 'civilian');
    } else {
      document.documentElement.removeAttribute('data-mode');
    }
  });

  function isEditableTarget(target) {
    if (!target) return false;
    const el = target;
    const tag = el.tagName;
    if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return true;
    if (el.isContentEditable) return true;
    return !!el.closest?.('[contenteditable="true"]');
  }

  function matchesHotkey(e, binding) {
    const combo = normalizeHotkeyBinding(binding);
    if (!combo) return false;

    const ctrl = combo.includes('Ctrl');
    const shift = combo.includes('Shift');
    const alt = combo.includes('Alt');
    const parts = combo.split('+');
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

    let disposed = false;

    async function init() {
      const savedSettings = await mdtStore.initSettings();
      if (disposed) return;

      themeStore.apply(savedSettings.theme || 'default');

      if (isEnvBrowser()) {
        mdtStore.visible = true;
      }
    }

    init();

    const cleanup = onNuiMessages({
      'cortex_mdt:show': (data) => {
        mdtStore.visible = true;
        if (data?.mode === 'civilian') {
          mdtStore.mode = 'civilian';
          mdtStore.activePage = 'civ-dashboard';
          if (data?.civilian) mdtStore.civilian = data.civilian;
          if (typeof data?.playerName === 'string') mdtStore.gameUsername = data.playerName;
        } else {
          mdtStore.mode = 'pd';
          if (data?.officer) {
            const frameworkMode = String(data.officer.frameworkMode || '').toLowerCase();
            const useLocalProfileSettings = frameworkMode !== '' && frameworkMode !== 'qbx';
            const savedCallsign = useLocalProfileSettings ? mdtStore.settings.callsign : '';
            const savedAvatarUrl = useLocalProfileSettings ? mdtStore.settings.avatarUrl : null;
            const df =
              frameworkMode === 'standalone'
                ? String(mdtStore.settings.officerDisplayFirstName || '').trim()
                : '';
            const dl =
              frameworkMode === 'standalone'
                ? String(mdtStore.settings.officerDisplayLastName || '').trim()
                : '';
            mdtStore.officer = {
              ...data.officer,
              officerId: mdtStore.officer.officerId || data.officer.officerId || data.officer.officer_id || data.officer.id || null,
              callsign: savedCallsign || data.officer.callsign,
              avatar: savedAvatarUrl || data.officer.avatar,
              ...(frameworkMode === 'standalone'
                ? {
                    firstName: df || data.officer.firstName,
                    lastName: dl || data.officer.lastName,
                  }
                : {}),
            };
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
        if (data) {
          const frameworkMode = String(data.frameworkMode || '').toLowerCase();
          const df =
            frameworkMode === 'standalone'
              ? String(mdtStore.settings.officerDisplayFirstName || '').trim()
              : '';
          const dl =
            frameworkMode === 'standalone'
              ? String(mdtStore.settings.officerDisplayLastName || '').trim()
              : '';
          mdtStore.officer = {
            ...data,
            officerId: mdtStore.officer.officerId || data.officerId || data.officer_id || data.id || null,
            ...(frameworkMode === 'standalone'
              ? {
                  firstName: df || data.firstName,
                  lastName: dl || data.lastName,
                }
              : {}),
          };
        }
      },
      'cortex_mdt:update': (data) => {
        if (!data?.event) return;
        const { event, data: payload } = data;
        if (event === 'dispatch') {
          dataStore.dispatchCalls = payload || [];
        } else if (event === 'units') {
          dataStore.dispatchActiveUnits = payload || [];
        } else if (event === 'dispatch:snapshot') {
          dataStore.dispatchCalls = payload?.calls || [];
          dataStore.dispatchActiveUnits = payload?.units || [];
          if (dataStore.selectedDispatchId && !dataStore.dispatchCalls.find((call) => call.id === dataStore.selectedDispatchId)) {
            dataStore.selectedDispatchId = null;
          }
        } else if (event === 'dispatch:attach') {
          dataStore.fetchDispatch();
        } else if (event === 'dispatch:panic') {
          dataStore.fetchDispatch();
        } else if (event === 'dispatch:selectCall' && payload?.dispatchId) {
          dataStore.selectedDispatchId = payload.dispatchId;
        }
      },
      'cortex_mdt:bodycamLocation': (data) => {
        dataStore.bodycamLiveLocation = typeof data?.location === 'string' ? data.location : '';
      },
      'cortex_mdt:cameraFeedState': (data) => {
        dataStore.cameraFeedState = data || { state: 'idle' };
        if (data?.state === 'disconnected') {
          dataStore.activeBodycamFeed = null;
        }
      },
      'cortex_mdt:bodycamAvailability': (data) => {
        dataStore.cameraFeedState = {
          availabilityEnabled: data?.enabled === true,
          availabilityMessage: typeof data?.message === 'string' ? data.message : '',
        };
      },
      'cortex_mdt:showComplaint': (data) => {
        if (!complaintOpen) complaintReturnFocus = document.activeElement;
        complaintDefaults = {
          reporterName: typeof data?.reporterName === 'string' ? data.reporterName : '',
        };
        complaintOpen = true;
      },
      'cortex_mdt:hideComplaint': () => {
        void closeComplaintUi();
      },
      'cortex_mdt:showCitation': (data) => {
        mdtStore.showCitation = true;
        if (data?.playerName && !data?.id) {
          mdtStore.citationData = null;
        } else {
          mdtStore.citationData = data || null;
        }
      },
      'cortex_mdt:hideCitation': () => {
        mdtStore.showCitation = false;
        mdtStore.citationData = null;
        mdtStore.citationsList = [];
      },
    });

    function handleKeydown(e) {
      if (!mdtStore.visible) return;
      if (complaintOpen) return;
      if (e.defaultPrevented) return;

      // Page-level dialogs own Escape first. The dialog may unmount during the
      // same key event, so honour both its current presence and preventDefault.
      if (e.key === 'Escape' && document.querySelector('[role="dialog"][aria-modal="true"]')) return;

      if (e.key === 'Escape') {
        if (dataStore.activeCameraFeed && tabsStore.activePage === 'cctv') {
          e.preventDefault();
          void dataStore.stopCameraView();
          return;
        }
        if (dataStore.activeBodycamFeed && tabsStore.activePage === 'bodycams') {
          e.preventDefault();
          void dataStore.stopCameraView();
          return;
        }
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

      if (!isEditableTarget(e.target)) {
        const qaId = findQuickActionForHotkeyEvent(e);
        if (qaId) {
          e.preventDefault();
          quickActionsStore.runAction(qaId);
          return;
        }
      }
    }

    function handleMdtUiPointerDown(e) {
      if (!mdtStore.visible || !mdtStore.loggedIn || mdtStore.mode !== 'pd') return;
      const t = e.target;
      if (!t || !(t instanceof Element)) return;
      if (t.closest('[data-mdt-no-ui-sound]')) return;
      if (t.closest('input, textarea, select, [contenteditable="true"]')) return;
      const interactive = t.closest('button, a[href], [role="button"], .nav-item, label.pin-toggle');
      if (!interactive) return;
      playMdtSound('ui_click');
    }

    window.addEventListener('keydown', handleKeydown);
    window.addEventListener('pointerdown', handleMdtUiPointerDown, true);

    return () => {
      disposed = true;
      cleanup();
      window.removeEventListener('resize', setUiScale);
      window.removeEventListener('keydown', handleKeydown);
      window.removeEventListener('pointerdown', handleMdtUiPointerDown, true);
    };
  });
</script>

{#if visible}
  <div
    class="mdt-root"
    class:cctv-feed-active={cctvFeedActive}
    class:bodycam-feed-active={bodycamFeedActive}
  >
    <PeekZone />
    <div class="mdt-shell" class:peeking>
      <Bezel transparentContent={cameraFeedActive}>
      {#if isCivilian}
        {#if !loggedIn}
          <div class="mdt-login-shell">
            <CivilianLogin />
          </div>
        {:else}
          <div class="mdt-authed-shell" in:fade={mainFadeParams}>
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
          </div>
        {/if}
      {:else}
        {#if !loggedIn}
          <div class="mdt-login-shell">
            <Login />
          </div>
        {:else}
          <div class="mdt-authed-shell" in:fade={mainFadeParams}>
            <Toolbar />
            <TabBar />
            <div class="mdt-body">
              <Sidebar />
              <main class="mdt-content">
                {#if tabActivePage === 'dashboard'}
                  <Dashboard />
                {:else if tabActivePage === 'dispatch'}
                  <Dispatch />
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
                {:else if tabActivePage === 'roster'}
                  <Roster />
                {:else if tabActivePage === 'cctv'}
                  <CCTV />
                {:else if tabActivePage === 'bodycams'}
                  <Bodycams />
                {:else if tabActivePage === 'weapons'}
                  <Weapons />
                {:else if tabActivePage === 'leaderboard'}
                  <Leaderboard />
                {:else if tabActivePage === 'charges'}
                  <Charges />
                {:else if tabActivePage === 'fto'}
                  <FTO />
                {:else if tabActivePage === 'sops'}
                  <SOPs />
                {:else if tabActivePage === 'command'}
                  <Command />
                {:else if tabActivePage === 'settings'}
                  <Settings />
                {:else}
                  <Placeholder title={tabsStore.PAGE_META[tabActivePage]?.label || 'Unknown'} />
                {/if}
              </main>
            </div>
          </div>
        {/if}
      {/if}
      </Bezel>
    </div>
  </div>
{/if}

{#if mdtStore.showCitation}
  <CitationView />
{/if}

<ComplaintForm show={complaintOpen} defaults={complaintDefaults} onClose={closeComplaintUi} />

<style>
  .mdt-root {
    position: fixed;
    inset: 0;
    z-index: 9999;
    opacity: 1;
    transition: opacity 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    animation: mdtEnter 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .mdt-login-shell,
  .mdt-authed-shell {
    position: relative;
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .mdt-shell {
    position: absolute;
    inset: 0;
    opacity: 1;
    transition:
      opacity 0.45s cubic-bezier(0.16, 1, 0.3, 1),
      filter 0.45s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .mdt-shell.peeking {
    opacity: 0.22;
    filter: saturate(0.9);
    pointer-events: none;
  }

  .mdt-body {
    flex: 1;
    display: flex;
    overflow: hidden;
  }

  .mdt-content {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    overflow-x: hidden;
    background: var(--mdt-bg);
  }

  /* CCTV + bodycam live: full-bleed game under UI (child components → :global) */
  .mdt-root.cctv-feed-active :global(.toolbar),
  .mdt-root.cctv-feed-active :global(.tab-bar-wrap),
  .mdt-root.cctv-feed-active :global(.sidebar),
  .mdt-root.bodycam-feed-active :global(.toolbar),
  .mdt-root.bodycam-feed-active :global(.tab-bar-wrap),
  .mdt-root.bodycam-feed-active :global(.sidebar) {
    display: none !important;
  }

  .mdt-root.cctv-feed-active :global(.bezel-frame),
  .mdt-root.bodycam-feed-active :global(.bezel-frame) {
    inset: 0;
    border-radius: 0;
    padding: 0;
    background: transparent;
    box-shadow: none;
  }

  .mdt-root.cctv-feed-active :global(.bezel-frame)::before,
  .mdt-root.cctv-feed-active :global(.bezel-frame)::after,
  .mdt-root.bodycam-feed-active :global(.bezel-frame)::before,
  .mdt-root.bodycam-feed-active :global(.bezel-frame)::after {
    display: none;
  }

  .mdt-root.cctv-feed-active .mdt-body,
  .mdt-root.cctv-feed-active .mdt-content,
  .mdt-root.bodycam-feed-active .mdt-body,
  .mdt-root.bodycam-feed-active .mdt-content {
    background: transparent;
  }

  .mdt-root.cctv-feed-active .mdt-content,
  .mdt-root.bodycam-feed-active .mdt-content {
    position: relative;
    overflow: hidden;
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
