<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const TEMPLATES = [
    'General Report',
    'Arrest Report',
    'Traffic Citation',
    'Use of Force',
    'Incident Report',
  ];

  const PRIORITIES = ['low', 'normal', 'high', 'critical'];

  const STATUS_ACTIONS = [
    { status: 'draft', label: 'Draft' },
    { status: 'submitted', label: 'Submit for Review' },
    { status: 'approved', label: 'Approve' },
    { status: 'rejected', label: 'Reject' },
    { status: 'archived', label: 'Archive' },
  ];

  const PRIORITY_COLORS = {
    low: 'var(--mdt-text-muted)',
    normal: 'var(--mdt-accent)',
    high: 'var(--mdt-warning)',
    critical: 'var(--mdt-error)',
  };

  const STATUS_COLORS = {
    draft: 'var(--mdt-text-muted)',
    submitted: 'var(--mdt-accent)',
    approved: 'var(--mdt-success)',
    rejected: 'var(--mdt-error)',
    archived: 'var(--mdt-text-muted)',
    open: 'var(--mdt-warning)',
    closed: 'var(--mdt-success)',
  };

  const ENTITY_ICONS = {
    citizen: 'M12 8a4 4 0 100-8 4 4 0 000 8zm-8 13a8 8 0 0116 0',
    vehicle: 'M5 17h14M5 17a2 2 0 01-2-2V9a2 2 0 012-2h1l2-3h8l2 3h1a2 2 0 012 2v6a2 2 0 01-2 2M5 17v2m14-2v2',
    evidence: 'M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8zM14 2v6h6',
  };

  let mode = $state('list');
  let activeFilter = $state('all');
  let currentPage = $state(1);
  let mounted = $state(false);
  let saving = $state(false);
  let confirmAction = $state(null);

  let createTitle = $state('');
  let createTemplate = $state(TEMPLATES[0]);
  let createNarrative = $state('');
  let createTagInput = $state('');
  let createTags = $state([]);

  let editTitle = $state('');
  let editNarrative = $state('');
  let editPriority = $state('normal');
  let editTags = $state([]);
  let editTagInput = $state('');

  let timelineDesc = $state('');
  let timelineTime = $state('');

  let reports = $derived(dataStore.reportsList || []);
  let total = $derived(dataStore.reportsTotal || 0);
  let report = $derived(dataStore.selectedReport);
  let timeline = $derived(dataStore.reportTimeline || []);
  let entities = $derived(dataStore.reportEntities || []);
  let collaborators = $derived(dataStore.reportCollaborators || []);
  let officer = $derived(mdtStore.officer);

  let totalPages = $derived(Math.max(1, Math.ceil(total / 15)));

  $effect(() => {
    if (report) {
      editTitle = report.title || '';
      editNarrative = report.narrative || '';
      editPriority = report.priority || 'normal';
      editTags = [...(report.tags || [])];
    }
  });

  function formatDate(dateStr) {
    if (!dateStr) return '\u2014';
    try {
      const d = new Date(dateStr);
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    } catch {
      return dateStr;
    }
  }

  function formatDateTime(dateStr) {
    if (!dateStr) return '\u2014';
    try {
      const d = new Date(dateStr);
      return d.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    } catch {
      return dateStr;
    }
  }

  function getStatusColor(status) {
    return STATUS_COLORS[status] || 'var(--mdt-text-muted)';
  }

  function getPriorityColor(priority) {
    return PRIORITY_COLORS[priority] || 'var(--mdt-text-muted)';
  }

  async function loadReports() {
    await dataStore.fetchReports(currentPage, activeFilter);
  }

  function switchFilter(filter) {
    activeFilter = filter;
    currentPage = 1;
    loadReports();
  }

  function prevPage() {
    if (currentPage > 1) {
      currentPage--;
      loadReports();
    }
  }

  function nextPage() {
    if (currentPage < totalPages) {
      currentPage++;
      loadReports();
    }
  }

  function openCreate() {
    createTitle = '';
    createTemplate = TEMPLATES[0];
    createNarrative = '';
    createTags = [];
    createTagInput = '';
    mode = 'create';
  }

  function openDetail(reportId) {
    dataStore.getReport(reportId);
    mode = 'detail';
  }

  function goBackToList() {
    dataStore.selectedReport = null;
    dataStore.reportTimeline = [];
    dataStore.reportEntities = [];
    dataStore.reportCollaborators = [];
    confirmAction = null;
    mode = 'list';
    loadReports();
  }

  function handleCreateTagKey(e) {
    if (e.key === 'Enter' && createTagInput.trim()) {
      e.preventDefault();
      const tag = createTagInput.trim().toLowerCase();
      if (!createTags.includes(tag)) {
        createTags = [...createTags, tag];
      }
      createTagInput = '';
    }
  }

  function removeCreateTag(tag) {
    createTags = createTags.filter(t => t !== tag);
  }

  function handleEditTagKey(e) {
    if (e.key === 'Enter' && editTagInput.trim()) {
      e.preventDefault();
      const tag = editTagInput.trim().toLowerCase();
      if (!editTags.includes(tag)) {
        editTags = [...editTags, tag];
      }
      editTagInput = '';
    }
  }

  function removeEditTag(tag) {
    editTags = editTags.filter(t => t !== tag);
  }

  async function handleCreate() {
    if (!createTitle.trim()) return;
    saving = true;
    const resp = await dataStore.createReport({
      title: createTitle.trim(),
      template: createTemplate,
      narrative: createNarrative,
      tags: createTags,
    });
    saving = false;
    if (resp?.ok && resp.reportId) {
      await dataStore.getReport(resp.reportId);
      mode = 'detail';
    } else if (isEnvBrowser()) {
      dataStore.selectedReport = {
        id: 999,
        report_number: 'RPT-20260321-0001',
        title: createTitle.trim(),
        template: createTemplate,
        narrative: createNarrative,
        tags: createTags,
        status: 'draft',
        priority: 'normal',
        author_name: `${officer.firstName} ${officer.lastName}`,
        created_at: new Date().toISOString(),
      };
      dataStore.reportTimeline = [];
      dataStore.reportEntities = [];
      dataStore.reportCollaborators = [{ name: `${officer.firstName} ${officer.lastName}`, callsign: officer.callsign }];
      mode = 'detail';
    }
  }

  async function handleSave() {
    if (!report) return;
    saving = true;
    await dataStore.updateReport({
      reportId: report.id,
      title: editTitle.trim(),
      narrative: editNarrative,
      tags: editTags,
      priority: editPriority,
    });
    saving = false;
  }

  async function handleStatusChange(newStatus) {
    if (!report) return;
    confirmAction = null;
    saving = true;
    await dataStore.updateReport({
      reportId: report.id,
      status: newStatus,
    });
    if (isEnvBrowser()) {
      dataStore.selectedReport = { ...report, status: newStatus };
    }
    saving = false;
  }

  async function handleAddTimeline() {
    if (!report || !timelineDesc.trim()) return;
    saving = true;
    const resp = await dataStore.addTimeline({
      reportId: report.id,
      timestamp: timelineTime || new Date().toISOString(),
      description: timelineDesc.trim(),
    });
    if (isEnvBrowser()) {
      dataStore.reportTimeline = [
        ...timeline,
        {
          id: Date.now(),
          timestamp: timelineTime || new Date().toISOString(),
          description: timelineDesc.trim(),
          author_name: `${officer.firstName} ${officer.lastName}`,
        },
      ];
    }
    timelineDesc = '';
    timelineTime = '';
    saving = false;
  }

  async function handleRemoveEntity(entityId) {
    saving = true;
    await dataStore.removeEntity(entityId);
    if (isEnvBrowser()) {
      dataStore.reportEntities = entities.filter(e => e.id !== entityId);
    }
    saving = false;
  }

  onMount(() => {
    mounted = true;

    if (isEnvBrowser()) {
      dataStore.reportsList = [
        { id: 1, report_number: 'RPT-20260315-0042', title: 'Armed Robbery — Fleeca Bank, Hawick', author_name: 'Ofc. Rivera', status: 'submitted', priority: 'high', created_at: '2026-03-15T14:30:00Z' },
        { id: 2, report_number: 'RPT-20260315-0041', title: 'Traffic Stop — Failure to Yield', author_name: 'Ofc. Chen', status: 'approved', priority: 'normal', created_at: '2026-03-15T11:15:00Z' },
        { id: 3, report_number: 'RPT-20260314-0040', title: 'Aggravated Assault — Davis Ave', author_name: 'Det. Nakamura', status: 'draft', priority: 'critical', created_at: '2026-03-14T22:45:00Z' },
        { id: 4, report_number: 'RPT-20260314-0039', title: 'Vehicle Pursuit — Stolen Sultan RS', author_name: 'Ofc. Park', status: 'submitted', priority: 'high', created_at: '2026-03-14T18:20:00Z' },
        { id: 5, report_number: 'RPT-20260313-0038', title: 'Noise Complaint — Vinewood Hills', author_name: 'Ofc. Rivera', status: 'archived', priority: 'low', created_at: '2026-03-13T09:00:00Z' },
        { id: 6, report_number: 'RPT-20260313-0037', title: 'Use of Force — Suspect Resisting Arrest', author_name: 'Sgt. Delgado', status: 'approved', priority: 'high', created_at: '2026-03-13T03:30:00Z' },
        { id: 7, report_number: 'RPT-20260312-0036', title: 'Missing Person — Diana Vasquez', author_name: 'Det. Kim', status: 'submitted', priority: 'normal', created_at: '2026-03-12T16:00:00Z' },
      ];
      dataStore.reportsTotal = 7;
    } else {
      loadReports();
    }
  });
</script>

<div class="reports-page" class:mounted>
  {#if mode === 'list'}
    <div class="list-mode">
      <div class="page-header">
        <div class="header-left">
          <h2 class="page-title">Incident Reports</h2>
          <p class="page-subtitle">Manage and review officer reports</p>
        </div>
        <button class="btn-new" onclick={openCreate}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
          </svg>
          <span>New Report</span>
        </button>
      </div>

      <div class="filter-bar">
        {#each [['all', 'All'], ['mine', 'My Reports'], ['submitted', 'Submitted'], ['draft', 'Drafts']] as [key, label]}
          <button
            class="filter-tab"
            class:active={activeFilter === key}
            onclick={() => switchFilter(key)}
          >{label}</button>
        {/each}
      </div>

      {#if reports.length > 0}
        <div class="reports-table">
          <div class="table-header">
            <span class="th-num">Report #</span>
            <span class="th-title">Title</span>
            <span class="th-author">Author</span>
            <span class="th-status">Status</span>
            <span class="th-priority">Priority</span>
            <span class="th-date">Date</span>
          </div>
          {#each reports as row, i (row.id || i)}
            <button class="table-row" onclick={() => openDetail(row.id)}>
              <span class="td-num font-mono">{row.report_number || row.id}</span>
              <span class="td-title">{row.title || '\u2014'}</span>
              <span class="td-author">{row.author_name || (row.author_first ? `${row.author_first} ${row.author_last}` : '\u2014')}</span>
              <span class="td-status">
                <span class="status-badge" style="--badge-color: {getStatusColor(row.status)}">{row.status || '\u2014'}</span>
              </span>
              <span class="td-priority">
                <span class="priority-dot" style="background: {getPriorityColor(row.priority)}"></span>
                <span class="priority-label" style="color: {getPriorityColor(row.priority)}">{row.priority || 'normal'}</span>
              </span>
              <span class="td-date font-mono">{formatDate(row.created_at)}</span>
            </button>
          {/each}
        </div>

        <div class="pagination">
          <button class="page-btn" disabled={currentPage <= 1} onclick={prevPage}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6" /></svg>
          </button>
          <span class="page-indicator font-mono">{currentPage} / {totalPages}</span>
          <button class="page-btn" disabled={currentPage >= totalPages} onclick={nextPage}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6" /></svg>
          </button>
        </div>
      {:else}
        <div class="empty-state">
          <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" />
            <line x1="9" y1="13" x2="15" y2="13" />
          </svg>
          <p class="empty-text">No reports found</p>
          <p class="empty-sub">Create a new report to get started</p>
        </div>
      {/if}
    </div>

  {:else if mode === 'create'}
    <div class="create-mode">
      <button class="back-btn" onclick={() => { mode = 'list'; }}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to Reports</span>
      </button>

      <h2 class="section-title">Create Report</h2>

      <div class="form-card">
        <div class="form-group">
          <label class="form-label">Title</label>
          <input
            type="text"
            class="form-input"
            placeholder="Enter report title..."
            bind:value={createTitle}
          />
        </div>

        <div class="form-group">
          <label class="form-label">Template</label>
          <select class="form-select" bind:value={createTemplate}>
            {#each TEMPLATES as tmpl}
              <option value={tmpl}>{tmpl}</option>
            {/each}
          </select>
        </div>

        <div class="form-group">
          <label class="form-label">Tags</label>
          <div class="tags-wrapper">
            {#each createTags as tag (tag)}
              <span class="tag-pill">
                <span>{tag}</span>
                <button class="tag-remove" onclick={() => removeCreateTag(tag)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12" /></svg>
                </button>
              </span>
            {/each}
            <input
              type="text"
              class="tag-input"
              placeholder={createTags.length === 0 ? 'Type and press Enter...' : ''}
              bind:value={createTagInput}
              onkeydown={handleCreateTagKey}
            />
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Narrative</label>
          <textarea
            class="form-textarea"
            placeholder="Describe the incident in detail..."
            bind:value={createNarrative}
            rows="10"
          ></textarea>
        </div>

        <div class="form-actions">
          <button class="btn-cancel" onclick={() => { mode = 'list'; }}>Cancel</button>
          <button class="btn-primary" onclick={handleCreate} disabled={!createTitle.trim() || saving}>
            {saving ? 'Creating...' : 'Create Report'}
          </button>
        </div>
      </div>
    </div>

  {:else if mode === 'detail' && report}
    <div class="detail-mode">
      <button class="back-btn" onclick={goBackToList}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to Reports</span>
      </button>

      <div class="detail-header">
        <div class="detail-header-left">
          <span class="report-number font-mono">{report.report_number || `RPT-${report.id}`}</span>
          <div class="header-badges">
            <span class="status-badge status-badge-lg" style="--badge-color: {getStatusColor(report.status)}">{report.status || 'draft'}</span>
            <span class="priority-badge" style="--pri-color: {getPriorityColor(report.priority || editPriority)}">
              <span class="priority-dot-sm" style="background: {getPriorityColor(report.priority || editPriority)}"></span>
              {report.priority || editPriority}
            </span>
          </div>
        </div>
        <div class="detail-header-right">
          <span class="detail-author">{report.author_name || (report.author_first ? `${report.author_first} ${report.author_last}` : '\u2014')}</span>
          <span class="detail-date font-mono">{formatDate(report.created_at)}</span>
        </div>
      </div>

      <div class="detail-grid">
        <div class="detail-main">
          <div class="section-card">
            <label class="form-label">Title</label>
            <input
              type="text"
              class="form-input"
              bind:value={editTitle}
            />
          </div>

          {#if report.template}
            <div class="template-label">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
              <span>{report.template}</span>
            </div>
          {/if}

          <div class="section-card">
            <label class="form-label">Narrative</label>
            <textarea
              class="form-textarea narrative-textarea"
              bind:value={editNarrative}
              rows="12"
            ></textarea>
          </div>

          <div class="section-card">
            <label class="form-label">Tags</label>
            <div class="tags-wrapper">
              {#each editTags as tag (tag)}
                <span class="tag-pill">
                  <span>{tag}</span>
                  <button class="tag-remove" onclick={() => removeEditTag(tag)}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12" /></svg>
                  </button>
                </span>
              {/each}
              <input
                type="text"
                class="tag-input"
                placeholder={editTags.length === 0 ? 'Add tags...' : ''}
                bind:value={editTagInput}
                onkeydown={handleEditTagKey}
              />
            </div>
          </div>

          <div class="section-card timeline-section">
            <div class="section-header">
              <h3 class="section-label">Timeline</h3>
              <span class="section-count font-mono">{timeline.length}</span>
            </div>

            {#if timeline.length > 0}
              <div class="timeline-list">
                {#each timeline as entry, i (entry.id || i)}
                  <div class="timeline-entry">
                    <div class="timeline-dot-line">
                      <span class="timeline-dot"></span>
                      {#if i < timeline.length - 1}
                        <span class="timeline-line"></span>
                      {/if}
                    </div>
                    <div class="timeline-content">
                      <div class="timeline-meta">
                        <span class="timeline-time font-mono">{formatDateTime(entry.timestamp)}</span>
                        {#if entry.author_name || entry.first_name}
                          <span class="timeline-author">{entry.author_name || `${entry.first_name} ${entry.last_name}`}</span>
                        {/if}
                      </div>
                      <p class="timeline-desc">{entry.description}</p>
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="empty-inline">No timeline entries yet</p>
            {/if}

            <div class="timeline-add">
              <div class="timeline-add-row">
                <input
                  type="text"
                  class="form-input timeline-time-input"
                  placeholder="Time (optional)"
                  bind:value={timelineTime}
                />
                <input
                  type="text"
                  class="form-input timeline-desc-input"
                  placeholder="Describe what happened..."
                  bind:value={timelineDesc}
                  onkeydown={(e) => { if (e.key === 'Enter') handleAddTimeline(); }}
                />
                <button class="btn-add" onclick={handleAddTimeline} disabled={!timelineDesc.trim() || saving}>Add</button>
              </div>
            </div>
          </div>
        </div>

        <div class="detail-sidebar">
          <div class="section-card">
            <h3 class="section-label">Status</h3>
            <div class="status-actions">
              {#each STATUS_ACTIONS as action (action.status)}
                {#if action.status !== (report.status || 'draft')}
                  <button
                    class="status-action-btn"
                    style="--sa-color: {getStatusColor(action.status)}"
                    onclick={() => { confirmAction = confirmAction === action.status ? null : action.status; }}
                  >
                    {action.label}
                  </button>
                  {#if confirmAction === action.status}
                    <div class="confirm-row">
                      <span class="confirm-text">Confirm?</span>
                      <button class="confirm-yes" onclick={() => handleStatusChange(action.status)}>Yes</button>
                      <button class="confirm-no" onclick={() => { confirmAction = null; }}>No</button>
                    </div>
                  {/if}
                {/if}
              {/each}
            </div>
          </div>

          <div class="section-card">
            <h3 class="section-label">Priority</h3>
            <div class="priority-selector">
              {#each PRIORITIES as pri (pri)}
                <button
                  class="priority-option"
                  class:active={editPriority === pri}
                  style="--po-color: {getPriorityColor(pri)}"
                  onclick={() => { editPriority = pri; }}
                >
                  <span class="priority-dot-sm" style="background: {getPriorityColor(pri)}"></span>
                  {pri}
                </button>
              {/each}
            </div>
          </div>

          <div class="section-card">
            <div class="section-header">
              <h3 class="section-label">Tagged Entities</h3>
              <span class="section-count font-mono">{entities.length}</span>
            </div>
            {#if entities.length > 0}
              <div class="entity-list">
                {#each entities as entity, i (entity.id || i)}
                  <div class="entity-item">
                    <div class="entity-icon">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <path d="{ENTITY_ICONS[entity.entity_type] || ENTITY_ICONS.citizen}" />
                      </svg>
                    </div>
                    <div class="entity-info">
                      <span class="entity-name">{entity.name || entity.identifier || `${entity.entity_type} #${entity.entity_id}`}</span>
                      <span class="entity-role">{entity.role || entity.entity_type}</span>
                    </div>
                    <button class="entity-remove" onclick={() => handleRemoveEntity(entity.id)}>
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                    </button>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="empty-inline">No entities linked</p>
            {/if}
          </div>

          <div class="section-card">
            <div class="section-header">
              <h3 class="section-label">Collaborators</h3>
              <span class="section-count font-mono">{collaborators.length}</span>
            </div>
            {#if collaborators.length > 0}
              <div class="collab-list">
                {#each collaborators as collab, i (collab.name || collab.first_name || i)}
                  <div class="collab-item">
                    <div class="collab-avatar">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" /></svg>
                    </div>
                    <div class="collab-info">
                      <span class="collab-name">{collab.name || (collab.first_name ? `${collab.first_name} ${collab.last_name}` : '—')}</span>
                      {#if collab.callsign}
                        <span class="collab-callsign font-mono">{collab.callsign}</span>
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="empty-inline">No collaborators</p>
            {/if}
          </div>

          <button class="btn-save-full" onclick={handleSave} disabled={saving}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z" /><polyline points="17 21 17 13 7 13 7 21" /><polyline points="7 3 7 8 15 8" /></svg>
            <span>{saving ? 'Saving...' : 'Save Report'}</span>
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .reports-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale));
    height: 100%;
    opacity: 0;
    transform: translateY(calc(8px * var(--mdt-scale)));
  }

  .reports-page.mounted {
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .list-mode,
  .create-mode,
  .detail-mode {
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
  }

  .header-left {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
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
  }

  .btn-new {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    border: none;
    border-radius: var(--mdt-radius);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .btn-new svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .btn-new:hover {
    opacity: 0.9;
  }

  .btn-new:active {
    transform: scale(0.97);
  }

  .filter-bar {
    display: flex;
    gap: calc(2px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(3px * var(--mdt-scale));
  }

  .filter-tab {
    flex: 1;
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: transparent;
    border: none;
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: color 0.15s ease, background 0.15s ease;
  }

  .filter-tab:hover {
    color: var(--mdt-text-dim);
    background: var(--mdt-surface-2);
  }

  .filter-tab.active {
    color: var(--mdt-accent);
    background: var(--mdt-surface-3);
  }

  .reports-table {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
  }

  .table-header {
    display: grid;
    grid-template-columns: 1.4fr 2.5fr 1.2fr 0.9fr 0.9fr 1fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-bottom: 1px solid var(--mdt-border);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .table-row {
    display: grid;
    grid-template-columns: 1.4fr 2.5fr 1.2fr 0.9fr 0.9fr 1fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text);
    cursor: pointer;
    transition: background 0.12s ease;
    text-align: left;
    width: 100%;
    align-items: center;
  }

  .table-row:last-child {
    border-bottom: none;
  }

  .table-row:hover {
    background: var(--mdt-surface-2);
  }

  .table-row:active {
    transform: scale(0.998);
  }

  .td-num {
    color: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    opacity: 0.7;
    font-size: calc(11px * var(--mdt-scale));
  }

  .td-title {
    font-weight: 600;
    color: var(--mdt-text);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .td-author {
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .td-status {
    display: flex;
    align-items: center;
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    background: color-mix(in srgb, var(--badge-color) 15%, transparent);
    color: var(--badge-color);
    border: 1px solid color-mix(in srgb, var(--badge-color) 25%, transparent);
    white-space: nowrap;
    line-height: 1.4;
  }

  .status-badge-lg {
    font-size: calc(11px * var(--mdt-scale));
    padding: calc(3px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
  }

  .td-priority {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
  }

  .priority-dot {
    width: calc(7px * var(--mdt-scale));
    height: calc(7px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .priority-label {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    text-transform: capitalize;
  }

  .td-date {
    color: var(--mdt-text-dim);
    font-size: calc(10px * var(--mdt-scale));
  }

  .pagination {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) 0;
  }

  .page-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface);
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
    padding: 0;
  }

  .page-btn svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .page-btn:hover:not(:disabled) {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .page-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }

  .page-indicator {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.05em;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: calc(48px * var(--mdt-scale)) 0;
    gap: calc(8px * var(--mdt-scale));
    opacity: 0.5;
  }

  .empty-icon {
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .empty-text {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
  }

  .empty-sub {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .empty-inline {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding: calc(8px * var(--mdt-scale)) 0;
    text-align: center;
    opacity: 0.7;
  }

  .back-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease, transform 0.1s ease;
    align-self: flex-start;
  }

  .back-btn svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .back-btn:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .back-btn:active {
    transform: scale(0.97);
  }

  .section-title {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
  }

  .form-card {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(20px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
  }

  .section-card {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(14px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .form-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .form-input {
    width: 100%;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .form-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-input:focus {
    border-color: var(--mdt-accent);
  }

  .form-select {
    width: 100%;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale));
    outline: none;
    cursor: pointer;
    transition: border-color 0.15s ease;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='rgba(228,232,239,0.38)' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right calc(10px * var(--mdt-scale)) center;
    padding-right: calc(32px * var(--mdt-scale));
  }

  .form-select:focus {
    border-color: var(--mdt-accent);
  }

  .form-select option {
    background: #14181f;
    color: var(--mdt-text);
  }

  .tags-wrapper {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    min-height: calc(36px * var(--mdt-scale));
    align-items: center;
    transition: border-color 0.15s ease;
  }

  .tags-wrapper:focus-within {
    border-color: var(--mdt-accent);
  }

  .tag-pill {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 25%, transparent);
  }

  .tag-remove {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    border: none;
    background: none;
    color: var(--mdt-accent);
    cursor: pointer;
    padding: 0;
    opacity: 0.6;
    transition: opacity 0.12s ease;
  }

  .tag-remove svg {
    width: calc(10px * var(--mdt-scale));
    height: calc(10px * var(--mdt-scale));
  }

  .tag-remove:hover {
    opacity: 1;
  }

  .tag-input {
    flex: 1;
    min-width: calc(80px * var(--mdt-scale));
    border: none;
    background: transparent;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
  }

  .tag-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea {
    width: 100%;
    resize: vertical;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale));
    line-height: 1.6;
    outline: none;
    transition: border-color 0.15s ease;
    min-height: calc(300px * var(--mdt-scale));
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .narrative-textarea {
    min-height: calc(220px * var(--mdt-scale));
  }

  .form-actions {
    display: flex;
    justify-content: flex-end;
    gap: calc(8px * var(--mdt-scale));
    padding-top: calc(4px * var(--mdt-scale));
  }

  .btn-cancel {
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
  }

  .btn-cancel:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .btn-primary {
    padding: calc(8px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .btn-primary:hover {
    opacity: 0.9;
  }

  .btn-primary:active {
    transform: scale(0.97);
  }

  .btn-primary:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .detail-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(18px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
  }

  .detail-header-left {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .report-number {
    font-size: calc(14px * var(--mdt-scale));
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
    opacity: 0.8;
  }

  .header-badges {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
  }

  .priority-badge {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(3px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    text-transform: capitalize;
    color: var(--pri-color);
    background: color-mix(in srgb, var(--pri-color) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--pri-color) 20%, transparent);
  }

  .priority-dot-sm {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .detail-header-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: calc(4px * var(--mdt-scale));
  }

  .detail-author {
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-weight: 500;
  }

  .detail-date {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .template-label {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    align-self: flex-start;
  }

  .template-label svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    opacity: 0.5;
  }

  .detail-grid {
    display: grid;
    grid-template-columns: 1fr calc(280px * var(--mdt-scale));
    gap: calc(14px * var(--mdt-scale));
    min-height: 0;
  }

  .detail-main {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    min-width: 0;
  }

  .detail-sidebar {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    min-width: 0;
  }

  .section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .section-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .section-count {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    padding: calc(1px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    letter-spacing: 0.05em;
  }

  .status-actions {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .status-action-btn {
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid color-mix(in srgb, var(--sa-color) 25%, transparent);
    background: color-mix(in srgb, var(--sa-color) 8%, transparent);
    color: var(--sa-color);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, transform 0.1s ease;
    width: 100%;
    text-align: left;
  }

  .status-action-btn:hover {
    background: color-mix(in srgb, var(--sa-color) 15%, transparent);
  }

  .status-action-btn:active {
    transform: scale(0.97);
  }

  .confirm-row {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    animation: fadeIn 0.15s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .confirm-text {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex: 1;
  }

  .confirm-yes,
  .confirm-no {
    padding: calc(3px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    font-family: 'Outfit', sans-serif;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.12s ease;
  }

  .confirm-yes {
    background: var(--mdt-success);
    color: var(--mdt-bg);
  }

  .confirm-no {
    background: var(--mdt-surface-3);
    color: var(--mdt-text-dim);
  }

  .confirm-yes:hover,
  .confirm-no:hover {
    opacity: 0.85;
  }

  .priority-selector {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(4px * var(--mdt-scale));
  }

  .priority-option {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    text-transform: capitalize;
    cursor: pointer;
    transition: border-color 0.15s ease, background 0.15s ease;
  }

  .priority-option:hover {
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-3);
  }

  .priority-option.active {
    border-color: color-mix(in srgb, var(--po-color) 50%, transparent);
    background: color-mix(in srgb, var(--po-color) 10%, transparent);
    color: var(--po-color);
  }

  .timeline-section {
    gap: calc(12px * var(--mdt-scale));
  }

  .timeline-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .timeline-entry {
    display: flex;
    gap: calc(12px * var(--mdt-scale));
    min-height: calc(40px * var(--mdt-scale));
  }

  .timeline-dot-line {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: calc(12px * var(--mdt-scale));
    flex-shrink: 0;
    padding-top: calc(4px * var(--mdt-scale));
  }

  .timeline-dot {
    width: calc(8px * var(--mdt-scale));
    height: calc(8px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-accent);
    flex-shrink: 0;
    box-shadow: 0 0 calc(6px * var(--mdt-scale)) var(--mdt-accent-glow);
  }

  .timeline-line {
    width: calc(1px * var(--mdt-scale));
    flex: 1;
    background: var(--mdt-border-2);
    margin-top: calc(4px * var(--mdt-scale));
  }

  .timeline-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    padding-bottom: calc(14px * var(--mdt-scale));
    min-width: 0;
  }

  .timeline-meta {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .timeline-time {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0.7;
    letter-spacing: 0.04em;
  }

  .timeline-author {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .timeline-desc {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
  }

  .timeline-add {
    border-top: 1px solid var(--mdt-border);
    padding-top: calc(10px * var(--mdt-scale));
  }

  .timeline-add-row {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
    align-items: center;
  }

  .timeline-time-input {
    width: calc(120px * var(--mdt-scale));
    flex-shrink: 0;
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(11px * var(--mdt-scale));
  }

  .timeline-desc-input {
    flex: 1;
  }

  .btn-add {
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-accent);
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: background 0.12s ease, transform 0.1s ease;
    white-space: nowrap;
  }

  .btn-add:hover {
    background: color-mix(in srgb, var(--mdt-accent) 20%, transparent);
  }

  .btn-add:active {
    transform: scale(0.97);
  }

  .btn-add:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .entity-list {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .entity-item {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-radius: var(--mdt-radius-sm);
    transition: background 0.12s ease;
  }

  .entity-item:hover {
    background: var(--mdt-surface-3);
  }

  .entity-icon {
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .entity-icon svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .entity-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .entity-name {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .entity-role {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-transform: capitalize;
  }

  .entity-remove {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(20px * var(--mdt-scale));
    height: calc(20px * var(--mdt-scale));
    border: none;
    background: none;
    color: var(--mdt-text-muted);
    cursor: pointer;
    border-radius: var(--mdt-radius-sm);
    padding: 0;
    transition: color 0.12s ease, background 0.12s ease;
    flex-shrink: 0;
  }

  .entity-remove svg {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
  }

  .entity-remove:hover {
    color: var(--mdt-error);
    background: color-mix(in srgb, var(--mdt-error) 12%, transparent);
  }

  .collab-list {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .collab-item {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-radius: var(--mdt-radius-sm);
  }

  .collab-avatar {
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    background: var(--mdt-surface-3);
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .collab-avatar svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .collab-info {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .collab-name {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .collab-callsign {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .btn-save-full {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
    width: 100%;
  }

  .btn-save-full svg {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
  }

  .btn-save-full:hover {
    opacity: 0.9;
  }

  .btn-save-full:active {
    transform: scale(0.97);
  }

  .btn-save-full:disabled {
    opacity: 0.4;
    cursor: not-allowed;
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
</style>
