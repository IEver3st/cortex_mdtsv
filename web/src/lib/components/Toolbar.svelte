<script>
  import { fade } from 'svelte/transition';
  import { User, CheckCircle, Clock, Navigation, MapPin, Siren, Circle, ChevronDown } from '@lucide/svelte';
  import { mdtStore } from '../stores/mdt.svelte.js';
  import { dataStore } from '../stores/data.svelte.js';
  import { getDepartmentBrand } from '../utils/branding.js';
  import { findUnitForOfficer, getGreeting, getInitialLastName } from '../utils/helpers.js';

  const DEPT_COLORS = {
    police:  '#60a5fa',
    lspd:    '#60a5fa',
    sheriff: '#fbbf24',
    bcso:    '#fbbf24',
    highway: '#a78bfa',
    sahp:    '#a78bfa',
    ems:     '#f87171',
    fire:    '#fb923c',
    tow:     '#34d399',
  };

  const STATUS_COLORS = {
    available: '#34d399',
    busy:      '#fbbf24',
    en_route:  '#60a5fa',
    on_scene:  '#a78bfa',
    emergency: '#f87171',
    off_duty:  '#6b7280',
  };

  const STATUS_LABELS = {
    available: 'Available',
    busy:      'Busy',
    en_route:  'En Route',
    on_scene:  'On Scene',
    emergency: 'Emergency',
    off_duty:  'Off Duty',
  };

  const STATUS_ICONS = {
    available: CheckCircle,
    busy:      Clock,
    en_route:  Navigation,
    on_scene:  MapPin,
    emergency: Siren,
    off_duty:  Circle,
  };

  const SELECTABLE_STATUSES = ['available', 'busy', 'en_route', 'on_scene', 'emergency'];

  /** Newline-separated in Settings; toolbar shows one line, random rotate when multiple. */
  const MOTD_CYCLE_MS = 45_000;

  /** Strip wrapping quotes so CSS decorative marks are not duplicated. */
  function stripOuterQuotes(text) {
    const t = String(text ?? '').trim();
    const pairs = [
      ['"', '"'],
      ["'", "'"],
      ['\u201C', '\u201D'],
      ['\u2018', '\u2019'],
    ];
    for (const [open, close] of pairs) {
      if (t.startsWith(open) && t.endsWith(close) && t.length > open.length + close.length) {
        return t.slice(open.length, -close.length).trim();
      }
    }
    return t;
  }

  const RING_SIZE       = 40;
  const RING_STROKE     = 2.5;
  const RING_RADIUS     = (RING_SIZE / 2) - RING_STROKE;
  const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;

  let greeting      = $derived(getGreeting());
  let displayName   = $derived(getInitialLastName(mdtStore.officer.firstName, mdtStore.officer.lastName));
  let rank          = $derived(mdtStore.officer.rank);
  let departmentKey = $derived(mdtStore.officer.departmentKey);
  let department    = $derived(mdtStore.officer.department);
  let departmentShort = $derived(mdtStore.officer.departmentShort);
  let avatar        = $derived(mdtStore.officer.avatar || mdtStore.settings.avatarUrl);
  let brand         = $derived(getDepartmentBrand({ departmentKey, department, departmentShort }));
  let deptColor     = $derived(
    DEPT_COLORS[(departmentKey || '').toLowerCase()] ||
    DEPT_COLORS[(departmentShort || '').toLowerCase()] ||
    'var(--mdt-accent)'
  );

  let units         = $derived(dataStore.unitsList || []);
  let officer       = $derived(mdtStore.officer);
  let myUnit        = $derived(findUnitForOfficer(units, officer));
  let currentStatus = $derived(myUnit?.status || 'off_duty');
  let isOnDuty      = $derived(currentStatus !== 'off_duty');
  let statusColor   = $derived(STATUS_COLORS[currentStatus] || STATUS_COLORS.off_duty);
  let statusLabel   = $derived(STATUS_LABELS[currentStatus] || 'Off Duty');

  let ringDashoffset = $derived(
    currentStatus === 'off_duty' ? RING_CIRCUMFERENCE * 0.72 : 0
  );

  let motdDisplay = $state('');

  $effect(() => {
    const raw = dataStore.dashboardMotd ?? '';
    const lines = raw
      .split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean);

    if (lines.length === 0) {
      motdDisplay = '';
      return;
    }

    let idx = Math.floor(Math.random() * lines.length);
    motdDisplay = stripOuterQuotes(lines[idx]);

    if (lines.length < 2) return;

    const id = setInterval(() => {
      let next = Math.floor(Math.random() * lines.length);
      if (next === idx) next = (next + 1) % lines.length;
      idx = next;
      motdDisplay = stripOuterQuotes(lines[idx]);
    }, MOTD_CYCLE_MS);

    return () => clearInterval(id);
  });

  let dropdownOpen    = $state(false);
  let autoMode        = $state(false);
  let togglingStatus  = $state(false);
  let dropdownEl      = $state(null);

  async function handleDutyAction(shouldGoOnDuty) {
    if (togglingStatus) return;
    togglingStatus = true;
    try {
      const resp = shouldGoOnDuty
        ? await dataStore.goOnDuty()
        : await dataStore.goOffDuty();

      if (resp?.ok) {
        dropdownOpen = false;
      }
    } finally {
      togglingStatus = false;
    }
  }

  async function handleStatusSelect(status) {
    if (togglingStatus || !isOnDuty || currentStatus === status) return;
    togglingStatus = true;
    dropdownOpen = false;
    try {
      const resp = await dataStore.updateUnitStatus(status, myUnit?.assignment || '');
      if (resp?.ok) {
        dropdownOpen = false;
      }
    } finally {
      togglingStatus = false;
    }
  }

  function toggleDropdown() {
    dropdownOpen = !dropdownOpen;
  }

  function handleOutsideClick(e) {
    if (dropdownEl && !dropdownEl.contains(e.target)) {
      dropdownOpen = false;
    }
  }

  $effect(() => {
    if (dropdownOpen) {
      document.addEventListener('mousedown', handleOutsideClick);
      return () => document.removeEventListener('mousedown', handleOutsideClick);
    }
  });
</script>

<header class="toolbar">
  <div class="toolbar-left">
    <div class="brand-lockup" aria-hidden="true">
      <img
        class="brand-image"
        class:brand-image-logo={brand.variant === 'logo'}
        class:brand-image-seal={brand.variant === 'seal'}
        src={brand.src}
        alt=""
      />
    </div>

    <div class="dept-info">
      <span class="dept-name">{department}</span>
      <span class="dept-short font-mono">{departmentShort} - CORTEX MDT</span>
    </div>
  </div>

  <div class="toolbar-motd" role="region" aria-label="Message of the day">
    {#if motdDisplay}
      {#key motdDisplay}
        <blockquote
          class="toolbar-quote"
          in:fade={{ duration: 320 }}
          out:fade={{ duration: 180 }}
        >
          <p class="toolbar-quote-text">
            <span class="toolbar-quote-mark toolbar-quote-mark-open" aria-hidden="true">&ldquo;</span>
            <span class="toolbar-quote-body">{motdDisplay}</span>
            <span class="toolbar-quote-mark toolbar-quote-mark-close" aria-hidden="true">&rdquo;</span>
          </p>
        </blockquote>
      {/key}
    {:else}
      <p class="toolbar-motd-empty">No line set — configure in Settings.</p>
    {/if}
  </div>

  <div class="toolbar-right">
    <div class="officer-info">
      <span class="officer-greeting">{greeting},</span>
      <span class="officer-name" style="color: {deptColor}">{rank} {displayName}</span>
    </div>

    <!-- Status Ring Avatar -->
    <div class="avatar-wrap" bind:this={dropdownEl}>
      <button
        class="avatar-ring-btn"
        class:dropdown-open={dropdownOpen}
        class:is-emergency={currentStatus === 'emergency'}
        onclick={toggleDropdown}
        title="Duty status: {statusLabel}"
        aria-label="Duty status: {statusLabel}. Click to change."
        style="--status-color: {statusColor}"
      >
        <svg
          class="status-ring"
          width={RING_SIZE}
          height={RING_SIZE}
          viewBox="0 0 {RING_SIZE} {RING_SIZE}"
          aria-hidden="true"
        >
          <circle
            class="ring-track"
            cx={RING_SIZE / 2}
            cy={RING_SIZE / 2}
            r={RING_RADIUS}
            fill="none"
            stroke-width={RING_STROKE}
          />
          <circle
            class="ring-arc"
            cx={RING_SIZE / 2}
            cy={RING_SIZE / 2}
            r={RING_RADIUS}
            fill="none"
            stroke-width={RING_STROKE}
            stroke-dasharray={RING_CIRCUMFERENCE}
            stroke-dashoffset={ringDashoffset}
            stroke={statusColor}
            transform="rotate(-90 {RING_SIZE / 2} {RING_SIZE / 2})"
          />
        </svg>

        <div class="avatar-inner">
          {#if avatar}
            <img class="avatar-img" src={avatar} alt="Avatar" />
          {:else}
            <div class="avatar-placeholder">
              <User size="100%" />
            </div>
          {/if}
        </div>

        <div class="ring-chevron">
          <ChevronDown size="100%" />
        </div>
      </button>

      {#if dropdownOpen}
        <div class="status-dropdown" role="menu" aria-label="Duty status selector">
          <div class="dropdown-header">
            <span class="dropdown-title font-mono">DUTY STATUS</span>
            <div class="auto-toggle" title="Automatically manage status based on active calls">
              <span class="auto-label">Auto</span>
              <button
                class="auto-btn"
                class:active={autoMode}
                onclick={() => autoMode = !autoMode}
                role="switch"
                aria-checked={autoMode}
                aria-label="Auto status mode"
              >
                <span class="auto-thumb"></span>
              </button>
            </div>
          </div>

          <div class="dropdown-divider"></div>

          <div class="duty-actions">
            {#if isOnDuty}
              <button
                class="duty-action duty-action-off"
                onclick={() => handleDutyAction(false)}
                disabled={togglingStatus}
                role="menuitem"
              >
                <span class="duty-action-dot"></span>
                Go Off Duty
              </button>
            {:else}
              <button
                class="duty-action duty-action-on"
                onclick={() => handleDutyAction(true)}
                disabled={togglingStatus}
                role="menuitem"
              >
                <span class="duty-action-dot"></span>
                Go On Duty
              </button>
            {/if}
          </div>

          <div class="dropdown-divider"></div>

          <div class="status-list">
            {#each SELECTABLE_STATUSES as status (status)}
              {@const Icon = STATUS_ICONS[status]}
              {@const color = STATUS_COLORS[status]}
              {@const label = STATUS_LABELS[status]}
              {@const isActive = currentStatus === status}
              <button
                class="status-option"
                class:active={isActive}
                style="--opt-color: {color}"
                onclick={() => handleStatusSelect(status)}
                disabled={togglingStatus || autoMode}
                role="menuitemradio"
                aria-checked={isActive}
              >
                <div class="opt-icon-wrap">
                  <Icon size="100%" />
                </div>
                <span class="opt-label">{label}</span>
                {#if isActive}
                  <span class="opt-active-dot"></span>
                {/if}
              </button>
            {/each}
          </div>

          {#if autoMode}
            <div class="auto-hint font-mono">
              Status updates automatically based on active calls
            </div>
          {/if}
        </div>
      {/if}
    </div>
  </div>
</header>

<style>
  .toolbar {
    height: var(--mdt-toolbar-height);
    min-height: var(--mdt-toolbar-height);
    background: var(--mdt-toolbar);
    border-bottom: 1px solid transparent;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 calc(16px * var(--mdt-scale));
    gap: calc(12px * var(--mdt-scale));
    z-index: 10;
    transition: padding 0.35s cubic-bezier(0.16, 1, 0.3, 1);
    position: relative;
  }

  .toolbar-left {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    min-width: 0;
    position: relative;
    z-index: 2;
  }

  /* Centered in header (between brand + officer), not left column */
  .toolbar-motd {
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    max-width: min(42%, calc(380px * var(--mdt-scale)));
    width: max-content;
    text-align: center;
    pointer-events: none;
    z-index: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0;
    padding: 0 calc(8px * var(--mdt-scale));
    box-sizing: border-box;
  }

  .toolbar-quote {
    margin: 0;
    padding: 0;
    border: none;
    max-width: 100%;
    quotes: none;
  }

  .toolbar-quote-text {
    margin: 0;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    gap: calc(3px * var(--mdt-scale));
    max-width: 100%;
    line-height: 1.35;
  }

  .toolbar-quote-mark {
    flex-shrink: 0;
    font-family: 'Cormorant Garamond', Georgia, 'Times New Roman', serif;
    font-size: calc(17px * var(--mdt-scale));
    font-weight: 500;
    line-height: 1;
    color: color-mix(in srgb, var(--mdt-accent) 55%, var(--mdt-text-muted));
    opacity: 0.9;
    user-select: none;
    margin-top: calc(-1px * var(--mdt-scale));
  }

  .toolbar-quote-mark-close {
    align-self: flex-end;
    margin-top: 0;
    margin-bottom: calc(-2px * var(--mdt-scale));
  }

  .toolbar-quote-body {
    font-family: 'Cormorant Garamond', Georgia, 'Times New Roman', serif;
    font-size: calc(12.5px * var(--mdt-scale));
    font-weight: 400;
    font-style: italic;
    letter-spacing: 0.015em;
    color: color-mix(in srgb, var(--mdt-text) 88%, var(--mdt-accent) 12%);
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    text-wrap: balance;
  }

  .toolbar-motd-empty {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    font-style: italic;
    font-weight: 400;
    line-height: 1.25;
    color: var(--mdt-text-muted);
    max-width: 100%;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .brand-lockup {
    display: flex;
    align-items: center;
    flex-shrink: 0;
  }

  .brand-image {
    display: block;
    object-fit: contain;
    flex-shrink: 0;
  }

  .brand-image-logo {
    width: calc(44px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
  }

  .brand-image-seal {
    width: calc(34px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
  }

  .dept-info {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .dept-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    line-height: 1.2;
    letter-spacing: 0.01em;
  }

  .dept-short {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.08em;
    text-transform: uppercase;
    line-height: 1.3;
  }

  .toolbar-right {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    flex-shrink: 0;
    position: relative;
    z-index: 2;
  }

  .officer-info {
    display: flex;
    align-items: baseline;
    gap: calc(5px * var(--mdt-scale));
    text-align: right;
  }

  .officer-greeting {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-weight: 400;
  }

  .officer-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    white-space: nowrap;
  }

  /* ── Avatar Wrap ──────────────────────────────────── */
  .avatar-wrap {
    position: relative;
    flex-shrink: 0;
  }

  /* ── Avatar Ring Button ────────────────────────────── */
  .avatar-ring-btn {
    position: relative;
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    border-radius: 50%;
    border: none;
    background: none;
    cursor: pointer;
    padding: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.18s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .avatar-ring-btn:hover {
    transform: scale(1.06);
  }

  .avatar-ring-btn:active {
    transform: scale(0.96);
  }

  .avatar-ring-btn.dropdown-open {
    transform: scale(1.04);
  }

  .avatar-ring-btn.is-emergency {
    animation: emergRingPulse 1.1s ease-in-out infinite;
  }

  @keyframes emergRingPulse {
    0%, 100% { filter: drop-shadow(0 0 calc(4px * var(--mdt-scale)) rgba(248, 113, 113, 0.7)); }
    50%       { filter: drop-shadow(0 0 calc(10px * var(--mdt-scale)) rgba(248, 113, 113, 0.25)); }
  }

  /* ── SVG Ring ─────────────────────────────────────── */
  .status-ring {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
  }

  .ring-track {
    stroke: var(--mdt-border-2);
    opacity: 0.45;
  }

  .ring-arc {
    transition: stroke 0.4s cubic-bezier(0.16, 1, 0.3, 1),
                stroke-dashoffset 0.55s cubic-bezier(0.16, 1, 0.3, 1);
    stroke-linecap: round;
  }

  /* ── Avatar Inner ─────────────────────────────────── */
  .avatar-inner {
    position: relative;
    width: calc(29px * var(--mdt-scale));
    height: calc(29px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-2);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1px solid color-mix(in srgb, var(--status-color) 25%, var(--mdt-border));
    transition: border-color 0.35s ease;
    z-index: 1;
    pointer-events: none;
  }

  .avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 50%;
  }

  .avatar-placeholder {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  /* ── Chevron badge ────────────────────────────────── */
  .ring-chevron {
    position: absolute;
    bottom: calc(-1px * var(--mdt-scale));
    right: calc(-1px * var(--mdt-scale));
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border-2);
    border-radius: 50%;
    color: var(--mdt-text-muted);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2;
    pointer-events: none;
    transition: color 0.2s ease, background 0.2s ease, border-color 0.2s ease;
    padding: calc(2px * var(--mdt-scale));
  }

  .avatar-ring-btn:hover .ring-chevron,
  .avatar-ring-btn.dropdown-open .ring-chevron {
    color: var(--status-color);
    background: color-mix(in srgb, var(--status-color) 14%, var(--mdt-surface-3));
    border-color: color-mix(in srgb, var(--status-color) 32%, transparent);
  }

  /* ── Dropdown ─────────────────────────────────────── */
  .status-dropdown {
    position: absolute;
    top: calc(100% + calc(8px * var(--mdt-scale)));
    right: 0;
    width: calc(196px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border-2);
    border-radius: var(--mdt-radius-lg);
    box-shadow:
      0 calc(8px * var(--mdt-scale)) calc(32px * var(--mdt-scale)) rgba(0, 0, 0, 0.55),
      0 calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) rgba(0, 0, 0, 0.3),
      inset 0 1px 0 rgba(255, 255, 255, 0.04);
    z-index: 9999;
    overflow: hidden;
    animation: dropdownIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) both;
    transform-origin: top right;
  }

  @keyframes dropdownIn {
    from { opacity: 0; transform: scale(0.92) translateY(calc(-6px * var(--mdt-scale))); }
    to   { opacity: 1; transform: scale(1) translateY(0); }
  }

  .dropdown-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
  }

  .dropdown-title {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-muted);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  /* ── Auto toggle ──────────────────────────────────── */
  .auto-toggle {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .auto-label {
    font-size: calc(9.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-weight: 500;
    letter-spacing: 0.02em;
  }

  .auto-btn {
    position: relative;
    width: calc(28px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border-2);
    cursor: pointer;
    padding: 0;
    flex-shrink: 0;
    transition: background 0.2s ease, border-color 0.2s ease;
  }
  .auto-btn::after {
    content: '';
    position: absolute;
    inset: calc(-12px * var(--mdt-scale)) calc(-6px * var(--mdt-scale));
  }

  .auto-btn.active {
    background: color-mix(in srgb, var(--mdt-accent) 22%, var(--mdt-surface-3));
    border-color: color-mix(in srgb, var(--mdt-accent) 40%, transparent);
  }

  .auto-thumb {
    position: absolute;
    top: calc(2px * var(--mdt-scale));
    left: calc(2px * var(--mdt-scale));
    width: calc(9px * var(--mdt-scale));
    height: calc(9px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-text-muted);
    transition: transform 0.22s cubic-bezier(0.16, 1, 0.3, 1), background 0.2s ease;
    display: block;
  }

  .auto-btn.active .auto-thumb {
    transform: translateX(calc(13px * var(--mdt-scale)));
    background: var(--mdt-accent);
  }

  .dropdown-divider {
    height: 1px;
    background: var(--mdt-border);
    margin: 0 calc(8px * var(--mdt-scale));
  }

  .duty-actions {
    padding: calc(8px * var(--mdt-scale));
  }

  .duty-action {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid transparent;
    background: none;
    color: var(--mdt-text);
    cursor: pointer;
    font: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.02em;
    transition: background 0.13s ease, border-color 0.13s ease, transform 0.1s ease, color 0.13s ease;
  }

  .duty-action:hover:not(:disabled) {
    transform: translateY(calc(-1px * var(--mdt-scale)));
  }

  .duty-action:active:not(:disabled) {
    transform: scale(0.96);
  }

  .duty-action:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .duty-action-on {
    background: color-mix(in srgb, #34d399 11%, var(--mdt-surface-2));
    border-color: color-mix(in srgb, #34d399 24%, transparent);
    color: #34d399;
  }

  .duty-action-off {
    background: color-mix(in srgb, #6b7280 16%, var(--mdt-surface-2));
    border-color: color-mix(in srgb, #6b7280 26%, transparent);
    color: #d1d5db;
  }

  .duty-action-dot {
    width: calc(7px * var(--mdt-scale));
    height: calc(7px * var(--mdt-scale));
    border-radius: 999px;
    background: currentColor;
    box-shadow: 0 0 calc(8px * var(--mdt-scale)) currentColor;
    flex-shrink: 0;
  }

  /* ── Status list ──────────────────────────────────── */
  .status-list {
    padding: calc(5px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(1px * var(--mdt-scale));
  }

  .status-option {
    display: flex;
    align-items: center;
    gap: calc(9px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(9px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid transparent;
    background: none;
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    transition: background 0.13s ease, border-color 0.13s ease, transform 0.1s ease;
    position: relative;
    width: 100%;
  }

  .status-option:hover:not(:disabled) {
    background: color-mix(in srgb, var(--opt-color) 9%, var(--mdt-surface-2));
    border-color: color-mix(in srgb, var(--opt-color) 18%, transparent);
  }

  .status-option:active:not(:disabled) {
    transform: scale(0.96);
  }

  .status-option.active {
    background: color-mix(in srgb, var(--opt-color) 12%, var(--mdt-surface-2));
    border-color: color-mix(in srgb, var(--opt-color) 25%, transparent);
  }

  .status-option:disabled {
    opacity: 0.38;
    cursor: not-allowed;
  }

  .opt-icon-wrap {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--opt-color);
    flex-shrink: 0;
    opacity: 0.85;
  }

  .opt-icon-wrap :global(svg) {
    width: 100%;
    height: 100%;
  }

  .opt-label {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    flex: 1;
    letter-spacing: 0.01em;
  }

  .status-option.active .opt-label {
    color: var(--opt-color);
    font-weight: 600;
  }

  .opt-active-dot {
    width: calc(5px * var(--mdt-scale));
    height: calc(5px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--opt-color);
    box-shadow: 0 0 calc(5px * var(--mdt-scale)) var(--opt-color);
    flex-shrink: 0;
    animation: optDotPulse 2s ease-in-out infinite;
  }

  @keyframes optDotPulse {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.4; }
  }

  /* ── Auto hint ────────────────────────────────────── */
  .auto-hint {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-align: center;
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    letter-spacing: 0.04em;
    line-height: 1.4;
    border-top: 1px solid var(--mdt-border);
    margin-top: calc(2px * var(--mdt-scale));
  }

</style>
