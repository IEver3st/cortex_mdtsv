<script>
  import { onMount } from 'svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';

  const STATUS_OPTIONS = ['active', 'suspended', 'terminated', 'loa'];

  let query = $state('');
  let loading = $state(false);
  let saving = $state(false);
  let expandedOfficer = $state(null);
  let draft = $state({
    officerId: null,
    rank: '',
    callsign: '',
    department: '',
    status: 'active',
    certifications: [],
  });

  let roster = $derived(dataStore.adminRoster || []);
  let units = $derived(dataStore.unitsList || []);
  let config = $derived(dataStore.configData || {});
  let certifications = $derived(config.certifications || []);
  let departments = $derived(config.departments || []);
  let filteredRoster = $derived.by(() => {
    const search = query.trim().toLowerCase();
    if (!search) return roster;
    return roster.filter((officer) => [
      officer.first_name,
      officer.last_name,
      officer.callsign,
      officer.rank,
      officer.department,
    ].some((value) => (value || '').toLowerCase().includes(search)));
  });

  onMount(async () => {
    loading = true;
    await Promise.all([
      dataStore.fetchRoster(),
      dataStore.fetchUnits(),
      dataStore.fetchConfig(),
    ]);
    loading = false;
  });

  function unitFor(officerId) {
    return units.find((entry) => entry.officer_id === officerId);
  }

  function ranksForDepartment(department) {
    return config.ranks?.[department] || [];
  }

  function openEditor(officer) {
    expandedOfficer = officer.id;
    draft = {
      officerId: officer.id,
      rank: officer.rank || '',
      callsign: officer.callsign || '',
      department: officer.department || '',
      status: officer.status || 'active',
      certifications: [...(officer.certifications || [])],
    };
  }

  function toggleCertification(certification) {
    if (draft.certifications.includes(certification)) {
      draft = { ...draft, certifications: draft.certifications.filter((entry) => entry !== certification) };
      return;
    }
    draft = { ...draft, certifications: [...draft.certifications, certification] };
  }

  async function saveOfficer() {
    if (!draft.officerId) return;
    saving = true;
    const response = await dataStore.updateOfficer(draft);
    if (response?.ok) {
      await Promise.all([dataStore.fetchRoster(), dataStore.fetchUnits()]);
      expandedOfficer = null;
    }
    saving = false;
  }
</script>

<div class="roster-page">
  <header class="page-header">
    <div>
      <h2 class="page-title">Roster</h2>
      <p class="page-subtitle">Dedicated officer directory with live duty context and admin editing.</p>
    </div>
    <input class="search-input" bind:value={query} placeholder="Search roster..." />
  </header>

  {#if loading}
    <div class="empty-state">Loading roster...</div>
  {:else if filteredRoster.length === 0}
    <div class="empty-state">No officers match that search.</div>
  {:else}
    <section class="roster-list">
      {#each filteredRoster as officer (officer.id)}
        {@const liveUnit = unitFor(officer.id)}
        <article class="officer-card">
          <div class="card-head">
            <div class="card-head-left">
              {#if officer.avatar}
                <img class="roster-avatar" src={officer.avatar} alt="" />
              {:else}
                <div class="roster-avatar-empty">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" /></svg>
                </div>
              {/if}
              <div>
                <strong>{officer.first_name} {officer.last_name}</strong>
                <span>{officer.callsign || 'No callsign'} · {officer.rank || 'Officer'}</span>
              </div>
            </div>
            <button class="btn-small" onclick={() => openEditor(officer)}>
              {expandedOfficer === officer.id ? 'Editing' : 'Edit'}
            </button>
          </div>

          <div class="meta-grid">
            <div><small>Department</small><span>{officer.department || 'Unknown'}</span></div>
            <div><small>Roster Status</small><span>{officer.status || 'active'}</span></div>
            <div><small>Duty Status</small><span>{liveUnit?.status || 'off_duty'}</span></div>
            <div><small>Assignment</small><span>{liveUnit?.assignment || 'Unassigned'}</span></div>
          </div>

          {#if expandedOfficer === officer.id}
            <div class="editor">
              <div class="editor-grid">
                <label><span>Rank</span>
                  <select class="field" bind:value={draft.rank}>
                    {#each ranksForDepartment(draft.department) as rank (rank)}
                      <option value={rank}>{rank}</option>
                    {/each}
                  </select>
                </label>
                <label><span>Callsign</span><input class="field" bind:value={draft.callsign} /></label>
                <label><span>Department</span>
                  <select class="field" bind:value={draft.department}>
                    {#each departments as department (department)}
                      <option value={department}>{department}</option>
                    {/each}
                  </select>
                </label>
                <label><span>Status</span>
                  <select class="field" bind:value={draft.status}>
                    {#each STATUS_OPTIONS as option (option)}
                      <option value={option}>{option}</option>
                    {/each}
                  </select>
                </label>
              </div>

              <div class="cert-grid">
                {#each certifications as certification (certification)}
                  <button
                    class:active={draft.certifications.includes(certification)}
                    class="cert-pill"
                    onclick={() => toggleCertification(certification)}
                  >
                    {certification}
                  </button>
                {/each}
              </div>

              <div class="editor-actions">
                <button class="btn-primary" onclick={saveOfficer} disabled={saving}>
                  {saving ? 'Saving...' : 'Save Officer'}
                </button>
                <button class="btn-small" onclick={() => expandedOfficer = null}>Cancel</button>
              </div>
            </div>
          {/if}
        </article>
      {/each}
    </section>
  {/if}
</div>

<style>
  .roster-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    height: 100%;
    overflow: auto;
  }

  .page-header,
  .card-head,
  .meta-grid,
  .editor-grid,
  .editor-actions,
  .roster-list,
  .cert-grid {
    display: grid;
    gap: calc(12px * var(--mdt-scale));
  }

  .page-header {
    grid-template-columns: 1fr minmax(220px, 320px);
    align-items: center;
  }

  .page-title {
    font-size: calc(28px * var(--mdt-scale));
    color: var(--mdt-text);
  }

  .page-subtitle {
    color: var(--mdt-text-muted);
    font-size: calc(13px * var(--mdt-scale));
  }

  .search-input,
  .field,
  .btn-primary,
  .btn-small,
  .cert-pill {
    border: 1px solid var(--mdt-border);
    border-radius: calc(12px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font: inherit;
  }

  .search-input,
  .field {
    width: 100%;
    padding: calc(12px * var(--mdt-scale));
  }

  .btn-primary,
  .btn-small,
  .cert-pill {
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    cursor: pointer;
  }

  .officer-card {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: calc(18px * var(--mdt-scale));
    padding: calc(18px * var(--mdt-scale));
  }

  .card-head {
    grid-template-columns: 1fr auto;
    align-items: center;
  }

  .card-head-left {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
  }

  .roster-avatar {
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    border-radius: 50%;
    object-fit: cover;
    flex-shrink: 0;
    border: 1px solid var(--mdt-border);
  }

  .roster-avatar-empty {
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    border: 1px solid var(--mdt-border);
  }

  .roster-avatar-empty svg {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
  }

  .card-head strong {
    display: block;
    color: var(--mdt-text);
  }

  .card-head span,
  .meta-grid span,
  .meta-grid small {
    color: var(--mdt-text-muted);
  }

  .meta-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
    margin-top: calc(12px * var(--mdt-scale));
  }

  .meta-grid small {
    display: block;
    font-size: calc(11px * var(--mdt-scale));
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .editor {
    margin-top: calc(14px * var(--mdt-scale));
    padding-top: calc(14px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
  }

  .editor-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .editor-grid label {
    display: grid;
    gap: calc(8px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-size: calc(12px * var(--mdt-scale));
  }

  .cert-grid {
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    margin-top: calc(12px * var(--mdt-scale));
  }

  .cert-pill.active {
    background: color-mix(in srgb, var(--mdt-accent) 12%, var(--mdt-surface-2));
  }

  .editor-actions {
    grid-template-columns: auto auto;
    justify-content: end;
    margin-top: calc(12px * var(--mdt-scale));
  }

  .empty-state {
    padding: calc(24px * var(--mdt-scale));
    border: 1px dashed var(--mdt-border);
    border-radius: calc(14px * var(--mdt-scale));
    text-align: center;
    color: var(--mdt-text-muted);
  }

  @media (max-width: 1180px) {
    .page-header,
    .meta-grid,
    .editor-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
