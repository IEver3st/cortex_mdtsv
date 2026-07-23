const STORAGE_KEY = 'cortex_mdt_dashboard_layout';

export const WIDGET_DEFS = [
  {
    id: 'statCards',
    label: 'Stat Cards',
    description: 'Active calls, reports, warrants & units summary',
    group: 'header',
    defaultVisible: true,
    alwaysVisible: false,
  },
  {
    id: 'announcements',
    label: 'Bulletins & Announcements',
    description: 'Department bulletins and SOPs',
    group: 'header',
    defaultVisible: true,
    alwaysVisible: false,
  },
  {
    id: 'quickActions',
    label: 'Quick Actions',
    description: 'Shortcuts: status + templated reports',
    group: 'left',
    defaultVisible: true,
    alwaysVisible: false,
  },
  {
    id: 'dispatch',
    label: 'Recent Dispatch',
    description: 'Live active CAD calls',
    group: 'left',
    defaultVisible: true,
    alwaysVisible: false,
  },
  {
    id: 'reports',
    label: 'Recent Reports',
    description: 'Latest submitted incident reports',
    group: 'left',
    defaultVisible: true,
    alwaysVisible: false,
  },
  {
    id: 'bolos',
    label: 'Active BOLOs',
    description: 'Be On the Lookout bulletins',
    group: 'left',
    defaultVisible: true,
    alwaysVisible: false,
  },
  {
    id: 'officers',
    label: 'Officers On Duty',
    description: 'Live roster of on-duty personnel',
    group: 'right',
    defaultVisible: true,
    alwaysVisible: false,
  },
  {
    id: 'chat',
    label: 'Officer Chat',
    description: 'Real-time broadcast channel',
    group: 'right',
    defaultVisible: true,
    alwaysVisible: false,
  },
];

function loadSaved() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function buildDefaults() {
  const map = {};
  for (const w of WIDGET_DEFS) {
    map[w.id] = w.defaultVisible;
  }
  return map;
}

function createDashboardLayoutStore() {
  const saved = loadSaved();
  const defaults = buildDefaults();

  let visibility = $state(saved ? { ...defaults, ...saved } : { ...defaults });
  let customizerOpen = $state(false);

  function isVisible(id) {
    const def = WIDGET_DEFS.find((w) => w.id === id);
    if (def?.alwaysVisible) return true;
    return visibility[id] !== false;
  }

  function toggle(id) {
    const def = WIDGET_DEFS.find((w) => w.id === id);
    if (def?.alwaysVisible) return;
    visibility = { ...visibility, [id]: !visibility[id] };
    persist();
  }

  function setVisible(id, val) {
    const def = WIDGET_DEFS.find((w) => w.id === id);
    if (def?.alwaysVisible) return;
    visibility = { ...visibility, [id]: val };
    persist();
  }

  function resetToDefaults() {
    visibility = { ...defaults };
    persist();
  }

  function persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(visibility));
    } catch {}
  }

  function openCustomizer() {
    customizerOpen = true;
  }

  function closeCustomizer() {
    customizerOpen = false;
  }

  return {
    get visibility() { return visibility; },
    get customizerOpen() { return customizerOpen; },
    isVisible,
    toggle,
    setVisible,
    resetToDefaults,
    openCustomizer,
    closeCustomizer,
  };
}

export const dashboardLayout = createDashboardLayoutStore();
