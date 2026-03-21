<script>
  import { onMount } from 'svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const TYPE_CONFIG = {
    person: { label: 'Person', color: '#3b82f6', border: '#3b82f6' },
    vehicle: { label: 'Vehicle', color: '#f59e0b', border: '#f59e0b' },
    weapon: { label: 'Weapon', color: '#ef4444', border: '#ef4444' },
  };

  const STATUS_CONFIG = {
    active: { label: 'Active', color: 'var(--mdt-success)' },
    cancelled: { label: 'Cancelled', color: 'var(--mdt-text-muted)' },
    resolved: { label: 'Resolved', color: 'var(--mdt-accent)' },
  };

  const MOCK_BOLOS = [
    { id: 1, type: 'person', title: 'Armed Suspect — Davis Ave Shooting', description: 'Male, approximately 6\'1, wearing a black hoodie and dark jeans. Last seen fleeing south on Davis Ave on foot. Suspect is considered armed and dangerous — approach with caution.', citizen_id: 'CIT-20260102-1842', plate: null, vehicle_description: null, weapon_description: null, photo_url: '', status: 'active', issued_by: 'Det. Nakamura', department: 'LSPD', report_id: 'RPT-20260315-0042', created_at: '2026-03-20T14:30:00Z', officer_first: 'Kenji', officer_last: 'Nakamura' },
    { id: 2, type: 'vehicle', title: 'Stolen Sultan RS — Fleeca Robbery Getaway', description: 'Red Karin Sultan RS with aftermarket spoiler and tinted windows. Vehicle was used as getaway in the Fleeca Bank robbery on Route 68.', citizen_id: null, plate: '59CKN843', vehicle_description: 'Red Karin Sultan RS, aftermarket spoiler, tinted windows, front bumper damage', weapon_description: null, photo_url: '', status: 'active', issued_by: 'Ofc. Rivera', department: 'LSPD', report_id: 'RPT-20260314-0039', created_at: '2026-03-19T09:15:00Z', officer_first: 'Sofia', officer_last: 'Rivera' },
    { id: 3, type: 'weapon', title: 'Missing Service Weapon — Glock 19', description: 'Standard-issue Glock 19 reported missing from evidence locker. Serial number: GLK-2024-08812. May have been stolen during evidence transfer.', citizen_id: null, plate: null, vehicle_description: null, weapon_description: 'Glock 19 9mm, Serial: GLK-2024-08812, black finish, standard sights', photo_url: '', status: 'active', issued_by: 'Sgt. Delgado', department: 'LSPD', report_id: null, created_at: '2026-03-18T22:45:00Z', officer_first: 'Miguel', officer_last: 'Delgado' },
    { id: 4, type: 'person', title: 'Suspect in Multiple Carjackings — Mirror Park', description: 'Female suspect, mid-20s, brown hair, tattoo on right forearm. Linked to three carjackings in Mirror Park area over the past week.', citizen_id: null, plate: null, vehicle_description: null, weapon_description: null, photo_url: '', status: 'resolved', issued_by: 'Ofc. Chen', department: 'LSPD', report_id: null, created_at: '2026-03-16T11:00:00Z', officer_first: 'Wei', officer_last: 'Chen' },
    { id: 5, type: 'vehicle', title: 'White Burrito Van — Suspicious Activity', description: 'White Declasse Burrito van with no plates observed circling Maze Bank Tower. Possibly conducting surveillance for planned robbery.', citizen_id: null, plate: 'NO PLATE', vehicle_description: 'White Declasse Burrito, no visible plates, dented rear panel', weapon_description: null, photo_url: '', status: 'cancelled', issued_by: 'Ofc. Park', department: 'BCSO', report_id: null, created_at: '2026-03-14T16:20:00Z', officer_first: 'Jisoo', officer_last: 'Park' },
  ];

  let mode = $state('list');
  let activeFilter = $state('active');
  let searchQuery = $state('');
  let loading = $state(false);
  let saving = $state(false);
  let mounted = $state(false);

  let createType = $state('person');
  let createTitle = $state('');
  let createDescription = $state('');
  let createCitizenId = $state('');
  let createPlate = $state('');
  let createVehicleDesc = $state('');
  let createWeaponDesc = $state('');
  let createPhotoUrl = $state('');
  let createReportId = $state('');

  let bolos = $derived(dataStore.bolosList || []);
  let officer = $derived(mdtStore.officer);

  let filteredBolos = $derived(() => {
    if (!searchQuery.trim()) return bolos;
    const q = searchQuery.toLowerCase();
    return bolos.filter(b =>
      (b.title && b.title.toLowerCase().includes(q)) ||
      (b.description && b.description.toLowerCase().includes(q)) ||
      (b.plate && b.plate.toLowerCase().includes(q)) ||
      (b.issued_by && b.issued_by.toLowerCase().includes(q))
    );
  });

  function getTypeConfig(type) {
    return TYPE_CONFIG[type] || TYPE_CONFIG.person;
  }

  function getStatusConfig(status) {
    return STATUS_CONFIG[status] || STATUS_CONFIG.active;
  }

  function formatDate(dateStr) {
    if (!dateStr) return '\u2014';
    try {
      const d = new Date(dateStr);
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    } catch {
      return dateStr;
    }
  }

  async function loadBolos() {
    loading = true;
    if (isEnvBrowser()) {
      if (activeFilter === 'active') {
        dataStore.bolosList = MOCK_BOLOS.filter(b => b.status === 'active');
      } else {
        dataStore.bolosList = [...MOCK_BOLOS];
      }
    } else {
      await dataStore.fetchBolos(activeFilter);
    }
    loading = false;
  }

  function switchFilter(filter) {
    activeFilter = filter;
    loadBolos();
  }

  function openCreate() {
    createType = 'person';
    createTitle = '';
    createDescription = '';
    createCitizenId = '';
    createPlate = '';
    createVehicleDesc = '';
    createWeaponDesc = '';
    createPhotoUrl = '';
    createReportId = '';
    mode = 'create';
  }

  function cancelCreate() {
    mode = 'list';
  }

  async function handleCreate() {
    if (!createTitle.trim()) return;
    saving = true;
    const resp = await dataStore.createBolo({
      type: createType,
      title: createTitle.trim(),
      description: createDescription.trim(),
      citizenId: createType === 'person' ? createCitizenId.trim() : null,
      plate: createType === 'vehicle' ? createPlate.trim() : null,
      vehicleDescription: createType === 'vehicle' ? createVehicleDesc.trim() : null,
      weaponDescription: createType === 'weapon' ? createWeaponDesc.trim() : null,
      photoUrl: createPhotoUrl.trim() || null,
      reportId: createReportId.trim() || null,
    });
    if (isEnvBrowser()) {
      const newBolo = {
        id: Date.now(),
        type: createType,
        title: createTitle.trim(),
        description: createDescription.trim(),
        citizen_id: createType === 'person' ? createCitizenId.trim() : null,
        plate: createType === 'vehicle' ? createPlate.trim() : null,
        vehicle_description: createType === 'vehicle' ? createVehicleDesc.trim() : null,
        weapon_description: createType === 'weapon' ? createWeaponDesc.trim() : null,
        photo_url: createPhotoUrl.trim(),
        status: 'active',
        issued_by: `${officer.firstName} ${officer.lastName}`,
        department: officer.departmentShort || 'LSPD',
        report_id: createReportId.trim() || null,
        created_at: new Date().toISOString(),
        officer_first: officer.firstName,
        officer_last: officer.lastName,
      };
      dataStore.bolosList = [newBolo, ...bolos];
    }
    saving = false;
    mode = 'list';
    if (!isEnvBrowser()) {
      await loadBolos();
    }
  }

  async function handleStatusChange(boloId, newStatus) {
    saving = true;
    await dataStore.updateBoloStatus(boloId, newStatus);
    if (isEnvBrowser()) {
      dataStore.bolosList = bolos.map(b =>
        b.id === boloId ? { ...b, status: newStatus } : b
      );
      if (activeFilter === 'active') {
        dataStore.bolosList = dataStore.bolosList.filter(b => b.status === 'active');
      }
    } else {
      await loadBolos();
    }
    saving = false;
  }

  onMount(() => {
    mounted = true;
    loadBolos();
  });
</script>

<div class="bolos-page" class:mounted>
  {#if mode === 'list'}
    <div class="list-mode">
      <div class="page-header">
        <div class="header-left">
          <h2 class="page-title">BOLOs</h2>
          <p class="page-subtitle">Be On the Lookout — active alerts and bulletins</p>
        </div>
        <button class="btn-new" onclick={openCreate}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
          </svg>
          <span>New BOLO</span>
        </button>
      </div>

      <div class="controls-bar">
        <div class="filter-bar">
          {#each [['active', 'Active'], ['all', 'All']] as [key, label]}
            <button
              class="filter-tab"
              class:active={activeFilter === key}
              onclick={() => switchFilter(key)}
            >{label}</button>
          {/each}
        </div>
        <div class="search-wrapper">
          <svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
          </svg>
          <input
            type="text"
            class="search-input"
            placeholder="Search BOLOs..."
            bind:value={searchQuery}
          />
        </div>
      </div>

      {#if loading}
        <div class="loading-state">
          <div class="spinner"></div>
          <p class="loading-text">Loading BOLOs...</p>
        </div>
      {:else if filteredBolos().length > 0}
        <div class="cards-grid">
          {#each filteredBolos() as bolo, i (bolo.id)}
            {@const typeConf = getTypeConfig(bolo.type)}
            {@const statusConf = getStatusConfig(bolo.status)}
            {@const isActive = bolo.status === 'active'}
            <div
              class="bolo-card"
              class:dimmed={!isActive}
              class:glow={isActive}
              style="
                --card-border-color: {typeConf.border};
                --card-delay: {i * 0.04}s;
              "
            >
              <div class="card-left-border"></div>
              <div class="card-content">
                <div class="card-top-row">
                  <div class="card-badges">
                    <span class="type-badge" style="--type-color: {typeConf.color}">{typeConf.label}</span>
                    <span class="status-badge" style="--status-color: {statusConf.color}">{statusConf.label}</span>
                  </div>
                  <span class="card-date font-mono">{formatDate(bolo.created_at)}</span>
                </div>

                <h3 class="card-title">{bolo.title}</h3>
                <p class="card-desc">{bolo.description || '\u2014'}</p>

                {#if bolo.type === 'vehicle' && bolo.plate}
                  <div class="card-plate">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                      <rect x="1" y="6" width="22" height="12" rx="2" ry="2" />
                      <path d="M1 10h22" />
                    </svg>
                    <span class="font-mono">{bolo.plate}</span>
                  </div>
                {/if}

                <div class="card-meta">
                  <div class="meta-item">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                      <circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" />
                    </svg>
                    <span>{bolo.officer_first ? `${bolo.officer_first} ${bolo.officer_last}` : (typeof bolo.issued_by === 'string' ? bolo.issued_by : '\u2014')}</span>
                  </div>
                  {#if bolo.department}
                    <div class="meta-item">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <path d="M3 21h18M9 8h1M9 12h1M9 16h1M14 8h1M14 12h1M14 16h1M5 21V5a2 2 0 012-2h10a2 2 0 012 2v16" />
                      </svg>
                      <span>{bolo.department}</span>
                    </div>
                  {/if}
                  {#if bolo.report_id}
                    <div class="meta-item meta-report">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" />
                      </svg>
                      <span class="font-mono">{bolo.report_id}</span>
                    </div>
                  {/if}
                </div>

                {#if isActive}
                  <div class="card-actions">
                    <button
                      class="action-btn resolve-btn"
                      onclick={() => handleStatusChange(bolo.id, 'resolved')}
                      disabled={saving}
                    >
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="20 6 9 17 4 12" />
                      </svg>
                      <span>Resolve</span>
                    </button>
                    <button
                      class="action-btn cancel-btn"
                      onclick={() => handleStatusChange(bolo.id, 'cancelled')}
                      disabled={saving}
                    >
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M18 6L6 18M6 6l12 12" />
                      </svg>
                      <span>Cancel</span>
                    </button>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty-state">
          <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
            <line x1="12" y1="9" x2="12" y2="13" />
            <line x1="12" y1="17" x2="12.01" y2="17" />
          </svg>
          <p class="empty-text">No BOLOs found</p>
          <p class="empty-sub">{searchQuery.trim() ? 'Try adjusting your search query' : 'Create a new BOLO to get started'}</p>
        </div>
      {/if}
    </div>

  {:else if mode === 'create'}
    <div class="create-mode">
      <button class="back-btn" onclick={cancelCreate}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to BOLOs</span>
      </button>

      <h2 class="section-title">Create BOLO</h2>

      <div class="form-card">
        <div class="form-group">
          <label class="form-label">Type</label>
          <div class="type-selector">
            {#each [['person', 'Person'], ['vehicle', 'Vehicle'], ['weapon', 'Weapon']] as [key, label]}
              {@const conf = getTypeConfig(key)}
              <button
                class="type-option"
                class:active={createType === key}
                style="--type-opt-color: {conf.color}"
                onclick={() => { createType = key; }}
              >
                {#if key === 'person'}
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" />
                  </svg>
                {:else if key === 'vehicle'}
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M5 17h14M5 17a2 2 0 01-2-2V9a2 2 0 012-2h1l2-3h8l2 3h1a2 2 0 012 2v6a2 2 0 01-2 2M5 17v2m14-2v2" />
                  </svg>
                {:else}
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14 22H2l4-12 3.5 3.5L14 2l4.5 11.5L22 10l-4 12h-4z" />
                  </svg>
                {/if}
                <span>{label}</span>
              </button>
            {/each}
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Title <span class="required">*</span></label>
          <input
            type="text"
            class="form-input"
            placeholder="Brief descriptive title for this BOLO..."
            bind:value={createTitle}
          />
        </div>

        <div class="form-group">
          <label class="form-label">Description</label>
          <textarea
            class="form-textarea"
            placeholder="Detailed description — include physical characteristics, last known location, circumstances..."
            bind:value={createDescription}
            rows="5"
          ></textarea>
        </div>

        {#if createType === 'person'}
          <div class="form-row">
            <div class="form-group form-group-half">
              <label class="form-label">Citizen ID</label>
              <input
                type="text"
                class="form-input font-mono"
                placeholder="CIT-00000000-0000"
                bind:value={createCitizenId}
              />
            </div>
            <div class="form-group form-group-half">
              <label class="form-label">Photo URL</label>
              <input
                type="text"
                class="form-input"
                placeholder="https://example.com/photo.png"
                bind:value={createPhotoUrl}
              />
            </div>
          </div>
        {:else if createType === 'vehicle'}
          <div class="form-row">
            <div class="form-group form-group-half">
              <label class="form-label">License Plate</label>
              <input
                type="text"
                class="form-input font-mono"
                placeholder="e.g. 59CKN843"
                bind:value={createPlate}
              />
            </div>
            <div class="form-group form-group-half">
              <label class="form-label">Photo URL</label>
              <input
                type="text"
                class="form-input"
                placeholder="https://example.com/photo.png"
                bind:value={createPhotoUrl}
              />
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">Vehicle Description</label>
            <textarea
              class="form-textarea form-textarea-sm"
              placeholder="Make, model, color, modifications, damage..."
              bind:value={createVehicleDesc}
              rows="3"
            ></textarea>
          </div>
        {:else if createType === 'weapon'}
          <div class="form-group">
            <label class="form-label">Weapon Description</label>
            <textarea
              class="form-textarea form-textarea-sm"
              placeholder="Weapon type, serial number, distinguishing marks..."
              bind:value={createWeaponDesc}
              rows="3"
            ></textarea>
          </div>
          <div class="form-group">
            <label class="form-label">Photo URL</label>
            <input
              type="text"
              class="form-input"
              placeholder="https://example.com/photo.png"
              bind:value={createPhotoUrl}
            />
          </div>
        {/if}

        {#if createPhotoUrl.trim()}
          <div class="photo-preview-box">
            <span class="form-label">Photo Preview</span>
            <div class="photo-preview-frame">
              <img src={createPhotoUrl} alt="BOLO preview" class="photo-preview-img" />
            </div>
          </div>
        {/if}

        <div class="form-group">
          <label class="form-label">Linked Report ID</label>
          <input
            type="text"
            class="form-input font-mono"
            placeholder="RPT-00000000-0000"
            bind:value={createReportId}
          />
        </div>

        <div class="form-actions">
          <button class="btn-cancel" onclick={cancelCreate}>Cancel</button>
          <button
            class="btn-primary"
            onclick={handleCreate}
            disabled={!createTitle.trim() || saving}
          >
            {saving ? 'Creating...' : 'Issue BOLO'}
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .bolos-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale));
    height: 100%;
    opacity: 0;
    transform: translateY(calc(8px * var(--mdt-scale)));
  }

  .bolos-page.mounted {
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .list-mode,
  .create-mode {
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
    flex-shrink: 0;
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

  .controls-bar {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
  }

  .filter-bar {
    display: flex;
    gap: calc(2px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(3px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .filter-tab {
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
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

  .search-wrapper {
    position: relative;
    flex: 1;
    max-width: calc(320px * var(--mdt-scale));
  }

  .search-icon {
    position: absolute;
    left: calc(10px * var(--mdt-scale));
    top: 50%;
    transform: translateY(-50%);
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) calc(32px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    box-sizing: border-box;
  }

  .search-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .search-input:focus {
    border-color: var(--mdt-accent);
  }

  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: calc(60px * var(--mdt-scale)) 0;
    gap: calc(12px * var(--mdt-scale));
  }

  .spinner {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border: calc(3px * var(--mdt-scale)) solid var(--mdt-border-2);
    border-top-color: var(--mdt-accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .loading-text {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .cards-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(360px * var(--mdt-scale)), 1fr));
    gap: calc(12px * var(--mdt-scale));
  }

  .bolo-card {
    display: flex;
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    transition: border-color 0.2s ease, box-shadow 0.2s ease, opacity 0.2s ease;
    opacity: 0;
    animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: var(--card-delay);
  }

  .bolo-card:hover {
    border-color: var(--mdt-border-2);
  }

  .bolo-card.glow {
    box-shadow: inset calc(3px * var(--mdt-scale)) 0 calc(12px * var(--mdt-scale)) calc(-6px * var(--mdt-scale)) color-mix(in srgb, var(--card-border-color) 20%, transparent);
  }

  .bolo-card.dimmed {
    opacity: 0;
    animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: var(--card-delay);
  }

  .bolo-card.dimmed .card-content {
    opacity: 0.55;
  }

  .card-left-border {
    width: calc(4px * var(--mdt-scale));
    flex-shrink: 0;
    background: var(--card-border-color);
    border-radius: var(--mdt-radius) 0 0 var(--mdt-radius);
  }

  .card-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale));
    min-width: 0;
    transition: opacity 0.2s ease;
  }

  .card-top-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .card-badges {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
    align-items: center;
  }

  .type-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    background: color-mix(in srgb, var(--type-color) 15%, transparent);
    color: var(--type-color);
    border: 1px solid color-mix(in srgb, var(--type-color) 30%, transparent);
    white-space: nowrap;
    line-height: 1.4;
    text-transform: uppercase;
    letter-spacing: 0.04em;
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
    text-transform: capitalize;
  }

  .card-date {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .card-title {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    line-height: 1.3;
    letter-spacing: -0.01em;
  }

  .card-desc {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .card-plate {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    align-self: flex-start;
  }

  .card-plate svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    color: var(--mdt-warning, #f59e0b);
    flex-shrink: 0;
  }

  .card-plate span {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.08em;
  }

  .card-meta {
    display: flex;
    flex-wrap: wrap;
    gap: calc(10px * var(--mdt-scale));
    padding-top: calc(4px * var(--mdt-scale));
  }

  .meta-item {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .meta-item svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    flex-shrink: 0;
    opacity: 0.6;
  }

  .meta-report span {
    color: var(--mdt-accent);
    opacity: 0.7;
    font-size: calc(10px * var(--mdt-scale));
  }

  .card-actions {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
    padding-top: calc(6px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    margin-top: calc(2px * var(--mdt-scale));
  }

  .action-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(5px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, transform 0.1s ease, opacity 0.12s ease;
    border: none;
  }

  .action-btn svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .action-btn:active {
    transform: scale(0.97);
  }

  .action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .resolve-btn {
    background: color-mix(in srgb, var(--mdt-success) 12%, transparent);
    color: var(--mdt-success);
    border: 1px solid color-mix(in srgb, var(--mdt-success) 25%, transparent);
  }

  .resolve-btn:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-success) 20%, transparent);
  }

  .cancel-btn {
    background: color-mix(in srgb, var(--mdt-error) 10%, transparent);
    color: var(--mdt-error);
    border: 1px solid color-mix(in srgb, var(--mdt-error) 20%, transparent);
  }

  .cancel-btn:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-error) 18%, transparent);
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: calc(56px * var(--mdt-scale)) 0;
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

  .section-title {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
  }

  .form-card {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
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

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(14px * var(--mdt-scale));
  }

  .form-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .required {
    color: var(--mdt-error);
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
    box-sizing: border-box;
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
    min-height: calc(120px * var(--mdt-scale));
    box-sizing: border-box;
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .form-textarea-sm {
    min-height: calc(80px * var(--mdt-scale));
  }

  .type-selector {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: calc(6px * var(--mdt-scale));
  }

  .type-option {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(7px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: border-color 0.15s ease, background 0.15s ease, color 0.15s ease, transform 0.1s ease;
  }

  .type-option svg {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .type-option:hover {
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-3);
  }

  .type-option:active {
    transform: scale(0.97);
  }

  .type-option.active {
    border-color: color-mix(in srgb, var(--type-opt-color) 60%, transparent);
    background: color-mix(in srgb, var(--type-opt-color) 10%, transparent);
    color: var(--type-opt-color);
  }

  .photo-preview-box {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .photo-preview-frame {
    width: calc(160px * var(--mdt-scale));
    height: calc(120px * var(--mdt-scale));
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

  .form-actions {
    display: flex;
    justify-content: flex-end;
    gap: calc(8px * var(--mdt-scale));
    padding-top: calc(6px * var(--mdt-scale));
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

  .font-mono {
    font-family: 'Share Tech Mono', monospace;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(calc(6px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes cardIn {
    from {
      opacity: 0;
      transform: translateY(calc(10px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
