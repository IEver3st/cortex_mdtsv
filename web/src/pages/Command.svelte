<script>
  import { onMount, tick } from 'svelte';
  import {
    Award,
    BookOpenCheck,
    CalendarClock,
    Check,
    ChevronRight,
    ClipboardCheck,
    FileWarning,
    Gavel,
    Landmark,
    MapPinned,
    Megaphone,
    Pencil,
    Plus,
    RefreshCw,
    Search,
    ShieldAlert,
    Trash2,
    X,
  } from '@lucide/svelte';
  import { isEnvBrowser, nuiPost } from '../lib/utils/nui.js';

  const MODULES = [
    { id: 'bulletins', label: 'Bulletins', singular: 'bulletin', icon: Megaphone, description: 'Department notices and operational updates.' },
    { id: 'awards', label: 'Awards', singular: 'award', icon: Award, description: 'Commendations and service recognition.' },
    { id: 'ia', label: 'Internal Affairs', singular: 'case', icon: ShieldAlert, description: 'Restricted complaints and professional-standards cases.' },
    { id: 'ppr', label: 'Performance', singular: 'review', icon: ClipboardCheck, description: 'Personnel performance reviews and coaching records.' },
    { id: 'court', label: 'Court', singular: 'court record', icon: Gavel, description: 'Hearings, filings, outcomes, and DOJ coordination.' },
    { id: 'sops', label: 'Directives', singular: 'directive', icon: BookOpenCheck, description: 'Controlled SOP publications and acknowledgements.' },
    { id: 'patrols', label: 'Patrols', singular: 'patrol', icon: MapPinned, description: 'Patrol plans, assignments, locations, and status.' },
  ];

  const EMPTY_FORM = {
    title: '',
    summary: '',
    content: '',
    subjectName: '',
    subjectId: '',
    reference: '',
    assignee: '',
    location: '',
    scheduledAt: '',
    status: 'open',
    priority: 'normal',
    visibility: 'department',
    score: '',
    radius: '',
    pinned: false,
  };

  let selectedKind = $state('bulletins');
  let recordsByKind = $state({});
  let selectedId = $state('');
  let canManage = $state(false);
  let loading = $state(true);
  let saving = $state(false);
  let deleting = $state(false);
  let errorMessage = $state('');
  let searchQuery = $state('');
  let statusFilter = $state('all');
  let editorOpen = $state(false);
  let editingRecord = $state(null);
  let form = $state({ ...EMPTY_FORM });
  let deleteConfirmId = $state('');
  let acknowledgements = $state([]);
  let editorModal = $state(null);
  let editorTitleInput = $state(null);
  let editorTrigger = null;

  let selectedModule = $derived(MODULES.find((module) => module.id === selectedKind) || MODULES[0]);
  let records = $derived(recordsByKind[selectedKind] || []);
  let filteredRecords = $derived.by(() => {
    const query = searchQuery.trim().toLowerCase();
    return records.filter((record) => {
      if (statusFilter !== 'all' && String(record.status || '').toLowerCase() !== statusFilter) return false;
      if (!query) return true;
      return [record.title, record.summary, record.content, record.subjectName, record.reference]
        .some((value) => String(value || '').toLowerCase().includes(query));
    });
  });
  let selectedRecord = $derived(
    filteredRecords.find((record) => String(record.id) === String(selectedId)) || filteredRecords[0] || null,
  );

  function browserRecords(kind) {
    const now = new Date().toISOString();
    const samples = {
      bulletins: [{ id: 'bull:1', title: 'Night shift briefing', summary: 'Construction closure on Olympic Freeway.', content: 'Use the Alta Street diversion until public works clears the northbound lanes.', status: 'active', priority: 'high', visibility: 'all', pinned: true, department: 'police', createdAt: now, updatedAt: now, version: 1, createdBy: { name: 'Sgt. Sarah Alvarez', callsign: '1-S-27' } }],
      awards: [{ id: 'awar:1', title: 'Meritorious Service', subjectName: 'Officer John Doe', summary: 'Recognized for coordinated lifesaving response.', content: 'Awarded following command review.', status: 'approved', reference: 'AWD-2026-014', department: 'police', createdAt: now, updatedAt: now, version: 1 }],
      ia: [{ id: 'ia:1', title: 'Use-of-force review', subjectName: 'Unit 1-A-12', summary: 'Supervisor referral awaiting evidence review.', content: 'Restricted professional-standards record.', status: 'open', priority: 'high', visibility: 'management', department: 'police', createdAt: now, updatedAt: now, version: 2 }],
      ppr: [{ id: 'ppr:1', title: 'Quarterly field performance', subjectName: 'Officer Riley Parker', summary: 'Strong incident control; radio brevity remains a coaching goal.', content: 'Review completed with the employee.', status: 'complete', score: 8.4, visibility: 'management', department: 'police', createdAt: now, updatedAt: now, version: 1 }],
      court: [{ id: 'cour:1', title: 'People v. Carter', subjectName: 'Alex Carter', summary: 'Suppression hearing scheduled.', content: 'Assigned officers should confirm evidence availability before calendar call.', status: 'scheduled', reference: 'CR-26-1842', scheduledAt: '2026-08-18T14:00', location: 'Superior Court, Dept. 4', department: 'police', createdAt: now, updatedAt: now, version: 3 }],
      sops: [{ id: 'sop:1', title: 'Vehicle Pursuit', summary: 'Risk-balanced pursuit and termination requirements.', content: 'Notify dispatch immediately and continuously reassess public risk.', status: 'active', reference: 'SOP-PUR-1.0', visibility: 'all', department: 'police', createdAt: now, updatedAt: now, version: 1 }],
      patrols: [{ id: 'patr:1', title: 'Downtown saturation patrol', summary: 'Evening visible-presence assignment.', content: 'Stage at Mission Row and coordinate two-officer units with dispatch.', status: 'active', priority: 'normal', assignee: 'Watch 2', location: 'Downtown Los Santos', radius: 850, scheduledAt: '2026-08-12T20:00', department: 'police', createdAt: now, updatedAt: now, version: 1 }],
    };
    return samples[kind] || [];
  }

  function recordDate(record) {
    const value = record?.updatedAt || record?.createdAt;
    if (!value) return 'No timestamp';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString();
  }

  function statusLabel(value) {
    return String(value || 'open').replaceAll('_', ' ').toUpperCase();
  }

  function canCreateCurrent() {
    return canManage || selectedKind === 'ia' || selectedKind === 'ppr';
  }

  function acknowledgementFor(record) {
    return acknowledgements.find((row) => (
      String(row.sopId) === String(record?.id)
      && Number(row.sopVersion) === Number(record?.version || 1)
    ));
  }

  async function loadAcknowledgements() {
    if (selectedKind !== 'sops') return;
    if (isEnvBrowser()) {
      acknowledgements = [];
      return;
    }
    const response = await nuiPost('cortex_mdt:getSopAcknowledgements', { includeAll: canManage });
    if (response?.ok) acknowledgements = response.acknowledgements || [];
  }

  async function loadRecords(kind = selectedKind, { quiet = false } = {}) {
    if (!quiet) loading = true;
    errorMessage = '';
    let response;
    if (isEnvBrowser()) {
      response = { ok: true, records: browserRecords(kind), canManage: true };
    } else {
      response = await nuiPost('cortex_mdt:getFeatureRecords', { kind, limit: 250 });
    }
    if (response?.ok) {
      recordsByKind = { ...recordsByKind, [kind]: response.records || [] };
      canManage = response.canManage === true;
      if (kind === selectedKind && !(response.records || []).some((record) => String(record.id) === String(selectedId))) {
        selectedId = String(response.records?.[0]?.id || '');
      }
      await loadAcknowledgements();
    } else {
      errorMessage = response?.error || `Unable to load ${selectedModule.label.toLowerCase()}.`;
    }
    if (!quiet) loading = false;
  }

  async function changeModule(kind) {
    selectedKind = kind;
    searchQuery = '';
    statusFilter = 'all';
    selectedId = '';
    deleteConfirmId = '';
    await loadRecords(kind);
  }

  function openCreate(trigger) {
    editorTrigger = trigger || document.activeElement;
    editingRecord = null;
    form = {
      ...EMPTY_FORM,
      status: selectedKind === 'bulletins' || selectedKind === 'sops' || selectedKind === 'patrols' ? 'active' : 'open',
      visibility: selectedKind === 'bulletins' || selectedKind === 'sops' ? 'all' : selectedKind === 'ia' || selectedKind === 'ppr' ? 'management' : 'department',
    };
    editorOpen = true;
    setTimeout(() => editorTitleInput?.focus(), 0);
  }

  function openEdit(record, trigger) {
    editorTrigger = trigger || document.activeElement;
    editingRecord = record;
    form = { ...EMPTY_FORM, ...record, score: record.score ?? '', radius: record.radius ?? '' };
    editorOpen = true;
    setTimeout(() => editorTitleInput?.focus(), 0);
  }

  async function closeEditor() {
    if (saving) return;
    const trigger = editorTrigger;
    editorOpen = false;
    editingRecord = null;
    form = { ...EMPTY_FORM };
    await tick();
    trigger?.focus?.();
    editorTrigger = null;
  }

  async function saveRecord(event) {
    event.preventDefault();
    if (!form.title.trim()) {
      errorMessage = 'A title is required.';
      return;
    }
    saving = true;
    errorMessage = '';
    const payload = {
      ...form,
      kind: selectedKind,
      score: form.score === '' ? null : Number(form.score),
      radius: form.radius === '' ? null : Number(form.radius),
      ...(editingRecord ? { id: editingRecord.id, version: editingRecord.version } : {}),
    };
    let response;
    if (isEnvBrowser()) {
      response = { ok: true, record: { ...payload, id: editingRecord?.id || `${selectedKind}:preview`, version: (editingRecord?.version || 0) + 1, updatedAt: new Date().toISOString() } };
    } else {
      response = await nuiPost(
        editingRecord ? 'cortex_mdt:updateFeatureRecord' : 'cortex_mdt:createFeatureRecord',
        payload,
      );
    }
    if (response?.ok) {
      const next = records.filter((record) => String(record.id) !== String(response.record.id));
      recordsByKind = { ...recordsByKind, [selectedKind]: [response.record, ...next] };
      selectedId = String(response.record.id);
      saving = false;
      closeEditor();
    } else {
      errorMessage = response?.error || 'The record could not be saved.';
      if (response?.code === 'version_conflict') await loadRecords(selectedKind, { quiet: true });
    }
    saving = false;
  }

  async function deleteRecord(record) {
    if (deleteConfirmId !== String(record.id)) {
      deleteConfirmId = String(record.id);
      return;
    }
    deleting = true;
    const response = isEnvBrowser()
      ? { ok: true }
      : await nuiPost('cortex_mdt:deleteFeatureRecord', { kind: selectedKind, id: record.id });
    if (response?.ok) {
      const next = records.filter((row) => String(row.id) !== String(record.id));
      recordsByKind = { ...recordsByKind, [selectedKind]: next };
      selectedId = String(next[0]?.id || '');
      deleteConfirmId = '';
    } else {
      errorMessage = response?.error || 'The record could not be deleted.';
    }
    deleting = false;
  }

  async function acknowledge(record) {
    const response = isEnvBrowser()
      ? { ok: true, acknowledgement: { sopId: record.id, sopVersion: record.version || 1, acknowledgedAt: new Date().toISOString() } }
      : await nuiPost('cortex_mdt:acknowledgeSop', { id: record.id });
    if (response?.ok) {
      acknowledgements = [
        response.acknowledgement,
        ...acknowledgements.filter((row) => String(row.sopId) !== String(record.id)),
      ];
    } else {
      errorMessage = response?.error || 'The directive could not be acknowledged.';
    }
  }

  function handleWindowKeydown(event) {
    if (!editorOpen) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      closeEditor();
      return;
    }
    if (event.key !== 'Tab' || !editorModal) return;
    const focusable = [...editorModal.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])')];
    if (!focusable.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  onMount(() => loadRecords(selectedKind));
</script>

<svelte:window onkeydown={handleWindowKeydown} />

<div class="command-page">
  <div class="command-rail">
    <nav class="module-tabs" aria-label="Command modules">
      {#each MODULES as module (module.id)}
        {@const ModuleIcon = module.icon}
        <button type="button" class:active={selectedKind === module.id} onclick={() => changeModule(module.id)}>
          <ModuleIcon size={15} />
          <span>{module.label}</span>
          <strong class="font-mono">{(recordsByKind[module.id] || []).length}</strong>
        </button>
      {/each}
    </nav>
    <div class="access-state" class:manager={canManage}>
      {#if canManage}<Check size={14} /> Management access{:else}<FileWarning size={14} /> Restricted access{/if}
    </div>
  </div>

  {#if errorMessage}
    <div class="error-banner" role="alert"><FileWarning size={16} /><span>{errorMessage}</span><button type="button" onclick={() => (errorMessage = '')} aria-label="Dismiss error"><X size={14} /></button></div>
  {/if}

  <section class="command-workspace">
    <aside class="record-index">
      <div class="index-heading">
        <div>
          <span class="font-mono">{selectedModule.id.toUpperCase()}</span>
          <h2>{selectedModule.label}</h2>
        </div>
        <button type="button" class="icon-button" onclick={() => loadRecords(selectedKind)} disabled={loading} aria-label="Refresh records" title="Refresh records"><span class:spin={loading}><RefreshCw size={15} /></span></button>
      </div>
      <p class="module-description">{selectedModule.description}</p>

      <div class="index-tools">
        <label class="search-control"><Search size={14} /><span class="sr-only">Search records</span><input bind:value={searchQuery} type="search" placeholder="Search records" /></label>
        <label><span class="sr-only">Status</span><select bind:value={statusFilter}><option value="all">All states</option><option value="open">Open</option><option value="active">Active</option><option value="scheduled">Scheduled</option><option value="complete">Complete</option><option value="approved">Approved</option><option value="closed">Closed</option><option value="archived">Archived</option></select></label>
      </div>

      {#if canCreateCurrent()}
        <button type="button" class="create-button" onclick={(event) => openCreate(event.currentTarget)}><Plus size={15} /> New {selectedModule.singular}</button>
      {/if}

      <div class="record-list">
        {#if loading}
          <div class="index-state" aria-busy="true"><span class="spin"><RefreshCw size={18} /></span><span>Loading records…</span></div>
        {:else if filteredRecords.length === 0}
          <div class="index-state"><FileWarning size={20} /><span>No records match this view.</span></div>
        {:else}
          {#each filteredRecords as record (record.id)}
            <button type="button" class="record-link" class:active={String(selectedRecord?.id) === String(record.id)} onclick={() => { selectedId = String(record.id); deleteConfirmId = ''; }}>
              <span class="record-link-top"><strong>{record.title}</strong>{#if record.pinned}<span class="pin-mark font-mono">PIN</span>{/if}</span>
              <span>{record.subjectName || record.summary || record.reference || 'No summary provided'}</span>
              <span class="record-link-meta font-mono"><i class:high={record.priority === 'high'}></i>{statusLabel(record.status)} · {recordDate(record)}</span>
              <ChevronRight size={14} />
            </button>
          {/each}
        {/if}
      </div>
    </aside>

    <article class="record-detail">
      {#if selectedRecord}
        <div class="detail-tape font-mono">
          <span>{selectedRecord.reference || selectedRecord.id}</span>
          <span>REV {selectedRecord.version || 1}</span>
          <span>{String(selectedRecord.department || 'police').toUpperCase()}</span>
          <span>{statusLabel(selectedRecord.status)}</span>
        </div>
        <header class="detail-header">
          <div>
            <span class="detail-kind font-mono">{selectedModule.singular.toUpperCase()}</span>
            <h2>{selectedRecord.title}</h2>
            {#if selectedRecord.summary}<p>{selectedRecord.summary}</p>{/if}
          </div>
          {#if canManage}
            <div class="detail-actions">
              <button type="button" class="secondary-button" onclick={(event) => openEdit(selectedRecord, event.currentTarget)}><Pencil size={14} /> Edit</button>
              <button type="button" class="danger-button" onclick={() => deleteRecord(selectedRecord)} disabled={deleting}><Trash2 size={14} />{deleteConfirmId === String(selectedRecord.id) ? 'Confirm delete' : 'Delete'}</button>
            </div>
          {/if}
        </header>

        <dl class="record-facts">
          {#if selectedRecord.subjectName}<div><dt>Subject</dt><dd>{selectedRecord.subjectName}{#if selectedRecord.subjectId} <span class="font-mono">{selectedRecord.subjectId}</span>{/if}</dd></div>{/if}
          {#if selectedRecord.assignee}<div><dt>Assigned</dt><dd>{selectedRecord.assignee}</dd></div>{/if}
          {#if selectedRecord.location}<div><dt>Location</dt><dd>{selectedRecord.location}</dd></div>{/if}
          {#if selectedRecord.scheduledAt}<div><dt>Scheduled</dt><dd>{selectedRecord.scheduledAt}</dd></div>{/if}
          {#if selectedRecord.incidentAt}<div><dt>Incident date</dt><dd>{selectedRecord.incidentAt}</dd></div>{/if}
          {#if selectedRecord.reporterContact}<div><dt>Reporter contact</dt><dd>{selectedRecord.reporterContact}</dd></div>{/if}
          {#if selectedRecord.score != null}<div><dt>Score</dt><dd>{selectedRecord.score} / 10</dd></div>{/if}
          {#if selectedRecord.radius}<div><dt>Patrol radius</dt><dd>{selectedRecord.radius} m</dd></div>{/if}
          <div><dt>Visibility</dt><dd>{statusLabel(selectedRecord.visibility || 'department')}</dd></div>
          <div><dt>Updated</dt><dd>{recordDate(selectedRecord)}</dd></div>
        </dl>

        <section class="record-content">
          <h3>Record</h3>
          <p>{selectedRecord.content || 'No detailed narrative has been entered.'}</p>
        </section>
        {#if selectedRecord.witnesses}
          <section class="record-supplement"><h3>Witnesses</h3><p>{selectedRecord.witnesses}</p></section>
        {/if}
        {#if selectedRecord.evidence?.length}
          <section class="record-supplement"><h3>Evidence links</h3><ul>{#each selectedRecord.evidence as url (url)}<li><code>{url}</code></li>{/each}</ul></section>
        {/if}

        <footer class="record-footer">
          <div>
            <span class="font-mono">AUTHORITY</span>
            <p>{selectedRecord.updatedBy?.name || selectedRecord.createdBy?.name || 'Cortex MDT'}{#if selectedRecord.createdBy?.callsign} · {selectedRecord.createdBy.callsign}{/if}</p>
          </div>
          {#if selectedKind === 'sops'}
            {#if acknowledgementFor(selectedRecord)}
              <span class="ack-state"><Check size={14} /> Acknowledged {recordDate({ updatedAt: acknowledgementFor(selectedRecord).acknowledgedAt })}</span>
            {:else}
              <button type="button" class="ack-button" onclick={() => acknowledge(selectedRecord)}><BookOpenCheck size={15} /> Acknowledge directive</button>
            {/if}
          {/if}
        </footer>
      {:else}
        <div class="detail-empty">
          <Landmark size={28} />
          <h2>No {selectedModule.label.toLowerCase()} in this view</h2>
          <p>{filteredRecords.length === 0 && records.length > 0 ? 'Clear the search or status filter to see available records.' : selectedModule.description}</p>
          {#if canCreateCurrent()}
            <button type="button" class="create-button detail-create" onclick={(event) => openCreate(event.currentTarget)}><Plus size={15} /> New {selectedModule.singular}</button>
          {/if}
        </div>
      {/if}
    </article>
  </section>
</div>

{#if editorOpen}
  <div class="modal-backdrop" role="presentation" onclick={(event) => { if (event.target === event.currentTarget) closeEditor(); }}>
    <div class="editor-modal" role="dialog" aria-modal="true" aria-labelledby="command-editor-title" tabindex="-1" bind:this={editorModal}>
      <header><div><span class="font-mono">{selectedKind.toUpperCase()}</span><h2 id="command-editor-title">{editingRecord ? 'Edit' : 'Create'} {selectedModule.singular}</h2></div><button type="button" class="icon-button" onclick={closeEditor} aria-label="Close editor"><X size={16} /></button></header>
      <form onsubmit={saveRecord}>
        <div class="form-grid">
          <label class="wide"><span>Title *</span><input bind:this={editorTitleInput} bind:value={form.title} maxlength="160" required /></label>
          <label><span>Status</span><select bind:value={form.status}><option value="open">Open</option><option value="active">Active</option><option value="scheduled">Scheduled</option><option value="complete">Complete</option><option value="approved">Approved</option><option value="closed">Closed</option><option value="archived">Archived</option></select></label>
          <label><span>Priority</span><select bind:value={form.priority}><option value="low">Low</option><option value="normal">Normal</option><option value="high">High</option><option value="critical">Critical</option></select></label>
          <label class="wide"><span>Summary</span><input bind:value={form.summary} maxlength="1200" /></label>
          {#if ['awards', 'ia', 'ppr', 'court'].includes(selectedKind)}<label><span>Subject name</span><input bind:value={form.subjectName} maxlength="160" /></label><label><span>Subject ID</span><input bind:value={form.subjectId} maxlength="96" /></label>{/if}
          {#if ['awards', 'court', 'sops'].includes(selectedKind)}<label><span>Reference</span><input bind:value={form.reference} maxlength="96" placeholder="Optional record number" /></label>{/if}
          {#if ['ia', 'ppr', 'court', 'patrols'].includes(selectedKind)}<label><span>Assignee</span><input bind:value={form.assignee} maxlength="160" /></label>{/if}
          {#if ['court', 'patrols'].includes(selectedKind)}<label><span>Location</span><input bind:value={form.location} maxlength="180" /></label><label><span>Scheduled</span><input bind:value={form.scheduledAt} type="datetime-local" /></label>{/if}
          {#if selectedKind === 'ppr'}<label><span>Score (0–10)</span><input bind:value={form.score} type="number" min="0" max="10" step="0.1" /></label>{/if}
          {#if selectedKind === 'patrols'}<label><span>Radius (25–5000 m)</span><input bind:value={form.radius} type="number" min="25" max="5000" /></label>{/if}
          <label><span>Visibility</span><select bind:value={form.visibility}><option value="department">Department</option><option value="all">All departments</option><option value="management">Management</option></select></label>
          <label class="check-row"><input bind:checked={form.pinned} type="checkbox" /><span>Pin this record</span></label>
          <label class="wide"><span>Detailed record</span><textarea bind:value={form.content} maxlength="12000" rows="8"></textarea></label>
        </div>
        <footer><button type="button" class="secondary-button" onclick={closeEditor}>Cancel</button><button type="submit" class="save-button" disabled={saving}>{#if saving}<span class="spin"><RefreshCw size={14} /></span>{:else}<Check size={14} />{/if}{saving ? 'Saving…' : 'Save record'}</button></footer>
      </form>
    </div>
  </div>
{/if}

<style>
  .font-mono { font-family: 'Share Tech Mono', monospace; }
  .sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
  .command-page { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: calc(10px * var(--mdt-scale)); padding: calc(12px * var(--mdt-scale)); color: var(--mdt-text); overflow: hidden; }
  .command-rail { display: flex; align-items: stretch; gap: calc(8px * var(--mdt-scale)); min-width: 0; }
  .access-state { display: inline-flex; align-items: center; gap: calc(6px * var(--mdt-scale)); padding: 0 calc(10px * var(--mdt-scale)); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface); color: var(--mdt-warning); font-size: calc(10px * var(--mdt-scale)); white-space: nowrap; }
  .access-state.manager { color: var(--mdt-success); }
  button, input, select, textarea { font: inherit; }
  button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible { outline: 2px solid var(--mdt-accent); outline-offset: 2px; }
  button:disabled { opacity: .45; cursor: not-allowed; }

  .module-tabs { flex: 1; min-width: 0; display: flex; gap: calc(2px * var(--mdt-scale)); min-height: calc(38px * var(--mdt-scale)); padding: calc(3px * var(--mdt-scale)); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); overflow-x: auto; background: var(--mdt-chrome); }
  .module-tabs button { flex: 1 0 auto; display: inline-grid; grid-template-columns: auto 1fr auto; align-items: center; gap: calc(7px * var(--mdt-scale)); min-width: calc(116px * var(--mdt-scale)); padding: 0 calc(9px * var(--mdt-scale)); border: 0; border-radius: var(--mdt-radius-sm); background: transparent; color: var(--mdt-text-muted); cursor: pointer; }
  .module-tabs button:hover { color: var(--mdt-text); background: var(--mdt-surface-2); }
  .module-tabs button.active { color: var(--mdt-text); background: var(--mdt-surface-3); box-shadow: inset 0 -2px 0 var(--mdt-accent); }
  .module-tabs strong { color: var(--mdt-text-dim); font-size: calc(10px * var(--mdt-scale)); }
  .error-banner { display: flex; align-items: center; gap: calc(8px * var(--mdt-scale)); padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale)); border: 1px solid color-mix(in srgb, var(--mdt-error) 45%, var(--mdt-border)); border-radius: var(--mdt-radius-sm); color: var(--mdt-error); background: var(--mdt-surface); font-size: calc(10px * var(--mdt-scale)); }
  .error-banner span { flex: 1; }
  .error-banner button { display: inline-flex; border: 0; background: transparent; color: inherit; cursor: pointer; }

  .command-workspace { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(calc(280px * var(--mdt-scale)), calc(350px * var(--mdt-scale))) minmax(0, 1fr); gap: calc(10px * var(--mdt-scale)); }
  .record-index, .record-detail { border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); background: var(--mdt-surface); overflow: hidden; }
  .record-index { min-height: 0; display: flex; flex-direction: column; }
  .index-heading { display: flex; align-items: center; justify-content: space-between; gap: calc(10px * var(--mdt-scale)); padding: calc(12px * var(--mdt-scale)) calc(13px * var(--mdt-scale)) calc(6px * var(--mdt-scale)); }
  .index-heading span, .detail-kind { color: var(--mdt-accent); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .08em; }
  .index-heading h2 { margin: calc(3px * var(--mdt-scale)) 0 0; font-size: calc(16px * var(--mdt-scale)); }
  .module-description { margin: 0; padding: 0 calc(13px * var(--mdt-scale)) calc(10px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); color: var(--mdt-text-muted); font-size: calc(11px * var(--mdt-scale)); line-height: 1.45; }
  .icon-button { display: inline-flex; align-items: center; justify-content: center; width: calc(32px * var(--mdt-scale)); height: calc(32px * var(--mdt-scale)); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text-muted); cursor: pointer; }
  .icon-button:hover { color: var(--mdt-text); border-color: var(--mdt-accent); }
  .index-tools { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: calc(6px * var(--mdt-scale)); padding: calc(9px * var(--mdt-scale)) calc(10px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .search-control { display: flex; align-items: center; gap: calc(6px * var(--mdt-scale)); min-width: 0; padding: 0 calc(8px * var(--mdt-scale)); color: var(--mdt-text-muted); }
  .search-control, select, input, textarea { border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text); }
  .search-control:focus-within { border-color: var(--mdt-accent); }
  .search-control input { flex: 1; min-width: 0; border: 0; background: transparent; }
  .index-tools select { height: calc(34px * var(--mdt-scale)); padding: 0 calc(8px * var(--mdt-scale)); font-size: calc(10px * var(--mdt-scale)); }
  .create-button, .save-button, .ack-button { display: inline-flex; align-items: center; justify-content: center; gap: calc(7px * var(--mdt-scale)); min-height: calc(34px * var(--mdt-scale)); margin: calc(9px * var(--mdt-scale)) calc(10px * var(--mdt-scale)); border: 0; border-radius: var(--mdt-radius-sm); background: var(--mdt-accent); color: var(--mdt-bg); font-size: calc(10px * var(--mdt-scale)); font-weight: 700; cursor: pointer; }
  .record-list { flex: 1; min-height: 0; overflow-y: auto; }
  .record-link { position: relative; display: flex; flex-direction: column; gap: calc(4px * var(--mdt-scale)); width: 100%; min-height: calc(72px * var(--mdt-scale)); padding: calc(9px * var(--mdt-scale)) calc(28px * var(--mdt-scale)) calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border: 0; border-bottom: 1px solid var(--mdt-border); border-left: 2px solid transparent; border-radius: 0; background: transparent; color: var(--mdt-text-muted); text-align: left; cursor: pointer; }
  .record-link:hover { background: var(--mdt-surface-2); color: var(--mdt-text-dim); }
  .record-link.active { border-left-color: var(--mdt-accent); background: var(--mdt-surface-2); }
  .record-link :global(svg:last-child) { position: absolute; right: calc(9px * var(--mdt-scale)); top: 50%; transform: translateY(-50%); }
  .record-link-top { display: flex; align-items: center; gap: calc(7px * var(--mdt-scale)); }
  .record-link strong { min-width: 0; overflow: hidden; color: var(--mdt-text); font-size: calc(11px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .pin-mark { color: var(--mdt-accent); font-size: calc(9px * var(--mdt-scale)); }
  .record-link > span:nth-child(2) { overflow: hidden; font-size: calc(10px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .record-link-meta { display: flex; align-items: center; gap: calc(5px * var(--mdt-scale)); font-size: calc(9px * var(--mdt-scale)); }
  .record-link-meta i { width: calc(5px * var(--mdt-scale)); height: calc(5px * var(--mdt-scale)); background: var(--mdt-success); }
  .record-link-meta i.high { background: var(--mdt-warning); }
  .index-state { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: calc(8px * var(--mdt-scale)); min-height: calc(170px * var(--mdt-scale)); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); }

  .record-detail { min-width: 0; min-height: 0; display: flex; flex-direction: column; overflow-y: auto; padding: 0 calc(20px * var(--mdt-scale)) calc(18px * var(--mdt-scale)); }
  .detail-tape { position: sticky; top: 0; z-index: 2; display: flex; flex-wrap: wrap; gap: calc(6px * var(--mdt-scale)) calc(14px * var(--mdt-scale)); min-height: calc(38px * var(--mdt-scale)); align-items: center; border-bottom: 1px solid var(--mdt-border); background: var(--mdt-surface); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .07em; }
  .detail-tape span:first-child { color: var(--mdt-accent); }
  .detail-header { display: flex; align-items: flex-start; justify-content: space-between; gap: calc(16px * var(--mdt-scale)); padding: calc(18px * var(--mdt-scale)) 0 calc(14px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .detail-header h2 { margin: calc(5px * var(--mdt-scale)) 0 0; font-size: calc(19px * var(--mdt-scale)); line-height: 1.25; }
  .detail-header p { max-width: 70ch; margin: calc(7px * var(--mdt-scale)) 0 0; color: var(--mdt-text-muted); font-size: calc(12px * var(--mdt-scale)); line-height: 1.5; }
  .detail-actions { display: flex; align-items: center; gap: calc(7px * var(--mdt-scale)); }
  .secondary-button, .danger-button { display: inline-flex; align-items: center; justify-content: center; gap: calc(6px * var(--mdt-scale)); min-height: calc(32px * var(--mdt-scale)); padding: 0 calc(10px * var(--mdt-scale)); border: 1px solid var(--mdt-border-2); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text-dim); font-size: calc(9px * var(--mdt-scale)); cursor: pointer; }
  .danger-button { color: var(--mdt-error); }
  .record-facts { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); margin: 0; border-bottom: 1px solid var(--mdt-border); }
  .record-facts > div { display: grid; grid-template-columns: minmax(calc(90px * var(--mdt-scale)), .4fr) minmax(0, 1fr); gap: calc(8px * var(--mdt-scale)); padding: calc(10px * var(--mdt-scale)) 0; border-bottom: 1px solid var(--mdt-border); }
  .record-facts > div:nth-child(odd) { padding-right: calc(14px * var(--mdt-scale)); border-right: 1px solid var(--mdt-border); }
  .record-facts > div:nth-child(even) { padding-left: calc(14px * var(--mdt-scale)); }
  dt { color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); text-transform: uppercase; letter-spacing: .06em; }
  dd { margin: 0; color: var(--mdt-text-dim); font-size: calc(11px * var(--mdt-scale)); overflow-wrap: anywhere; }
  .record-content { flex: 1; padding: calc(16px * var(--mdt-scale)) 0; }
  .record-content h3 { margin: 0; color: var(--mdt-text-muted); font-size: calc(9px * var(--mdt-scale)); letter-spacing: .08em; text-transform: uppercase; }
  .record-content p { max-width: 78ch; margin: calc(10px * var(--mdt-scale)) 0 0; color: var(--mdt-text-dim); font-size: calc(12px * var(--mdt-scale)); line-height: 1.7; white-space: pre-wrap; }
  .record-supplement { padding: calc(12px * var(--mdt-scale)) 0; border-top: 1px solid var(--mdt-border); }
  .record-supplement h3 { margin: 0; color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .08em; text-transform: uppercase; }
  .record-supplement p, .record-supplement ul { margin: calc(8px * var(--mdt-scale)) 0 0; color: var(--mdt-text-dim); font-size: calc(11px * var(--mdt-scale)); line-height: 1.55; white-space: pre-wrap; }
  .record-supplement ul { padding-left: calc(18px * var(--mdt-scale)); }
  .record-supplement code { overflow-wrap: anywhere; color: var(--mdt-accent); }
  .record-footer { display: flex; align-items: flex-end; justify-content: space-between; gap: calc(14px * var(--mdt-scale)); padding-top: calc(12px * var(--mdt-scale)); border-top: 1px solid var(--mdt-border); }
  .record-footer > div > span { color: var(--mdt-text-muted); font-size: calc(9px * var(--mdt-scale)); letter-spacing: .08em; }
  .record-footer p { margin: calc(3px * var(--mdt-scale)) 0 0; color: var(--mdt-text-dim); font-size: calc(11px * var(--mdt-scale)); }
  .ack-button { margin: 0; padding: 0 calc(11px * var(--mdt-scale)); }
  .ack-state { display: inline-flex; align-items: center; gap: calc(6px * var(--mdt-scale)); color: var(--mdt-success); font-size: calc(9px * var(--mdt-scale)); }
  .detail-empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: calc(8px * var(--mdt-scale)); color: var(--mdt-text-muted); text-align: center; }
  .detail-empty h2 { margin: 0; color: var(--mdt-text-dim); font-size: calc(15px * var(--mdt-scale)); }
  .detail-empty p { margin: 0; font-size: calc(10px * var(--mdt-scale)); }
  .detail-empty > :global(svg) { color: var(--mdt-accent); }
  .detail-create { flex: 0 0 auto; margin: calc(4px * var(--mdt-scale)) 0 0; padding: 0 calc(12px * var(--mdt-scale)); }

  .modal-backdrop { position: fixed; inset: 0; z-index: 80; display: flex; align-items: center; justify-content: center; padding: calc(22px * var(--mdt-scale)); background: color-mix(in srgb, var(--mdt-bg) 76%, transparent); }
  .editor-modal { width: min(calc(760px * var(--mdt-scale)), 94vw); max-height: 90vh; display: flex; flex-direction: column; border: 1px solid var(--mdt-border-2); border-radius: var(--mdt-radius); background: var(--mdt-bg); box-shadow: 0 calc(20px * var(--mdt-scale)) calc(60px * var(--mdt-scale)) color-mix(in srgb, var(--mdt-bg) 70%, transparent); overflow: hidden; }
  .editor-modal > header { display: flex; align-items: center; justify-content: space-between; gap: calc(12px * var(--mdt-scale)); padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); background: var(--mdt-chrome); }
  .editor-modal header span { color: var(--mdt-accent); font-size: calc(8px * var(--mdt-scale)); letter-spacing: .1em; }
  .editor-modal h2 { margin: calc(3px * var(--mdt-scale)) 0 0; font-size: calc(15px * var(--mdt-scale)); }
  .editor-modal form { min-height: 0; display: flex; flex-direction: column; }
  .form-grid { min-height: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: calc(11px * var(--mdt-scale)); padding: calc(14px * var(--mdt-scale)); overflow-y: auto; }
  .form-grid label { display: flex; flex-direction: column; gap: calc(5px * var(--mdt-scale)); min-width: 0; color: var(--mdt-text-dim); font-size: calc(9px * var(--mdt-scale)); font-weight: 600; }
  .form-grid .wide { grid-column: 1 / -1; }
  .form-grid input, .form-grid select, .form-grid textarea { width: 100%; min-height: calc(34px * var(--mdt-scale)); padding: calc(7px * var(--mdt-scale)) calc(8px * var(--mdt-scale)); font-size: calc(10px * var(--mdt-scale)); }
  .form-grid textarea { resize: vertical; min-height: calc(130px * var(--mdt-scale)); line-height: 1.5; }
  .form-grid .check-row { flex-direction: row; align-items: center; align-self: end; min-height: calc(34px * var(--mdt-scale)); }
  .check-row input { width: calc(16px * var(--mdt-scale)); min-height: 0; height: calc(16px * var(--mdt-scale)); accent-color: var(--mdt-accent); }
  .editor-modal form > footer { display: flex; justify-content: flex-end; gap: calc(8px * var(--mdt-scale)); padding: calc(11px * var(--mdt-scale)) calc(14px * var(--mdt-scale)); border-top: 1px solid var(--mdt-border); background: var(--mdt-chrome); }
  .save-button { min-width: calc(120px * var(--mdt-scale)); margin: 0; padding: 0 calc(12px * var(--mdt-scale)); }
  .spin { animation: spin .8s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  @media (prefers-reduced-motion: reduce) { .spin { animation: none; } }

  @media (max-width: 980px) {
    .command-page { overflow-y: auto; }
    .command-workspace { flex: 0 0 auto; display: flex; flex-direction: column; }
    .record-index { flex: 0 0 calc(320px * var(--mdt-scale)); min-height: calc(260px * var(--mdt-scale)); max-height: calc(420px * var(--mdt-scale)); }
    .record-detail { flex: 0 0 auto; min-height: calc(480px * var(--mdt-scale)); }
  }
  @media (max-width: 620px) {
    .command-rail { flex-direction: column; }
    .module-tabs { border-radius: var(--mdt-radius-sm); }
    .access-state { min-height: calc(34px * var(--mdt-scale)); border-radius: var(--mdt-radius-sm); }
    .detail-header, .record-footer { align-items: stretch; flex-direction: column; }
    .detail-actions { width: 100%; }
    .detail-actions button { flex: 1; }
    .record-facts { grid-template-columns: 1fr; }
    .record-facts > div:nth-child(n) { padding-left: 0; padding-right: 0; border-right: 0; }
    .form-grid { grid-template-columns: 1fr; }
    .form-grid label { grid-column: 1 !important; }
  }
</style>
