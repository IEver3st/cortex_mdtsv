<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { findUnitForOfficer } from '../lib/utils/helpers.js';
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

  let mounted = $state(false);
  let lastUpdated = $state(null);
  let refreshInterval = $state(null);
  let togglingDuty = $state(false);
  let collapsedDepts = $state({});

  let officer = $derived(mdtStore.officer);
  let units = $derived(dataStore.unitsList || []);

  let myUnit = $derived(findUnitForOfficer(units, officer));

  let isOnDuty = $derived(myUnit && myUnit.status !== 'off_duty');

  let departmentGroups = $derived.by(() => {
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

  let groupedDepartments = $derived(departmentGroups);

  function streetCell(unit) {
    const s = (unit.locationStreet || '').trim();
    return s || '—';
  }

  function areaCell(unit) {
    const a = (unit.mapArea || '').trim();
    return a || '—';
  }

  function formatLastUpdated() {
    if (!lastUpdated) return '';
    const h = lastUpdated.getHours().toString().padStart(2, '0');
    const m = lastUpdated.getMinutes().toString().padStart(2, '0');
    const s = lastUpdated.getSeconds().toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  }

  let lastUpdatedStr = $derived(formatLastUpdated());

  async function refreshUnits() {
    const resp = await dataStore.fetchUnits();
    if (resp?.ok) {
      lastUpdated = new Date();
    }
    return resp;
  }

  async function handleDutyToggle() {
    if (togglingDuty) return;
    togglingDuty = true;
    try {
      if (isOnDuty) {
        const resp = await dataStore.goOffDuty();
        if (resp?.ok) {
          lastUpdated = new Date();
        } else if (resp?.error) {
          console.error('[cortex_mdtsv] goOffDuty failed:', resp.error);
        }
      } else {
        const resp = await dataStore.goOnDuty();
        if (resp?.ok) {
          lastUpdated = new Date();
        } else if (resp?.error) {
          console.error('[cortex_mdtsv] goOnDuty failed:', resp.error);
        }
      }
    } finally {
      togglingDuty = false;
    }
  }

  function toggleDeptCollapse(dept) {
    collapsedDepts = { ...collapsedDepts, [dept]: !collapsedDepts[dept] };
  }

  function getDeptActiveCount(deptUnits) {
    return deptUnits.filter((u) => u.status !== 'off_duty').length;
  }

  onMount(() => {
    mounted = true;

    if (isEnvBrowser()) {
      dataStore.unitsList = [
        { id: 1, callsign: '1-A-12', officer_id: 1, department: 'Los Santos Police Department', status: 'available', assignment: 'Patrol — Central', first_name: 'John', last_name: 'Doe', rank: 'Officer', avatar: '', dept: 'LSPD', locationStreet: 'Integrity Way / Strawberry Ave', mapArea: 'Downtown' },
        { id: 2, callsign: '1-A-15', officer_id: 2, department: 'Los Santos Police Department', status: 'en_route', assignment: 'Code 3 — Vespucci Beach', first_name: 'Sarah', last_name: 'Chen', rank: 'Sergeant', avatar: '', dept: 'LSPD', locationStreet: 'Bay City Ave / Aguja St', mapArea: 'Vespucci' },
        { id: 3, callsign: '1-L-20', officer_id: 3, department: 'Los Santos Police Department', status: 'on_scene', assignment: 'Traffic stop — Route 68', first_name: 'Marcus', last_name: 'Rivera', rank: 'Officer', avatar: '', dept: 'LSPD', locationStreet: 'Route 68', mapArea: 'Grand Senora Desert' },
        { id: 4, callsign: '1-X-01', officer_id: 4, department: 'Los Santos Police Department', status: 'emergency', assignment: '10-99 — Grove St', first_name: 'Alex', last_name: 'Kim', rank: 'Corporal', avatar: '', dept: 'LSPD', locationStreet: 'Grove Street', mapArea: 'Davis' },
        { id: 5, callsign: '1-A-22', officer_id: 5, department: 'Los Santos Police Department', status: 'busy', assignment: 'Processing — MRPD', first_name: 'Diana', last_name: 'Vasquez', rank: 'Officer', avatar: '', dept: 'LSPD', locationStreet: 'Sinner Street', mapArea: 'Mission Row' },
        { id: 6, callsign: '2-S-01', officer_id: 6, department: 'Blaine County Sheriff', status: 'available', assignment: '', first_name: 'James', last_name: 'Harper', rank: 'Deputy', avatar: '', dept: 'BCSO', locationStreet: 'Paleto Blvd', mapArea: 'Paleto Bay' },
        { id: 7, callsign: '2-S-05', officer_id: 7, department: 'Blaine County Sheriff', status: 'on_scene', assignment: 'Welfare check', first_name: 'Mia', last_name: 'Torres', rank: 'Senior Deputy', avatar: '', dept: 'BCSO', locationStreet: 'Zancudo Ave', mapArea: 'Sandy Shores' },
        { id: 8, callsign: '2-S-10', officer_id: 8, department: 'Blaine County Sheriff', status: 'en_route', assignment: 'Backup — Paleto', first_name: 'Ryan', last_name: 'Brooks', rank: 'Deputy', avatar: '', dept: 'BCSO', locationStreet: 'Great Ocean Hwy', mapArea: 'Mount Chiliad' },
        { id: 9, callsign: '3-T-01', officer_id: 9, department: 'State Troopers', status: 'available', assignment: '', first_name: 'Nathan', last_name: 'Cruz', rank: 'Trooper', avatar: '', dept: 'SASP', locationStreet: 'Senora Fwy', mapArea: 'Grand Senora Desert' },
        { id: 10, callsign: '3-T-07', officer_id: 10, department: 'State Troopers', status: 'busy', assignment: 'Speed enforcement', first_name: 'Olivia', last_name: 'Nguyen', rank: 'Senior Trooper', avatar: '', dept: 'SASP', locationStreet: 'Great Ocean Hwy', mapArea: 'Banham Canyon' },
        { id: 11, callsign: '1-A-30', officer_id: 11, department: 'Los Santos Police Department', status: 'off_duty', assignment: '', first_name: 'Tyler', last_name: 'Brennan', rank: 'Detective', avatar: '', dept: 'LSPD', locationStreet: '—', mapArea: '—' },
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
  <header class="u-top">
    <div class="u-top__left">
      <h2 class="u-top__title">Units</h2>
      <p class="u-top__sub">Live field roster — grouped by department</p>
    </div>
    <div class="u-top__right">
      {#if lastUpdatedStr}
        <div class="u-kpi font-mono" title="Last refresh (local)">
          <span class="u-kpi__label">Updated</span>
          <span class="u-kpi__sep" aria-hidden="true">·</span>
          <span class="u-kpi__val">{lastUpdatedStr}</span>
        </div>
      {/if}
      <button type="button" class="u-btn u-btn--ghost u-refresh" onclick={refreshUnits} aria-label="Refresh unit list">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <polyline points="23 4 23 10 17 10" /><polyline points="1 20 1 14 7 14" />
          <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15" />
        </svg>
      </button>
    </div>
  </header>

  <section class="u-me" aria-label="My unit">
    <div class="u-me__band">
      <span class="u-kicker">You</span>
      <p class="u-me__hint">Your callsign, roster line, and duty toggle</p>
    </div>
    <div class="u-rule" aria-hidden="true"></div>

    <div class="u-me__grid">
      <div class="u-me__cell">
        <span class="u-lbl">Callsign & identity</span>
        <div class="u-me__panel" aria-label="Callsign and identity" style="--panel-accent: var(--mdt-accent)">
          <span class="u-me__panel-accent" aria-hidden="true"></span>
          <div class="u-me__panel-body">
            <p class="u-me__primary font-mono">{officer.callsign}</p>
            <p class="u-me__secondary">{officer.rank} {officer.firstName} {officer.lastName}</p>
            <p class="u-me__tertiary font-mono">
              {officer.departmentShort || officer.departmentLabel || '—'}
            </p>
          </div>
        </div>
      </div>
      <div class="u-me__cell">
        <span class="u-lbl">Roster status</span>
        <div
          class="u-me__panel"
          role="status"
          aria-live="polite"
          style="--panel-accent: {myUnit ? (STATUS_COLORS[myUnit.status] || STATUS_COLORS.off_duty) : STATUS_COLORS.off_duty}"
        >
          <span class="u-me__panel-accent" aria-hidden="true"></span>
          <div class="u-me__panel-body">
            {#if myUnit}
              {@const isEmergency = myUnit.status === 'emergency'}
              {@const statusColor = STATUS_COLORS[myUnit.status] || STATUS_COLORS.off_duty}
              <div class="u-me__primary-row">
                <span class="u-stat u-stat--me font-mono" class:u-stat--emg={isEmergency} style="--st: {statusColor}">
                  {#if isEmergency}
                    <span class="u-stat__flag" title="Priority">911</span>
                  {/if}
                  {STATUS_LABELS[myUnit.status] ?? myUnit.status}
                </span>
              </div>
              <p class="u-me__secondary u-me__secondary--clip" title={myUnit.assignment || 'No assignment'}>
                {(myUnit.assignment || '').trim() || 'No active assignment'}
              </p>
              <p class="u-me__tertiary font-mono">Roster line active</p>
            {:else}
              <div class="u-me__primary-row">
                <span class="u-stat u-stat--me u-stat--muted font-mono" style="--st: {STATUS_COLORS.off_duty}">Not on roster</span>
              </div>
              <p class="u-me__secondary">Clock in to appear on the wire</p>
              <p class="u-me__tertiary font-mono">Off roster</p>
            {/if}
          </div>
        </div>
      </div>
      <div class="u-me__cell">
        <span class="u-lbl">Duty</span>
        <div
          class="u-me__panel u-me__panel--duty"
          class:u-me__panel--duty-on={isOnDuty}
          class:u-me__panel--duty-off={!isOnDuty}
          style="--panel-accent: {isOnDuty ? 'var(--mdt-text-dim)' : 'var(--mdt-success)'}"
        >
          <span class="u-me__panel-accent" aria-hidden="true"></span>
          <div class="u-me__panel-body">
            <p class="u-me__primary">{isOnDuty ? 'On duty' : 'Off duty'}</p>
            <p class="u-me__secondary">
              {isOnDuty ? 'Listed on active roster' : 'Not broadcasting on roster'}
            </p>
            <button
              type="button"
              class="u-btn u-me__panel-action"
              class:u-me__panel-action--on={isOnDuty}
              class:u-me__panel-action--off={!isOnDuty}
              onclick={handleDutyToggle}
              disabled={togglingDuty}
            >
              {#if isOnDuty}
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <path d="M18.36 6.64a9 9 0 11-12.73 0" /><line x1="12" y1="2" x2="12" y2="12" />
                </svg>
                <span>Clock out</span>
              {:else}
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
                </svg>
                <span>Clock in</span>
              {/if}
            </button>
          </div>
        </div>
      </div>
    </div>
  </section>

  <section class="u-roster" aria-label="All units">
    {#if groupedDepartments.length === 0}
      <div class="u-empty">
        <div class="u-empty__frame">
          <svg class="u-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
          </svg>
        </div>
        <h3 class="u-empty__title">No units on the wire</h3>
        <p class="u-empty__text">Roster is empty. Units appear here when officers are loaded from the server.</p>
        <button type="button" class="u-btn u-btn--accent u-empty__btn" onclick={refreshUnits}>
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <polyline points="23 4 23 10 17 10" /><path d="M20.49 15a9 9 0 11-3-6.11L23 10" />
          </svg>
          Try refresh
        </button>
      </div>
    {:else}
      {#each groupedDepartments as [deptName, deptUnits], deptIdx (deptName)}
        {@const activeCount = getDeptActiveCount(deptUnits)}
        {@const isCollapsed = collapsedDepts[deptName]}
        <div class="u-dept-wrap" style="--dly: {deptIdx * 24}ms">
          <button type="button" class="u-btn u-btn--bare u-dept__bar" onclick={() => toggleDeptCollapse(deptName)}>
            <span class="u-dept__chev" class:u-dept__chev--collapsed={isCollapsed} aria-hidden="true">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="6 9 12 15 18 9" />
              </svg>
            </span>
            <span class="u-dept__name">{deptName}</span>
            <span class="u-dept__stat font-mono" title="On duty / total"
              ><span class="u-dept__n u-dept__n--on">{activeCount}</span><span class="u-dept__sep">/</span><span class="u-dept__n">{deptUnits.length}</span></span
            >
          </button>

          {#if !isCollapsed}
            <div class="u-table" role="table" aria-label={`Units in ${deptName}`}>
              <div class="u-table__head font-mono" role="row">
                <span role="columnheader">Call</span>
                <span role="columnheader">Officer</span>
                <span role="columnheader">Rank</span>
                <span role="columnheader">Status</span>
                <span role="columnheader">Street</span>
                <span role="columnheader">Zone</span>
                <span role="columnheader">Assignment</span>
              </div>
              <div class="u-table__body" role="rowgroup">
                {#each deptUnits as unit, rowIdx (unit.id || unit.callsign)}
                  {@const statusColor = STATUS_COLORS[unit.status] || STATUS_COLORS.off_duty}
                  {@const isEmergency = unit.status === 'emergency'}
                  {@const isOffDuty = unit.status === 'off_duty'}
                  <div
                    class="u-row font-mono"
                    class:u-row--emg={isEmergency}
                    class:u-row--off={isOffDuty}
                    class:u-row--alt={rowIdx % 2 === 1}
                    style="--row-c: {statusColor}"
                    role="row"
                  >
                    <span class="u-cell u-cell--call" role="cell">{unit.callsign}</span>
                    <span class="u-cell u-cell--name" role="cell">{unit.first_name} {unit.last_name}</span>
                    <span class="u-cell u-cell--dim" role="cell">{unit.rank}</span>
                    <span class="u-cell" role="cell">
                      <span class="u-stat" class:u-stat--emg={isEmergency} style="--st: {statusColor}">
                        {#if isEmergency}
                          <span class="u-stat__flag" title="Priority">911</span>
                        {/if}
                        {STATUS_LABELS[unit.status] || unit.status}
                      </span>
                    </span>
                    <span class="u-cell u-cell--dim" title={streetCell(unit)} role="cell">{streetCell(unit)}</span>
                    <span class="u-cell u-cell--dim" title={areaCell(unit)} role="cell">{areaCell(unit)}</span>
                    <span class="u-cell u-cell--asg" title={unit.assignment || ''} role="cell">{unit.assignment || '—'}</span>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>
      {/each}
    {/if}
  </section>
</div>

<style>
  .units-page {
    --u-line: 1px solid color-mix(in srgb, var(--mdt-border) 88%, var(--mdt-text) 10%);
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    height: 100%;
    min-height: 0;
    overflow: hidden;
    opacity: 0;
    transform: translateY(calc(6px * var(--mdt-scale)));
  }

  .units-page.mounted {
    animation: uFade 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .font-mono {
    font-family: 'Share Tech Mono', ui-monospace, monospace;
    font-variant-numeric: tabular-nums;
  }

  /* —— Top —— */
  .u-top {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .u-top__title {
    margin: 0;
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.02em;
    font-family: 'Outfit', sans-serif;
  }

  .u-top__sub {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-weight: 500;
    max-width: 42ch;
  }

  .u-top__right {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .u-kpi {
    display: inline-flex;
    flex-direction: row;
    align-items: center;
    justify-content: flex-end;
    gap: calc(5px * var(--mdt-scale));
    margin: 0;
    padding: 0;
    background: transparent;
    border: none;
    box-sizing: border-box;
    line-height: 1.2;
  }

  .u-kpi__label {
    font-size: calc(8px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--mdt-text-muted);
  }

  .u-kpi__sep {
    color: var(--mdt-text-muted);
    opacity: 0.45;
    font-weight: 400;
  }

  .u-kpi__val {
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.2;
    color: var(--mdt-text);
    letter-spacing: 0.04em;
  }

  /* Shared button chrome — rect, slight radius */
  .u-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    box-sizing: border-box;
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.03em;
    border-radius: var(--mdt-radius);
    cursor: pointer;
    border: 1px solid transparent;
    transition:
      background 0.12s ease,
      color 0.12s ease,
      border-color 0.12s ease,
      opacity 0.12s ease,
      transform 0.1s ease,
      filter 0.12s ease;
  }

  .u-btn:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--mdt-accent) 55%, transparent);
    outline-offset: 2px;
  }

  .u-btn:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .u-btn:active:not(:disabled) {
    transform: scale(0.99);
  }

  .u-btn--ghost {
    color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-surface) 55%, transparent);
    border-color: color-mix(in srgb, var(--mdt-border) 82%, var(--mdt-accent) 18%);
  }

  .u-btn--ghost:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-text) 7%, transparent);
  }

  .u-btn--accent {
    color: var(--mdt-bg);
    background: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 50%, #000);
  }

  .u-btn--accent:hover:not(:disabled) {
    filter: brightness(1.06);
  }

  .u-btn--bare {
    width: 100%;
    border-radius: 0;
    border-color: transparent;
    font-family: 'Outfit', sans-serif;
    text-align: left;
    justify-content: flex-start;
  }

  /* —— “You” — unified panel row —— */
  .u-rule {
    display: block;
    height: 0;
    margin: 0;
    border: 0;
    border-top: var(--u-line);
  }

  .u-me {
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    gap: 0;
    padding-bottom: calc(4px * var(--mdt-scale));
  }

  .u-me__band {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    padding: 0 0 calc(12px * var(--mdt-scale));
  }

  .u-me__hint {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.35;
    color: var(--mdt-text-muted);
    font-weight: 500;
    max-width: 48ch;
  }

  .u-kicker {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .u-me__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) 0 0;
  }

  .u-me__cell {
    min-width: 0;
    padding: 0;
  }

  @media (min-width: 900px) {
    .u-me__grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 0;
      padding-top: calc(12px * var(--mdt-scale));
    }

    .u-me__cell:not(:first-child) {
      padding-left: calc(18px * var(--mdt-scale));
      border-left: var(--u-line);
    }
  }

  .u-lbl {
    display: block;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--mdt-text-muted);
    margin-bottom: calc(8px * var(--mdt-scale));
  }

  /* Unified “You” row — shared layout, no card shell */
  .u-me__panel {
    --panel-accent: var(--mdt-accent);
    display: flex;
    align-items: stretch;
    gap: calc(10px * var(--mdt-scale));
    min-width: 0;
    padding: 0;
    box-sizing: border-box;
    background: transparent;
    border: none;
    border-radius: 0;
  }

  .u-me__panel-accent {
    flex-shrink: 0;
    width: calc(3px * var(--mdt-scale));
    border-radius: 1px;
    background: var(--panel-accent);
    box-shadow: 0 0 calc(10px * var(--mdt-scale)) color-mix(in srgb, var(--panel-accent) 38%, transparent);
  }

  .u-me__panel-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    justify-content: flex-start;
  }

  .u-me__primary-row {
    display: flex;
    align-items: center;
    min-height: calc(22px * var(--mdt-scale));
    margin-bottom: calc(2px * var(--mdt-scale));
  }

  .u-me__primary {
    margin: 0 0 calc(2px * var(--mdt-scale));
    padding: 0 0 calc(8px * var(--mdt-scale));
    border-bottom: var(--u-line);
    font-family: 'Share Tech Mono', ui-monospace, monospace;
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--panel-accent, var(--mdt-accent));
    line-height: 1.2;
    font-variant-numeric: tabular-nums;
  }

  .u-me__panel--duty .u-me__primary {
    font-family: 'Outfit', sans-serif;
    font-size: calc(14px * var(--mdt-scale));
    letter-spacing: 0.02em;
    text-transform: none;
    color: var(--mdt-text);
  }

  .u-me__secondary {
    margin: 0;
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    line-height: 1.35;
  }

  .u-me__secondary--clip {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .u-me__tertiary {
    margin: 0;
    margin-top: auto;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.14em;
    line-height: 1.35;
  }

  .u-me__panel--duty .u-me__panel-body {
    gap: calc(6px * var(--mdt-scale));
  }

  .u-me__panel-action {
    width: 100%;
    margin-top: auto;
    min-height: calc(34px * var(--mdt-scale));
    padding: 0 calc(12px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
  }

  .u-me__panel-action svg {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .u-me__panel-action--on {
    background: var(--mdt-surface-3);
    color: var(--mdt-text-dim);
    border-color: var(--mdt-border);
  }

  .u-me__panel-action--on:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-text) 8%, var(--mdt-surface-3));
    color: var(--mdt-text);
  }

  .u-me__panel-action--off {
    background: color-mix(in srgb, var(--mdt-success) 12%, var(--mdt-surface-2));
    color: var(--mdt-success);
    border-color: color-mix(in srgb, var(--mdt-success) 35%, var(--mdt-border));
  }

  .u-me__panel-action--off:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-success) 18%, var(--mdt-surface-2));
  }

  /* —— Roster —— */
  .u-roster {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    gap: 0;
    overflow-y: auto;
    padding: calc(12px * var(--mdt-scale)) calc(4px * var(--mdt-scale)) 0 0;
    border-top: var(--u-line);
  }

  .u-empty {
    flex: 1;
    min-height: calc(200px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(28px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
  }

  .u-empty__frame {
    width: calc(48px * var(--mdt-scale));
    height: calc(48px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--mdt-text-muted);
    margin-bottom: calc(2px * var(--mdt-scale));
    border: var(--u-line);
    border-radius: var(--mdt-radius);
    background: color-mix(in srgb, var(--mdt-text) 3%, transparent);
  }

  .u-empty__icon {
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
  }

  .u-empty__title {
    margin: 0;
    font-family: 'Outfit', sans-serif;
    font-size: calc(16px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .u-empty__text {
    margin: 0;
    max-width: 36ch;
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.5;
    color: var(--mdt-text-muted);
  }

  .u-empty__btn {
    margin-top: calc(6px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
  }

  .u-dept-wrap {
    flex-shrink: 0;
    border-top: var(--u-line);
    overflow: hidden;
    animation: uCard 0.36s cubic-bezier(0.16, 1, 0.3, 1) both;
    animation-delay: var(--dly, 0ms);
  }

  .u-roster > .u-dept-wrap:first-child {
    border-top: none;
  }

  .u-dept-wrap:last-child {
    border-bottom: var(--u-line);
  }

  .u-dept__bar {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    background: transparent;
    border: none;
    border-bottom: var(--u-line);
    color: var(--mdt-text);
  }

  .u-dept__bar:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-text) 4%, transparent);
  }

  .u-dept__chev {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .u-dept__chev--collapsed {
    transform: rotate(-90deg);
  }

  .u-dept__name {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--mdt-text-dim);
    min-width: 0;
  }

  .u-dept__stat {
    margin-left: auto;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .u-dept__n--on {
    color: var(--mdt-success);
    font-weight: 600;
  }

  .u-dept__sep {
    margin: 0 2px;
    opacity: 0.45;
  }

  .u-row {
    display: grid;
    grid-template-columns:
      minmax(52px, 0.5fr)
      minmax(72px, 1.1fr)
      minmax(64px, 0.5fr)
      minmax(100px, 0.7fr)
      minmax(88px, 1.2fr)
      minmax(56px, 0.55fr)
      minmax(80px, 1.1fr);
    gap: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    align-items: center;
  }

  .u-table__head {
    font-size: calc(9px * var(--mdt-scale));
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--mdt-text-muted);
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: color-mix(in srgb, #000 22%, var(--mdt-surface-2));
  }

  .u-table__body {
    display: flex;
    flex-direction: column;
  }

  .u-row {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    position: relative;
    border-bottom: 1px solid var(--mdt-border);
    transition: background 0.1s ease;
  }

  .u-row::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3px;
    background: var(--row-c);
    opacity: 0.6;
  }

  .u-row--alt {
    background: color-mix(in srgb, var(--mdt-text) 1.4%, transparent);
  }

  .u-row:hover {
    background: color-mix(in srgb, var(--mdt-text) 3.5%, transparent);
  }

  .u-row--off {
    opacity: 0.4;
  }

  .u-row--emg {
    animation: uEmg 2.2s ease-in-out infinite;
  }

  .u-cell {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .u-cell--call {
    font-weight: 700;
    color: var(--mdt-text);
  }

  .u-cell--name {
    color: var(--mdt-text);
    font-weight: 500;
  }

  .u-cell--dim {
    color: var(--mdt-text-dim);
    font-size: calc(9px * var(--mdt-scale));
  }

  .u-cell--asg {
    color: var(--mdt-text-muted);
    font-size: calc(9px * var(--mdt-scale));
  }

  .u-stat {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    max-width: 100%;
    padding: calc(3px * var(--mdt-scale)) calc(6px * var(--mdt-scale)) calc(3px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    line-height: 1.2;
    text-transform: none;
    letter-spacing: 0.04em;
    color: var(--st);
    border: 1px solid color-mix(in srgb, var(--st) 28%, var(--mdt-border));
    background: color-mix(in srgb, var(--st) 7%, var(--mdt-surface-2));
    border-radius: var(--mdt-radius-sm);
  }

  .u-stat--me {
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(5px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    letter-spacing: 0.05em;
  }

  .u-stat--muted {
    color: var(--mdt-text-muted);
    border-color: var(--mdt-border);
    background: color-mix(in srgb, var(--mdt-text) 3%, transparent);
  }

  .u-stat--emg {
    box-shadow: 0 0 0 1px color-mix(in srgb, var(--mdt-error) 32%, transparent);
  }

  .u-stat__flag {
    flex-shrink: 0;
    min-width: calc(22px * var(--mdt-scale));
    padding: 0 1px;
    text-align: center;
    font-size: calc(8px * var(--mdt-scale));
    font-weight: 800;
    line-height: calc(14px * var(--mdt-scale));
    color: var(--mdt-bg);
    background: var(--mdt-error);
    border-radius: 1px;
    letter-spacing: 0.04em;
    animation: uEmgF 1.4s ease-in-out infinite;
  }

  @keyframes uFade {
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes uCard {
    from {
      opacity: 0;
      transform: translateY(6px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes uEmg {
    0%,
    100% {
      background: color-mix(in srgb, var(--mdt-error) 4%, transparent);
    }
    50% {
      background: color-mix(in srgb, var(--mdt-error) 10%, transparent);
    }
  }

  @keyframes uEmgF {
    0%,
    100% {
      filter: brightness(1);
    }
    50% {
      filter: brightness(0.9);
    }
  }
</style>
