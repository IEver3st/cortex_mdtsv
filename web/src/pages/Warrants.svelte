<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const STATUS_COLORS = {
    active: 'var(--mdt-error)',
    served: 'var(--mdt-success)',
    expired: 'var(--mdt-text-muted)',
    quashed: 'var(--mdt-warning)',
  };

  let mode = $state('list');
  let activeFilter = $state('active');
  let searchQuery = $state('');
  let loading = $state(false);
  let saving = $state(false);
  let mounted = $state(false);
  let confirmAction = $state(null);

  let citizenQuery = $state('');
  let citizenDebounce = $state(null);
  let showCitizenDropdown = $state(false);
  let selectedCitizenId = $state('');
  let selectedCitizenName = $state('');
  let chargeInput = $state('');
  let charges = $state([]);
  let description = $state('');
  let reportId = $state('');
  let boloId = $state('');

  let warrants = $derived(dataStore.warrantsList || []);
  let citizenResults = $derived(dataStore.citizenSearchResults || []);
  let officer = $derived(mdtStore.officer);

  let filteredWarrants = $derived.by(() => {
    if (!searchQuery.trim()) return warrants;
    const q = searchQuery.toLowerCase();
    return warrants.filter(w =>
      (w.citizen_name || '').toLowerCase().includes(q) ||
      (w.charges || []).some(c => c.toLowerCase().includes(q))
    );
  });

  let statusSummary = $derived.by(() => {
    const list = filteredWarrants;
    const c = { active: 0, served: 0, expired: 0, quashed: 0 };
    for (const w of list) {
      if (c[w.status] !== undefined) c[w.status]++;
    }
    return { ...c, total: list.length };
  });

  function getStatusColor(status) {
    return STATUS_COLORS[status] || 'var(--mdt-text-muted)';
  }

  function statusLabel(status) {
    if (!status) return '\u2014';
    return status.charAt(0).toUpperCase() + status.slice(1);
  }

  function chargeToneClass(index) {
    return `tone-${index % 3}`;
  }

  function formatDate(dateStr) {
    if (!dateStr) return '\u2014';
    try {
      const d = new Date(dateStr);
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    } catch {
      return dateStr;
    }
  }

  function truncate(str, max) {
    if (!str) return '\u2014';
    return str.length > max ? str.slice(0, max) + '\u2026' : str;
  }

  async function loadWarrants() {
    loading = true;
    await dataStore.fetchWarrants(activeFilter);
    loading = false;
  }

  function switchFilter(filter) {
    activeFilter = filter;
    loadWarrants();
  }

  function openCreate() {
    citizenQuery = '';
    selectedCitizenId = '';
    selectedCitizenName = '';
    charges = [];
    chargeInput = '';
    description = '';
    reportId = '';
    boloId = '';
    showCitizenDropdown = false;
    mode = 'create';
  }

  function cancelCreate() {
    mode = 'list';
    dataStore.citizenSearchResults = [];
    showCitizenDropdown = false;
  }

  function handleCitizenInput(e) {
    citizenQuery = e.target.value;
    selectedCitizenId = '';
    selectedCitizenName = '';
    if (citizenDebounce) clearTimeout(citizenDebounce);
    if (!citizenQuery.trim()) {
      dataStore.citizenSearchResults = [];
      showCitizenDropdown = false;
      return;
    }
    citizenDebounce = setTimeout(() => {
      dataStore.searchCitizens(citizenQuery.trim());
      showCitizenDropdown = true;
    }, 300);
  }

  function selectCitizen(cit) {
    selectedCitizenId = cit.citizen_id;
    selectedCitizenName = `${cit.first_name} ${cit.last_name}`;
    citizenQuery = selectedCitizenName;
    showCitizenDropdown = false;
    dataStore.citizenSearchResults = [];
  }

  function handleChargeKey(e) {
    if (e.key === 'Enter' && chargeInput.trim()) {
      e.preventDefault();
      const val = chargeInput.trim();
      if (!charges.includes(val)) {
        charges = [...charges, val];
      }
      chargeInput = '';
    }
  }

  function removeCharge(charge) {
    charges = charges.filter(c => c !== charge);
  }

  async function handleCreate() {
    if (!selectedCitizenId || charges.length === 0) return;
    saving = true;
    const resp = await dataStore.createWarrant({
      citizenId: selectedCitizenId,
      citizenName: selectedCitizenName,
      charges,
      description,
      reportId: reportId || null,
      boloId: boloId || null,
    });
    if (resp?.ok || isEnvBrowser()) {
      if (isEnvBrowser()) {
        dataStore.warrantsList = [
          {
            id: Date.now(),
            citizen_id: selectedCitizenId,
            citizen_name: selectedCitizenName,
            charges: [...charges],
            description,
            status: 'active',
            issued_by: officer ? `${officer.firstName} ${officer.lastName}` : 'Unknown',
            department: officer?.department || 'LSPD',
            report_id: reportId || null,
            bolo_id: boloId || null,
            created_at: new Date().toISOString(),
            officer_first: officer?.firstName || '',
            officer_last: officer?.lastName || '',
          },
          ...warrants,
        ];
      } else {
        await loadWarrants();
      }
      mode = 'list';
    }
    saving = false;
  }

  async function handleStatusChange(warrantId, newStatus) {
    confirmAction = null;
    saving = true;
    await dataStore.updateWarrantStatus(warrantId, newStatus);
    if (isEnvBrowser()) {
      dataStore.warrantsList = warrants.map(w =>
        w.id === warrantId ? { ...w, status: newStatus } : w
      );
    } else {
      await loadWarrants();
    }
    saving = false;
  }

  onMount(() => {
    mounted = true;

    if (isEnvBrowser()) {
      dataStore.warrantsList = [
        {
          id: 1,
          citizen_id: 'CIT-10042',
          citizen_name: 'Marcus Rivera',
          charges: ['Armed Robbery', 'Assault with a Deadly Weapon'],
          description: 'Suspect wanted in connection with the armed robbery at Fleeca Bank, Hawick Ave. Considered armed and dangerous.',
          status: 'active',
          issued_by: 'Det. Nakamura',
          department: 'LSPD',
          report_id: 'RPT-20260315-0042',
          bolo_id: null,
          created_at: '2026-03-15T14:30:00Z',
          officer_first: 'Aiko',
          officer_last: 'Nakamura',
        },
        {
          id: 2,
          citizen_id: 'CIT-10078',
          citizen_name: 'Diana Vasquez',
          charges: ['Grand Theft Auto', 'Evading Police'],
          description: 'Subject identified as the driver in the pursuit of a stolen Sultan RS. Failed to yield at multiple intersections.',
          status: 'active',
          issued_by: 'Ofc. Park',
          department: 'LSPD',
          report_id: 'RPT-20260314-0039',
          bolo_id: 'BOLO-0012',
          created_at: '2026-03-14T18:20:00Z',
          officer_first: 'Jin',
          officer_last: 'Park',
        },
        {
          id: 3,
          citizen_id: 'CIT-10015',
          citizen_name: 'Terrence Okafor',
          charges: ['Felony Possession', 'Distribution of Controlled Substance'],
          description: 'Warrant issued following narcotics investigation. Suspect found with over 50 grams of methamphetamine.',
          status: 'served',
          issued_by: 'Sgt. Delgado',
          department: 'LSPD',
          report_id: null,
          bolo_id: null,
          created_at: '2026-03-12T09:00:00Z',
          officer_first: 'Elena',
          officer_last: 'Delgado',
        },
        {
          id: 4,
          citizen_id: 'CIT-10091',
          citizen_name: 'Kyle Brennan',
          charges: ['Domestic Violence'],
          description: 'Warrant for arrest on domestic violence charges. Victim obtained a protective order.',
          status: 'expired',
          issued_by: 'Ofc. Rivera',
          department: 'BCSO',
          report_id: null,
          bolo_id: null,
          created_at: '2026-03-08T11:45:00Z',
          officer_first: 'Marco',
          officer_last: 'Rivera',
        },
        {
          id: 5,
          citizen_id: 'CIT-10033',
          citizen_name: 'Alexis Whitmore',
          charges: ['Fraud', 'Identity Theft', 'Money Laundering'],
          description: 'Subject involved in a multi-count white-collar crime investigation. Warrant quashed due to procedural error.',
          status: 'quashed',
          issued_by: 'Det. Kim',
          department: 'LSPD',
          report_id: 'RPT-20260310-0031',
          bolo_id: null,
          created_at: '2026-03-05T16:00:00Z',
          officer_first: 'Soo-yeon',
          officer_last: 'Kim',
        },
      ];
    } else {
      loadWarrants();
    }
  });
</script>

<div class="warrants-page" class:mounted>
  {#if mode === 'list'}
    <div class="list-mode warrant-shell">
      <header class="page-header">
        <div class="header-left">
          <h2 class="page-title">Warrants</h2>
          <p class="page-subtitle">Manage arrest warrants and court orders</p>
        </div>
        <button type="button" class="btn-new" onclick={openCreate}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
          </svg>
          <span>New Warrant</span>
        </button>
      </header>

      <div class="toolbar-grid" role="toolbar" aria-label="Warrant filters and search">
        <div class="filter-bar">
          {#each [['active', 'Active'], ['all', 'All']] as [key, label]}
            <button
              type="button"
              class="filter-tab"
              class:active={activeFilter === key}
              aria-pressed={activeFilter === key}
              onclick={() => switchFilter(key)}
            >{label}</button>
          {/each}
        </div>
        <div class="search-bar">
          <label class="sr-only" for="warrant-search">Filter by name or charge</label>
          <svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
          </svg>
          <input
            id="warrant-search"
            type="search"
            class="search-input"
            placeholder="Filter by name or charge..."
            autocomplete="off"
            bind:value={searchQuery}
          />
          {#if searchQuery}
            <button type="button" class="search-clear" onclick={() => { searchQuery = ''; }} aria-label="Clear search">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M18 6L6 18M6 6l12 12" />
              </svg>
            </button>
          {/if}
        </div>
      </div>

      {#if !loading && warrants.length > 0}
        <div class="summary-strip" aria-live="polite">
          <span class="summary-total"><span class="summary-num font-mono">{statusSummary.total}</span> showing</span>
          <span class="summary-div" aria-hidden="true"></span>
          <span class="summary-chip summary-active">Active <span class="font-mono">{statusSummary.active}</span></span>
          <span class="summary-chip summary-served">Served <span class="font-mono">{statusSummary.served}</span></span>
          <span class="summary-chip summary-expired">Expired <span class="font-mono">{statusSummary.expired}</span></span>
          <span class="summary-chip summary-quashed">Quashed <span class="font-mono">{statusSummary.quashed}</span></span>
        </div>
      {/if}

      {#if loading}
        <div class="skeleton-list" aria-busy="true" aria-label="Loading warrants">
          {#each [0, 1, 2, 3] as sk (sk)}
            <div class="warrant-skeleton">
              <div class="sk-accent"></div>
              <div class="sk-body">
                <div class="sk-row sk-row-top">
                  <div class="sk-block sk-title"></div>
                  <div class="sk-block sk-badge"></div>
                </div>
                <div class="sk-charges">
                  <div class="sk-block sk-charge-block"></div>
                  <div class="sk-block sk-charge-block sk-charge-block-short"></div>
                </div>
                <div class="sk-block sk-line"></div>
                <div class="sk-block sk-line sk-line-short"></div>
                <div class="sk-row sk-row-bottom">
                  <div class="sk-block sk-meta"></div>
                  <div class="sk-block sk-meta sk-meta-short"></div>
                </div>
              </div>
            </div>
          {/each}
        </div>
      {:else if filteredWarrants.length > 0}
        <div class="warrants-list">
          {#each filteredWarrants as warrant, i (warrant.id || i)}
            <div
              class="warrant-card"
              class:status-active={warrant.status === 'active'}
              class:status-served={warrant.status === 'served'}
              class:status-expired={warrant.status === 'expired'}
              class:status-quashed={warrant.status === 'quashed'}
              style="animation-delay: {i * 0.04}s"
            >
              <div class="card-accent"></div>
              <div class="card-body">
                <div class="card-top">
                  <div class="card-identity">
                    <span class="citizen-name">{warrant.citizen_name || '\u2014'}</span>
                    <span class="citizen-id font-mono">{warrant.citizen_id || '\u2014'}</span>
                  </div>
                  <div class="card-meta-right">
                    <span class="status-badge" style="--badge-color: {getStatusColor(warrant.status)}">{statusLabel(warrant.status)}</span>
                    <span class="card-date font-mono">{formatDate(warrant.created_at)}</span>
                  </div>
                </div>

                <div class="card-charges">
                  {#each (warrant.charges || []) as charge, ci (charge + ci)}
                    <span class="warrant-charge {chargeToneClass(ci)}">{charge}</span>
                  {/each}
                </div>

                <p class="card-description">{truncate(warrant.description, 140)}</p>

                <div class="card-bottom">
                  <div class="card-officer">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                      <circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" />
                    </svg>
                    <span>{warrant.officer_first ? `${warrant.officer_first} ${warrant.officer_last}` : (typeof warrant.issued_by === 'string' ? warrant.issued_by : '\u2014')}</span>
                    {#if warrant.department}
                      <span class="card-dept">{warrant.department}</span>
                    {/if}
                  </div>
                  <div class="card-links">
                    {#if warrant.report_id}
                      <span class="link-badge font-mono">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
                        {warrant.report_id}
                      </span>
                    {/if}
                    {#if warrant.bolo_id}
                      <span class="link-badge font-mono">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" /></svg>
                        {warrant.bolo_id}
                      </span>
                    {/if}
                  </div>
                </div>

                {#if warrant.status === 'active'}
                  <div class="card-actions">
                    {#if confirmAction === `served-${warrant.id}`}
                      <div class="confirm-row">
                        <span class="confirm-text">Mark as served?</span>
                        <button type="button" class="confirm-yes" onclick={() => handleStatusChange(warrant.id, 'served')}>Yes</button>
                        <button type="button" class="confirm-no" onclick={() => { confirmAction = null; }}>No</button>
                      </div>
                    {:else if confirmAction === `expired-${warrant.id}`}
                      <div class="confirm-row">
                        <span class="confirm-text">Mark as expired?</span>
                        <button type="button" class="confirm-yes" onclick={() => handleStatusChange(warrant.id, 'expired')}>Yes</button>
                        <button type="button" class="confirm-no" onclick={() => { confirmAction = null; }}>No</button>
                      </div>
                    {:else if confirmAction === `quashed-${warrant.id}`}
                      <div class="confirm-row">
                        <span class="confirm-text">Quash this warrant?</span>
                        <button type="button" class="confirm-yes" onclick={() => handleStatusChange(warrant.id, 'quashed')}>Yes</button>
                        <button type="button" class="confirm-no" onclick={() => { confirmAction = null; }}>No</button>
                      </div>
                    {:else}
                      <button
                        type="button"
                        class="action-btn action-served"
                        onclick={() => { confirmAction = `served-${warrant.id}`; }}
                        disabled={saving}
                      >
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12" /></svg>
                        Mark Served
                      </button>
                      <button
                        type="button"
                        class="action-btn action-expired"
                        onclick={() => { confirmAction = `expired-${warrant.id}`; }}
                        disabled={saving}
                      >
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" /></svg>
                        Expire
                      </button>
                      <button
                        type="button"
                        class="action-btn action-quashed"
                        onclick={() => { confirmAction = `quashed-${warrant.id}`; }}
                        disabled={saving}
                      >
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12" /></svg>
                        Quash
                      </button>
                    {/if}
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty-state">
          <svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <line x1="9" y1="15" x2="15" y2="15" />
          </svg>
          <p class="empty-text">No warrants match</p>
          <p class="empty-sub">{searchQuery ? 'Clear the filter or try another name or charge.' : 'Issue a warrant against a citizen to list it here.'}</p>
          {#if !searchQuery}
            <button type="button" class="btn-new empty-cta" onclick={openCreate}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
              </svg>
              <span>New Warrant</span>
            </button>
          {/if}
        </div>
      {/if}
    </div>

  {:else if mode === 'create'}
    <div class="create-mode warrant-shell">
      <button type="button" class="back-btn" onclick={cancelCreate}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to Warrants</span>
      </button>

      <header class="create-header">
        <h2 class="section-title">Issue Warrant</h2>
        <p class="create-lead">Select a citizen, add one or more charges, then link an existing report or BOLO if needed.</p>
      </header>

      <div class="form-card form-card-grid">
        <div class="form-col form-col-main">
        <div class="form-group">
          <label class="form-label" for="citizen-lookup-input">Citizen</label>
          <div class="citizen-lookup">
            <div class="lookup-input-wrap">
              <svg class="lookup-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
              </svg>
              <input
                id="citizen-lookup-input"
                type="text"
                class="form-input lookup-input"
                placeholder="Search by name or citizen ID..."
                value={citizenQuery}
                oninput={handleCitizenInput}
                onfocus={() => { if (citizenResults.length > 0) showCitizenDropdown = true; }}
                onblur={() => { setTimeout(() => { showCitizenDropdown = false; }, 200); }}
              />
              {#if selectedCitizenId}
                <span class="lookup-selected">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12" /></svg>
                </span>
              {/if}
            </div>
            {#if showCitizenDropdown && citizenResults.length > 0}
              <div class="citizen-dropdown">
                {#each citizenResults as cit, ci (cit.citizen_id || ci)}
                  <button type="button" class="dropdown-item" onmousedown={() => selectCitizen(cit)}>
                    <span class="dropdown-name">{cit.first_name} {cit.last_name}</span>
                    <span class="dropdown-cid font-mono">{cit.citizen_id}</span>
                    {#if cit.dob}
                      <span class="dropdown-dob font-mono">{cit.dob}</span>
                    {/if}
                  </button>
                {/each}
              </div>
            {/if}
          </div>
          {#if selectedCitizenId}
            <div class="selected-citizen-info">
              <span class="selected-name">{selectedCitizenName}</span>
              <span class="selected-cid font-mono">{selectedCitizenId}</span>
            </div>
          {/if}
        </div>

        <div class="form-group">
          <label class="form-label" for="warrant-charges-input">Charges</label>
          <div class="tags-wrapper">
            {#each charges as charge, ci (charge + ci)}
              <span class="charge-tag {chargeToneClass(ci)}">
                <span>{charge}</span>
                <button type="button" class="tag-remove" aria-label="Remove {charge}" onclick={() => removeCharge(charge)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12" /></svg>
                </button>
              </span>
            {/each}
            <input
              id="warrant-charges-input"
              type="text"
              class="tag-input"
              placeholder={charges.length === 0 ? 'Type a charge and press Enter...' : 'Add another...'}
              bind:value={chargeInput}
              onkeydown={handleChargeKey}
            />
          </div>
        </div>
        </div>

        <div class="form-col form-col-side">
        <div class="form-group">
          <label class="form-label" for="warrant-desc">Description</label>
          <textarea
            id="warrant-desc"
            class="form-textarea"
            placeholder="Provide details about the warrant..."
            bind:value={description}
            rows="6"
          ></textarea>
        </div>

        <div class="form-row">
          <div class="form-group form-half">
            <label class="form-label" for="warrant-report-id">Linked Report ID (optional)</label>
            <input
              id="warrant-report-id"
              type="text"
              class="form-input font-mono"
              placeholder="RPT-XXXXXXXX-XXXX"
              bind:value={reportId}
            />
          </div>
          <div class="form-group form-half">
            <label class="form-label" for="warrant-bolo-id">Linked BOLO ID (optional)</label>
            <input
              id="warrant-bolo-id"
              type="text"
              class="form-input font-mono"
              placeholder="BOLO-XXXX"
              bind:value={boloId}
            />
          </div>
        </div>
        </div>

        <div class="form-actions form-actions-span">
          <button type="button" class="btn-cancel" onclick={cancelCreate}>Cancel</button>
          <button
            type="button"
            class="btn-primary"
            onclick={handleCreate}
            disabled={!selectedCitizenId || charges.length === 0 || saving}
          >
            {saving ? 'Issuing...' : 'Issue Warrant'}
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }

  .warrants-page {
    width: 100%;
    min-width: 0;
    box-sizing: border-box;
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale));
    height: 100%;
    opacity: 0;
    transform: translateY(calc(8px * var(--mdt-scale)));
  }

  .warrants-page.mounted {
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .list-mode,
  .create-mode {
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .warrant-shell {
    width: 100%;
    min-width: 0;
    align-self: stretch;
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
    padding: calc(8px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    border: none;
    border-radius: var(--mdt-radius);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
    white-space: nowrap;
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

  .toolbar-grid {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: calc(10px * var(--mdt-scale));
    align-items: stretch;
  }

  @media (max-width: 640px) {
    .toolbar-grid {
      grid-template-columns: 1fr;
    }
  }

  .summary-strip {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
  }

  .summary-total {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-weight: 500;
  }

  .summary-num {
    color: var(--mdt-text);
    font-weight: 600;
    margin-right: calc(2px * var(--mdt-scale));
  }

  .summary-div {
    width: 1px;
    height: calc(14px * var(--mdt-scale));
    background: var(--mdt-border-2);
    margin-inline: calc(2px * var(--mdt-scale));
  }

  .summary-chip {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
    padding: calc(3px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
  }

  .summary-chip .font-mono {
    margin-left: calc(4px * var(--mdt-scale));
    opacity: 0.95;
  }

  .summary-active {
    border-color: color-mix(in srgb, var(--mdt-error) 35%, var(--mdt-border));
    color: var(--mdt-error);
  }

  .summary-served {
    border-color: color-mix(in srgb, var(--mdt-success) 35%, var(--mdt-border));
    color: var(--mdt-success);
  }

  .summary-expired {
    border-color: var(--mdt-border-2);
    color: var(--mdt-text-muted);
  }

  .summary-quashed {
    border-color: color-mix(in srgb, var(--mdt-warning) 35%, var(--mdt-border));
    color: var(--mdt-warning);
  }

  .skeleton-list {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .warrant-skeleton {
    display: flex;
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    overflow: hidden;
    min-height: calc(120px * var(--mdt-scale));
  }

  .sk-accent {
    width: calc(4px * var(--mdt-scale));
    flex-shrink: 0;
    background: var(--mdt-surface-3);
  }

  .sk-body {
    flex: 1;
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .sk-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
  }

  .sk-block {
    border-radius: var(--mdt-radius-sm);
    background: linear-gradient(
      90deg,
      var(--mdt-surface-3) 0%,
      var(--mdt-surface-2) 45%,
      var(--mdt-surface-3) 90%
    );
    background-size: 200% 100%;
    animation: skShimmer 1.4s cubic-bezier(0.4, 0, 0.2, 1) infinite;
  }

  .sk-title {
    height: calc(14px * var(--mdt-scale));
    width: 42%;
    max-width: calc(220px * var(--mdt-scale));
  }

  .sk-badge {
    height: calc(18px * var(--mdt-scale));
    width: calc(56px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
  }

  .sk-charges {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
  }

  .sk-charge-block {
    height: calc(18px * var(--mdt-scale));
    width: calc(88px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
  }

  .sk-charge-block-short {
    width: calc(64px * var(--mdt-scale));
  }

  .sk-line {
    height: calc(10px * var(--mdt-scale));
    width: 100%;
  }

  .sk-line-short {
    width: 72%;
  }

  .sk-meta {
    height: calc(11px * var(--mdt-scale));
    width: calc(140px * var(--mdt-scale));
  }

  .sk-meta-short {
    width: calc(72px * var(--mdt-scale));
  }

  @keyframes skShimmer {
    0% { background-position: 100% 0; }
    100% { background-position: -100% 0; }
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
    padding: calc(8px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: transparent;
    border: none;
    border-radius: var(--mdt-radius-sm);
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: color 0.15s ease, background 0.15s ease;
    white-space: nowrap;
  }

  .filter-tab:hover {
    color: var(--mdt-text-dim);
    background: var(--mdt-surface-2);
  }

  .filter-tab.active {
    color: var(--mdt-accent);
    background: var(--mdt-surface-3);
  }

  .search-bar {
    position: relative;
    display: flex;
    align-items: center;
    flex: 1;
  }

  .search-icon {
    position: absolute;
    left: calc(12px * var(--mdt-scale));
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) calc(9px * var(--mdt-scale)) calc(34px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
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
    width: calc(22px * var(--mdt-scale));
    height: calc(22px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    color: var(--mdt-text-muted);
    cursor: pointer;
    padding: 0;
    transition: color 0.15s ease;
  }

  .search-clear svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .search-clear:hover {
    color: var(--mdt-text);
  }

  .warrants-list {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .warrant-card {
    display: flex;
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    overflow: hidden;
    transition: border-color 0.15s ease, transform 0.1s ease;
    opacity: 0;
    animation: cardIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .warrant-card:hover {
    border-color: var(--mdt-border-2);
  }

  .card-accent {
    width: calc(4px * var(--mdt-scale));
    flex-shrink: 0;
    transition: background 0.2s ease;
  }

  .status-active .card-accent {
    background: var(--mdt-error);
  }

  .status-served .card-accent {
    background: var(--mdt-success);
  }

  .status-expired .card-accent {
    background: var(--mdt-text-muted);
    opacity: 0.5;
  }

  .status-quashed .card-accent {
    background: var(--mdt-warning);
    opacity: 0.7;
  }

  .status-expired,
  .status-quashed {
    opacity: 0.65;
  }

  .status-expired:hover,
  .status-quashed:hover {
    opacity: 0.8;
  }

  .card-body {
    flex: 1;
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    min-width: 0;
  }

  .card-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
  }

  .card-identity {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .citizen-name {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .citizen-id {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .card-meta-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: calc(4px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    background: color-mix(in srgb, var(--badge-color) 15%, transparent);
    color: var(--badge-color);
    border: 1px solid color-mix(in srgb, var(--badge-color) 25%, transparent);
    white-space: nowrap;
    line-height: 1.4;
  }

  .card-date {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .card-charges {
    display: flex;
    flex-wrap: wrap;
    gap: calc(5px * var(--mdt-scale));
  }

  .warrant-charge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(9px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    white-space: nowrap;
    line-height: 1.4;
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
  }

  .warrant-charge.tone-0 {
    background: color-mix(in srgb, var(--mdt-accent) 10%, var(--mdt-surface-2));
    color: var(--mdt-text);
    border-color: color-mix(in srgb, var(--mdt-accent) 22%, var(--mdt-border));
  }

  .warrant-charge.tone-1 {
    background: color-mix(in srgb, var(--mdt-accent) 16%, var(--mdt-surface-2));
    color: var(--mdt-text);
    border-color: color-mix(in srgb, var(--mdt-accent) 30%, var(--mdt-border));
  }

  .warrant-charge.tone-2 {
    background: color-mix(in srgb, var(--mdt-accent) 22%, var(--mdt-surface-2));
    color: var(--mdt-text);
    border-color: color-mix(in srgb, var(--mdt-accent) 38%, var(--mdt-border));
  }

  .card-description {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .card-bottom {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
  }

  .card-officer {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .card-officer svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    opacity: 0.5;
    flex-shrink: 0;
  }

  .card-dept {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding: calc(1px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
  }

  .card-links {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .link-badge {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    padding: calc(2px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
  }

  .link-badge svg {
    width: calc(10px * var(--mdt-scale));
    height: calc(10px * var(--mdt-scale));
    opacity: 0.5;
  }

  .card-actions {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
    margin-top: calc(4px * var(--mdt-scale));
    padding-top: calc(10px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
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
    transition: background 0.12s ease, transform 0.1s ease;
    border: 1px solid;
  }

  .action-btn svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
  }

  .action-btn:active {
    transform: scale(0.96);
  }

  .action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .action-served {
    color: var(--mdt-success);
    background: color-mix(in srgb, var(--mdt-success) 8%, transparent);
    border-color: color-mix(in srgb, var(--mdt-success) 25%, transparent);
  }

  .action-served:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-success) 15%, transparent);
  }

  .action-expired {
    color: var(--mdt-text-dim);
    background: color-mix(in srgb, var(--mdt-text-muted) 8%, transparent);
    border-color: color-mix(in srgb, var(--mdt-text-muted) 25%, transparent);
  }

  .action-expired:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-text-muted) 15%, transparent);
  }

  .action-quashed {
    color: var(--mdt-warning);
    background: color-mix(in srgb, var(--mdt-warning) 8%, transparent);
    border-color: color-mix(in srgb, var(--mdt-warning) 25%, transparent);
  }

  .action-quashed:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-warning) 15%, transparent);
  }

  .confirm-row {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    animation: fadeIn 0.15s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    width: 100%;
  }

  .confirm-text {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    flex: 1;
  }

  .confirm-yes,
  .confirm-no {
    padding: calc(4px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    font-family: 'Outfit', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.12s ease, transform 0.1s ease;
  }

  .confirm-yes:active,
  .confirm-no:active {
    transform: scale(0.96);
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

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: calc(56px * var(--mdt-scale)) calc(24px * var(--mdt-scale));
    gap: calc(10px * var(--mdt-scale));
    text-align: center;
    border: 1px dashed var(--mdt-border-2);
    border-radius: var(--mdt-radius-lg);
    background: color-mix(in srgb, var(--mdt-surface) 88%, transparent);
  }

  .empty-cta {
    margin-top: calc(8px * var(--mdt-scale));
  }

  .empty-icon {
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .empty-text {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .empty-sub {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    max-width: calc(36ch * var(--mdt-scale));
    line-height: 1.5;
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

  .create-header {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    max-width: calc(62ch * var(--mdt-scale));
  }

  .create-lead {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.55;
  }

  .form-card {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    padding: calc(20px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(18px * var(--mdt-scale));
  }

  .form-card-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: calc(18px * var(--mdt-scale));
  }

  @media (min-width: 900px) {
    .form-card-grid {
      grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
      align-items: start;
      gap: 0;
    }

    .form-col-main {
      padding-right: calc(18px * var(--mdt-scale));
      border-right: 1px solid var(--mdt-border);
    }

    .form-col-side {
      padding-left: calc(18px * var(--mdt-scale));
    }

    .form-actions-span {
      grid-column: 1 / -1;
    }
  }

  .form-col {
    display: flex;
    flex-direction: column;
    gap: calc(18px * var(--mdt-scale));
    min-width: 0;
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
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr;
    gap: calc(12px * var(--mdt-scale));
  }

  @media (min-width: 520px) {
    .form-row {
      grid-template-columns: 1fr 1fr;
    }
  }

  .form-half {
    min-width: 0;
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

  .citizen-lookup {
    position: relative;
  }

  .lookup-input-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }

  .lookup-icon {
    position: absolute;
    left: calc(12px * var(--mdt-scale));
    width: calc(15px * var(--mdt-scale));
    height: calc(15px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    pointer-events: none;
  }

  .lookup-input {
    padding-left: calc(34px * var(--mdt-scale));
    padding-right: calc(32px * var(--mdt-scale));
  }

  .lookup-selected {
    position: absolute;
    right: calc(10px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(18px * var(--mdt-scale));
    height: calc(18px * var(--mdt-scale));
    color: var(--mdt-success);
    pointer-events: none;
  }

  .lookup-selected svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .citizen-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    margin-top: calc(4px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border-2);
    border-radius: var(--mdt-radius-sm);
    max-height: calc(200px * var(--mdt-scale));
    overflow-y: auto;
    z-index: 50;
    animation: dropdownIn 0.15s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .dropdown-item {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    width: 100%;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: none;
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text);
    cursor: pointer;
    transition: background 0.12s ease;
    text-align: left;
  }

  .dropdown-item:last-child {
    border-bottom: none;
  }

  .dropdown-item:hover {
    background: var(--mdt-surface-3);
  }

  .dropdown-name {
    font-weight: 600;
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .dropdown-cid {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0.7;
    flex-shrink: 0;
  }

  .dropdown-dob {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .selected-citizen-info {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: color-mix(in srgb, var(--mdt-accent) 8%, transparent);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 20%, transparent);
    border-radius: var(--mdt-radius-sm);
    animation: fadeIn 0.15s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .selected-name {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-accent);
  }

  .selected-cid {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0.6;
  }

  .tags-wrapper {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    min-height: calc(38px * var(--mdt-scale));
    align-items: center;
    transition: border-color 0.15s ease;
  }

  .tags-wrapper:focus-within {
    border-color: var(--mdt-accent);
  }

  .charge-tag {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(3px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    color: var(--mdt-text-dim);
    animation: fadeIn 0.15s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .charge-tag.tone-0 {
    background: color-mix(in srgb, var(--mdt-accent) 12%, var(--mdt-surface-3));
    color: var(--mdt-text);
    border-color: color-mix(in srgb, var(--mdt-accent) 24%, var(--mdt-border));
  }

  .charge-tag.tone-1 {
    background: color-mix(in srgb, var(--mdt-accent) 18%, var(--mdt-surface-3));
    color: var(--mdt-text);
    border-color: color-mix(in srgb, var(--mdt-accent) 32%, var(--mdt-border));
  }

  .charge-tag.tone-2 {
    background: color-mix(in srgb, var(--mdt-accent) 24%, var(--mdt-surface-3));
    color: var(--mdt-text);
    border-color: color-mix(in srgb, var(--mdt-accent) 40%, var(--mdt-border));
  }

  .tag-remove {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    border: none;
    background: none;
    color: inherit;
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
    min-width: calc(120px * var(--mdt-scale));
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

  .font-mono {
    font-family: 'Share Tech Mono', monospace;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes cardIn {
    from { opacity: 0; transform: translateY(calc(10px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes dropdownIn {
    from { opacity: 0; transform: translateY(calc(-4px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
