<script>
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const STATUSES = [
    { key: 'open', label: 'Open', color: 'var(--mdt-success)' },
    { key: 'pending_warrant', label: 'Pending Warrant', color: 'var(--mdt-warning)' },
    { key: 'under_review', label: 'Under Review', color: '#3b82f6' },
    { key: 'closed', label: 'Closed', color: 'var(--mdt-text-muted)' },
    { key: 'cold', label: 'Cold', color: 'var(--mdt-text-muted)' },
  ];

  const PRIORITIES = [
    { key: 'low', label: 'Low', color: 'var(--mdt-text-muted)' },
    { key: 'normal', label: 'Normal', color: 'var(--mdt-text-dim)' },
    { key: 'high', label: 'High', color: 'var(--mdt-warning)' },
    { key: 'critical', label: 'Critical', color: 'var(--mdt-error)' },
  ];

  const ENTITY_GROUPS = [
    { key: 'report', label: 'Reports', icon: 'M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z' },
    { key: 'evidence', label: 'Evidence', icon: 'M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z' },
    { key: 'citizen', label: 'Citizens', icon: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z' },
    { key: 'vehicle', label: 'Vehicles', icon: 'M8 17h8M8 17l-2 0a2 2 0 01-2-2V9a2 2 0 012-2h12a2 2 0 012 2v6a2 2 0 01-2 2h-2M8 17v2m8-2v2M7 9h2m6 0h2' },
  ];

  const MOCK_CASES = [
    { case_id: 1, case_number: 'CASE-20260115-0001', title: 'Downtown Bank Robbery Investigation', lead_detective: 'Det. Sarah Mitchell', status: 'open', priority: 'critical', updated_at: '2026-03-20', description: 'Multiple suspects involved in armed robbery of Fleeca Bank downtown. Suspects fled in a black SUV heading north.', restricted: false },
    { case_id: 2, case_number: 'CASE-20260112-0002', title: 'Vangelico Jewelry Heist', lead_detective: 'Det. Marcus Cole', status: 'pending_warrant', priority: 'high', updated_at: '2026-03-19', description: 'Organized smash-and-grab at Vangelico Fine Jewelry. Security footage shows three masked individuals.', restricted: false },
    { case_id: 3, case_number: 'CASE-20260108-0003', title: 'Missing Person - Jane Whitfield', lead_detective: 'Det. Sarah Mitchell', status: 'under_review', priority: 'normal', updated_at: '2026-03-18', description: 'Jane Whitfield reported missing by family. Last seen near Del Perro pier.', restricted: false },
    { case_id: 4, case_number: 'CASE-20251220-0004', title: 'Paleto Bay Drug Trafficking', lead_detective: 'Det. Ricardo Vasquez', status: 'closed', priority: 'high', updated_at: '2026-03-10', description: 'Investigation into drug supply chain operating out of Paleto Bay. Multiple arrests made.', restricted: true },
    { case_id: 5, case_number: 'CASE-20251115-0005', title: 'Vinewood Hit-and-Run', lead_detective: 'Det. Marcus Cole', status: 'cold', priority: 'low', updated_at: '2026-02-28', description: 'Unidentified vehicle struck pedestrian on Vinewood Blvd. No witnesses have come forward.', restricted: false },
  ];

  const MOCK_PERSONNEL = [
    { id: 1, officer_name: 'Det. Sarah Mitchell', callsign: '3-D-01', rank: 'Detective', role: 'lead' },
    { id: 2, officer_name: 'Ofc. James Rivera', callsign: '1-A-14', rank: 'Officer', role: 'assigned' },
    { id: 3, officer_name: 'Ofc. Chen Wei', callsign: '1-B-07', rank: 'Officer', role: 'assigned' },
  ];

  const MOCK_LINKS = [
    { id: 1, entity_type: 'report', entity_id: 101, identifier: 'RPT-20260115-0012', display_name: 'Armed Robbery - Fleeca Bank' },
    { id: 2, entity_type: 'report', entity_id: 102, identifier: 'RPT-20260116-0013', display_name: 'Witness Statement - Bank Teller' },
    { id: 3, entity_type: 'evidence', entity_id: 201, identifier: 'EV-20260115-0004', display_name: 'Security Camera Footage' },
    { id: 4, entity_type: 'evidence', entity_id: 202, identifier: 'EV-20260115-0005', display_name: 'Shell Casings (9mm)' },
    { id: 5, entity_type: 'citizen', entity_id: 301, identifier: 'CID-44210', display_name: 'Marcus Thompson' },
    { id: 6, entity_type: 'citizen', entity_id: 302, identifier: 'CID-51887', display_name: 'Alejandro Reyes' },
    { id: 7, entity_type: 'vehicle', entity_id: 401, identifier: 'ABC 1234', display_name: 'Black Granger (SUV)' },
  ];

  let mode = $state('list');
  let currentPage = $state(1);
  let saving = $state(false);
  let creating = $state(false);

  let createTitle = $state('');
  let createDescription = $state('');
  let createPriority = $state('normal');

  let editTitle = $state('');
  let editDescription = $state('');
  let editStatus = $state('');
  let editPriority = $state('');
  let editRestricted = $state(false);

  let curStatusDef = $derived(getStatusDef(editStatus));
  let curPriorityDef = $derived(getPriorityDef(editPriority));

  let caseList = $derived(isEnvBrowser() ? MOCK_CASES : dataStore.casesList);
  let caseTotal = $derived(isEnvBrowser() ? MOCK_CASES.length : dataStore.casesTotal);
  let caseDetail = $derived(isEnvBrowser() ? (dataStore.selectedCase || MOCK_CASES[0]) : dataStore.selectedCase);
  let personnel = $derived(isEnvBrowser() ? MOCK_PERSONNEL : dataStore.casePersonnel);
  let links = $derived(isEnvBrowser() ? MOCK_LINKS : dataStore.caseLinks);

  let perPage = 15;
  let totalPages = $derived(Math.max(1, Math.ceil(caseTotal / perPage)));

  let groupedLinks = $derived(() => {
    const grouped = {};
    for (const group of ENTITY_GROUPS) {
      grouped[group.key] = (links || []).filter(l => l.entity_type === group.key);
    }
    return grouped;
  });

  $effect(() => {
    if (caseDetail && mode === 'detail') {
      editTitle = caseDetail.title || '';
      editDescription = caseDetail.description || '';
      editStatus = caseDetail.status || 'open';
      editPriority = caseDetail.priority || 'normal';
      editRestricted = caseDetail.restricted || false;
    }
  });

  $effect(() => {
    if (mode === 'list') {
      if (!isEnvBrowser()) {
        dataStore.fetchCases(currentPage);
      }
    }
  });

  function getStatusDef(status) {
    return STATUSES.find(s => s.key === status) || STATUSES[0];
  }

  function getPriorityDef(priority) {
    return PRIORITIES.find(p => p.key === priority) || PRIORITIES[1];
  }

  function formatDate(dateStr) {
    if (!dateStr) return '\u2014';
    return dateStr;
  }

  function openDetail(caseId) {
    if (!isEnvBrowser()) {
      dataStore.getCase(caseId);
    }
    mode = 'detail';
  }

  function goToList() {
    mode = 'list';
    dataStore.selectedCase = null;
  }

  function goToCreate() {
    createTitle = '';
    createDescription = '';
    createPriority = 'normal';
    mode = 'create';
  }

  async function handleCreate() {
    if (!createTitle.trim()) return;
    creating = true;
    const resp = await dataStore.createCase({
      title: createTitle.trim(),
      description: createDescription.trim(),
      priority: createPriority,
    });
    creating = false;
    if (resp?.ok || isEnvBrowser()) {
      mode = 'list';
      if (!isEnvBrowser()) {
        dataStore.fetchCases(currentPage);
      }
    }
  }

  async function handleSave() {
    if (!caseDetail) return;
    saving = true;
    await dataStore.updateCase({
      caseId: caseDetail.id || caseDetail.case_id,
      title: editTitle.trim(),
      description: editDescription.trim(),
      status: editStatus,
      priority: editPriority,
      restricted: editRestricted,
    });
    saving = false;
  }

  async function handleRemovePersonnel(id) {
    await dataStore.removePersonnel(id);
    if (!isEnvBrowser() && caseDetail) {
      dataStore.getCase(caseDetail.id || caseDetail.case_id);
    }
  }

  async function handleRemoveLink(id) {
    await dataStore.removeCaseLink(id);
    if (!isEnvBrowser() && caseDetail) {
      dataStore.getCase(caseDetail.id || caseDetail.case_id);
    }
  }

  function prevPage() {
    if (currentPage > 1) currentPage--;
  }

  function nextPage() {
    if (currentPage < totalPages) currentPage++;
  }
</script>

<div class="cases-page">
  {#if mode === 'list'}
    <div class="list-mode">
      <div class="page-header">
        <div class="header-left">
          <h2 class="page-title">Cases & Investigations</h2>
          <p class="page-subtitle">Manage active and archived investigations</p>
        </div>
        <button class="btn-primary" onclick={goToCreate}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 5v14M5 12h14" />
          </svg>
          <span>New Case</span>
        </button>
      </div>

      {#if caseList.length > 0}
        <div class="results-table">
          <div class="table-header">
            <span class="th-number">Case #</span>
            <span class="th-title">Title</span>
            <span class="th-lead">Lead Detective</span>
            <span class="th-status">Status</span>
            <span class="th-priority">Priority</span>
            <span class="th-updated">Updated</span>
          </div>
          {#each caseList as row, i (row.id || row.case_id || i)}
            {@const sDef = getStatusDef(row.status)}
            {@const pDef = getPriorityDef(row.priority)}
            <button class="table-row" onclick={() => openDetail(row.id || row.case_id)}>
              <span class="td-number font-mono">{row.case_number}</span>
              <span class="td-title">{row.title}</span>
              <span class="td-lead">{row.lead_detective || (row.lead_first ? `${row.lead_first} ${row.lead_last}` : '\u2014')}</span>
              <span class="td-status">
                <span class="status-badge" style="--status-color: {sDef.color}">{sDef.label}</span>
              </span>
              <span class="td-priority">
                <span class="priority-dot" style="background: {pDef.color}"></span>
                {pDef.label}
              </span>
              <span class="td-updated font-mono">{formatDate(row.updated_at)}</span>
            </button>
          {/each}
        </div>

        <div class="pagination">
          <button class="pag-btn" onclick={prevPage} disabled={currentPage <= 1}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 19l-7-7 7-7" /></svg>
          </button>
          <span class="pag-info font-mono">{currentPage} / {totalPages}</span>
          <button class="pag-btn" onclick={nextPage} disabled={currentPage >= totalPages}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 5l7 7-7 7" /></svg>
          </button>
        </div>
      {:else}
        <div class="empty-state">
          <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
          </svg>
          <p class="empty-text">No cases found</p>
          <p class="empty-sub">Create a new investigation to get started</p>
        </div>
      {/if}
    </div>

  {:else if mode === 'create'}
    <div class="create-mode">
      <button class="back-btn" onclick={goToList}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to Cases</span>
      </button>

      <div class="page-header">
        <h2 class="page-title">New Investigation</h2>
        <p class="page-subtitle">Open a new case file</p>
      </div>

      <div class="create-form">
        <div class="form-group">
          <label class="form-label">Title</label>
          <input
            type="text"
            class="text-input"
            placeholder="Case title..."
            bind:value={createTitle}
          />
        </div>

        <div class="form-group">
          <label class="form-label">Description</label>
          <textarea
            class="form-textarea"
            placeholder="Describe the investigation..."
            rows="6"
            bind:value={createDescription}
          ></textarea>
        </div>

        <div class="form-group">
          <label class="form-label">Priority</label>
          <div class="priority-selector">
            {#each PRIORITIES as p (p.key)}
              <button
                class="priority-option"
                class:active={createPriority === p.key}
                style="--pri-color: {p.color}"
                onclick={() => createPriority = p.key}
              >
                <span class="priority-dot" style="background: {p.color}"></span>
                {p.label}
              </button>
            {/each}
          </div>
        </div>

        <button class="btn-primary btn-create" onclick={handleCreate} disabled={creating || !createTitle.trim()}>
          {creating ? 'Creating...' : 'Create Case'}
        </button>
      </div>
    </div>

  {:else if mode === 'detail' && caseDetail}
    <div class="detail-mode">
      <button class="back-btn" onclick={goToList}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to Cases</span>
      </button>

      <div class="detail-header">
        <div class="header-top-row">
          <span class="case-number font-mono">{caseDetail.case_number}</span>
          <div class="header-badges">
            <span class="status-badge" style="--status-color: {curStatusDef.color}">{curStatusDef.label}</span>
            <span class="priority-badge" style="--pri-color: {curPriorityDef.color}">
              <span class="priority-dot" style="background: {curPriorityDef.color}"></span>
              {curPriorityDef.label}
            </span>
          </div>
        </div>
        <input
          type="text"
          class="title-input"
          bind:value={editTitle}
          placeholder="Case title..."
        />
      </div>

      <div class="detail-controls">
        <div class="control-group">
          <span class="control-label">Status</span>
          <div class="control-options">
            {#each STATUSES as s (s.key)}
              <button
                class="control-btn"
                class:active={editStatus === s.key}
                style="--ctrl-color: {s.color}"
                onclick={() => editStatus = s.key}
              >{s.label}</button>
            {/each}
          </div>
        </div>

        <div class="control-group">
          <span class="control-label">Priority</span>
          <div class="control-options">
            {#each PRIORITIES as p (p.key)}
              <button
                class="control-btn"
                class:active={editPriority === p.key}
                style="--ctrl-color: {p.color}"
                onclick={() => editPriority = p.key}
              >{p.label}</button>
            {/each}
          </div>
        </div>
      </div>

      <div class="section-card">
        <h3 class="section-label">Description</h3>
        <textarea
          class="form-textarea"
          rows="5"
          placeholder="Case description..."
          bind:value={editDescription}
        ></textarea>
      </div>

      <div class="section-card">
        <div class="section-header-row">
          <h3 class="section-label">Personnel</h3>
          <button class="btn-ghost" disabled>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14" /></svg>
            Add
          </button>
        </div>
        {#if personnel.length > 0}
          <div class="personnel-list">
            {#each personnel as p (p.id)}
              <div class="personnel-row">
                <div class="personnel-info">
                  <span class="personnel-name">{p.officer_name || (p.first_name ? `${p.first_name} ${p.last_name}` : '—')}</span>
                  <span class="personnel-meta font-mono">{p.callsign || '—'} &middot; {p.rank || '—'}</span>
                </div>
                <span class="role-badge" class:role-lead={p.role === 'lead'}>{p.role === 'lead' ? 'Lead' : 'Assigned'}</span>
                <button class="btn-remove" onclick={() => handleRemovePersonnel(p.id)} aria-label="Remove">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                </button>
              </div>
            {/each}
          </div>
        {:else}
          <p class="section-empty">No personnel assigned</p>
        {/if}
      </div>

      <div class="section-card">
        <h3 class="section-label">Linked Entities</h3>
        {#each ENTITY_GROUPS as group (group.key)}
          {@const items = groupedLinks()[group.key]}
          {#if items.length > 0}
            <div class="entity-group">
              <div class="entity-group-header">
                <svg class="entity-group-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d={group.icon} /></svg>
                <span class="entity-group-label">{group.label}</span>
                <span class="entity-group-count font-mono">{items.length}</span>
              </div>
              {#each items as link (link.id)}
                <div class="entity-row">
                  <span class="entity-id font-mono">{link.identifier}</span>
                  <span class="entity-name">{link.display_name || '\u2014'}</span>
                  <button class="btn-remove" onclick={() => handleRemoveLink(link.id)} aria-label="Remove link">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        {/each}
        {#if (links || []).length === 0}
          <p class="section-empty">No linked entities</p>
        {/if}
      </div>

      <div class="section-card restricted-row">
        <label class="checkbox-label">
          <input type="checkbox" class="checkbox-input" bind:checked={editRestricted} />
          <span class="checkbox-box">
            {#if editRestricted}
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M5 13l4 4L19 7" /></svg>
            {/if}
          </span>
          <span class="checkbox-text">Restricted Case</span>
        </label>
        <span class="restricted-hint">Only authorized personnel can view this case</span>
      </div>

      <div class="detail-actions">
        <button class="btn-primary" onclick={handleSave} disabled={saving}>
          {saving ? 'Saving...' : 'Save Changes'}
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  .cases-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale));
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    height: 100%;
    overflow-y: auto;
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
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
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
    font-family: 'Outfit', sans-serif;
  }

  .page-subtitle {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .font-mono {
    font-family: 'Share Tech Mono', monospace;
  }

  .btn-primary {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
    white-space: nowrap;
  }

  .btn-primary svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .btn-primary:hover {
    opacity: 0.9;
  }

  .btn-primary:active {
    transform: scale(0.97);
  }

  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-create {
    align-self: flex-start;
    margin-top: calc(4px * var(--mdt-scale));
  }

  .btn-ghost {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: none;
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
  }

  .btn-ghost svg {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
  }

  .btn-ghost:hover {
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
  }

  .btn-ghost:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .results-table {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
  }

  .table-header {
    display: grid;
    grid-template-columns: 1.6fr 2.5fr 1.4fr 1.1fr 0.9fr 1fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-bottom: 1px solid var(--mdt-border);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
  }

  .table-row {
    display: grid;
    grid-template-columns: 1.6fr 2.5fr 1.4fr 1.1fr 0.9fr 1fr;
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

  .td-number {
    color: var(--mdt-accent-dim);
    font-size: calc(11px * var(--mdt-scale));
  }

  .td-title {
    font-weight: 600;
    color: var(--mdt-text);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .td-lead {
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

  .td-priority {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
    text-transform: capitalize;
  }

  .td-updated {
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    font-family: 'Outfit', sans-serif;
    background: color-mix(in srgb, var(--status-color) 15%, transparent);
    color: var(--status-color);
    border: 1px solid color-mix(in srgb, var(--status-color) 25%, transparent);
    white-space: nowrap;
    line-height: 1.4;
  }

  .priority-dot {
    width: calc(7px * var(--mdt-scale));
    height: calc(7px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .priority-badge {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    font-family: 'Outfit', sans-serif;
    background: color-mix(in srgb, var(--pri-color) 10%, transparent);
    color: var(--pri-color);
    border: 1px solid color-mix(in srgb, var(--pri-color) 20%, transparent);
    white-space: nowrap;
    line-height: 1.4;
  }

  .pagination {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .pag-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
    padding: 0;
  }

  .pag-btn svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .pag-btn:hover:not(:disabled) {
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
  }

  .pag-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }

  .pag-info {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
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
    font-family: 'Outfit', sans-serif;
  }

  .empty-sub {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
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

  .create-form {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(20px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .form-label {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
  }

  .text-input {
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

  .text-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .text-input:focus {
    border-color: var(--mdt-accent);
  }

  .form-textarea {
    width: 100%;
    resize: vertical;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.5;
    outline: none;
    transition: border-color 0.15s ease;
    min-height: calc(60px * var(--mdt-scale));
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .priority-selector {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
  }

  .priority-option {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: border-color 0.15s ease, background 0.15s ease, transform 0.1s ease;
  }

  .priority-option:hover {
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-3);
  }

  .priority-option:active {
    transform: scale(0.97);
  }

  .priority-option.active {
    border-color: color-mix(in srgb, var(--pri-color) 50%, transparent);
    background: color-mix(in srgb, var(--pri-color) 10%, transparent);
    color: var(--pri-color);
  }

  .detail-header {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(18px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .header-top-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
  }

  .case-number {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-accent-dim);
    letter-spacing: 0.04em;
  }

  .header-badges {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
  }

  .title-input {
    width: 100%;
    padding: calc(6px * var(--mdt-scale)) 0;
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    background: transparent;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.01em;
    outline: none;
    transition: border-color 0.15s ease;
  }

  .title-input:focus {
    border-bottom-color: var(--mdt-accent);
  }

  .title-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .detail-controls {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(14px * var(--mdt-scale));
  }

  .control-group {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .control-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
    min-width: calc(60px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .control-options {
    display: flex;
    flex-wrap: wrap;
    gap: calc(4px * var(--mdt-scale));
  }

  .control-btn {
    padding: calc(5px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: none;
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, border-color 0.12s ease, color 0.12s ease, transform 0.1s ease;
    white-space: nowrap;
  }

  .control-btn:hover {
    border-color: var(--mdt-border-2);
    color: var(--mdt-text-dim);
  }

  .control-btn:active {
    transform: scale(0.97);
  }

  .control-btn.active {
    border-color: color-mix(in srgb, var(--ctrl-color) 60%, transparent);
    background: color-mix(in srgb, var(--ctrl-color) 12%, transparent);
    color: var(--ctrl-color);
  }

  .section-card {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(16px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .section-label {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
  }

  .section-header-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .section-empty {
    text-align: center;
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) 0;
    opacity: 0.6;
    font-family: 'Outfit', sans-serif;
  }

  .personnel-list {
    display: flex;
    flex-direction: column;
  }

  .personnel-row {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
    transition: background 0.12s ease;
  }

  .personnel-row:last-child {
    border-bottom: none;
  }

  .personnel-row:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 60%, transparent);
  }

  .personnel-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .personnel-name {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
  }

  .personnel-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .role-badge {
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    font-family: 'Outfit', sans-serif;
    background: color-mix(in srgb, var(--mdt-text-muted) 12%, transparent);
    color: var(--mdt-text-muted);
    border: 1px solid color-mix(in srgb, var(--mdt-text-muted) 20%, transparent);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .role-lead {
    background: color-mix(in srgb, var(--mdt-accent) 12%, transparent);
    color: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 25%, transparent);
  }

  .btn-remove {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    background: none;
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition: color 0.12s ease, background 0.12s ease;
    padding: 0;
    flex-shrink: 0;
  }

  .btn-remove svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .btn-remove:hover {
    color: var(--mdt-error);
    background: color-mix(in srgb, var(--mdt-error) 10%, transparent);
  }

  .entity-group {
    display: flex;
    flex-direction: column;
    border: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
    border-radius: var(--mdt-radius-sm);
    overflow: hidden;
  }

  .entity-group + .entity-group {
    margin-top: calc(6px * var(--mdt-scale));
  }

  .entity-group-header {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
  }

  .entity-group-icon {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .entity-group-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
    flex: 1;
  }

  .entity-group-count {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    opacity: 0.6;
  }

  .entity-row {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 30%, transparent);
    transition: background 0.12s ease;
  }

  .entity-row:last-child {
    border-bottom: none;
  }

  .entity-row:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 50%, transparent);
  }

  .entity-id {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent-dim);
    min-width: calc(140px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .entity-name {
    flex: 1;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .restricted-row {
    flex-direction: row;
    align-items: center;
    justify-content: flex-start;
    gap: calc(16px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .checkbox-label {
    display: inline-flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    cursor: pointer;
    user-select: none;
  }

  .checkbox-input {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
    pointer-events: none;
  }

  .checkbox-box {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
    border-radius: calc(3px * var(--mdt-scale));
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-2);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: background 0.12s ease, border-color 0.12s ease;
  }

  .checkbox-box svg {
    width: calc(10px * var(--mdt-scale));
    height: calc(10px * var(--mdt-scale));
    color: var(--mdt-bg);
  }

  .checkbox-input:checked + .checkbox-box {
    background: var(--mdt-accent);
    border-color: var(--mdt-accent);
  }

  .checkbox-text {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
  }

  .restricted-hint {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .detail-actions {
    display: flex;
    justify-content: flex-end;
    padding-top: calc(4px * var(--mdt-scale));
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
