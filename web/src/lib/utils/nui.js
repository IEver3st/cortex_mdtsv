const resourceName =
  typeof window !== 'undefined' && window.GetParentResourceName
    ? window.GetParentResourceName()
    : 'cortex_mdtsv';

export function isEnvBrowser() {
  return !window.invokeNative;
}

export async function nuiPost(endpoint, data = {}) {
  if (isEnvBrowser()) {
    return null;
  }

  try {
    const resp = await fetch(`https://${resourceName}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return await resp.json();
  } catch {
    return null;
  }
}

export function onNuiMessage(action, handler) {
  function listener(event) {
    if (event.data?.action === action) {
      handler(event.data.data);
    }
  }
  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}

export function onNuiMessages(handlers) {
  function listener(event) {
    const fn = handlers[event.data?.action];
    if (fn) fn(event.data.data);
  }
  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}

export function mockNuiMessage(action, data) {
  window.dispatchEvent(
    new MessageEvent('message', {
      data: { action, data },
    }),
  );
}

export function setUiScale() {
  const h = window.innerHeight || 1080;
  const scale = Math.max(1, h / 1080);
  document.documentElement.style.setProperty('--mdt-scale', String(scale));
}
