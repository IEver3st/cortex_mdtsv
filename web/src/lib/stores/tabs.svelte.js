import {
  LayoutGrid,
  Users,
  Car,
  FileText,
  FolderOpen,
  AlertTriangle,
  Radio,
  Shield,
  ShieldUser,
  Camera,
  Crosshair,
  Cctv,
  Video,
  Settings,
  Map,
  Trophy,
  Scale,
  GraduationCap,
  BookOpen,
  Landmark,
} from '@lucide/svelte';

const PAGE_META = {
  dashboard:  { label: 'Dashboard',  icon: LayoutGrid,    pinnable: true },
  dispatch:   { label: 'Dispatch',   icon: Map,           pinnable: false },
  citizens:   { label: 'Citizens',   icon: Users,         pinnable: false },
  vehicles:   { label: 'Vehicles',   icon: Car,           pinnable: false },
  reports:    { label: 'Reports',    icon: FileText,      pinnable: false },
  cases:      { label: 'Cases',      icon: FolderOpen,    pinnable: false },
  warrants:   { label: 'Warrants',   icon: AlertTriangle, pinnable: false },
  bolos:      { label: 'BOLOs',      icon: Radio,         pinnable: false },
  units:      { label: 'Units',      icon: Shield,        pinnable: false },
  roster:     { label: 'Roster',     icon: ShieldUser,    pinnable: false },
  cctv:       { label: 'CCTV',       icon: Cctv,          pinnable: false },
  bodycams:   { label: 'Bodycams',   icon: Video,         pinnable: false },
  evidence:   { label: 'Evidence',   icon: Camera,        pinnable: false },
  weapons:    { label: 'Weapons',    icon: Crosshair,     pinnable: false },
  leaderboard:{ label: 'Leaderboard',icon: Trophy,        pinnable: false },
  charges:    { label: 'Charges',    icon: Scale,         pinnable: false },
  fto:        { label: 'FTO',        icon: GraduationCap, pinnable: false },
  sops:       { label: 'SOPs',       icon: BookOpen,      pinnable: false },
  command:    { label: 'Command',    icon: Landmark,      pinnable: false },
  settings:   { label: 'Settings',   icon: Settings,      pinnable: false },
};

let _idCounter = 0;
function nextId() {
  return `tab_${++_idCounter}_${Date.now()}`;
}

function createTabsStore() {
  const defaultTab = {
    id: 'tab_dashboard',
    pageId: 'dashboard',
    label: 'Dashboard',
    icon: LayoutGrid,
    pinned: true,
    closable: false,
  };

  let tabs = $state([{ ...defaultTab }]);
  let activeTabId = $state('tab_dashboard');
  let recentlyClosed = $state([]);
  let dragTarget = $state(null);

  function getActiveTab() {
    return tabs.find(t => t.id === activeTabId) || tabs[0];
  }

  function openTab(pageId, opts = {}) {
    const meta = PAGE_META[pageId];
    if (!meta) return;

    const label = opts.label || meta.label;
    const subtitle = opts.subtitle || null;

    if (!opts.forceNew) {
      const existing = tabs.find(t => t.pageId === pageId && !t.subtitle);
      if (existing && !subtitle) {
        activeTabId = existing.id;
        return existing;
      }
      if (subtitle) {
        const existingSub = tabs.find(t => t.pageId === pageId && t.subtitle === subtitle);
        if (existingSub) {
          activeTabId = existingSub.id;
          return existingSub;
        }
      }
    }

    const newTab = {
      id: nextId(),
      pageId,
      label: subtitle ? `${label}: ${subtitle}` : label,
      subtitle,
      icon: meta.icon,
      pinned: false,
      closable: true,
    };

    const activeIdx = tabs.findIndex(t => t.id === activeTabId);
    const insertIdx = activeIdx >= 0 ? activeIdx + 1 : tabs.length;
    tabs = [...tabs.slice(0, insertIdx), newTab, ...tabs.slice(insertIdx)];
    activeTabId = newTab.id;
    return newTab;
  }

  function closeTab(tabId) {
    const idx = tabs.findIndex(t => t.id === tabId);
    if (idx < 0) return;

    const tab = tabs[idx];
    if (!tab.closable || tab.pinned) return;

    recentlyClosed = [{ ...tab, closedAt: Date.now() }, ...recentlyClosed].slice(0, 10);

    if (activeTabId === tabId) {
      const nextTab = tabs[idx + 1] || tabs[idx - 1];
      activeTabId = nextTab ? nextTab.id : null;
    }

    tabs = tabs.filter(t => t.id !== tabId);

    if (tabs.length === 0) {
      tabs = [{ ...defaultTab }];
      activeTabId = 'tab_dashboard';
    }
  }

  function closeOtherTabs(keepTabId) {
    const keep = tabs.filter(t => t.id === keepTabId || t.pinned || !t.closable);
    const closed = tabs.filter(t => t.id !== keepTabId && !t.pinned && t.closable);
    closed.forEach(t => {
      recentlyClosed = [{ ...t, closedAt: Date.now() }, ...recentlyClosed].slice(0, 10);
    });
    tabs = keep;
    if (!tabs.find(t => t.id === activeTabId)) {
      activeTabId = keepTabId;
    }
  }

  function closeTabsToRight(tabId) {
    const idx = tabs.findIndex(t => t.id === tabId);
    if (idx < 0) return;
    const toClose = tabs.slice(idx + 1).filter(t => t.closable && !t.pinned);
    toClose.forEach(t => {
      recentlyClosed = [{ ...t, closedAt: Date.now() }, ...recentlyClosed].slice(0, 10);
    });
    const keepIds = new Set(tabs.slice(0, idx + 1).map(t => t.id).concat(tabs.filter(t => t.pinned || !t.closable).map(t => t.id)));
    tabs = tabs.filter(t => keepIds.has(t.id));
    if (!tabs.find(t => t.id === activeTabId)) {
      activeTabId = tabId;
    }
  }

  function activateTab(tabId) {
    if (tabs.find(t => t.id === tabId)) {
      activeTabId = tabId;
    }
  }

  function nextTab() {
    if (tabs.length <= 1) return;
    const idx = tabs.findIndex(t => t.id === activeTabId);
    const next = (idx + 1) % tabs.length;
    activeTabId = tabs[next].id;
  }

  function prevTab() {
    if (tabs.length <= 1) return;
    const idx = tabs.findIndex(t => t.id === activeTabId);
    const prev = (idx - 1 + tabs.length) % tabs.length;
    activeTabId = tabs[prev].id;
  }

  function goToTab(index) {
    if (index >= 0 && index < tabs.length) {
      activeTabId = tabs[index].id;
    }
  }

  function pinTab(tabId) {
    tabs = tabs.map(t => {
      if (t.id === tabId) return { ...t, pinned: true, closable: false };
      return t;
    });
    const pinned = tabs.filter(t => t.pinned);
    const unpinned = tabs.filter(t => !t.pinned);
    tabs = [...pinned, ...unpinned];
  }

  function unpinTab(tabId) {
    if (tabId === 'tab_dashboard') return;
    tabs = tabs.map(t => {
      if (t.id === tabId) return { ...t, pinned: false, closable: true };
      return t;
    });
  }

  function moveTab(fromIdx, toIdx) {
    if (fromIdx === toIdx) return;
    const moved = tabs[fromIdx];
    const newTabs = [...tabs];
    newTabs.splice(fromIdx, 1);
    newTabs.splice(toIdx, 0, moved);
    tabs = newTabs;
  }

  function reopenLastClosed() {
    if (recentlyClosed.length === 0) return;
    const last = recentlyClosed[0];
    recentlyClosed = recentlyClosed.slice(1);
    const restored = {
      id: nextId(),
      pageId: last.pageId,
      label: last.label,
      subtitle: last.subtitle,
      icon: last.icon,
      pinned: false,
      closable: true,
    };
    tabs = [...tabs, restored];
    activeTabId = restored.id;
  }

  function duplicateTab(tabId) {
    const tab = tabs.find(t => t.id === tabId);
    if (!tab) return;
    openTab(tab.pageId, { subtitle: tab.subtitle, forceNew: true });
  }

  function updateTabLabel(tabId, newLabel) {
    tabs = tabs.map(t => {
      if (t.id === tabId) return { ...t, label: newLabel };
      return t;
    });
  }

  function reset() {
    _idCounter = 0;
    tabs = [{ ...defaultTab }];
    activeTabId = 'tab_dashboard';
    recentlyClosed = [];
  }

  return {
    get tabs() { return tabs; },
    get activeTabId() { return activeTabId; },
    set activeTabId(v) { activeTabId = v; },
    get activeTab() { return getActiveTab(); },
    get activePage() { return getActiveTab()?.pageId || 'dashboard'; },
    get tabCount() { return tabs.length; },
    get recentlyClosed() { return recentlyClosed; },
    get dragTarget() { return dragTarget; },
    set dragTarget(v) { dragTarget = v; },

    openTab,
    closeTab,
    closeOtherTabs,
    closeTabsToRight,
    activateTab,
    nextTab,
    prevTab,
    goToTab,
    pinTab,
    unpinTab,
    moveTab,
    reopenLastClosed,
    duplicateTab,
    updateTabLabel,
    reset,
    PAGE_META,
  };
}

export const tabsStore = createTabsStore();
