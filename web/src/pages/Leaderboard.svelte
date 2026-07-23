<script>
  import { onMount } from 'svelte';
  import { Trophy, FileText, ShieldAlert, Activity, RefreshCw, Info } from '@lucide/svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';

  let loading = $state(true);
  let errorMessage = $state('');
  let period = $state('week');

  let leaderboard = $derived(dataStore.leaderboardData || {
    summary: {},
    categories: { arrests: [], reports: [], activity: [] },
    generatedAt: null,
    period: 'week',
  });

  let summary = $derived(leaderboard.summary || {});
  let reportLeaders = $derived(leaderboard.categories?.reports || []);
  let arrestLeaders = $derived(leaderboard.categories?.arrests || []);
  let activityLeaders = $derived(leaderboard.categories?.activity || []);

  let periodLabel = $derived(
    period === 'all' ? 'All time' : period === 'month' ? 'Last 30 days' : 'Last 7 days',
  );

  let hasAnyBoard = $derived(
    reportLeaders.length > 0 || arrestLeaders.length > 0 || activityLeaders.length > 0,
  );

  let maxReports = $derived(Math.max(1, ...reportLeaders.map((r) => Number(r.reports_count ?? r.report_count ?? 0) || 0)));
  let maxArrests = $derived(Math.max(1, ...arrestLeaders.map((r) => Number(r.arrests_count ?? r.arrest_count ?? 0) || 0)));
  let maxActivity = $derived(Math.max(1, ...activityLeaders.map((r) => Number(r.activity_score ?? 0) || 0)));

  function fullName(row) {
    return row?.name || `${row?.first_name || ''} ${row?.last_name || ''}`.trim() || 'Unknown Officer';
  }

  function departmentLabel(value) {
    return String(value || 'police').toUpperCase();
  }

  function officerKey(row, index) {
    return row.officer_id ?? row.id ?? `${index}-${fullName(row)}`;
  }

  function initials(name) {
    const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) return '?';
    const a = parts[0][0] || '';
    const b = parts.length > 1 ? parts[parts.length - 1][0] || '' : parts[0][1] || '';
    return (a + b).toUpperCase().slice(0, 2);
  }

  function tintClass(row, index) {
    const raw = String(row?.officer_id ?? row?.id ?? index);
    let h = 0;
    for (let i = 0; i < raw.length; i += 1) h = (h + raw.charCodeAt(i) * (i + 11)) % 360;
    return `tint-${h % 5}`;
  }

  function formatStamp(value) {
    if (!value) return 'Unavailable';
    try {
      return new Date(value).toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
      });
    } catch {
      return value;
    }
  }

  function formatMetricValue(value) {
    const n = Number(value) || 0;
    return Number.isInteger(n) ? String(n) : n.toFixed(1);
  }

  function countLabel(count, singular, plural) {
    const n = Number(count) || 0;
    return n === 1 ? singular : plural;
  }

  async function loadLeaderboard() {
    errorMessage = '';
    loading = true;
    const response = await dataStore.fetchLeaderboard(period);
    loading = false;
    if (!response?.ok) {
      errorMessage = response?.error || 'Unable to load leaderboard data.';
    }
    return response;
  }

  onMount(loadLeaderboard);
</script>

<div class="leaderboard-page">
  <header class="page-header rule-below">
    <div class="header-copy">
      <div class="eyebrow">
        <Trophy size={14} strokeWidth={2} />
        <span>Agency performance</span>
      </div>
      <div class="title-row">
        <h2 class="page-title">Leaderboard</h2>
        <span class="range-pill" title="Current ranking window">{periodLabel}</span>
      </div>
      <p class="page-subtitle">
        Compare report volume, report-linked arrests, and composite activity for the selected window.
      </p>
    </div>

    <div class="header-actions">
      <div class="field">
        <label class="field-label" for="lb-period">Window</label>
        <select id="lb-period" class="period-select" bind:value={period} onchange={loadLeaderboard} disabled={loading}>
          <option value="week">Last 7 days</option>
          <option value="month">Last 30 days</option>
          <option value="all">All time</option>
        </select>
      </div>

      <button type="button" class="btn" onclick={loadLeaderboard} disabled={loading}>
        <span class="btn-refresh-icon" class:spinning={loading} aria-hidden="true">
          <RefreshCw size={14} strokeWidth={2} />
        </span>
        Refresh
      </button>
    </div>
  </header>

  {#if errorMessage}
    <div class="error-banner" role="alert">{errorMessage}</div>
  {/if}

  <section class="metrics-strip rule-below" aria-label="Summary statistics">
    <div class="metric-cell">
      <span class="metric-label">Officers tracked</span>
      <span class="metric-value tabular" class:skeleton={loading}>{loading ? '' : summary.totalOfficers ?? 0}</span>
    </div>
    <div class="metric-cell">
      <span class="metric-label">Reports logged</span>
      <span class="metric-value tabular" class:skeleton={loading}>{loading ? '' : summary.totalReports ?? 0}</span>
    </div>
    <div class="metric-cell">
      <span class="metric-label">Arrests counted</span>
      <span class="metric-value tabular" class:skeleton={loading}>{loading ? '' : summary.totalArrests ?? 0}</span>
    </div>
    <div class="metric-cell">
      <span class="metric-label">Avg. activity score</span>
      <div class="metric-value-wrap" class:skeleton={loading}>
        {#if !loading}
          <span class="metric-value tabular">{formatMetricValue(summary.averageActivity ?? 0)}</span>
          <span class="metric-unit">points</span>
        {/if}
      </div>
    </div>
  </section>

  {#if loading}
    <div class="boards-grid boards-grid--loading" aria-hidden="true">
      <div class="sk-block sk-block--tall"></div>
      <div class="sk-block"></div>
      <div class="sk-block"></div>
    </div>
  {:else if !hasAnyBoard}
    <div class="empty-state rule-above">
      <p class="empty-title">No rankings yet</p>
      <p class="empty-body">Log reports and arrests in the MDT for this period to populate leaderboards.</p>
    </div>
  {:else}
    <section class="boards-grid" aria-label="Rankings by category">
      <article class="board board--activity">
        <header class="board-head">
          <Activity size={17} strokeWidth={2} />
          <div class="board-head-copy">
            <h3>Activity leaders</h3>
            <p class="board-desc">
              Composite points from MDT usage in <strong>{periodLabel.toLowerCase()}</strong>.
              <span class="info-wrap" title="Higher scores reflect more tracked MDT actions in-range.">
                <Info size={12} strokeWidth={2} aria-hidden="true" />
              </span>
            </p>
          </div>
        </header>

        <ul class="rank-list">
          {#each activityLeaders as row, index (officerKey(row, index))}
            {@const score = Number(row.activity_score ?? 0) || 0}
            <li
              class="rank-row"
              class:rank-row--lead={index === 0}
              style="--i: {index}; --fill: {(score / maxActivity) * 100}%"
            >
              <div class="rank-badge">{index + 1}</div>
              {#if row.avatar}
                <img class="avatar-img" src={row.avatar} alt="" />
              {:else}
                <div class="avatar {tintClass(row, index)}" aria-hidden="true">{initials(fullName(row))}</div>
              {/if}
              <div class="rank-body">
                <div class="rank-top">
                  <strong class="rank-name">{fullName(row)}</strong>
                  <div class="rank-stat" aria-label="{score} {countLabel(score, 'point', 'points')}">
                    <span class="rank-stat-value tabular">{formatMetricValue(score)}</span>
                    <span class="rank-stat-label">{countLabel(score, 'point', 'points')}</span>
                  </div>
                </div>
                <div class="rank-meta">
                  {row.callsign || 'No callsign'} · {row.rank || 'Officer'} · {departmentLabel(row.department)}
                </div>
                <div class="rank-bar" aria-hidden="true"><span class="rank-bar-fill"></span></div>
              </div>
            </li>
          {/each}
        </ul>
      </article>

      <article class="board board--reports">
        <header class="board-head board-head--compact">
          <FileText size={16} strokeWidth={2} />
          <div class="board-head-copy">
            <h3>Reports</h3>
            <p class="board-desc">Completed reports filed.</p>
          </div>
        </header>

        <ul class="rank-list rank-list--compact">
          {#each reportLeaders as row, index (officerKey(row, index))}
            {@const n = Number(row.reports_count ?? row.report_count ?? 0) || 0}
            <li class="rank-row rank-row--compact" style="--i: {index}; --fill: {(n / maxReports) * 100}%">
              <div class="rank-badge rank-badge--sm">{index + 1}</div>
              {#if row.avatar}
                <img class="avatar-img avatar-img--sm" src={row.avatar} alt="" />
              {:else}
                <div class="avatar avatar--sm {tintClass(row, index)}" aria-hidden="true">{initials(fullName(row))}</div>
              {/if}
              <div class="rank-body">
                <div class="rank-top">
                  <strong class="rank-name">{fullName(row)}</strong>
                  <div class="rank-stat" aria-label="{n} {countLabel(n, 'report', 'reports')}">
                    <span class="rank-stat-value tabular">{formatMetricValue(n)}</span>
                    <span class="rank-stat-label">{countLabel(n, 'report', 'reports')}</span>
                  </div>
                </div>
                <div class="rank-meta">
                  {row.callsign || '—'} · {departmentLabel(row.department)}
                </div>
                <div class="rank-bar" aria-hidden="true"><span class="rank-bar-fill rank-bar-fill--muted"></span></div>
              </div>
            </li>
          {/each}
        </ul>
      </article>

      <article class="board board--arrests">
        <header class="board-head board-head--compact">
          <ShieldAlert size={16} strokeWidth={2} />
          <div class="board-head-copy">
            <h3>Arrests</h3>
            <p class="board-desc">Arrests linked to reports.</p>
          </div>
        </header>

        <ul class="rank-list rank-list--compact">
          {#each arrestLeaders as row, index (officerKey(row, index))}
            {@const n = Number(row.arrests_count ?? row.arrest_count ?? 0) || 0}
            <li class="rank-row rank-row--compact" style="--i: {index}; --fill: {(n / maxArrests) * 100}%">
              <div class="rank-badge rank-badge--sm">{index + 1}</div>
              {#if row.avatar}
                <img class="avatar-img avatar-img--sm" src={row.avatar} alt="" />
              {:else}
                <div class="avatar avatar--sm {tintClass(row, index)}" aria-hidden="true">{initials(fullName(row))}</div>
              {/if}
              <div class="rank-body">
                <div class="rank-top">
                  <strong class="rank-name">{fullName(row)}</strong>
                  <div class="rank-stat" aria-label="{n} {countLabel(n, 'arrest', 'arrests')}">
                    <span class="rank-stat-value tabular">{formatMetricValue(n)}</span>
                    <span class="rank-stat-label">{countLabel(n, 'arrest', 'arrests')}</span>
                  </div>
                </div>
                <div class="rank-meta">
                  {row.callsign || '—'} · {departmentLabel(row.department)}
                </div>
                <div class="rank-bar" aria-hidden="true"><span class="rank-bar-fill rank-bar-fill--muted"></span></div>
              </div>
            </li>
          {/each}
        </ul>
      </article>
    </section>

    <footer class="page-footer rule-above">
      <span class="generated-at">Updated {formatStamp(leaderboard.generatedAt)}</span>
    </footer>
  {/if}
</div>

<style>
  .leaderboard-page {
    --lb-rule: 1px solid var(--mdt-border);
    --lb-rule-strong: 1px solid var(--mdt-border-2);
    padding: calc(20px * var(--mdt-scale)) calc(24px * var(--mdt-scale)) calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: 0;
    min-height: 100%;
    overflow: auto;
    animation: fadeIn 0.22s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .rule-below {
    padding-bottom: calc(18px * var(--mdt-scale));
    margin-bottom: calc(18px * var(--mdt-scale));
    border-bottom: var(--lb-rule);
  }

  .rule-above {
    padding-top: calc(14px * var(--mdt-scale));
    margin-top: calc(14px * var(--mdt-scale));
    border-top: var(--lb-rule);
  }

  .page-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
  }

  .header-copy {
    min-width: 0;
    flex: 1;
    max-width: min(100%, calc(640px * var(--mdt-scale)));
  }

  .eyebrow {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    color: var(--mdt-accent);
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    margin-bottom: calc(6px * var(--mdt-scale));
  }

  .title-row {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: calc(10px * var(--mdt-scale));
    margin-bottom: calc(5px * var(--mdt-scale));
  }

  .page-title {
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.03em;
    color: var(--mdt-text);
    line-height: 1.1;
  }

  .range-pill {
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
    padding: calc(2px * var(--mdt-scale)) calc(9px * var(--mdt-scale));
    border-radius: 999px;
    border: var(--lb-rule);
    background: transparent;
  }

  .page-subtitle {
    color: var(--mdt-text-muted);
    font-size: calc(12.5px * var(--mdt-scale));
    line-height: 1.5;
    max-width: 58ch;
  }

  .header-actions {
    display: flex;
    flex-shrink: 0;
    align-items: flex-end;
    gap: calc(10px * var(--mdt-scale));
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .field-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--mdt-text-muted);
  }

  .period-select,
  .btn {
    border-radius: var(--mdt-radius);
    border: var(--lb-rule);
    background: transparent;
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
  }

  .period-select {
    padding: calc(8px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    min-width: calc(132px * var(--mdt-scale));
    cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }

  .period-select:hover:not(:disabled) {
    border-color: var(--mdt-border-2);
    color: var(--mdt-text);
  }

  .period-select:disabled {
    opacity: 0.55;
    cursor: not-allowed;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    gap: calc(7px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(13px * var(--mdt-scale));
    cursor: pointer;
    font-weight: 600;
    transition:
      transform 0.2s cubic-bezier(0.16, 1, 0.3, 1),
      border-color 0.2s ease,
      background 0.2s ease;
  }

  .btn:hover:not(:disabled) {
    border-color: var(--mdt-border-2);
    background: rgba(255, 255, 255, 0.03);
  }

  .btn:active:not(:disabled) {
    transform: translateY(1px) scale(0.98);
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-refresh-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }

  .btn-refresh-icon.spinning :global(svg) {
    animation: spin 0.7s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .metrics-strip {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0;
    background: transparent;
    box-shadow: none;
    border-radius: 0;
  }

  @media (min-width: 720px) {
    .metrics-strip {
      grid-template-columns: repeat(4, minmax(0, 1fr));
    }
  }

  .metric-cell {
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
    border-right: var(--lb-rule);
    border-bottom: var(--lb-rule);
  }

  @media (min-width: 720px) {
    .metric-cell {
      border-bottom: none;
      padding: calc(10px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    }

    .metric-cell:first-child {
      padding-left: 0;
    }

    .metric-cell:last-child {
      border-right: none;
      padding-right: 0;
    }
  }

  @media (max-width: 719px) {
    .metric-cell:nth-child(2n) {
      border-right: none;
    }

    .metric-cell:nth-last-child(-n + 2) {
      border-bottom: none;
    }

    .metric-cell:nth-child(odd) {
      padding-left: 0;
    }

    .metric-cell:nth-child(even) {
      padding-right: 0;
    }
  }

  .metric-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--mdt-text-muted);
  }

  .metric-value {
    font-size: calc(26px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.03em;
    color: var(--mdt-text);
    font-variant-numeric: tabular-nums;
    line-height: 1.1;
  }

  .metric-value-wrap {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: calc(6px * var(--mdt-scale));
  }

  .metric-unit {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    letter-spacing: 0.02em;
  }

  .metric-value-wrap.skeleton,
  .metric-value.skeleton {
    min-height: calc(28px * var(--mdt-scale));
    border-radius: 2px;
    background: linear-gradient(
      90deg,
      transparent 0%,
      rgba(255, 255, 255, 0.06) 45%,
      transparent 90%
    );
    background-size: 200% 100%;
    animation: shimmer 1.1s ease-in-out infinite;
  }

  .metric-value-wrap.skeleton {
    min-width: calc(72px * var(--mdt-scale));
  }

  @keyframes shimmer {
    0% {
      background-position: 100% 0;
    }
    100% {
      background-position: -100% 0;
    }
  }

  .boards-grid {
    display: grid;
    gap: 0;
    grid-template-columns: 1fr;
    align-items: stretch;
  }

  @media (min-width: 768px) {
    .boards-grid {
      grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.925fr);
      grid-template-rows: auto auto;
    }

    .board--activity {
      grid-column: 1;
      grid-row: 1 / span 2;
      border-right: var(--lb-rule);
      padding-right: calc(20px * var(--mdt-scale));
    }

    .board--reports {
      grid-column: 2;
      grid-row: 1;
      border-bottom: var(--lb-rule);
      padding-bottom: calc(16px * var(--mdt-scale));
      padding-left: calc(20px * var(--mdt-scale));
    }

    .board--arrests {
      grid-column: 2;
      grid-row: 2;
      padding-top: calc(16px * var(--mdt-scale));
      padding-left: calc(20px * var(--mdt-scale));
    }
  }

  @media (min-width: 1100px) {
    .boards-grid {
      grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr) minmax(0, 1fr);
      grid-template-rows: 1fr;
    }

    .board--activity {
      grid-column: 1;
      grid-row: 1;
      border-right: var(--lb-rule);
      border-bottom: none;
      padding-right: calc(22px * var(--mdt-scale));
      padding-bottom: 0;
    }

    .board--reports {
      grid-column: 2;
      grid-row: 1;
      border-right: var(--lb-rule);
      border-bottom: none;
      padding: 0 calc(22px * var(--mdt-scale));
    }

    .board--arrests {
      grid-column: 3;
      grid-row: 1;
      padding-top: 0;
      padding-left: calc(22px * var(--mdt-scale));
      padding-right: 0;
    }
  }

  .board {
    min-width: 0;
    display: flex;
    flex-direction: column;
    padding: calc(4px * var(--mdt-scale)) 0 calc(8px * var(--mdt-scale));
  }

  @media (max-width: 767px) {
    .board + .board {
      margin-top: calc(20px * var(--mdt-scale));
      padding-top: calc(20px * var(--mdt-scale));
      border-top: var(--lb-rule);
    }
  }

  .board-head {
    display: flex;
    align-items: flex-start;
    gap: calc(10px * var(--mdt-scale));
    color: var(--mdt-text);
    padding-bottom: calc(12px * var(--mdt-scale));
    margin-bottom: calc(4px * var(--mdt-scale));
    border-bottom: var(--lb-rule);
  }

  .board-head--compact {
    padding-bottom: calc(10px * var(--mdt-scale));
  }

  .board-head-copy h3 {
    font-size: calc(13.5px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.01em;
    line-height: 1.2;
  }

  .board-desc {
    margin-top: calc(3px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.4;
    max-width: 48ch;
  }

  .board-desc strong {
    color: var(--mdt-text-dim);
    font-weight: 600;
  }

  .info-wrap {
    display: inline-flex;
    vertical-align: middle;
    margin-left: calc(3px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    cursor: help;
  }

  .rank-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
  }

  .rank-row {
    display: grid;
    grid-template-columns: auto auto minmax(0, 1fr);
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) 0;
    background: transparent;
    border: none;
    border-bottom: var(--lb-rule);
    border-radius: 0;
    transition: background 0.18s ease;
    animation: rowIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) both;
    animation-delay: calc(var(--i, 0) * 38ms);
  }

  .rank-row:last-child {
    border-bottom: none;
  }

  .rank-row:hover {
    background: rgba(255, 255, 255, 0.025);
  }

  .rank-row--lead {
    padding-top: calc(14px * var(--mdt-scale));
  }

  .rank-row--lead .rank-badge {
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.08);
  }

  .rank-row--lead .rank-bar-fill {
    opacity: 1;
  }

  .rank-row--compact {
    padding: calc(9px * var(--mdt-scale)) 0;
    gap: calc(8px * var(--mdt-scale));
  }

  @keyframes rowIn {
    from {
      opacity: 0;
      transform: translateY(4px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .rank-badge {
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 800;
    background: transparent;
    border: var(--lb-rule);
    color: var(--mdt-accent);
    flex-shrink: 0;
    font-variant-numeric: tabular-nums;
  }

  .rank-badge--sm {
    width: calc(20px * var(--mdt-scale));
    height: calc(20px * var(--mdt-scale));
    font-size: calc(9.5px * var(--mdt-scale));
  }

  .avatar {
    width: calc(34px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.02em;
    flex-shrink: 0;
    border: var(--lb-rule);
    color: var(--mdt-text);
  }

  .avatar--sm {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    font-size: calc(9.5px * var(--mdt-scale));
  }

  .avatar.tint-0 {
    background: rgba(96, 165, 250, 0.12);
  }
  .avatar.tint-1 {
    background: rgba(52, 211, 153, 0.1);
  }
  .avatar.tint-2 {
    background: rgba(251, 191, 36, 0.1);
  }
  .avatar.tint-3 {
    background: rgba(248, 113, 113, 0.09);
  }
  .avatar.tint-4 {
    background: rgba(148, 163, 184, 0.12);
  }

  .avatar-img {
    width: calc(34px * var(--mdt-scale));
    height: calc(34px * var(--mdt-scale));
    border-radius: 50%;
    object-fit: cover;
    flex-shrink: 0;
    border: var(--lb-rule);
  }

  .avatar-img--sm {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
  }

  .rank-body {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .rank-top {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .rank-name {
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .rank-meta {
    font-size: calc(10.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .rank-stat {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: calc(1px * var(--mdt-scale));
    flex-shrink: 0;
    min-width: calc(56px * var(--mdt-scale));
    text-align: right;
  }

  .rank-stat-value {
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.03em;
    color: var(--mdt-text);
    line-height: 1;
  }

  .rank-row--lead .rank-stat-value {
    font-size: calc(16px * var(--mdt-scale));
  }

  .rank-stat-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    letter-spacing: 0.02em;
    line-height: 1.2;
  }

  .tabular {
    font-variant-numeric: tabular-nums;
  }

  .rank-bar {
    height: calc(2px * var(--mdt-scale));
    border-radius: 0;
    background: rgba(255, 255, 255, 0.05);
    margin-top: calc(5px * var(--mdt-scale));
    overflow: hidden;
  }

  .rank-bar-fill {
    display: block;
    height: 100%;
    width: var(--fill, 0%);
    background: var(--mdt-accent);
    opacity: 0.75;
    transition: width 0.45s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .rank-bar-fill--muted {
    background: var(--mdt-text-dim);
    opacity: 0.35;
  }

  .error-banner {
    padding: calc(10px * var(--mdt-scale)) 0;
    border-top: var(--lb-rule-strong);
    border-bottom: var(--lb-rule-strong);
    background: transparent;
    color: var(--mdt-error);
    font-size: calc(12px * var(--mdt-scale));
    margin-bottom: calc(16px * var(--mdt-scale));
  }

  .empty-state {
    padding: calc(40px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    text-align: center;
    background: transparent;
    border-radius: 0;
    border: none;
  }

  .empty-title {
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    margin-bottom: calc(6px * var(--mdt-scale));
  }

  .empty-body {
    font-size: calc(12.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    max-width: 42ch;
    margin: 0 auto;
    line-height: 1.45;
  }

  .page-footer {
    display: flex;
    justify-content: flex-end;
  }

  .generated-at {
    font-size: calc(10.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.02em;
  }

  .boards-grid--loading {
    min-height: calc(240px * var(--mdt-scale));
    border-top: var(--lb-rule);
    padding-top: calc(16px * var(--mdt-scale));
  }

  .sk-block {
    min-height: calc(120px * var(--mdt-scale));
    border-bottom: var(--lb-rule);
    animation: pulseSk 1.2s ease-in-out infinite;
  }

  .sk-block--tall {
    min-height: calc(260px * var(--mdt-scale));
  }

  @keyframes pulseSk {
    0%,
    100% {
      opacity: 0.35;
    }
    50% {
      opacity: 0.7;
    }
  }

  @media (max-width: 900px) {
    .page-header {
      flex-direction: column;
      align-items: stretch;
    }

    .header-actions {
      justify-content: space-between;
    }
  }
</style>
