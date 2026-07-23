<script>
  import { onMount } from 'svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import {
    Plus,
    Search,
    User,
    Car,
    Swords,
    ChevronDown,
    Check,
    X,
    FileText,
    Shield,
    Clock,
  } from '@lucide/svelte';

  /** Category stripes: muted tints (semantic, not competing with --mdt-accent) */
  const TYPE_CONFIG = {
    person: {
      label: 'Person',
      stripe: 'rgba(110, 168, 178, 0.55)',
      tone: 'rgba(110, 168, 178, 0.9)',
    },
    vehicle: {
      label: 'Vehicle',
      stripe: 'rgba(196, 154, 82, 0.55)',
      tone: 'rgba(196, 154, 82, 0.9)',
    },
    weapon: {
      label: 'Weapon',
      stripe: 'rgba(188, 108, 106, 0.55)',
      tone: 'rgba(188, 108, 106, 0.9)',
    },
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

  const TYPE_CHIPS = [
    { key: 'all', label: 'All types' },
    { key: 'person', label: 'Person' },
    { key: 'vehicle', label: 'Vehicle' },
    { key: 'weapon', label: 'Weapon' },
  ];

  let mode = $state('list');
  let activeFilter = $state('active');
  let typeFilter = $state('all');
  let searchQuery = $state('');
  let loading = $state(false);
  let saving = $state(false);
  let mounted = $state(false);
  let expandedId = $state(null);

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

  let filteredBolos = $derived.by(() => {
    let list = bolos;
    if (typeFilter !== 'all') {
      list = list.filter(b => b.type === typeFilter);
    }
    if (!searchQuery.trim()) return list;
    const q = searchQuery.toLowerCase();
    return list.filter(
      b =>
        (b.title && b.title.toLowerCase().includes(q)) ||
        (b.description && b.description.toLowerCase().includes(q)) ||
        (b.plate && b.plate.toLowerCase().includes(q)) ||
        (b.issued_by && b.issued_by.toLowerCase().includes(q))
    );
  });

  let activeOpenCount = $derived(bolos.filter(b => b.status === 'active').length);

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

  function toggleExpand(id) {
    expandedId = expandedId === id ? null : id;
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
    expandedId = null;
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
    await dataStore.createBolo({
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

  async function handleStatusChange(boloId, newStatus, e) {
    e?.stopPropagation?.();
    saving = true;
    await dataStore.updateBoloStatus(boloId, newStatus);
    if (isEnvBrowser()) {
      dataStore.bolosList = bolos.map(b => (b.id === boloId ? { ...b, status: newStatus } : b));
      if (activeFilter === 'active') {
        dataStore.bolosList = dataStore.bolosList.filter(b => b.status === 'active');
      }
    } else {
      await loadBolos();
    }
    expandedId = null;
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
      <header class="masthead">
        <div class="masthead-copy">
          <p class="masthead-kicker">Field bulletin board</p>
          <h2 class="masthead-title">BOLOs</h2>
          <p class="masthead-sub">Be On the Lookout — tap a row for full detail and disposition.</p>
        </div>
        <button type="button" class="btn-new" onclick={openCreate}>
          <Plus size={16} strokeWidth={2} aria-hidden="true" />
          <span>New BOLO</span>
        </button>
      </header>

      <div class="workspace">
        <aside class="rail" aria-label="Filters and summary">
          <div class="rail-stat">
            <span class="rail-stat-label">Open active</span>
            <div class="rail-stat-value-row">
              <span class="rail-stat-num font-mono">{activeOpenCount}</span>
              {#if activeFilter === 'active' && activeOpenCount > 0}
                <span class="live-mark" aria-hidden="true"></span>
              {/if}
            </div>
          </div>

          <div class="rail-block">
            <span class="rail-label">Scope</span>
            <div class="tab-row" role="tablist" aria-label="List scope">
              {#each [['active', 'Active'], ['all', 'All']] as [key, label], idx}
                {#if idx > 0}<span class="tab-div" aria-hidden="true"></span>{/if}
                <button
                  type="button"
                  role="tab"
                  class="tab-link"
                  aria-selected={activeFilter === key}
                  class:selected={activeFilter === key}
                  onclick={() => switchFilter(key)}
                >{label}</button>
              {/each}
            </div>
          </div>

          <div class="rail-block">
            <span class="rail-label">Type</span>
            <nav class="type-nav" aria-label="Filter by type">
              {#each TYPE_CHIPS as chip}
                <button
                  type="button"
                  class="type-nav-item"
                  class:selected={typeFilter === chip.key}
                  onclick={() => {
                    typeFilter = chip.key;
                    expandedId = null;
                  }}
                >{chip.label}</button>
              {/each}
            </nav>
          </div>

          <div class="rail-hint">
            <span class="font-mono">{filteredBolos.length}</span> shown
            {#if typeFilter !== 'all' || searchQuery.trim()}
              <span class="rail-hint-muted">after filters</span>
            {/if}
          </div>
        </aside>

        <section class="main-col" aria-label="BOLO list">
          <div class="search-row">
            <label class="search-wrap" for="bolo-search">
              <Search class="search-ic" size={16} strokeWidth={2} aria-hidden="true" />
              <input
                id="bolo-search"
                type="search"
                class="search-input"
                placeholder="Search title, plate, officer, description..."
                bind:value={searchQuery}
                autocomplete="off"
              />
            </label>
          </div>

          {#if loading}
            <div class="skeleton-stack" aria-busy="true" aria-label="Loading">
              {#each [1, 2, 3, 4] as row (row)}
                <div class="sk-row" style="--sk-delay: {(row - 1) * 0.07}s">
                  <div class="sk-stripe"></div>
                  <div class="sk-body">
                    <div class="sk-line sk-w-40"></div>
                    <div class="sk-line sk-w-70"></div>
                    <div class="sk-line sk-w-55"></div>
                  </div>
                </div>
              {/each}
            </div>
          {:else if filteredBolos.length > 0}
            <ul class="feed" role="list">
              {#each filteredBolos as bolo, i (bolo.id)}
                {@const typeConf = getTypeConfig(bolo.type)}
                {@const statusConf = getStatusConfig(bolo.status)}
                {@const isActive = bolo.status === 'active'}
                {@const open = expandedId === bolo.id}
                {@const stagger = i * 0.045}
                <li
                  class="feed-item"
                  style="--stripe: {typeConf.stripe}; --type-tone: {typeConf.tone}; --st: {statusConf.color}; --enter-delay: {stagger}s;"
                >
                  <article class="dossier" class:open class:inactive={!isActive}>
                    <button
                      type="button"
                      class="dossier-hit"
                      onclick={() => toggleExpand(bolo.id)}
                      aria-expanded={open}
                    >
                      <span class="dossier-stripe" aria-hidden="true"></span>
                      <span class="dossier-main">
                        <span class="dossier-top">
                          <span class="type-ic" aria-hidden="true">
                            {#if bolo.type === 'vehicle'}
                              <Car size={15} strokeWidth={1.75} />
                            {:else if bolo.type === 'weapon'}
                              <Swords size={15} strokeWidth={1.75} />
                            {:else}
                              <User size={15} strokeWidth={1.75} />
                            {/if}
                          </span>
                          <span class="type-label font-mono">{typeConf.label}</span>
                          <span class="meta-sep" aria-hidden="true"></span>
                          <span class="status-inline">
                            <span class="status-dot" aria-hidden="true"></span>
                            {statusConf.label}
                          </span>
                          <span class="dossier-time font-mono">
                            <Clock size={12} strokeWidth={1.75} class="time-ic" aria-hidden="true" />
                            {formatDate(bolo.created_at)}
                          </span>
                          <ChevronDown class="chev" size={16} strokeWidth={2} aria-hidden="true" />
                        </span>
                        <h3 class="dossier-title">{bolo.title}</h3>
                        <p class="dossier-preview" class:clamp={!open}>{bolo.description || '\u2014'}</p>
                      </span>
                    </button>

                    {#if open}
                      <div class="dossier-drawer">
                        {#if bolo.type === 'vehicle' && bolo.plate}
                          <div class="plate-inline">
                            <span class="plate-label font-mono">Plate</span>
                            <span class="plate-val font-mono">{bolo.plate}</span>
                          </div>
                        {/if}

                        <div class="meta-grid">
                          <div class="meta-cell">
                            <span class="meta-lbl">Issued by</span>
                            <span class="meta-val">{bolo.officer_first ? `${bolo.officer_first} ${bolo.officer_last}` : (typeof bolo.issued_by === 'string' ? bolo.issued_by : '\u2014')}</span>
                          </div>
                          {#if bolo.department}
                            <div class="meta-cell">
                              <span class="meta-lbl">Dept</span>
                              <span class="meta-val"><Shield size={12} strokeWidth={1.75} class="meta-ic" aria-hidden="true" />{bolo.department}</span>
                            </div>
                          {/if}
                          {#if bolo.report_id}
                            <div class="meta-cell meta-span">
                              <span class="meta-lbl">Report</span>
                              <span class="meta-val font-mono"><FileText size={12} strokeWidth={1.75} class="meta-ic" aria-hidden="true" />{bolo.report_id}</span>
                            </div>
                          {/if}
                        </div>

                        {#if isActive}
                          <div class="drawer-actions">
                            <button
                              type="button"
                              class="btn-resolve"
                              disabled={saving}
                              onclick={e => handleStatusChange(bolo.id, 'resolved', e)}
                            >
                              <Check size={14} strokeWidth={2} aria-hidden="true" />
                              Resolve
                            </button>
                            <button
                              type="button"
                              class="btn-cancel-bolo"
                              disabled={saving}
                              onclick={e => handleStatusChange(bolo.id, 'cancelled', e)}
                            >
                              <X size={14} strokeWidth={2} aria-hidden="true" />
                              Cancel
                            </button>
                          </div>
                        {/if}
                      </div>
                    {:else if isActive}
                      <div class="quick-actions" aria-hidden="true">
                        <span class="quick-hint">Open row for actions</span>
                      </div>
                    {/if}
                  </article>
                </li>
              {/each}
            </ul>
          {:else}
            <div class="empty-state">
              <div class="empty-visual" aria-hidden="true"></div>
              <p class="empty-title">No BOLOs in this view</p>
              <p class="empty-sub">
                {#if searchQuery.trim() || typeFilter !== 'all'}
                  Widen scope to All, clear search, or pick another type.
                {:else}
                  Issue a bulletin from New BOLO when you have suspect or asset data.
                {/if}
              </p>
              {#if searchQuery.trim() || typeFilter !== 'all'}
                <button
                  type="button"
                  class="empty-reset"
                  onclick={() => {
                    searchQuery = '';
                    typeFilter = 'all';
                  }}
                >Reset filters</button>
              {:else}
                <button type="button" class="empty-reset" onclick={openCreate}>New BOLO</button>
              {/if}
            </div>
          {/if}
        </section>
      </div>
    </div>
  {:else if mode === 'create'}
    <div class="create-mode">
      <button type="button" class="back-btn" onclick={cancelCreate}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to BOLOs</span>
      </button>

      <h2 class="section-title">Create BOLO</h2>

      <div class="create-form">
        <div class="form-section">
          <label class="form-label" for="bolo-type">Type</label>
          <div class="type-tabs" id="bolo-type" role="tablist">
            {#each [['person', 'Person'], ['vehicle', 'Vehicle'], ['weapon', 'Weapon']] as [key, label], ti}
              {#if ti > 0}<span class="type-tabs-div" aria-hidden="true"></span>{/if}
              <button
                type="button"
                role="tab"
                class="type-tab"
                aria-selected={createType === key}
                class:selected={createType === key}
                style="--type-tab-tone: {getTypeConfig(key).tone}"
                onclick={() => {
                  createType = key;
                }}
              >
                {#if key === 'person'}
                  <User size={16} strokeWidth={2} aria-hidden="true" />
                {:else if key === 'vehicle'}
                  <Car size={16} strokeWidth={2} aria-hidden="true" />
                {:else}
                  <Swords size={16} strokeWidth={2} aria-hidden="true" />
                {/if}
                <span>{label}</span>
              </button>
            {/each}
          </div>
        </div>

        <div class="form-section form-group">
          <label class="form-label" for="bolo-title">Title <span class="required">*</span></label>
          <input
            id="bolo-title"
            type="text"
            class="form-input"
            placeholder="Brief descriptive title for this BOLO..."
            bind:value={createTitle}
          />
        </div>

        <div class="form-section form-group">
          <label class="form-label" for="bolo-desc">Description</label>
          <textarea
            id="bolo-desc"
            class="form-textarea"
            placeholder="Detailed description — include physical characteristics, last known location, circumstances..."
            bind:value={createDescription}
            rows="5"
          ></textarea>
        </div>

        {#if createType === 'person'}
          <div class="form-section form-row">
            <div class="form-group form-group-half">
              <label class="form-label" for="bolo-cit">Citizen ID</label>
              <input
                id="bolo-cit"
                type="text"
                class="form-input font-mono"
                placeholder="CIT-00000000-0000"
                bind:value={createCitizenId}
              />
            </div>
            <div class="form-group form-group-half">
              <label class="form-label" for="bolo-photo-p">Photo URL</label>
              <input
                id="bolo-photo-p"
                type="text"
                class="form-input"
                placeholder="https://example.com/photo.png"
                bind:value={createPhotoUrl}
              />
            </div>
          </div>
        {:else if createType === 'vehicle'}
          <div class="form-section form-row">
            <div class="form-group form-group-half">
              <label class="form-label" for="bolo-plate">License Plate</label>
              <input
                id="bolo-plate"
                type="text"
                class="form-input font-mono"
                placeholder="e.g. 59CKN843"
                bind:value={createPlate}
              />
            </div>
            <div class="form-group form-group-half">
              <label class="form-label" for="bolo-photo-v">Photo URL</label>
              <input
                id="bolo-photo-v"
                type="text"
                class="form-input"
                placeholder="https://example.com/photo.png"
                bind:value={createPhotoUrl}
              />
            </div>
          </div>
          <div class="form-section form-group">
            <label class="form-label" for="bolo-veh-desc">Vehicle Description</label>
            <textarea
              id="bolo-veh-desc"
              class="form-textarea form-textarea-sm"
              placeholder="Make, model, color, modifications, damage..."
              bind:value={createVehicleDesc}
              rows="3"
            ></textarea>
          </div>
        {:else if createType === 'weapon'}
          <div class="form-section form-group">
            <label class="form-label" for="bolo-wpn">Weapon Description</label>
            <textarea
              id="bolo-wpn"
              class="form-textarea form-textarea-sm"
              placeholder="Weapon type, serial number, distinguishing marks..."
              bind:value={createWeaponDesc}
              rows="3"
            ></textarea>
          </div>
          <div class="form-section form-group">
            <label class="form-label" for="bolo-photo-w">Photo URL</label>
            <input
              id="bolo-photo-w"
              type="text"
              class="form-input"
              placeholder="https://example.com/photo.png"
              bind:value={createPhotoUrl}
            />
          </div>
        {/if}

        {#if createPhotoUrl.trim()}
          <div class="form-section photo-preview-box">
            <span class="form-label">Photo Preview</span>
            <div class="photo-preview-frame">
              <img src={createPhotoUrl} alt="BOLO preview" class="photo-preview-img" />
            </div>
          </div>
        {/if}

        <div class="form-section form-group">
          <label class="form-label" for="bolo-rpt">Linked Report ID</label>
          <input
            id="bolo-rpt"
            type="text"
            class="form-input font-mono"
            placeholder="RPT-00000000-0000"
            bind:value={createReportId}
          />
        </div>

        <div class="form-section form-actions">
          <button type="button" class="btn-cancel" onclick={cancelCreate}>Cancel</button>
          <button
            type="button"
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
    padding: calc(22px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(18px * var(--mdt-scale));
    height: 100%;
    min-height: 0;
    opacity: 0;
    transform: translateY(calc(6px * var(--mdt-scale)));
  }

  .bolos-page.mounted {
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .list-mode,
  .create-mode {
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    min-height: 0;
    flex: 1;
    animation: fadeIn 0.25s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  /* --- Masthead (asymmetric, no centered hero) --- */
  .masthead {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: calc(20px * var(--mdt-scale));
    flex-wrap: wrap;
    padding-bottom: calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .masthead-copy {
    max-width: min(52ch, 100%);
    text-align: left;
  }

  .masthead-kicker {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  .masthead-title {
    font-family: 'Unbounded', sans-serif;
    font-size: calc(26px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.03em;
    line-height: 1.05;
    color: var(--mdt-text);
  }

  .masthead-sub {
    margin-top: calc(6px * var(--mdt-scale));
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.5;
    color: var(--mdt-text-dim);
    max-width: 50ch;
  }

  .btn-new {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    border: none;
    border-radius: var(--mdt-radius);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    flex-shrink: 0;
    white-space: nowrap;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .btn-new:hover {
    opacity: 0.9;
  }

  .btn-new:active {
    transform: scale(0.96);
  }

  /* --- Workspace: rail + feed (line-divided, no panels) --- */
  .workspace {
    display: grid;
    grid-template-columns: minmax(calc(168px * var(--mdt-scale)), calc(220px * var(--mdt-scale))) 1fr;
    gap: 0;
    align-items: stretch;
    min-height: 0;
    flex: 1;
    border-top: 1px solid var(--mdt-border);
  }

  @media (max-width: 820px) {
    .workspace {
      grid-template-columns: 1fr;
    }
  }

  .rail {
    position: sticky;
    top: calc(4px * var(--mdt-scale));
    align-self: start;
    display: flex;
    flex-direction: column;
    gap: 0;
    padding: calc(16px * var(--mdt-scale)) calc(18px * var(--mdt-scale)) calc(16px * var(--mdt-scale)) 0;
    background: transparent;
    border-right: 1px solid var(--mdt-border);
  }

  @media (max-width: 820px) {
    .rail {
      position: static;
      border-right: none;
      border-bottom: 1px solid var(--mdt-border);
      padding: calc(14px * var(--mdt-scale)) 0;
    }
  }

  .rail-stat-label {
    display: block;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .rail-stat-value-row {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    margin-top: calc(4px * var(--mdt-scale));
  }

  .rail-stat-num {
    font-size: calc(28px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: -0.02em;
    line-height: 1;
  }

  .live-mark {
    width: calc(2px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    background: var(--mdt-success);
    flex-shrink: 0;
  }

  .rail-stat {
    padding-bottom: calc(14px * var(--mdt-scale));
    margin-bottom: calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .rail-block {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    padding-bottom: calc(14px * var(--mdt-scale));
    margin-bottom: calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .rail-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
  }

  .tab-row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: calc(2px * var(--mdt-scale));
  }

  .tab-div {
    width: 1px;
    height: calc(12px * var(--mdt-scale));
    background: var(--mdt-border);
    margin: 0 calc(4px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .tab-link {
    padding: calc(4px * var(--mdt-scale)) 0 calc(6px * var(--mdt-scale));
    margin: 0;
    border: none;
    border-bottom: 2px solid transparent;
    background: none;
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition:
      color 0.15s ease,
      border-color 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .tab-link:hover {
    color: var(--mdt-text-dim);
  }

  .tab-link.selected {
    color: var(--mdt-text);
    border-bottom-color: var(--mdt-accent);
  }

  .type-nav {
    display: flex;
    flex-direction: column;
    margin: 0;
    padding: 0;
  }

  .type-nav-item {
    text-align: left;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    margin: 0;
    border: none;
    border-left: 2px solid transparent;
    background: transparent;
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition:
      color 0.15s ease,
      border-color 0.2s ease,
      background 0.15s ease;
  }

  .type-nav-item + .type-nav-item {
    border-top: 1px solid var(--mdt-border);
    margin-top: -1px;
  }

  .type-nav-item:hover {
    color: var(--mdt-text);
    background: color-mix(in srgb, var(--mdt-surface-2) 40%, transparent);
  }

  .type-nav-item.selected {
    color: var(--mdt-text);
    border-left-color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-surface-2) 55%, transparent);
  }

  .rail-hint {
    font-family: 'Outfit', sans-serif;
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding-top: calc(2px * var(--mdt-scale));
    margin-top: auto;
  }

  .rail-hint-muted {
    display: block;
    margin-top: calc(2px * var(--mdt-scale));
    opacity: 0.85;
  }

  /* --- Main column --- */
  .main-col {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 0;
    min-height: 0;
    flex: 1;
    padding: calc(16px * var(--mdt-scale)) 0 calc(16px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
  }

  @media (max-width: 820px) {
    .main-col {
      padding-left: 0;
      padding-top: calc(12px * var(--mdt-scale));
    }
  }

  .search-row {
    width: 100%;
    padding-bottom: calc(12px * var(--mdt-scale));
    margin-bottom: calc(4px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .search-wrap {
    position: relative;
    display: block;
    width: 100%;
    max-width: min(100%, calc(520px * var(--mdt-scale)));
  }

  .search-wrap :global(.search-ic) {
    position: absolute;
    left: 0;
    top: 50%;
    transform: translateY(-50%);
    color: var(--mdt-text-muted);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(26px * var(--mdt-scale));
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    border-radius: 0;
    background: transparent;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    box-sizing: border-box;
  }

  .search-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .search-input:focus {
    border-bottom-color: color-mix(in srgb, var(--mdt-accent) 55%, var(--mdt-border));
  }

  /* --- Skeleton --- */
  .skeleton-stack {
    display: flex;
    flex-direction: column;
    border-top: 1px solid var(--mdt-border);
  }

  .sk-row {
    display: flex;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) 0;
    border-bottom: 1px solid var(--mdt-border);
    overflow: hidden;
    opacity: 0;
    animation: rowIn 0.45s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: var(--sk-delay);
    background: transparent;
  }

  .sk-stripe {
    width: calc(2px * var(--mdt-scale));
    background: var(--mdt-border-2);
    flex-shrink: 0;
    align-self: stretch;
  }

  .sk-body {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    min-width: 0;
  }

  .sk-line {
    height: calc(10px * var(--mdt-scale));
    border-radius: 0;
    background: linear-gradient(
      90deg,
      var(--mdt-surface-3) 0%,
      var(--mdt-surface-2) 45%,
      var(--mdt-surface-3) 90%
    );
    background-size: 200% 100%;
    animation: shimmer 1.35s ease-in-out infinite;
  }

  .sk-w-40 {
    width: 40%;
  }
  .sk-w-55 {
    width: 55%;
  }
  .sk-w-70 {
    width: 70%;
  }

  /* --- Feed: rows divided by hairlines --- */
  .feed {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0;
    overflow-y: auto;
    padding-right: calc(4px * var(--mdt-scale));
    min-height: 0;
    flex: 1;
    border-top: 1px solid var(--mdt-border);
  }

  .feed-item {
    margin: 0;
    padding: 0;
    border-bottom: 1px solid var(--mdt-border);
  }

  .dossier {
    border: none;
    border-left: 2px solid transparent;
    border-radius: 0;
    background: transparent;
    overflow: visible;
    box-shadow: none;
    opacity: 0;
    transform: translateY(calc(6px * var(--mdt-scale)));
    animation: rowIn 0.42s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: var(--enter-delay);
    transition:
      background 0.2s ease,
      border-color 0.2s ease;
  }

  .dossier:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 35%, transparent);
  }

  .dossier.open {
    background: color-mix(in srgb, var(--mdt-surface-2) 50%, transparent);
    border-left-color: var(--mdt-accent);
  }

  .dossier.inactive {
    opacity: 0.92;
  }

  .dossier-hit {
    display: flex;
    width: 100%;
    padding: 0;
    margin: 0;
    border: none;
    background: transparent;
    cursor: pointer;
    text-align: left;
    color: inherit;
    font: inherit;
  }

  .dossier-hit:focus-visible {
    outline: 2px solid var(--mdt-accent);
    outline-offset: 2px;
  }

  .dossier-stripe {
    width: calc(2px * var(--mdt-scale));
    flex-shrink: 0;
    background: var(--stripe);
    align-self: stretch;
  }

  .dossier-main {
    flex: 1;
    padding: calc(14px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .dossier-top {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .type-ic {
    display: flex;
    color: var(--type-tone, var(--mdt-text-muted));
    opacity: 0.9;
  }

  .type-label {
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--type-tone, var(--mdt-text-dim));
  }

  .meta-sep {
    width: 1px;
    height: calc(11px * var(--mdt-scale));
    background: var(--mdt-border);
    flex-shrink: 0;
  }

  .status-inline {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    color: var(--st);
    font-family: 'Outfit', sans-serif;
  }

  .status-dot {
    width: calc(5px * var(--mdt-scale));
    height: calc(5px * var(--mdt-scale));
    background: var(--st);
    flex-shrink: 0;
  }

  .dossier-time {
    margin-left: auto;
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .dossier-time :global(.time-ic) {
    flex-shrink: 0;
    opacity: 0.65;
  }

  .dossier-top :global(.chev) {
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .dossier.open :global(.chev) {
    transform: rotate(180deg);
  }

  .dossier-title {
    font-family: 'Outfit', sans-serif;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: -0.02em;
    line-height: 1.25;
    color: var(--mdt-text);
  }

  .dossier-preview {
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.55;
    color: var(--mdt-text-dim);
  }

  .dossier-preview.clamp {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .quick-actions {
    padding: 0 calc(12px * var(--mdt-scale)) calc(10px * var(--mdt-scale))
      calc((2px + 14px) * var(--mdt-scale));
    border-top: 1px solid transparent;
  }

  .quick-hint {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .dossier-drawer {
    padding: calc(12px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale))
      calc((2px + 14px) * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    margin-left: calc(2px * var(--mdt-scale));
    animation: fadeIn 0.25s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }

  .plate-inline {
    display: flex;
    align-items: baseline;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) 0;
    border-bottom: 1px solid var(--mdt-border);
    align-self: stretch;
  }

  .plate-label {
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .plate-val {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.12em;
  }

  .meta-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(140px * var(--mdt-scale)), 1fr));
    gap: calc(10px * var(--mdt-scale));
  }

  .meta-cell {
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
  }

  .meta-span {
    grid-column: 1 / -1;
  }

  .meta-lbl {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .meta-val {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
  }

  .meta-val :global(.meta-ic) {
    flex-shrink: 0;
    opacity: 0.55;
  }

  .drawer-actions {
    display: flex;
    flex-wrap: wrap;
    gap: calc(8px * var(--mdt-scale));
  }

  .btn-resolve,
  .btn-cancel-bolo {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: 2px;
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    background: transparent;
    transition:
      transform 0.15s cubic-bezier(0.16, 1, 0.3, 1),
      opacity 0.15s ease,
      filter 0.15s ease;
  }

  .btn-resolve {
    color: var(--mdt-success);
    border: 1px solid color-mix(in srgb, var(--mdt-success) 45%, var(--mdt-border));
  }

  .btn-cancel-bolo {
    color: var(--mdt-error);
    border: 1px solid color-mix(in srgb, var(--mdt-error) 40%, var(--mdt-border));
  }

  .btn-resolve:active,
  .btn-cancel-bolo:active {
    transform: scale(0.98) translateY(1px);
  }

  .btn-resolve:disabled,
  .btn-cancel-bolo:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .btn-resolve:hover:not(:disabled),
  .btn-cancel-bolo:hover:not(:disabled) {
    filter: brightness(1.08);
  }

  /* --- Empty --- */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    padding: calc(40px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    gap: calc(10px * var(--mdt-scale));
    max-width: 42ch;
  }

  .empty-visual {
    width: calc(44px * var(--mdt-scale));
    height: calc(4px * var(--mdt-scale));
    border-radius: 2px;
    background: linear-gradient(90deg, var(--mdt-accent), transparent);
    opacity: 0.5;
  }

  .empty-title {
    font-family: 'Unbounded', sans-serif;
    font-size: calc(16px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .empty-sub {
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.55;
    color: var(--mdt-text-dim);
  }

  .empty-reset {
    margin-top: calc(4px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: 2px;
    border: 1px solid var(--mdt-border-2);
    background: transparent;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition:
      background 0.2s ease,
      transform 0.15s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .empty-reset:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 50%, transparent);
  }

  .empty-reset:active {
    transform: scale(0.98);
  }

  /* --- Create mode (unchanged structure, aligned tokens) --- */
  .back-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: transparent;
    border: 1px solid var(--mdt-border);
    border-radius: 2px;
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

  .back-btn:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 45%, transparent);
    color: var(--mdt-text);
  }

  .back-btn:active {
    transform: scale(0.98);
  }

  .section-title {
    font-family: 'Unbounded', sans-serif;
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.02em;
    padding-bottom: calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .create-form {
    display: flex;
    flex-direction: column;
    gap: 0;
    max-width: min(100%, calc(640px * var(--mdt-scale)));
  }

  .form-section {
    padding: calc(16px * var(--mdt-scale)) 0;
    border-bottom: 1px solid var(--mdt-border);
  }

  .form-section:last-child {
    border-bottom: none;
  }

  .type-tabs {
    display: flex;
    align-items: stretch;
    flex-wrap: wrap;
    gap: 0;
    border: 1px solid var(--mdt-border);
    border-radius: 0;
  }

  .type-tabs-div {
    width: 1px;
    background: var(--mdt-border);
    flex-shrink: 0;
    align-self: stretch;
  }

  .type-tab {
    flex: 1;
    min-width: calc(88px * var(--mdt-scale));
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border: none;
    background: transparent;
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition:
      color 0.15s ease,
      background 0.15s ease,
      box-shadow 0.2s ease;
    box-shadow: inset 0 -2px 0 transparent;
  }

  .type-tab:hover {
    color: var(--mdt-text);
    background: color-mix(in srgb, var(--mdt-surface-2) 40%, transparent);
  }

  .type-tab.selected {
    color: var(--mdt-text);
    box-shadow: inset 0 -2px 0 var(--type-tab-tone, var(--mdt-accent));
    background: color-mix(in srgb, var(--mdt-surface-2) 25%, transparent);
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

  @media (max-width: 560px) {
    .form-row {
      grid-template-columns: 1fr;
    }
  }

  .form-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
  }

  .required {
    color: var(--mdt-error);
  }

  .form-group-half {
    min-width: 0;
  }

  .form-input {
    width: 100%;
    padding: calc(9px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: 0;
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    background: transparent;
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    box-sizing: border-box;
  }

  .form-input:focus {
    border-color: color-mix(in srgb, var(--mdt-accent) 50%, var(--mdt-border));
  }

  .form-textarea {
    width: 100%;
    resize: vertical;
    padding: calc(10px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: 0;
    border: 1px solid var(--mdt-border);
    background: color-mix(in srgb, var(--mdt-surface-2) 30%, transparent);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale));
    line-height: 1.6;
    outline: none;
    transition: border-color 0.15s ease;
    min-height: calc(120px * var(--mdt-scale));
    box-sizing: border-box;
  }

  .form-textarea:focus {
    border-color: color-mix(in srgb, var(--mdt-accent) 50%, var(--mdt-border));
  }

  .form-textarea-sm {
    min-height: calc(80px * var(--mdt-scale));
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
    border-radius: 0;
    border: 1px solid var(--mdt-border);
    background: color-mix(in srgb, var(--mdt-surface-2) 35%, transparent);
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
    padding-top: calc(4px * var(--mdt-scale));
  }

  .btn-cancel {
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: 2px;
    border: 1px solid var(--mdt-border);
    background: transparent;
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease;
  }

  .btn-cancel:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 50%, transparent);
    color: var(--mdt-text);
  }

  .btn-primary {
    padding: calc(8px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    border-radius: 2px;
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition:
      opacity 0.15s ease,
      transform 0.1s ease;
  }

  .btn-primary:hover {
    opacity: 0.92;
  }

  .btn-primary:active {
    transform: scale(0.98);
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
      transform: translateY(calc(5px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes rowIn {
    from {
      opacity: 0;
      transform: translateY(calc(10px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes shimmer {
    0% {
      background-position: 100% 0;
    }
    100% {
      background-position: -100% 0;
    }
  }

</style>
