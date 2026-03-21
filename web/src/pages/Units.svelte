<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const STATUS_ORDER = { emergency: 0, on_scene: 1, en_route: 2, busy: 3, available: 4, off_duty: 5 };

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
    emergency: 'Emergency',
    off_duty: 'Off Duty',
  };

  const SELECTABLE_STATUSES = ['available', 'busy', 'en_route', 'on_scene', 'emergency'];

  let mounted = $state(false);
  let lastUpdated = $state(null);
  let refreshInterval = $state(null);
  let assignmentInput = $state('');
  let updatingStatus = $state(false);
  let togglingDuty = $state(false);
  let collapsedDepts = $state({});

  let officer = $derived(mdtStore.officer);
  let units = $derived(dataStore.unitsList || []);

  let myUnit = $derived(
    units.find(u => u.callsign === officer.callsign) || null
  );

  let isOnDuty = $derived(myUnit && myUnit.status !== 'off_duty');

  let activeUnits = $derived(units.filter(u => u.status !== 'off_duty'));

  let departmentGroups = $derived(() => {
    const groups = {};
    for (const unit of units) {
      const dept = unit.department || unit.dept || 'Unknown';
      if (!groups[dept]) {
        groups[dept] = [];
      }
      groups[dept].push(unit);
    }

    for (const dept of Object.keys(groups)) {
      groups[dept].sort((a, b) => {
        const orderA = STATUS_ORDER[a.status] ?? 6;
        const orderB = STATUS_ORDER[b.status] ?? 6;
        return orderA - orderB;
      });
    }

    return Object.entries(groups).sort((a, b) => a[0].localeCompare(b[0]));
  });

  let groupedDepartments = $derived(departmentGroups());

  function formatLastUpdated() {
    if (!lastUpdated) return '';
    const h = lastUpdated.getHours().toString().padStart(2, '0');
    const m = lastUpdated.getMinutes().toString().padStart(2, '0');
    const s = lastUpdated.getSeconds().toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  }

  let lastUpdatedStr = $derived(formatLastUpdated());

  async function refreshUnits() {
    await dataStore.fetchUnits();
    lastUpdated = new Date();
  }

  async function handleStatusChange(status) {
    if (updatingStatus) return;
    updatingStatus = true;
    const resp = await dataStore.updateUnitStatus(status, assignmentInput);
    if (resp?.ok) {
      await refreshUnits();
    }
    updatingStatus = false;
  }

  async function handleAssignmentUpdate() {
    if (updatingStatus || !myUnit) return;
    updatingStatus = true;
    const resp = await dataStore.updateUnitStatus(myUnit.status, assignmentInput);
    if (resp?.ok) {
      await refreshUnits();
    }
    updatingStatus = false;
  }

  async function handleDutyToggle() {
    if (togglingDuty) return;
    togglingDuty = true;
    if (isOnDuty) {
      const resp = await dataStore.goOffDuty();
      if (resp?.ok) {
        assignmentInput = '';
        await refreshUnits();
      }
    } else {
      const resp = await dataStore.goOnDuty();
      if (resp?.ok) {
        await refreshUnits();
      }
    }
    togglingDuty = false;
  }

  function toggleDeptCollapse(dept) {
    collapsedDepts = { ...collapsedDepts, [dept]: !collapsedDepts[dept] };
  }

  function getDeptActiveCount(deptUnits) {
    return deptUnits.filter(u => u.status !== 'off_duty').length;
  }

  $effect(() => {
    if (myUnit?.assignment && !assignmentInput) {
      assignmentInput = myUnit.assignment;
    }
  });

  onMount(() => {
    mounted = true;

    if (isEnvBrowser()) {
      dataStore.unitsList = [
        { id: 1, callsign: '1-A-12', officer_id: 1, department: 'Los Santos Police Department', status: 'available', assignment: '', first_name: 'John', last_name: 'Doe', rank: 'Officer', dept: 'LSPD' },
        { id: 2, callsign: '1-A-15', officer_id: 2, department: 'Los Santos Police Department', status: 'en_route', assignment: 'Code 3 to Vespucci Beach', first_name: 'Sarah', last_name: 'Chen', rank: 'Sergeant', dept: 'LSPD' },
        { id: 3, callsign: '1-L-20', officer_id: 3, department: 'Los Santos Police Department', status: 'on_scene', assignment: 'Traffic stop — Route 68', first_name: 'Marcus', last_name: 'Rivera', rank: 'Officer', dept: 'LSPD' },
        { id: 4, callsign: '1-X-01', officer_id: 4, department: 'Los Santos Police Department', status: 'emergency', assignment: '10-99 Shots fired — Grove St', first_name: 'Alex', last_name: 'Kim', rank: 'Corporal', dept: 'LSPD' },
        { id: 5, callsign: '1-A-22', officer_id: 5, department: 'Los Santos Police Department', status: 'busy', assignment: 'Processing suspect at MRPD', first_name: 'Diana', last_name: 'Vasquez', rank: 'Officer', dept: 'LSPD' },
        { id: 6, callsign: '2-S-01', officer_id: 6, department: 'Blaine County Sheriff', status: 'available', assignment: '', first_name: 'James', last_name: 'Harper', rank: 'Deputy', dept: 'BCSO' },
        { id: 7, callsign: '2-S-05', officer_id: 7, department: 'Blaine County Sheriff', status: 'on_scene', assignment: 'Welfare check — Sandy Shores', first_name: 'Mia', last_name: 'Torres', rank: 'Senior Deputy', dept: 'BCSO' },
        { id: 8, callsign: '2-S-10', officer_id: 8, department: 'Blaine County Sheriff', status: 'en_route', assignment: 'Backup request — Paleto Bay', first_name: 'Ryan', last_name: 'Brooks', rank: 'Deputy', dept: 'BCSO' },
        { id: 9, callsign: '3-T-01', officer_id: 9, department: 'State Troopers', status: 'available', assignment: '', first_name: 'Nathan', last_name: 'Cruz', rank: 'Trooper', dept: 'SASP' },
        { id: 10, callsign: '3-T-07', officer_id: 10, department: 'State Troopers', status: 'busy', assignment: 'Speed enforcement — Great Ocean Hwy', first_name: 'Olivia', last_name: 'Nguyen', rank: 'Senior Trooper', dept: 'SASP' },
        { id: 11, callsign: '1-A-30', officer_id: 11, department: 'Los Santos Police Department', status: 'off_duty', assignment: '', first_name: 'Tyler', last_name: 'Brennan', rank: 'Detective', dept: 'LSPD' },
      ];
      lastUpdated = new Date();
    } else {
      refreshUnits();
    }

    refreshInterval = setInterval(refreshUnits, 15000);

    return () => {
      if (refreshInterval) clearInterval(refreshInterval);
    };
  });
</script>

<div class="units-page" class:mounted>
  <div class="page-header">
    <div class="header-left">
      <h1 class="page-title">Units</h1>
      <span class="page-subtitle">Live Operations</span>
    </div>
    <div class="header-right">
      {#if lastUpdatedStr}
        <span class="last-updated font-mono">
          <svg class="clock-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
          </svg>
          {lastUpdatedStr}
        </span>
      {/if}
      <span class="active-count font-mono">
        <span class="active-dot"></span>
        {activeUnits.length} ON DUTY
      </span>
      <button class="refresh-btn" onclick={refreshUnits}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="23 4 23 10 17 10" /><polyline points="1 20 1 14 7 14" />
          <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" />
        </svg>
        Refresh
      </button>
    </div>
  </div>

  <div class="my-status-panel">
    <div class="my-status-header">
      <svg class="panel-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" /><circle cx="12" cy="7" r="4" />
      </svg>
      <h2 class="panel-title">My Status</h2>
      {#if myUnit}
        <span class="my-status-badge" style="--badge-color: {STATUS_COLORS[myUnit.status]}">
          <span class="badge-dot"></span>
          {STATUS_LABELS[myUnit.status]}
        </span>
      {:else}
        <span class="my-status-badge" style="--badge-color: {STATUS_COLORS.off_duty}">
          <span class="badge-dot"></span>
          Off Duty
        </span>
      {/if}
    </div>

    <div class="my-status-body">
      <div class="officer-info">
        <div class="officer-identity">
          <span class="officer-callsign font-mono">{officer.callsign}</span>
          <span class="officer-name">{officer.rank} {officer.firstName} {officer.lastName}</span>
          <span class="officer-dept font-mono">{officer.departmentShort || officer.departmentLabel || ''}</span>
        </div>

        <button
          class="duty-btn"
          class:duty-on={isOnDuty}
          class:duty-off={!isOnDuty}
          onclick={handleDutyToggle}
          disabled={togglingDuty}
        >
          {#if isOnDuty}
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M18.36 6.64a9 9 0 11-12.73 0" /><line x1="12" y1="2" x2="12" y2="12" />
            </svg>
            Go Off Duty
          {:else}
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
            </svg>
            Go On Duty
          {/if}
        </button>
      </div>

      {#if isOnDuty}
        <div class="status-controls">
          <div class="status-buttons">
            {#each SELECTABLE_STATUSES as status (status)}
              <button
                class="status-btn"
                class:active={myUnit?.status === status}
                style="--status-color: {STATUS_COLORS[status]}"
                onclick={() => handleStatusChange(status)}
                disabled={updatingStatus}
              >
                <span class="status-btn-dot"></span>
                {STATUS_LABELS[status]}
              </button>
            {/each}
          </div>

          <div class="assignment-row">
            <div class="assignment-input-wrap">
              <svg class="assignment-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" /><circle cx="12" cy="10" r="3" />
              </svg>
              <input
                type="text"
                class="assignment-input"
                placeholder="Assignment — e.g. Traffic stop on Vespucci Blvd"
                bind:value={assignmentInput}
                onkeydown={(e) => { if (e.key === 'Enter') handleAssignmentUpdate(); }}
              />
            </div>
            <button class="assignment-btn" onclick={handleAssignmentUpdate} disabled={updatingStatus}>
              Update
            </button>
          </div>
        </div>
      {/if}
    </div>
  </div>

  <div class="units-board">
    {#if groupedDepartments.length === 0}
      <div class="empty-state">
        <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" /><circle cx="9" cy="7" r="4" />
          <path d="M23 21v-2a4 4 0 00-3-3.87" /><path d="M16 3.13a4 4 0 010 7.75" />
        </svg>
        <p class="empty-text">No units on duty</p>
        <p class="empty-sub">Units will appear here when officers go on duty</p>
      </div>
    {:else}
      {#each groupedDepartments as [deptName, deptUnits], deptIdx (deptName)}
        {@const activeCount = getDeptActiveCount(deptUnits)}
        {@const isCollapsed = collapsedDepts[deptName]}
        <div class="dept-group" style="--dept-stagger: {deptIdx}">
          <button class="dept-header" onclick={() => toggleDeptCollapse(deptName)}>
            <svg class="dept-chevron" class:collapsed={isCollapsed} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="6 9 12 15 18 9" />
            </svg>
            <span class="dept-name">{deptName}</span>
            <span class="dept-counts font-mono">
              <span class="dept-active">{activeCount}</span>
              <span class="dept-sep">/</span>
              <span class="dept-total">{deptUnits.length}</span>
            </span>
          </button>

          {#if !isCollapsed}
            <div class="dept-units-grid">
              {#each deptUnits as unit (unit.id || unit.callsign)}
                {@const statusColor = STATUS_COLORS[unit.status] || STATUS_COLORS.off_duty}
                {@const isEmergency = unit.status === 'emergency'}
                {@const isOffDuty = unit.status === 'off_duty'}
                <div
                  class="unit-card"
                  class:emergency={isEmergency}
                  class:off-duty={isOffDuty}
                  style="--unit-color: {statusColor}"
                >
                  <div class="unit-card-top">
                    <span class="unit-callsign font-mono">{unit.callsign}</span>
                    <span class="unit-status-badge" style="--badge-color: {statusColor}">
                      {#if isEmergency}
                        <span class="emergency-pulse"></span>
                      {/if}
                      <span class="unit-status-dot"></span>
                      {STATUS_LABELS[unit.status] || unit.status}
                    </span>
                  </div>

                  <div class="unit-card-body">
                    <span class="unit-officer-name">{unit.first_name} {unit.last_name}</span>
                    <span class="unit-officer-rank">{unit.rank}</span>
                  </div>

                  {#if unit.assignment}
                    <div class="unit-assignment">
                      <svg class="unit-assignment-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" /><circle cx="12" cy="10" r="3" />
                      </svg>
                      <span class="unit-assignment-text">{unit.assignment}</span>
                    </div>
                  {/if}
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .units-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    opacity: 0;
    transform: translateY(calc(8px * var(--mdt-scale)));
    height: 100%;
    overflow-y: auto;
  }

  .units-page.mounted {
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .header-left {
    display: flex;
    align-items: baseline;
    gap: calc(10px * var(--mdt-scale));
  }

  .page-title {
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
  }

  .page-subtitle {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-weight: 400;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .last-updated {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .clock-icon {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
    opacity: 0.6;
  }

  .active-count {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-success);
    letter-spacing: 0.08em;
    font-weight: 600;
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: rgba(52, 211, 153, 0.08);
    border: 1px solid rgba(52, 211, 153, 0.15);
    border-radius: calc(20px * var(--mdt-scale));
  }

  .active-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-success);
    box-shadow: 0 0 calc(5px * var(--mdt-scale)) rgba(52, 211, 153, 0.5);
    animation: pulseDot 2s ease-in-out infinite;
  }

  .refresh-btn {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease, transform 0.1s ease;
  }

  .refresh-btn svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .refresh-btn:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .refresh-btn:active {
    transform: scale(0.96);
  }

  .my-status-panel {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg, var(--mdt-radius));
    padding: calc(18px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
    position: relative;
    overflow: hidden;
  }

  .my-status-panel::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: calc(2px * var(--mdt-scale));
    background: linear-gradient(90deg, var(--mdt-accent) 0%, transparent 100%);
    opacity: 0.5;
  }

  .my-status-header {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .panel-icon {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .panel-title {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.01em;
  }

  .my-status-badge {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(3px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(20px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--badge-color);
    background: color-mix(in srgb, var(--badge-color) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--badge-color) 20%, transparent);
  }

  .badge-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--badge-color);
  }

  .my-status-body {
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
  }

  .officer-info {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
  }

  .officer-identity {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
  }

  .officer-callsign {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    letter-spacing: 0.04em;
  }

  .officer-name {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .officer-dept {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  .duty-btn {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: none;
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .duty-btn svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .duty-btn:active {
    transform: scale(0.96);
  }

  .duty-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .duty-btn.duty-on {
    background: rgba(107, 114, 128, 0.15);
    color: #9ca3af;
    border: 1px solid rgba(107, 114, 128, 0.25);
  }

  .duty-btn.duty-on:hover {
    background: rgba(107, 114, 128, 0.25);
  }

  .duty-btn.duty-off {
    background: rgba(52, 211, 153, 0.15);
    color: #34d399;
    border: 1px solid rgba(52, 211, 153, 0.25);
  }

  .duty-btn.duty-off:hover {
    background: rgba(52, 211, 153, 0.25);
  }

  .status-controls {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    animation: slideDown 0.25s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .status-buttons {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .status-btn {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: calc(20px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .status-btn:hover {
    border-color: color-mix(in srgb, var(--status-color) 40%, transparent);
    background: color-mix(in srgb, var(--status-color) 8%, transparent);
    color: var(--status-color);
  }

  .status-btn:active {
    transform: scale(0.95);
  }

  .status-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .status-btn.active {
    border-color: color-mix(in srgb, var(--status-color) 50%, transparent);
    background: color-mix(in srgb, var(--status-color) 15%, transparent);
    color: var(--status-color);
    box-shadow: 0 0 calc(8px * var(--mdt-scale)) color-mix(in srgb, var(--status-color) 20%, transparent);
  }

  .status-btn-dot {
    width: calc(7px * var(--mdt-scale));
    height: calc(7px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--status-color);
    opacity: 0.5;
    transition: opacity 0.15s ease;
  }

  .status-btn.active .status-btn-dot {
    opacity: 1;
    box-shadow: 0 0 calc(4px * var(--mdt-scale)) var(--status-color);
  }

  .assignment-row {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
  }

  .assignment-input-wrap {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
  }

  .assignment-icon {
    position: absolute;
    left: calc(10px * var(--mdt-scale));
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    pointer-events: none;
  }

  .assignment-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) calc(30px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .assignment-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .assignment-input:focus {
    border-color: var(--mdt-accent);
  }

  .assignment-btn {
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
    white-space: nowrap;
  }

  .assignment-btn:hover {
    opacity: 0.9;
  }

  .assignment-btn:active {
    transform: scale(0.96);
  }

  .assignment-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .units-board {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: calc(60px * var(--mdt-scale)) 0;
    gap: calc(10px * var(--mdt-scale));
    opacity: 0.5;
  }

  .empty-icon {
    width: calc(48px * var(--mdt-scale));
    height: calc(48px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .empty-text {
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
  }

  .empty-sub {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .dept-group {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--dept-stagger) * 50ms);
    opacity: 0;
    transform: translateY(calc(6px * var(--mdt-scale)));
  }

  .dept-header {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    width: 100%;
    cursor: pointer;
    font-family: 'Outfit', sans-serif;
    transition: background 0.12s ease;
  }

  .dept-header:hover {
    background: var(--mdt-surface-3);
  }

  .dept-chevron {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    flex-shrink: 0;
  }

  .dept-chevron.collapsed {
    transform: rotate(-90deg);
  }

  .dept-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.01em;
  }

  .dept-counts {
    margin-left: auto;
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.04em;
    display: flex;
    align-items: center;
    gap: calc(2px * var(--mdt-scale));
  }

  .dept-active {
    color: var(--mdt-success);
    font-weight: 600;
  }

  .dept-sep {
    color: var(--mdt-text-muted);
  }

  .dept-total {
    color: var(--mdt-text-muted);
  }

  .dept-units-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(280px * var(--mdt-scale)), 1fr));
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale));
  }

  .unit-card {
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    padding: calc(12px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    position: relative;
    overflow: hidden;
    transition: border-color 0.2s ease, box-shadow 0.2s ease;
  }

  .unit-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    width: calc(3px * var(--mdt-scale));
    height: 100%;
    background: var(--unit-color);
    opacity: 0.6;
  }

  .unit-card:hover {
    border-color: color-mix(in srgb, var(--unit-color) 30%, var(--mdt-border));
  }

  .unit-card.emergency {
    border-color: rgba(248, 113, 113, 0.3);
    box-shadow: 0 0 calc(12px * var(--mdt-scale)) rgba(248, 113, 113, 0.08);
    animation: emergencyPulse 2s ease-in-out infinite;
  }

  .unit-card.off-duty {
    opacity: 0.45;
  }

  .unit-card.off-duty:hover {
    opacity: 0.6;
  }

  .unit-card-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .unit-callsign {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: 0.04em;
  }

  .unit-status-badge {
    display: flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(20px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--badge-color);
    background: color-mix(in srgb, var(--badge-color) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--badge-color) 20%, transparent);
    position: relative;
  }

  .unit-status-dot {
    width: calc(5px * var(--mdt-scale));
    height: calc(5px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--badge-color);
    flex-shrink: 0;
    position: relative;
    z-index: 1;
  }

  .emergency-pulse {
    position: absolute;
    top: 50%;
    left: calc(8px * var(--mdt-scale));
    width: calc(9px * var(--mdt-scale));
    height: calc(9px * var(--mdt-scale));
    border-radius: 50%;
    background: rgba(248, 113, 113, 0.4);
    transform: translate(0, -50%);
    animation: emergencyPulseDot 1.5s ease-in-out infinite;
  }

  .unit-card-body {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .unit-officer-name {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .unit-officer-rank {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-weight: 500;
  }

  .unit-assignment {
    display: flex;
    align-items: flex-start;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    background: color-mix(in srgb, var(--mdt-surface-3) 60%, transparent);
    border-radius: calc(4px * var(--mdt-scale));
    border-left: calc(2px * var(--mdt-scale)) solid var(--unit-color);
  }

  .unit-assignment-icon {
    width: calc(11px * var(--mdt-scale));
    height: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    margin-top: calc(1px * var(--mdt-scale));
  }

  .unit-assignment-text {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.4;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(calc(8px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes cardIn {
    from {
      opacity: 0;
      transform: translateY(calc(6px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes slideDown {
    from {
      opacity: 0;
      transform: translateY(calc(-4px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes pulseDot {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  @keyframes emergencyPulse {
    0%, 100% {
      border-color: rgba(248, 113, 113, 0.3);
      box-shadow: 0 0 calc(12px * var(--mdt-scale)) rgba(248, 113, 113, 0.08);
    }
    50% {
      border-color: rgba(248, 113, 113, 0.55);
      box-shadow: 0 0 calc(18px * var(--mdt-scale)) rgba(248, 113, 113, 0.18);
    }
  }

  @keyframes emergencyPulseDot {
    0%, 100% {
      transform: translate(0, -50%) scale(1);
      opacity: 0.4;
    }
    50% {
      transform: translate(0, -50%) scale(1.8);
      opacity: 0;
    }
  }
</style>
