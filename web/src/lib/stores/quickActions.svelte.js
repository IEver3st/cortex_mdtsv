import { tabsStore } from './tabs.svelte.js';
import { dataStore } from './data.svelte.js';
import { mdtStore } from './mdt.svelte.js';
import { queueReportsCompose } from './reportsCompose.svelte.js';
import { findUnitForOfficer } from '../utils/helpers.js';
import { REPORT_TEMPLATES } from '../data/reportTemplates.js';

const STORAGE_KEY = 'cortex_mdt_quick_actions_v1';

/** @typedef {{ id: string, label: string, description: string, icon: string, unitStatus: string | null, reportTemplate: string | null, defaultTitle: string, defaultNarrative: string }} QuickActionDef */

/** @type {QuickActionDef[]} */
export const QUICK_ACTION_CATALOG = [
  {
    id: 'traffic_stop',
    label: 'Traffic Stop',
    description: 'Set Busy + new Traffic Citation draft',
    icon: 'Car',
    unitStatus: 'busy',
    reportTemplate: 'Traffic Citation',
    defaultTitle: 'Traffic Stop',
    defaultNarrative:
      '**Location:**\n**Vehicle / plate:**\n**Reason for stop:**\n**Occupants:**\n**Outcome (warning / citation / arrest):**\n**Notes:**\n',
  },
  {
    id: 'incident_scene',
    label: 'On Scene (Incident)',
    description: 'Set On Scene + Incident Report draft',
    icon: 'MapPin',
    unitStatus: 'on_scene',
    reportTemplate: 'Incident Report',
    defaultTitle: 'Incident',
    defaultNarrative: '**Location:**\n**Summary:**\n**Parties involved:**\n**Evidence / photos:**\n',
  },
  {
    id: 'en_route',
    label: 'En Route',
    description: 'Set En Route (no report)',
    icon: 'Navigation',
    unitStatus: 'en_route',
    reportTemplate: null,
    defaultTitle: '',
    defaultNarrative: '',
  },
  {
    id: 'code_run',
    label: 'Code / Emergency',
    description: 'Set Emergency status',
    icon: 'Siren',
    unitStatus: 'emergency',
    reportTemplate: null,
    defaultTitle: '',
    defaultNarrative: '',
  },
  {
    id: 'arrest_report',
    label: 'Arrest Report',
    description: 'Set Busy + Arrest Report draft',
    icon: 'Shield',
    unitStatus: 'busy',
    reportTemplate: 'Arrest Report',
    defaultTitle: 'Arrest',
    defaultNarrative: '**Charges:**\n**Circumstances:**\n**Use of force:**\n**Medical:**\n',
  },
  {
    id: 'uof_report',
    label: 'Use of Force',
    description: 'Set On Scene + UOF report draft',
    icon: 'AlertTriangle',
    unitStatus: 'on_scene',
    reportTemplate: 'Use of Force',
    defaultTitle: 'Use of Force',
    defaultNarrative: '**Type:**\n**Subject:**\n**Resistance:**\n**Injuries:**\n**Supervisor notified:**\n',
  },
  {
    id: 'general_report',
    label: 'General Report',
    description: 'Set Available + General Report draft',
    icon: 'FileText',
    unitStatus: 'available',
    reportTemplate: 'General Report',
    defaultTitle: 'General Report',
    defaultNarrative: '',
  },
];

const DEFAULT_ORDER = [
  'traffic_stop',
  'incident_scene',
  'en_route',
  'code_run',
  'arrest_report',
  'uof_report',
  'general_report',
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

function normalizeOrder(order) {
  const catalogIds = new Set(QUICK_ACTION_CATALOG.map((a) => a.id));
  const seen = new Set();
  const out = [];
  for (const id of order || []) {
    if (catalogIds.has(id) && !seen.has(id)) {
      seen.add(id);
      out.push(id);
    }
  }
  return out;
}

function createQuickActionsStore() {
  const saved = loadSaved();
  const initialOrder = saved?.order?.length ? saved.order : DEFAULT_ORDER;
  let order = $state(normalizeOrder(initialOrder));
  /** @type {Record<string, string>} actionId → combo e.g. Ctrl+Alt+1 */
  let hotkeys = $state(
    typeof saved?.hotkeys === 'object' && saved.hotkeys ? { ...saved.hotkeys } : {}
  );

  function persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ order, hotkeys }));
    } catch {}
  }

  function getDef(id) {
    return QUICK_ACTION_CATALOG.find((a) => a.id === id);
  }

  function setOrder(next) {
    order = normalizeOrder(next);
    persist();
  }

  function moveInOrder(id, delta) {
    const idx = order.indexOf(id);
    if (idx < 0) return;
    const n = idx + delta;
    if (n < 0 || n >= order.length) return;
    const copy = [...order];
    const [removed] = copy.splice(idx, 1);
    copy.splice(n, 0, removed);
    order = copy;
    persist();
  }

  function setHotkey(actionId, combo) {
    const c = (combo || '').trim();
    const next = { ...hotkeys };
    for (const k of Object.keys(next)) {
      if (next[k] === c && k !== actionId) delete next[k];
    }
    if (!c) {
      delete next[actionId];
    } else {
      next[actionId] = c;
    }
    hotkeys = next;
    persist();
  }

  function resetLayout() {
    order = normalizeOrder([...DEFAULT_ORDER]);
    hotkeys = {};
    persist();
  }

  function addToOrder(actionId) {
    if (order.includes(actionId)) return;
    order = normalizeOrder([...order, actionId]);
    persist();
  }

  function removeFromOrder(actionId) {
    order = normalizeOrder(order.filter((id) => id !== actionId));
    persist();
  }

  async function runAction(actionId) {
    const def = getDef(actionId);
    if (!def) return;

    const units = dataStore.unitsList || [];
    const officer = mdtStore.officer;
    const myUnit = findUnitForOfficer(units, officer);
    const currentStatus = myUnit?.status || 'off_duty';
    const isOnDuty = currentStatus !== 'off_duty';

    if (def.unitStatus && isOnDuty) {
      await dataStore.updateUnitStatus(def.unitStatus, myUnit?.assignment || '');
    }

    if (def.reportTemplate && REPORT_TEMPLATES.includes(def.reportTemplate)) {
      queueReportsCompose({
        template: def.reportTemplate,
        title: def.defaultTitle || '',
        narrative: def.defaultNarrative || '',
      });
      tabsStore.openTab('reports');
    }
  }

  return {
    get order() {
      return order;
    },
    get hotkeys() {
      return hotkeys;
    },
    getDef,
    setOrder,
    moveInOrder,
    setHotkey,
    resetLayout,
    addToOrder,
    removeFromOrder,
    runAction,
  };
}

export const quickActionsStore = createQuickActionsStore();

/** Match binding string like Ctrl+Alt+1 — used from App.svelte */
export function matchesQuickActionHotkey(e, binding) {
  if (!binding?.trim()) return false;
  const parts = binding.split('+').map((s) => s.trim());
  const key = parts[parts.length - 1];
  const wantCtrl = parts.includes('Ctrl') || parts.includes('Control');
  const wantShift = parts.includes('Shift');
  const wantAlt = parts.includes('Alt');
  if (wantCtrl !== (e.ctrlKey || e.metaKey)) return false;
  if (wantShift !== e.shiftKey) return false;
  if (wantAlt !== e.altKey) return false;

  if (key === 'Tab') return e.key === 'Tab';
  if (/^F\d{1,2}$/i.test(key)) return e.key.toLowerCase() === key.toLowerCase();
  if (key.length === 1) return e.key.toLowerCase() === key.toLowerCase();
  if (/^[0-9]$/.test(key)) return e.key === key;
  return e.key === key;
}

export function findQuickActionForHotkeyEvent(e) {
  const h = quickActionsStore.hotkeys;
  for (const actionId of Object.keys(h)) {
    if (matchesQuickActionHotkey(e, h[actionId])) return actionId;
  }
  return null;
}
