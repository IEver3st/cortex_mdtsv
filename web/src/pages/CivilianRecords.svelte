<script>
  import { onMount } from 'svelte';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { FileText, AlertTriangle, Clock, Check, Scale } from '@lucide/svelte';

  let mounted = $state(false);
  let records = $state([]);

  const MOCK_RECORDS = [
    { id: 1, type: 'citation', title: 'Traffic Violation — Speeding', date: '2026-03-18', status: 'unpaid', amount: '$350', officer: 'Ofc. Rivera', badge: '1-A-14' },
    { id: 2, type: 'citation', title: 'Expired Registration', date: '2026-02-05', status: 'paid', amount: '$150', officer: 'Ofc. Chen', badge: '2-L-07' },
    { id: 3, type: 'warrant', title: 'Bench Warrant — FTA', date: '2026-01-12', status: 'active', amount: null, officer: 'Det. Nakamura', badge: 'D-42' },
    { id: 4, type: 'arrest', title: 'Arrest — Reckless Driving', date: '2025-11-20', status: 'resolved', amount: null, officer: 'Sgt. Williams', badge: '1-S-03' },
  ];

  onMount(async () => {
    mounted = true;
    if (isEnvBrowser()) {
      records = MOCK_RECORDS;
    } else {
      const citizenId = mdtStore.civilian?.citizenId;
      if (citizenId) {
        const resp = await dataStore.fetchCivilianRecords(citizenId);
        if (resp?.ok && resp.records) {
          const combined = [
            ...(resp.records.citations || []).map(r => ({ ...r, type: 'citation' })),
            ...(resp.records.warrants || []).map(r => ({ ...r, type: 'warrant' })),
            ...(resp.records.arrests || []).map(r => ({ ...r, type: 'arrest' })),
          ];
          records = combined.sort((a, b) => new Date(b.date || b.created_at || 0) - new Date(a.date || a.created_at || 0));
        }
      }
    }
  });

  function typeIcon(type) {
    if (type === 'warrant') return AlertTriangle;
    if (type === 'arrest') return Scale;
    return FileText;
  }

  function statusColor(status) {
    if (status === 'paid' || status === 'resolved') return 'var(--mdt-success)';
    if (status === 'active' || status === 'unpaid') return 'var(--mdt-error)';
    return 'var(--mdt-warning)';
  }

  function statusBg(status) {
    if (status === 'paid' || status === 'resolved') return 'rgba(52, 211, 153, 0.1)';
    if (status === 'active' || status === 'unpaid') return 'rgba(248, 113, 113, 0.1)';
    return 'rgba(251, 191, 36, 0.1)';
  }

  function typeColor(type) {
    if (type === 'warrant') return 'var(--mdt-error)';
    if (type === 'arrest') return 'var(--mdt-warning)';
    return 'var(--mdt-accent)';
  }

  function typeBg(type) {
    if (type === 'warrant') return 'rgba(248, 113, 113, 0.1)';
    if (type === 'arrest') return 'rgba(251, 191, 36, 0.1)';
    return 'var(--mdt-accent-dim)';
  }
</script>

<div class="civ-records" class:mounted>
  <div class="page-header">
    <h1 class="page-title">My Records</h1>
    <span class="page-count font-mono">{records.length} entries</span>
  </div>

  <div class="records-list">
    {#if records.length === 0}
      <div class="empty-state">
        <FileText size={32} strokeWidth={1} />
        <span class="empty-text">No records found</span>
      </div>
    {:else}
      {#each records as record, i}
        {@const Icon = typeIcon(record.type)}
        <div class="record-card" style="--stagger: {i}">
          <div class="rec-icon-wrap" style="color: {typeColor(record.type)}; background: {typeBg(record.type)};">
            <Icon size={16} strokeWidth={1.8} />
          </div>

          <div class="rec-main">
            <div class="rec-top-row">
              <div class="rec-title-block">
                <span class="rec-type font-mono" style="color: {typeColor(record.type)};">{record.type.toUpperCase()}</span>
                <span class="rec-title">{record.title}</span>
              </div>
              <span
                class="rec-status font-mono"
                style="color: {statusColor(record.status)}; background: {statusBg(record.status)};"
              >
                {record.status.toUpperCase()}
              </span>
            </div>

            <div class="rec-meta font-mono">
              <span class="rec-meta-item">
                <Clock size={10} strokeWidth={2} />
                {record.date}
              </span>
              {#if record.amount}
                <span class="rec-meta-sep">|</span>
                <span class="rec-meta-item rec-meta-amount">{record.amount}</span>
              {/if}
              <span class="rec-meta-sep">|</span>
              <span class="rec-meta-item">{record.officer} ({record.badge})</span>
            </div>
          </div>
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .civ-records {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    opacity: 0;
  }

  .civ-records.mounted {
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .page-header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }

  .page-title {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
  }

  .page-count {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.06em;
    font-variant-numeric: tabular-nums;
    text-transform: uppercase;
  }

  .records-list {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .record-card {
    display: flex;
    align-items: flex-start;
    gap: calc(14px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    animation: cardIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--stagger) * 60ms);
    opacity: 0;
    transition: border-color 0.2s ease;
  }

  .record-card:hover {
    border-color: var(--mdt-border-2);
  }

  .rec-icon-wrap {
    width: calc(36px * var(--mdt-scale));
    height: calc(36px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .rec-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .rec-top-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
  }

  .rec-title-block {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .rec-type {
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.15em;
    font-weight: 600;
  }

  .rec-title {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .rec-status {
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.1em;
    font-weight: 600;
    padding: calc(3px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    flex-shrink: 0;
    white-space: nowrap;
  }

  .rec-meta {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .rec-meta-item {
    display: flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
  }

  .rec-meta-amount {
    color: var(--mdt-error);
    font-weight: 600;
  }

  .rec-meta-sep {
    opacity: 0.3;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(48px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    opacity: 0.5;
  }

  .empty-text {
    font-size: calc(13px * var(--mdt-scale));
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(8px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes cardIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
