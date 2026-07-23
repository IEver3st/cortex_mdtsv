<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { getGreeting } from '../lib/utils/helpers.js';
  import {
    Car,
    FileText,
    AlertTriangle,
    Shield,
    Bell,
    ChevronRight,
    Plus,
    Users,
    X,
    Search,
  } from '@lucide/svelte';

  let mounted = $state(false);
  let busyCitizenId = $state(null);
  let generating = $state(false);
  let searchOpen = $state(false);
  let searchQuery = $state('');
  let searchInputEl = $state(null);
  let greeting = $derived(getGreeting());
  let civ = $derived(mdtStore.civilian);
  let sessionState = $derived(dataStore.standaloneCivilianState);
  let personas = $derived(dataStore.standaloneCitizens || []);
  let activePersona = $derived(personas.find((p) => p.isActive) ?? null);
  let displayName = $derived(
    civ.firstName && civ.lastName
      ? `${civ.firstName} ${civ.lastName}`
      : 'Citizen'
  );

  let notices = $state([]);
  let civStats = $derived([
    { key: 'vehicles', label: 'Registered Vehicles', value: civ.vehicleCount || 0, icon: Car, color: '--mdt-accent' },
    { key: 'citations', label: 'Active Citations', value: civ.citationCount || 0, icon: FileText, color: '--mdt-warning' },
    { key: 'warrants', label: 'Active Warrants', value: civ.warrantCount || 0, icon: AlertTriangle, color: '--mdt-error' },
    { key: 'records', label: 'Record Entries', value: civ.recordCount || 0, icon: Shield, color: '--mdt-success' },
  ]);

  function navigate(pageId) {
    mdtStore.activePage = pageId;
  }

  async function toggleSearch() {
    searchOpen = !searchOpen;
    if (searchOpen) {
      await Promise.resolve();
      searchInputEl?.focus();
    } else {
      searchQuery = '';
    }
  }

  function handleSearchKey(e) {
    if (e.key === 'Escape') {
      searchOpen = false;
      searchQuery = '';
    }
  }

  onMount(() => {
    mounted = true;

    if (!isEnvBrowser()) {
      dataStore.fetchStandaloneCivilianState();
    }

    if (isEnvBrowser()) {
      notices = [
        { id: 1, type: 'info', title: 'Vehicle Registration Renewal', content: 'Vehicle registrations generated in standalone mode can be linked to your active civilian once those endpoints are added.', time: Date.now() - 3600000 },
        { id: 2, type: 'warning', title: 'Session Cleanup', content: 'Standalone civilians are session-scoped and are removed when the player disconnects or the resource restarts.', time: Date.now() - 86400000 },
      ];
    }
  });

  async function handleGenerate() {
    generating = true;
    const response = await dataStore.generateStandaloneCivilian();
    generating = false;

    if (response?.ok && response.citizen?.citizenId) {
      await handleActivate(response.citizen.citizenId);
    }
  }

  async function handleActivate(citizenId) {
    busyCitizenId = citizenId;
    await dataStore.claimStandaloneCivilian(citizenId);
    busyCitizenId = null;
  }

  async function handleUnclaim(citizenId) {
    busyCitizenId = citizenId;
    await dataStore.unclaimStandaloneCivilian(citizenId);
    busyCitizenId = null;
  }

  function formatTime(timestamp) {
    if (!timestamp) return '';
    const then = new Date(timestamp);
    const now = new Date();
    const diff = now - then;
    const mins = Math.floor(diff / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  }
</script>

<div class="dashboard" class:mounted>
  <!-- ── Header Row ──────────────────────────────── -->
  <div class="dash-header">
    <div class="header-right">
      <!-- Expandable Search -->
      <div class="search-wrap" class:open={searchOpen}>
        {#if searchOpen}
          <input
            bind:this={searchInputEl}
            class="search-input font-mono"
            type="text"
            placeholder="Search portal..."
            bind:value={searchQuery}
            onkeydown={handleSearchKey}
          />
          <button class="search-close-btn" onclick={toggleSearch} title="Close search">
            <X size={14} />
          </button>
        {:else}
          <button class="search-icon-btn" onclick={toggleSearch} title="Search">
            <Search size={16} />
          </button>
        {/if}
      </div>

      <!-- Live status -->
      <div class="duty-status-chip" style="--status-color: {civ.citizenId ? 'var(--mdt-success)' : 'var(--mdt-text-muted)'}">
        <span class="duty-dot"></span>
        <span class="duty-label font-mono">{civ.citizenId ? 'ACTIVE' : 'NO PROFILE'}</span>
      </div>
    </div>
  </div>

  <!-- ── Welcome Banner ─────────────────────────── -->
  <div class="welcome-bar">
    <div class="welcome-left">
      <span class="welcome-greeting">{greeting},</span>
      <span class="welcome-name">{displayName}</span>
      <div class="welcome-meta font-mono">
        <span class="meta-role">CITIZEN</span>
        <span class="meta-sep"></span>
        <span class="meta-id">{civ.citizenId || 'UNCLAIMED'}</span>
      </div>
    </div>
  </div>

  <!-- ── Stats (single strip) ──────────────────────── -->
  <div class="stats-strip">
    {#each civStats as card (card.key)}
      {@const Icon = card.icon}
      <button
        class="stat-cell"
        style="--card-color: var({card.color})"
        onclick={() => {
          if (card.key === 'vehicles') navigate('civ-vehicles');
          else if (card.key === 'citations' || card.key === 'records') navigate('civ-records');
          else if (card.key === 'warrants') navigate('civ-records');
        }}
      >
        <div class="stat-icon">
          <Icon size="100%" />
        </div>
        <div class="stat-info">
          <span class="stat-value font-mono">{card.value}</span>
          <span class="stat-label">{card.label}</span>
        </div>
        <div class="stat-bar" style="--bar-pct: {Math.min(100, card.value * 20)}%"></div>
      </button>
    {/each}
  </div>

  <!-- ── Main Grid ─────────────────────────────────── -->
  <div class="main-grid">

    <!-- Column 1: Persona Management -->
    <div class="col col-left">
      <div class="panel">
        <div class="panel-header">
          <div class="panel-title-row">
            <Users size={13} class="panel-icon" />
            <h2 class="panel-title">Session Personas</h2>
          </div>
          <button class="btn-rect generate-btn" onclick={handleGenerate} disabled={generating || sessionState.standaloneEnabled === false}>
            <Plus size={14} strokeWidth={2.5} />
            <span>{generating ? 'Generating...' : 'Generate New'}</span>
          </button>
        </div>

        {#if sessionState.standaloneEnabled === false}
          <div class="empty-state">
            <span>{sessionState.error || 'Standalone civilian generation is only available while the MDT framework mode is `standalone`.'}</span>
          </div>
        {:else if personas.length === 0}
          <div class="empty-state">
            <span>No civilians generated for this session yet.</span>
          </div>
        {:else}
          {#if activePersona}
            <div class="active-spotlight">
              <span class="active-spotlight-kicker font-mono">Current session</span>
              <span class="active-spotlight-name">{activePersona.fullName}</span>
              <span class="active-spotlight-id font-mono">{activePersona.citizenId}</span>
            </div>
          {/if}
          <div class="persona-list">
            {#each personas as persona (persona.citizenId)}
              <div
                class="persona-row"
                class:persona-row-active={persona.isActive}
              >
                <div class="persona-main">
                  <div class="persona-top">
                    <div>
                      <h3 class="persona-name">{persona.fullName}</h3>
                      <span class="persona-id font-mono">{persona.citizenId}</span>
                    </div>
                  </div>
                  <div class="persona-meta font-mono">
                    <span>{persona.dateOfBirth}</span>
                    <span class="meta-sep"></span>
                    <span>{persona.occupation}</span>
                    <span class="meta-sep"></span>
                    <span>{persona.phone}</span>
                  </div>
                  <p class="persona-address">{persona.address}</p>
                </div>
                <div class="persona-actions">
                  {#if !persona.isActive}
                    <button class="btn-rect persona-action-primary" onclick={() => handleActivate(persona.citizenId)} disabled={busyCitizenId === persona.citizenId}>
                      {#if busyCitizenId === persona.citizenId}
                        Applying...
                      {:else if persona.isOwner}
                        Switch
                      {:else}
                        Claim
                      {/if}
                    </button>
                  {/if}
                  {#if persona.isOwner}
                    <button class="btn-rect persona-action-unclaim" onclick={() => handleUnclaim(persona.citizenId)} disabled={busyCitizenId === persona.citizenId}>
                      Unclaim
                    </button>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Column 2: notices + quick access (one surface) -->
    <div class="col col-right">
      <div class="panel panel-stack">
        <div class="panel-header">
          <div class="panel-title-row">
            <Bell size={13} class="panel-icon" />
            <h2 class="panel-title">Notices & Alerts</h2>
          </div>
          {#if notices.length > 0}
            <span class="panel-badge font-mono">{notices.length}</span>
          {/if}
        </div>
        <div class="notices-list">
          {#if notices.length === 0}
            <div class="empty-state">
              <span>No notices at this time</span>
            </div>
          {:else}
            {#each notices as notice (notice.id)}
              <div class="notice-item" class:notice-warning={notice.type === 'warning'}>
                <div class="notice-icon-wrap">
                  {#if notice.type === 'warning'}
                    <AlertTriangle size={14} strokeWidth={2} />
                  {:else}
                    <Bell size={14} strokeWidth={2} />
                  {/if}
                </div>
                <div class="notice-content">
                  <div class="notice-top">
                    <h3 class="notice-title">{notice.title}</h3>
                    <span class="notice-time font-mono">{formatTime(notice.time)}</span>
                  </div>
                  <p class="notice-text">{notice.content}</p>
                </div>
              </div>
            {/each}
          {/if}
        </div>

        <div class="panel-divider"></div>

        <div class="panel-header panel-header-sub">
          <div class="panel-title-row">
            <Shield size={13} class="panel-icon" />
            <h2 class="panel-title">Quick Access</h2>
          </div>
        </div>
        <div class="quick-list">
          <button class="quick-item" onclick={() => navigate('civ-identity')}>
            <span class="quick-item-label">View Identity</span>
            <ChevronRight size={14} />
          </button>
          <button class="quick-item" onclick={() => navigate('civ-vehicles')}>
            <span class="quick-item-label">My Vehicles</span>
            <ChevronRight size={14} />
          </button>
          <button class="quick-item" onclick={() => navigate('civ-records')}>
            <span class="quick-item-label">My Records</span>
            <ChevronRight size={14} />
          </button>
          <button class="quick-item" onclick={() => navigate('civ-services')}>
            <span class="quick-item-label">City Services</span>
            <ChevronRight size={14} />
          </button>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .dashboard {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(18px * var(--mdt-scale)) calc(22px * var(--mdt-scale));
    overflow-y: auto;
    opacity: 0;
    animation: fadeIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .dashboard.mounted {
    opacity: 1;
  }

  /* ── Header ─────────────────────────────────────────── */
  .dash-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    flex-shrink: 0;
  }

  /* ── Search ─────────────────────────────────────────── */
  .search-wrap {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .search-icon-btn {
    width: calc(34px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
  }

  .search-icon-btn :global(svg) {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
  }

  .search-icon-btn:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 30%, transparent);
  }

  .search-wrap.open {
    background: var(--mdt-surface-2);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 40%, transparent);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    animation: expandSearch 0.22s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  @keyframes expandSearch {
    from { width: calc(34px * var(--mdt-scale)); opacity: 0.5; }
    to { width: calc(200px * var(--mdt-scale)); opacity: 1; }
  }

  .search-input {
    flex: 1;
    min-width: 0;
    width: calc(160px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: transparent;
    border: none;
    color: var(--mdt-text);
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(11px * var(--mdt-scale));
    outline: none;
    letter-spacing: 0.04em;
  }

  .search-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .search-close-btn {
    position: relative;
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    color: var(--mdt-text-muted);
    cursor: pointer;
    flex-shrink: 0;
    margin-right: calc(3px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    transition: color 0.12s ease;
  }
  .search-close-btn::after {
    content: '';
    position: absolute;
    inset: calc(-6px * var(--mdt-scale));
  }

  .search-close-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .search-close-btn:hover {
    color: var(--mdt-error);
  }

  /* ── Header status chip ─────────────────────────────── */
  .duty-status-chip {
    display: flex;
    align-items: center;
    gap: calc(7px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: color-mix(in srgb, var(--status-color) 8%, transparent);
    border: 1px solid color-mix(in srgb, var(--status-color) 22%, transparent);
    border-radius: var(--mdt-radius-sm);
    transition: background 0.35s ease, border-color 0.35s ease;
  }

  .duty-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--status-color);
    box-shadow: 0 0 calc(6px * var(--mdt-scale)) color-mix(in srgb, var(--status-color) 60%, transparent);
    animation: pulseDuty 2s ease-in-out infinite;
    flex-shrink: 0;
    transition: background 0.35s ease;
  }

  .duty-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--status-color);
    letter-spacing: 0.1em;
    text-transform: uppercase;
    transition: color 0.35s ease;
  }

  /* ── Welcome (flat bar, no extra card frame) ────────── */
  .welcome-bar {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) 0 calc(16px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    animation: cardIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .welcome-left {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .welcome-greeting {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-weight: 400;
    line-height: 1.2;
  }

  .welcome-name {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
    line-height: 1.2;
  }

  .welcome-meta {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    margin-top: calc(4px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  .meta-role {
    color: var(--mdt-accent);
    font-weight: 600;
  }

  .meta-sep {
    width: calc(3px * var(--mdt-scale));
    height: calc(3px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-text-muted);
  }

  .meta-id {
    color: var(--mdt-text-muted);
  }

  /* ── Stats: one strip, internal dividers ─────────────── */
  .stats-strip {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    flex-shrink: 0;
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .stat-cell {
    position: relative;
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: transparent;
    border: none;
    border-right: 1px solid var(--mdt-border);
    cursor: pointer;
    transition: background 0.2s ease, transform 0.15s ease;
    text-align: left;
    font-family: inherit;
    overflow: hidden;
  }

  .stat-cell:last-child {
    border-right: none;
  }

  .stat-cell:hover {
    background: var(--mdt-surface-3);
  }

  .stat-cell:active {
    transform: scale(0.96);
  }

  .stat-bar {
    position: absolute;
    bottom: 0;
    left: 0;
    width: var(--bar-pct);
    height: calc(2px * var(--mdt-scale));
    background: var(--card-color);
    opacity: 0.4;
    transition: width 0.8s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .stat-icon {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: color-mix(in srgb, var(--card-color) 12%, transparent);
    color: var(--card-color);
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .stat-info {
    display: flex;
    flex-direction: column;
    gap: calc(1px * var(--mdt-scale));
    min-width: 0;
  }

  .stat-value {
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }

  .stat-label {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  /* ── Main Grid ──────────────────────────────────────── */
  .main-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(10px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
  }

  .col {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    min-height: 0;
  }

  /* ── Panel ──────────────────────────────────────────── */
  .panel {
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
    background: var(--mdt-surface);
  }

  .panel-title-row {
    display: flex;
    align-items: center;
    gap: calc(7px * var(--mdt-scale));
  }

  .panel-title-row :global(.panel-icon),
  .panel-title-row :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .panel-title {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-dim);
    text-transform: uppercase;
    letter-spacing: 0.07em;
  }

  .panel-badge {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    letter-spacing: 0.05em;
  }

  .panel-stack {
    flex: 1;
    min-height: 0;
  }

  .panel-divider {
    height: 1px;
    background: var(--mdt-border);
    flex-shrink: 0;
  }

  .panel-header-sub {
    border-bottom: none;
    padding-top: calc(8px * var(--mdt-scale));
  }

  /* ── Active persona spotlight ───────────────────────── */
  .active-spotlight {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-success) 35%, var(--mdt-border));
    background: linear-gradient(
      90deg,
      color-mix(in srgb, var(--mdt-success) 14%, transparent) 0%,
      transparent 72%
    );
  }

  .active-spotlight-kicker {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--mdt-success);
  }

  .active-spotlight-name {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
  }

  .active-spotlight-id {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-accent);
    letter-spacing: 0.06em;
  }

  /* ── Persona list ───────────────────────────────────── */
  .persona-list {
    display: flex;
    flex-direction: column;
  }

  .persona-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    border-left: calc(3px * var(--mdt-scale)) solid transparent;
    transition: background 0.12s ease, border-left-color 0.12s ease;
  }

  .persona-row:last-child {
    border-bottom: none;
  }

  .persona-row:hover {
    background: color-mix(in srgb, var(--mdt-surface-3) 85%, transparent);
  }

  .persona-row-active {
    border-left-color: var(--mdt-success);
    background: color-mix(in srgb, var(--mdt-success) 6%, transparent);
  }

  .persona-row-active:hover {
    background: color-mix(in srgb, var(--mdt-success) 9%, transparent);
  }

  .persona-main {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    min-width: 0;
    flex: 1;
  }

  .persona-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
  }

  .persona-name {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .persona-id {
    display: inline-block;
    margin-top: calc(2px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    letter-spacing: 0.08em;
  }

  .persona-meta {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: wrap;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.05em;
  }

  .persona-address {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .btn-rect {
    border-radius: var(--mdt-radius-sm);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.18s ease, opacity 0.18s ease, border-color 0.18s ease, background 0.18s ease, color 0.18s ease;
    white-space: nowrap;
    flex-shrink: 0;
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
  }

  .persona-actions {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .persona-action-primary {
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .persona-action-primary:hover:enabled {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    color: var(--mdt-accent);
  }

  .persona-action-unclaim {
    border: 1px solid color-mix(in srgb, var(--mdt-error) 55%, var(--mdt-border));
    color: var(--mdt-error);
    background: color-mix(in srgb, var(--mdt-error) 18%, var(--mdt-surface-2));
    box-shadow: inset 0 1px 0 color-mix(in srgb, var(--mdt-error) 12%, transparent);
  }

  .persona-action-unclaim:hover:enabled {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: var(--mdt-error);
    background: color-mix(in srgb, var(--mdt-error) 28%, var(--mdt-surface-2));
    color: color-mix(in srgb, var(--mdt-error) 92%, white);
  }

  .btn-rect:disabled {
    opacity: 0.5;
    cursor: wait;
  }

  /* ── Notices ─────────────────────────────────────────── */
  .notices-list {
    display: flex;
    flex-direction: column;
  }

  .notice-item {
    display: flex;
    align-items: flex-start;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    transition: background 0.12s ease;
  }

  .notice-item:last-child {
    border-bottom: none;
  }

  .notice-item:hover {
    background: var(--mdt-surface-3);
  }

  .notice-item.notice-warning {
    border-left: calc(3px * var(--mdt-scale)) solid var(--mdt-warning);
  }

  .notice-item:not(.notice-warning) {
    border-left: calc(3px * var(--mdt-scale)) solid var(--mdt-accent);
  }

  .notice-icon-wrap {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-accent-dim);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--mdt-accent);
  }

  .notice-warning .notice-icon-wrap {
    background: rgba(251, 191, 36, 0.12);
    color: var(--mdt-warning);
  }

  .notice-content {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .notice-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .notice-title {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .notice-time {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
    flex-shrink: 0;
  }

  .notice-text {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.45;
    margin: 0;
  }

  /* ── Quick List ─────────────────────────────────────── */
  .quick-list {
    display: flex;
    flex-direction: column;
  }

  .quick-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: none;
    border-left: none;
    border-right: none;
    border-top: none;
    border-radius: 0;
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    transition: background 0.12s ease;
    color: var(--mdt-text-dim);
  }

  .quick-item:last-child {
    border-bottom: none;
  }

  .quick-item:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-accent);
  }

  .quick-item-label {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
  }

  /* ── Generate (match primary surface buttons) ─────────── */
  .generate-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 600;
    transition: transform 0.18s ease, opacity 0.18s ease, border-color 0.18s ease, color 0.18s ease, background 0.18s ease;
  }

  .generate-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
    opacity: 0.9;
  }

  .generate-btn:hover:enabled {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    color: var(--mdt-accent);
    background: var(--mdt-surface-3);
  }

  .generate-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* ── Empty state ────────────────────────────────────── */
  .empty-state {
    padding: calc(20px * var(--mdt-scale));
    text-align: center;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  /* ── Keyframes ──────────────────────────────────────── */
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes cardIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes pulseDuty {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.45; }
  }
</style>
