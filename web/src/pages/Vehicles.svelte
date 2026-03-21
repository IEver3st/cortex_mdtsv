<script>
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const REGISTRATION_COLORS = {
    valid: 'var(--mdt-success)',
    expired: 'var(--mdt-warning)',
    suspended: 'var(--mdt-error)',
    stolen: 'var(--mdt-error)',
    unregistered: 'var(--mdt-text-muted)',
  };

  const FLAG_DEFS = [
    { key: 'stolen', label: 'Stolen', color: '#ef4444' },
    { key: 'wanted', label: 'Wanted', color: '#f97316' },
    { key: 'impounded', label: 'Impounded', color: '#eab308' },
    { key: 'bolo', label: 'BOLO', color: '#3b82f6' },
    { key: 'evidence_hold', label: 'Evidence Hold', color: '#a855f7' },
    { key: 'fled_scene', label: 'Fled Scene', color: '#ec4899' },
  ];

  const LOT_OPTIONS = ['Downtown Lot', 'Sandy Shores Lot', 'Paleto Bay Lot'];

  const MOCK_RESULTS = [
    { id: 1, vehicle_id: 'VEH001', plate: 'LSPD 001', model: 'Police Cruiser', color: 'Black/White', owner_name: 'LSPD Fleet', registration_status: 'valid', flags: [] },
    { id: 2, vehicle_id: 'VEH002', plate: 'SA1 KNG', model: 'Sultan RS', color: 'Midnight Blue', owner_name: 'James Sullivan', registration_status: 'valid', flags: ['bolo'] },
    { id: 3, vehicle_id: 'VEH003', plate: 'XPRD 92', model: 'Dominator GTX', color: 'Red', owner_name: 'Maria Santos', registration_status: 'expired', flags: [] },
    { id: 4, vehicle_id: 'VEH004', plate: 'GONE 44', model: 'Zentorno', color: 'Matte Black', owner_name: 'Unknown', registration_status: 'stolen', flags: ['stolen', 'fled_scene'] },
    { id: 5, vehicle_id: 'VEH005', plate: 'NREG 77', model: 'Faggio', color: 'White', owner_name: 'Tony Rizzo', registration_status: 'unregistered', flags: [] },
    { id: 6, vehicle_id: 'VEH006', plate: 'SUSP 11', model: 'Baller LE', color: 'Silver', owner_name: 'Derek Haines', registration_status: 'suspended', flags: ['wanted'] },
  ];

  const MOCK_VEHICLE = {
    vehicle_id: 'VEH002',
    plate: 'SA1 KNG',
    model: 'Sultan RS',
    color: 'Midnight Blue',
    vehicle_class: 'Sports',
    registration_status: 'valid',
    owner_name: 'James Sullivan',
    owner_citizen_id: 'CIT-20240315-0042',
    flags: ['bolo'],
    notes: 'Vehicle spotted multiple times near Maze Bank. Possible involvement in robbery case #4412.',
    vin: 'LSC9X83HK201445',
  };

  const MOCK_IMPOUNDS = [
    { id: 101, status: 'released', reason: 'Parked in restricted zone during city event.', lot_location: 'Downtown Lot', fee: 250, hold_until: '2025-01-16 18:00', impound_date: '2025-01-15 14:30', release_date: '2025-01-16 09:00', officer_name: 'Ofc. Martinez' },
    { id: 102, status: 'released', reason: 'Abandoned vehicle on Route 68.', lot_location: 'Sandy Shores Lot', fee: 500, hold_until: '2024-11-02 08:00', impound_date: '2024-11-01 02:15', release_date: '2024-11-02 11:30', officer_name: 'Dep. Chen' },
  ];

  let searchQuery = $state('');
  let debounceTimer = $state(null);
  let impoundFormOpen = $state(false);
  let impoundReason = $state('');
  let impoundLot = $state(LOT_OPTIONS[0]);
  let impoundFee = $state(0);
  let impoundHoldHours = $state(24);
  let submitting = $state(false);

  let useMock = $derived(isEnvBrowser());
  let results = $derived(useMock && searchQuery.trim() ? MOCK_RESULTS.filter(v => {
    const q = searchQuery.toLowerCase();
    return v.plate.toLowerCase().includes(q) || v.model.toLowerCase().includes(q) || (v.vin || '').toLowerCase().includes(q);
  }) : (dataStore.vehicleSearchResults || []));
  let vehicle = $derived(useMock ? (dataStore.selectedVehicle || null) : (dataStore.selectedVehicle || null));
  let impounds = $derived(useMock ? (dataStore.vehicleImpounds?.length ? dataStore.vehicleImpounds : []) : (dataStore.vehicleImpounds || []));
  let isDetail = $derived(!!vehicle);
  let activeImpound = $derived(impounds.find(i => i.status === 'impounded') || null);
  let pastImpounds = $derived(impounds.filter(i => i.status !== 'impounded'));

  function handleSearchInput(e) {
    searchQuery = e.target.value;
    if (debounceTimer) clearTimeout(debounceTimer);
    if (!searchQuery.trim()) return;
    debounceTimer = setTimeout(() => {
      if (!useMock) {
        dataStore.searchVehicles(searchQuery.trim());
      }
    }, 300);
  }

  function openDetail(row) {
    if (useMock) {
      dataStore.selectedVehicle = MOCK_VEHICLE;
      dataStore.vehicleImpounds = MOCK_IMPOUNDS;
    } else {
      dataStore.getVehicle(row.id);
    }
    impoundFormOpen = false;
    resetImpoundForm();
  }

  function goBack() {
    dataStore.selectedVehicle = null;
    dataStore.vehicleImpounds = [];
    impoundFormOpen = false;
    resetImpoundForm();
  }

  function resetImpoundForm() {
    impoundReason = '';
    impoundLot = LOT_OPTIONS[0];
    impoundFee = 0;
    impoundHoldHours = 24;
  }

  function navigateToCitizen(citizenId) {
    mdtStore.activePage = 'citizens';
  }

  async function confirmImpound() {
    if (!vehicle || submitting) return;
    submitting = true;
    await dataStore.impoundVehicle({
      vehicleId: vehicle.id,
      reason: impoundReason,
      lotLocation: impoundLot,
      fee: impoundFee,
      holdHours: impoundHoldHours,
    });
    if (useMock) {
      const now = new Date();
      const holdUntil = new Date(now.getTime() + impoundHoldHours * 3600000);
      dataStore.vehicleImpounds = [{
        id: Date.now(),
        status: 'impounded',
        reason: impoundReason,
        lot_location: impoundLot,
        fee: impoundFee,
        hold_until: holdUntil.toISOString().slice(0, 16).replace('T', ' '),
        impound_date: now.toISOString().slice(0, 16).replace('T', ' '),
        release_date: null,
        officer_name: `${mdtStore.officer.rank} ${mdtStore.officer.lastName}`,
      }, ...dataStore.vehicleImpounds];
    } else {
      dataStore.getVehicle(vehicle.id);
    }
    impoundFormOpen = false;
    resetImpoundForm();
    submitting = false;
  }

  async function handleRelease(impoundId) {
    if (submitting) return;
    submitting = true;
    await dataStore.releaseImpound(impoundId);
    if (useMock) {
      dataStore.vehicleImpounds = dataStore.vehicleImpounds.map(i =>
        i.id === impoundId ? { ...i, status: 'released', release_date: new Date().toISOString().slice(0, 16).replace('T', ' ') } : i
      );
    } else {
      dataStore.getVehicle(vehicle.id);
    }
    submitting = false;
  }

  function getRegColor(status) {
    return REGISTRATION_COLORS[status] || 'var(--mdt-text-muted)';
  }

  function getFlagDef(key) {
    return FLAG_DEFS.find(f => f.key === key) || { key, label: key, color: '#6b7280' };
  }

  function formatDate(dateStr) {
    if (!dateStr) return '\u2014';
    return dateStr;
  }

  function formatCurrency(val) {
    if (val == null) return '\u2014';
    return `$${Number(val).toLocaleString()}`;
  }
</script>

<div class="vehicles-page">
  {#if !isDetail}
    <div class="search-mode">
      <div class="page-header">
        <h2 class="page-title">DMV & Vehicle Registry</h2>
        <p class="page-subtitle">Search by plate, VIN, or model</p>
      </div>

      <div class="search-bar">
        <svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
        </svg>
        <input
          type="text"
          class="search-input"
          placeholder="Search plate, VIN, or model..."
          value={searchQuery}
          oninput={handleSearchInput}
        />
        {#if searchQuery}
          <button class="search-clear" aria-label="Clear search" onclick={() => { searchQuery = ''; dataStore.vehicleSearchResults = []; }}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        {/if}
      </div>

      {#if results.length > 0}
        <div class="results-table">
          <div class="table-header">
            <span class="th">Plate</span>
            <span class="th">Model</span>
            <span class="th">Color</span>
            <span class="th">Owner</span>
            <span class="th">Registration</span>
            <span class="th">Flags</span>
          </div>
          {#each results as row, i (row.id || row.vehicle_id || i)}
            <button class="table-row" onclick={() => openDetail(row)}>
              <span class="td-plate font-mono">{row.plate.toUpperCase()}</span>
              <span class="td-model">{row.model || '\u2014'}</span>
              <span class="td-color">{row.color || '\u2014'}</span>
              <span class="td-owner">{row.owner_name || '\u2014'}</span>
              <span class="td-reg">
                <span class="reg-badge" style="--reg-color: {getRegColor(row.registration_status)}">{row.registration_status || '\u2014'}</span>
              </span>
              <span class="td-flags">
                {#each (row.flags || []) as flag (flag)}
                  {@const def = getFlagDef(flag)}
                  <span class="flag-badge" style="--flag-color: {def.color}">{def.label}</span>
                {/each}
              </span>
            </button>
          {/each}
        </div>
      {:else if searchQuery.trim()}
        <div class="empty-state">
          <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" /><path d="M8 11h6" />
          </svg>
          <p class="empty-text">No vehicles found</p>
          <p class="empty-sub">Try a different plate, VIN, or model</p>
        </div>
      {/if}
    </div>
  {:else}
    <div class="detail-mode">
      <button class="back-btn" onclick={goBack}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to Search</span>
      </button>

      <div class="vehicle-header">
        <div class="header-left">
          <div class="plate-frame">
            <span class="plate-text font-mono">{vehicle.plate.toUpperCase()}</span>
          </div>
          <div class="header-info">
            <h2 class="vehicle-model">{vehicle.model}</h2>
            <div class="header-meta">
              <span class="meta-tag">{vehicle.color || '\u2014'}</span>
              {#if vehicle.vehicle_class}
                <span class="meta-divider"></span>
                <span class="meta-tag">{vehicle.vehicle_class}</span>
              {/if}
              {#if vehicle.vin}
                <span class="meta-divider"></span>
                <span class="meta-tag font-mono vin-tag">{vehicle.vin}</span>
              {/if}
            </div>
          </div>
        </div>
        <div class="header-right">
          <span class="reg-badge-lg" style="--reg-color: {getRegColor(vehicle.registration_status)}">{vehicle.registration_status || '\u2014'}</span>
        </div>
      </div>

      <div class="detail-grid">
        <div class="section-card owner-card">
          <h3 class="section-label">Owner Information</h3>
          <div class="owner-row">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="owner-icon">
              <circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" />
            </svg>
            <div class="owner-details">
              <span class="owner-name">{vehicle.owner_name || '\u2014'}</span>
              {#if vehicle.owner_citizen_id}
                <button class="cid-link font-mono" onclick={() => navigateToCitizen(vehicle.owner_citizen_id)}>{vehicle.owner_citizen_id}</button>
              {/if}
            </div>
          </div>
        </div>

        <div class="section-card flags-card">
          <h3 class="section-label">Flags</h3>
          {#if vehicle.flags?.length > 0}
            <div class="flags-row">
              {#each vehicle.flags as flag (flag)}
                {@const def = getFlagDef(flag)}
                <span class="flag-badge flag-badge-lg" style="--flag-color: {def.color}">{def.label}</span>
              {/each}
            </div>
          {:else}
            <p class="no-data">No flags on record</p>
          {/if}
        </div>
      </div>

      {#if vehicle.notes}
        <div class="section-card">
          <h3 class="section-label">Notes</h3>
          <p class="notes-text">{vehicle.notes}</p>
        </div>
      {/if}

      <div class="section-card impound-section">
        <h3 class="section-label">Impound</h3>

        {#if activeImpound}
          <div class="active-impound">
            <div class="impound-status-bar">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="impound-status-icon">
                <rect x="3" y="3" width="18" height="18" rx="2" /><path d="M9 3v18M15 3v18M3 9h18M3 15h18" />
              </svg>
              <span class="impound-status-text">Currently Impounded</span>
            </div>
            <div class="impound-details-grid">
              <div class="impound-detail">
                <span class="impound-detail-label">Reason</span>
                <span class="impound-detail-value">{activeImpound.reason}</span>
              </div>
              <div class="impound-detail">
                <span class="impound-detail-label">Lot Location</span>
                <span class="impound-detail-value">{activeImpound.lot_location}</span>
              </div>
              <div class="impound-detail">
                <span class="impound-detail-label">Fee</span>
                <span class="impound-detail-value font-mono">{formatCurrency(activeImpound.fee)}</span>
              </div>
              <div class="impound-detail">
                <span class="impound-detail-label">Hold Until</span>
                <span class="impound-detail-value font-mono">{formatDate(activeImpound.hold_until)}</span>
              </div>
              <div class="impound-detail">
                <span class="impound-detail-label">Impounded On</span>
                <span class="impound-detail-value font-mono">{formatDate(activeImpound.impound_date)}</span>
              </div>
              <div class="impound-detail">
                <span class="impound-detail-label">Officer</span>
                <span class="impound-detail-value">{activeImpound.officer_name || '\u2014'}</span>
              </div>
            </div>
            <button class="btn-release" onclick={() => handleRelease(activeImpound.id)} disabled={submitting}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7" />
              </svg>
              Release Vehicle
            </button>
          </div>
        {:else}
          {#if !impoundFormOpen}
            <button class="btn-impound" onclick={() => impoundFormOpen = true}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="3" width="18" height="18" rx="2" /><path d="M9 3v18M15 3v18M3 9h18M3 15h18" />
              </svg>
              Impound Vehicle
            </button>
          {:else}
            <div class="impound-form">
              <div class="form-group">
                <label class="form-label" for="impound-reason">Reason</label>
                <textarea
                  id="impound-reason"
                  class="form-textarea"
                  placeholder="Enter impound reason..."
                  bind:value={impoundReason}
                  rows="3"
                ></textarea>
              </div>
              <div class="form-row">
                <div class="form-group form-group-half">
                  <label class="form-label" for="impound-lot">Lot Location</label>
                  <select id="impound-lot" class="form-select" bind:value={impoundLot}>
                    {#each LOT_OPTIONS as lot (lot)}
                      <option value={lot}>{lot}</option>
                    {/each}
                  </select>
                </div>
                <div class="form-group form-group-quarter">
                  <label class="form-label" for="impound-fee">Fee ($)</label>
                  <input id="impound-fee" type="number" class="form-input font-mono" min="0" bind:value={impoundFee} />
                </div>
                <div class="form-group form-group-quarter">
                  <label class="form-label" for="impound-hold">Hold (hrs)</label>
                  <input id="impound-hold" type="number" class="form-input font-mono" min="1" bind:value={impoundHoldHours} />
                </div>
              </div>
              <div class="form-actions">
                <button class="btn-confirm" onclick={confirmImpound} disabled={submitting || !impoundReason.trim()}>Confirm Impound</button>
                <button class="btn-cancel" onclick={() => { impoundFormOpen = false; resetImpoundForm(); }}>Cancel</button>
              </div>
            </div>
          {/if}
        {/if}
      </div>

      {#if pastImpounds.length > 0}
        <div class="section-card">
          <h3 class="section-label">Impound History</h3>
          <div class="history-list">
            <div class="history-header">
              <span>Date</span>
              <span>Reason</span>
              <span>Lot</span>
              <span>Fee</span>
              <span>Status</span>
              <span>Officer</span>
            </div>
            {#each pastImpounds as imp, i (imp.id || i)}
              <div class="history-row">
                <span class="font-mono">{formatDate(imp.impound_date)}</span>
                <span class="history-reason">{imp.reason || '\u2014'}</span>
                <span>{imp.lot_location || '\u2014'}</span>
                <span class="font-mono">{formatCurrency(imp.fee)}</span>
                <span class="history-status" class:status-released={imp.status === 'released'} class:status-impounded={imp.status === 'impounded'}>{imp.status || '\u2014'}</span>
                <span>{imp.officer_name || '\u2014'}</span>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .vehicles-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale));
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    height: 100%;
  }

  .search-mode {
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .detail-mode {
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .page-header {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .page-title {
    font-family: 'Outfit', sans-serif;
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
  }

  .page-subtitle {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .search-bar {
    position: relative;
    display: flex;
    align-items: center;
  }

  .search-icon {
    position: absolute;
    left: calc(12px * var(--mdt-scale));
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(36px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .search-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .search-input:focus {
    border-color: var(--mdt-accent);
  }

  .search-clear {
    position: absolute;
    right: calc(8px * var(--mdt-scale));
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    color: var(--mdt-text-muted);
    cursor: pointer;
    border-radius: var(--mdt-radius-sm);
    transition: color 0.15s ease;
    padding: 0;
  }

  .search-clear svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .search-clear:hover {
    color: var(--mdt-text);
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
    grid-template-columns: 1.1fr 1.2fr 0.9fr 1.3fr 1fr 1.4fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-bottom: 1px solid var(--mdt-border);
  }

  .th {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .table-row {
    display: grid;
    grid-template-columns: 1.1fr 1.2fr 0.9fr 1.3fr 1fr 1.4fr;
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

  .td-plate {
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.04em;
  }

  .td-model {
    color: var(--mdt-text-dim);
  }

  .td-color {
    color: var(--mdt-text-dim);
  }

  .td-owner {
    color: var(--mdt-text-dim);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .td-reg {
    display: flex;
    align-items: center;
  }

  .reg-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    background: color-mix(in srgb, var(--reg-color) 15%, transparent);
    color: var(--reg-color);
    border: 1px solid color-mix(in srgb, var(--reg-color) 25%, transparent);
    white-space: nowrap;
    line-height: 1.4;
  }

  .td-flags {
    display: flex;
    flex-wrap: wrap;
    gap: calc(4px * var(--mdt-scale));
    align-items: center;
  }

  .flag-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    background: color-mix(in srgb, var(--flag-color) 15%, transparent);
    color: var(--flag-color);
    border: 1px solid color-mix(in srgb, var(--flag-color) 25%, transparent);
    white-space: nowrap;
    line-height: 1.4;
  }

  .flag-badge-lg {
    padding: calc(4px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
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

  .vehicle-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(18px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(20px * var(--mdt-scale));
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: calc(16px * var(--mdt-scale));
    min-width: 0;
  }

  .plate-frame {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: calc(10px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 2px solid var(--mdt-border-2);
    border-radius: var(--mdt-radius);
    flex-shrink: 0;
  }

  .plate-text {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: 0.08em;
    line-height: 1;
  }

  .header-info {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    min-width: 0;
  }

  .vehicle-model {
    font-family: 'Outfit', sans-serif;
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
    line-height: 1.1;
  }

  .header-meta {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .meta-tag {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .vin-tag {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.03em;
  }

  .meta-divider {
    width: calc(3px * var(--mdt-scale));
    height: calc(3px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .header-right {
    flex-shrink: 0;
  }

  .reg-badge-lg {
    display: inline-flex;
    align-items: center;
    padding: calc(6px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 700;
    text-transform: capitalize;
    background: color-mix(in srgb, var(--reg-color) 15%, transparent);
    color: var(--reg-color);
    border: 1px solid color-mix(in srgb, var(--reg-color) 30%, transparent);
    white-space: nowrap;
    letter-spacing: 0.02em;
  }

  .detail-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(12px * var(--mdt-scale));
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
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .owner-row {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .owner-icon {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .owner-details {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .owner-name {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .cid-link {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-accent-dim);
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    text-align: left;
    font-family: 'Share Tech Mono', monospace;
    letter-spacing: 0.03em;
    transition: color 0.12s ease;
  }

  .cid-link:hover {
    color: var(--mdt-accent);
    text-decoration: underline;
  }

  .flags-row {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
  }

  .no-data {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    opacity: 0.6;
  }

  .notes-text {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.6;
    white-space: pre-wrap;
  }

  .impound-section {
    gap: calc(12px * var(--mdt-scale));
  }

  .active-impound {
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
  }

  .impound-status-bar {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: color-mix(in srgb, var(--mdt-warning) 10%, transparent);
    border: 1px solid color-mix(in srgb, var(--mdt-warning) 25%, transparent);
    border-radius: var(--mdt-radius-sm);
  }

  .impound-status-icon {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
    color: var(--mdt-warning);
    flex-shrink: 0;
  }

  .impound-status-text {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-warning);
  }

  .impound-details-grid {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: calc(10px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
  }

  .impound-detail {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .impound-detail-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .impound-detail-value {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text);
  }

  .btn-release {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    align-self: flex-start;
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    background: var(--mdt-success);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .btn-release svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .btn-release:hover {
    opacity: 0.9;
  }

  .btn-release:active {
    transform: scale(0.97);
  }

  .btn-release:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-impound {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    align-self: flex-start;
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease, transform 0.1s ease;
  }

  .btn-impound svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .btn-impound:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .btn-impound:active {
    transform: scale(0.97);
  }

  .impound-form {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    animation: fadeIn 0.15s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .form-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .form-textarea {
    width: 100%;
    resize: vertical;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.5;
    outline: none;
    transition: border-color 0.15s ease;
    min-height: calc(50px * var(--mdt-scale));
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .form-row {
    display: flex;
    gap: calc(10px * var(--mdt-scale));
  }

  .form-group-half {
    flex: 2;
  }

  .form-group-quarter {
    flex: 1;
  }

  .form-select {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    cursor: pointer;
    appearance: none;
  }

  .form-select:focus {
    border-color: var(--mdt-accent);
  }

  .form-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .form-input:focus {
    border-color: var(--mdt-accent);
  }

  .form-actions {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
  }

  .btn-confirm {
    padding: calc(8px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .btn-confirm:hover {
    opacity: 0.9;
  }

  .btn-confirm:active {
    transform: scale(0.97);
  }

  .btn-confirm:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .btn-cancel {
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: none;
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease, transform 0.1s ease;
  }

  .btn-cancel:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .btn-cancel:active {
    transform: scale(0.97);
  }

  .history-list {
    display: flex;
    flex-direction: column;
  }

  .history-header {
    display: grid;
    grid-template-columns: 1.2fr 2fr 1fr 0.7fr 0.8fr 1fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    border-bottom: 1px solid var(--mdt-border);
  }

  .history-row {
    display: grid;
    grid-template-columns: 1.2fr 2fr 1fr 0.7fr 0.8fr 1fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
    align-items: center;
  }

  .history-row:last-child {
    border-bottom: none;
  }

  .history-reason {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .history-status {
    text-transform: capitalize;
    font-weight: 500;
  }

  .status-released {
    color: var(--mdt-success);
  }

  .status-impounded {
    color: var(--mdt-warning);
  }

  .font-mono {
    font-family: 'Share Tech Mono', monospace;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
