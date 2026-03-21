<script>
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const FLAG_DEFS = [
    { key: 'violent', label: 'Violent', color: '#ef4444' },
    { key: 'felon', label: 'Felon', color: '#f97316' },
    { key: 'active_warrant', label: 'Active Warrant', color: '#eab308' },
    { key: 'medical_alert', label: 'Medical Alert', color: '#3b82f6' },
    { key: 'mental_health', label: 'Mental Health', color: '#a855f7' },
    { key: 'gang_affiliated', label: 'Gang Affiliated', color: '#ec4899' },
    { key: 'known_armed', label: 'Known Armed', color: '#dc2626' },
    { key: 'missing_person', label: 'Missing Person', color: '#06b6d4' },
  ];

  let searchQuery = $state('');
  let debounceTimer = $state(null);
  let activeTab = $state('vehicles');
  let notesInput = $state('');
  let mugshotInput = $state('');
  let editedFlags = $state([]);
  let saving = $state(false);

  let results = $derived(dataStore.citizenSearchResults || []);
  let selected = $derived(dataStore.selectedCitizen);
  let citizen = $derived(selected?.citizen || null);
  let isProfile = $derived(!!selected);

  $effect(() => {
    if (citizen) {
      notesInput = citizen.notes || '';
      mugshotInput = citizen.mugshot || '';
      editedFlags = [...(citizen.flags || [])];
    }
  });

  function handleSearchInput(e) {
    searchQuery = e.target.value;
    if (debounceTimer) clearTimeout(debounceTimer);
    if (!searchQuery.trim()) {
      dataStore.clearCitizenSearch();
      return;
    }
    debounceTimer = setTimeout(() => {
      dataStore.searchCitizens(searchQuery.trim());
    }, 300);
  }

  function openProfile(citizenId) {
    dataStore.getCitizen(citizenId);
    activeTab = 'vehicles';
  }

  function goBack() {
    dataStore.selectedCitizen = null;
  }

  function toggleFlag(key) {
    if (editedFlags.includes(key)) {
      editedFlags = editedFlags.filter(f => f !== key);
    } else {
      editedFlags = [...editedFlags, key];
    }
  }

  async function saveNotes() {
    if (!citizen) return;
    saving = true;
    await dataStore.updateCitizen({ citizenId: citizen.citizen_id, notes: notesInput });
    saving = false;
  }

  async function saveMugshot() {
    if (!citizen) return;
    saving = true;
    await dataStore.updateCitizen({ citizenId: citizen.citizen_id, mugshot: mugshotInput });
    saving = false;
  }

  async function saveFlags() {
    if (!citizen) return;
    saving = true;
    await dataStore.updateCitizen({ citizenId: citizen.citizen_id, flags: editedFlags });
    saving = false;
  }

  function getFlagDef(key) {
    return FLAG_DEFS.find(f => f.key === key) || { key, label: key, color: '#6b7280' };
  }

  function formatDate(dateStr) {
    if (!dateStr) return '—';
    return dateStr;
  }
</script>

<div class="citizens-page">
  {#if !isProfile}
    <div class="search-mode" >
      <div class="page-header">
        <h2 class="page-title">Citizens</h2>
        <p class="page-subtitle">Search civilian records</p>
      </div>

      <div class="search-bar">
        <svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
        </svg>
        <input
          type="text"
          class="search-input"
          placeholder="Search by name, citizen ID, or phone..."
          value={searchQuery}
          oninput={handleSearchInput}
        />
        {#if searchQuery}
          <button class="search-clear" aria-label="Clear search" onclick={() => { searchQuery = ''; dataStore.clearCitizenSearch(); }}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        {/if}
      </div>

      {#if results.length > 0}
        <div class="results-table">
          <div class="table-header">
            <span class="th-name">Name</span>
            <span class="th-id">Citizen ID</span>
            <span class="th-dob">DOB</span>
            <span class="th-gender">Gender</span>
            <span class="th-flags">Flags</span>
          </div>
          {#each results as row, i (row.id || row.citizen_id || i)}
            <button class="table-row" onclick={() => openProfile(row.citizen_id)}>
              <span class="td-name">{row.first_name} {row.last_name}</span>
              <span class="td-id font-mono">{row.citizen_id}</span>
              <span class="td-dob font-mono">{formatDate(row.dob)}</span>
              <span class="td-gender">{row.gender || '—'}</span>
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
            <circle cx="11" cy="11" r="8" /><path d="M21 21l-4.35-4.35" />
            <path d="M8 11h6" />
          </svg>
          <p class="empty-text">No citizens found</p>
          <p class="empty-sub">Try a different search term</p>
        </div>
      {/if}
    </div>
  {:else}
    <div class="profile-mode">
      <button class="back-btn" onclick={goBack}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
        <span>Back to Search</span>
      </button>

      <div class="profile-header">
        <div class="mugshot-frame">
          {#if citizen.mugshot}
            <img src={citizen.mugshot} alt="Mugshot" class="mugshot-img" />
          {:else}
            <div class="mugshot-placeholder">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" />
              </svg>
            </div>
          {/if}
        </div>
        <div class="profile-info">
          <h2 class="profile-name">{citizen.first_name} {citizen.last_name}</h2>
          <span class="profile-cid font-mono">{citizen.citizen_id}</span>
          <div class="profile-meta">
            <span class="meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></svg>
              {formatDate(citizen.dob)}
            </span>
            <span class="meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10" /><path d="M12 8v4M12 16h.01" /></svg>
              {citizen.gender || '—'}
            </span>
            {#if citizen.phone}
              <span class="meta-item font-mono">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="2" width="14" height="20" rx="2" /><path d="M12 18h.01" /></svg>
                {citizen.phone}
              </span>
            {/if}
          </div>
          {#if editedFlags.length > 0}
            <div class="profile-flags">
              {#each editedFlags as flag (flag)}
                {@const def = getFlagDef(flag)}
                <span class="flag-badge" style="--flag-color: {def.color}">{def.label}</span>
              {/each}
            </div>
          {/if}
        </div>
      </div>

      <div class="profile-sections">
        <div class="section-row">
          <div class="section-card notes-card">
            <h3 class="section-label">Officer Notes</h3>
            <textarea
              class="notes-textarea"
              placeholder="Add notes about this citizen..."
              bind:value={notesInput}
              rows="4"
            ></textarea>
            <button class="btn-save" onclick={saveNotes} disabled={saving}>Save Notes</button>
          </div>

          <div class="section-card mugshot-card">
            <h3 class="section-label">Mugshot</h3>
            <div class="mugshot-edit-row">
              <div class="mugshot-mini-preview">
                {#if mugshotInput}
                  <img src={mugshotInput} alt="Preview" class="mugshot-mini-img" />
                {:else}
                  <div class="mugshot-mini-empty">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                      <rect x="3" y="3" width="18" height="18" rx="2" /><circle cx="8.5" cy="8.5" r="1.5" /><path d="M21 15l-5-5L5 21" />
                    </svg>
                  </div>
                {/if}
              </div>
              <div class="mugshot-input-group">
                <input
                  type="text"
                  class="text-input"
                  placeholder="https://example.com/mugshot.png"
                  bind:value={mugshotInput}
                />
                <button class="btn-save" onclick={saveMugshot} disabled={saving}>Save</button>
              </div>
            </div>
          </div>
        </div>

        <div class="section-card flags-card">
          <h3 class="section-label">Flags</h3>
          <div class="flags-grid">
            {#each FLAG_DEFS as def (def.key)}
              <button
                class="flag-toggle"
                class:active={editedFlags.includes(def.key)}
                style="--flag-color: {def.color}"
                onclick={() => toggleFlag(def.key)}
              >
                <span class="flag-dot"></span>
                <span>{def.label}</span>
              </button>
            {/each}
          </div>
          <button class="btn-save" onclick={saveFlags} disabled={saving}>Save Flags</button>
        </div>

        <div class="section-card tabs-card">
          <div class="tabs-bar">
            {#each ['vehicles', 'reports', 'warrants', 'licenses'] as tab (tab)}
              <button
                class="tab-btn"
                class:active={activeTab === tab}
                onclick={() => activeTab = tab}
              >{tab[0].toUpperCase() + tab.slice(1)}</button>
            {/each}
          </div>

          <div class="tab-content">
            {#if activeTab === 'vehicles'}
              {#if selected.vehicles?.length > 0}
                <div class="list-table">
                  <div class="list-header">
                    <span>Plate</span>
                    <span>Model</span>
                    <span>Status</span>
                  </div>
                  {#each selected.vehicles as v, i (v.plate || i)}
                    <button class="list-row">
                      <span class="font-mono">{v.plate}</span>
                      <span>{v.model || '—'}</span>
                      <span class="status-cell" class:status-good={v.status === 'registered'} class:status-bad={v.status === 'stolen'}>{v.status || '—'}</span>
                    </button>
                  {/each}
                </div>
              {:else}
                <p class="tab-empty">No vehicles on record</p>
              {/if}

            {:else if activeTab === 'reports'}
              {#if selected.reports?.length > 0}
                <div class="list-table">
                  <div class="list-header">
                    <span>Report #</span>
                    <span>Title</span>
                    <span>Status</span>
                    <span>Date</span>
                  </div>
                  {#each selected.reports as r, i (r.id || i)}
                    <button class="list-row list-row-4">
                      <span class="font-mono">{r.report_number || r.id}</span>
                      <span class="list-title">{r.title || '—'}</span>
                      <span class="status-cell" class:status-good={r.status === 'closed'} class:status-warn={r.status === 'open'}>{r.status || '—'}</span>
                      <span class="font-mono">{formatDate(r.date)}</span>
                    </button>
                  {/each}
                </div>
              {:else}
                <p class="tab-empty">No reports on record</p>
              {/if}

            {:else if activeTab === 'warrants'}
              {#if selected.warrants?.length > 0}
                <div class="list-table">
                  <div class="list-header">
                    <span>Charges</span>
                    <span>Status</span>
                  </div>
                  {#each selected.warrants as w, i (w.id || i)}
                    <button class="list-row list-row-2">
                      <span class="list-title">{w.charges || '—'}</span>
                      <span class="status-cell" class:status-bad={w.status === 'active'} class:status-good={w.status === 'served'}>{w.status || '—'}</span>
                    </button>
                  {/each}
                </div>
              {:else}
                <p class="tab-empty">No warrants on record</p>
              {/if}

            {:else if activeTab === 'licenses'}
              {#if selected.licenses?.length > 0}
                <div class="list-table">
                  <div class="list-header">
                    <span>Type</span>
                    <span>Status</span>
                  </div>
                  {#each selected.licenses as l, i (l.type || i)}
                    <button class="list-row list-row-2">
                      <span>{l.type}</span>
                      <span class="status-cell" class:status-good={l.status === 'valid'} class:status-bad={l.status === 'revoked'} class:status-warn={l.status === 'suspended'}>{l.status || '—'}</span>
                    </button>
                  {/each}
                </div>
              {:else}
                <p class="tab-empty">No licenses on record</p>
              {/if}
            {/if}
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .citizens-page {
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

  .profile-mode {
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    animation: fadeIn 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .page-header {
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
    font-family: inherit;
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
    grid-template-columns: 2fr 1.2fr 1fr 0.8fr 2fr;
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
    grid-template-columns: 2fr 1.2fr 1fr 0.8fr 2fr;
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

  .td-name {
    font-weight: 600;
    color: var(--mdt-text);
  }

  .td-id {
    color: var(--mdt-accent-dim);
    font-size: calc(11px * var(--mdt-scale));
  }

  .td-dob {
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
  }

  .td-gender {
    color: var(--mdt-text-dim);
    text-transform: capitalize;
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
    transform: scale(0.97);
  }

  .profile-header {
    display: flex;
    gap: calc(18px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-lg);
    padding: calc(20px * var(--mdt-scale));
    align-items: flex-start;
  }

  .mugshot-frame {
    width: calc(90px * var(--mdt-scale));
    height: calc(110px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 2px solid var(--mdt-border-2);
    background: var(--mdt-surface-2);
    overflow: hidden;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mugshot-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .mugshot-placeholder {
    width: calc(36px * var(--mdt-scale));
    height: calc(36px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .mugshot-placeholder svg {
    width: 100%;
    height: 100%;
  }

  .profile-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    min-width: 0;
  }

  .profile-name {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
    line-height: 1.1;
  }

  .profile-cid {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-accent-dim);
    letter-spacing: 0.04em;
  }

  .profile-meta {
    display: flex;
    flex-wrap: wrap;
    gap: calc(14px * var(--mdt-scale));
    margin-top: calc(4px * var(--mdt-scale));
  }

  .meta-item {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .meta-item svg {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    flex-shrink: 0;
    opacity: 0.6;
  }

  .profile-flags {
    display: flex;
    flex-wrap: wrap;
    gap: calc(5px * var(--mdt-scale));
    margin-top: calc(6px * var(--mdt-scale));
  }

  .profile-sections {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }

  .section-row {
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
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .notes-textarea {
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
  }

  .notes-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .notes-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .text-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(11px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .text-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .text-input:focus {
    border-color: var(--mdt-accent);
  }

  .mugshot-edit-row {
    display: flex;
    gap: calc(10px * var(--mdt-scale));
    align-items: flex-start;
  }

  .mugshot-mini-preview {
    width: calc(48px * var(--mdt-scale));
    height: calc(48px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    overflow: hidden;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mugshot-mini-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .mugshot-mini-empty {
    width: calc(20px * var(--mdt-scale));
    height: calc(20px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .mugshot-mini-empty svg {
    width: 100%;
    height: 100%;
  }

  .mugshot-input-group {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .btn-save {
    align-self: flex-start;
    padding: calc(6px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s ease, transform 0.1s ease;
  }

  .btn-save:hover {
    opacity: 0.9;
  }

  .btn-save:active {
    transform: scale(0.97);
  }

  .btn-save:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .flags-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(150px * var(--mdt-scale)), 1fr));
    gap: calc(6px * var(--mdt-scale));
  }

  .flag-toggle {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: border-color 0.15s ease, background 0.15s ease, transform 0.1s ease;
  }

  .flag-toggle:hover {
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-3);
  }

  .flag-toggle:active {
    transform: scale(0.97);
  }

  .flag-toggle.active {
    border-color: color-mix(in srgb, var(--flag-color) 50%, transparent);
    background: color-mix(in srgb, var(--flag-color) 10%, transparent);
    color: var(--flag-color);
  }

  .flag-dot {
    width: calc(8px * var(--mdt-scale));
    height: calc(8px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--flag-color);
    flex-shrink: 0;
    opacity: 0.5;
    transition: opacity 0.15s ease;
  }

  .flag-toggle.active .flag-dot {
    opacity: 1;
    box-shadow: 0 0 6px color-mix(in srgb, var(--flag-color) 50%, transparent);
  }

  .tabs-card {
    gap: 0;
    padding: 0;
    overflow: hidden;
  }

  .tabs-bar {
    display: flex;
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
  }

  .tab-btn {
    flex: 1;
    padding: calc(10px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    color: var(--mdt-text-muted);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease;
  }

  .tab-btn:hover {
    color: var(--mdt-text-dim);
  }

  .tab-btn.active {
    color: var(--mdt-accent);
    border-bottom-color: var(--mdt-accent);
  }

  .tab-content {
    padding: calc(14px * var(--mdt-scale));
    min-height: calc(80px * var(--mdt-scale));
  }

  .list-table {
    display: flex;
    flex-direction: column;
  }

  .list-header {
    display: grid;
    grid-template-columns: 1fr 1.5fr 0.8fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    border-bottom: 1px solid var(--mdt-border);
  }

  .list-row {
    display: grid;
    grid-template-columns: 1fr 1.5fr 0.8fr;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: none;
    border: none;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 50%, transparent);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition: background 0.12s ease;
    text-align: left;
    width: 100%;
  }

  .list-row:last-child {
    border-bottom: none;
  }

  .list-row:hover {
    background: color-mix(in srgb, var(--mdt-surface-2) 60%, transparent);
  }

  .list-row-4 {
    grid-template-columns: 1fr 2fr 0.8fr 1fr;
  }

  .list-row-2 {
    grid-template-columns: 2fr 1fr;
  }

  .list-row-4 + .list-row-4,
  .list-row-2 + .list-row-2 {
    border-top: none;
  }

  .list-table:has(.list-row-4) .list-header {
    grid-template-columns: 1fr 2fr 0.8fr 1fr;
  }

  .list-table:has(.list-row-2) .list-header {
    grid-template-columns: 2fr 1fr;
  }

  .list-title {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .status-cell {
    text-transform: capitalize;
    font-weight: 500;
  }

  .status-good {
    color: var(--mdt-success);
  }

  .status-bad {
    color: var(--mdt-error);
  }

  .status-warn {
    color: var(--mdt-warning);
  }

  .tab-empty {
    text-align: center;
    color: var(--mdt-text-muted);
    font-size: calc(12px * var(--mdt-scale));
    padding: calc(20px * var(--mdt-scale)) 0;
    opacity: 0.6;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
