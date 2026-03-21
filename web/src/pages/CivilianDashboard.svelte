<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { getGreeting } from '../lib/utils/helpers.js';
  import { Building2, Shield, FileText, Car, AlertTriangle, Bell, ChevronRight, Sparkles, Users } from 'lucide-svelte';

  let mounted = $state(false);
  let busyCitizenId = $state(null);
  let generating = $state(false);
  let greeting = $derived(getGreeting());
  let civ = $derived(mdtStore.civilian);
  let sessionState = $derived(dataStore.standaloneCivilianState);
  let personas = $derived(dataStore.standaloneCitizens || []);
  let displayName = $derived(
    civ.firstName && civ.lastName
      ? `${civ.firstName} ${civ.lastName}`
      : 'Citizen'
  );

  let notices = $state([]);
  let quickActions = [
    { id: 'civ-identity', label: 'View Identity', icon: Shield, desc: 'Review the active civilian identity card' },
    { id: 'civ-vehicles', label: 'My Vehicles', icon: Car, desc: 'Check vehicle ownership and registration' },
    { id: 'civ-records', label: 'My Records', icon: FileText, desc: 'Review citations, warrants, and history' },
    { id: 'civ-services', label: 'City Services', icon: Building2, desc: 'Access municipal services and forms' },
  ];

  function navigate(pageId) {
    mdtStore.activePage = pageId;
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

<div class="civ-dashboard" class:mounted>
  <div class="welcome-bar">
    <div class="welcome-left">
      <h1 class="welcome-greeting">{greeting},</h1>
      <span class="welcome-name">{displayName}</span>
      <div class="welcome-meta font-mono">
        <span class="meta-role">CITIZEN</span>
        <span class="meta-sep"></span>
        <span class="meta-id">{civ.citizenId || 'UNCLAIMED'}</span>
      </div>
    </div>
    <div class="status-badge" class:status-badge-muted={!civ.citizenId}>
      <span class="status-dot"></span>
      <span class="status-label font-mono">{civ.citizenId ? 'ACTIVE' : 'NO PROFILE'}</span>
    </div>
  </div>

  <div class="quick-grid">
    {#each quickActions as action, index (action.id)}
      {@const Icon = action.icon}
      <button class="quick-card" style={`--stagger: ${index};`} onclick={() => navigate(action.id)}>
        <div class="quick-icon-wrap">
          <Icon size={22} strokeWidth={1.5} />
        </div>
        <div class="quick-text">
          <span class="quick-label">{action.label}</span>
          <span class="quick-desc">{action.desc}</span>
        </div>
        <div class="quick-arrow">
          <ChevronRight size={16} strokeWidth={2} />
        </div>
      </button>
    {/each}
  </div>

  <div class="persona-panel">
    <div class="panel-header">
      <div class="panel-header-copy">
        <Users size={16} strokeWidth={1.5} />
        <h2 class="panel-title">Session Personas</h2>
      </div>
      <button class="generate-btn" onclick={handleGenerate} disabled={generating || sessionState.standaloneEnabled === false}>
        <Sparkles size={14} strokeWidth={1.8} />
        <span>{generating ? 'Generating...' : 'Generate New Citizen'}</span>
      </button>
    </div>

    {#if sessionState.standaloneEnabled === false}
      <div class="empty-state persona-empty">
        <span class="empty-text">Standalone civilian generation is only available while the MDT framework mode is `standalone`.</span>
      </div>
    {:else if personas.length === 0}
      <div class="empty-state persona-empty">
        <span class="empty-text">No civilians generated for this session yet.</span>
      </div>
    {:else}
      <div class="persona-list">
        {#each personas as persona (persona.citizenId)}
          <div class="persona-card">
            <div class="persona-main">
              <div class="persona-top">
                <div>
                  <h3 class="persona-name">{persona.fullName}</h3>
                  <span class="persona-id font-mono">{persona.citizenId}</span>
                </div>
                <span class="persona-badge font-mono" class:persona-badge-active={persona.isActive}>
                  {persona.isActive ? 'ACTIVE' : persona.claimed ? 'CLAIMED' : 'UNCLAIMED'}
                </span>
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
            <button class="persona-action" onclick={() => handleActivate(persona.citizenId)} disabled={busyCitizenId === persona.citizenId}>
              {#if busyCitizenId === persona.citizenId}
                Applying...
              {:else if persona.isActive}
                Active
              {:else if persona.isOwner}
                Switch
              {:else}
                Claim
              {/if}
            </button>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <div class="notices-panel">
    <div class="panel-header">
      <div class="panel-header-copy">
        <Bell size={16} strokeWidth={1.5} />
        <h2 class="panel-title">Notices & Alerts</h2>
      </div>
      {#if notices.length > 0}
        <span class="panel-badge font-mono">{notices.length}</span>
      {/if}
    </div>
    <div class="notices-list">
      {#if notices.length === 0}
        <div class="empty-state">
          <span class="empty-text">No notices at this time</span>
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
  </div>
</div>

<style>
  .civ-dashboard {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(18px * var(--mdt-scale));
    opacity: 0;
    transform: translateY(calc(8px * var(--mdt-scale)));
  }

  .civ-dashboard.mounted {
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .welcome-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(20px * var(--mdt-scale)) calc(22px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--civ-border, var(--mdt-border));
    border-radius: var(--mdt-radius-lg);
  }

  .welcome-left {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .welcome-greeting {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 400;
    color: var(--mdt-text-dim);
    line-height: 1.2;
  }

  .welcome-name {
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--civ-cream, var(--mdt-text));
    letter-spacing: -0.02em;
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
    color: var(--civ-gold, var(--mdt-accent));
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

  .status-badge {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: rgba(52, 211, 153, 0.1);
    border: 1px solid rgba(52, 211, 153, 0.2);
    border-radius: calc(20px * var(--mdt-scale));
  }

  .status-badge-muted {
    background: rgba(148, 163, 184, 0.08);
    border-color: rgba(148, 163, 184, 0.18);
  }

  .status-dot {
    width: calc(7px * var(--mdt-scale));
    height: calc(7px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-success);
    box-shadow: 0 0 calc(6px * var(--mdt-scale)) rgba(52, 211, 153, 0.5);
    animation: pulse 2s ease-in-out infinite;
  }

  .status-badge-muted .status-dot {
    background: var(--mdt-text-muted);
    box-shadow: none;
  }

  .status-label {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-success);
    letter-spacing: 0.1em;
    font-weight: 600;
  }

  .status-badge-muted .status-label {
    color: var(--mdt-text-muted);
  }

  .quick-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: calc(10px * var(--mdt-scale));
  }

  .quick-card {
    display: flex;
    align-items: center;
    gap: calc(14px * var(--mdt-scale));
    padding: calc(16px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--civ-border, var(--mdt-border));
    border-radius: var(--mdt-radius);
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    width: 100%;
    transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    animation: cardIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--stagger) * 60ms);
    opacity: 0;
    transform: translateY(calc(6px * var(--mdt-scale)));
  }

  .quick-card:hover {
    background: var(--mdt-surface-2);
    border-color: var(--civ-gold, var(--mdt-accent));
    box-shadow: 0 0 16px rgba(201, 168, 76, 0.08);
    transform: translateY(calc(-2px * var(--mdt-scale)));
  }

  .quick-card:active {
    transform: scale(0.98);
  }

  .quick-icon-wrap {
    width: calc(44px * var(--mdt-scale));
    height: calc(44px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--civ-gold, var(--mdt-accent));
  }

  .quick-text {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .quick-label {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .quick-desc {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .quick-arrow {
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    transition: transform 0.2s ease, color 0.2s ease;
  }

  .quick-card:hover .quick-arrow {
    color: var(--civ-gold, var(--mdt-accent));
    transform: translateX(calc(3px * var(--mdt-scale)));
  }

  .persona-panel,
  .notices-panel {
    background: var(--mdt-surface);
    border: 1px solid var(--civ-border, var(--mdt-border));
    border-radius: var(--mdt-radius);
    padding: calc(16px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
    color: var(--civ-gold, var(--mdt-accent));
  }

  .panel-header-copy {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .panel-title {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.01em;
  }

  .panel-badge {
    margin-left: auto;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--civ-gold, var(--mdt-accent));
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    letter-spacing: 0.05em;
  }

  .generate-btn,
  .persona-action {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(6px * var(--mdt-scale));
    border-radius: calc(999px * var(--mdt-scale));
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.18s ease, opacity 0.18s ease, border-color 0.18s ease;
  }

  .generate-btn {
    border: 1px solid color-mix(in srgb, var(--civ-gold, var(--mdt-accent)) 22%, transparent);
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    color: var(--civ-gold, var(--mdt-accent));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
  }

  .persona-action {
    border: 1px solid var(--civ-border, var(--mdt-border));
    background: transparent;
    color: var(--mdt-text);
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
  }

  .generate-btn:hover:enabled,
  .persona-action:hover:enabled {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: var(--civ-gold, var(--mdt-accent));
  }

  .generate-btn:disabled,
  .persona-action:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .persona-list,
  .notices-list {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .persona-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    border: 1px solid color-mix(in srgb, var(--civ-border, var(--mdt-border)) 70%, transparent);
  }

  .persona-main {
    display: flex;
    flex-direction: column;
    gap: calc(5px * var(--mdt-scale));
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
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .persona-id {
    display: inline-block;
    margin-top: calc(2px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--civ-gold, var(--mdt-accent));
    letter-spacing: 0.08em;
  }

  .persona-badge {
    padding: calc(4px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(999px * var(--mdt-scale));
    background: rgba(201, 168, 76, 0.12);
    color: var(--civ-gold, var(--mdt-accent));
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.1em;
    flex-shrink: 0;
  }

  .persona-badge-active {
    background: rgba(52, 211, 153, 0.12);
    color: var(--mdt-success);
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

  .notice-item {
    display: flex;
    align-items: flex-start;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-radius: var(--mdt-radius-sm);
    border-left: calc(3px * var(--mdt-scale)) solid var(--civ-gold, var(--mdt-accent));
  }

  .notice-item.notice-warning {
    border-left-color: var(--mdt-warning);
  }

  .notice-icon-wrap {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--civ-gold, var(--mdt-accent));
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
    font-size: calc(13px * var(--mdt-scale));
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
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.45;
    margin: 0;
  }

  .empty-state {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .persona-empty {
    justify-content: flex-start;
  }

  .empty-text {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(8px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes cardIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }
</style>
