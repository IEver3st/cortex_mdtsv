<script>
  import { onMount, tick } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser, nuiPost } from '../lib/utils/nui.js';
  import { playMdtSound } from '../lib/utils/mdtSounds.js';
  import { tabsStore } from '../lib/stores/tabs.svelte.js';
  import { dashboardLayout } from '../lib/stores/dashboardLayout.svelte.js';
  import DashboardCustomizer from '../lib/components/DashboardCustomizer.svelte';
  import QuickActionsWidget from '../lib/components/QuickActionsWidget.svelte';
  import {
    Radio,
    FileText,
    AlertTriangle,
    Shield,
    Megaphone,
    Send,
    Users,
    Siren,
    MessageSquare,
    SlidersHorizontal,
    ChevronRight,
  } from '@lucide/svelte';

  let layout = dashboardLayout;

  let mounted = $state(false);
  let chatInputVal = $state('');
  let chatListEl = $state(null);
  let sendingChat = $state(false);

  let officer = $derived(mdtStore.officer);
  let settings = $derived(mdtStore.settings);
  let stats = $derived(dataStore.dashboardStats);
  let bolos = $derived(dataStore.dashboardBolos || []);
  let announcements = $derived(dataStore.dashboardAnnouncements || []);
  /** Same source as Dispatch page (`getDashboard` dispatch list empty on server). */
  let dispatchCalls = $derived.by(() => {
    const raw = dataStore.dispatchCalls || [];
    return [...raw].sort((a, b) => {
      const ta = new Date(a.createdAt || a.created_at || 0).getTime();
      const tb = new Date(b.createdAt || b.created_at || 0).getTime();
      return tb - ta;
    });
  });
  let recentReports = $derived(dataStore.dashboardRecentReports || []);
  let onDutyOfficers = $derived(dataStore.dashboardOnDutyOfficers || []);
  let chatMessages = $derived(dataStore.dashboardChatMessages || []);

  let rankLabel = $derived(officer.rank || 'Officer');
  let callsign = $derived(officer.callsign || '—');

  let statCards = $derived([
    { key: 'activeCalls', label: 'Active Calls', value: stats.activeCalls || 0, icon: Radio, color: '--mdt-error' },
    { key: 'openReports', label: 'Open Reports', value: stats.openReports || 0, icon: FileText, color: '--mdt-warning' },
    { key: 'activeWarrants', label: 'Active Warrants', value: stats.activeWarrants || 0, icon: AlertTriangle, color: '--mdt-error' },
    { key: 'unitsOnDuty', label: 'Units On Duty', value: stats.unitsOnDuty || 0, icon: Shield, color: '--mdt-success' },
  ]);

  let recentBolos = $derived(bolos.slice(0, 3));

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

  const DISPATCH_SEVERITY_COLORS = {
    critical: '#f87171',
    high: '#fb923c',
    medium: '#fbbf24',
    low: '#94a3b8',
  };

  function dispatchAccentColor(call) {
    const st = call?.status;
    if (st && DISPATCH_STATUS_COLORS[st]) return DISPATCH_STATUS_COLORS[st];
    const sev = String(call?.severity || '').toLowerCase();
    if (sev && DISPATCH_SEVERITY_COLORS[sev]) return DISPATCH_SEVERITY_COLORS[sev];
    return '#6b7280';
  }

  function dispatchCallTitle(call) {
    return call?.title || call?.description || '—';
  }

  function dispatchCallUnit(call) {
    return call?.primaryCallsign || call?.unit || '—';
  }

  function dispatchCallTimestamp(call) {
    return call?.createdAt || call?.created_at || '';
  }

  function dispatchBadgeLabel(call) {
    const raw = call?.statusLabel || call?.codeName || call?.status || call?.severity || 'active';
    return String(raw).replace(/_/g, ' ');
  }

  let visibleLeftWidgets = $derived([
    layout.isVisible('dispatch') ? 'dispatch' : null,
    layout.isVisible('reports') ? 'reports' : null,
    layout.isVisible('bolos') ? 'bolos' : null,
  ].filter(Boolean));

  let visibleRightWidgets = $derived([
    layout.isVisible('officers') ? 'officers' : null,
    layout.isVisible('chat') ? 'chat' : null,
  ].filter(Boolean));

  let mainGridClass = $derived.by(() => {
    const left = visibleLeftWidgets.length;
    const right = visibleRightWidgets.length;
    if (left === 0 && right === 0) return 'main-grid empty';
    if (left === 0) return 'main-grid right-only';
    if (right === 0) return 'main-grid left-only';
    return 'main-grid';
  });

  function navigate(pageId) {
    tabsStore.openTab(pageId);
  }

  $effect(() => {
    if (!mdtStore.pendingAuthedIntro) return;
    if (tabsStore.activePage !== 'dashboard') return;
    playMdtSound('dashboard');
  });

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

  function chatAvatarInitials(msg) {
    const n = String(msg.name || '').trim();
    const c = String(msg.callsign || '').trim();
    if (n.length >= 2) return n.slice(0, 2).toUpperCase();
    if (n.length === 1) return (n + (c[0] || '?')).slice(0, 2).toUpperCase();
    const parts = c.split(/[-\s]/).filter(Boolean);
    if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    return (c.slice(0, 2) || '??').toUpperCase();
  }

  function chatSenderLine(msg) {
    const cs = msg.callsign || '—';
    const nm = msg.name ? String(msg.name) : '';
    const rk = msg.rank ? String(msg.rank) : '';
    if (nm && rk) return `${cs} · ${rk} ${nm}`;
    if (nm) return `${cs} · ${nm}`;
    return cs;
  }

  function chatAvatarHue(msg) {
    let h = 0;
    const s = String(msg.callsign || msg.name || 'x');
    for (let i = 0; i < s.length; i++) h = (h + s.charCodeAt(i) * (i + 1)) % 360;
    return h;
  }

  function chatMsgIsMine(msg) {
    if (msg.isMine) return true;
    const myId = officer?.officerId;
    const oid = msg.officerId;
    if (myId != null && oid != null && String(myId) === String(oid)) return true;
    return false;
  }

  /** Server `avatar` on row, else local profile URL for own messages. */
  function chatAvatarDisplayUrl(msg) {
    const fromRow = String(msg.avatar || '').trim();
    if (fromRow) return fromRow;
    if (chatMsgIsMine(msg)) {
      const o = String(officer?.avatar || '').trim();
      if (o) return o;
      const s = String(settings?.avatarUrl || '').trim();
      if (s) return s;
    }
    return '';
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
    const sub = !isEnvBrowser()
      ? nuiPost('cortex_mdt:subscribeDispatch').catch(() => {})
      : Promise.resolve();
    Promise.all([
      dataStore.fetchDashboard(),
      dataStore.fetchUnits(),
      dataStore.fetchDispatch(),
      sub,
    ]);
  });
</script>

<div class="dashboard" class:mounted>

  {#if layout.isVisible('quickActions')}
    <div class="dash-prelude-qa">
      <QuickActionsWidget />
    </div>
    <div class="prelude-hrule" aria-hidden="true"></div>
  {:else}
    <div class="dash-layout-only">
      <button
        type="button"
        class="dash-layout-only-btn"
        onclick={() => layout.openCustomizer()}
        title="Customize dashboard layout"
        aria-label="Customize dashboard layout"
      >
        <SlidersHorizontal size={14} />
      </button>
    </div>
  {/if}

  <!-- ── Bulletins (ruled, no cards) ─── -->
  {#if layout.isVisible('announcements')}
    <div class="dash-prelude">
      <section class="bulletins-block" aria-label="Bulletins">
          <header class="bulletins-head">
            <div class="bulletins-head-left">
              <Megaphone size={12} class="bulletins-ico" />
              <span class="bulletins-title">Bulletins</span>
            </div>
          </header>
          {#if announcements.length > 0}
            <ul class="bulletins-list">
              {#each announcements.slice(0, 4) as ann (ann.id)}
                <li class="bulletin-item">
                  <span class="bulletin-title">{ann.title}</span>
                  <p class="bulletin-body">{ann.content}</p>
                </li>
              {/each}
            </ul>
          {:else}
            <p class="bulletins-empty">No active bulletins.</p>
          {/if}
        </section>
    </div>
    <div class="prelude-hrule" aria-hidden="true"></div>
  {/if}

  <!-- ── Stats strip (image-2 style: icon tile + two lines, dividers) ─── -->
  {#if layout.isVisible('statCards')}
    <div class="stats-strip">
      {#each statCards as card, i (card.key)}
        {@const Icon = card.icon}
        <button
          class="stat-cell"
          style="--cell-color: var({card.color}); --delay: {i * 0.05}s"
          onclick={() => {
            if (card.key === 'openReports') navigate('reports');
            else if (card.key === 'activeWarrants') navigate('warrants');
            else if (card.key === 'unitsOnDuty') navigate('units');
            else if (card.key === 'activeCalls') navigate('units');
          }}
        >
          <div class="stat-cell-ico">
            <Icon size="100%" />
          </div>
          <div class="stat-cell-lines">
            <span class="stat-cell-value font-mono">{card.value}</span>
            <span class="stat-cell-label">{card.label}</span>
          </div>
        </button>
      {/each}
    </div>
    <div class="stats-strip-hrule" aria-hidden="true"></div>
  {/if}

  <!-- ── Main Grid ─────────────────────────────────── -->
  <div class={mainGridClass}>

    <!-- Column 1: Dispatch + Reports + BOLOs -->
    {#if visibleLeftWidgets.length > 0}
      <div class="col col-left">

        {#if layout.isVisible('dispatch')}
          <div class="panel dispatch-panel">
            <div class="panel-header">
              <div class="panel-title-row">
                <Siren size={13} class="panel-icon" />
                <h2 class="panel-title">Recent Dispatch</h2>
              </div>
              <button class="see-all" onclick={() => navigate('dispatch')}>View All</button>
            </div>
            <div class="dispatch-list">
              {#each dispatchCalls as call (call.id)}
                {@const statusColor = dispatchAccentColor(call)}
                <div class="dispatch-item" style="--dispatch-color: {statusColor}">
                  <div class="dispatch-item-top">
                    <span class="dispatch-code font-mono">{call.code}</span>
                    <span class="dispatch-status-text" style="color: {statusColor}">{dispatchBadgeLabel(call)}</span>
                  </div>
                  <span class="dispatch-desc">{dispatchCallTitle(call)}</span>
                  {#if call.location}
                    <span class="dispatch-loc">{call.location}</span>
                  {/if}
                  <div class="dispatch-meta">
                    <span class="dispatch-unit font-mono">{dispatchCallUnit(call)}</span>
                    <span class="dispatch-dot-sep">·</span>
                    <span class="dispatch-time">{formatTimeAgo(dispatchCallTimestamp(call))}</span>
                  </div>
                </div>
              {:else}
                <div class="empty-state">No active calls</div>
              {/each}
            </div>
          </div>
        {/if}

        {#if layout.isVisible('reports')}
          <div class="panel reports-panel">
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
                  <span class="report-number font-mono">#{report.id.split('-').pop()}</span>
                  <div class="report-body">
                    <span class="report-title">{report.title}</span>
                    <span class="report-author">{report.author} · {formatTimeAgo(report.created_at)}</span>
                  </div>
                  <span class="report-status-text" style="--status-color: var({rStatus.color})">{rStatus.label}</span>
                </button>
              {:else}
                <div class="empty-state">No recent reports</div>
              {/each}
            </div>
          </div>
        {/if}

        {#if layout.isVisible('bolos')}
          <div class="panel bolos-panel">
            <div class="panel-header">
              <div class="panel-title-row">
                <AlertTriangle size={13} class="panel-icon" />
                <h2 class="panel-title">Active BOLOs</h2>
              </div>
              {#if bolos.length > 3}
                <button class="see-all" onclick={() => navigate('bolos')}>See All</button>
              {/if}
            </div>
            <div class="bolo-list">
              {#each recentBolos as bolo (bolo.id)}
                <div class="bolo-item">
                  <div class="bolo-info">
                    <span class="bolo-title">{bolo.title || 'Untitled BOLO'}</span>
                    <span class="bolo-meta">{bolo.type} · {formatTimeAgo(bolo.created_at)}</span>
                  </div>
                  <ChevronRight size={12} class="bolo-arrow" />
                </div>
              {:else}
                <div class="empty-state">No active BOLOs</div>
              {/each}
            </div>
          </div>
        {/if}

      </div>
    {/if}

    <!-- Column 2: Officers + Chat -->
    {#if visibleRightWidgets.length > 0}
      <div class="col col-right">

        {#if layout.isVisible('officers')}
          <div class="panel officers-panel">
            <div class="panel-header">
              <div class="panel-title-row">
                <Users size={13} class="panel-icon" />
                <h2 class="panel-title">Officers On Duty</h2>
              </div>
              <span class="officer-count font-mono">{onDutyOfficers.length} on roster</span>
            </div>
            <div class="officer-list">
              {#each onDutyOfficers as ofc (ofc.id)}
                {@const statusColor = STATUS_COLORS[ofc.status] || STATUS_COLORS.off_duty}
                {@const statusLabel = STATUS_LABELS[ofc.status] || ofc.status}
                <div class="officer-row" style="--ofc-color: {statusColor}">
                  <span class="ofc-callsign font-mono">{ofc.callsign}</span>
                  {#if ofc.avatar}
                    <img class="ofc-avatar" src={ofc.avatar} alt="" />
                  {/if}
                  <div class="ofc-info">
                    <span class="ofc-name">{ofc.name}</span>
                    <span class="ofc-rank">{ofc.rank}</span>
                  </div>
                  <div class="ofc-status">
                    <span class="ofc-dot" style="background: {statusColor}; {ofc.status === 'emergency' ? 'animation: emergPulse 1s infinite;' : ''}"></span>
                    <span class="ofc-status-label">{statusLabel}</span>
                  </div>
                </div>
              {:else}
                <div class="empty-state">No officers on duty</div>
              {/each}
            </div>
          </div>
        {/if}

        {#if layout.isVisible('chat')}
          <div class="panel chat-panel">
            <div class="panel-header">
              <div class="panel-title-row">
                <MessageSquare size={13} class="panel-icon" />
                <h2 class="panel-title">Officer Chat</h2>
              </div>
              <span class="live-indicator">
                <span class="live-dot"></span>
                Live
              </span>
            </div>
            <div class="chat-messages" bind:this={chatListEl}>
              {#each chatMessages as msg (msg.id)}
                {@const chatAvUrl = chatAvatarDisplayUrl(msg)}
                <div class="chat-msg" class:mine={chatMsgIsMine(msg)}>
                  <div
                    class="chat-avatar font-mono"
                    class:chat-avatar-img-wrap={!!chatAvUrl}
                    style="--chat-av-h: {chatAvatarHue(msg)}"
                    aria-hidden="true"
                  >
                    {#if chatAvUrl}
                      <img class="chat-avatar-img" src={chatAvUrl} alt="" />
                    {:else}
                      {chatAvatarInitials(msg)}
                    {/if}
                  </div>
                  <div class="chat-msg-col">
                    <div class="chat-meta-row">
                      <span class="chat-sender">{chatSenderLine(msg)}</span>
                      <span class="chat-time font-mono">{formatChatTime(msg.timestamp)}</span>
                    </div>
                    <div class="chat-bubble">{msg.message}</div>
                  </div>
                </div>
              {:else}
                <div class="empty-state">No messages yet</div>
              {/each}
            </div>
            <div class="chat-input-row">
              <input
                class="chat-input"
                type="text"
                placeholder="Broadcast..."
                bind:value={chatInputVal}
                onkeydown={handleChatKey}
                disabled={sendingChat}
              />
              <button class="chat-send-btn" onclick={handleSendChat} disabled={sendingChat || !chatInputVal.trim()}>
                <Send size={12} />
              </button>
            </div>
          </div>
        {/if}

      </div>
    {/if}

  </div>
</div>

<DashboardCustomizer />

<style>
  /* ─────────────────────────────────────────────────
     DASHBOARD SHELL
  ───────────────────────────────────────────────── */
  .dashboard {
    flex: 1;
    width: 100%;
    height: 100%;
    min-height: 0;
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    overflow: hidden;
    opacity: 0;
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    container-type: size;
    container-name: dash;
  }

  .dashboard.mounted { opacity: 1; }

  .dash-layout-only {
    display: flex;
    justify-content: flex-end;
    flex-shrink: 0;
    padding: 0 0 calc(4px * var(--mdt-scale));
  }

  .dash-layout-only-btn {
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition:
      background 0.15s ease,
      color 0.15s ease,
      border-color 0.15s ease,
      transform 0.12s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .dash-layout-only-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .dash-layout-only-btn:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 28%, var(--mdt-border));
    box-shadow: inset 0 1px 0 color-mix(in srgb, var(--mdt-text) 6%, transparent);
  }

  .dash-layout-only-btn:active {
    transform: scale(0.96);
  }

  .dash-prelude-qa {
    flex-shrink: 0;
    min-width: 0;
    /* opacity-only: fadeIn uses transform → traps position:fixed (Quick Actions modal) to this tiny box */
    animation: preludeFade 0.45s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .dash-prelude-qa :global(.quick-actions-panel) {
    margin-top: 0;
    padding-top: 0;
    border-top: none;
  }

  /* ── Bulletins prelude ─── */
  .dash-prelude {
    display: grid;
    grid-template-columns: 1fr;
    gap: calc(6px * var(--mdt-scale));
    flex-shrink: 0;
    align-items: stretch;
    /* Grid bulletins need a bit more vertical room per tile (title + body) */
    max-height: min(30cqh, calc(12.5rem * var(--mdt-scale)));
    overflow: hidden;
    animation: fadeIn 0.45s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .prelude-hrule {
    height: 1px;
    margin: calc(4px * var(--mdt-scale)) 0 calc(2px * var(--mdt-scale));
    background: linear-gradient(
      90deg,
      transparent 0%,
      var(--mdt-border) 8%,
      var(--mdt-border) 92%,
      transparent 100%
    );
    flex-shrink: 0;
  }

  .bulletins-block {
    min-width: 0;
    min-height: 0;
    padding: calc(2px * var(--mdt-scale)) 0;
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    overflow: hidden;
  }

  .bulletins-head {
    margin: 0;
  }

  .bulletins-head-left {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .bulletins-block :global(.bulletins-ico) {
    color: var(--mdt-warning);
    flex-shrink: 0;
  }

  .bulletins-title {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--mdt-text-dim);
  }

  .bulletins-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(100%, calc(200px * var(--mdt-scale))), 1fr));
    gap: calc(8px * var(--mdt-scale));
    overflow-y: auto;
    min-height: 0;
    flex: 1;
    align-content: start;
  }

  .bulletin-item {
    min-width: 0;
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: calc(3px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(4px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: color-mix(in srgb, var(--mdt-surface-2) 88%, transparent);
    font-size: calc(10px * var(--mdt-scale));
    line-height: 1.35;
  }

  .bulletin-title {
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.02em;
  }

  .bulletin-body {
    margin: 0;
    color: var(--mdt-text-dim);
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    overflow: hidden;
  }

  .bulletins-empty {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-style: italic;
  }

  /* ── Stats strip (flat, ruled) ─── */
  .stats-strip {
    display: flex;
    flex-wrap: wrap;
    flex-shrink: 0;
    border-top: 1px solid transparent;
  }

  .stats-strip-hrule {
    height: 1px;
    margin: calc(4px * var(--mdt-scale)) 0 calc(2px * var(--mdt-scale));
    background: linear-gradient(
      90deg,
      transparent,
      var(--mdt-border) 6%,
      var(--mdt-border) 94%,
      transparent
    );
  }

  .stat-cell {
    flex: 1 1 calc(25% - 1px);
    min-width: calc(130px * var(--mdt-scale));
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: transparent;
    border: none;
    border-right: 1px solid var(--mdt-border);
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    transition: background 0.15s ease;
    animation: cardIn 0.38s cubic-bezier(0.16, 1, 0.3, 1) both;
    animation-delay: var(--delay);
  }

  .stat-cell:last-child {
    border-right: none;
  }

  .stat-cell:hover {
    background: color-mix(in srgb, var(--cell-color) 6%, transparent);
  }

  .stat-cell:active {
    transform: scale(0.96);
  }

  .stat-cell-ico {
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: calc(5px * var(--mdt-scale));
    color: var(--mdt-bg);
    background: var(--cell-color);
    border-radius: calc(4px * var(--mdt-scale));
    box-shadow:
      0 calc(2px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) color-mix(in srgb, var(--cell-color) 35%, transparent),
      inset 0 1px 0 rgba(255, 255, 255, 0.12);
  }

  .stat-cell-ico :global(svg) {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
  }

  .stat-cell-lines {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .stat-cell-value {
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    line-height: 1;
    letter-spacing: -0.02em;
    font-variant-numeric: tabular-nums;
  }

  .stat-cell-label {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  /* ─────────────────────────────────────────────────
     MAIN GRID — fills remaining vertical space
  ───────────────────────────────────────────────── */
  .main-grid {
    display: grid;
    grid-template-columns: 1.15fr 1fr;
    gap: 0 calc(12px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
    position: relative;
    container-type: size;
    container-name: dash-main;
  }

  .main-grid.empty { display: none; }

  .main-grid.left-only,
  .main-grid.right-only {
    grid-template-columns: 1fr;
  }

  .main-grid:not(.left-only):not(.right-only) .col-right {
    border-left: 1px solid var(--mdt-border);
    padding-left: calc(16px * var(--mdt-scale));
    margin-left: calc(2px * var(--mdt-scale));
  }

  .col {
    display: flex;
    flex-direction: column;
    gap: 0;
    min-height: 0;
    flex: 1;
    overflow: hidden;
    align-items: stretch;
  }

  /* ─────────────────────────────────────────────────
     Sections — no card chrome, rules only
  ───────────────────────────────────────────────── */
  .panel {
    background: transparent;
    border: none;
    border-radius: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    flex: 0 1 auto;
    min-height: 0;
    margin-top: calc(6px * var(--mdt-scale));
    padding-top: calc(6px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  .panel:first-child {
    margin-top: 0;
    padding-top: 0;
    border-top: none;
  }

  /* Hug content; max-height + scroll when list is long (no flex-grow gap below last row) */
  .dispatch-panel {
    flex: 0 1 auto;
    min-height: calc(9rem * var(--mdt-scale));
    max-height: min(50cqh, 58%);
    width: 100%;
    align-self: stretch;
  }

  .reports-panel {
    flex: 0 1 auto;
    min-height: calc(4.5rem * var(--mdt-scale));
    max-height: min(28cqh, 36%);
  }

  .bolos-panel {
    flex: 0 1 auto;
    max-height: min(24cqh, 32%);
  }

  .officers-panel {
    flex: 0 1 34%;
    min-height: calc(5rem * var(--mdt-scale));
    max-height: min(40cqh, 44%);
  }

  .chat-panel {
    flex: 1 1 0;
    min-height: 0;
    width: 100%;
    align-self: stretch;
  }

  /* ── Panel Header ─── */
  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 0 calc(5px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border-2) 70%, transparent);
    flex-shrink: 0;
    background: transparent;
    gap: calc(8px * var(--mdt-scale));
  }

  .panel-title-row {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  /* Per-panel icon colors (semantic tying) */
  .dispatch-panel .panel-title-row :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-error);
    flex-shrink: 0;
  }

  .reports-panel .panel-title-row :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-warning);
    flex-shrink: 0;
  }

  .bolos-panel .panel-title-row :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-warning);
    flex-shrink: 0;
  }

  .officers-panel .panel-title-row :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-success);
    flex-shrink: 0;
  }

  .chat-panel .panel-title-row :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .panel-title {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-dim);
    text-transform: uppercase;
    letter-spacing: 0.07em;
    text-wrap: balance;
  }

  .see-all {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-accent);
    background: none;
    border: none;
    cursor: pointer;
    font-family: inherit;
    font-weight: 500;
    padding: calc(2px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    transition: background 0.15s ease;
    opacity: 0.7;
  }

  .see-all:hover {
    background: var(--mdt-accent-dim);
    opacity: 1;
  }

  /* ─────────────────────────────────────────────────
     DISPATCH — full-height list
  ───────────────────────────────────────────────── */
  .dispatch-list {
    display: flex;
    flex-direction: column;
    flex: 1 1 auto;
    overflow-x: hidden;
    overflow-y: auto;
    min-height: 0;
    scrollbar-gutter: stable;
  }

  .dispatch-item {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    transition: background 0.12s ease;
  }

  .dispatch-item:last-child { border-bottom: none; }
  .dispatch-item:hover { background: var(--mdt-surface-3); }

  .dispatch-item-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .dispatch-code {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--dispatch-color);
    letter-spacing: 0.04em;
    font-family: 'Share Tech Mono', monospace;
    line-height: 1.2;
    flex-shrink: 0;
  }

  .dispatch-desc {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 500;
    line-height: 1.35;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .dispatch-loc {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.3;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .dispatch-meta {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
  }

  .dispatch-unit {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-accent);
    font-family: 'Share Tech Mono', monospace;
    letter-spacing: 0.03em;
  }

  .dispatch-dot-sep {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-border-2);
  }

  .dispatch-time {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .dispatch-status-text {
    font-size: calc(8px * var(--mdt-scale));
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    flex-shrink: 0;
    max-width: 55%;
    text-align: right;
    line-height: 1.2;
    white-space: normal;
  }

  /* ─────────────────────────────────────────────────
     REPORTS — full-height list
  ───────────────────────────────────────────────── */
  .reports-list {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow-y: auto;
    min-height: 0;
  }

  .report-item {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
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
    width: 100%;
  }

  .report-item:last-child { border-bottom: none; }
  .report-item:hover { background: var(--mdt-surface-3); }

  .report-number {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', monospace;
    letter-spacing: 0.03em;
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
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .report-author {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .report-status-text {
    font-size: calc(8px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--status-color);
    flex-shrink: 0;
    white-space: nowrap;
  }

  /* ─────────────────────────────────────────────────
     BOLOs — full-height list
  ───────────────────────────────────────────────── */
  .bolo-list {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow-y: auto;
    min-height: 0;
  }

  .bolo-item {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    transition: background 0.12s ease;
    cursor: default;
  }

  .bolo-item:last-child { border-bottom: none; }
  .bolo-item:hover { background: var(--mdt-surface-3); }

  .bolo-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .bolo-title {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .bolo-meta {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-transform: capitalize;
  }

  .bolo-item :global(.bolo-arrow) {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    opacity: 0;
    transition: opacity 0.12s ease;
  }

  .bolo-item:hover :global(.bolo-arrow) { opacity: 1; }

  /* ─────────────────────────────────────────────────
     OFFICERS — compact with scroll
  ───────────────────────────────────────────────── */
  .officer-list {
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    flex: 1;
    min-height: 0;
  }

  .officer-row {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(9px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    transition: background 0.12s ease;
  }

  .officer-row:last-child { border-bottom: none; }
  .officer-row:hover { background: var(--mdt-surface-3); }

  .ofc-callsign {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-success);
    letter-spacing: 0.03em;
    font-family: 'Share Tech Mono', monospace;
    min-width: calc(48px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .ofc-avatar {
    width: calc(22px * var(--mdt-scale));
    height: calc(22px * var(--mdt-scale));
    border-radius: 50%;
    object-fit: cover;
    flex-shrink: 0;
    border: 1px solid var(--mdt-border);
  }

  .ofc-info {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: baseline;
    gap: calc(6px * var(--mdt-scale));
  }

  .ofc-name {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ofc-rank {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
  }

  .ofc-status {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .ofc-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .ofc-status-label {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--ofc-color);
  }

  .officer-count {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-success);
    font-family: 'Share Tech Mono', monospace;
    letter-spacing: 0.03em;
  }

  /* ─────────────────────────────────────────────────
     CHAT — fills remaining right-column height
  ───────────────────────────────────────────────── */
  .chat-messages {
    flex: 1;
    overflow-y: auto;
    padding: calc(10px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    min-height: 0;
  }

  .chat-msg {
    display: flex;
    flex-direction: row;
    align-items: flex-end;
    gap: calc(8px * var(--mdt-scale));
    max-width: 100%;
  }

  .chat-msg.mine {
    flex-direction: row-reverse;
    justify-content: flex-start;
  }

  .chat-avatar {
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.02em;
    line-height: 1;
    border: 1px solid var(--mdt-border);
    background: color-mix(
      in hsl,
      hsl(var(--chat-av-h, 210) 38% 46%) 78%,
      var(--mdt-surface-3)
    );
    color: rgba(248, 250, 252, 0.96);
    box-shadow: 0 calc(1px * var(--mdt-scale)) calc(6px * var(--mdt-scale)) rgba(0, 0, 0, 0.35);
  }

  .chat-avatar-img-wrap {
    padding: 0;
    overflow: hidden;
    background: var(--mdt-surface-3);
  }

  .chat-avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
    border-radius: 50%;
  }

  .chat-msg.mine .chat-avatar {
    background: color-mix(in srgb, var(--mdt-accent) 72%, var(--mdt-surface-3));
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, transparent);
    color: rgba(248, 250, 252, 0.96);
  }

  .chat-msg-col {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: calc(3px * var(--mdt-scale));
    min-width: 0;
    max-width: calc(100% - calc(30px * var(--mdt-scale)) - calc(8px * var(--mdt-scale)));
  }

  .chat-msg.mine .chat-msg-col {
    align-items: flex-end;
  }

  .chat-meta-row {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: calc(6px * var(--mdt-scale));
    width: 100%;
    max-width: 100%;
  }

  .chat-msg.mine .chat-meta-row {
    flex-direction: row-reverse;
    justify-content: flex-end;
  }

  .chat-sender {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.04em;
    line-height: 1.25;
    color: color-mix(in srgb, var(--mdt-error) 82%, var(--mdt-text));
  }

  .chat-msg.mine .chat-sender {
    color: var(--mdt-accent);
  }

  .chat-time {
    font-size: calc(8px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', monospace;
    letter-spacing: 0.02em;
    flex-shrink: 0;
  }

  .chat-bubble {
    width: fit-content;
    max-width: 100%;
    padding: calc(7px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    background: var(--mdt-accent);
    border: 1px solid color-mix(in srgb, var(--mdt-bg) 18%, transparent);
    border-radius: calc(4px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-bg);
    line-height: 1.45;
    word-wrap: break-word;
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
    font-size: calc(11px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .chat-input::placeholder { color: var(--mdt-text-muted); }
  .chat-input:focus { border-color: color-mix(in srgb, var(--mdt-accent) 35%, transparent); }
  .chat-input:disabled { opacity: 0.5; cursor: not-allowed; }

  .chat-send-btn {
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--mdt-accent);
    border: none;
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-bg);
    cursor: pointer;
    transition: background 0.15s ease, opacity 0.15s ease, transform 0.15s ease;
  }

  .chat-send-btn :global(svg) {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
  }

  .chat-send-btn:hover:not(:disabled) { opacity: 0.85; }
  .chat-send-btn:active:not(:disabled) { transform: scale(0.96); }
  .chat-send-btn:disabled { opacity: 0.3; cursor: not-allowed; }

  /* ── Live Indicator ─── */
  .live-indicator {
    display: flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    font-size: calc(8px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-success);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .live-dot {
    width: calc(5px * var(--mdt-scale));
    height: calc(5px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-success);
    animation: dutyPulse 1.5s ease-in-out infinite;
  }

  /* ── Empty State ─── */
  .empty-state {
    padding: calc(10px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    text-align: center;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* ── Scrollbars inside panels ─── */
  .dispatch-list::-webkit-scrollbar,
  .reports-list::-webkit-scrollbar,
  .bolo-list::-webkit-scrollbar,
  .officer-list::-webkit-scrollbar,
  .chat-messages::-webkit-scrollbar {
    width: calc(3px * var(--mdt-scale));
  }

  .dispatch-list::-webkit-scrollbar-thumb,
  .reports-list::-webkit-scrollbar-thumb,
  .bolo-list::-webkit-scrollbar-thumb,
  .officer-list::-webkit-scrollbar-thumb,
  .chat-messages::-webkit-scrollbar-thumb {
    background: var(--mdt-border-2);
    border-radius: 2px;
  }

  /* ── Keyframes ─── */
  @keyframes preludeFade {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(4px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes cardIn {
    from { opacity: 0; transform: translateY(calc(4px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes dutyPulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  @keyframes emergPulse {
    0%, 100% { opacity: 1; box-shadow: 0 0 5px rgba(248,113,113,0.7); }
    50% { opacity: 0.5; box-shadow: none; }
  }
</style>
