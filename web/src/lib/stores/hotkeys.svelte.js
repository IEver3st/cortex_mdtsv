const DEFAULT_BINDINGS = {
  nextTab: 'Ctrl+Tab',
  prevTab: 'Ctrl+Shift+Tab',
  closeTab: 'Ctrl+W',
  newTab: 'Ctrl+T',
  reopenTab: 'Ctrl+Shift+Z',
};

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

  function updateBinding(action, combo) {
    bindings = { ...bindings, [action]: combo };
    try {
      localStorage.setItem('cortex_mdt_hotkeys', JSON.stringify(bindings));
    } catch {}
  }

  function resetToDefaults() {
    bindings = { ...DEFAULT_BINDINGS };
    try {
      localStorage.setItem('cortex_mdt_hotkeys', JSON.stringify(bindings));
    } catch {}
  }

  function loadFromStorage() {
    try {
      const saved = localStorage.getItem('cortex_mdt_hotkeys');
      if (saved) {
        const parsed = JSON.parse(saved);
        bindings = { ...DEFAULT_BINDINGS, ...parsed };
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
