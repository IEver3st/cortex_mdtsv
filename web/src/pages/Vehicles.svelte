<script>
  import { onMount } from 'svelte';
  import {
    Car,
    Search,
    Clock,
    ChevronRight,
    X,
    RefreshCw,
    User,
    Hash,
    Tag,
  } from '@lucide/svelte';
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
    { id: 1, vehicle_id: 'VEH001', plate: 'LSPD 001', model: 'Police Cruiser', color: 'Black/White', owner_name: 'LSPD Fleet', registration_status: 'valid', flags: [], vin: 'LSC1FLEET01X9' },
    { id: 2, vehicle_id: 'VEH002', plate: 'SA1 KNG', model: 'Sultan RS', color: 'Midnight Blue', owner_name: 'James Sullivan', registration_status: 'valid', flags: ['bolo'], vin: 'LSC9X83HK201445' },
    { id: 3, vehicle_id: 'VEH003', plate: 'XPRD 92', model: 'Dominator GTX', color: 'Red', owner_name: 'Maria Santos', registration_status: 'expired', flags: [], vin: 'LSC7DGT92M3K1' },
    { id: 4, vehicle_id: 'VEH004', plate: 'GONE 44', model: 'Zentorno', color: 'Matte Black', owner_name: 'Unknown', registration_status: 'stolen', flags: ['stolen', 'fled_scene'], vin: 'LSC4ZNT44UNK0' },
    { id: 5, vehicle_id: 'VEH005', plate: 'NREG 77', model: 'Faggio', color: 'White', owner_name: 'Tony Rizzo', registration_status: 'unregistered', flags: [], vin: 'LSC5FGG77NREG' },
    { id: 6, vehicle_id: 'VEH006', plate: 'SUSP 11', model: 'Baller LE', color: 'Silver', owner_name: 'Derek Haines', registration_status: 'suspended', flags: ['wanted'], vin: 'LSC6BLL11SUSP' },
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
  let loading = $state(false);
  let errorMessage = $state('');

  let useMock = $derived(isEnvBrowser());
  let results = $derived(
    useMock && searchQuery.trim()
      ? MOCK_RESULTS.filter((v) => {
          const q = searchQuery.toLowerCase();
          return (
            v.plate.toLowerCase().includes(q) ||
            v.model.toLowerCase().includes(q) ||
            (v.vin || '').toLowerCase().includes(q) ||
            (v.owner_name || '').toLowerCase().includes(q)
          );
        })
      : dataStore.vehicleSearchResults || [],
  );
  let vehicle = $derived(useMock ? dataStore.selectedVehicle || null : dataStore.selectedVehicle || null);
  let impounds = $derived(useMock ? (dataStore.vehicleImpounds?.length ? dataStore.vehicleImpounds : []) : dataStore.vehicleImpounds || []);
  let isDetail = $derived(!!vehicle);
  let activeImpound = $derived(impounds.find((i) => i.status === 'impounded') || null);
  let pastImpounds = $derived(impounds.filter((i) => i.status !== 'impounded'));
  let recentlyViewed = $derived(dataStore.recentVehicles || []);

  function formatViewedAgo(ts) {
    if (ts == null || Number.isNaN(Number(ts))) return '';
    const s = Math.floor((Date.now() - Number(ts)) / 1000);
    if (s < 45) return 'Just now';
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    if (s < 604800) return `${Math.floor(s / 86400)}d ago`;
    return '';
  }

  function plateInitials(plate) {
    const t = String(plate || '')
      .replace(/\s+/g, '')
      .toUpperCase();
    if (!t) return '?';
    return t.slice(0, 2);
  }

  function normalizeFlagList(raw) {
    if (!raw) return [];
    if (Array.isArray(raw)) return raw.filter(Boolean);
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed.filter(Boolean) : [];
      } catch {
        return [];
      }
    }
    return [];
  }

  function vehicleFlagTone(flag) {
    if (['stolen', 'fled_scene', 'evidence_hold'].includes(flag)) return 'danger';
    if (['wanted', 'impounded'].includes(flag)) return 'warning';
    if (['bolo'].includes(flag)) return 'info';
    return 'neutral';
  }

  function scheduleSearch() {
    if (debounceTimer) clearTimeout(debounceTimer);
    if (!searchQuery.trim()) {
      if (!useMock) dataStore.clearVehicleSearch();
      errorMessage = '';
      return;
    }
    if (useMock) return;
    debounceTimer = setTimeout(async () => {
      loading = true;
      errorMessage = '';
      const response = await dataStore.searchVehicles(searchQuery.trim());
      if (!response?.ok) {
        errorMessage = response?.error || 'Unable to search vehicles.';
      }
      loading = false;
    }, 300);
  }

  function clearLookupSearch() {
    searchQuery = '';
    errorMessage = '';
    if (!useMock) dataStore.clearVehicleSearch();
  }

  async function openDetail(row) {
    loading = true;
    errorMessage = '';
    impoundFormOpen = false;
    resetImpoundForm();
    if (useMock) {
      const base = MOCK_RESULTS.find((r) => r.id === row.id) || row;
      dataStore.selectedVehicle = {
        ...MOCK_VEHICLE,
        id: base.id,
        vehicle_id: base.vehicle_id || MOCK_VEHICLE.vehicle_id,
        plate: base.plate,
        model: base.model,
        color: base.color,
        owner_name: base.owner_name,
        registration_status: base.registration_status,
        flags: base.flags || [],
        vin: base.vin || MOCK_VEHICLE.vin,
        owner_citizen_id: base.owner_citizen_id || MOCK_VEHICLE.owner_citizen_id,
      };
      dataStore.vehicleImpounds = [...MOCK_IMPOUNDS];
      dataStore.rememberRecentVehicle(dataStore.selectedVehicle);
      loading = false;
      return;
    }
    const response = await dataStore.getVehicle(row.id);
    if (!response?.ok) {
      errorMessage = response?.error || 'Unable to load vehicle.';
    }
    loading = false;
  }

  async function openRecent(entry) {
    await openDetail({ id: entry.id, plate: entry.plate, model: entry.model });
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

  function navigateToCitizen() {
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
      dataStore.vehicleImpounds = [
        {
          id: Date.now(),
          status: 'impounded',
          reason: impoundReason,
          lot_location: impoundLot,
          fee: impoundFee,
          hold_until: holdUntil.toISOString().slice(0, 16).replace('T', ' '),
          impound_date: now.toISOString().slice(0, 16).replace('T', ' '),
          release_date: null,
          officer_name: `${mdtStore.officer.rank} ${mdtStore.officer.lastName}`,
        },
        ...dataStore.vehicleImpounds,
      ];
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
      dataStore.vehicleImpounds = dataStore.vehicleImpounds.map((i) =>
        i.id === impoundId ? { ...i, status: 'released', release_date: new Date().toISOString().slice(0, 16).replace('T', ' ') } : i,
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
    return FLAG_DEFS.find((f) => f.key === key) || { key, label: key, color: '#6b7280' };
  }

  function formatDate(dateStr) {
    if (!dateStr) return '\u2014';
    return dateStr;
  }

  function formatCurrency(val) {
    if (val == null) return '\u2014';
    return `$${Number(val).toLocaleString()}`;
  }

  onMount(() => {
    if (!useMock) {
      dataStore.clearVehicleSearch();
    }
  });
</script>

<div class="cp-page">
  {#if !isDetail}
    <section class="cp-lookup" aria-label="Vehicle registry search">
      <div class="cp-lookup-toolbar">
        <div class="cp-lookup-heading">
          <div class="cp-eyebrow">
            <Car size={13} strokeWidth={2} />
            <span>Registry</span>
          </div>
          <h2 class="cp-lookup-h1">Vehicles</h2>
          <p class="cp-lookup-desc">Search by plate, model, owner name, or VIN.</p>
        </div>
        <div class="cp-lookup-searchcol">
          <label class="cp-lookup-field">
            <span class="cp-lookup-field-ico" aria-hidden="true"><Search size={15} strokeWidth={2} /></span>
            <input
              bind:value={searchQuery}
              type="text"
              placeholder="Start typing…"
              autocomplete="off"
              oninput={scheduleSearch}
            />
            {#if searchQuery.trim()}
              <button type="button" class="cp-lookup-clear" onclick={clearLookupSearch} aria-label="Clear search">
                <X size={14} strokeWidth={2} />
              </button>
            {/if}
          </label>
          <div class="cp-lookup-hints">
            <span class="cp-lookup-hint"><Hash size={11} strokeWidth={2} /> VIN</span>
            <span class="cp-lookup-hint"><Tag size={11} strokeWidth={2} /> Plate</span>
            <span class="cp-lookup-hint"><Car size={11} strokeWidth={2} /> Model</span>
            <span class="cp-lookup-hint"><User size={11} strokeWidth={2} /> Owner</span>
          </div>
        </div>
      </div>

      {#if errorMessage}
        <div class="cp-error cp-error-tight">{errorMessage}</div>
      {/if}

      <div class="cp-lookup-split">
        <aside class="cp-lookup-aside" aria-label="Recently opened records">
          <div class="cp-aside-cap">
            <Clock size={12} strokeWidth={2} />
            <span>Recent</span>
            {#if recentlyViewed.length}
              <span class="cp-aside-count">{recentlyViewed.length}</span>
            {/if}
          </div>
          {#if recentlyViewed.length > 0}
            <ul class="cp-aside-list">
              {#each recentlyViewed as entry (entry.id ?? entry.vehicle_id ?? entry.plate)}
                {@const rfRecent = normalizeFlagList(entry.flags)}
                <li>
                  <button type="button" class="cp-aside-row" onclick={() => openRecent(entry)}>
                    <div class="cp-aside-av mono" aria-hidden="true">
                      {plateInitials(entry.plate)}
                    </div>
                    <div class="cp-aside-mid">
                      <span class="cp-aside-name mono">{entry.plate}</span>
                      <span class="cp-aside-sub">{entry.model || '—'}</span>
                      <span class="cp-aside-meta">
                        {#if entry.viewedAt}{formatViewedAgo(entry.viewedAt)}{/if}
                        {#if entry.viewedAt && entry.owner_name}<span class="cp-aside-dot"></span>{/if}
                        {#if entry.owner_name}{entry.owner_name}{/if}
                      </span>
                      {#if rfRecent.length}
                        <div class="cp-flag-strip">
                          {#each rfRecent.slice(0, 2) as flag (flag)}
                            <span
                              class="cp-flag-tag"
                              class:danger={vehicleFlagTone(flag) === 'danger'}
                              class:warning={vehicleFlagTone(flag) === 'warning'}
                              class:info={vehicleFlagTone(flag) === 'info'}
                            >
                              {FLAG_DEFS.find((d) => d.key === flag)?.label || flag}
                            </span>
                          {/each}
                          {#if rfRecent.length > 2}
                            <span class="cp-flag-more">+{rfRecent.length - 2}</span>
                          {/if}
                        </div>
                      {/if}
                    </div>
                    <span class="cp-aside-chev" aria-hidden="true"><ChevronRight size={14} strokeWidth={2} /></span>
                  </button>
                </li>
              {/each}
            </ul>
          {:else}
            <p class="cp-aside-empty">Open a record to pin it here for the session.</p>
          {/if}
        </aside>

        <div class="cp-lookup-panel">
          {#if loading}
            <div class="cp-lookup-panel-inner cp-lookup-state">
              <span class="cp-lookup-spin"><RefreshCw size={18} strokeWidth={2} /></span>
              <span>Searching…</span>
            </div>
          {:else if results.length > 0}
            <div class="cp-lookup-panel-head">
              <span class="cp-lookup-panel-title">{results.length} result{results.length === 1 ? '' : 's'}</span>
              {#if searchQuery.trim()}
                <span class="cp-lookup-panel-q mono">{searchQuery.trim()}</span>
              {/if}
            </div>
            <div class="cp-lookup-sheet" role="region" aria-label="Search results">
              <div class="cp-lookup-tr cp-lookup-tr-head vp-tr-vehicle" aria-hidden="true">
                <span class="cp-lookup-td cp-td-subject">Vehicle</span>
                <span class="cp-lookup-td cp-td-owner">Owner</span>
                <span class="cp-lookup-td cp-td-reg">Registration</span>
                <span class="cp-lookup-td cp-td-flags">Flags</span>
                <span class="cp-lookup-td cp-td-go"></span>
              </div>
              {#each results as row (row.id || row.vehicle_id)}
                {@const rf = normalizeFlagList(row.flags)}
                <button type="button" class="cp-lookup-tr cp-lookup-tr-data vp-tr-vehicle" onclick={() => openDetail(row)}>
                  <span class="cp-lookup-td cp-td-subject">
                    <span class="cp-lookup-av mono" aria-hidden="true">{plateInitials(row.plate)}</span>
                    <span class="cp-lookup-subject-text">
                      <span class="cp-lookup-legal mono">{row.plate}</span>
                      <span class="cp-lookup-subline">
                        <Car size={10} strokeWidth={2} />
                        {row.model || '—'}
                        {#if row.color}<span class="cp-aside-dot"></span>{row.color}{/if}
                      </span>
                    </span>
                  </span>
                  <span class="cp-lookup-td cp-td-owner">{row.owner_name || '—'}</span>
                  <span class="cp-lookup-td cp-td-reg">
                    <span class="reg-badge-sm" style="--reg-color: {getRegColor(row.registration_status)}">{row.registration_status || '—'}</span>
                  </span>
                  <span class="cp-lookup-td cp-td-flags">
                    {#if rf.length}
                      <span class="cp-flag-strip">
                        {#each rf.slice(0, 3) as flag (flag)}
                          <span
                            class="cp-flag-tag"
                            class:danger={vehicleFlagTone(flag) === 'danger'}
                            class:warning={vehicleFlagTone(flag) === 'warning'}
                            class:info={vehicleFlagTone(flag) === 'info'}
                          >
                            {FLAG_DEFS.find((d) => d.key === flag)?.label || flag}
                          </span>
                        {/each}
                        {#if rf.length > 3}
                          <span class="cp-flag-more">+{rf.length - 3}</span>
                        {/if}
                      </span>
                    {:else}
                      <span class="cp-flag-clear">Clear</span>
                    {/if}
                  </span>
                  <span class="cp-lookup-td cp-td-go" aria-hidden="true"><ChevronRight size={15} strokeWidth={2} /></span>
                </button>
              {/each}
            </div>
          {:else if searchQuery.trim()}
            <div class="cp-lookup-panel-inner cp-lookup-state cp-lookup-state-muted">
              <Search size={20} strokeWidth={2} />
              <span>No records match <span class="mono">{searchQuery.trim()}</span>.</span>
            </div>
          {:else}
            <div class="cp-lookup-panel-inner cp-lookup-state cp-lookup-state-muted">
              <Car size={20} strokeWidth={2} />
              <span>Results appear here.</span>
            </div>
          {/if}
        </div>
      </div>
    </section>
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
                <button class="cid-link font-mono" onclick={navigateToCitizen}>{vehicle.owner_citizen_id}</button>
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
            <button class="btn-impound" onclick={() => (impoundFormOpen = true)}>
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
                <button
                  class="btn-cancel"
                  onclick={() => {
                    impoundFormOpen = false;
                    resetImpoundForm();
                  }}>Cancel</button>
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
  .cp-page {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    color: var(--mdt-text);
    flex: 1;
    min-height: 0;
    width: 100%;
    container-type: inline-size;
    container-name: cp-page;
  }

  .cp-eyebrow {
    display: inline-flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    margin-bottom: calc(6px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .cp-lookup {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
  }

  .cp-lookup-toolbar {
    display: grid;
    grid-template-columns: 1fr minmax(min(100%, calc(280px * var(--mdt-scale))), 1fr);
    gap: calc(12px * var(--mdt-scale));
    align-items: end;
    padding-bottom: calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .cp-lookup-heading .cp-eyebrow {
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  .cp-lookup-h1 {
    margin: 0;
    font-family: 'Unbounded', 'Outfit', system-ui, sans-serif;
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.02em;
    line-height: 1.2;
    color: var(--mdt-text);
  }

  .cp-lookup-desc {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.4;
    color: var(--mdt-text-muted);
    max-width: 52ch;
  }

  .cp-lookup-searchcol {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    min-width: 0;
  }

  .cp-lookup-field {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
  }

  .cp-lookup-field:focus-within {
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    box-shadow: 0 0 0 1px color-mix(in srgb, var(--mdt-accent) 18%, transparent);
  }

  .cp-lookup-field-ico {
    display: flex;
    flex-shrink: 0;
    opacity: 0.85;
  }

  .cp-lookup-field input {
    flex: 1;
    min-width: 0;
    border: 0;
    outline: none;
    background: transparent;
    color: var(--mdt-text);
    font: inherit;
    font-size: calc(12px * var(--mdt-scale));
  }

  .cp-lookup-clear {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    padding: 0;
    border: 0;
    border-radius: var(--mdt-radius-sm);
    background: color-mix(in srgb, var(--mdt-surface-3) 80%, transparent);
    color: var(--mdt-text-muted);
    cursor: pointer;
  }

  .cp-lookup-clear:hover {
    color: var(--mdt-text);
    background: var(--mdt-surface-3);
  }

  .cp-lookup-hints {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.02em;
  }

  .cp-lookup-hint {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    opacity: 0.92;
  }

  .cp-lookup-hint :global(svg) {
    flex-shrink: 0;
    opacity: 0.75;
  }

  .cp-lookup-split {
    display: grid;
    grid-template-columns: minmax(calc(200px * var(--mdt-scale)), calc(260px * var(--mdt-scale))) minmax(0, 1fr);
    gap: calc(10px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
    align-items: stretch;
  }

  .cp-lookup-aside {
    display: flex;
    flex-direction: column;
    min-width: 0;
    min-height: 0;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface);
    overflow: hidden;
    box-shadow: inset 2px 0 0 color-mix(in srgb, var(--mdt-accent) 40%, transparent);
  }

  .cp-aside-cap {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .cp-aside-cap :global(svg) {
    flex-shrink: 0;
    opacity: 0.85;
  }

  .cp-aside-count {
    margin-left: auto;
    font-variant-numeric: tabular-nums;
    font-family: 'Share Tech Mono', ui-monospace, monospace;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .cp-aside-list {
    list-style: none;
    margin: 0;
    padding: calc(4px * var(--mdt-scale));
    overflow-y: auto;
    flex: 1;
    min-height: 0;
  }

  .cp-aside-row {
    display: grid;
    grid-template-columns: auto 1fr auto;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
    width: 100%;
    padding: calc(7px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    margin: 0 0 calc(2px * var(--mdt-scale));
    border: 1px solid transparent;
    border-radius: var(--mdt-radius-sm);
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: pointer;
    transition:
      background 0.12s ease,
      border-color 0.12s ease;
  }

  .cp-aside-row:hover {
    background: var(--mdt-surface-2);
    border-color: var(--mdt-border);
  }

  .cp-aside-av {
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    overflow: hidden;
    display: grid;
    place-items: center;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .cp-aside-mid {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .cp-aside-name {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    line-height: 1.2;
  }

  .cp-aside-sub {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-weight: 500;
  }

  .cp-aside-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
  }

  .cp-aside-dot {
    width: 2px;
    height: 2px;
    border-radius: 50%;
    background: var(--mdt-text-muted);
    opacity: 0.65;
    flex-shrink: 0;
  }

  .cp-aside-chev {
    display: flex;
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    opacity: 0.55;
  }

  .cp-aside-row:hover .cp-aside-chev {
    opacity: 0.95;
    color: var(--mdt-accent);
  }

  .cp-aside-empty {
    margin: 0;
    padding: calc(12px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.45;
    color: var(--mdt-text-muted);
  }

  .cp-lookup-panel {
    display: flex;
    flex-direction: column;
    min-width: 0;
    min-height: 0;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface);
    overflow: hidden;
    flex: 1;
  }

  .cp-lookup-panel-head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    flex-shrink: 0;
  }

  .cp-lookup-panel-title {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .cp-lookup-panel-q {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .cp-lookup-panel-inner {
    flex: 1;
    min-height: calc(120px * var(--mdt-scale));
    min-width: 0;
  }

  .cp-lookup-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(24px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    text-align: center;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text);
  }

  .cp-lookup-state-muted {
    color: var(--mdt-text-muted);
  }

  .cp-lookup-state-muted :global(svg) {
    opacity: 0.45;
  }

  .cp-lookup-spin {
    display: inline-flex;
    animation: cp-rot 0.75s linear infinite;
  }

  .cp-lookup-sheet {
    flex: 1;
    min-height: 0;
    overflow: auto;
    display: flex;
    flex-direction: column;
  }

  .cp-lookup-tr {
    display: grid;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    font-size: calc(11px * var(--mdt-scale));
  }

  .cp-lookup-tr.vp-tr-vehicle {
    grid-template-columns: minmax(0, 1.45fr) minmax(0, 1fr) minmax(0, 0.78fr) minmax(0, 1fr) calc(28px * var(--mdt-scale));
  }

  .cp-lookup-tr:last-child {
    border-bottom: 0;
  }

  .cp-lookup-tr-head {
    position: sticky;
    top: 0;
    z-index: 1;
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    border-bottom: 1px solid var(--mdt-border);
  }

  .cp-lookup-tr-data {
    width: 100%;
    margin: 0;
    border: 0;
    border-radius: 0;
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: pointer;
    transition: background 0.12s ease;
  }

  .cp-lookup-tr-data:hover {
    background: color-mix(in srgb, var(--mdt-surface-3) 55%, var(--mdt-surface));
  }

  .cp-lookup-td {
    min-width: 0;
  }

  .cp-td-subject {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .cp-lookup-av {
    width: calc(36px * var(--mdt-scale));
    height: calc(36px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    overflow: hidden;
    display: grid;
    place-items: center;
    flex-shrink: 0;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
  }

  .cp-lookup-subject-text {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .cp-lookup-legal {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    line-height: 1.2;
  }

  .cp-lookup-subline {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .cp-lookup-subline :global(svg) {
    flex-shrink: 0;
    opacity: 0.7;
  }

  .cp-td-owner {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    word-break: break-word;
    line-height: 1.35;
  }

  .cp-td-reg {
    display: flex;
    align-items: center;
  }

  .reg-badge-sm {
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

  .cp-td-go {
    display: flex;
    justify-content: flex-end;
    color: var(--mdt-text-muted);
    opacity: 0.5;
  }

  .cp-lookup-tr-data:hover .cp-td-go {
    opacity: 1;
    color: var(--mdt-accent);
  }

  .cp-flag-strip {
    display: flex;
    flex-wrap: wrap;
    gap: calc(4px * var(--mdt-scale));
    align-items: center;
  }

  .cp-flag-tag {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    border-left-width: 2px;
    border-left-color: var(--mdt-border-2);
    background: var(--mdt-surface-2);
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.02em;
    color: var(--mdt-text-dim);
    line-height: 1.25;
    max-width: 100%;
  }

  .cp-flag-tag.danger {
    border-left-color: #dc2626;
    color: color-mix(in srgb, #fecaca 55%, var(--mdt-text-dim));
  }

  .cp-flag-tag.warning {
    border-left-color: #d97706;
    color: color-mix(in srgb, #fde68a 45%, var(--mdt-text-dim));
  }

  .cp-flag-tag.info {
    border-left-color: #2563eb;
    color: color-mix(in srgb, #bfdbfe 40%, var(--mdt-text-dim));
  }

  .cp-flag-more {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    padding: calc(2px * var(--mdt-scale)) calc(5px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px dashed var(--mdt-border);
    color: var(--mdt-text-muted);
    font-variant-numeric: tabular-nums;
  }

  .cp-flag-clear {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-success);
    opacity: 0.85;
  }

  @container cp-page (max-width: 720px) {
    .cp-lookup-toolbar {
      grid-template-columns: 1fr;
      align-items: stretch;
    }

    .cp-lookup-split {
      grid-template-columns: 1fr;
    }

    .cp-lookup-aside {
      max-height: min(36vh, 260px);
      order: 2;
    }

    .cp-lookup-panel {
      order: 1;
      min-height: min(44vh, 320px);
    }
  }

  @container cp-page (max-width: 560px) {
    .cp-lookup-sheet {
      overflow-x: auto;
    }

    .cp-lookup-tr.vp-tr-vehicle {
      min-width: calc(520px * var(--mdt-scale));
    }
  }

  .cp-error {
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid color-mix(in srgb, var(--mdt-error) 45%, transparent);
    background: color-mix(in srgb, var(--mdt-error) 12%, var(--mdt-surface));
    color: var(--mdt-error);
    font-size: calc(13px * var(--mdt-scale));
  }

  .cp-error-tight {
    margin-top: calc(2px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
  }

  @keyframes cp-rot {
    to {
      transform: rotate(360deg);
    }
  }

  .mono {
    font-family: 'Share Tech Mono', 'Courier New', monospace;
  }

  .detail-mode {
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
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
    transition:
      background 0.12s ease,
      color 0.12s ease,
      transform 0.1s ease;
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
    transition:
      opacity 0.15s ease,
      transform 0.1s ease;
  }

  .btn-release svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .btn-release:hover {
    opacity: 0.9;
  }

  .btn-release:active {
    transform: scale(0.96);
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
    transition:
      background 0.12s ease,
      color 0.12s ease,
      transform 0.1s ease;
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
    transform: scale(0.96);
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
    transition:
      opacity 0.15s ease,
      transform 0.1s ease;
  }

  .btn-confirm:hover {
    opacity: 0.9;
  }

  .btn-confirm:active {
    transform: scale(0.96);
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
    transition:
      background 0.12s ease,
      color 0.12s ease,
      transform 0.1s ease;
  }

  .btn-cancel:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .btn-cancel:active {
    transform: scale(0.96);
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

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(6px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>
