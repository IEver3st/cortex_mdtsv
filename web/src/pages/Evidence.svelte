<script>
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const EVIDENCE_TYPES = [
    { value: 'general', label: 'General' },
    { value: 'firearm', label: 'Firearm' },
    { value: 'narcotics', label: 'Narcotics' },
    { value: 'digital_media', label: 'Digital Media' },
    { value: 'clothing', label: 'Clothing' },
    { value: 'biological', label: 'Biological' },
    { value: 'documents', label: 'Documents' },
    { value: 'currency', label: 'Currency' },
    { value: 'vehicle_part', label: 'Vehicle Part' },
    { value: 'other', label: 'Other' },
  ];

  const STATUS_DEFS = {
    in_custody: { label: 'In Custody', color: 'var(--mdt-accent)' },
    transferred: { label: 'Transferred', color: 'var(--mdt-warning)' },
    released: { label: 'Released', color: 'var(--mdt-success)' },
    destroyed: { label: 'Destroyed', color: 'var(--mdt-error)' },
    in_lab: { label: 'In Lab', color: '#a855f7' },
    collected: { label: 'Collected', color: 'var(--mdt-accent)' },
  };

  const TRANSFER_STATUSES = [
    { value: 'in_custody', label: 'In Custody' },
    { value: 'transferred', label: 'Transferred' },
    { value: 'released', label: 'Released' },
    { value: 'destroyed', label: 'Destroyed' },
    { value: 'in_lab', label: 'In Lab' },
  ];

  const MOCK_EVIDENCE_LIST = [
    { evidence_id: 1, evidence_tag: 'EV-20260114-0001', type: 'firearm', description: 'Glock 19 recovered from vehicle trunk during traffic stop', collected_by: 'Ofc. Martinez', status: 'in_custody', stash_location: 'Locker 12-B', created_at: '2026-01-14 09:32' },
    { evidence_id: 2, evidence_tag: 'EV-20260114-0002', type: 'narcotics', description: 'Bag of white powder found on suspect\'s person during search', collected_by: 'Ofc. Davis', status: 'in_lab', stash_location: 'Locker 07-A', created_at: '2026-01-14 11:15' },
    { evidence_id: 3, evidence_tag: 'EV-20260113-0001', type: 'digital_media', description: 'Security camera footage from robbery at 24/7 convenience store', collected_by: 'Det. Chen', status: 'in_custody', stash_location: 'Digital Vault 03', created_at: '2026-01-13 16:44' },
    { evidence_id: 4, evidence_tag: 'EV-20260112-0003', type: 'clothing', description: 'Bloodstained jacket recovered from dumpster behind Vespucci Blvd', collected_by: 'Ofc. Johnson', status: 'transferred', stash_location: 'Locker 19-C', created_at: '2026-01-12 22:08' },
    { evidence_id: 5, evidence_tag: 'EV-20260111-0001', type: 'documents', description: 'Forged ID documents and blank check templates', collected_by: 'Det. Williams', status: 'released', stash_location: 'Locker 02-D', created_at: '2026-01-11 14:20' },
    { evidence_id: 6, evidence_tag: 'EV-20260110-0002', type: 'currency', description: '$4,500 in counterfeit bills seized during raid', collected_by: 'Sgt. Thompson', status: 'destroyed', stash_location: 'Secure Vault A', created_at: '2026-01-10 08:55' },
  ];

  const MOCK_EVIDENCE_DETAIL = {
    evidence_id: 1,
    evidence_tag: 'EV-20260114-0001',
    type: 'firearm',
    description: 'Glock 19 semi-automatic pistol recovered from the trunk of a black Dominator during a traffic stop on Route 68. Serial number partially filed off. Loaded magazine with 12 rounds of 9mm ammunition.',
    collected_by: 'Ofc. Martinez',
    status: 'in_custody',
    stash_location: 'Locker 12-B',
    photo_url: '',
    report_id: null,
    case_id: null,
    created_at: '2026-01-14 09:32',
  };

  const MOCK_CUSTODY = [
    { id: 1, timestamp: '2026-01-14 09:32', action: 'Collected', from_officer: null, to_officer: 'Ofc. Martinez', from_location: 'Route 68 / Sandy Shores', to_location: 'Locker 12-B', notes: 'Recovered during traffic stop of suspect vehicle. Photographed in-situ before bagging.' },
    { id: 2, timestamp: '2026-01-14 14:10', action: 'Transfer', from_officer: 'Ofc. Martinez', to_officer: 'Det. Chen', from_location: 'Locker 12-B', to_location: 'Evidence Processing', notes: 'Transferred for fingerprint and ballistic analysis.' },
    { id: 3, timestamp: '2026-01-15 08:45', action: 'Transfer', from_officer: 'Det. Chen', to_officer: 'Ofc. Martinez', from_location: 'Evidence Processing', to_location: 'Locker 12-B', notes: 'Analysis complete. Returned to secure storage.' },
  ];

  let mode = $state('list');
  let currentPage = $state(1);
  let creating = $state(false);
  let transferring = $state(false);
  let showTransferForm = $state(false);

  let createType = $state('general');
  let createSerialNumber = $state('');
  let createDescription = $state('');
  let createPhotoUrl = $state('');
  let createStashLocation = $state('');
  let createReportId = $state('');
  let createCaseId = $state('');

  let transferToLocation = $state('');
  let transferNotes = $state('');
  let transferNewStatus = $state('in_custody');

  let editType = $state('general');
  let editSerialNumber = $state('');
  let editDescription = $state('');
  let editPhotoUrl = $state('');
  let editStashLocation = $state('');
  let editReportId = $state('');
  let editCaseId = $state('');
  let editStatus = $state('in_custody');
  let attachmentName = $state('');
  let attachmentUrl = $state('');
  let attachmentType = $state('');
  let attachmentNotes = $state('');

  let evidenceItems = $derived(isEnvBrowser() ? MOCK_EVIDENCE_LIST : dataStore.evidenceList);
  let evidenceTotal = $derived(isEnvBrowser() ? MOCK_EVIDENCE_LIST.length : dataStore.evidenceTotal);
  let detail = $derived(isEnvBrowser() ? MOCK_EVIDENCE_DETAIL : dataStore.selectedEvidence);
  let custody = $derived(isEnvBrowser() ? MOCK_CUSTODY : dataStore.evidenceCustody);
  let attachments = $derived(isEnvBrowser() ? [] : dataStore.evidenceAttachments);
  let imageAttachments = $derived((attachments || []).filter((attachment) => {
    const fileType = String(attachment.file_type || '').toLowerCase();
    const fileUrl = String(attachment.file_url || '').toLowerCase();
    return fileType.includes('image')
      || fileType.includes('photo')
      || /\.(png|jpe?g|webp|gif|bmp)$/i.test(fileUrl);
  }));
  let totalPages = $derived(Math.max(1, Math.ceil(evidenceTotal / 20)));

  $effect(() => {
    if (mode === 'list' && !isEnvBrowser()) {
      dataStore.fetchEvidence(currentPage);
    }
  });

  $effect(() => {
    if (!detail) return;
    editType = detail.type || 'general';
    editSerialNumber = detail.serial_number || '';
    editDescription = detail.description || '';
    editPhotoUrl = detail.photo_url || '';
    editStashLocation = detail.stash_location || '';
    editReportId = detail.report_id || '';
    editCaseId = detail.case_id || '';
    editStatus = detail.status || 'in_custody';
  });

  function goToList() {
    mode = 'list';
    dataStore.selectedEvidence = null;
    showTransferForm = false;
  }

  function goToCreate() {
    mode = 'create';
    createType = 'general';
    createSerialNumber = '';
    createDescription = '';
    createPhotoUrl = '';
    createStashLocation = '';
    createReportId = '';
    createCaseId = '';
  }

  async function openDetail(evidenceId) {
    if (!isEnvBrowser()) {
      await dataStore.getEvidenceRecord(evidenceId);
    }
    mode = 'detail';
    showTransferForm = false;
  }

  async function handleCreate() {
    if (!createDescription.trim()) return;
    creating = true;
    await dataStore.createEvidence({
      description: createDescription.trim(),
      type: createType,
      serialNumber: createSerialNumber.trim() || null,
      photoUrl: createPhotoUrl.trim(),
      stashLocation: createStashLocation.trim(),
      reportId: createReportId.trim() || null,
      caseId: createCaseId.trim() || null,
    });
    creating = false;
    goToList();
  }

  async function handleTransfer() {
    if (!detail || !transferToLocation.trim()) return;
    transferring = true;
    await dataStore.transferEvidence({
      evidenceId: detail.id || detail.evidence_id,
      fromOfficer: detail.collected_by || '',
      toOfficer: '',
      fromLocation: detail.stash_location || '',
      toLocation: transferToLocation.trim(),
      notes: transferNotes.trim(),
      newStatus: transferNewStatus,
    });
    transferring = false;
    showTransferForm = false;
    transferToLocation = '';
    transferNotes = '';
    transferNewStatus = 'in_custody';
    if (!isEnvBrowser()) {
      await dataStore.getEvidenceRecord(detail.id || detail.evidence_id);
    }
  }

  async function handleSaveEvidence() {
    if (!detail || !editDescription.trim()) return;
    creating = true;
    await dataStore.updateEvidence({
      evidenceId: detail.id || detail.evidence_id,
      type: editType,
      serialNumber: editSerialNumber.trim() || null,
      description: editDescription.trim(),
      photoUrl: editPhotoUrl.trim() || null,
      stashLocation: editStashLocation.trim() || null,
      reportId: editReportId.trim() || null,
      caseId: editCaseId.trim() || null,
      status: editStatus,
    });
    if (!isEnvBrowser()) {
      await dataStore.getEvidenceRecord(detail.id || detail.evidence_id);
    }
    creating = false;
  }

  async function handleAddAttachment() {
    if (!detail || !attachmentName.trim() || !attachmentUrl.trim()) return;
    creating = true;
    await dataStore.addAttachment({
      parentType: 'evidence',
      parentId: detail.id || detail.evidence_id,
      fileName: attachmentName.trim(),
      fileUrl: attachmentUrl.trim(),
      fileType: attachmentType.trim() || null,
      notes: attachmentNotes.trim() || null,
    });
    if (!isEnvBrowser()) {
      await dataStore.getEvidenceRecord(detail.id || detail.evidence_id);
    }
    attachmentName = '';
    attachmentUrl = '';
    attachmentType = '';
    attachmentNotes = '';
    creating = false;
  }

  async function handleRemoveAttachment(id) {
    if (!detail) return;
    creating = true;
    await dataStore.removeAttachment(id, 'evidence');
    if (!isEnvBrowser()) {
      await dataStore.getEvidenceRecord(detail.id || detail.evidence_id);
    }
    creating = false;
  }

  async function handleUseAttachmentAsPhoto(url) {
    if (!detail || !url) return;
    creating = true;
    editPhotoUrl = url;
    await dataStore.updateEvidence({
      evidenceId: detail.id || detail.evidence_id,
      type: editType,
      serialNumber: editSerialNumber.trim() || null,
      description: editDescription.trim(),
      photoUrl: url,
      stashLocation: editStashLocation.trim() || null,
      reportId: editReportId.trim() || null,
      caseId: editCaseId.trim() || null,
      status: editStatus,
    });
    if (!isEnvBrowser()) {
      await dataStore.getEvidenceRecord(detail.id || detail.evidence_id);
    }
    creating = false;
  }

  function prevPage() {
    if (currentPage > 1) currentPage--;
  }

  function nextPage() {
    if (currentPage < totalPages) currentPage++;
  }

  function getStatusDef(status) {
    return STATUS_DEFS[status] || { label: status || '—', color: 'var(--mdt-text-muted)' };
  }

  function getTypeLabel(type) {
    const found = EVIDENCE_TYPES.find(t => t.value === type);
    return found ? found.label : type || '—';
  }

  function formatDate(dateStr) {
    if (!dateStr) return '—';
    return dateStr;
  }

  function truncate(str, len) {
    if (!str) return '—';
    return str.length > len ? str.slice(0, len) + '...' : str;
  }
</script>

<div class="evidence-page">
  {#if mode === 'list'}
    <div class="list-mode">
      <div class="page-header">
        <div class="header-left">
          <h2 class="page-title">Evidence & Stash Locker</h2>
          <p class="page-subtitle">Manage physical and digital evidence records</p>
        </div>
        <button class="btn-primary" onclick={goToCreate}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14" /></svg>
          <span>Log Evidence</span>
        </button>
      </div>

      {#if evidenceItems.length > 0}
        <div class="results-table">
          <div class="table-header">
            <span class="th-tag">Evidence ID</span>
            <span class="th-type">Type</span>
            <span class="th-serial">Serial</span>
            <span class="th-desc">Description</span>
            <span class="th-officer">Collected By</span>
            <span class="th-status">Status</span>
            <span class="th-location">Location</span>
            <span class="th-date">Date</span>
          </div>
          {#each evidenceItems as item, i (item.id || item.evidence_id || i)}
            <button class="table-row" onclick={() => openDetail(item.id || item.evidence_id)}>
              <span class="td-tag font-mono">{item.evidence_tag || item.evidence_id}</span>
              <span class="td-type">{getTypeLabel(item.type)}</span>
              <span class="td-serial font-mono">{item.serial_number || '—'}</span>
              <span class="td-desc">{truncate(item.description, 40)}</span>
              <span class="td-officer">{item.collector_first ? `${item.collector_first} ${item.collector_last}` : (item.collected_by || '—')}</span>
              <span class="td-status">
                <span class="status-badge" style="--status-color: {getStatusDef(item.status).color}">{getStatusDef(item.status).label}</span>
              </span>
              <span class="td-location">{item.stash_location || '—'}</span>
              <span class="td-date font-mono">{formatDate(item.created_at)}</span>
            </button>
          {/each}
        </div>

        <div class="pagination">
          <button class="page-btn" onclick={prevPage} disabled={currentPage <= 1} aria-label="Previous evidence page">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6" /></svg>
          </button>
          <span class="page-info font-mono">Page {currentPage} of {totalPages}</span>
          <button class="page-btn" onclick={nextPage} disabled={currentPage >= totalPages} aria-label="Next evidence page">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6" /></svg>
          </button>
        </div>
      {:else}
        <div class="empty-state">
          <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
          </svg>
          <p class="empty-text">No evidence records found</p>
          <p class="empty-sub">Log new evidence to get started</p>
        </div>
      {/if}
    </div>

  {:else if mode === 'create'}
    <div class="create-mode">
      <button class="back-btn" onclick={goToList}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7" /></svg>
        <span>Back to Evidence</span>
      </button>

      <h2 class="page-title">Log New Evidence</h2>

      <div class="create-form">
        <div class="form-group">
          <label class="form-label" for="ev-type">Evidence Type</label>
          <select id="ev-type" class="form-select" bind:value={createType}>
            {#each EVIDENCE_TYPES as t (t.value)}
              <option value={t.value}>{t.label}</option>
            {/each}
          </select>
        </div>

        <div class="form-group">
          <label class="form-label" for="ev-desc">Description</label>
          <textarea
            id="ev-desc"
            class="form-textarea"
            placeholder="Describe the evidence in detail..."
            bind:value={createDescription}
            rows="4"
          ></textarea>
        </div>

        <div class="form-row">
          <div class="form-group form-group-half">
            <label class="form-label" for="ev-photo">Photo URL</label>
            <input
              id="ev-photo"
              type="text"
              class="form-input"
              placeholder="https://example.com/photo.png"
              bind:value={createPhotoUrl}
            />
          </div>
          <div class="form-group form-group-half">
            <label class="form-label" for="ev-stash">Stash Location</label>
            <input
              id="ev-stash"
              type="text"
              class="form-input"
              placeholder="e.g. Locker 12-B"
              bind:value={createStashLocation}
            />
          </div>
        </div>

        {#if createPhotoUrl.trim()}
          <div class="photo-preview-box">
            <span class="form-label">Photo Preview</span>
            <div class="photo-preview-frame">
              <img src={createPhotoUrl} alt="Evidence preview" class="photo-preview-img" />
            </div>
          </div>
        {/if}

        <div class="form-row">
          <div class="form-group form-group-half">
            <label class="form-label" for="ev-report">Report ID (optional)</label>
            <input
              id="ev-report"
              type="text"
              class="form-input font-mono"
              placeholder="RPT-00000000-0000"
              bind:value={createReportId}
            />
          </div>
          <div class="form-group form-group-half">
            <label class="form-label" for="ev-case">Case ID (optional)</label>
            <input
              id="ev-case"
              type="text"
              class="form-input font-mono"
              placeholder="CASE-00000000-0000"
              bind:value={createCaseId}
            />
          </div>
          <div class="form-group form-group-half">
            <label class="form-label" for="ev-serial">Serial Number (optional)</label>
            <input
              id="ev-serial"
              type="text"
              class="form-input font-mono"
              placeholder="SN-000000"
              bind:value={createSerialNumber}
            />
          </div>
        </div>

        <button
          class="btn-primary btn-create"
          onclick={handleCreate}
          disabled={creating || !createDescription.trim()}
        >
          {#if creating}Creating...{:else}Create Evidence Record{/if}
        </button>
      </div>
    </div>

  {:else if mode === 'detail' && detail}
    <div class="detail-mode">
      <button class="back-btn" onclick={goToList}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7" /></svg>
        <span>Back to Evidence</span>
      </button>

      <div class="detail-header">
        <div class="detail-header-left">
          <span class="detail-tag font-mono">{detail.evidence_tag || detail.evidence_id}</span>
          <div class="detail-badges">
            <span class="type-badge">{getTypeLabel(detail.type)}</span>
            <span class="status-badge" style="--status-color: {getStatusDef(detail.status).color}">{getStatusDef(detail.status).label}</span>
          </div>
        </div>
        <div class="detail-header-meta">
          <div class="detail-meta-line">
            <span class="detail-meta-k">Created</span>
            <span class="detail-meta-v font-mono">{formatDate(detail.created_at)}</span>
          </div>
          {#if detail.collector_first || detail.collected_by}
            <div class="detail-meta-line">
              <span class="detail-meta-k">Collected by</span>
              <span class="detail-meta-v">{detail.collector_first ? `${detail.collector_first} ${detail.collector_last || ''}`.trim() : (typeof detail.collected_by === 'string' ? detail.collected_by : '—')}</span>
            </div>
          {/if}
        </div>
      </div>

      <div class="detail-body">
        <div class="detail-main">
          <div class="detail-section">
            <h3 class="section-label">Description</h3>
            <p class="detail-description">{detail.description || '—'}</p>
          </div>

          {#if detail.photo_url}
            <div class="detail-section">
              <h3 class="section-label">Photo</h3>
              <div class="detail-photo-frame">
                <img src={detail.photo_url} alt="Primary evidence record" class="detail-photo-img" />
              </div>
            </div>
          {/if}

          {#if imageAttachments.length > 0}
            <div class="detail-section">
              <h3 class="section-label">Attachment Gallery</h3>
              <div class="attachment-gallery">
                {#each imageAttachments as attachment (attachment.id)}
                  <div class="gallery-card">
                    <div class="gallery-frame">
                      <img src={attachment.file_url} alt={attachment.file_name || 'Evidence attachment'} class="gallery-img" />
                    </div>
                    <div class="gallery-meta">
                      <span class="gallery-name">{attachment.file_name}</span>
                      <div class="gallery-actions">
                        <a class="gallery-link" href={attachment.file_url} target="_blank" rel="noreferrer">Open</a>
                        <button class="gallery-btn" onclick={() => handleUseAttachmentAsPhoto(attachment.file_url)} disabled={creating}>
                          Use as Primary Photo
                        </button>
                      </div>
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {/if}

          <div class="detail-meta-grid">
            <div class="meta-block">
              <span class="meta-label">Stash Location</span>
              <span class="meta-value">{detail.stash_location || '—'}</span>
            </div>
            <div class="meta-block">
              <span class="meta-label">Serial Number</span>
              <span class="meta-value font-mono">{detail.serial_number || 'Not logged'}</span>
            </div>
            <div class="meta-block">
              <span class="meta-label">Collected By</span>
              <span class="meta-value">{detail.collector_first ? `${detail.collector_first} ${detail.collector_last}` : (typeof detail.collected_by === 'string' ? detail.collected_by : '—')}</span>
            </div>
            {#if detail.report_id}
              <div class="meta-block">
                <span class="meta-label">Report</span>
                <span class="meta-value font-mono">{detail.report_id}</span>
              </div>
            {/if}
            {#if detail.case_id}
              <div class="meta-block">
                <span class="meta-label">Case</span>
                <span class="meta-value font-mono">{detail.case_id}</span>
              </div>
            {/if}
          </div>
        </div>

        <div class="detail-sidebar">
          <div class="custody-section">
            <h3 class="section-label">Update Record</h3>
            <div class="form-group">
              <label class="form-label" for="evidence-edit-type">Type</label>
              <select id="evidence-edit-type" class="form-select" bind:value={editType}>
                {#each EVIDENCE_TYPES as t (t.value)}
                  <option value={t.value}>{t.label}</option>
                {/each}
              </select>
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-edit-serial">Serial Number</label>
              <input id="evidence-edit-serial" class="form-input font-mono" bind:value={editSerialNumber} placeholder="SN-000000" />
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-edit-description">Description</label>
              <textarea id="evidence-edit-description" class="form-textarea" rows="3" bind:value={editDescription}></textarea>
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-edit-photo-url">Photo URL</label>
              <input id="evidence-edit-photo-url" class="form-input" bind:value={editPhotoUrl} placeholder="https://..." />
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-edit-stash">Stash Location</label>
              <input id="evidence-edit-stash" class="form-input" bind:value={editStashLocation} placeholder="Locker / vault" />
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-edit-status">Status</label>
              <select id="evidence-edit-status" class="form-select" bind:value={editStatus}>
                {#each TRANSFER_STATUSES as s (s.value)}
                  <option value={s.value}>{s.label}</option>
                {/each}
              </select>
            </div>
            <button class="btn-primary btn-save-evidence" onclick={handleSaveEvidence} disabled={creating || !editDescription.trim()}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z" /><path d="M17 21v-8H7v8M7 3v5h8" /></svg>
              {#if creating}Saving...{:else}Save Evidence{/if}
            </button>
          </div>

          <div class="custody-section">
            <h3 class="section-label">Attachments</h3>
            {#if attachments && attachments.length > 0}
              <div class="custody-timeline">
                {#each attachments as attachment (attachment.id)}
                  <div class="custody-entry">
                    <div class="custody-content">
                      <div class="custody-header">
                        <a class="custody-action" href={attachment.file_url} target="_blank" rel="noreferrer">{attachment.file_name}</a>
                        <div class="attachment-actions">
                          {#if String(attachment.file_type || '').toLowerCase().includes('image') || String(attachment.file_url || '').match(/\.(png|jpe?g|webp|gif|bmp)$/i)}
                            <button class="btn-link-inline" onclick={() => handleUseAttachmentAsPhoto(attachment.file_url)} disabled={creating}>
                              Primary Photo
                            </button>
                          {/if}
                          <button class="btn-remove" onclick={() => handleRemoveAttachment(attachment.id)} aria-label="Remove attachment">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                          </button>
                        </div>
                      </div>
                      <p class="custody-notes">{attachment.file_type || 'file'}{attachment.notes ? ` • ${attachment.notes}` : ''}</p>
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="tab-empty">No evidence files attached</p>
            {/if}

            <div class="form-group">
              <label class="form-label" for="evidence-attachment-name">File Name</label>
              <input id="evidence-attachment-name" class="form-input" bind:value={attachmentName} placeholder="Lab report.pdf" />
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-attachment-url">File URL</label>
              <input id="evidence-attachment-url" class="form-input" bind:value={attachmentUrl} placeholder="https://..." />
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-attachment-type">File Type</label>
              <input id="evidence-attachment-type" class="form-input" bind:value={attachmentType} placeholder="pdf, image, doc..." />
            </div>
            <div class="form-group">
              <label class="form-label" for="evidence-attachment-notes">Notes</label>
              <input id="evidence-attachment-notes" class="form-input" bind:value={attachmentNotes} placeholder="Optional notes" />
            </div>
            <button class="btn-primary" onclick={handleAddAttachment} disabled={creating || !attachmentName.trim() || !attachmentUrl.trim()}>
              {#if creating}Saving...{:else}Add Attachment{/if}
            </button>
          </div>

          <div class="custody-section">
            <h3 class="section-label">Chain of Custody</h3>
            {#if custody && custody.length > 0}
              <div class="custody-timeline">
                {#each custody as entry, i (entry.id || i)}
                  <div class="custody-entry" class:custody-first={i === 0} class:custody-last={i === custody.length - 1}>
                    <div class="custody-connector">
                      <div class="custody-dot"></div>
                      {#if i < custody.length - 1}
                        <div class="custody-line"></div>
                      {/if}
                    </div>
                    <div class="custody-content">
                      <div class="custody-header">
                        <span class="custody-action">{entry.action}</span>
                        <span class="custody-timestamp font-mono">{formatDate(entry.timestamp)}</span>
                      </div>
                      {#if entry.from_officer || entry.to_officer || entry.from_first || entry.to_first}
                        <div class="custody-transfer-row">
                          <span class="custody-officer">{entry.from_first ? `${entry.from_first} ${entry.from_last}` : (entry.from_officer || 'Origin')}</span>
                          <svg class="custody-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7" /></svg>
                          <span class="custody-officer">{entry.to_first ? `${entry.to_first} ${entry.to_last}` : (entry.to_officer || '—')}</span>
                        </div>
                      {/if}
                      {#if entry.from_location || entry.to_location}
                        <div class="custody-location-row">
                          <span class="custody-loc">{entry.from_location || '—'}</span>
                          <svg class="custody-arrow-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14M12 5l7 7-7 7" /></svg>
                          <span class="custody-loc">{entry.to_location || '—'}</span>
                        </div>
                      {/if}
                      {#if entry.notes}
                        <p class="custody-notes">{entry.notes}</p>
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <p class="tab-empty">No custody records</p>
            {/if}
          </div>

          {#if !showTransferForm}
            <button class="btn-primary btn-transfer" onclick={() => { showTransferForm = true; transferToLocation = ''; transferNotes = ''; transferNewStatus = 'in_custody'; }}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 17l9.2-9.2M17 17V7H7" /></svg>
              <span>Transfer Evidence</span>
            </button>
          {:else}
            <div class="transfer-form">
              <h3 class="section-label">Transfer Evidence</h3>
              <div class="form-group">
                <label class="form-label" for="tr-location">To Location</label>
                <input
                  id="tr-location"
                  type="text"
                  class="form-input"
                  placeholder="e.g. Evidence Processing"
                  bind:value={transferToLocation}
                />
              </div>
              <div class="form-group">
                <label class="form-label" for="tr-notes">Notes</label>
                <input
                  id="tr-notes"
                  type="text"
                  class="form-input"
                  placeholder="Reason for transfer..."
                  bind:value={transferNotes}
                />
              </div>
              <div class="form-group">
                <label class="form-label" for="tr-status">New Status</label>
                <select id="tr-status" class="form-select" bind:value={transferNewStatus}>
                  {#each TRANSFER_STATUSES as s (s.value)}
                    <option value={s.value}>{s.label}</option>
                  {/each}
                </select>
              </div>
              <div class="transfer-actions">
                <button
                  class="btn-primary"
                  onclick={handleTransfer}
                  disabled={transferring || !transferToLocation.trim()}
                >
                  {#if transferring}Transferring...{:else}Confirm Transfer{/if}
                </button>
                <button class="btn-cancel" onclick={() => { showTransferForm = false; }}>Cancel</button>
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .evidence-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale));
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    height: 100%;
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

  .btn-primary {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
    flex-shrink: 0;
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

  .results-table {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
  }

  .table-header {
    display: grid;
    grid-template-columns: 1.2fr 0.8fr 1fr 1.8fr 1.1fr 0.9fr 1fr 1fr;
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
    grid-template-columns: 1.2fr 0.8fr 1fr 1.8fr 1.1fr 0.9fr 1fr 1fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    font-family: inherit;
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

  .td-tag {
    color: var(--mdt-accent-dim);
    font-size: calc(11px * var(--mdt-scale));
  }

  .td-type {
    color: var(--mdt-text-dim);
    text-transform: capitalize;
  }

  .td-serial {
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
  }

  .td-desc {
    color: var(--mdt-text-dim);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .td-officer {
    color: var(--mdt-text-dim);
  }

  .td-status {
    display: flex;
    align-items: center;
  }

  .td-location {
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
  }

  .td-date {
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    background: color-mix(in srgb, var(--status-color) 15%, transparent);
    color: var(--status-color);
    border: 1px solid color-mix(in srgb, var(--status-color) 25%, transparent);
    white-space: nowrap;
    line-height: 1.4;
  }

  .type-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    background: var(--mdt-surface-3);
    color: var(--mdt-text-dim);
    border: 1px solid var(--mdt-border);
    white-space: nowrap;
    line-height: 1.4;
    text-transform: capitalize;
  }

  .pagination {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .page-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease, transform 0.1s ease;
    padding: 0;
  }

  .page-btn svg {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
  }

  .page-btn:hover:not(:disabled) {
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
  }

  .page-btn:active:not(:disabled) {
    transform: scale(0.96);
  }

  .page-btn:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }

  .page-info {
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
  }

  .empty-sub {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
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
    font-family: inherit;
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
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(20px * var(--mdt-scale));
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(14px * var(--mdt-scale));
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
  }

  .form-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    box-sizing: border-box;
  }

  .form-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-input:focus {
    border-color: var(--mdt-accent);
  }

  .form-select {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    cursor: pointer;
    appearance: none;
    box-sizing: border-box;
  }

  .form-select:focus {
    border-color: var(--mdt-accent);
  }

  .form-textarea {
    width: 100%;
    resize: vertical;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.5;
    outline: none;
    transition: border-color 0.15s ease;
    min-height: calc(60px * var(--mdt-scale));
    box-sizing: border-box;
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .photo-preview-box {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .photo-preview-frame {
    width: calc(120px * var(--mdt-scale));
    height: calc(90px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    overflow: hidden;
  }

  .photo-preview-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .btn-create {
    align-self: flex-start;
    margin-top: calc(4px * var(--mdt-scale));
  }

  .detail-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(20px * var(--mdt-scale));
  }

  .detail-header-left {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .detail-tag {
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
    letter-spacing: 0.02em;
  }

  .detail-badges {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
  }

  .detail-header-meta {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: calc(6px * var(--mdt-scale));
    flex-shrink: 0;
    text-align: right;
  }

  .detail-meta-line {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: calc(2px * var(--mdt-scale));
  }

  .detail-meta-k {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .detail-meta-v {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
  }

  .detail-body {
    display: grid;
    grid-template-columns: 1fr calc(340px * var(--mdt-scale));
    gap: calc(16px * var(--mdt-scale));
    align-items: start;
  }

  .detail-main {
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
  }

  .detail-section {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(16px * var(--mdt-scale));
  }

  .section-label {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .detail-description {
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text);
    line-height: 1.6;
  }

  .detail-photo-frame {
    width: 100%;
    max-width: calc(400px * var(--mdt-scale));
    aspect-ratio: 16 / 10;
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    overflow: hidden;
  }

  .detail-photo-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .attachment-gallery {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(170px * var(--mdt-scale)), 1fr));
    gap: calc(12px * var(--mdt-scale));
  }

  .gallery-card {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(10px * var(--mdt-scale));
  }

  .gallery-frame {
    aspect-ratio: 4 / 3;
    border-radius: var(--mdt-radius-sm);
    overflow: hidden;
    background: var(--mdt-surface-2);
  }

  .gallery-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .gallery-meta {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .gallery-name {
    color: var(--mdt-text);
    font-size: calc(12px * var(--mdt-scale));
    word-break: break-word;
  }

  .gallery-actions,
  .attachment-actions {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .gallery-link,
  .gallery-btn,
  .btn-link-inline {
    border: none;
    background: transparent;
    color: var(--mdt-accent);
    padding: 0;
    font: inherit;
    cursor: pointer;
    text-decoration: none;
  }

  .detail-meta-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(160px * var(--mdt-scale)), 1fr));
    gap: calc(12px * var(--mdt-scale));
  }

  .meta-block {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
  }

  .meta-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .meta-value {
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 500;
  }

  .detail-sidebar {
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
  }

  .custody-section {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(16px * var(--mdt-scale));
  }

  .custody-timeline {
    display: flex;
    flex-direction: column;
  }

  .custody-entry {
    display: flex;
    gap: calc(12px * var(--mdt-scale));
    position: relative;
  }

  .custody-connector {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: calc(16px * var(--mdt-scale));
    flex-shrink: 0;
    padding-top: calc(4px * var(--mdt-scale));
  }

  .custody-dot {
    width: calc(10px * var(--mdt-scale));
    height: calc(10px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-accent);
    border: calc(2px * var(--mdt-scale)) solid var(--mdt-surface);
    box-shadow: 0 0 0 calc(1px * var(--mdt-scale)) var(--mdt-accent-dim);
    flex-shrink: 0;
    z-index: 1;
  }

  .custody-line {
    width: calc(2px * var(--mdt-scale));
    flex: 1;
    background: var(--mdt-border-2);
    margin-top: calc(2px * var(--mdt-scale));
  }

  .custody-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    padding-bottom: calc(16px * var(--mdt-scale));
    min-width: 0;
  }

  .custody-last .custody-content {
    padding-bottom: 0;
  }

  .custody-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .custody-action {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .custody-timestamp {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .custody-transfer-row {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .custody-officer {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-accent-dim);
    font-weight: 500;
  }

  .custody-arrow {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .custody-location-row {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .custody-loc {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .custody-arrow-sm {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .custody-notes {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
    margin-top: calc(2px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-radius: var(--mdt-radius-sm);
    border-left: calc(2px * var(--mdt-scale)) solid var(--mdt-border-2);
  }

  .btn-transfer {
    width: 100%;
    justify-content: center;
  }

  .transfer-form {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-accent-dim);
    border-radius: var(--mdt-radius);
    padding: calc(16px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .transfer-actions {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    margin-top: calc(4px * var(--mdt-scale));
  }

  .btn-cancel {
    display: inline-flex;
    align-items: center;
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease, transform 0.1s ease;
  }

  .btn-cancel:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .btn-cancel:active {
    transform: scale(0.96);
  }

  .tab-empty {
    text-align: center;
    color: var(--mdt-text-muted);
    font-size: calc(12px * var(--mdt-scale));
    padding: calc(20px * var(--mdt-scale)) 0;
    opacity: 0.6;
  }

  .font-mono {
    font-family: 'Share Tech Mono', monospace;
  }

  /* Detail view — incident-report panel styling */
  .detail-mode {
    --ev-panel: #22252c;
    --ev-panel-inset: #1a1d24;
    --ev-border: #2d3139;
    --ev-accent: #3b82f6;
    --ev-accent-muted: #60a5fa;
    --ev-tag: #93c5fd;
    --ev-label: #8b95a8;
  }

  .detail-mode .back-btn {
    background: var(--ev-panel);
    border: 1px solid var(--ev-border);
    color: var(--ev-accent);
  }

  .detail-mode .back-btn:hover {
    background: #262a32;
    border-color: color-mix(in srgb, var(--ev-accent) 35%, var(--ev-border));
    color: var(--ev-accent-muted);
  }

  .detail-mode .detail-header {
    background: var(--ev-panel);
    border: 1px solid var(--ev-border);
    border-radius: calc(6px * var(--mdt-scale));
    box-shadow: 0 1px 0 rgba(255, 255, 255, 0.04) inset;
  }

  .detail-mode .detail-tag {
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--ev-tag);
    letter-spacing: 0.04em;
  }

  .detail-mode .type-badge {
    border-radius: calc(6px * var(--mdt-scale));
    background: rgba(59, 130, 246, 0.1);
    border: 1px solid rgba(59, 130, 246, 0.4);
    color: #bfdbfe;
  }

  .detail-mode .status-badge {
    border-radius: calc(6px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
  }

  .detail-mode .detail-meta-k {
    color: var(--ev-label);
  }

  .detail-mode .detail-meta-v.font-mono {
    color: var(--ev-accent-muted);
    font-size: calc(11px * var(--mdt-scale));
  }

  .detail-mode .detail-body {
    gap: calc(18px * var(--mdt-scale));
  }

  .detail-mode .detail-section,
  .detail-mode .custody-section,
  .detail-mode .meta-block,
  .detail-mode .gallery-card {
    background: var(--ev-panel);
    border: 1px solid var(--ev-border);
    border-radius: calc(6px * var(--mdt-scale));
    box-shadow: 0 1px 0 rgba(255, 255, 255, 0.03) inset;
  }

  .detail-mode .section-label {
    color: var(--ev-label);
    letter-spacing: 0.08em;
    font-size: calc(10px * var(--mdt-scale));
  }

  .detail-mode .detail-description {
    color: #e8eaef;
  }

  .detail-mode .detail-photo-frame,
  .detail-mode .gallery-frame {
    border-color: var(--ev-border);
    background: var(--ev-panel-inset);
    border-radius: calc(6px * var(--mdt-scale));
  }

  .detail-mode .form-label {
    color: var(--ev-label);
  }

  .detail-mode .form-input,
  .detail-mode .form-select,
  .detail-mode .form-textarea {
    background: var(--ev-panel-inset);
    border: 1px solid var(--ev-border);
    border-radius: calc(6px * var(--mdt-scale));
    color: #e8eaef;
  }

  .detail-mode .form-input:focus,
  .detail-mode .form-select:focus,
  .detail-mode .form-textarea:focus {
    border-color: var(--ev-accent);
    box-shadow: 0 0 0 1px rgba(59, 130, 246, 0.25);
  }

  .detail-mode .btn-primary {
    background: var(--ev-accent);
    color: #ffffff;
    border-radius: calc(6px * var(--mdt-scale));
  }

  .detail-mode .btn-primary:hover {
    opacity: 1;
    filter: brightness(1.06);
  }

  .detail-mode .btn-save-evidence svg {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .detail-mode .btn-cancel {
    background: var(--ev-panel-inset);
    border-color: var(--ev-border);
    color: var(--ev-accent-muted);
    border-radius: calc(6px * var(--mdt-scale));
  }

  .detail-mode .btn-cancel:hover {
    border-color: color-mix(in srgb, var(--ev-accent) 40%, var(--ev-border));
    color: #dbeafe;
  }

  .detail-mode .btn-transfer {
    background: transparent;
    border: 1px solid color-mix(in srgb, var(--ev-accent) 45%, var(--ev-border));
    color: var(--ev-accent-muted);
  }

  .detail-mode .btn-transfer:hover {
    background: rgba(59, 130, 246, 0.08);
    color: #dbeafe;
  }

  .detail-mode .gallery-link,
  .detail-mode .btn-link-inline {
    color: var(--ev-accent-muted);
  }

  .detail-mode .gallery-btn {
    border: 1px solid var(--ev-border);
    background: var(--ev-panel-inset);
    color: var(--ev-accent-muted);
    padding: calc(4px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(6px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
  }

  .detail-mode .tab-empty {
    border: 1px dashed var(--ev-border);
    border-radius: calc(6px * var(--mdt-scale));
    padding: calc(18px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: rgba(0, 0, 0, 0.15);
    color: var(--ev-label);
    font-size: calc(11px * var(--mdt-scale));
  }

  .detail-mode .custody-dot {
    background: var(--ev-accent);
    border-color: var(--ev-panel);
    box-shadow: 0 0 0 1px rgba(59, 130, 246, 0.35);
  }

  .detail-mode .custody-line {
    background: var(--ev-border);
  }

  .detail-mode .custody-officer {
    color: #93c5fd;
  }

  .detail-mode .custody-notes {
    background: var(--ev-panel-inset);
    border-left-color: rgba(59, 130, 246, 0.45);
    border-radius: calc(4px * var(--mdt-scale));
  }

  .detail-mode .transfer-form {
    background: var(--ev-panel);
    border: 1px solid var(--ev-border);
  }

  .detail-mode .btn-remove {
    border: 1px solid var(--ev-border);
    background: var(--ev-panel-inset);
    border-radius: calc(6px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding: calc(4px * var(--mdt-scale));
    cursor: pointer;
    transition: border-color 0.12s ease, color 0.12s ease;
  }

  .detail-mode .btn-remove:hover {
    border-color: rgba(248, 113, 113, 0.5);
    color: #f87171;
  }

  .detail-mode .meta-label {
    color: var(--ev-label);
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
