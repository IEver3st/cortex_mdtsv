const DEFAULT_BINDINGS = {
  nextTab: 'Ctrl+Tab',
  prevTab: 'Ctrl+Shift+Tab',
  closeTab: 'Ctrl+W',
  newTab: 'Ctrl+T',
  reopenTab: 'Ctrl+Shift+Z',
};

export function normalizeHotkeyBinding(combo, fallback = '') {
  if (typeof combo !== 'string') return fallback;

  const normalized = combo.trim();
  return normalized || fallback;
}

function sanitizeBindings(candidate) {
  if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) {
    return { ...DEFAULT_BINDINGS };
  }

  const next = { ...DEFAULT_BINDINGS };
  for (const action of Object.keys(DEFAULT_BINDINGS)) {
    next[action] = normalizeHotkeyBinding(candidate[action], DEFAULT_BINDINGS[action]);
  }
  return next;
}

const HOTKEY_LABELS = {
  nextTab: 'Next Tab',
  prevTab: 'Previous Tab',
  closeTab: 'Close Tab',
  newTab: 'New Tab',
  reopenTab: 'Reopen Closed Tab',
};

const HOTKEY_DESCRIPTIONS = {
  nextTab: 'Switch to the next open tab',
  prevTab: 'Switch to the previous open tab',
  closeTab: 'Close the current active tab',
  newTab: 'Open a new Dashboard tab',
  reopenTab: 'Reopen the last closed tab',
};

function createHotkeysStore() {
  let bindings = $state({ ...DEFAULT_BINDINGS });

  function persistBindings(nextBindings) {
    try {
      localStorage.setItem('cortex_mdt_hotkeys', JSON.stringify(nextBindings));
    } catch {}
  }

  function updateBinding(action, combo) {
    if (!(action in DEFAULT_BINDINGS)) return;

    const nextBindings = {
      ...bindings,
      [action]: normalizeHotkeyBinding(combo, DEFAULT_BINDINGS[action]),
    };

    bindings = nextBindings;
    persistBindings(nextBindings);
  }

  function resetToDefaults() {
    const nextBindings = { ...DEFAULT_BINDINGS };
    bindings = nextBindings;
    persistBindings(nextBindings);
  }

  function loadFromStorage() {
    try {
      const saved = localStorage.getItem('cortex_mdt_hotkeys');
      if (saved) {
        const parsed = JSON.parse(saved);
        bindings = sanitizeBindings(parsed);
      }
    } catch {}
  }

  loadFromStorage();

  return {
    get bindings() { return bindings; },
    get labels() { return HOTKEY_LABELS; },
    get descriptions() { return HOTKEY_DESCRIPTIONS; },
    get defaults() { return DEFAULT_BINDINGS; },
    updateBinding,
    resetToDefaults,
  };
}

export const hotkeysStore = createHotkeysStore();
