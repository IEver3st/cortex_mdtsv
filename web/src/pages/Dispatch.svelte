<script>
  import { onMount } from 'svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { nuiPost, isEnvBrowser } from '../lib/utils/nui.js';
  import { mergeDispatchUnits, isUnitOnDuty } from '../lib/utils/helpers.js';
  import DispatchMap from '../lib/components/DispatchMap.svelte';
  import {
    RefreshCw,
    Users,
    AlertTriangle,
    MapPin,
    Crosshair,
    Construction,
  } from '@lucide/svelte';

  const SEVERITY_FILTERS = ['All', 'Critical', 'High', 'Medium', 'Low'];
  let activeFilter = $state('All');
  let selectedCallId = $state(null);
  let noteDraft = $state('');
  let closeReason = $state('');
  let mapComponent;

  let calls = $derived(dataStore.dispatchCalls);
  let rosterUnits = $derived(dataStore.unitsList || []);
  let liveUnits = $derived(dataStore.dispatchActiveUnits || []);
  let units = $derived(mergeDispatchUnits(rosterUnits, liveUnits));
  let actionState = $derived(dataStore.dispatchActionState);

  let filteredCalls = $derived.by(() => {
    if (activeFilter === 'All') return calls;
    return calls.filter((c) => {
      const s = String(c.severity || 'Medium').toLowerCase();
      return s === activeFilter.toLowerCase();
    });
  });

  let selectedCall = $derived.by(() => {
    if (!selectedCallId) return null;
    return calls.find((c) => c.id === selectedCallId) || null;
  });

  $effect(() => {
    if (dataStore.selectedDispatchId !== selectedCallId) {
      selectedCallId = dataStore.selectedDispatchId;
    }
  });

  onMount(async () => {
    await Promise.all([
      dataStore.fetchDispatch(),
      dataStore.fetchUnits(),
    ]);
    if (!isEnvBrowser()) {
      await nuiPost('cortex_mdt:subscribeDispatch');
    }
  });

  function handleSelectCall(id) {
    selectedCallId = selectedCallId === id ? null : id;
    dataStore.selectedDispatchId = selectedCallId;
  }

  async function handleRefresh() {
    await dataStore.fetchDispatch();
  }

  async function handleAttachSelected() {
    if (!selectedCallId) return;
    await dataStore.attachDispatchCall(selectedCallId);
    await dataStore.fetchDispatch();
  }

  async function handleAttach(callId) {
    await dataStore.attachDispatchCall(callId);
    await dataStore.fetchDispatch();
  }

  async function handleDetach(callId) {
    await dataStore.detachDispatchCall(callId);
    await dataStore.fetchDispatch();
  }

  async function handleWaypoint(coords) {
    if (!coords) return;
    await dataStore.setDispatchWaypoint(coords);
  }

  async function handlePanic() {
    await dataStore.triggerDispatchPanic();
    await dataStore.fetchDispatch();
  }

  async function handleTrafficStop() {
    await dataStore.createTrafficStopCall();
    await dataStore.fetchDispatch();
  }

  async function handleAddNote() {
    if (!selectedCallId || !noteDraft.trim()) return;
    await dataStore.addDispatchNote(selectedCallId, noteDraft.trim());
    noteDraft = '';
    await dataStore.fetchDispatch();
  }

  async function handleCode4() {
    if (!selectedCallId) return;
    await dataStore.markDispatchCode4(selectedCallId);
    await dataStore.fetchDispatch();
  }

  async function handleCloseCall() {
    if (!selectedCallId) return;
    await dataStore.closeDispatchCall(selectedCallId, closeReason);
    closeReason = '';
    await dataStore.fetchDispatch();
  }

  function handleFocusCoords(coords) {
    if (mapComponent?.focusCoords) {
      mapComponent.focusCoords(coords);
    }
  }

  function severityTone(severity) {
    const s = String(severity || '').trim().toLowerCase();
    if (s === 'critical') return 'critical';
    if (s === 'high') return 'high';
    if (s === 'low') return 'low';
    return 'medium';
  }

  function sourceTone(value) {
    const s = String(value || '').toLowerCase();
    if (s === 'ers') return 'ers';
    if (s === 'cortex-dispatch') return 'cortex';
    return 'local';
  }

  function sourceLabel(value) {
    const s = String(value || '').toLowerCase();
    if (s === 'ers') return 'ERS';
    if (s === 'cortex-dispatch') return 'CORTEX';
    if (!s) return 'LOCAL';
    return s.toUpperCase();
  }

  function formatAge(createdAt) {
    if (!createdAt) return '';
    const created = new Date(createdAt);
    const now = Date.now();
    const diffMs = now - created.getTime();
    if (diffMs < 0) return 'just now';
    const seconds = Math.floor(diffMs / 1000);
    if (seconds < 60) return `${seconds}s ago`;
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    return `${hours}h ago`;
  }

  function isUnitActive(unit) {
    return isUnitOnDuty(unit?.status);
  }

  function callSummaryLabel(call) {
    return call?.statusLabel || call?.codeName || 'Open';
  }
</script>

<div class="dispatch-page">
  <!-- Toolbar -->
  <div class="dispatch-toolbar">
    <div class="filter-pills">
      {#each SEVERITY_FILTERS as filter (filter)}
        <button
          class="pill"
          class:active={activeFilter === filter}
          onclick={() => (activeFilter = filter)}
        >
          {filter}
        </button>
      {/each}
    </div>
    <div class="toolbar-actions">
      <button class="dispatch-btn" onclick={handleRefresh}>
        <RefreshCw size={13} /> Refresh
      </button>
      <button class="dispatch-btn" onclick={handleAttachSelected} disabled={!selectedCallId || actionState.busy}>
        <Users size={13} /> Attach Unit
      </button>
      <button class="dispatch-btn" onclick={handleTrafficStop} disabled={actionState.busy}>
        <Construction size={13} /> Traffic Stop
      </button>
      <button class="dispatch-btn panic-btn" onclick={handlePanic} disabled={actionState.busy}>
        <AlertTriangle size={13} /> Panic
      </button>
    </div>
  </div>

  <!-- Grid -->
  <div class="dispatch-grid">
    <!-- Map panel -->
    <section class="dispatch-panel map-panel">
      <div class="map-meta">
        <span>{units.length} units</span>
        <span>{filteredCalls.length} calls</span>
      </div>
      <div class="map-container">
        <DispatchMap
          bind:this={mapComponent}
          calls={filteredCalls}
          {units}
          {selectedCallId}
          onSelectCall={handleSelectCall}
        />
      </div>
    </section>

    <!-- Calls panel -->
    <section class="dispatch-panel calls-panel">
      <header class="panel-head">CALLS</header>
      <div class="panel-list">
        {#if filteredCalls.length === 0}
          <div class="empty-state">No dispatch calls</div>
        {/if}
        {#each filteredCalls as call (call.id)}
          {@const selected = call.id === selectedCallId}
          {@const tone = severityTone(call.severity)}
          <article class="call-card" class:selected>
            <button class="call-main" onclick={() => handleSelectCall(call.id)}>
              <div class="call-row">
                <div class="call-tags">
                  <span class="call-code tone-{tone}">{call.code}</span>
                  <span class="call-source tone-{sourceTone(call.sourceSystem)}">{sourceLabel(call.sourceSystem)}</span>
                  {#if call.statusLabel || call.codeName}
                    <span class="call-status">{call.statusLabel || call.codeName}</span>
                  {/if}
                </div>
                <span class="call-time">{formatAge(call.createdAt)}</span>
              </div>
              <h4 class="call-title">{call.title}</h4>
              <span class="call-location">{call.location}</span>
              {#if call.street || call.postal || call.primaryCallsign || call.vehiclePlate}
                <div class="call-details">
                  {#if call.street}
                    <div class="call-detail">
                      <span class="detail-label">Street</span>
                      <span class="detail-value">{call.street}</span>
                    </div>
                  {/if}
                  {#if call.postal}
                    <div class="call-detail">
                      <span class="detail-label">Postal</span>
                      <span class="detail-value">{call.postal}</span>
                    </div>
                  {/if}
                  {#if call.primaryCallsign}
                    <div class="call-detail">
                      <span class="detail-label">Primary Unit</span>
                      <span class="detail-value">{call.primaryCallsign}</span>
                    </div>
                  {/if}
                  {#if call.vehiclePlate}
                    <div class="call-detail">
                      <span class="detail-label">Plate</span>
                      <span class="detail-value">{call.vehiclePlate}</span>
                    </div>
                  {/if}
                </div>
              {/if}
              <span class="call-meta">{call.unitCount} unit(s)</span>
            </button>
            <div class="call-actions">
              <button class="action-btn" onclick={() => handleFocusCoords(call.coords)}>
                <Crosshair size={12} /> Focus
              </button>
              <button class="action-btn" onclick={() => handleWaypoint(call.coords)}>
                <MapPin size={12} /> Waypoint
              </button>
              <button class="action-btn" onclick={() => handleAttach(call.id)} disabled={actionState.busy || call.mutationsAllowed === false}>
                <Users size={12} /> Attach
              </button>
            </div>
          </article>
        {/each}
      </div>
    </section>

    <section class="dispatch-panel details-panel">
      <header class="panel-head">DETAILS</header>
      <div class="panel-list details-list">
        {#if !selectedCall}
          <div class="empty-state">Select a dispatch call to inspect details</div>
        {:else}
          <div class="details-card">
            <div class="details-title-row">
              <div>
                <div class="call-tags">
                  <span class="call-code tone-{severityTone(selectedCall.severity)}">{selectedCall.code}</span>
                  <span class="call-source tone-{sourceTone(selectedCall.sourceSystem)}">{sourceLabel(selectedCall.sourceSystem)}</span>
                  <span class="call-status">{callSummaryLabel(selectedCall)}</span>
                </div>
                <h3 class="details-title">{selectedCall.title}</h3>
                <div class="details-subtitle">{selectedCall.location}</div>
              </div>
              <span class="call-time">{formatAge(selectedCall.createdAt)}</span>
            </div>

            {#if actionState.error}
              <div class="dispatch-error">{actionState.error}</div>
            {/if}

            <div class="details-grid">
              <div class="call-detail"><span class="detail-label">Street</span><span class="detail-value">{selectedCall.street || '—'}</span></div>
              <div class="call-detail"><span class="detail-label">Cross</span><span class="detail-value">{selectedCall.locationCross || '—'}</span></div>
              <div class="call-detail"><span class="detail-label">Area</span><span class="detail-value">{selectedCall.locationArea || '—'}</span></div>
              <div class="call-detail"><span class="detail-label">Postal</span><span class="detail-value">{selectedCall.postal || '—'}</span></div>
              <div class="call-detail"><span class="detail-label">Caller</span><span class="detail-value">{selectedCall.callerName || '—'}</span></div>
              <div class="call-detail"><span class="detail-label">External</span><span class="detail-value">{selectedCall.externalLifecycle ? 'Managed Externally' : 'Editable'}</span></div>
            </div>

            {#if selectedCall.respondingUnitDetails?.length}
              <div class="details-section">
                <strong>Responding Units</strong>
                <div class="unit-chip-row">
                  {#each selectedCall.respondingUnitDetails as unitDetail (unitDetail.unitId)}
                    <span class="unit-chip">{unitDetail.callsign || unitDetail.unitId} · {unitDetail.status || unitDetail.availability || '10-8'}</span>
                  {/each}
                </div>
              </div>
            {/if}

            {#if selectedCall.details}
              <div class="details-section">
                <strong>Details</strong>
                <div class="details-grid">
                  {#each Object.entries(selectedCall.details) as [key, value] (key)}
                    <div class="call-detail">
                      <span class="detail-label">{key}</span>
                      <span class="detail-value">{value || '—'}</span>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}

            <div class="details-section">
              <strong>Notes</strong>
              <div class="notes-list">
                {#if !selectedCall.notes?.length}
                  <span class="details-subtitle">No notes added</span>
                {/if}
                {#each selectedCall.notes || [] as note (`${note.time}-${note.author}`)}
                  <div class="note-item">
                    <span class="detail-label">{note.author} · {formatAge(new Date((note.time || 0) * 1000).toISOString())}</span>
                    <span class="detail-value">{note.text}</span>
                  </div>
                {/each}
              </div>
              <textarea class="dispatch-textarea" bind:value={noteDraft} placeholder="Add note..." disabled={actionState.busy || selectedCall.mutationsAllowed === false}></textarea>
              <div class="details-actions">
                <button class="action-btn" onclick={handleAddNote} disabled={actionState.busy || selectedCall.mutationsAllowed === false || !noteDraft.trim()}>Add Note</button>
                <button class="action-btn" onclick={() => handleWaypoint(selectedCall.coords)} disabled={!selectedCall.coords}>Waypoint</button>
                <button class="action-btn" onclick={() => handleDetach(selectedCall.id)} disabled={actionState.busy || selectedCall.mutationsAllowed === false}>Detach</button>
                <button class="action-btn" onclick={handleCode4} disabled={actionState.busy || selectedCall.mutationsAllowed === false}>Code 4</button>
              </div>
              <input class="dispatch-input" bind:value={closeReason} placeholder="Close reason" disabled={actionState.busy || selectedCall.mutationsAllowed === false} />
              <button class="dispatch-btn" onclick={handleCloseCall} disabled={actionState.busy || selectedCall.mutationsAllowed === false}>Close Call</button>
            </div>
          </div>
        {/if}
      </div>
    </section>

    <!-- Units panel -->
    <section class="dispatch-panel units-panel">
      <header class="panel-head">UNITS</header>
      <div class="panel-list">
        {#if units.length === 0}
          <div class="empty-state">No active units</div>
        {/if}
        {#each units as unit (unit.unitId || unit.source || unit.callsign)}
          {@const active = isUnitActive(unit)}
          <article class="unit-card">
            <div class="unit-main">
              <span class="unit-dot" class:active class:passive={!active}></span>
              <div class="unit-copy">
                <strong>{unit.callsign || unit.name}</strong>
                <span>{unit.name}</span>
                <span>{unit.availability}</span>
              </div>
            </div>
            <button class="action-btn" onclick={() => handleFocusCoords(unit.coords)}>
              <Crosshair size={12} /> Focus
            </button>
          </article>
        {/each}
      </div>
    </section>
  </div>
</div>

<style>
  .dispatch-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: calc(12px * var(--mdt-scale));
    gap: calc(10px * var(--mdt-scale));
    overflow: hidden;
  }

  /* ─── Toolbar ──────────────────────────── */
  .dispatch-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .filter-pills {
    display: flex;
    gap: calc(4px * var(--mdt-scale));
  }

  .pill {
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: transparent;
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
    font-family: inherit;
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
    white-space: nowrap;
  }

  .pill:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .pill.active {
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    border-color: var(--mdt-accent);
  }

  .toolbar-actions {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
  }

  .dispatch-btn {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: transparent;
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
    font-family: inherit;
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
    white-space: nowrap;
  }

  .dispatch-btn:hover:not(:disabled) {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .dispatch-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .panic-btn {
    border-color: rgba(239, 68, 68, 0.4);
    color: #f87171;
  }

  .panic-btn:hover {
    background: rgba(239, 68, 68, 0.12) !important;
    color: #fca5a5 !important;
    border-color: rgba(239, 68, 68, 0.6);
  }

  /* ─── Grid ─────────────────────────────── */
  .dispatch-grid {
    display: grid;
    grid-template-columns: 1.15fr 1fr 1fr 0.75fr;
    gap: calc(10px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
  }

  .dispatch-panel {
    display: flex;
    flex-direction: column;
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
  }

  .panel-head {
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.1em;
    color: var(--mdt-text-muted);
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
  }

  .panel-list {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    padding: calc(6px * var(--mdt-scale));
  }

  .details-list {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .details-card {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .details-title-row {
    display: flex;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
  }

  .details-title {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(15px * var(--mdt-scale));
  }

  .details-subtitle {
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
  }

  .details-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: calc(6px * var(--mdt-scale));
  }

  .details-section {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    padding-top: calc(4px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
  }

  .unit-chip-row {
    display: flex;
    flex-wrap: wrap;
    gap: calc(4px * var(--mdt-scale));
  }

  .unit-chip {
    padding: calc(4px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: 999px;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .notes-list {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .note-item {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface-2);
  }

  .dispatch-textarea,
  .dispatch-input {
    width: 100%;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    padding: calc(8px * var(--mdt-scale));
    font: inherit;
    resize: vertical;
  }

  .dispatch-textarea {
    min-height: calc(74px * var(--mdt-scale));
  }

  .details-actions {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
  }

  .dispatch-error {
    border: 1px solid rgba(239, 68, 68, 0.4);
    background: rgba(239, 68, 68, 0.12);
    color: #fca5a5;
    border-radius: var(--mdt-radius);
    padding: calc(8px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
  }

  .empty-state {
    padding: calc(24px * var(--mdt-scale));
    text-align: center;
    color: var(--mdt-text-muted);
    font-size: calc(12px * var(--mdt-scale));
  }

  /* ─── Map panel ────────────────────────── */
  .map-panel {
    position: relative;
  }

  .map-meta {
    position: absolute;
    top: calc(8px * var(--mdt-scale));
    right: calc(8px * var(--mdt-scale));
    z-index: 450;
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.6);
    background: rgba(10, 15, 26, 0.75);
    padding: calc(3px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    backdrop-filter: blur(4px);
  }

  .map-container {
    flex: 1;
    min-height: 200px;
  }

  /* ─── Call cards ────────────────────────── */
  .call-card {
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface-2, rgba(255, 255, 255, 0.02));
    margin-bottom: calc(6px * var(--mdt-scale));
    transition: border-color 0.15s ease, background 0.15s ease;
  }

  .call-card:hover {
    border-color: var(--mdt-accent-dim, rgba(99, 102, 241, 0.3));
  }

  .call-card.selected {
    border-color: var(--mdt-accent);
    background: var(--mdt-accent-dim, rgba(99, 102, 241, 0.08));
  }

  .call-main {
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: none;
    background: transparent;
    text-align: left;
    cursor: pointer;
    color: var(--mdt-text);
    font-family: inherit;
  }

  .call-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .call-tags {
    display: flex;
    gap: calc(4px * var(--mdt-scale));
    align-items: center;
  }

  .call-code {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    padding: calc(1px * var(--mdt-scale)) calc(5px * var(--mdt-scale));
    border-radius: 4px;
    letter-spacing: 0.05em;
  }

  .call-code.tone-critical { background: rgba(239, 68, 68, 0.2); color: #fca5a5; }
  .call-code.tone-high { background: rgba(249, 115, 22, 0.2); color: #fdba74; }
  .call-code.tone-medium { background: rgba(234, 179, 8, 0.2); color: #fde047; }
  .call-code.tone-low { background: rgba(34, 197, 94, 0.2); color: #86efac; }

  .call-source {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    padding: calc(1px * var(--mdt-scale)) calc(4px * var(--mdt-scale));
    border-radius: 3px;
    letter-spacing: 0.08em;
  }

  .call-source.tone-local { background: rgba(148, 163, 184, 0.15); color: #94a3b8; }
  .call-source.tone-cortex { background: rgba(99, 102, 241, 0.15); color: #a5b4fc; }
  .call-source.tone-ers { background: rgba(16, 185, 129, 0.15); color: #6ee7b7; }

  .call-status {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .call-time {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
  }

  .call-title {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    margin: 0;
    color: var(--mdt-text);
  }

  .call-location {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .call-details {
    display: flex;
    flex-wrap: wrap;
    gap: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    margin-top: calc(3px * var(--mdt-scale));
  }

  .call-detail {
    display: flex;
    gap: calc(3px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
  }

  .detail-label {
    color: var(--mdt-text-muted);
  }

  .detail-value {
    color: var(--mdt-text-dim);
    font-weight: 500;
  }

  .call-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .call-actions {
    display: flex;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
  }

  .action-btn {
    display: flex;
    align-items: center;
    gap: calc(3px * var(--mdt-scale));
    padding: calc(3px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: transparent;
    color: var(--mdt-text-dim);
    font-size: calc(10px * var(--mdt-scale));
    font-family: inherit;
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
  }

  .action-btn:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  /* ─── Unit cards ────────────────────────── */
  .unit-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    margin-bottom: calc(4px * var(--mdt-scale));
    background: var(--mdt-surface-2, rgba(255, 255, 255, 0.02));
  }

  .unit-main {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    min-width: 0;
  }

  .unit-dot {
    width: calc(8px * var(--mdt-scale));
    height: calc(8px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .unit-dot.active { background: #3b82f6; box-shadow: 0 0 6px rgba(59, 130, 246, 0.5); }
  .unit-dot.passive { background: #6b7280; }

  .unit-copy {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
  }

  .unit-copy strong {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .unit-copy span {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
