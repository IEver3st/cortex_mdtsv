<script>
  import { onMount, tick } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { tabsStore } from '../lib/stores/tabs.svelte.js';
  import { dashboardLayout } from '../lib/stores/dashboardLayout.svelte.js';
  import DashboardCustomizer from '../lib/components/DashboardCustomizer.svelte';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { getGreeting } from '../lib/utils/helpers.js';
  import {
    Radio,
    FileText,
    AlertTriangle,
    Shield,
    Bell,
    ChevronRight,
    Search,
    Megaphone,
    Send,
    Users,
    X,
    BadgeCheck,
    Siren,
    Clock,
    MessageSquare,
    SlidersHorizontal,
  } from 'lucide-svelte';

  let layout = dashboardLayout;

  let mounted = $state(false);
  let searchQuery = $state('');
  let searchOpen = $state(false);
  let searchInputEl = $state(null);
  let chatInputVal = $state('');
  let chatListEl = $state(null);
  let sendingChat = $state(false);

  let greeting = $derived(getGreeting());
  let officer = $derived(mdtStore.officer);
  let stats = $derived(dataStore.dashboardStats);
  let motd = $derived(dataStore.dashboardMotd);
  let bolos = $derived(dataStore.dashboardBolos || []);
  let announcements = $derived(dataStore.dashboardAnnouncements || []);
  let dispatchCalls = $derived(dataStore.dashboardDispatchCalls || []);
  let recentReports = $derived(dataStore.dashboardRecentReports || []);
  let onDutyOfficers = $derived(dataStore.dashboardOnDutyOfficers || []);
  let chatMessages = $derived(dataStore.dashboardChatMessages || []);

  let displayName = $derived(
    officer.firstName && officer.lastName
      ? `${officer.firstName} ${officer.lastName}`
      : officer.name || 'Officer'
  );

  let rankLabel = $derived(officer.rank || 'Officer');
  let callsign = $derived(officer.callsign || '—');
  let deptShort = $derived(officer.departmentShort || 'DEPT');

  let statCards = $derived([
    { key: 'activeCalls', label: 'Active Calls', value: stats.activeCalls || 0, icon: Radio, color: '--mdt-accent' },
    { key: 'openReports', label: 'Open Reports', value: stats.openReports || 0, icon: FileText, color: '--mdt-warning' },
    { key: 'activeWarrants', label: 'Active Warrants', value: stats.activeWarrants || 0, icon: AlertTriangle, color: '--mdt-error' },
    { key: 'unitsOnDuty', label: 'Units On Duty', value: stats.unitsOnDuty || 0, icon: Shield, color: '--mdt-success' },
  ]);

  let recentBolos = $derived(bolos.slice(0, 4));

  const STATUS_COLORS = {
    available: '#34d399',
    busy: '#fbbf24',
    en_route: '#60a5fa',
    on_scene: '#a78bfa',
    emergency: '#f87171',
    off_duty: '#6b7280',
  };

  const STATUS_LABELS = {
    available: 'Available',
    busy: 'Busy',
    en_route: 'En Route',
    on_scene: 'On Scene',
    emergency: 'EMERGENCY',
    off_duty: 'Off Duty',
  };

  const REPORT_STATUS = {
    open: { label: 'Open', color: '--mdt-accent' },
    pending_review: { label: 'Review', color: '--mdt-warning' },
    approved: { label: 'Approved', color: '--mdt-success' },
    closed: { label: 'Closed', color: 'rgba(228,232,239,0.3)' },
  };

  const DISPATCH_STATUS_COLORS = {
    active: '#f87171',
    in_progress: '#fbbf24',
    closed: '#6b7280',
  };

  function navigate(pageId) {
    tabsStore.openTab(pageId);
  }

  function formatTimeAgo(timestamp) {
    if (!timestamp) return '';
    const diff = Date.now() - new Date(timestamp).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'Just now';
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
  }

  function formatChatTime(timestamp) {
    if (!timestamp) return '';
    const d = new Date(timestamp);
    return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
  }

  async function toggleSearch() {
    searchOpen = !searchOpen;
    if (searchOpen) {
      await tick();
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

  async function handleSendChat() {
    const msg = chatInputVal.trim();
    if (!msg || sendingChat) return;
    sendingChat = true;
    chatInputVal = '';
    await dataStore.sendChatMessage(msg);
    sendingChat = false;
    await tick();
    if (chatListEl) {
      chatListEl.scrollTop = chatListEl.scrollHeight;
    }
  }

  function handleChatKey(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendChat();
    }
  }

  $effect(() => {
    if (chatMessages && chatListEl) {
      tick().then(() => {
        if (chatListEl) chatListEl.scrollTop = chatListEl.scrollHeight;
      });
    }
  });

  onMount(() => {
    mounted = true;
    dataStore.fetchDashboard();
  });
</script>

<div class="dashboard" class:mounted>

  <!-- ── Header Row ──────────────────────────────── -->
  <div class="dash-header">
    <div class="header-left">
      <div class="rank-badge">
        <BadgeCheck size={12} />
        <span class="rank-badge-text font-mono">{deptShort}</span>
      </div>
      <div class="header-identity">
        <h1 class="header-greeting">{greeting}, <span class="accent">{displayName}</span></h1>
        <div class="header-meta">
          <span class="meta-chip rank-chip">{rankLabel}</span>
          <span class="meta-sep">·</span>
          <span class="meta-chip callsign-chip font-mono">{callsign}</span>
        </div>
      </div>
    </div>

    <div class="header-right">
      <!-- Expandable Search -->
      <div class="search-wrap" class:open={searchOpen}>
        {#if searchOpen}
          <input
            bind:this={searchInputEl}
            class="search-input font-mono"
            type="text"
            placeholder="Search MDT..."
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

      <!-- Customize Dashboard -->
      <button class="customize-btn" onclick={() => layout.openCustomizer()} title="Customize dashboard widgets">
        <SlidersHorizontal size={14} />
        <span class="customize-btn-label">Customize</span>
      </button>

      <!-- On Duty Status pill -->
      <div class="duty-status-pill">
        <span class="duty-dot"></span>
        <span class="duty-label font-mono">ON DUTY</span>
      </div>
    </div>
  </div>

  <!-- ── Announcements Banner (top priority) ─────── -->
  {#if layout.isVisible('announcements') && announcements.length > 0}
    <div class="announcements-section">
      <div class="section-label">
        <Megaphone size={11} />
        <span>Bulletins & Announcements</span>
      </div>
      <div class="ann-list">
        {#each announcements.slice(0, 3) as ann (ann.id)}
          <div class="ann-item">
            <div class="ann-icon-wrap">
              <Bell size="100%" />
            </div>
            <div class="ann-body">
              <span class="ann-title">{ann.title}</span>
              <span class="ann-content">{ann.content}</span>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <!-- ── MOTD ─────────────────────────────────────── -->
  {#if layout.isVisible('motd') && motd}
    <div class="motd-card">
      <div class="motd-label">
        <Bell size={11} />
        <span>Message of the Day</span>
      </div>
      <p class="motd-text">{motd}</p>
    </div>
  {/if}

  <!-- ── Stat Cards ────────────────────────────────── -->
  {#if layout.isVisible('statCards')}
  <div class="stats-row">
    {#each statCards as card, i (card.key)}
      {@const Icon = card.icon}
      <button
        class="stat-card"
        style="--card-color: var({card.color}); --delay: {i * 0.05}s"
        onclick={() => {
          if (card.key === 'openReports') navigate('reports');
          else if (card.key === 'activeWarrants') navigate('warrants');
          else if (card.key === 'unitsOnDuty') navigate('units');
          else if (card.key === 'activeCalls') navigate('units');
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
  {/if}

  <!-- ── Main Grid ─────────────────────────────────── -->
  <div class="main-grid">

    <!-- Column 1: Dispatch + Recent Reports + Active BOLOs -->
    <div class="col col-left">

      <!-- Recent Dispatch Calls -->
      {#if layout.isVisible('dispatch')}
      <div class="panel">
        <div class="panel-header">
          <div class="panel-title-row">
            <Siren size={13} class="panel-icon" />
            <h2 class="panel-title">Recent Dispatch</h2>
          </div>
          <button class="see-all" onclick={() => navigate('units')}>View All</button>
        </div>
        <div class="dispatch-list">
          {#each dispatchCalls.slice(0, 4) as call (call.id)}
            {@const statusColor = DISPATCH_STATUS_COLORS[call.status] || '#6b7280'}
            <div class="dispatch-item" style="--dispatch-color: {statusColor}">
              <div class="dispatch-code font-mono">{call.code}</div>
              <div class="dispatch-body">
                <span class="dispatch-desc">{call.description}</span>
                <div class="dispatch-meta">
                  <span class="dispatch-unit font-mono">{call.unit}</span>
                  <span class="dispatch-dot-sep">·</span>
                  <span class="dispatch-time">{formatTimeAgo(call.created_at)}</span>
                </div>
              </div>
              <div class="dispatch-status-dot" style="background: {statusColor}"></div>
            </div>
          {:else}
            <div class="empty-state">No active calls</div>
          {/each}
        </div>
      </div>
      {/if}

      <!-- Recent Reports -->
      {#if layout.isVisible('reports')}
      <div class="panel">
        <div class="panel-header">
          <div class="panel-title-row">
            <FileText size={13} class="panel-icon" />
            <h2 class="panel-title">Recent Reports</h2>
          </div>
          <button class="see-all" onclick={() => navigate('reports')}>View All</button>
        </div>
        <div class="reports-list">
          {#each recentReports.slice(0, 4) as report (report.id)}
            {@const rStatus = REPORT_STATUS[report.status] || REPORT_STATUS.open}
            <button class="report-item" onclick={() => navigate('reports')}>
              <div class="report-number font-mono">{report.id.split('-').pop()}</div>
              <div class="report-body">
                <span class="report-title">{report.title}</span>
                <span class="report-author">{report.author} · {formatTimeAgo(report.created_at)}</span>
              </div>
              <span class="report-status-badge" style="color: var({rStatus.color}); background: color-mix(in srgb, var({rStatus.color}) 12%, transparent); border-color: color-mix(in srgb, var({rStatus.color}) 22%, transparent)">{rStatus.label}</span>
            </button>
          {:else}
            <div class="empty-state">No recent reports</div>
          {/each}
        </div>
      </div>
      {/if}

      <!-- Active BOLOs -->
      {#if layout.isVisible('bolos')}
      <div class="panel">
        <div class="panel-header">
          <div class="panel-title-row">
            <AlertTriangle size={13} class="panel-icon" />
            <h2 class="panel-title">Active BOLOs</h2>
          </div>
          {#if bolos.length > 4}
            <button class="see-all" onclick={() => navigate('bolos')}>See All</button>
          {/if}
        </div>
        <div class="bolo-list">
          {#each recentBolos as bolo (bolo.id)}
            <div class="bolo-item">
              <div class="bolo-type" class:person={bolo.type === 'person'} class:vehicle={bolo.type === 'vehicle'} class:weapon={bolo.type === 'weapon'} title={bolo.type}>
                {bolo.type?.[0]?.toUpperCase() || '?'}
              </div>
              <div class="bolo-info">
                <span class="bolo-title">{bolo.title || 'Untitled BOLO'}</span>
                <span class="bolo-meta">{bolo.type || 'Unknown'} · {formatTimeAgo(bolo.created_at)}</span>
              </div>
            </div>
          {:else}
            <div class="empty-state">No active BOLOs</div>
          {/each}
        </div>
      </div>
      {/if}
    </div>

    <!-- Column 2: Officer List + Officer Chat -->
    <div class="col col-right">

      <!-- On-Duty Officers -->
      {#if layout.isVisible('officers')}
      <div class="panel officer-panel">
        <div class="panel-header">
          <div class="panel-title-row">
            <Users size={13} class="panel-icon" />
            <h2 class="panel-title">Officers On Duty</h2>
          </div>
          <button class="see-all" onclick={() => navigate('units')}>
            <span class="officer-count-badge">{onDutyOfficers.length}</span>
          </button>
        </div>
        <div class="officer-list">
          {#each onDutyOfficers as ofc (ofc.id)}
            {@const statusColor = STATUS_COLORS[ofc.status] || STATUS_COLORS.off_duty}
            {@const statusLabel = STATUS_LABELS[ofc.status] || ofc.status}
            <div class="officer-row" style="--ofc-color: {statusColor}">
              <span class="ofc-callsign font-mono">{ofc.callsign}</span>
              <div class="ofc-info">
                <span class="ofc-name">{ofc.name}</span>
                <span class="ofc-rank">{ofc.rank}</span>
              </div>
              <div class="ofc-status" style="color: {statusColor}">
                <span class="ofc-status-dot" style="background: {statusColor}; {ofc.status === 'emergency' ? 'animation: emergDot 1s ease-in-out infinite;' : ''}"></span>
                <span class="ofc-status-label">{statusLabel}</span>
              </div>
            </div>
          {:else}
            <div class="empty-state">No officers on duty</div>
          {/each}
        </div>
      </div>
      {/if}

      <!-- Officer Chat -->
      {#if layout.isVisible('chat')}
      <div class="panel chat-panel">
        <div class="panel-header">
          <div class="panel-title-row">
            <MessageSquare size={13} class="panel-icon" />
            <h2 class="panel-title">Officer Chat</h2>
          </div>
          <span class="live-badge">
            <span class="live-dot"></span>
            Live
          </span>
        </div>
        <div class="chat-messages" bind:this={chatListEl}>
          {#each chatMessages as msg (msg.id)}
            <div class="chat-msg" class:mine={msg.isMine}>
              <div class="chat-msg-meta">
                <span class="chat-callsign font-mono">{msg.callsign}</span>
                <span class="chat-rank">{msg.rank}</span>
                <span class="chat-name">{msg.name}</span>
                <span class="chat-time font-mono">{formatChatTime(msg.timestamp)}</span>
              </div>
              <div class="chat-bubble">
                {msg.message}
              </div>
            </div>
          {:else}
            <div class="empty-state chat-empty">No messages yet</div>
          {/each}
        </div>
        <div class="chat-input-row">
          <input
            class="chat-input"
            type="text"
            placeholder="Broadcast message..."
            bind:value={chatInputVal}
            onkeydown={handleChatKey}
            disabled={sendingChat}
          />
          <button class="chat-send-btn" onclick={handleSendChat} disabled={sendingChat || !chatInputVal.trim()} title="Send">
            <Send size={14} />
          </button>
        </div>
      </div>
      {/if}
    </div>
  </div>
</div>

<DashboardCustomizer />

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

  .header-left {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    min-width: 0;
  }

  .rank-badge {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(9px * var(--mdt-scale));
    background: var(--mdt-accent-dim);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 20%, transparent);
    border-radius: calc(20px * var(--mdt-scale));
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .rank-badge :global(svg) {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .rank-badge-text {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .header-identity {
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
    min-width: 0;
  }

  .header-greeting {
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    line-height: 1.2;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .header-greeting .accent {
    color: var(--mdt-accent);
  }

  .header-meta {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .meta-chip {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .rank-chip {
    color: var(--mdt-text-dim);
    font-weight: 500;
  }

  .callsign-chip {
    color: var(--mdt-accent);
    letter-spacing: 0.05em;
  }

  .meta-sep {
    color: var(--mdt-border-2);
    font-size: calc(10px * var(--mdt-scale));
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

  .search-close-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .search-close-btn:hover {
    color: var(--mdt-error);
  }

  /* ── Customize Button ───────────────────────────── */
  .customize-btn {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
    cursor: pointer;
    font-family: inherit;
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 500;
    transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
    flex-shrink: 0;
  }

  .customize-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .customize-btn:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 30%, transparent);
  }

  .customize-btn:active {
    transform: scale(0.97);
  }

  .customize-btn-label {
    white-space: nowrap;
  }

  /* ── Duty Pill ──────────────────────────────────────── */
  .duty-status-pill {
    display: flex;
    align-items: center;
    gap: calc(7px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: rgba(52, 211, 153, 0.07);
    border: 1px solid rgba(52, 211, 153, 0.18);
    border-radius: calc(20px * var(--mdt-scale));
  }

  .duty-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-success);
    box-shadow: 0 0 calc(6px * var(--mdt-scale)) rgba(52, 211, 153, 0.6);
    animation: pulseDuty 2s ease-in-out infinite;
    flex-shrink: 0;
  }

  .duty-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-success);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  /* ── Announcements ──────────────────────────────────── */
  .announcements-section {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    animation: cardIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .section-label {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-warning);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .section-label :global(svg) {
    width: calc(11px * var(--mdt-scale));
    height: calc(11px * var(--mdt-scale));
  }

  .ann-list {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .ann-item {
    display: flex;
    align-items: flex-start;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: rgba(251, 191, 36, 0.05);
    border: 1px solid rgba(251, 191, 36, 0.12);
    border-left: 2px solid rgba(251, 191, 36, 0.5);
    border-radius: var(--mdt-radius);
  }

  .ann-icon-wrap {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-warning);
    opacity: 0.7;
    flex-shrink: 0;
    margin-top: calc(2px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .ann-icon-wrap :global(svg) {
    width: 100%;
    height: 100%;
  }

  .ann-body {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .ann-title {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .ann-content {
    font-size: calc(10.5px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.45;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  /* ── MOTD ───────────────────────────────────────────── */
  .motd-card {
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-accent-dim);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 18%, transparent);
    border-left: 2px solid color-mix(in srgb, var(--mdt-accent) 50%, transparent);
    border-radius: var(--mdt-radius);
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    animation: cardIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) 0.05s both;
  }

  .motd-label {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    color: var(--mdt-accent);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .motd-label :global(svg) {
    width: calc(11px * var(--mdt-scale));
    height: calc(11px * var(--mdt-scale));
  }

  .motd-text {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
  }

  /* ── Stat Cards ─────────────────────────────────────── */
  .stats-row {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: calc(8px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .stat-card {
    position: relative;
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    cursor: pointer;
    transition: background 0.2s ease, border-color 0.2s ease, transform 0.15s ease;
    text-align: left;
    font-family: inherit;
    overflow: hidden;
    animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) both;
    animation-delay: var(--delay);
  }

  .stat-card:hover {
    background: var(--mdt-surface-3);
    border-color: color-mix(in srgb, var(--card-color) 25%, var(--mdt-border));
  }

  .stat-card:active {
    transform: scale(0.97);
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

  .see-all {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    background: none;
    border: none;
    cursor: pointer;
    font-family: inherit;
    font-weight: 500;
    padding: calc(2px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    transition: background 0.15s ease;
    opacity: 0.75;
  }

  .see-all:hover {
    background: var(--mdt-accent-dim);
    opacity: 1;
  }

  /* ── Dispatch ───────────────────────────────────────── */
  .dispatch-list {
    display: flex;
    flex-direction: column;
  }

  .dispatch-item {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    position: relative;
    transition: background 0.12s ease;
  }

  .dispatch-item:last-child {
    border-bottom: none;
  }

  .dispatch-item::before {
    content: '';
    position: absolute;
    left: 0;
    top: 20%;
    bottom: 20%;
    width: calc(2px * var(--mdt-scale));
    background: var(--dispatch-color);
    border-radius: 0 2px 2px 0;
  }

  .dispatch-item:hover {
    background: var(--mdt-surface-3);
  }

  .dispatch-code {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 700;
    color: var(--dispatch-color);
    letter-spacing: 0.04em;
    min-width: calc(42px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .dispatch-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .dispatch-desc {
    font-size: calc(11.5px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .dispatch-meta {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
  }

  .dispatch-unit {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
  }

  .dispatch-dot-sep {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-border-2);
  }

  .dispatch-time {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .dispatch-status-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
    opacity: 0.8;
  }

  /* ── Reports ────────────────────────────────────────── */
  .reports-list {
    display: flex;
    flex-direction: column;
  }

  .report-item {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
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
  }

  .report-item:last-child {
    border-bottom: none;
  }

  .report-item:hover {
    background: var(--mdt-surface-3);
  }

  .report-number {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
    min-width: calc(36px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .report-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .report-title {
    font-size: calc(11.5px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .report-author {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .report-status-badge {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    padding: calc(2px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    border-radius: calc(20px * var(--mdt-scale));
    border: 1px solid;
    flex-shrink: 0;
    white-space: nowrap;
  }

  /* ── BOLOs ──────────────────────────────────────────── */
  .bolo-list {
    display: flex;
    flex-direction: column;
  }

  .bolo-item {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .bolo-item:last-child {
    border-bottom: none;
  }

  .bolo-type {
    width: calc(26px * var(--mdt-scale));
    height: calc(26px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--mdt-radius-sm);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 800;
    background: var(--mdt-surface-3);
    color: var(--mdt-text-muted);
    text-transform: uppercase;
  }

  .bolo-type.person {
    background: rgba(251, 191, 36, 0.12);
    color: var(--mdt-warning);
  }

  .bolo-type.vehicle {
    background: rgba(96, 165, 250, 0.12);
    color: #60a5fa;
  }

  .bolo-type.weapon {
    background: rgba(248, 113, 113, 0.12);
    color: var(--mdt-error);
  }

  .bolo-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .bolo-title {
    font-size: calc(11.5px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .bolo-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-transform: capitalize;
  }

  /* ── Officer List ───────────────────────────────────── */
  .officer-panel {
    flex-shrink: 0;
  }

  .officer-list {
    display: flex;
    flex-direction: column;
    max-height: calc(180px * var(--mdt-scale));
    overflow-y: auto;
  }

  .officer-row {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    transition: background 0.12s ease;
  }

  .officer-row:last-child {
    border-bottom: none;
  }

  .officer-row:hover {
    background: var(--mdt-surface-3);
  }

  .ofc-callsign {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
    min-width: calc(48px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .ofc-info {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: baseline;
    gap: calc(6px * var(--mdt-scale));
  }

  .ofc-name {
    font-size: calc(11.5px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ofc-rank {
    font-size: calc(9.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
  }

  .ofc-status {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .ofc-status-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .ofc-status-label {
    font-size: calc(9.5px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.03em;
    text-transform: uppercase;
  }

  .officer-count-badge {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-success);
    background: rgba(52, 211, 153, 0.1);
    border: 1px solid rgba(52, 211, 153, 0.2);
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(20px * var(--mdt-scale));
    font-family: 'Share Tech Mono', monospace;
    letter-spacing: 0.04em;
  }

  /* ── Officer Chat ───────────────────────────────────── */
  .chat-panel {
    flex: 1;
    min-height: calc(200px * var(--mdt-scale));
  }

  .live-badge {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-success);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .live-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-success);
    animation: pulseDuty 1.5s ease-in-out infinite;
  }

  .chat-messages {
    flex: 1;
    overflow-y: auto;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    max-height: calc(200px * var(--mdt-scale));
  }

  .chat-msg {
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
  }

  .chat-msg.mine .chat-bubble {
    background: color-mix(in srgb, var(--mdt-accent) 10%, var(--mdt-surface-3));
    border-color: color-mix(in srgb, var(--mdt-accent) 20%, transparent);
    color: var(--mdt-text);
  }

  .chat-msg-meta {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
  }

  .chat-callsign {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
  }

  .chat-rank {
    font-size: calc(9.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .chat-name {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-weight: 500;
  }

  .chat-time {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    margin-left: auto;
    letter-spacing: 0.04em;
  }

  .chat-bubble {
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    font-size: calc(11.5px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.45;
  }

  .chat-input-row {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    flex-shrink: 0;
    background: var(--mdt-surface);
  }

  .chat-input {
    flex: 1;
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .chat-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .chat-input:focus {
    border-color: color-mix(in srgb, var(--mdt-accent) 40%, transparent);
  }

  .chat-input:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .chat-send-btn {
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--mdt-accent);
    border: none;
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-bg);
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .chat-send-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .chat-send-btn:hover:not(:disabled) {
    opacity: 0.88;
  }

  .chat-send-btn:active:not(:disabled) {
    transform: scale(0.94);
  }

  .chat-send-btn:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }

  /* ── Empty state ────────────────────────────────────── */
  .empty-state {
    padding: calc(16px * var(--mdt-scale));
    text-align: center;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .chat-empty {
    padding: calc(24px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
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
    0%, 100% { opacity: 1; box-shadow: 0 0 calc(6px * var(--mdt-scale)) rgba(52, 211, 153, 0.6); }
    50% { opacity: 0.55; box-shadow: 0 0 calc(3px * var(--mdt-scale)) rgba(52, 211, 153, 0.3); }
  }

  @keyframes emergDot {
    0%, 100% { opacity: 1; box-shadow: 0 0 6px rgba(248,113,113,0.8); }
    50% { opacity: 0.4; box-shadow: none; }
  }
</style>
