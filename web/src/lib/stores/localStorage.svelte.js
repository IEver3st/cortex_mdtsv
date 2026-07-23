import { nuiPost, isEnvBrowser } from '../utils/nui.js';

const STORAGE_KEY_PREFIX = 'cortex_mdt_local_';

function createLocalStorageStore() {
  async function get(key) {
    if (isEnvBrowser()) {
      const value = localStorage.getItem(STORAGE_KEY_PREFIX + key);
      try {
        return value ? JSON.parse(value) : null;
      } catch {
        return value;
      }
    }
    const resp = await nuiPost('cortex_mdt:getLocalStorage', key);
    if (resp?.ok) {
      return resp.value;
    }
    return null;
  }

  async function set(key, value) {
    if (isEnvBrowser()) {
      try {
        localStorage.setItem(STORAGE_KEY_PREFIX + key, JSON.stringify(value));
        return true;
      } catch {
        return false;
      }
    }
    const resp = await nuiPost('cortex_mdt:setLocalStorage', { key, value });
    return resp?.ok === true;
  }

  async function getAll() {
    if (isEnvBrowser()) {
      const data = {};
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key?.startsWith(STORAGE_KEY_PREFIX)) {
          const shortKey = key.slice(STORAGE_KEY_PREFIX.length);
          try {
            data[shortKey] = JSON.parse(localStorage.getItem(key));
          } catch {
            data[shortKey] = localStorage.getItem(key);
          }
        }
      }
      return data;
    }
    const resp = await nuiPost('cortex_mdt:getAllLocalStorage');
    return resp?.data || {};
  }

  async function setMultiple(data) {
    if (!data || typeof data !== 'object') return false;
    if (isEnvBrowser()) {
      try {
        for (const [key, value] of Object.entries(data)) {
          localStorage.setItem(STORAGE_KEY_PREFIX + key, JSON.stringify(value));
        }
        return true;
      } catch {
        return false;
      }
    }
    const resp = await nuiPost('cortex_mdt:setLocalStorageMultiple', data);
    return resp?.ok === true;
  }

  return {
    get,
    set,
    getAll,
    setMultiple,
  };
}

export const localStorageStore = createLocalStorageStore();
