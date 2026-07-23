<script>
  const { report, participants = [], charges = [], officer, onIssue, onClose } = $props();

  let selectedCitizenId = $state('');
  let selectedPlayerName = $state('');
  let notes = $state('');
  let issuing = $state(false);

  let suspects = $derived((participants || []).filter(p =>
    (p.participant_type || p.participantType) === 'suspect' &&
    (p.citizen_id || p.citizenId)
  ));

  let defaultSuspect = $derived(suspects[0] || null);

  $effect(() => {
    if (defaultSuspect && !selectedCitizenId) {
      selectedCitizenId = defaultSuspect.citizen_id || defaultSuspect.citizenId || '';
      selectedPlayerName = defaultSuspect.name || '';
    }
  });

  function handleIssue() {
    if (!selectedCitizenId) return;
    const result = onIssue({
      reportId: report?.id,
      citizenId: selectedCitizenId,
      playerName: selectedPlayerName,
      notes,
    });

    if (result && typeof result.then === 'function') {
      issuing = true;
      result.finally(() => {
        issuing = false;
      });
    }
  }
</script>

<div
  class="modal-overlay"
  onclick={onClose}
  onkeydown={(e) => { if (e.key === 'Escape') onClose(); }}
  role="dialog"
  aria-modal="true"
  tabindex="0"
>
  <div class="modal-panel issue-citation-modal" role="document">
    <div class="modal-header">
      <h3 class="modal-title">Issue Citation</h3>
      <button class="modal-close" onclick={onClose} aria-label="Close">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
      </button>
    </div>

    <div class="modal-body citation-issue-body">
      {#if suspects.length === 0}
        <div class="empty-state">
          <p class="empty-text">No suspects in this report</p>
          <p class="empty-sub">Add at least one suspect participant with a Citizen ID before issuing a citation.</p>
        </div>
      {:else}
        <div class="form-group">
          <label class="form-label" for="citation-recipient-select">Recipient</label>
          <select id="citation-recipient-select" class="form-select" bind:value={selectedCitizenId} onchange={(e) => {
            const s = suspects.find(p => (p.citizen_id || p.citizenId) === e.target.value);
            selectedPlayerName = s?.name || '';
          }}>
            {#each suspects as suspect (suspect.citizen_id || suspect.citizenId)}
              <option value={suspect.citizen_id || suspect.citizenId}>
                {suspect.name || `${suspect.citizen_id || suspect.citizenId}`}
              </option>
            {/each}
          </select>
        </div>
      {/if}

      <div class="citation-charges-preview">
        <label class="form-label" for="citation-charges-preview">Charges on Citation ({charges.length})</label>
        <div class="charges-preview-list" id="citation-charges-preview">
          {#each charges as charge, i (i)}
            <div class="charge-preview-row">
              <span class="charge-preview-name">{charge.charge}</span>
              <span class="charge-preview-detail">{charge.severity} &middot; Count: {charge.count || 1} &middot; ${Number(charge.fine || 0).toLocaleString()}</span>
            </div>
          {/each}
        </div>
        {#if charges.length === 0}
          <p class="empty-inline">No charges attached. Add charges to the report first.</p>
        {/if}
      </div>

      <div class="form-group">
        <label class="form-label" for="citation-notes">Notes (optional)</label>
        <textarea
          id="citation-notes"
          class="form-textarea compact-textarea"
          bind:value={notes}
          rows="3"
          placeholder="Additional notes for the citation..."
        ></textarea>
      </div>
    </div>

    <div class="modal-footer">
      <button class="btn-cancel" onclick={onClose}>Cancel</button>
      <button
        class="btn-primary btn-issue-citation"
        onclick={handleIssue}
        disabled={!selectedCitizenId || issuing || charges.length === 0}
      >
        {#if issuing}
          Issuing...
        {:else}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>
          Issue Citation
        {/if}
      </button>
    </div>
  </div>
</div>

<style>
  .issue-citation-modal {
    max-width: calc(480px * var(--mdt-scale));
  }

  .citation-issue-body {
    padding: calc(16px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
  }

  .citation-charges-preview {
    margin-bottom: calc(12px * var(--mdt-scale));
  }

  .charges-preview-list {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    max-height: calc(160px * var(--mdt-scale));
    overflow-y: auto;
  }

  .charge-preview-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid var(--es-border, rgba(255, 255, 255, 0.06));
    border-radius: calc(var(--es-radius, 6px) * var(--mdt-scale));
  }

  .charge-preview-name {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(12px * var(--mdt-scale));
    color: #00ffcc;
  }

  .charge-preview-detail {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted, #888);
    white-space: nowrap;
  }

  .btn-issue-citation {
    background: #00ffcc;
    color: #080a0e;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .btn-issue-citation svg {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
  }

  .btn-issue-citation:disabled {
    background: rgba(0, 255, 204, 0.2);
    color: rgba(0, 255, 204, 0.4);
    cursor: not-allowed;
  }

  .empty-inline {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted, #888);
    text-align: center;
    padding: calc(10px * var(--mdt-scale)) 0;
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border-top: 1px solid var(--es-border, rgba(255, 255, 255, 0.06));
  }

  .btn-cancel {
    padding: calc(6px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    background: transparent;
    border: 1px solid var(--es-border, rgba(255, 255, 255, 0.12));
    color: var(--mdt-text-muted, #888);
    border-radius: calc(var(--es-radius, 6px) * var(--mdt-scale));
    cursor: pointer;
    font-size: calc(12px * var(--mdt-scale));
  }

  .btn-cancel:hover {
    color: #fff;
    border-color: rgba(255, 255, 255, 0.25);
  }

  .btn-primary {
    padding: calc(6px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border: none;
    border-radius: calc(var(--es-radius, 6px) * var(--mdt-scale));
    cursor: pointer;
    font-size: calc(12px * var(--mdt-scale));
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .form-group {
    margin-bottom: calc(12px * var(--mdt-scale));
  }

  .form-label {
    display: block;
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted, #666);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  .form-select {
    width: 100%;
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid var(--es-border, rgba(255, 255, 255, 0.08));
    border-radius: calc(var(--es-radius, 6px) * var(--mdt-scale));
    color: #fff;
    font-size: calc(13px * var(--mdt-scale));
    outline: none;
  }

  .form-select:focus {
    border-color: #00ffcc;
  }

  .form-textarea {
    width: 100%;
    padding: calc(8px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid var(--es-border, rgba(255, 255, 255, 0.08));
    border-radius: calc(var(--es-radius, 6px) * var(--mdt-scale));
    color: #fff;
    font-size: calc(12px * var(--mdt-scale));
    resize: vertical;
    outline: none;
  }

  .form-textarea:focus {
    border-color: #00ffcc;
  }

  .compact-textarea {
    min-height: calc(50px * var(--mdt-scale));
  }

  .empty-state {
    padding: calc(24px * var(--mdt-scale));
    text-align: center;
  }

  .empty-text {
    font-size: calc(14px * var(--mdt-scale));
    color: var(--mdt-text-muted, #888);
  }

  .empty-sub {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted, #666);
    margin-top: calc(4px * var(--mdt-scale));
  }
</style>
