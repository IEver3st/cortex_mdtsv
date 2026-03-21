/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{svelte,js,ts}', './index.html'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        'mdt-bg': 'var(--mdt-bg)',
        'mdt-surface': 'var(--mdt-surface)',
        'mdt-surface-2': 'var(--mdt-surface-2)',
        'mdt-surface-3': 'var(--mdt-surface-3)',
        'mdt-border': 'var(--mdt-border)',
        'mdt-border-2': 'var(--mdt-border-2)',
        'mdt-text': 'var(--mdt-text)',
        'mdt-text-dim': 'var(--mdt-text-dim)',
        'mdt-text-muted': 'var(--mdt-text-muted)',
        'mdt-accent': 'var(--mdt-accent)',
        'mdt-accent-dim': 'var(--mdt-accent-dim)',
        'mdt-success': 'var(--mdt-success)',
        'mdt-error': 'var(--mdt-error)',
        'mdt-warning': 'var(--mdt-warning)',
        'mdt-bezel': 'var(--mdt-bezel)',
        'mdt-bezel-edge': 'var(--mdt-bezel-edge)',
        'mdt-bezel-shadow': 'var(--mdt-bezel-shadow)',
        'mdt-sidebar': 'var(--mdt-sidebar)',
        'mdt-toolbar': 'var(--mdt-toolbar)',
      },
      fontFamily: {
        display: ['Outfit', 'sans-serif'],
        body: ['Outfit', 'sans-serif'],
        mono: ['Share Tech Mono', 'Courier New', 'monospace'],
      },
      borderRadius: {
        'mdt': 'var(--mdt-radius)',
        'mdt-sm': 'var(--mdt-radius-sm)',
        'mdt-lg': 'var(--mdt-radius-lg)',
      },
      transitionTimingFunction: {
        'mdt': 'cubic-bezier(0.16, 1, 0.3, 1)',
      },
      animation: {
        'fade-in': 'fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards',
        'slide-in': 'slideIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards',
        'scale-in': 'scaleIn 0.25s cubic-bezier(0.16, 1, 0.3, 1) forwards',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideIn: {
          '0%': { opacity: '0', transform: 'translateX(-8px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' },
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.96)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
      },
    },
  },
  plugins: [],
};
