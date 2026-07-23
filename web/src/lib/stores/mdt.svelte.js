import { localStorageStore } from './localStorage.svelte.js';

const STORAGE_KEY = 'cortex_mdt_settings';

const DEFAULT_SOUNDS = {
  master: true,
  biometric: true,
  status: true,
  dashboard: true,
  uiClick: true,
  logout: true,
  /** exec_navigate | warehouse_mouse | hangar_click */
  uiClickPreset: 'exec_navigate',
};

const DEFAULT_SETTINGS = {
  theme: 'default',
  avatarUrl: null,
  callsign: '',
  /** Standalone: custom officer display names (persisted locally). */
  officerDisplayFirstName: '',
  officerDisplayLastName: '',
  sounds: { ...DEFAULT_SOUNDS },
};

function mergeSounds(raw) {
  const s = raw && typeof raw.sounds === 'object' ? raw.sounds : {};
  return { ...DEFAULT_SOUNDS, ...s };
}

function hasBrowserLocalStorage() {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';
}

function readBrowserSettings() {
  if (!hasBrowserLocalStorage()) {
    return null;
  }

  try {
    const rawValue = window.localStorage.getItem(STORAGE_KEY);
    return rawValue ? JSON.parse(rawValue) : null;
  } catch {
    return null;
  }
}

async function writeBrowserSettings(settings) {
  if (!hasBrowserLocalStorage()) {
    return false;
  }

  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
    return true;
  } catch {
    return false;
  }
}

async function loadSettings() {
  const browserSaved = readBrowserSettings();
  if (browserSaved && typeof browserSaved === 'object') {
    return { ...DEFAULT_SETTINGS, ...browserSaved, sounds: mergeSounds(browserSaved) };
  }

  try {
    const saved = await localStorageStore.get(STORAGE_KEY);
    if (saved && typeof saved === 'object') {
      const mergedSettings = { ...DEFAULT_SETTINGS, ...saved, sounds: mergeSounds(saved) };
      await writeBrowserSettings(mergedSettings);
      return mergedSettings;
    }
  } catch {}
  return { ...DEFAULT_SETTINGS };
}

function createMdtStore() {
  let visible = $state(false);
  let loggedIn = $state(false);
  let sessionLoggedIn = $state(false);
  let sidebarCollapsed = $state(false);
  let activePage = $state('dashboard');
  let peeking = $state(false);
  let mode = $state('pd');
  let settingsLoaded = $state(false);
  /** True only after `login()` — drives short authed `in:fade`; cleared post-anim. Session restore skips. */
  let pendingAuthedIntro = $state(false);

  let officer = $state({
    officerId: null,
    firstName: 'John',
    lastName: 'Doe',
    rank: 'Officer',
    callsign: '1-A-12',
    departmentKey: 'police',
    department: 'Los Santos Police Department',
    departmentShort: 'LSPD',
    avatar: null,
  });

  let civilian = $state({
    firstName: '',
    lastName: '',
    citizenId: null,
  });

  /** FiveM `GetPlayerName` — not RP character name */
  let gameUsername = $state('');

  let settings = $state({
    theme: 'default',
    avatarUrl: null,
    callsign: '',
    officerDisplayFirstName: '',
    officerDisplayLastName: '',
    sounds: { ...DEFAULT_SOUNDS },
  });

  /** When opening Settings from another page (e.g. Penal Code → Edit charges). */
  let pendingSettingsTabId = $state(null);
  let settingsDeepLinkSeq = $state(0);

  let showCitation = $state(false);
  let citationData = $state(null);
  let citationsList = $state([]);

  async function persistSettings() {
    if (!settingsLoaded) return;
    const nextSettings = {
      theme: settings.theme,
      avatarUrl: settings.avatarUrl,
      callsign: settings.callsign,
      officerDisplayFirstName: settings.officerDisplayFirstName || '',
      officerDisplayLastName: settings.officerDisplayLastName || '',
      sounds: { ...DEFAULT_SOUNDS, ...settings.sounds },
    };

    const wroteToBrowser = await writeBrowserSettings(nextSettings);
    if (!wroteToBrowser) {
      await localStorageStore.set(STORAGE_KEY, nextSettings);
    }
  }

  return {
    get visible() { return visible; },
    set visible(v) { visible = v; },

    get loggedIn() { return loggedIn; },
    set loggedIn(v) { loggedIn = v; },
    get sessionLoggedIn() { return sessionLoggedIn; },
    get pendingAuthedIntro() { return pendingAuthedIntro; },
    clearAuthedIntro() { pendingAuthedIntro = false; },
    login() {
      loggedIn = true;
      sessionLoggedIn = true;
      pendingAuthedIntro = true;
    },
    logout() {
      loggedIn = false;
      sessionLoggedIn = false;
      activePage = 'dashboard';
      pendingAuthedIntro = false;
    },

    get sidebarCollapsed() { return sidebarCollapsed; },
    set sidebarCollapsed(v) { sidebarCollapsed = v; },
    toggleSidebar() { sidebarCollapsed = !sidebarCollapsed; },

    get activePage() { return activePage; },
    set activePage(v) { activePage = v; },

    get peeking() { return peeking; },
    set peeking(v) { peeking = v; },

    get mode() { return mode; },
    set mode(v) { mode = v; },

    get officer() { return officer; },
    set officer(v) { officer = { ...officer, ...v }; },

    get civilian() { return civilian; },
    set civilian(v) { civilian = { ...civilian, ...v }; },

    get gameUsername() { return gameUsername; },
    set gameUsername(v) { gameUsername = typeof v === 'string' ? v : ''; },

    get settings() { return settings; },
    set settings(v) {
      settings = { ...settings, ...v };
      persistSettings();
    },

    get settingsLoaded() { return settingsLoaded; },

    async initSettings() {
      const loaded = await loadSettings();
      settings = loaded;
      settingsLoaded = true;
      return settings;
    },

    async updateSettings(updates) {
      let next = { ...settings, ...updates };
      if (updates.sounds && typeof updates.sounds === 'object') {
        next.sounds = { ...DEFAULT_SOUNDS, ...(settings.sounds || {}), ...updates.sounds };
      }
      settings = next;
      await persistSettings();
    },

    get settingsDeepLinkSeq() {
      return settingsDeepLinkSeq;
    },

    requestOpenSettingsTab(tabId) {
      pendingSettingsTabId = tabId || null;
      settingsDeepLinkSeq += 1;
    },

    consumePendingSettingsTab() {
      const id = pendingSettingsTabId;
      pendingSettingsTabId = null;
      return id;
    },

    // Citation view overlay (separate from MDT, used by /showcitation and inventory)
    get showCitation() { return showCitation; },
    set showCitation(v) { showCitation = v; },
    get citationData() { return citationData; },
    set citationData(v) { citationData = v; },
    get citationsList() { return citationsList; },
    set citationsList(v) { citationsList = v; },

  };
}

export const mdtStore = createMdtStore();
