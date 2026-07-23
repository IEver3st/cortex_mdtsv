import { mdtStore } from '../stores/mdt.svelte.js';
import { nuiPost, isEnvBrowser } from './nui.js';

const DEFAULT_PRESET = 'exec_navigate';

/**
 * @param {'biometric' | 'status' | 'dashboard' | 'ui_click' | 'logout'} kind
 * @param {{ force?: boolean }} [options]
 */
export function playMdtSound(kind, options = {}) {
  if (isEnvBrowser()) return;
  const { force = false } = options;
  if (!force && !isSoundEnabled(kind)) return;
  const preset = mdtStore.settings?.sounds?.uiClickPreset || DEFAULT_PRESET;
  nuiPost('cortex_mdt:playSound', { kind, preset });
}

/**
 * Settings previews — always sent to client (ignore per-event toggles; still obeys nothing in browser).
 * @param {'biometric' | 'status' | 'dashboard' | 'ui_click' | 'logout'} kind
 * @param {string} [presetOverride] ui_click preset id
 */
export function previewMdtSound(kind, presetOverride) {
  if (isEnvBrowser()) return;
  const preset = presetOverride ?? mdtStore.settings?.sounds?.uiClickPreset ?? DEFAULT_PRESET;
  nuiPost('cortex_mdt:playSound', { kind, preset });
}

function isSoundEnabled(kind) {
  const s = mdtStore.settings?.sounds;
  if (!s?.master) return false;
  const map = {
    biometric: s.biometric,
    status: s.status,
    dashboard: s.dashboard,
    ui_click: s.uiClick,
    logout: s.logout,
  };
  return map[kind] !== false;
}
