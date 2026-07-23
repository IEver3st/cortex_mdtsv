<script>
  import { dataStore } from '../stores/data.svelte.js';
  import { mdtStore } from '../stores/mdt.svelte.js';
  import { onMount } from 'svelte';

  let citations = $state([]);
  let loading = $state(true);
  let selectedCitation = $state(null);
  let error = $state('');

  let showList = $derived(!selectedCitation && citations.length > 0);
  let showDetail = $derived(!!selectedCitation);
  let showEmpty = $derived(!loading && citations.length === 0 && !selectedCitation);

  onMount(async () => {
    loading = true;
    const resp = await dataStore.getMyCitations();
    if (resp?.ok) {
      citations = resp.citations || [];

      if (mdtStore.citationData) {
        const targetId = mdtStore.citationData.id || mdtStore.citationData;
        const found = citations.find(c => c.id === targetId);
        if (found) {
          selectedCitation = found;
          if (found.status === 'pending') {
            await dataStore.markCitationViewed(found.id);
          }
        }
        mdtStore.citationData = null;
      }
    } else {
      error = 'Failed to load citations.';
    }
    loading = false;
  });

  function selectCitation(cit) {
    selectedCitation = cit;
    if (cit.status === 'pending') {
      dataStore.markCitationViewed(cit.id);
    }
  }

  function goBackToList() {
    selectedCitation = null;
  }

  function handleClose() {
    mdtStore.showCitation = false;
    mdtStore.citationData = null;
    mdtStore.citationsList = [];
    mdtStore.visible = false;
    if (!window.invokeNative) return;
    fetch('https://cortex_mdtsv/cortex_mdt:closeCitation', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    }).catch(() => {});
  }

  function handleKeydown(e) {
    if (e.key === 'Escape') {
      handleClose();
    }
  }

  function getStatusLabel(status) {
    return status === 'pending' ? 'UNPAID' : status === 'viewed' ? 'VIEWED' : status === 'paid' ? 'PAID' : status.toUpperCase();
  }

  function getStatusColor(status) {
    return status === 'pending' ? '#f87171' : status === 'viewed' ? '#fbbf24' : '#34d399';
  }

  function formatDate(dateStr) {
    if (!dateStr) return '';
    try {
      return new Date(dateStr).toLocaleDateString('en-US', {
        month: 'long', day: 'numeric', year: 'numeric',
      });
    } catch { return dateStr; }
  }

  function formatTime(dateStr) {
    if (!dateStr) return '';
    try {
      return new Date(dateStr).toLocaleTimeString('en-US', {
        hour: '2-digit', minute: '2-digit',
      });
    } catch { return ''; }
  }
</script>

<svelte:window onkeydown={handleKeydown} />

<div class="citation-overlay">
  <button class="citation-close" onclick={handleClose} aria-label="Close citation">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12" /></svg>
  </button>

  {#if loading}
    <div class="citation-loading">
      <div class="loading-spinner"></div>
      <p>Loading citations...</p>
    </div>
  {:else if error}
    <div class="citation-error">
      <p>{error}</p>
    </div>
  {:else if showEmpty}
    <div class="citation-empty">
      <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
        <polyline points="14 2 14 8 20 8" />
      </svg>
      <p class="empty-title">No Citations Found</p>
      <p class="empty-sub">You have no citations on your record. Drive safely.</p>
    </div>

  {:else if showList}
    <div class="citation-list-view">
      <div class="citation-list-header">
        <h2 class="list-title">Your Citations</h2>
        <span class="list-count">{citations.length} citation{citations.length !== 1 ? 's' : ''}</span>
      </div>
      <div class="citation-list">
        {#each citations as cit (cit.id)}
          <button class="citation-list-item" onclick={() => selectCitation(cit)}>
            <div class="cli-left">
              <span class="cli-number font-mono">{cit.citation_number}</span>
              <span class="cli-title">{cit.report_title || 'Citation'}</span>
              <span class="cli-officer">Issued by {cit.issued_by?.rank} {cit.issued_by?.name}</span>
            </div>
            <div class="cli-right">
              <span class="cli-status" style="color: {getStatusColor(cit.status)}">{getStatusLabel(cit.status)}</span>
              <span class="cli-fine font-mono">${Number(cit.total_fine || 0).toLocaleString()}</span>
              <span class="cli-date">{formatDate(cit.issued_at)}</span>
            </div>
            <div class="cli-chevron">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6" /></svg>
            </div>
          </button>
        {/each}
      </div>
    </div>

  {:else if showDetail && selectedCitation}
    {@const cit = selectedCitation}
    {@const by = cit.issued_by || {}}
    <div class="citation-detail-view">
      <button class="citation-back-btn" onclick={goBackToList}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6" /></svg>
        Back to list
      </button>

      <div class="paper-citation">
        <div class="paper-header">
          <div class="paper-seal">
            <span class="seal-text">{by.department_short || 'LSPD'}</span>
          </div>
          <div class="paper-department">
            <h1 class="paper-dept-name">{by.department || 'Los Santos Police Department'}</h1>
            <p class="paper-dept-sub">San Andreas Penal Code &middot; Official Citation</p>
          </div>
        </div>

        <div class="paper-divider">
          <span class="divider-label">TRAFFIC / PENAL CODE CITATION</span>
        </div>

        <div class="paper-meta-grid">
          <div class="paper-meta-item">
            <span class="meta-label">Citation No.</span>
            <span class="meta-value font-mono">{cit.citation_number}</span>
          </div>
          <div class="paper-meta-item">
            <span class="meta-label">Report No.</span>
            <span class="meta-value font-mono">{cit.report_number || '—'}</span>
          </div>
          <div class="paper-meta-item">
            <span class="meta-label">Date Issued</span>
            <span class="meta-value">{formatDate(cit.issued_at)}</span>
          </div>
          <div class="paper-meta-item">
            <span class="meta-label">Time</span>
            <span class="meta-value font-mono">{formatTime(cit.issued_at)}</span>
          </div>
        </div>

        <div class="paper-section">
          <h3 class="paper-section-title">Issuing Officer</h3>
          <div class="paper-field-row">
            <div class="paper-field">
              <span class="field-label">Name</span>
              <span class="field-value">{by.rank} {by.name}</span>
            </div>
            <div class="paper-field">
              <span class="field-label">Badge / Callsign</span>
              <span class="field-value font-mono">{by.callsign || '—'}</span>
            </div>
          </div>
          <div class="paper-field">
            <span class="field-label">Department</span>
            <span class="field-value">{by.department}</span>
          </div>
        </div>

        <div class="paper-section">
          <h3 class="paper-section-title">Issued To</h3>
          <div class="paper-field-row">
            <div class="paper-field">
              <span class="field-label">Name</span>
              <span class="field-value">{cit.issued_to?.name || '—'}</span>
            </div>
            <div class="paper-field">
              <span class="field-label">Citizen ID</span>
              <span class="field-value font-mono">{cit.issued_to?.citizen_id || '—'}</span>
            </div>
          </div>
        </div>

        <div class="paper-section">
          <h3 class="paper-section-title">Violations</h3>
          <div class="paper-charges-table">
            <div class="pct-header">
              <span class="pct-h-1">Violation</span>
              <span class="pct-h-2">Severity</span>
              <span class="pct-h-3">Count</span>
              <span class="pct-h-4">Fine ($)</span>
            </div>
            {#each cit.charges || [] as charge, i (i)}
              <div class="pct-row">
                <span class="pct-1">{charge.charge}</span>
                <span class="pct-2">{charge.severity}</span>
                <span class="pct-3 font-mono">{charge.count || 1}</span>
                <span class="pct-4 font-mono">${Number(charge.fine || 0).toLocaleString()}</span>
              </div>
            {/each}
          </div>
          <div class="paper-total">
            <span class="total-label">TOTAL FINE DUE</span>
            <span class="total-value">${Number(cit.total_fine || 0).toLocaleString()}</span>
          </div>
        </div>

        {#if cit.notes}
          <div class="paper-section">
            <h3 class="paper-section-title">Notes</h3>
            <p class="paper-notes">{cit.notes}</p>
          </div>
        {/if}

        <div class="paper-footer">
          <div class="paper-status-stamp" style="color: {getStatusColor(cit.status)}; border-color: {getStatusColor(cit.status)}">
            {getStatusLabel(cit.status)}
          </div>
          <p class="paper-disclaimer">
            This citation was issued electronically via the Cortex Mobile Data Terminal. It is an official record of the {by.department || 'issuing department'}. Failure to respond to this citation may result in additional penalties, including license suspension or warrant issuance.
          </p>
          <div class="paper-barcode">
            █▌▐█▌▐█▌▐██▌▐█▌▐█▌▐█▌▐█▌▐█▌▐█▌▐█▌▐███████▌
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .citation-overlay {
    position: fixed;
    inset: 0;
    z-index: 10000;
    background: rgba(0, 0, 0, 0.85);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: calc(40px * var(--mdt-scale));
  }

  .citation-close {
    position: fixed;
    top: calc(16px * var(--mdt-scale));
    right: calc(16px * var(--mdt-scale));
    z-index: 10001;
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: calc(var(--es-radius, 8px) * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.6);
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .citation-close:hover {
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
    transform: scale(1.05);
  }

  .citation-close svg {
    width: calc(20px * var(--mdt-scale));
    height: calc(20px * var(--mdt-scale));
  }

  .citation-loading, .citation-error, .citation-empty {
    text-align: center;
    color: var(--mdt-text-muted, #888);
  }

  .loading-spinner {
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    border: 2px solid rgba(255, 255, 255, 0.1);
    border-top-color: #00ffcc;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin: 0 auto calc(12px * var(--mdt-scale));
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .empty-icon {
    width: calc(48px * var(--mdt-scale));
    height: calc(48px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.15);
    margin-bottom: calc(12px * var(--mdt-scale));
  }

  .empty-title {
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 600;
    color: #fff;
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  .empty-sub {
    font-size: calc(13px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.4);
  }

  /* ── List View ── */
  .citation-list-view {
    width: 100%;
    max-width: calc(640px * var(--mdt-scale));
    max-height: calc(80vh * var(--mdt-scale));
    overflow-y: auto;
  }

  .citation-list-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: calc(16px * var(--mdt-scale));
  }

  .list-title {
    font-family: 'Outfit', sans-serif;
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 600;
    color: #fff;
  }

  .list-count {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted, #666);
    background: rgba(255, 255, 255, 0.04);
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(var(--es-radius, 4px) * var(--mdt-scale));
  }

  .citation-list {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .citation-list-item {
    display: flex;
    align-items: center;
    gap: calc(16px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: calc(var(--es-radius, 8px) * var(--mdt-scale));
    color: #fff;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .citation-list-item:hover {
    background: rgba(255, 255, 255, 0.06);
    border-color: rgba(0, 255, 204, 0.2);
  }

  .cli-left {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .cli-number {
    font-size: calc(11px * var(--mdt-scale));
    color: #00ffcc;
  }

  .cli-title {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 500;
  }

  .cli-officer {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted, #666);
  }

  .cli-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: calc(2px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .cli-status {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .cli-fine {
    font-size: calc(16px * var(--mdt-scale));
    font-weight: 600;
    color: #f87171;
  }

  .cli-date {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted, #666);
  }

  .cli-chevron {
    color: rgba(255, 255, 255, 0.2);
    flex-shrink: 0;
  }

  .cli-chevron svg {
    width: calc(18px * var(--mdt-scale));
    height: calc(18px * var(--mdt-scale));
  }

  /* ── Detail / Paper View ── */
  .citation-detail-view {
    width: 100%;
    max-width: calc(680px * var(--mdt-scale));
    max-height: calc(85vh * var(--mdt-scale));
    overflow-y: auto;
  }

  .citation-back-btn {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.5);
    font-size: calc(12px * var(--mdt-scale));
    cursor: pointer;
    padding: 0;
    margin-bottom: calc(16px * var(--mdt-scale));
    transition: color 0.2s;
  }

  .citation-back-btn:hover {
    color: #00ffcc;
  }

  .citation-back-btn svg {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
  }

  .paper-citation {
    background: #1a1c18;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: calc(2px * var(--mdt-scale));
    padding: calc(32px * var(--mdt-scale)) calc(28px * var(--mdt-scale));
    box-shadow: 0 0 40px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.03);
    font-family: 'Outfit', sans-serif;
  }

  .paper-header {
    display: flex;
    align-items: center;
    gap: calc(20px * var(--mdt-scale));
    margin-bottom: calc(20px * var(--mdt-scale));
  }

  .paper-seal {
    width: calc(64px * var(--mdt-scale));
    height: calc(64px * var(--mdt-scale));
    border: 2px solid #888;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .seal-text {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(12px * var(--mdt-scale));
    color: #888;
    font-weight: 700;
    text-align: center;
    line-height: 1.2;
  }

  .paper-department {
    flex: 1;
  }

  .paper-dept-name {
    font-size: calc(16px * var(--mdt-scale));
    font-weight: 600;
    color: #ddd;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin: 0;
  }

  .paper-dept-sub {
    font-size: calc(10px * var(--mdt-scale));
    color: #777;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    margin: calc(2px * var(--mdt-scale)) 0 0;
  }

  .paper-divider {
    text-align: center;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    padding: calc(6px * var(--mdt-scale)) 0;
    margin-bottom: calc(20px * var(--mdt-scale));
  }

  .divider-label {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(9px * var(--mdt-scale));
    color: #666;
    letter-spacing: 0.12em;
  }

  .paper-meta-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(10px * var(--mdt-scale));
    margin-bottom: calc(20px * var(--mdt-scale));
  }

  .paper-meta-item {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .meta-label {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(9px * var(--mdt-scale));
    color: #666;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .meta-value {
    font-size: calc(14px * var(--mdt-scale));
    color: #ccc;
  }

  .paper-section {
    margin-bottom: calc(18px * var(--mdt-scale));
  }

  .paper-section-title {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10px * var(--mdt-scale));
    color: #888;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    margin: 0 0 calc(8px * var(--mdt-scale));
    padding-bottom: calc(3px * var(--mdt-scale));
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }

  .paper-field-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(12px * var(--mdt-scale));
    margin-bottom: calc(6px * var(--mdt-scale));
  }

  .paper-field {
    display: flex;
    flex-direction: column;
    gap: calc(1px * var(--mdt-scale));
  }

  .field-label {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(9px * var(--mdt-scale));
    color: #555;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .field-value {
    font-size: calc(13px * var(--mdt-scale));
    color: #ccc;
  }

  .paper-charges-table {
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: calc(2px * var(--mdt-scale));
    overflow: hidden;
  }

  .pct-header {
    display: grid;
    grid-template-columns: 2fr 1fr 0.6fr 1fr;
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.03);
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(9px * var(--mdt-scale));
    color: #666;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .pct-row {
    display: grid;
    grid-template-columns: 2fr 1fr 0.6fr 1fr;
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-top: 1px solid rgba(255, 255, 255, 0.03);
    font-size: calc(12px * var(--mdt-scale));
    color: #bbb;
  }

  .paper-total {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: calc(10px * var(--mdt-scale));
    margin-top: calc(1px * var(--mdt-scale));
    background: rgba(248, 113, 113, 0.08);
    border: 1px solid rgba(248, 113, 113, 0.15);
    border-radius: calc(2px * var(--mdt-scale));
  }

  .total-label {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10px * var(--mdt-scale));
    color: #f87171;
    letter-spacing: 0.1em;
  }

  .total-value {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    color: #f87171;
  }

  .paper-notes {
    font-size: calc(12px * var(--mdt-scale));
    color: #999;
    font-style: italic;
    margin: 0;
    padding: calc(8px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: calc(2px * var(--mdt-scale));
  }

  .paper-footer {
    margin-top: calc(24px * var(--mdt-scale));
    text-align: center;
  }

  .paper-status-stamp {
    display: inline-block;
    padding: calc(4px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border: 2px solid;
    border-radius: calc(4px * var(--mdt-scale));
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.15em;
    transform: rotate(-3deg);
    margin-bottom: calc(16px * var(--mdt-scale));
  }

  .paper-disclaimer {
    font-size: calc(9px * var(--mdt-scale));
    color: #555;
    line-height: 1.5;
    margin: 0 auto;
    max-width: calc(480px * var(--mdt-scale));
  }

  .paper-barcode {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(8px * var(--mdt-scale));
    color: #444;
    letter-spacing: 0.05em;
    margin-top: calc(12px * var(--mdt-scale));
    user-select: none;
  }

  .font-mono {
    font-family: 'Share Tech Mono', monospace;
  }

  /* scrollbar */
  .citation-detail-view::-webkit-scrollbar,
  .citation-list-view::-webkit-scrollbar {
    width: 4px;
  }
  .citation-detail-view::-webkit-scrollbar-track,
  .citation-list-view::-webkit-scrollbar-track {
    background: transparent;
  }
  .citation-detail-view::-webkit-scrollbar-thumb,
  .citation-list-view::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.08);
    border-radius: 2px;
  }
</style>
