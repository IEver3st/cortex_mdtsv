<script>
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import MdtCheckbox from '../lib/components/MdtCheckbox.svelte';

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

  /** @param {string} [fileName] @param {string} [fileType] */
  function attachmentKindAbbrev(fileName, fileType) {
    const n = String(fileName || '').toLowerCase();
    const t = String(fileType || '').toLowerCase();
    const dot = n.lastIndexOf('.');
    const ext = dot >= 0 ? n.slice(dot + 1, dot + 5) : '';
    if (t.includes('pdf') || ext === 'pdf') return 'PDF';
    if (t.includes('image') || /^(png|jpe?g|webp|gif|bmp)$/.test(ext)) return 'IMG';
    if (t.includes('video') || /^(mp4|webm|mov|mkv)$/.test(ext)) return 'VID';
    if (t.includes('audio') || /^(mp3|wav|ogg|m4a)$/.test(ext)) return 'AUD';
    if (ext) return ext.toUpperCase().slice(0, 4);
    const head = t.replace(/[/\\].*/, '').slice(0, 4).trim();
    return head ? head.toUpperCase() : 'FILE';
  }

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
  let attachmentName = $state('');
  let attachmentUrl = $state('');
  let attachmentType = $state('');
  let attachmentNotes = $state('');
  let personnelQuery = $state('');
  let personnelRole = $state('assigned');
  let linkEntityType = $state('report');
  let linkEntityId = $state('');

  let caseList = $derived(isEnvBrowser() ? MOCK_CASES : dataStore.casesList);
  let caseTotal = $derived(isEnvBrowser() ? MOCK_CASES.length : dataStore.casesTotal);
  let caseDetail = $derived(isEnvBrowser() ? (dataStore.selectedCase || MOCK_CASES[0]) : dataStore.selectedCase);
  let personnel = $derived(isEnvBrowser() ? MOCK_PERSONNEL : dataStore.casePersonnel);
  let links = $derived(isEnvBrowser() ? MOCK_LINKS : dataStore.caseLinks);
  let attachments = $derived(isEnvBrowser() ? [] : (dataStore.caseAttachments || []));
  let officerResults = $derived(dataStore.officerResults || []);

  let perPage = 15;
  let totalPages = $derived(Math.max(1, Math.ceil(caseTotal / perPage)));

  let groupedLinks = $derived.by(() => {
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

  async function handleAddAttachment() {
    if (!caseDetail || !attachmentName.trim() || !attachmentUrl.trim()) return;
    saving = true;
    await dataStore.addAttachment({
      parentType: 'case',
      parentId: caseDetail.id || caseDetail.case_id,
      fileName: attachmentName.trim(),
      fileUrl: attachmentUrl.trim(),
      fileType: attachmentType.trim() || null,
      notes: attachmentNotes.trim() || null,
    });
    if (!isEnvBrowser()) {
      await dataStore.getCase(caseDetail.id || caseDetail.case_id);
    }
    attachmentName = '';
    attachmentUrl = '';
    attachmentType = '';
    attachmentNotes = '';
    saving = false;
  }

  async function handleRemoveAttachment(id) {
    if (!caseDetail) return;
    saving = true;
    await dataStore.removeAttachment(id, 'case');
    if (!isEnvBrowser()) {
      await dataStore.getCase(caseDetail.id || caseDetail.case_id);
    }
    saving = false;
  }

  async function handleSearchPersonnel() {
    if (!personnelQuery.trim()) return;
    await dataStore.searchOfficers(personnelQuery.trim());
  }

  async function handleAddPersonnel(officerId) {
    if (!caseDetail || !officerId) return;
    saving = true;
    await dataStore.addPersonnel({
      caseId: caseDetail.id || caseDetail.case_id,
      officerId,
      role: personnelRole,
    });
    personnelQuery = '';
    await dataStore.getCase(caseDetail.id || caseDetail.case_id);
    saving = false;
  }

  async function handleAddLink() {
    if (!caseDetail || !linkEntityId.trim()) return;
    saving = true;
    await dataStore.addCaseLink({
      caseId: caseDetail.id || caseDetail.case_id,
      entityType: linkEntityType,
      entityId: linkEntityId.trim(),
    });
    linkEntityId = '';
    await dataStore.getCase(caseDetail.id || caseDetail.case_id);
    saving = false;
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
          <button class="pag-btn" onclick={prevPage} disabled={currentPage <= 1} aria-label="Previous cases page">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 19l-7-7 7-7" /></svg>
          </button>
          <span class="pag-info font-mono">{currentPage} / {totalPages}</span>
          <button class="pag-btn" onclick={nextPage} disabled={currentPage >= totalPages} aria-label="Next cases page">
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
          <label class="form-label" for="case-create-title">Title</label>
          <input
            type="text"
            id="case-create-title"
            class="text-input"
            placeholder="Case title..."
            bind:value={createTitle}
          />
        </div>

        <div class="form-group">
          <label class="form-label" for="case-create-description">Description</label>
          <textarea
            id="case-create-description"
            class="form-textarea"
            placeholder="Describe the investigation..."
            rows="6"
            bind:value={createDescription}
          ></textarea>
        </div>

        <div class="form-group">
          <span class="form-label" id="case-create-priority-label">Priority</span>
          <div class="priority-selector" role="radiogroup" aria-labelledby="case-create-priority-label">
            {#each PRIORITIES as p (p.key)}
              <button
                class="priority-option"
                class:active={createPriority === p.key}
                style="--pri-color: {p.color}"
                onclick={() => createPriority = p.key}
                aria-pressed={createPriority === p.key}
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
      <div class="detail-top-bar">
        <button class="back-btn" onclick={goToList}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          <span>Back to Cases</span>
        </button>
        <button class="btn-save-full" onclick={handleSave} disabled={saving}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z" /><polyline points="17 21 17 13 7 13 7 21" /><polyline points="7 3 7 8 15 8" /></svg>
          <span>{saving ? 'Saving...' : 'Save Case'}</span>
        </button>
      </div>

      <div class="detail-header">
        <div class="detail-report-line">
          <span class="detail-meta-label">Case number</span>
          <p class="detail-report-id font-mono">{caseDetail.case_number}</p>
        </div>

        <div class="detail-meta-grid">
          <div class="detail-meta-item">
            <span class="detail-meta-label">Status</span>
            <select id="case-edit-status" class="form-select" bind:value={editStatus}>
              {#each STATUSES as s (s.key)}
                <option value={s.key}>{s.label}</option>
              {/each}
            </select>
          </div>
          <div class="detail-meta-item">
            <span class="detail-meta-label">Priority</span>
            <select id="case-edit-priority" class="form-select" bind:value={editPriority}>
              {#each PRIORITIES as p (p.key)}
                <option value={p.key}>{p.label}</option>
              {/each}
            </select>
          </div>
          <div class="detail-meta-item">
            <span class="detail-meta-label">Lead</span>
            <p class="detail-meta-value">
              {caseDetail.lead_detective || (caseDetail.lead_first ? `${caseDetail.lead_first} ${caseDetail.lead_last}` : '\u2014')}
            </p>
          </div>
          <div class="detail-meta-item">
            <span class="detail-meta-label">Updated</span>
            <p class="detail-meta-value detail-meta-mono font-mono">{formatDate(caseDetail.updated_at)}</p>
          </div>
        </div>
      </div>

      <div class="detail-grid">
        <div class="detail-main">
          <div class="detail-stack">
            <div class="detail-section">
              <label class="form-label" for="case-title">Title</label>
              <input
                id="case-title"
                type="text"
                class="form-input"
                bind:value={editTitle}
                placeholder="Case title..."
              />
              <label class="form-label" for="case-desc">Description</label>
              <textarea
                id="case-desc"
                class="form-textarea narrative-textarea"
                rows="10"
                placeholder="Case description..."
                bind:value={editDescription}
              ></textarea>
            </div>

            <div class="detail-section">
              <div class="section-header">
                <h3 class="section-label">Personnel</h3>
                <span class="section-count font-mono">{personnel.length}</span>
              </div>
              <div class="inline-form-grid">
                <input
                  class="form-input"
                  bind:value={personnelQuery}
                  placeholder="Officer name or callsign"
                  onkeydown={(e) => { if (e.key === 'Enter') handleSearchPersonnel(); }}
                />
                <select class="form-select" bind:value={personnelRole}>
                  <option value="assigned">Assigned</option>
                  <option value="lead">Lead</option>
                  <option value="support">Support</option>
                </select>
              </div>
              <button type="button" class="btn-add-secondary" onclick={handleSearchPersonnel} disabled={!personnelQuery.trim() || saving}>
                Search
              </button>
              {#if officerResults.length > 0}
                <div class="flat-list">
                  {#each officerResults as result (result.id)}
                    <button type="button" class="flat-list-row flat-list-row-button" onclick={() => handleAddPersonnel(result.id)}>
                      <div class="flat-list-main">
                        <span class="flat-list-title">{result.first_name} {result.last_name}</span>
                        <span class="flat-list-sub">{result.rank || 'Officer'} · {result.callsign || 'No callsign'} · {(result.department || 'police').toUpperCase()}</span>
                      </div>
                    </button>
                  {/each}
                </div>
              {/if}
              {#if personnel.length > 0}
                <div class="flat-list flat-list-tight">
                  {#each personnel as p (p.id)}
                    <div class="flat-list-row">
                      <div class="flat-list-main">
                        <span class="flat-list-title">{p.officer_name || (p.first_name ? `${p.first_name} ${p.last_name}` : '—')}</span>
                        <span class="flat-list-sub font-mono">{p.callsign || '—'} · {p.rank || '—'}</span>
                      </div>
                      <span class="role-badge" class:role-lead={p.role === 'lead'}>{p.role === 'lead' ? 'Lead' : p.role === 'support' ? 'Support' : 'Assigned'}</span>
                      <button type="button" class="btn-remove" onclick={() => handleRemovePersonnel(p.id)} aria-label="Remove">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                      </button>
                    </div>
                  {/each}
                </div>
              {:else}
                <p class="empty-inline">No personnel assigned</p>
              {/if}
            </div>

            <div class="detail-section">
              <div class="section-header">
                <h3 class="section-label">Linked Entities</h3>
                <div class="section-header-actions">
                  <span class="section-count font-mono">{(links || []).length}</span>
                </div>
              </div>
              <div class="inline-form-grid">
                <select class="form-select" bind:value={linkEntityType}>
                  {#each ENTITY_GROUPS as group (group.key)}
                    <option value={group.key}>{group.label}</option>
                  {/each}
                </select>
                <input
                  class="form-input"
                  bind:value={linkEntityId}
                  placeholder="Entity ID"
                  onkeydown={(e) => { if (e.key === 'Enter') handleAddLink(); }}
                />
              </div>
              <button type="button" class="btn-add-secondary" onclick={handleAddLink} disabled={!linkEntityId.trim() || saving}>
                Add Link
              </button>
              {#each ENTITY_GROUPS as group (group.key)}
                {@const items = groupedLinks[group.key]}
                {#if items.length > 0}
                  <div class="link-type-block">
                    <div class="link-type-head">
                      <svg class="link-type-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d={group.icon} /></svg>
                      <span class="link-type-label">{group.label}</span>
                      <span class="link-type-count font-mono">{items.length}</span>
                    </div>
                    <div class="flat-list flat-list-tight">
                      {#each items as link (link.id)}
                        <div class="flat-list-row link-row">
                          <span class="link-id font-mono">{link.identifier}</span>
                          <span class="link-title">{link.display_name || '\u2014'}</span>
                          <button type="button" class="btn-remove" onclick={() => handleRemoveLink(link.id)} aria-label="Remove link">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                          </button>
                        </div>
                      {/each}
                    </div>
                  </div>
                {/if}
              {/each}
              {#if (links || []).length === 0}
                <p class="empty-inline">No linked entities</p>
              {/if}
            </div>
          </div>
        </div>

        <aside class="detail-sidebar">
          <div class="detail-stack">
            <div class="detail-section">
              <div class="section-header">
                <h3 class="section-label">Attachments</h3>
                <span class="section-count font-mono">{attachments.length}</span>
              </div>

              <div class="attachments-shell">
                {#if attachments.length > 0}
                  <ul class="attachments-list" role="list">
                    {#each attachments as attachment (attachment.id)}
                      <li class="attachments-row">
                        <span class="attachments-kind font-mono" title={attachment.file_type || 'file'}>{attachmentKindAbbrev(attachment.file_name, attachment.file_type)}</span>
                        <div class="attachments-body min-w-0">
                          <a class="attachments-title" href={attachment.file_url} target="_blank" rel="noreferrer">{attachment.file_name}</a>
                          {#if attachment.notes}
                            <p class="attachments-notes">{attachment.notes}</p>
                          {/if}
                          <span class="attachments-meta font-mono">{attachment.file_type || 'Unknown type'}</span>
                        </div>
                        <div class="attachments-actions">
                          <a class="attachments-open" href={attachment.file_url} target="_blank" rel="noreferrer" aria-label="Open in new tab">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6M15 3h6v6M10 14L21 3" /></svg>
                          </a>
                          <button type="button" class="btn-remove attachments-remove" onclick={() => handleRemoveAttachment(attachment.id)} aria-label="Remove attachment">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                          </button>
                        </div>
                      </li>
                    {/each}
                  </ul>
                {:else}
                  <div class="attachments-empty">
                    <p class="attachments-empty-title">No files linked</p>
                    <p class="attachments-empty-hint">Paste a stable URL (evidence locker, cloud export, or CAD export).</p>
                  </div>
                {/if}

                <div class="attachments-add">
                  <p class="attachments-add-hed">Add file</p>
                  <div class="attachments-form-grid">
                    <div class="attachments-field">
                      <label class="form-label" for="case-att-name">Display name</label>
                      <input id="case-att-name" class="form-input" bind:value={attachmentName} placeholder="Body-worn clip, lab PDF" />
                    </div>
                    <div class="attachments-field">
                      <label class="form-label" for="case-att-url">File URL</label>
                      <input id="case-att-url" class="form-input" bind:value={attachmentUrl} placeholder="https://..." />
                    </div>
                    <div class="attachments-field">
                      <label class="form-label" for="case-att-type">Type / MIME</label>
                      <input id="case-att-type" class="form-input" bind:value={attachmentType} placeholder="video/mp4, application/pdf" />
                    </div>
                  </div>
                  <div class="attachments-field attachments-field-notes">
                    <label class="form-label" for="case-att-notes">Notes</label>
                    <textarea id="case-att-notes" class="form-textarea compact-textarea" bind:value={attachmentNotes} rows="2" placeholder="Chain of custody, redaction flags, page refs"></textarea>
                  </div>
                  <button type="button" class="btn-add-secondary attachments-submit" onclick={handleAddAttachment} disabled={saving || !attachmentName.trim() || !attachmentUrl.trim()}>
                    Add attachment
                  </button>
                </div>
              </div>
            </div>

            <div class="detail-section detail-section-last">
              <h3 class="section-label">Restrictions</h3>
              <div class="toggle-row">
                <MdtCheckbox bind:checked={editRestricted}>
                  {#snippet children()}
                    <span class="checkbox-text">Restricted case</span>
                  {/snippet}
                </MdtCheckbox>
              </div>
              <span class="restricted-hint">Only authorized personnel can view this case</span>
            </div>
          </div>
        </aside>
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

  .detail-mode {
    gap: calc(10px * var(--mdt-scale));
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
    transform: scale(0.96);
  }

  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-create {
    align-self: flex-start;
    margin-top: calc(4px * var(--mdt-scale));
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
    transform: scale(0.96);
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

  .form-input {
    width: 100%;
    min-width: 0;
    box-sizing: border-box;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .form-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-input:focus {
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
    transform: scale(0.96);
  }

  .priority-option.active {
    border-color: color-mix(in srgb, var(--pri-color) 50%, transparent);
    background: color-mix(in srgb, var(--pri-color) 10%, transparent);
    color: var(--pri-color);
  }

  .detail-top-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .detail-top-bar .back-btn {
    align-self: center;
  }

  .btn-save-full {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
    flex-shrink: 0;
  }

  .btn-save-full svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .btn-save-full:hover {
    opacity: 0.9;
  }

  .btn-save-full:active {
    transform: scale(0.96);
  }

  .btn-save-full:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .detail-header {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: calc(10px * var(--mdt-scale));
    padding: 0 0 calc(12px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
    background: transparent;
    border-radius: 0;
    box-shadow: none;
    border-top: none;
    border-left: none;
    border-right: none;
  }

  .detail-header .detail-meta-label {
    display: block;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    margin: 0 0 calc(6px * var(--mdt-scale));
    font-family: 'Outfit', sans-serif;
  }

  .detail-report-line {
    padding-bottom: calc(8px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
  }

  .detail-report-id {
    margin: 0;
    font-size: calc(16px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
    line-height: 1.35;
  }

  .detail-meta-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
  }

  @media (max-width: 1100px) {
    .detail-meta-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }

  @media (max-width: 520px) {
    .detail-meta-grid {
      grid-template-columns: 1fr;
    }
  }

  .detail-meta-item {
    min-width: 0;
  }

  .detail-meta-value {
    margin: 0;
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 500;
    line-height: 1.4;
    font-family: 'Outfit', sans-serif;
  }

  .detail-meta-mono {
    color: var(--mdt-text-dim);
    font-size: calc(12px * var(--mdt-scale));
    letter-spacing: 0.04em;
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
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
  }

  .detail-grid {
    display: grid;
    grid-template-columns: 1fr minmax(220px, calc(268px * var(--mdt-scale)));
    gap: calc(18px * var(--mdt-scale));
    align-items: start;
    min-height: 0;
  }

  .detail-main {
    min-width: 0;
  }

  .detail-sidebar {
    min-width: 0;
    padding-left: calc(16px * var(--mdt-scale));
    margin-left: calc(2px * var(--mdt-scale));
    border-left: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
  }

  @media (max-width: 960px) {
    .detail-grid {
      grid-template-columns: 1fr;
      gap: calc(12px * var(--mdt-scale));
    }

    .detail-sidebar {
      padding-left: 0;
      margin-left: 0;
      border-left: none;
      padding-top: calc(12px * var(--mdt-scale));
      margin-top: calc(4px * var(--mdt-scale));
      border-top: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
    }
  }

  .detail-stack {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .detail-section {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
  }

  .detail-stack > .detail-section:first-child {
    padding-top: 0;
  }

  .detail-stack > .detail-section:last-child,
  .detail-section-last {
    border-bottom: none;
    padding-bottom: 0;
  }

  .detail-mode .form-label {
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.06em;
  }

  .detail-mode .form-input {
    font-size: calc(13px * var(--mdt-scale));
  }

  .narrative-textarea {
    min-height: calc(180px * var(--mdt-scale));
    line-height: 1.6;
  }

  .attachments-shell {
    margin-top: calc(6px * var(--mdt-scale));
  }

  .attachments-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .attachments-row {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr) auto;
    gap: calc(10px * var(--mdt-scale));
    align-items: start;
    padding: calc(10px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 48%, transparent);
    transition: background 0.18s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .attachments-row:last-child {
    border-bottom: none;
  }

  .attachments-row:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 42%, transparent);
  }

  .attachments-kind {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: calc(36px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.04em;
    color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-accent) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 22%, transparent);
    flex-shrink: 0;
    line-height: 1.2;
    margin-top: calc(2px * var(--mdt-scale));
  }

  .attachments-body {
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
    min-width: 0;
  }

  .attachments-title {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    text-decoration: none;
    line-height: 1.35;
    word-break: break-word;
    transition: color 0.15s ease;
  }

  .attachments-title:hover {
    color: var(--mdt-accent);
  }

  .attachments-notes {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.45;
    font-family: 'Outfit', sans-serif;
  }

  .attachments-meta {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.02em;
    line-height: 1.3;
    word-break: break-word;
  }

  .attachments-actions {
    display: flex;
    align-items: flex-start;
    gap: calc(4px * var(--mdt-scale));
    flex-shrink: 0;
    padding-top: calc(1px * var(--mdt-scale));
  }

  .attachments-open {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid color-mix(in srgb, var(--mdt-border) 75%, transparent);
    background: color-mix(in srgb, var(--mdt-surface-2) 55%, transparent);
    color: var(--mdt-text-muted);
    text-decoration: none;
    transition:
      color 0.15s ease,
      background 0.15s ease,
      border-color 0.15s ease,
      transform 0.1s ease;
  }

  .attachments-open svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .attachments-open:hover {
    color: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 28%, transparent);
    background: color-mix(in srgb, var(--mdt-accent) 10%, transparent);
  }

  .attachments-open:active {
    transform: translateY(1px);
  }

  .attachments-remove.btn-remove {
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-border) 75%, transparent);
    background: color-mix(in srgb, var(--mdt-surface-2) 55%, transparent);
  }

  .attachments-empty {
    padding: calc(10px * var(--mdt-scale)) 0 calc(6px * var(--mdt-scale));
    text-align: left;
  }

  .attachments-empty-title {
    margin: 0 0 calc(4px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
  }

  .attachments-empty-hint {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.5;
    color: var(--mdt-text-muted);
    max-width: 38ch;
    font-family: 'Outfit', sans-serif;
  }

  .attachments-add {
    margin-top: calc(8px * var(--mdt-scale));
    padding-top: calc(10px * var(--mdt-scale));
    border-top: 1px solid color-mix(in srgb, var(--mdt-border) 52%, transparent);
  }

  .attachments-add-hed {
    margin: 0 0 calc(10px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .attachments-form-grid {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .attachments-field {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .attachments-field-notes {
    margin-top: calc(2px * var(--mdt-scale));
  }

  .attachments-submit {
    margin-top: calc(10px * var(--mdt-scale));
  }

  .compact-textarea {
    min-height: calc(64px * var(--mdt-scale));
  }

  .btn-add-secondary {
    align-self: flex-start;
    margin-top: calc(4px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    font-family: 'Outfit', sans-serif;
    font-weight: 600;
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 28%, transparent);
    background: color-mix(in srgb, var(--mdt-accent) 14%, transparent);
    color: var(--mdt-accent);
    cursor: pointer;
    transition: background 0.12s ease, transform 0.1s ease, opacity 0.12s ease;
  }

  .btn-add-secondary:hover {
    background: color-mix(in srgb, var(--mdt-accent) 22%, transparent);
  }

  .btn-add-secondary:active {
    transform: scale(0.96);
  }

  .btn-add-secondary:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .toggle-row {
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  .toggle-row :global(.mdt-checkbox-label) {
    font-weight: 500;
    color: var(--mdt-text-dim);
  }

  .section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .section-header-actions {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .section-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
    margin: 0;
  }

  .section-count {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    padding: calc(1px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    letter-spacing: 0.05em;
    font-family: 'Share Tech Mono', monospace;
  }

  .empty-inline {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding: calc(6px * var(--mdt-scale)) 0;
    text-align: center;
    opacity: 0.72;
    font-family: 'Outfit', sans-serif;
  }

  .inline-form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(6px * var(--mdt-scale));
  }

  @media (max-width: 520px) {
    .inline-form-grid {
      grid-template-columns: 1fr;
    }
  }

  .flat-list {
    display: flex;
    flex-direction: column;
    gap: 0;
    margin-top: calc(4px * var(--mdt-scale));
  }

  .flat-list-tight {
    margin-top: calc(2px * var(--mdt-scale));
  }

  .flat-list-row {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 52%, transparent);
    transition: background 0.12s ease;
  }

  .flat-list-row:last-child {
    border-bottom: none;
  }

  .flat-list-row:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 35%, transparent);
  }

  .flat-list-row-button {
    width: 100%;
    border: none;
    background: transparent;
    color: inherit;
    cursor: pointer;
    text-align: left;
    font: inherit;
    padding-left: 0;
    padding-right: 0;
  }

  .flat-list-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .min-w-0 {
    min-width: 0;
  }

  .flat-list-title {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
  }

  .flat-list-sub {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .link-type-block {
    margin-top: calc(6px * var(--mdt-scale));
  }

  .link-type-block:first-of-type {
    margin-top: calc(2px * var(--mdt-scale));
  }

  .link-type-head {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) 0 calc(5px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 45%, transparent);
  }

  .link-type-icon {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .link-type-label {
    flex: 1;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
  }

  .link-type-count {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    opacity: 0.75;
  }

  .link-row {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 2fr) auto;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) 0;
  }

  .link-id {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent-dim);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .link-title {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
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

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
