<script>
  import { onMount, untrack } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { REPORT_TEMPLATES } from '../lib/data/reportTemplates.js';
  import { reportsCompose } from '../lib/stores/reportsCompose.svelte.js';
  import CitationIssueModal from '../lib/components/CitationIssueModal.svelte';
  import MdtCheckbox from '../lib/components/MdtCheckbox.svelte';

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

  let mode = $state('list');
  let activeFilter = $state('all');
  let currentPage = $state(1);
  let mounted = $state(false);
  let saving = $state(false);
  let confirmAction = $state(null);
  let priorityMenuOpen = $state(false);
  /** @type {HTMLElement | null} */
  let priorityPopoverEl = $state(null);

  let createTitle = $state('');
  let createTemplate = $state(REPORT_TEMPLATES[0]);
  let createNarrative = $state('');
  let createTagInput = $state('');
  let createTags = $state([]);

  let editTitle = $state('');
  let editNarrative = $state('');
  let editPriority = $state('normal');
  let editTags = $state([]);
  let editTagInput = $state('');
  let editRestricted = $state(false);
  let editRestrictedTo = $state('');
  let reportParticipantsDraft = $state([]);
  let reportChargesDraft = $state([]);
  let reportAttachmentName = $state('');
  let reportAttachmentUrl = $state('');
  let reportAttachmentType = $state('');
  let reportAttachmentNotes = $state('');

  let timelineDesc = $state('');
  let timelineTime = $state('');

  // ─── Citation Modal State ───
  let showCitationModal = $state(false);
  let citationIssuing = $state(false);

  // ─── Charges Modal State ───
  let showChargesModal = $state(false);
  let chargeSearch = $state('');
  let chargeFilterCat = $state('all');

  const CHARGE_CATEGORIES = [
    { id: 'all', label: 'All' },
    { id: 'traffic', label: 'Traffic' },
    { id: 'public_order', label: 'Public Order' },
    { id: 'property', label: 'Property' },
    { id: 'violent', label: 'Violent' },
    { id: 'weapons', label: 'Weapons' },
    { id: 'drugs', label: 'Drugs' },
    { id: 'government', label: 'Government' },
    { id: 'fraud', label: 'Fraud' },
    { id: 'other', label: 'Other' },
  ];

  const SEVERITY_COLORS = {
    infraction: 'var(--mdt-text-muted)',
    misdemeanor: 'var(--mdt-warning)',
    felony: 'var(--mdt-error)',
  };

  let chargesList = $derived(dataStore.chargesList || []);

  let filteredCharges = $derived.by(() => {
    let list = chargesList;
    if (chargeFilterCat !== 'all') {
      list = list.filter(c => c.category === chargeFilterCat);
    }
    if (chargeSearch.trim()) {
      const q = chargeSearch.trim().toLowerCase();
      list = list.filter(c => (c.charge || '').toLowerCase().includes(q));
    }
    return list;
  });

  // ─── Participants Modal State ───
  let showParticipantsModal = $state(false);
  let participantSearch = $state('');
  let participantSearchResults = $state([]);
  let participantSearching = $state(false);
  let participantType = $state('suspect');

  let reports = $derived(dataStore.reportsList || []);
  let total = $derived(dataStore.reportsTotal || 0);
  let report = $derived(dataStore.selectedReport);
  let timeline = $derived(dataStore.reportTimeline || []);
  let entities = $derived(dataStore.reportEntities || []);
  let participants = $derived(dataStore.reportParticipants || []);
  let charges = $derived(dataStore.reportCharges || []);
  let attachments = $derived(dataStore.reportAttachments || []);
  let collaborators = $derived(dataStore.reportCollaborators || []);
  let officer = $derived(mdtStore.officer);

  let totalPages = $derived(Math.max(1, Math.ceil(total / 15)));

  let availableStatusActions = $derived(
    report
      ? STATUS_ACTIONS.filter((a) => a.status !== (report.status || 'draft'))
      : [],
  );

  $effect(() => {
    if (report) {
      editTitle = report.title || '';
      editNarrative = report.narrative || '';
      editPriority = report.priority || 'normal';
      editTags = [...(report.tags || [])];
      editRestricted = report.restricted === true || report.restricted === 1;
      editRestrictedTo = Array.isArray(report.restricted_to) ? report.restricted_to.join(', ') : '';
      reportParticipantsDraft = participants.map((entry) => ({
        participantType: entry.participant_type || 'suspect',
        name: entry.name || '',
        citizenId: entry.citizen_id || '',
        officerId: entry.officer_id || '',
        notes: entry.notes || '',
      }));
      reportChargesDraft = charges.map((entry) => ({
        charge: entry.charge || '',
        severity: entry.severity || 'misdemeanor',
        count: entry.count || 1,
        fine: entry.fine || 0,
        notes: entry.notes || '',
      }));
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

  function togglePriorityMenu() {
    priorityMenuOpen = !priorityMenuOpen;
  }

  function selectPriority(pri) {
    editPriority = pri;
    priorityMenuOpen = false;
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
    createTemplate = REPORT_TEMPLATES[0];
    createNarrative = '';
    createTags = [];
    createTagInput = '';
    reportParticipantsDraft = [];
    reportChargesDraft = [];
    mode = 'create';
  }

  $effect(() => {
    const v = reportsCompose.tick;
    if (v < 1) return;
    untrack(() => {
      const p = reportsCompose.consume();
      if (!p) return;
      dataStore.selectedReport = null;
      dataStore.reportTimeline = [];
      dataStore.reportEntities = [];
      dataStore.reportParticipants = [];
      dataStore.reportCharges = [];
      dataStore.reportAttachments = [];
      dataStore.reportCollaborators = [];
      createTitle = p.title || '';
      createTemplate = REPORT_TEMPLATES.includes(p.template) ? p.template : REPORT_TEMPLATES[0];
      createNarrative = p.narrative || '';
      createTags = [];
      createTagInput = '';
      reportParticipantsDraft = [];
      reportChargesDraft = [];
      mode = 'create';
    });
  });

  function openDetail(reportId) {
    if (isEnvBrowser()) {
      const selected = (reports || []).find((entry) => entry.id === reportId) || null;
      dataStore.selectedReport = selected;
      dataStore.reportTimeline = [];
      dataStore.reportEntities = [];
      dataStore.reportParticipants = [];
      dataStore.reportCharges = [];
      dataStore.reportAttachments = [];
      dataStore.reportCollaborators = selected ? [{ name: selected.author_name || 'Officer' }] : [];
    } else {
      dataStore.getReport(reportId);
    }
    mode = 'detail';
  }

  function goBackToList() {
    dataStore.selectedReport = null;
    dataStore.reportTimeline = [];
    dataStore.reportEntities = [];
    dataStore.reportParticipants = [];
    dataStore.reportCharges = [];
    dataStore.reportAttachments = [];
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

  function addParticipantRow() {
    reportParticipantsDraft = [
      ...reportParticipantsDraft,
      { participantType: 'suspect', name: '', citizenId: '', officerId: '', notes: '' },
    ];
  }

  function removeParticipantRow(index) {
    reportParticipantsDraft = reportParticipantsDraft.filter((_, rowIndex) => rowIndex !== index);
  }

  function addChargeRow() {
    reportChargesDraft = [
      ...reportChargesDraft,
      { charge: '', severity: 'misdemeanor', count: 1, fine: 0, notes: '' },
    ];
  }

  function removeChargeRow(index) {
    reportChargesDraft = reportChargesDraft.filter((_, rowIndex) => rowIndex !== index);
  }

  // ─── Charges Modal ───
  function openChargesModal() {
    chargeSearch = '';
    chargeFilterCat = 'all';
    if (chargesList.length === 0) {
      dataStore.fetchCharges?.();
    }
    showChargesModal = true;
  }

  function selectCharge(charge) {
    reportChargesDraft = [
      ...reportChargesDraft,
      {
        charge: charge.charge,
        severity: charge.severity,
        count: 1,
        fine: charge.fine || 0,
        jailTime: charge.jailTime || 0,
        notes: '',
      },
    ];
    showChargesModal = false;
  }

  // ─── Participants Modal ───
  function openParticipantsModal() {
    participantSearch = '';
    participantSearchResults = [];
    participantType = 'suspect';
    showParticipantsModal = true;
  }

  async function searchCitizensForParticipant() {
    if (!participantSearch.trim()) return;
    participantSearching = true;
    const resp = await dataStore.searchCitizens(participantSearch.trim());
    if (resp?.ok && Array.isArray(resp.results)) {
      participantSearchResults = resp.results;
    } else if (isEnvBrowser()) {
      participantSearchResults = [
        { id: 'CIT-00102', firstName: 'John', lastName: 'Doe', dob: '1990-05-14' },
        { id: 'CIT-00234', firstName: 'Jane', lastName: 'Smith', dob: '1988-11-22' },
        { id: 'CIT-00345', firstName: 'Mike', lastName: 'Johnson', dob: '1995-03-08' },
      ].filter(c =>
        `${c.firstName} ${c.lastName}`.toLowerCase().includes(participantSearch.trim().toLowerCase()) ||
        c.id.toLowerCase().includes(participantSearch.trim().toLowerCase())
      );
      if (participantSearchResults.length === 0) {
        participantSearchResults = [
          { id: 'CIT-00102', firstName: 'John', lastName: 'Doe', dob: '1990-05-14' },
          { id: 'CIT-00234', firstName: 'Jane', lastName: 'Smith', dob: '1988-11-22' },
        ];
      }
    }
    participantSearching = false;
  }

  function selectParticipant(citizen) {
    reportParticipantsDraft = [
      ...reportParticipantsDraft,
      {
        participantType: participantType,
        name: `${citizen.firstName} ${citizen.lastName}`,
        citizenId: citizen.id || '',
        officerId: '',
        notes: '',
      },
    ];
    showParticipantsModal = false;
  }

  async function handleAddAttachment() {
    if (!report || !reportAttachmentName.trim() || !reportAttachmentUrl.trim()) return;
    saving = true;
    await dataStore.addAttachment({
      parentType: 'report',
      parentId: report.id,
      fileName: reportAttachmentName.trim(),
      fileUrl: reportAttachmentUrl.trim(),
      fileType: reportAttachmentType.trim() || null,
      notes: reportAttachmentNotes.trim() || null,
    });
    await dataStore.getReport(report.id);
    reportAttachmentName = '';
    reportAttachmentUrl = '';
    reportAttachmentType = '';
    reportAttachmentNotes = '';
    saving = false;
  }

  async function handleRemoveAttachment(attachmentId) {
    if (!report) return;
    saving = true;
    await dataStore.removeAttachment(attachmentId, 'report');
    await dataStore.getReport(report.id);
    saving = false;
  }

  async function handleIssueCitation(data) {
    if (!report) return;
    citationIssuing = true;
    const resp = await dataStore.issueCitation({
      reportId: report.id,
      citizenId: data.citizenId,
      playerName: data.playerName || '',
      notes: data.notes || '',
    });
    citationIssuing = false;
    if (resp?.ok) {
      showCitationModal = false;
      if (isEnvBrowser()) {
        alert(`Citation ${resp.citation?.citation_number} issued to ${resp.citation?.issued_to?.name}`);
      }
    }
  }

  async function handleCreate() {
    if (!createTitle.trim()) return;
    saving = true;
    const resp = await dataStore.createReport({
      title: createTitle.trim(),
      template: createTemplate,
      narrative: createNarrative,
      tags: createTags,
      participants: reportParticipantsDraft
        .map((entry) => ({
          participantType: entry.participantType,
          name: entry.name.trim(),
          citizenId: entry.citizenId.trim() || null,
          officerId: String(entry.officerId || '').trim() || null,
          notes: entry.notes.trim() || null,
        }))
        .filter((entry) => entry.name),
      charges: reportChargesDraft
        .map((entry) => ({
          charge: entry.charge.trim(),
          severity: entry.severity,
          count: Number(entry.count) || 1,
          fine: Number(entry.fine) || 0,
          notes: entry.notes.trim() || null,
        }))
        .filter((entry) => entry.charge),
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
      dataStore.reportParticipants = reportParticipantsDraft;
      dataStore.reportCharges = reportChargesDraft;
      dataStore.reportAttachments = [];
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
      restricted: editRestricted,
      restrictedTo: editRestrictedTo.split(',').map(entry => entry.trim()).filter(Boolean),
      participants: reportParticipantsDraft
        .map((entry) => ({
          participantType: entry.participantType,
          name: entry.name.trim(),
          citizenId: entry.citizenId.trim() || null,
          officerId: String(entry.officerId || '').trim() || null,
          notes: entry.notes.trim() || null,
        }))
        .filter((entry) => entry.name),
      charges: reportChargesDraft
        .map((entry) => ({
          charge: entry.charge.trim(),
          severity: entry.severity,
          count: Number(entry.count) || 1,
          fine: Number(entry.fine) || 0,
          notes: entry.notes.trim() || null,
        }))
        .filter((entry) => entry.charge),
    });
    await dataStore.getReport(report.id);
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

    function closePriorityOnOutside(e) {
      if (!priorityMenuOpen) return;
      const el = priorityPopoverEl;
      if (el && !el.contains(/** @type {Node} */ (e.target))) priorityMenuOpen = false;
    }
    function onKeyPriority(e) {
      if (e.key === 'Escape') priorityMenuOpen = false;
    }
    document.addEventListener('pointerdown', closePriorityOnOutside, true);
    document.addEventListener('keydown', onKeyPriority);
    return () => {
      document.removeEventListener('pointerdown', closePriorityOnOutside, true);
      document.removeEventListener('keydown', onKeyPriority);
    };
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
        {#each [['all', 'All'], ['mine', 'My Reports'], ['submitted', 'Submitted'], ['draft', 'Drafts']] as [key, label] (key)}
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
          <button class="page-btn" disabled={currentPage <= 1} onclick={prevPage} aria-label="Previous reports page">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6" /></svg>
          </button>
          <span class="page-indicator font-mono">{currentPage} / {totalPages}</span>
          <button class="page-btn" disabled={currentPage >= totalPages} onclick={nextPage} aria-label="Next reports page">
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

      <div class="detail-stack create-form-stack">
        <div class="detail-section">
          <div class="form-group">
            <label class="form-label" for="report-create-title">Title</label>
            <input
              type="text"
              id="report-create-title"
              class="form-input"
              placeholder="Enter report title..."
              bind:value={createTitle}
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="report-create-template">Template</label>
            <select id="report-create-template" class="form-select" bind:value={createTemplate}>
              {#each REPORT_TEMPLATES as tmpl (tmpl)}
                <option value={tmpl}>{tmpl}</option>
              {/each}
            </select>
          </div>

          <div class="form-group">
            <label class="form-label" for="report-create-tags">Tags</label>
            <div class="tags-wrapper">
              {#each createTags as tag (tag)}
                <span class="tag-pill">
                  <span>{tag}</span>
                  <button class="tag-remove" onclick={() => removeCreateTag(tag)} aria-label={`Remove tag ${tag}`}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12" /></svg>
                  </button>
                </span>
              {/each}
              <input
                type="text"
                id="report-create-tags"
                class="tag-input"
                placeholder={createTags.length === 0 ? 'Type and press Enter...' : ''}
                bind:value={createTagInput}
                onkeydown={handleCreateTagKey}
              />
            </div>
          </div>
        </div>

        <div class="detail-section">
          <div class="form-group">
            <label class="form-label" for="report-create-narrative">Narrative</label>
            <textarea
              id="report-create-narrative"
              class="form-textarea create-narrative-textarea"
              placeholder="Describe the incident in detail..."
              bind:value={createNarrative}
              rows="9"
            ></textarea>
          </div>
        </div>

        <div class="detail-section">
          <div class="section-header">
            <h3 class="section-label">Participants</h3>
            <span class="section-count font-mono">{reportParticipantsDraft.length}</span>
          </div>
          <div class="report-grid">
            {#each reportParticipantsDraft as participant, index (index)}
              <div class="report-row-block">
                <div class="report-row-grid">
                  <select class="form-select" bind:value={participant.participantType}>
                    {#each ['suspect', 'victim', 'officer', 'witness', 'other'] as participantType (participantType)}
                      <option value={participantType}>{participantType}</option>
                    {/each}
                  </select>
                  <input type="text" class="form-input" bind:value={participant.name} placeholder="Name" />
                  <input type="text" class="form-input" bind:value={participant.citizenId} placeholder="Citizen ID (optional)" />
                  {#if participant.participantType === 'officer'}
                    <input type="text" class="form-input" bind:value={participant.officerId} placeholder="Officer ID (optional)" />
                  {/if}
                  <button class="btn-remove-inline" onclick={() => removeParticipantRow(index)}>Remove</button>
                </div>
                <textarea class="form-textarea compact-textarea" bind:value={participant.notes} rows="2" placeholder="Participant notes"></textarea>
              </div>
            {/each}
          </div>
          <button class="btn-add-secondary" onclick={openParticipantsModal}>Add Participant</button>
        </div>

        <div class="detail-section">
          <div class="section-header">
            <h3 class="section-label">Charges</h3>
            <span class="section-count font-mono">{reportChargesDraft.length}</span>
          </div>
          <div class="report-grid">
            {#each reportChargesDraft as charge, index (index)}
              <div class="report-row-block">
                <div class="report-row-grid charges">
                  <input type="text" class="form-input" bind:value={charge.charge} placeholder="Charge" />
                  <select class="form-select" bind:value={charge.severity}>
                    {#each ['infraction', 'misdemeanor', 'felony'] as severity (severity)}
                      <option value={severity}>{severity}</option>
                    {/each}
                  </select>
                  <input type="number" min="1" class="form-input" bind:value={charge.count} placeholder="Count" />
                  <input type="number" min="0" class="form-input" bind:value={charge.fine} placeholder="Fine" />
                  <button class="btn-remove-inline" onclick={() => removeChargeRow(index)}>Remove</button>
                </div>
                <textarea class="form-textarea compact-textarea" bind:value={charge.notes} rows="2" placeholder="Charge notes"></textarea>
              </div>
            {/each}
          </div>
          <button class="btn-add-secondary" onclick={openChargesModal}>Add Charge</button>
        </div>

        <div class="detail-section detail-section-actions">
          <div class="form-actions">
            <button class="btn-cancel" onclick={() => { mode = 'list'; }}>Cancel</button>
            <button class="btn-primary" onclick={handleCreate} disabled={!createTitle.trim() || saving}>
              {saving ? 'Creating...' : 'Create Report'}
            </button>
          </div>
        </div>
      </div>
    </div>

  {:else if mode === 'detail' && report}
    <div class="detail-mode">
      <div class="detail-top-bar">
        <button class="back-btn" onclick={goBackToList}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          <span>Back to Reports</span>
        </button>
        <button class="btn-save-full" onclick={handleSave} disabled={saving}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z" /><polyline points="17 21 17 13 7 13 7 21" /><polyline points="7 3 7 8 15 8" /></svg>
          <span>{saving ? 'Saving...' : 'Save Report'}</span>
        </button>
      </div>

      <div class="detail-header">
        <div class="detail-report-line">
          <span class="detail-meta-label">Report number</span>
          <p class="detail-report-id font-mono">{report.report_number || `RPT-${report.id}`}</p>
        </div>

        <div class="detail-meta-grid">
          <div class="detail-meta-item">
            <span class="detail-meta-label">Status</span>
            <p class="detail-status-readout" style="--status-c: {getStatusColor(report.status)}">
              {report.status || 'draft'}
            </p>
          </div>
          <div class="detail-meta-item">
            <span class="detail-meta-label">Priority</span>
            <div class="priority-popover" bind:this={priorityPopoverEl}>
              <button
                type="button"
                class="detail-priority-trigger"
                aria-haspopup="listbox"
                aria-expanded={priorityMenuOpen}
                aria-label="Change report priority"
                onclick={(e) => {
                  e.stopPropagation();
                  togglePriorityMenu();
                }}
              >
                <span class="detail-priority-swatch" style="background: {getPriorityColor(editPriority)}"></span>
                <span class="detail-priority-text">{editPriority}</span>
                <svg class="priority-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                  <path d="M6 9l6 6 6-6" />
                </svg>
              </button>
              {#if priorityMenuOpen}
                <div class="priority-menu" role="listbox" aria-label="Priority">
                  {#each PRIORITIES as pri (pri)}
                    <button
                      type="button"
                      role="option"
                      class="priority-menu-item"
                      class:active={editPriority === pri}
                      aria-selected={editPriority === pri}
                      style="--po-color: {getPriorityColor(pri)}"
                      onclick={() => selectPriority(pri)}
                    >
                      <span class="priority-menu-dot" style="background: {getPriorityColor(pri)}"></span>
                      {pri}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          </div>
          <div class="detail-meta-item">
            <span class="detail-meta-label">Author</span>
            <p class="detail-meta-value">
              {report.author_name || (report.author_first ? `${report.author_first} ${report.author_last}` : '\u2014')}
            </p>
          </div>
          <div class="detail-meta-item">
            <span class="detail-meta-label">Created</span>
            <p class="detail-meta-value detail-meta-mono font-mono">{formatDate(report.created_at)}</p>
          </div>
        </div>

        {#if availableStatusActions.length > 0}
          <div class="detail-header-actions">
            <div class="detail-header-actions-label">
              <span class="detail-meta-label">Update status</span>
              <p class="detail-header-actions-hint">Applies a workflow change to this report.</p>
            </div>
            <div class="detail-header-actions-controls">
              <div class="header-status-row">
                <select
                  id="report-status-action"
                  class="form-select status-dropdown"
                  value=""
                  onchange={(e) => {
                    const v = e.currentTarget.value;
                    if (v) {
                      confirmAction = v;
                      e.currentTarget.value = '';
                    }
                  }}
                >
                  <option value="" disabled selected>Choose new status…</option>
                  {#each availableStatusActions as action (action.status)}
                    <option value={action.status}>{action.label}</option>
                  {/each}
                </select>
                {#if confirmAction}
                  <div class="confirm-row confirm-row-inline">
                    <span class="confirm-text">Confirm?</span>
                    <button type="button" class="confirm-yes" onclick={() => handleStatusChange(confirmAction)}>Yes</button>
                    <button type="button" class="confirm-no" onclick={() => { confirmAction = null; }}>No</button>
                  </div>
                {/if}
              </div>
            </div>
          </div>
        {/if}
      </div>

      <div class="detail-grid">
        <div class="detail-main">
          <div class="detail-stack">
            <div class="detail-section">
              <label class="form-label" for="report-edit-title">Title</label>
              <input
                type="text"
                id="report-edit-title"
                class="form-input"
                bind:value={editTitle}
              />
              {#if report.template}
                <div class="template-label template-label-inline">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
                  <span>{report.template}</span>
                </div>
              {/if}
              <label class="form-label" for="report-edit-tags">Tags</label>
              <div class="tags-wrapper">
                {#each editTags as tag (tag)}
                  <span class="tag-pill">
                    <span>{tag}</span>
                    <button class="tag-remove" onclick={() => removeEditTag(tag)} aria-label={`Remove tag ${tag}`}>
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12" /></svg>
                    </button>
                  </span>
                {/each}
                <input
                  type="text"
                  id="report-edit-tags"
                  class="tag-input"
                  placeholder={editTags.length === 0 ? 'Add tags...' : ''}
                  bind:value={editTagInput}
                  onkeydown={handleEditTagKey}
                />
              </div>
            </div>

            <div class="detail-section">
              <label class="form-label" for="report-edit-narrative">Narrative</label>
              <textarea
                id="report-edit-narrative"
                class="form-textarea narrative-textarea"
                bind:value={editNarrative}
                rows="10"
              ></textarea>
            </div>

            <div class="detail-section">
              <div class="section-header">
                <h3 class="section-label">Participants</h3>
                <span class="section-count font-mono">{reportParticipantsDraft.length}</span>
              </div>
              <div class="report-grid">
                {#each reportParticipantsDraft as participant, index (index)}
                  <div class="report-row-block">
                    <div class="report-row-grid">
                      <select class="form-select" bind:value={participant.participantType}>
                        {#each ['suspect', 'victim', 'officer', 'witness', 'other'] as participantType (participantType)}
                          <option value={participantType}>{participantType}</option>
                        {/each}
                      </select>
                      <input type="text" class="form-input" bind:value={participant.name} placeholder="Name" />
                      <input type="text" class="form-input" bind:value={participant.citizenId} placeholder="Citizen ID (optional)" />
                      {#if participant.participantType === 'officer'}
                        <input type="text" class="form-input" bind:value={participant.officerId} placeholder="Officer ID (optional)" />
                      {/if}
                      <button class="btn-remove-inline" onclick={() => removeParticipantRow(index)}>Remove</button>
                    </div>
                    <textarea class="form-textarea compact-textarea" bind:value={participant.notes} rows="2" placeholder="Participant notes"></textarea>
                  </div>
                {/each}
              </div>
              <button class="btn-add-secondary" onclick={openParticipantsModal}>Add Participant</button>
            </div>

            <div class="detail-section">
              <div class="section-header">
                <h3 class="section-label">Charges</h3>
                <span class="section-count font-mono">{reportChargesDraft.length}</span>
              </div>
              <div class="report-grid">
                {#each reportChargesDraft as charge, index (index)}
                  <div class="report-row-block">
                    <div class="report-row-grid charges">
                      <input type="text" class="form-input" bind:value={charge.charge} placeholder="Charge" />
                      <select class="form-select" bind:value={charge.severity}>
                        {#each ['infraction', 'misdemeanor', 'felony'] as severity (severity)}
                          <option value={severity}>{severity}</option>
                        {/each}
                      </select>
                      <input type="number" min="1" class="form-input" bind:value={charge.count} placeholder="Count" />
                      <input type="number" min="0" class="form-input" bind:value={charge.fine} placeholder="Fine" />
                      <button class="btn-remove-inline" onclick={() => removeChargeRow(index)}>Remove</button>
                    </div>
                    <textarea class="form-textarea compact-textarea" bind:value={charge.notes} rows="2" placeholder="Charge notes"></textarea>
                  </div>
                {/each}
              </div>
              <button class="btn-add-secondary" onclick={openChargesModal}>Add Charge</button>
            </div>

            <div class="detail-section timeline-section">
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
        </div>

        <aside class="detail-sidebar">
          <div class="detail-stack">
            <div class="detail-section">
              <h3 class="section-label">Restrictions</h3>
              <MdtCheckbox class="toggle-row" bind:checked={editRestricted}>
                {#snippet children()}
                  Restrict report visibility
                {/snippet}
              </MdtCheckbox>
              <input
                type="text"
                class="form-input"
                bind:value={editRestrictedTo}
                placeholder="Departments/ranks, comma separated"
              />
            </div>

            <div class="detail-section">
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
                      <button type="button" class="entity-remove" aria-label="Remove linked entity" onclick={() => handleRemoveEntity(entity.id)}>
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                      </button>
                    </div>
                  {/each}
              </div>
              {:else}
                <p class="empty-inline">No entities linked</p>
              {/if}
            </div>

            <div class="detail-section">
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

            <div class="detail-section">
              <div class="section-header">
                <h3 class="section-label">Attachments</h3>
                <span class="section-count font-mono">{attachments.length}</span>
              </div>

              <div class="attachments-shell">
                {#if attachments.length > 0}
                  <ul class="attachments-list" role="list">
                    {#each attachments as attachment, index (attachment.id || index)}
                      <li class="attachments-row">
                        <span class="attachments-kind font-mono" title={attachment.file_type || 'file'}>{attachmentKindAbbrev(attachment.file_name, attachment.file_type)}</span>
                        <div class="attachments-body min-w-0">
                          <a class="attachments-title" href={attachment.file_url} target="_blank" rel="noreferrer">{attachment.file_name}</a>
                          {#if attachment.notes}
                            <p class="attachments-notes">{attachment.notes}</p>
                          {/if}
                          <span class="attachments-meta font-mono">
                            {attachment.file_type || 'Unknown type'}{attachment.uploader_callsign ? ` · ${attachment.uploader_callsign}` : ''}
                          </span>
                        </div>
                        <div class="attachments-actions">
                          <a class="attachments-open" href={attachment.file_url} target="_blank" rel="noreferrer" aria-label="Open in new tab">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6M15 3h6v6M10 14L21 3" /></svg>
                          </a>
                          <button type="button" class="entity-remove attachments-remove" aria-label="Remove attachment" onclick={() => handleRemoveAttachment(attachment.id)}>
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                          </button>
                        </div>
                      </li>
                    {/each}
                  </ul>
                {:else}
                  <div class="attachments-empty">
                    <p class="attachments-empty-title">No files linked</p>
                    <p class="attachments-empty-hint">Link exports, BWC uploads, or MDC pulls so reviewers open sources in one click.</p>
                  </div>
                {/if}

                <div class="attachments-add">
                  <p class="attachments-add-hed">Add file</p>
                  <div class="attachments-form-grid">
                    <div class="attachments-field">
                      <label class="form-label" for="report-att-name">Display name</label>
                      <input id="report-att-name" type="text" class="form-input" bind:value={reportAttachmentName} placeholder="Narrative supplement, photo line-up" />
                    </div>
                    <div class="attachments-field">
                      <label class="form-label" for="report-att-url">File URL</label>
                      <input id="report-att-url" type="text" class="form-input" bind:value={reportAttachmentUrl} placeholder="https://..." />
                    </div>
                    <div class="attachments-field">
                      <label class="form-label" for="report-att-type">Type / MIME</label>
                      <input id="report-att-type" type="text" class="form-input" bind:value={reportAttachmentType} placeholder="image/jpeg, application/pdf" />
                    </div>
                  </div>
                  <div class="attachments-field attachments-field-notes">
                    <label class="form-label" for="report-att-notes">Notes</label>
                    <textarea id="report-att-notes" class="form-textarea compact-textarea" bind:value={reportAttachmentNotes} rows="2" placeholder="Source system, retention class, redactions"></textarea>
                  </div>
                  <button type="button" class="btn-add-secondary attachments-submit" onclick={handleAddAttachment} disabled={!reportAttachmentName.trim() || !reportAttachmentUrl.trim() || saving}>Add attachment</button>
                </div>
              </div>
            </div>

            {#if reportChargesDraft.length > 0}
              <div class="detail-section detail-section-cta">
                <button
                  class="btn-issue-citation"
                  onclick={() => { showCitationModal = true; }}
                  disabled={citationIssuing || !reportParticipantsDraft.some(p => p.participantType === 'suspect' && (p.citizenId || '').trim())}
                >
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>
                  <span>{citationIssuing ? 'Issuing...' : 'Issue Citation'}</span>
                </button>
              </div>
            {/if}
          </div>
        </aside>
      </div>
    </div>
  {/if}

  <!-- ─── Charges Picker Modal ─── -->
  {#if showChargesModal}
    <div
      class="modal-overlay"
      role="presentation"
      onclick={(event) => { if (event.target === event.currentTarget) showChargesModal = false; }}
      onkeydown={(event) => { if (event.key === 'Escape') showChargesModal = false; }}
    >
      <div class="modal-panel modal-lg" role="dialog" aria-modal="true" aria-labelledby="charges-modal-title">
        <div class="modal-header">
          <h3 id="charges-modal-title" class="modal-title">Select Charge</h3>
          <button class="modal-close" onclick={() => showChargesModal = false} aria-label="Close charge picker">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
          </button>
        </div>

        <div class="modal-search-row">
          <div class="modal-search-box">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input type="text" class="modal-search-input" placeholder="Search charges..." bind:value={chargeSearch} />
          </div>
          <div class="modal-filter-pills">
            {#each CHARGE_CATEGORIES as cat (cat.id)}
              <button class="modal-filter-pill" class:active={chargeFilterCat === cat.id} onclick={() => chargeFilterCat = cat.id}>{cat.label}</button>
            {/each}
          </div>
        </div>

        <div class="modal-body">
          <div class="charge-table-header">
            <span class="ct-charge">Charge</span>
            <span class="ct-sev">Severity</span>
            <span class="ct-jail">Jail (mo)</span>
            <span class="ct-fine">Fine ($)</span>
            <span class="ct-act"></span>
          </div>
          <div class="charge-table-body">
            {#each filteredCharges as charge (charge.id)}
              <button class="charge-table-row" onclick={() => selectCharge(charge)}>
                <span class="ct-charge">
                  <span class="ct-charge-name">{charge.charge}</span>
                  <span class="ct-charge-cat font-mono">{charge.category?.replace(/_/g, ' ')}</span>
                </span>
                <span class="ct-sev">
                  <span class="severity-pill" style="color: {SEVERITY_COLORS[charge.severity]}; background: color-mix(in srgb, {SEVERITY_COLORS[charge.severity]} 12%, transparent); border-color: color-mix(in srgb, {SEVERITY_COLORS[charge.severity]} 25%, transparent);">
                    {charge.severity}
                  </span>
                </span>
                <span class="ct-jail font-mono">{charge.jailTime || 0}{charge.maxJail ? `–${charge.maxJail}` : ''}</span>
                <span class="ct-fine font-mono">${(charge.fine || 0).toLocaleString()}</span>
                <span class="ct-act">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                </span>
              </button>
            {/each}
            {#if filteredCharges.length === 0}
              <div class="modal-empty">No charges match your search</div>
            {/if}
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- ─── Participants Search Modal ─── -->
  {#if showParticipantsModal}
    <div
      class="modal-overlay"
      role="presentation"
      onclick={(event) => { if (event.target === event.currentTarget) showParticipantsModal = false; }}
      onkeydown={(event) => { if (event.key === 'Escape') showParticipantsModal = false; }}
    >
      <div class="modal-panel" role="dialog" aria-modal="true" aria-labelledby="participants-modal-title">
        <div class="modal-header">
          <h3 id="participants-modal-title" class="modal-title">Add Participant</h3>
          <button class="modal-close" onclick={() => showParticipantsModal = false} aria-label="Close participant picker">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
          </button>
        </div>

        <div class="modal-search-row">
          <div class="participant-type-selector">
            {#each ['suspect', 'victim', 'officer', 'witness', 'other'] as ptype (ptype)}
              <button class="modal-filter-pill" class:active={participantType === ptype} onclick={() => participantType = ptype}>{ptype}</button>
            {/each}
          </div>
          <div class="modal-search-box">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input
              type="text"
              class="modal-search-input"
              placeholder="Search citizens by name or ID..."
              bind:value={participantSearch}
              onkeydown={(e) => { if (e.key === 'Enter') searchCitizensForParticipant(); }}
            />
            <button class="modal-search-btn" onclick={searchCitizensForParticipant} disabled={participantSearching || !participantSearch.trim()}>
              {participantSearching ? 'Searching...' : 'Search'}
            </button>
          </div>
        </div>

        <div class="modal-body">
          {#if participantSearchResults.length > 0}
            <div class="citizen-results">
              {#each participantSearchResults as citizen (citizen.id)}
                <button class="citizen-result-row" onclick={() => selectParticipant(citizen)}>
                  <div class="citizen-avatar">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="8" r="4"/><path d="M20 21a8 8 0 00-16 0"/></svg>
                  </div>
                  <div class="citizen-info">
                    <span class="citizen-name">{citizen.firstName} {citizen.lastName}</span>
                    <span class="citizen-meta font-mono">{citizen.id} · DOB: {citizen.dob || '—'}</span>
                  </div>
                  <span class="citizen-add-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                  </span>
                </button>
              {/each}
            </div>
          {:else if participantSearch.trim() && !participantSearching}
            <div class="modal-empty">
              <p>No citizens found. You can also add manually:</p>
              <button class="btn-add-manual" onclick={() => { addParticipantRow(); showParticipantsModal = false; }}>
                Add Manual Entry
              </button>
            </div>
          {:else}
            <div class="modal-empty">Search for a citizen to add as a participant</div>
          {/if}
        </div>
      </div>
    </div>
  {/if}

  <!-- ─── Citation Issue Modal ─── -->
  {#if showCitationModal && report}
    <CitationIssueModal
      report={report}
      participants={reportParticipantsDraft}
      charges={reportChargesDraft}
      officer={officer}
      onIssue={handleIssueCitation}
      onClose={() => { showCitationModal = false; }}
    />
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
    gap: calc(10px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
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

  .detail-top-bar .btn-save-full {
    width: auto;
    flex-shrink: 0;
    padding-left: calc(16px * var(--mdt-scale));
    padding-right: calc(16px * var(--mdt-scale));
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
    transform: scale(0.96);
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
    transform: scale(0.96);
  }

  .section-title {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
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

  .detail-stack > .detail-section:last-child,
  .detail-stack > .detail-section.detail-section-actions:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .detail-section-actions {
    padding-top: calc(8px * var(--mdt-scale));
    gap: 0;
  }

  .detail-section-actions .form-actions {
    padding-top: 0;
  }

  .detail-section-cta {
    padding-top: calc(8px * var(--mdt-scale));
    border-bottom: none;
  }

  .create-form-stack .detail-section:first-child {
    padding-top: 0;
  }

  .detail-main .detail-stack > .detail-section:first-child,
  .detail-sidebar .detail-stack > .detail-section:first-child {
    padding-top: 0;
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
    background: var(--mdt-surface-2);
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

  .create-narrative-textarea {
    min-height: calc(200px * var(--mdt-scale));
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .narrative-textarea {
    min-height: calc(180px * var(--mdt-scale));
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
    transform: scale(0.96);
  }

  .btn-primary:disabled {
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

  .detail-status-readout {
    margin: 0;
    display: block;
    width: fit-content;
    max-width: 100%;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    line-height: 1.4;
    text-transform: capitalize;
    color: var(--status-c);
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-left: 3px solid var(--status-c);
    background: color-mix(in srgb, var(--status-c) 9%, var(--mdt-surface-2));
    border-radius: 0 var(--mdt-radius-sm) var(--mdt-radius-sm) 0;
  }

  .detail-meta-value {
    margin: 0;
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 500;
    line-height: 1.4;
  }

  .detail-meta-mono {
    color: var(--mdt-text-dim);
    font-size: calc(12px * var(--mdt-scale));
    letter-spacing: 0.04em;
  }

  .priority-popover {
    position: relative;
    display: block;
    width: 100%;
  }

  .detail-priority-trigger {
    display: flex;
    align-items: center;
    width: 100%;
    min-height: calc(38px * var(--mdt-scale));
    box-sizing: border-box;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-family: inherit;
    text-align: left;
    cursor: pointer;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    box-shadow: inset 0 1px 0 color-mix(in srgb, #fff 5%, transparent);
    transition:
      border-color 0.18s cubic-bezier(0.16, 1, 0.3, 1),
      background 0.18s ease,
      transform 0.1s ease;
  }

  .detail-priority-trigger:hover {
    background: var(--mdt-surface-3);
    border-color: color-mix(in srgb, var(--mdt-text-muted) 50%, var(--mdt-border));
  }

  .detail-priority-trigger:active {
    transform: scale(0.995);
  }

  .detail-priority-swatch {
    width: calc(8px * var(--mdt-scale));
    height: calc(8px * var(--mdt-scale));
    border-radius: 2px;
    flex-shrink: 0;
    box-shadow: 0 0 0 1px color-mix(in srgb, #000 25%, transparent);
  }

  .detail-priority-text {
    flex: 1;
    min-width: 0;
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 500;
    text-transform: capitalize;
  }

  .priority-chevron {
    width: calc(12px * var(--mdt-scale));
    height: calc(12px * var(--mdt-scale));
    margin-left: auto;
    opacity: 0.6;
    flex-shrink: 0;
    transition: transform 0.22s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .priority-popover:has(.priority-menu) .priority-chevron {
    transform: rotate(180deg);
  }

  .priority-menu {
    position: absolute;
    left: 0;
    right: 0;
    top: calc(100% + calc(6px * var(--mdt-scale)));
    z-index: 30;
    min-width: 0;
    padding: calc(4px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    box-shadow:
      0 calc(10px * var(--mdt-scale)) calc(28px * var(--mdt-scale)) color-mix(in srgb, #000 22%, transparent),
      inset 0 1px 0 color-mix(in srgb, #fff 5%, transparent);
    animation: fadeIn 0.16s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .priority-menu-item {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: none;
    border-radius: calc(6px * var(--mdt-scale));
    background: transparent;
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    text-transform: capitalize;
    text-align: left;
    cursor: pointer;
    transition:
      background 0.15s ease,
      color 0.15s ease;
  }

  .priority-menu-item:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .priority-menu-item.active {
    background: color-mix(in srgb, var(--po-color) 12%, transparent);
    color: var(--po-color);
  }

  .priority-menu-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .detail-header-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    padding-top: calc(10px * var(--mdt-scale));
    margin-top: calc(2px * var(--mdt-scale));
    border-top: 1px solid color-mix(in srgb, var(--mdt-border) 55%, transparent);
  }

  .detail-header-actions-label {
    flex: 1 1 180px;
    min-width: 0;
  }

  .detail-header-actions-hint {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.45;
    color: var(--mdt-text-muted);
  }

  .detail-header-actions-controls {
    flex: 1 1 280px;
    min-width: 0;
    max-width: min(100%, calc(400px * var(--mdt-scale)));
  }

  .detail-header-actions .header-status-row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-start;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
  }

  .status-dropdown {
    width: auto;
    min-width: calc(180px * var(--mdt-scale));
    max-width: 100%;
    flex: 1 1 auto;
  }

  .confirm-row-inline {
    flex-wrap: nowrap;
    padding: 0;
    margin: 0;
  }

  .template-label {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding: calc(4px * var(--mdt-scale)) 0;
    background: transparent;
    border: none;
    border-radius: 0;
    align-self: flex-start;
  }

  .template-label-inline {
    margin-top: calc(2px * var(--mdt-scale));
    margin-bottom: calc(2px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) 0 calc(6px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 45%, transparent);
    width: 100%;
  }

  .template-label svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    opacity: 0.5;
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

  .timeline-section {
    gap: calc(8px * var(--mdt-scale));
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
    transform: scale(0.96);
  }

  .btn-add:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .entity-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .entity-item {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) 0;
    background: transparent;
    border-radius: 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
    transition: background 0.12s ease;
  }

  .entity-item:last-child {
    border-bottom: none;
  }

  .entity-item:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 40%, transparent);
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

  .report-grid {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .report-row-block {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 55%, transparent);
  }

  .report-row-block:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .report-row-grid {
    display: grid;
    grid-template-columns: 0.9fr 1.1fr 1fr auto;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
  }

  .report-row-grid.charges {
    grid-template-columns: 1.2fr 0.9fr 0.55fr 0.75fr auto;
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

  .attachments-remove.entity-remove {
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

  .btn-add-secondary,
  .btn-remove-inline {
    border-radius: var(--mdt-radius-sm);
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    font-family: 'Outfit', sans-serif;
  }

  .btn-add-secondary {
    align-self: flex-start;
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 28%, transparent);
    background: color-mix(in srgb, var(--mdt-accent) 14%, transparent);
    color: var(--mdt-accent);
  }

  .btn-remove-inline {
    border: 1px solid color-mix(in srgb, var(--mdt-error) 28%, transparent);
    background: color-mix(in srgb, var(--mdt-error) 14%, transparent);
    color: var(--mdt-error);
  }

  :global(.toggle-row) {
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  :global(.toggle-row .mdt-checkbox-label) {
    font-weight: 500;
    color: var(--mdt-text-dim);
  }

  .collab-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .collab-item {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) 0;
    background: transparent;
    border-radius: 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
  }

  .collab-item:last-child {
    border-bottom: none;
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
    transform: scale(0.96);
  }

  .btn-save-full:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .btn-issue-citation {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-accent) 10%, transparent);
    color: var(--mdt-accent);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition:
      background 0.18s cubic-bezier(0.16, 1, 0.3, 1),
      border-color 0.18s ease,
      transform 0.1s ease;
    width: 100%;
  }

  .btn-issue-citation svg {
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
  }

  .btn-issue-citation:hover {
    background: color-mix(in srgb, var(--mdt-accent) 16%, transparent);
    border-color: color-mix(in srgb, var(--mdt-accent) 55%, var(--mdt-border));
  }

  .btn-issue-citation:active {
    transform: scale(0.97);
  }

  .btn-issue-citation:disabled {
    opacity: 0.35;
    cursor: not-allowed;
    box-shadow: none;
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

  /* ─── Modal Overlay ─── */
  .modal-overlay {
    position: fixed;
    inset: 0;
    z-index: 1000;
    background: rgba(0, 0, 0, 0.65);
    display: flex;
    align-items: center;
    justify-content: center;
    animation: modalFadeIn 0.2s ease forwards;
    backdrop-filter: blur(4px);
  }

  .modal-panel {
    width: calc(560px * var(--mdt-scale));
    max-height: 80vh;
    background: var(--mdt-bg);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: modalSlideIn 0.25s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    box-shadow: 0 24px 48px rgba(0, 0, 0, 0.35);
  }

  .modal-panel.modal-lg {
    width: calc(720px * var(--mdt-scale));
    max-height: 85vh;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(16px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
  }

  .modal-title {
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
  }

  .modal-close {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
    padding: 0;
  }
  .modal-close::after {
    content: '';
    position: absolute;
    inset: calc(-6px * var(--mdt-scale));
  }

  .modal-close svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .modal-close:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .modal-search-row {
    padding: calc(12px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .modal-search-box {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
  }

  .modal-search-box svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .modal-search-input {
    flex: 1;
    background: none;
    border: none;
    outline: none;
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
  }

  .modal-search-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .modal-search-btn {
    padding: calc(4px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: 1px solid var(--mdt-accent);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
  }

  .modal-search-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .modal-filter-pills {
    display: flex;
    flex-wrap: wrap;
    gap: calc(4px * var(--mdt-scale));
  }

  .modal-filter-pill {
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: calc(999px * var(--mdt-scale));
    background: transparent;
    color: var(--mdt-text-muted);
    font-family: inherit;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    text-transform: capitalize;
    transition: color 0.12s ease, border-color 0.12s ease;
  }

  .modal-filter-pill:hover {
    color: var(--mdt-text);
    border-color: var(--mdt-border-2);
  }

  .modal-filter-pill.active {
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    border-color: color-mix(in srgb, var(--mdt-accent) 25%, transparent);
  }

  .participant-type-selector {
    display: flex;
    gap: calc(4px * var(--mdt-scale));
  }

  .modal-body {
    flex: 1;
    overflow-y: auto;
    min-height: calc(200px * var(--mdt-scale));
  }

  .modal-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(40px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-size: calc(12px * var(--mdt-scale));
    text-align: center;
  }

  /* ─── Charge Table ─── */
  .charge-table-header {
    display: grid;
    grid-template-columns: 2fr 1fr 0.8fr 0.8fr 0.4fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-bottom: 1px solid var(--mdt-border);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    position: sticky;
    top: 0;
    z-index: 1;
  }

  .charge-table-body {
    display: flex;
    flex-direction: column;
  }

  .charge-table-row {
    display: grid;
    grid-template-columns: 2fr 1fr 0.8fr 0.8fr 0.4fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border: none;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
    background: transparent;
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    cursor: pointer;
    text-align: left;
    width: 100%;
    align-items: center;
    transition: background 0.12s ease;
  }

  .charge-table-row:hover {
    background: var(--mdt-surface);
  }

  .charge-table-row:last-child {
    border-bottom: none;
  }

  .ct-charge {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .ct-charge-name {
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ct-charge-cat {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-transform: capitalize;
    letter-spacing: 0.04em;
  }

  .ct-jail, .ct-fine {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .ct-act {
    display: flex;
    justify-content: center;
  }

  .ct-act svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0;
    transition: opacity 0.12s ease;
  }

  .charge-table-row:hover .ct-act svg {
    opacity: 1;
  }

  .severity-pill {
    display: inline-flex;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    border: 1px solid;
    white-space: nowrap;
  }

  /* ─── Citizen Results ─── */
  .citizen-results {
    display: flex;
    flex-direction: column;
  }

  .citizen-result-row {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border: none;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
    background: transparent;
    color: var(--mdt-text);
    font-family: inherit;
    cursor: pointer;
    text-align: left;
    width: 100%;
    transition: background 0.12s ease;
  }

  .citizen-result-row:hover {
    background: var(--mdt-surface);
  }

  .citizen-result-row:last-child {
    border-bottom: none;
  }

  .citizen-avatar {
    width: calc(36px * var(--mdt-scale));
    height: calc(36px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .citizen-avatar svg {
    width: calc(18px * var(--mdt-scale));
    height: calc(18px * var(--mdt-scale));
  }

  .citizen-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .citizen-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .citizen-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .citizen-add-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0;
    transition: opacity 0.12s ease;
  }

  .citizen-add-icon svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .citizen-result-row:hover .citizen-add-icon {
    opacity: 1;
  }

  .btn-add-manual {
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
  }

  .btn-add-manual:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  @keyframes modalFadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes modalSlideIn {
    from { opacity: 0; transform: translateY(calc(12px * var(--mdt-scale))) scale(0.97); }
    to { opacity: 1; transform: translateY(0) scale(1); }
  }
</style>
