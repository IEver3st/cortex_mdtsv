const THEMES = [
  { id: 'default', label: 'Steel Blue', accent: '#60a5fa' },
  { id: 'emerald', label: 'Emerald', accent: '#34d399' },
  { id: 'amber', label: 'Amber', accent: '#fbbf24' },
  { id: 'rose', label: 'Rose', accent: '#fb7185' },
  { id: 'violet', label: 'Violet', accent: '#a78bfa' },
  { id: 'cyan', label: 'Cyan', accent: '#22d3ee' },
  { id: 'cortex', label: 'Cortex', accent: '#e8d5b5' },
];

function createThemeStore() {
  let current = $state('default');

  function apply(themeId) {
    current = themeId;
    if (themeId === 'default') {
      document.documentElement.removeAttribute('data-theme');
    } else {
      document.documentElement.setAttribute('data-theme', themeId);
    }
  }

  return {
    get current() { return current; },
    get themes() { return THEMES; },
    apply,
  };
}

export const themeStore = createThemeStore();
