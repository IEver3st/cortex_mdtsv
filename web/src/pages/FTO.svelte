<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import {
    GraduationCap, Plus, Search, User, ChevronRight, Check, X,
    Clock, Star, AlertTriangle, Shield,
  } from '@lucide/svelte';

  const PHASES = [
    { id: 1, label: 'Phase I — Observation',               short: 'I' },
    { id: 2, label: 'Phase II — Supervised Patrol',         short: 'II' },
    { id: 3, label: 'Phase III — Solo Patrol w/ Check-ins', short: 'III' },
    { id: 4, label: 'Phase IV — Evaluation',                short: 'IV' },
  ];

  const STATUS_OPTIONS = [
    { id: 'in_review', label: 'In Review',  color: 'var(--mdt-warning)' },
    { id: 'passed',    label: 'Passed',     color: 'var(--mdt-success)' },
    { id: 'failed',    label: 'Failed',     color: 'var(--mdt-error)' },
    { id: 'active',    label: 'Active',     color: 'var(--mdt-accent)' },
  ];

  const MOCK_FTO_RECORDS = [
    { id: 1, traineeId: 'CIT-001', traineeName: 'Ofc. Riley Parker', trainerId: 'CIT-005', trainerName: 'Sgt. Marcus Chen', phase: 2, score: 7.4, status: 'active', notes: 'Showing strong improvement in vehicle pursuits. Needs work on radio communication.', created_at: '2026-03-15T10:30:00Z', updated_at: '2026-03-28T14:22:00Z' },
    { id: 2, traineeId: 'CIT-002', traineeName: 'Ofc. Jordan Hayes', trainerId: 'CIT-005', trainerName: 'Sgt. Marcus Chen', phase: 4, score: 8.9, status: 'in_review', notes: 'Excellent performance across all phases. Recommendation for full clearance pending supervisor review.', created_at: '2026-02-01T08:15:00Z', updated_at: '2026-03-25T16:45:00Z' },
    { id: 3, traineeId: 'CIT-003', traineeName: 'Ofc. Avery Brooks', trainerId: 'CIT-006', trainerName: 'Cpl. Diana Torres', phase: 1, score: 5.2, status: 'active', notes: 'First week of observation. Basic procedures are solid; situational awareness needs development.', created_at: '2026-03-28T09:00:00Z', updated_at: '2026-03-30T11:00:00Z' },
    { id: 4, traineeId: 'CIT-004', traineeName: 'Ofc. Sam Nakamura', trainerId: 'CIT-006', trainerName: 'Cpl. Diana Torres', phase: 3, score: 3.1, status: 'failed', notes: 'Failed to follow use-of-force guidelines during solo patrol. Remedial training required.', created_at: '2026-01-10T07:30:00Z', updated_at: '2026-03-20T09:15:00Z' },
    { id: 5, traineeId: 'CIT-007', traineeName: 'Ofc. Casey Rivera', trainerId: 'CIT-005', trainerName: 'Sgt. Marcus Chen', phase: 4, score: 9.2, status: 'passed', notes: 'Cleared for full independent duty. Strong communicator, good instincts.', created_at: '2025-11-10T10:00:00Z', updated_at: '2026-02-14T13:30:00Z' },
  ];

  let mounted = $state(false);
  let mode = $state('list');
  let searchQuery = $state('');
  let statusFilter = $state('all');
  let records = $state([]);
  let selectedRecord = $state(null);
  let saving = $state(false);

  let createForm = $state({
    traineeName: '', traineeId: '', trainerName: '', trainerId: '',
    phase: 1, score: 5.0, status: 'active', notes: '',
  });

  let filteredRecords = $derived.by(() => {
    let result = records;
    if (statusFilter !== 'all') {
      result = result.filter(r => r.status === statusFilter);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      result = result.filter(r =>
        r.traineeName.toLowerCase().includes(q) ||
        r.trainerName.toLowerCase().includes(q) ||
        r.traineeId.toLowerCase().includes(q)
      );
    }
    return result;
  });

  let summary = $derived({
    total: records.length,
    active: records.filter(r => r.status === 'active').length,
    passed: records.filter(r => r.status === 'passed').length,
    failed: records.filter(r => r.status === 'failed').length,
    inReview: records.filter(r => r.status === 'in_review').length,
    avgScore: records.length > 0 ? (records.reduce((s, r) => s + (r.score || 0), 0) / records.length).toFixed(1) : '0.0',
  });

  onMount(async () => {
    mounted = true;
    if (isEnvBrowser()) {
      records = MOCK_FTO_RECORDS;
    } else {
      const resp = await dataStore.fetchFtoRecords();
      if (resp?.ok && resp.records) {
        records = resp.records;
      }
    }
  });

  function statusMeta(statusId) {
    return STATUS_OPTIONS.find(s => s.id === statusId) || STATUS_OPTIONS[0];
  }

  function phaseLabel(phaseId) {
    return PHASES.find(p => p.id === phaseId)?.label || `Phase ${phaseId}`;
  }

  function phaseShort(phaseId) {
    return PHASES.find(p => p.id === phaseId)?.short || String(phaseId);
  }

  function scoreColor(score) {
    if (score >= 8) return 'var(--mdt-success)';
    if (score >= 6) return 'var(--mdt-accent)';
    if (score >= 4) return 'var(--mdt-warning)';
    return 'var(--mdt-error)';
  }

  function formatDate(dateStr) {
    if (!dateStr) return '—';
    try {
      return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    } catch { return dateStr; }
  }

  function openDetail(record) {
    selectedRecord = { ...record };
    mode = 'detail';
  }

  function openCreate() {
    createForm = {
      traineeName: '', traineeId: '', trainerName: mdtStore.officer.firstName + ' ' + mdtStore.officer.lastName,
      trainerId: mdtStore.officer.officerId || '', phase: 1, score: 5.0, status: 'active', notes: '',
    };
    mode = 'create';
  }

  async function submitCreate() {
    if (!createForm.traineeName.trim()) return;
    saving = true;
    if (isEnvBrowser()) {
      const newRecord = {
        id: Date.now(),
        ...createForm,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      records = [newRecord, ...records];
      mode = 'list';
    } else {
      const resp = await dataStore.createFtoRecord(createForm);
      if (resp?.ok) {
        if (resp.record) records = [resp.record, ...records];
        mode = 'list';
      }
    }
    saving = false;
  }

  async function updateRecord() {
    if (!selectedRecord) return;
    saving = true;
    if (isEnvBrowser()) {
      records = records.map(r => r.id === selectedRecord.id ? { ...selectedRecord, updated_at: new Date().toISOString() } : r);
      mode = 'list';
    } else {
      const resp = await dataStore.updateFtoRecord(selectedRecord);
      if (resp?.ok) {
        records = records.map(r => r.id === selectedRecord.id ? { ...selectedRecord, updated_at: new Date().toISOString() } : r);
        mode = 'list';
      }
    }
    saving = false;
  }
</script>

<div class="fto-page" class:mounted>
  {#if mode === 'list'}
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">Field Training</h1>
        <span class="page-count font-mono">{filteredRecords.length} records</span>
      </div>
      <div class="header-actions">
        <div class="search-box">
          <Search size={14} strokeWidth={2} />
          <input class="search-input font-mono" type="text" placeholder="Search trainees..." bind:value={searchQuery} />
        </div>
        <button class="create-btn" onclick={openCreate}>
          <Plus size={14} strokeWidth={2} />
          <span>New Record</span>
        </button>
      </div>
    </div>

    <!-- Summary Stats -->
    <div class="stats-row">
      <div class="stat-card">
        <span class="stat-value font-mono">{summary.total}</span>
        <span class="stat-label">Total</span>
      </div>
      <div class="stat-card">
        <span class="stat-value font-mono" style="color: var(--mdt-accent);">{summary.active}</span>
        <span class="stat-label">Active</span>
      </div>
      <div class="stat-card">
        <span class="stat-value font-mono" style="color: var(--mdt-warning);">{summary.inReview}</span>
        <span class="stat-label">In Review</span>
      </div>
      <div class="stat-card">
        <span class="stat-value font-mono" style="color: var(--mdt-success);">{summary.passed}</span>
        <span class="stat-label">Passed</span>
      </div>
      <div class="stat-card">
        <span class="stat-value font-mono" style="color: var(--mdt-error);">{summary.failed}</span>
        <span class="stat-label">Failed</span>
      </div>
      <div class="stat-card">
        <Star size={14} strokeWidth={2} style="color: var(--mdt-warning); flex-shrink: 0;" />
        <span class="stat-value font-mono">{summary.avgScore}</span>
        <span class="stat-label">Avg Score</span>
      </div>
    </div>

    <!-- Status Filter -->
    <div class="filter-row">
      <button class="filter-btn font-mono" class:active={statusFilter === 'all'} onclick={() => statusFilter = 'all'}>All</button>
      {#each STATUS_OPTIONS as opt (opt.id)}
        <button class="filter-btn font-mono" class:active={statusFilter === opt.id} onclick={() => statusFilter = opt.id}>
          <span class="filter-dot" style="background: {opt.color};"></span>
          {opt.label}
        </button>
      {/each}
    </div>

    <!-- Records List -->
    <div class="records-list">
      {#if filteredRecords.length === 0}
        <div class="empty-state">
          <GraduationCap size={32} strokeWidth={1} />
          <span class="empty-text">No FTO records found</span>
        </div>
      {:else}
        {#each filteredRecords as rec, i (rec.id)}
          {@const sm = statusMeta(rec.status)}
          <button class="record-card" style="--stagger: {i}" onclick={() => openDetail(rec)}>
            <div class="rec-phase">
              <div class="phase-ring" style="--phase-progress: {(rec.phase / 4) * 100}%;">
                <span class="phase-num font-mono">{phaseShort(rec.phase)}</span>
              </div>
            </div>
            <div class="rec-main">
              <div class="rec-top">
                <span class="rec-trainee">{rec.traineeName}</span>
                <span class="rec-status font-mono" style="color: {sm.color}; background: {sm.color}15;">{sm.label.toUpperCase()}</span>
              </div>
              <div class="rec-meta font-mono">
                <span>FTO: {rec.trainerName}</span>
                <span class="rec-sep">|</span>
                <span>{phaseLabel(rec.phase)}</span>
                <span class="rec-sep">|</span>
                <span>Updated {formatDate(rec.updated_at)}</span>
              </div>
            </div>
            <div class="rec-score" style="color: {scoreColor(rec.score)};">
              <span class="score-value font-mono">{rec.score.toFixed(1)}</span>
              <span class="score-label font-mono">/10</span>
            </div>
            <div class="rec-chevron"><ChevronRight size={14} strokeWidth={2} /></div>
          </button>
        {/each}
      {/if}
    </div>

  {:else if mode === 'create'}
    <div class="form-page">
      <div class="form-header">
        <button class="back-btn" onclick={() => mode = 'list'}><X size={14} strokeWidth={2} /> <span>Cancel</span></button>
        <h2 class="form-title">New FTO Record</h2>
      </div>
      <div class="form-body">
        <div class="form-grid">
          <label class="form-field">
            <span class="field-label font-mono">Trainee Name</span>
            <input bind:value={createForm.traineeName} class="field-input" placeholder="Ofc. Riley Parker" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Trainee ID</span>
            <input bind:value={createForm.traineeId} class="field-input font-mono" placeholder="CIT-001" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Trainer Name</span>
            <input bind:value={createForm.trainerName} class="field-input" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Trainer ID</span>
            <input bind:value={createForm.trainerId} class="field-input font-mono" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Current Phase</span>
            <select bind:value={createForm.phase} class="field-input font-mono">
              {#each PHASES as p (p.id)}
                <option value={p.id}>{p.label}</option>
              {/each}
            </select>
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Score (0–10)</span>
            <input bind:value={createForm.score} class="field-input font-mono" type="number" min="0" max="10" step="0.1" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Status</span>
            <select bind:value={createForm.status} class="field-input font-mono">
              {#each STATUS_OPTIONS as opt (opt.id)}
                <option value={opt.id}>{opt.label}</option>
              {/each}
            </select>
          </label>
        </div>
        <label class="form-field form-field-full">
          <span class="field-label font-mono">Notes</span>
          <textarea bind:value={createForm.notes} class="field-textarea" rows="4" placeholder="Training observations, areas of improvement..."></textarea>
        </label>
        <div class="form-actions">
          <button class="save-btn" onclick={submitCreate} disabled={saving || !createForm.traineeName.trim()}>
            <Check size={14} strokeWidth={2} /> <span>{saving ? 'Saving...' : 'Create Record'}</span>
          </button>
        </div>
      </div>
    </div>

  {:else if mode === 'detail' && selectedRecord}
    <div class="form-page">
      <div class="form-header">
        <button class="back-btn" onclick={() => { mode = 'list'; selectedRecord = null; }}><X size={14} strokeWidth={2} /> <span>Back</span></button>
        <h2 class="form-title">{selectedRecord.traineeName}</h2>
        <span class="form-subtitle font-mono">{phaseLabel(selectedRecord.phase)}</span>
      </div>
      <div class="form-body">
        <div class="form-grid">
          <label class="form-field">
            <span class="field-label font-mono">Trainee Name</span>
            <input bind:value={selectedRecord.traineeName} class="field-input" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Trainee ID</span>
            <input bind:value={selectedRecord.traineeId} class="field-input font-mono" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Trainer Name</span>
            <input bind:value={selectedRecord.trainerName} class="field-input" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Current Phase</span>
            <select bind:value={selectedRecord.phase} class="field-input font-mono">
              {#each PHASES as p (p.id)}
                <option value={p.id}>{p.label}</option>
              {/each}
            </select>
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Score (0–10)</span>
            <input bind:value={selectedRecord.score} class="field-input font-mono" type="number" min="0" max="10" step="0.1" />
          </label>
          <label class="form-field">
            <span class="field-label font-mono">Status</span>
            <select bind:value={selectedRecord.status} class="field-input font-mono">
              {#each STATUS_OPTIONS as opt (opt.id)}
                <option value={opt.id}>{opt.label}</option>
              {/each}
            </select>
          </label>
        </div>
        <label class="form-field form-field-full">
          <span class="field-label font-mono">Notes</span>
          <textarea bind:value={selectedRecord.notes} class="field-textarea" rows="5"></textarea>
        </label>

        <!-- Phase Progress Visual -->
        <div class="phase-timeline">
          <span class="field-label font-mono" style="margin-bottom: calc(8px * var(--mdt-scale));">TRAINING PROGRESSION</span>
          <div class="timeline-track">
            {#each PHASES as p (p.id)}
              {@const completed = selectedRecord.phase > p.id}
              {@const current = selectedRecord.phase === p.id}
              <div class="timeline-step" class:completed class:current>
                <div class="step-dot">
                  {#if completed}
                    <Check size={10} strokeWidth={3} />
                  {:else}
                    <span class="step-num font-mono">{p.short}</span>
                  {/if}
                </div>
                <span class="step-label font-mono">{p.short}</span>
              </div>
              {#if p.id < 4}
                <div class="step-line" class:completed={selectedRecord.phase > p.id}></div>
              {/if}
            {/each}
          </div>
        </div>

        <div class="form-actions">
          <button class="save-btn" onclick={updateRecord} disabled={saving}>
            <Check size={14} strokeWidth={2} /> <span>{saving ? 'Saving...' : 'Save Changes'}</span>
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .fto-page { padding: calc(24px * var(--mdt-scale)); display: flex; flex-direction: column; gap: calc(16px * var(--mdt-scale)); opacity: 0; }
  .fto-page.mounted { animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards; }

  .page-header { display: flex; align-items: center; justify-content: space-between; gap: calc(16px * var(--mdt-scale)); flex-wrap: wrap; }
  .header-left { display: flex; align-items: baseline; gap: calc(12px * var(--mdt-scale)); }
  .page-title { font-size: calc(20px * var(--mdt-scale)); font-weight: 700; color: var(--mdt-text); margin: 0; }
  .page-count { font-size: calc(11px * var(--mdt-scale)); color: var(--mdt-text-muted); letter-spacing: 0.06em; font-variant-numeric: tabular-nums; }
  .header-actions { display: flex; align-items: center; gap: calc(10px * var(--mdt-scale)); }

  .search-box { display: flex; align-items: center; gap: calc(8px * var(--mdt-scale)); padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale)); background: var(--mdt-surface); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); color: var(--mdt-text-muted); }
  .search-input { background: none; border: none; color: var(--mdt-text); outline: none; font-size: calc(12px * var(--mdt-scale)); width: calc(140px * var(--mdt-scale)); }
  .search-input::placeholder { color: var(--mdt-text-muted); }

  .create-btn { display: flex; align-items: center; gap: calc(6px * var(--mdt-scale)); padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale)); background: var(--mdt-accent-dim); color: var(--mdt-accent); border: 1px solid rgba(255,255,255,0.06); border-radius: var(--mdt-radius); font-family: inherit; font-size: calc(12px * var(--mdt-scale)); font-weight: 600; cursor: pointer; transition: background 0.15s ease; }
  .create-btn:hover { background: var(--mdt-accent-glow); }

  .stats-row { display: flex; gap: calc(8px * var(--mdt-scale)); flex-wrap: wrap; }
  .stat-card { display: flex; align-items: center; gap: calc(8px * var(--mdt-scale)); padding: calc(10px * var(--mdt-scale)) calc(16px * var(--mdt-scale)); background: var(--mdt-surface); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); }
  .stat-value { font-size: calc(18px * var(--mdt-scale)); font-weight: 700; color: var(--mdt-text); font-variant-numeric: tabular-nums; }
  .stat-label { font-size: calc(10px * var(--mdt-scale)); color: var(--mdt-text-muted); }

  .filter-row { display: flex; gap: calc(4px * var(--mdt-scale)); padding-bottom: calc(4px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .filter-btn { display: flex; align-items: center; gap: calc(6px * var(--mdt-scale)); padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border-radius: var(--mdt-radius-sm); border: none; background: transparent; color: var(--mdt-text-muted); font-family: 'Share Tech Mono', monospace; font-size: calc(10px * var(--mdt-scale)); cursor: pointer; transition: color 0.15s ease, background 0.15s ease; }
  .filter-btn:hover { color: var(--mdt-text); background: var(--mdt-surface); }
  .filter-btn.active { color: var(--mdt-accent); background: var(--mdt-accent-dim); }
  .filter-dot { width: calc(6px * var(--mdt-scale)); height: calc(6px * var(--mdt-scale)); border-radius: 50%; }

  .records-list { display: flex; flex-direction: column; gap: calc(4px * var(--mdt-scale)); }
  .empty-state { display: flex; flex-direction: column; align-items: center; gap: calc(10px * var(--mdt-scale)); padding: calc(48px * var(--mdt-scale)); color: var(--mdt-text-muted); }
  .empty-text { font-size: calc(13px * var(--mdt-scale)); }

  .record-card { display: flex; align-items: center; gap: calc(14px * var(--mdt-scale)); padding: calc(14px * var(--mdt-scale)) calc(18px * var(--mdt-scale)); background: var(--mdt-surface); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); cursor: pointer; font-family: inherit; text-align: left; width: 100%; color: var(--mdt-text); animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards; animation-delay: calc(var(--stagger) * 50ms); opacity: 0; transition: border-color 0.2s ease; }
  .record-card:hover { border-color: var(--mdt-border-2); }

  .rec-phase { flex-shrink: 0; }
  .phase-ring { width: calc(42px * var(--mdt-scale)); height: calc(42px * var(--mdt-scale)); border-radius: 50%; background: conic-gradient(var(--mdt-accent) var(--phase-progress), var(--mdt-surface-3) var(--phase-progress)); display: flex; align-items: center; justify-content: center; position: relative; }
  .phase-ring::before { content: ''; position: absolute; inset: calc(3px * var(--mdt-scale)); border-radius: 50%; background: var(--mdt-surface); }
  .phase-num { position: relative; z-index: 1; font-size: calc(12px * var(--mdt-scale)); color: var(--mdt-accent); font-weight: 700; font-variant-numeric: tabular-nums; }

  .rec-main { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: calc(4px * var(--mdt-scale)); }
  .rec-top { display: flex; align-items: center; justify-content: space-between; gap: calc(10px * var(--mdt-scale)); }
  .rec-trainee { font-size: calc(14px * var(--mdt-scale)); font-weight: 600; }
  .rec-status { font-size: calc(9px * var(--mdt-scale)); letter-spacing: 0.1em; padding: calc(3px * var(--mdt-scale)) calc(10px * var(--mdt-scale)); border-radius: calc(999px * var(--mdt-scale)); }
  .rec-meta { font-size: calc(10px * var(--mdt-scale)); color: var(--mdt-text-muted); display: flex; gap: calc(6px * var(--mdt-scale)); flex-wrap: wrap; }
  .rec-sep { opacity: 0.3; }
  .rec-score { display: flex; align-items: baseline; gap: calc(2px * var(--mdt-scale)); flex-shrink: 0; }
  .score-value { font-size: calc(20px * var(--mdt-scale)); font-weight: 700; font-variant-numeric: tabular-nums; }
  .score-label { font-size: calc(10px * var(--mdt-scale)); color: var(--mdt-text-muted); }
  .rec-chevron { color: var(--mdt-text-muted); flex-shrink: 0; }

  /* Form styles */
  .form-page { display: flex; flex-direction: column; gap: calc(16px * var(--mdt-scale)); }
  .form-header { display: flex; align-items: center; gap: calc(14px * var(--mdt-scale)); padding: calc(16px * var(--mdt-scale)) calc(24px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .back-btn { display: flex; align-items: center; gap: calc(6px * var(--mdt-scale)); padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); background: var(--mdt-surface); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); color: var(--mdt-text-muted); font-family: inherit; font-size: calc(12px * var(--mdt-scale)); cursor: pointer; transition: color 0.15s ease, border-color 0.15s ease; }
  .back-btn:hover { color: var(--mdt-text); border-color: var(--mdt-border-2); }
  .form-title { font-size: calc(18px * var(--mdt-scale)); font-weight: 700; color: var(--mdt-text); margin: 0; }
  .form-subtitle { font-size: calc(11px * var(--mdt-scale)); color: var(--mdt-text-muted); letter-spacing: 0.06em; }
  .form-body { padding: calc(20px * var(--mdt-scale)) calc(24px * var(--mdt-scale)); display: flex; flex-direction: column; gap: calc(16px * var(--mdt-scale)); }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: calc(12px * var(--mdt-scale)); }
  .form-field { display: flex; flex-direction: column; gap: calc(4px * var(--mdt-scale)); }
  .form-field-full { grid-column: 1 / -1; }
  .field-label { font-size: calc(9px * var(--mdt-scale)); letter-spacing: 0.1em; color: var(--mdt-text-muted); text-transform: uppercase; }
  .field-input, .field-textarea { padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale)); background: var(--mdt-surface); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); color: var(--mdt-text); font-family: inherit; font-size: calc(13px * var(--mdt-scale)); outline: none; transition: border-color 0.2s ease; }
  .field-input:focus, .field-textarea:focus { border-color: var(--mdt-accent); }
  .field-textarea { resize: vertical; min-height: calc(60px * var(--mdt-scale)); }
  select.field-input { cursor: pointer; }
  .form-actions { display: flex; justify-content: flex-end; padding-top: calc(8px * var(--mdt-scale)); }
  .save-btn { display: flex; align-items: center; gap: calc(6px * var(--mdt-scale)); padding: calc(10px * var(--mdt-scale)) calc(20px * var(--mdt-scale)); background: var(--mdt-accent-dim); color: var(--mdt-accent); border: 1px solid rgba(255,255,255,0.06); border-radius: var(--mdt-radius); font-family: inherit; font-size: calc(13px * var(--mdt-scale)); font-weight: 600; cursor: pointer; transition: color 0.15s ease, background 0.15s ease; white-space: nowrap; }
  .save-btn:hover:not(:disabled) { background: var(--mdt-accent-glow); }
  .save-btn:disabled { opacity: 0.5; cursor: not-allowed; }

  /* Phase timeline */
  .phase-timeline { padding: calc(16px * var(--mdt-scale)); background: var(--mdt-surface); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); }
  .timeline-track { display: flex; align-items: center; gap: 0; }
  .timeline-step { display: flex; flex-direction: column; align-items: center; gap: calc(6px * var(--mdt-scale)); }
  .step-dot { width: calc(28px * var(--mdt-scale)); height: calc(28px * var(--mdt-scale)); border-radius: 50%; background: var(--mdt-surface-3); border: 2px solid var(--mdt-border); display: flex; align-items: center; justify-content: center; color: var(--mdt-text-muted); transition: background 0.2s ease, border-color 0.2s ease, color 0.2s ease; }
  .timeline-step.completed .step-dot { background: var(--mdt-success); border-color: var(--mdt-success); color: var(--mdt-bg); }
  .timeline-step.current .step-dot { background: var(--mdt-accent-dim); border-color: var(--mdt-accent); color: var(--mdt-accent); }
  .step-num { font-size: calc(9px * var(--mdt-scale)); font-weight: 700; }
  .step-label { font-size: calc(9px * var(--mdt-scale)); color: var(--mdt-text-muted); }
  .step-line { flex: 1; height: calc(2px * var(--mdt-scale)); background: var(--mdt-border); margin: 0 calc(4px * var(--mdt-scale)); margin-bottom: calc(20px * var(--mdt-scale)); }
  .step-line.completed { background: var(--mdt-success); }

  @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
  @keyframes cardIn { from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); } to { opacity: 1; transform: translateY(0); } }
</style>
