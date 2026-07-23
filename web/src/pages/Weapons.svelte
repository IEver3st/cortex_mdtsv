<script>
  import { onMount } from 'svelte';
  import {
    ArrowLeft,
    Crosshair,
    Search,
    RefreshCw,
    Plus,
    Save,
    UserRound,
  } from '@lucide/svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';

  const STATUS_OPTIONS = ['registered', 'transferred', 'seized', 'evidence', 'stolen', 'destroyed'];
  const STATUS_COLORS = {
    registered: 'var(--mdt-success)',
    transferred: 'var(--mdt-text-muted)',
    seized: 'var(--mdt-warning)',
    evidence: 'var(--mdt-warning)',
    stolen: 'var(--mdt-error)',
    destroyed: 'var(--mdt-text-muted)',
  };

  const DEFAULT_FORM = {
    id: null,
    serialNumber: '',
    weaponType: '',
    make: '',
    model: '',
    caliber: '',
    ownerCitizenId: '',
    ownerName: '',
    status: 'registered',
    imageUrl: '',
    notes: '',
  };

  /** @type {'browse' | 'record'} */
  let pageMode = $state('browse');
  let loading = $state(true);
  let saving = $state(false);
  let transferring = $state(false);
  let errorMessage = $state('');
  let searchQuery = $state('');
  let form = $state({ ...DEFAULT_FORM });
  let transferForm = $state({
    ownerCitizenId: '',
    ownerName: '',
    status: 'registered',
    notes: '',
  });

  let weapons = $derived(dataStore.weaponsList || []);
  let selectedWeapon = $derived(dataStore.selectedWeapon);
  let history = $derived(dataStore.weaponHistory || []);
  let analytics = $derived.by(() => ({
    total: weapons.length,
    registered: weapons.filter((w) => w.status === 'registered').length,
    transferred: weapons.filter((w) => w.status === 'transferred').length,
    seized: weapons.filter((w) => w.status === 'seized').length,
    evidence: weapons.filter((w) => w.status === 'evidence').length,
    stolen: weapons.filter((w) => w.status === 'stolen').length,
  }));

  $effect(() => {
    if (!selectedWeapon) return;

    form = {
      id: selectedWeapon.id ?? null,
      serialNumber: selectedWeapon.serial_number || '',
      weaponType: selectedWeapon.weapon_type || '',
      make: selectedWeapon.make || '',
      model: selectedWeapon.model || '',
      caliber: selectedWeapon.caliber || '',
      ownerCitizenId: selectedWeapon.owner_citizen_id || '',
      ownerName: selectedWeapon.owner_name || '',
      status: selectedWeapon.status || 'registered',
      imageUrl: selectedWeapon.image_url || '',
      notes: selectedWeapon.notes || '',
    };

    transferForm = {
      ownerCitizenId: '',
      ownerName: '',
      status: selectedWeapon.status || 'registered',
      notes: '',
    };
  });

  function statusLabel(status) {
    return String(status || 'unknown').replaceAll('_', ' ');
  }

  function statusTone(status) {
    const normalized = String(status || '').toLowerCase();
    if (['registered'].includes(normalized)) return 'good';
    if (['transferred', 'destroyed'].includes(normalized)) return 'neutral';
    if (['seized', 'evidence'].includes(normalized)) return 'warn';
    if (['stolen'].includes(normalized)) return 'danger';
    return 'neutral';
  }

  function weaponTitle(w) {
    const t = w.weapon_type || w.make || 'Weapon';
    const m = [w.make, w.model].filter(Boolean).join(' ');
    return m && m !== t ? `${t} \u00b7 ${m}` : t;
  }

  function recordHeadline() {
    const m = [form.make, form.model].filter(Boolean).join(' ').trim();
    if (m) return m;
    if (form.weaponType.trim()) return form.weaponType.trim();
    return form.id ? 'Weapon record' : 'New registry entry';
  }

  function primaryIdentifier() {
    const sn = form.serialNumber?.trim();
    if (sn) return sn;
    if (form.id != null) return `WPN-${String(form.id).padStart(4, '0')}`;
    return 'New entry';
  }

  function statusCssColor(status) {
    const k = String(status || '').toLowerCase();
    return STATUS_COLORS[k] || 'var(--mdt-text-muted)';
  }

  function formatDate(v) {
    if (!v) return '\u2014';
    try {
      const d = new Date(v);
      return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
    } catch {
      return '\u2014';
    }
  }

  function formatDateTime(v) {
    if (!v) return '\u2014';
    try {
      return new Date(v).toLocaleString();
    } catch {
      return '\u2014';
    }
  }

  function goBrowse() {
    pageMode = 'browse';
    dataStore.selectedWeapon = null;
    dataStore.weaponHistory = [];
    form = { ...DEFAULT_FORM };
    transferForm = {
      ownerCitizenId: '',
      ownerName: '',
      status: 'registered',
      notes: '',
    };
  }

  function startNew() {
    dataStore.selectedWeapon = null;
    dataStore.weaponHistory = [];
    form = { ...DEFAULT_FORM };
    transferForm = {
      ownerCitizenId: '',
      ownerName: '',
      status: 'registered',
      notes: '',
    };
    pageMode = 'record';
  }

  async function refreshList() {
    errorMessage = '';
    const response = await dataStore.fetchWeapons(searchQuery.trim());
    if (!response?.ok) {
      errorMessage = response?.error || 'Unable to load weapons.';
    }
  }

  async function openWeapon(weaponId) {
    const response = await dataStore.getWeaponRecord(weaponId);
    if (!response?.ok) {
      errorMessage = response?.error || 'Unable to load weapon record.';
      return;
    }
    pageMode = 'record';
  }

  async function saveWeapon() {
    saving = true;
    errorMessage = '';

    const payload = {
      weaponId: form.id,
      serialNumber: form.serialNumber.trim(),
      weaponType: form.weaponType.trim(),
      make: form.make.trim(),
      model: form.model.trim(),
      caliber: form.caliber.trim(),
      ownerCitizenId: form.ownerCitizenId.trim(),
      ownerName: form.ownerName.trim(),
      status: form.status,
      imageUrl: form.imageUrl.trim(),
      notes: form.notes.trim(),
    };

    const response = form.id
      ? await dataStore.updateWeapon(payload)
      : await dataStore.createWeapon(payload);

    if (response?.ok) {
      await refreshList();
      if (response.weaponId || form.id) {
        await openWeapon(response.weaponId || form.id);
      } else {
        goBrowse();
      }
    } else {
      errorMessage = response?.error || 'Unable to save weapon record.';
    }

    saving = false;
  }

  async function transferWeapon() {
    if (!selectedWeapon) return;
    transferring = true;
    errorMessage = '';

    const response = await dataStore.transferWeapon({
      weaponId: selectedWeapon.id,
      ownerCitizenId: transferForm.ownerCitizenId.trim(),
      ownerName: transferForm.ownerName.trim(),
      status: transferForm.status,
      notes: transferForm.notes.trim(),
    });

    if (response?.ok) {
      transferForm = {
        ownerCitizenId: '',
        ownerName: '',
        status: selectedWeapon.status || 'registered',
        notes: '',
      };
      await refreshList();
      await openWeapon(selectedWeapon.id);
    } else {
      errorMessage = response?.error || 'Unable to transfer weapon.';
    }

    transferring = false;
  }

  onMount(async () => {
    loading = true;
    await refreshList();
    loading = false;
  });
</script>

<div class="wpn-page">
  {#if pageMode === 'browse'}
    <div class="wpn-browse">
      <header class="wpn-page-head">
        <div class="wpn-page-head-text">
          <p class="wpn-eyebrow">Registry</p>
          <h1 class="wpn-page-title">Weapons</h1>
          <p class="wpn-page-sub">Serials, custody, and ownership records.</p>
        </div>
        <div class="wpn-page-head-actions">
          <label class="wpn-search">
            <Search size={16} strokeWidth={2} aria-hidden="true" />
            <input
              bind:value={searchQuery}
              type="search"
              placeholder="Serial, owner, make, model\u2026"
              onkeydown={(event) => event.key === 'Enter' && refreshList()}
            />
          </label>
          <button type="button" class="wpn-btn-refresh" onclick={refreshList} disabled={loading || saving || transferring}>
            <span class:wpn-spin={loading} aria-hidden="true">
              <RefreshCw size={14} strokeWidth={2} />
            </span>
            Refresh
          </button>
          <button type="button" class="wpn-btn-primary" onclick={startNew}>
            <Plus size={14} strokeWidth={2} />
            New record
          </button>
        </div>
      </header>

      <div class="wpn-stat-strip" aria-label="Registry summary">
        <div class="wpn-stat-cell">
          <span class="wpn-meta-label">Total</span>
          <strong class="wpn-stat-num font-mono">{analytics.total}</strong>
        </div>
        <div class="wpn-stat-cell">
          <span class="wpn-meta-label">Registered</span>
          <strong class="wpn-stat-num font-mono wpn-stat-good">{analytics.registered}</strong>
        </div>
        <div class="wpn-stat-cell">
          <span class="wpn-meta-label">Transferred</span>
          <strong class="wpn-stat-num font-mono">{analytics.transferred}</strong>
        </div>
        <div class="wpn-stat-cell">
          <span class="wpn-meta-label">Seized / evidence</span>
          <strong class="wpn-stat-num font-mono wpn-stat-warn">{analytics.seized + analytics.evidence}</strong>
        </div>
        <div class="wpn-stat-cell">
          <span class="wpn-meta-label">Stolen</span>
          <strong class="wpn-stat-num font-mono wpn-stat-bad">{analytics.stolen}</strong>
        </div>
      </div>

      {#if errorMessage}
        <div class="wpn-error" role="alert">{errorMessage}</div>
      {/if}

      {#if loading}
        <div class="wpn-empty">Loading registry\u2026</div>
      {:else if weapons.length === 0}
        <div class="wpn-empty">No records match this search.</div>
      {:else}
        <div class="wpn-table-wrap">
          <div class="wpn-table-head">
            <span>Serial</span>
            <span>Weapon</span>
            <span>Owner</span>
            <span>Status</span>
          </div>
          {#each weapons as weapon (weapon.id)}
            <button type="button" class="wpn-table-row" onclick={() => openWeapon(weapon.id)}>
              <span class="wpn-td-serial font-mono">{weapon.serial_number || '\u2014'}</span>
              <span class="wpn-td-title">{weaponTitle(weapon)}</span>
              <span class="wpn-td-owner">{weapon.owner_name || weapon.owner_citizen_id || '\u2014'}</span>
              <span class="wpn-td-status">
                <span class="wpn-status-badge" data-tone={statusTone(weapon.status)}>{statusLabel(weapon.status)}</span>
              </span>
            </button>
          {/each}
        </div>
      {/if}
    </div>
  {:else}
    <div class="wpn-record">
      <div class="wpn-top-bar">
        <button type="button" class="wpn-back" onclick={goBrowse}>
          <ArrowLeft size={14} strokeWidth={2} aria-hidden="true" />
          <span>Back to registry</span>
        </button>
        <button type="button" class="wpn-save" onclick={saveWeapon} disabled={saving}>
          <Save size={15} strokeWidth={2} aria-hidden="true" />
          <span>{saving ? 'Saving\u2026' : form.id ? 'Save record' : 'Register'}</span>
        </button>
      </div>

      {#if errorMessage}
        <div class="wpn-error" role="alert">{errorMessage}</div>
      {/if}

      <header class="wpn-detail-header">
        <div class="wpn-report-line">
          <span class="wpn-meta-label">Serial / record ID</span>
          <p class="wpn-report-id font-mono">{primaryIdentifier()}</p>
        </div>

        <div class="wpn-meta-grid">
          <div class="wpn-meta-item">
            <span class="wpn-meta-label">Status</span>
            <p class="wpn-status-readout" style="--status-c: {statusCssColor(form.status)}">
              {statusLabel(form.status)}
            </p>
          </div>
          <div class="wpn-meta-item">
            <span class="wpn-meta-label">Caliber</span>
            <p class="wpn-meta-value">{form.caliber.trim() || '\u2014'}</p>
          </div>
          <div class="wpn-meta-item">
            <span class="wpn-meta-label">Owner</span>
            <p class="wpn-meta-value">{form.ownerName.trim() || form.ownerCitizenId.trim() || '\u2014'}</p>
          </div>
          <div class="wpn-meta-item">
            <span class="wpn-meta-label">Updated</span>
            <p class="wpn-meta-value font-mono wpn-meta-dim">{formatDate(selectedWeapon?.updated_at || selectedWeapon?.created_at)}</p>
          </div>
        </div>

        <div class="wpn-header-actions">
          <div class="wpn-header-actions-label">
            <span class="wpn-meta-label">Update status</span>
            <p class="wpn-header-actions-hint">Sets custody state on this record (save applies all edits).</p>
          </div>
          <div class="wpn-header-actions-controls">
            <select class="wpn-select" bind:value={form.status} aria-label="Weapon status">
              {#each STATUS_OPTIONS as option (option)}
                <option value={option}>{statusLabel(option)}</option>
              {/each}
            </select>
          </div>
        </div>
      </header>

      <div class="wpn-detail-grid">
        <div class="wpn-detail-main">
          <div class="wpn-stack">
            <section class="wpn-section">
              <label class="wpn-label" for="wpn-designation">Designation</label>
              <input
                id="wpn-designation"
                class="wpn-input"
                bind:value={form.weaponType}
                placeholder="e.g. duty pistol, patrol rifle\u2026"
              />
              <p class="wpn-inline-hint">{recordHeadline()}</p>
            </section>

            <section class="wpn-section">
              <span class="wpn-label">Specifications</span>
              <div class="wpn-spec-grid">
                <label class="wpn-field">
                  <span class="wpn-label">Serial number</span>
                  <input class="wpn-input" bind:value={form.serialNumber} placeholder="SN-2403-0019" />
                </label>
                <label class="wpn-field">
                  <span class="wpn-label">Make</span>
                  <input class="wpn-input" bind:value={form.make} placeholder="Manufacturer" />
                </label>
                <label class="wpn-field">
                  <span class="wpn-label">Model</span>
                  <input class="wpn-input" bind:value={form.model} placeholder="Model" />
                </label>
                <label class="wpn-field">
                  <span class="wpn-label">Caliber</span>
                  <input class="wpn-input" bind:value={form.caliber} placeholder="9mm" />
                </label>
              </div>
            </section>

            <section class="wpn-section">
              <span class="wpn-label">Registered owner</span>
              <div class="wpn-spec-grid">
                <label class="wpn-field">
                  <span class="wpn-label">Citizen ID</span>
                  <input class="wpn-input font-mono" bind:value={form.ownerCitizenId} placeholder="CIT-0001" />
                </label>
                <label class="wpn-field">
                  <span class="wpn-label">Name</span>
                  <input class="wpn-input" bind:value={form.ownerName} placeholder="Legal name" />
                </label>
              </div>
            </section>

            <section class="wpn-section">
              <label class="wpn-label" for="wpn-notes">Notes</label>
              <textarea
                id="wpn-notes"
                class="wpn-textarea"
                bind:value={form.notes}
                rows="8"
                placeholder="Markings, linked incidents, seizure context\u2026"
              ></textarea>
            </section>

            {#if selectedWeapon}
              <section class="wpn-section">
                <span class="wpn-label">Transfer custody</span>
                <div class="wpn-spec-grid">
                  <label class="wpn-field">
                    <span class="wpn-label">New citizen ID</span>
                    <input class="wpn-input font-mono" bind:value={transferForm.ownerCitizenId} placeholder="CIT-0002" />
                  </label>
                  <label class="wpn-field">
                    <span class="wpn-label">New owner name</span>
                    <input class="wpn-input" bind:value={transferForm.ownerName} placeholder="Receiving party" />
                  </label>
                  <label class="wpn-field">
                    <span class="wpn-label">Status after transfer</span>
                    <select class="wpn-select" bind:value={transferForm.status}>
                      {#each STATUS_OPTIONS as option (option)}
                        <option value={option}>{statusLabel(option)}</option>
                      {/each}
                    </select>
                  </label>
                  <label class="wpn-field wpn-span-2">
                    <span class="wpn-label">Transfer notes</span>
                    <textarea class="wpn-textarea wpn-textarea-tight" bind:value={transferForm.notes} rows="2" placeholder="Chain of custody note"></textarea>
                  </label>
                </div>
                <button type="button" class="wpn-btn-secondary" onclick={transferWeapon} disabled={transferring}>
                  {transferring ? 'Applying\u2026' : 'Apply transfer'}
                </button>
              </section>

              <section class="wpn-section wpn-timeline-section">
                <div class="wpn-section-head">
                  <h2 class="wpn-section-title">Custody timeline</h2>
                  <span class="wpn-count font-mono">{history.length}</span>
                </div>
                {#if history.length > 0}
                  <div class="wpn-timeline">
                    {#each history as item, i (item.id)}
                      <div class="wpn-timeline-entry">
                        <div class="wpn-timeline-rail">
                          <span class="wpn-timeline-dot"></span>
                          {#if i < history.length - 1}
                            <span class="wpn-timeline-line"></span>
                          {/if}
                        </div>
                        <div class="wpn-timeline-body">
                          <div class="wpn-timeline-meta">
                            <span class="wpn-timeline-time font-mono">{formatDateTime(item.created_at)}</span>
                            <span class="wpn-timeline-action">{statusLabel(item.action)}</span>
                          </div>
                          <p class="wpn-timeline-desc">
                            {item.from_owner_name || item.from_owner_citizen_id || 'Registry'}
                            <span class="wpn-arrow">\u2192</span>
                            {item.to_owner_name || item.to_owner_citizen_id || 'Registry'}
                            {#if item.notes}
                              <span class="wpn-timeline-note">{item.notes}</span>
                            {/if}
                          </p>
                        </div>
                      </div>
                    {/each}
                  </div>
                {:else}
                  <p class="wpn-empty-inline">No timeline entries yet</p>
                {/if}
              </section>
            {/if}
          </div>
        </div>

        <aside class="wpn-sidebar">
          <div class="wpn-stack">
            <section class="wpn-section">
              <h2 class="wpn-section-title-block">Photo</h2>
              <div class="wpn-thumb-frame">
                {#if form.imageUrl?.trim()}
                  <img src={form.imageUrl.trim()} alt="" class="wpn-thumb-img" />
                {:else}
                  <div class="wpn-thumb-fallback" aria-hidden="true">
                    <Crosshair size={28} strokeWidth={1.5} />
                  </div>
                {/if}
              </div>
              <label class="wpn-label" for="wpn-img">Image URL</label>
              <input id="wpn-img" class="wpn-input" bind:value={form.imageUrl} placeholder="https://\u2026" />
            </section>

            <section class="wpn-section">
              <div class="wpn-section-head">
                <h2 class="wpn-section-title">Current assignee</h2>
                <span class="wpn-count font-mono">{form.ownerName.trim() || form.ownerCitizenId.trim() ? 1 : 0}</span>
              </div>
              {#if form.ownerName.trim() || form.ownerCitizenId.trim()}
                <div class="wpn-assignee">
                  <div class="wpn-assignee-avatar" aria-hidden="true">
                    <UserRound size={14} strokeWidth={1.75} />
                  </div>
                  <div class="wpn-assignee-text">
                    <span class="wpn-assignee-name">{form.ownerName.trim() || 'Unnamed'}</span>
                    {#if form.ownerCitizenId.trim()}
                      <span class="wpn-assignee-id font-mono">{form.ownerCitizenId.trim()}</span>
                    {/if}
                  </div>
                </div>
              {:else}
                <p class="wpn-empty-inline">No owner linked</p>
              {/if}
            </section>

            <section class="wpn-section">
              <div class="wpn-section-head">
                <h2 class="wpn-section-title">Registry</h2>
                <span class="wpn-count font-mono">{form.id ? 1 : 0}</span>
              </div>
              <p class="wpn-sidebar-note">
                {#if form.id}
                  Internal ID <span class="font-mono">{form.id}</span>
                {:else}
                  Draft record. Save to commit.
                {/if}
              </p>
            </section>
          </div>
        </aside>
      </div>
    </div>
  {/if}
</div>

<style>
  .wpn-page {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(16px * var(--mdt-scale));
    color: var(--mdt-text);
    min-height: min(100%, calc(100vh - 48px));
    font-family: 'Outfit', system-ui, sans-serif;
  }

  .wpn-browse,
  .wpn-record {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    animation: wpn-fade 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  @keyframes wpn-fade {
    from {
      opacity: 0;
      transform: translateY(calc(6px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: none;
    }
  }

  .wpn-page-head {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    justify-content: space-between;
    gap: calc(14px * var(--mdt-scale));
  }

  .wpn-page-head-text {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    min-width: 0;
  }

  .wpn-eyebrow {
    margin: 0;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .wpn-page-title {
    margin: 0;
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.02em;
    color: var(--mdt-text);
  }

  .wpn-page-sub {
    margin: 0;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    max-width: 42ch;
  }

  .wpn-page-head-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-end;
    gap: calc(8px * var(--mdt-scale));
  }

  .wpn-search {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    min-width: min(100%, calc(240px * var(--mdt-scale)));
    max-width: calc(320px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
  }

  .wpn-search input {
    flex: 1;
    min-width: 0;
    border: 0;
    outline: none;
    background: transparent;
    color: var(--mdt-text);
    font: inherit;
    font-size: calc(13px * var(--mdt-scale));
  }

  .wpn-btn-primary,
  .wpn-btn-refresh,
  .wpn-back,
  .wpn-save,
  .wpn-btn-secondary {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    font: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    border-radius: var(--mdt-radius-sm);
    transition:
      background 0.12s ease,
      opacity 0.12s ease,
      transform 0.1s ease;
  }

  .wpn-btn-primary {
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
  }

  .wpn-btn-primary:hover {
    opacity: 0.92;
  }

  .wpn-btn-refresh {
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-success) 35%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-success) 12%, var(--mdt-surface-2));
    color: var(--mdt-success);
  }

  .wpn-btn-refresh:hover {
    background: color-mix(in srgb, var(--mdt-success) 20%, var(--mdt-surface-3));
  }

  .wpn-btn-secondary {
    align-self: flex-start;
    margin-top: calc(4px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 28%, transparent);
    background: color-mix(in srgb, var(--mdt-accent) 14%, transparent);
    color: var(--mdt-accent);
  }

  .wpn-btn-secondary:hover {
    background: color-mix(in srgb, var(--mdt-accent) 22%, transparent);
  }

  .wpn-btn-primary:active,
  .wpn-btn-refresh:active,
  .wpn-back:active,
  .wpn-save:active,
  .wpn-btn-secondary:active {
    transform: scale(0.97);
  }

  .wpn-btn-primary:disabled,
  .wpn-btn-refresh:disabled,
  .wpn-save:disabled,
  .wpn-btn-secondary:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .wpn-spin {
    display: inline-flex;
    animation: wpn-rot 0.7s linear infinite;
  }

  @keyframes wpn-rot {
    to {
      transform: rotate(360deg);
    }
  }

  .wpn-stat-strip {
    display: flex;
    flex-wrap: wrap;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    background: var(--mdt-surface);
  }

  .wpn-stat-cell {
    flex: 1 1 auto;
    min-width: calc(96px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    border-right: 1px solid color-mix(in srgb, var(--mdt-border) 80%, transparent);
  }

  .wpn-stat-cell:last-child {
    border-right: 0;
  }

  .wpn-meta-label {
    display: block;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .wpn-stat-num {
    font-size: calc(17px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.02em;
    color: var(--mdt-text);
  }

  .wpn-stat-good {
    color: var(--mdt-success);
  }

  .wpn-stat-warn {
    color: var(--mdt-warning);
  }

  .wpn-stat-bad {
    color: var(--mdt-error);
  }

  .wpn-error {
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid color-mix(in srgb, var(--mdt-error) 45%, transparent);
    background: color-mix(in srgb, var(--mdt-error) 12%, var(--mdt-surface));
    color: var(--mdt-error);
    font-size: calc(13px * var(--mdt-scale));
  }

  .wpn-empty {
    padding: calc(28px * var(--mdt-scale));
    text-align: center;
    color: var(--mdt-text-muted);
    font-size: calc(14px * var(--mdt-scale));
    border: 1px dashed var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface);
  }

  .wpn-table-wrap {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    background: var(--mdt-surface);
  }

  .wpn-table-head {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1.6fr) minmax(0, 1.1fr) minmax(0, 0.85fr);
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

  .wpn-table-row {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1.6fr) minmax(0, 1.1fr) minmax(0, 0.85fr);
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border: none;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 85%, transparent);
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: pointer;
    align-items: center;
    transition: background 0.12s ease;
    width: 100%;
  }

  .wpn-table-row:last-child {
    border-bottom: none;
  }

  .wpn-table-row:hover {
    background: var(--mdt-surface-2);
  }

  .wpn-td-serial {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0.88;
  }

  .wpn-td-title {
    font-weight: 600;
    font-size: calc(13px * var(--mdt-scale));
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wpn-td-owner {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wpn-status-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    border: 1px solid transparent;
  }

  .wpn-status-badge[data-tone='good'] {
    color: var(--mdt-success);
    background: color-mix(in srgb, var(--mdt-success) 12%, var(--mdt-surface-2));
    border-color: color-mix(in srgb, var(--mdt-success) 28%, var(--mdt-border));
  }

  .wpn-status-badge[data-tone='neutral'] {
    color: var(--mdt-text-dim);
    background: var(--mdt-surface-2);
    border-color: var(--mdt-border);
  }

  .wpn-status-badge[data-tone='warn'] {
    color: var(--mdt-warning);
    background: color-mix(in srgb, var(--mdt-warning) 12%, var(--mdt-surface-2));
    border-color: color-mix(in srgb, var(--mdt-warning) 28%, var(--mdt-border));
  }

  .wpn-status-badge[data-tone='danger'] {
    color: var(--mdt-error);
    background: color-mix(in srgb, var(--mdt-error) 12%, var(--mdt-surface-2));
    border-color: color-mix(in srgb, var(--mdt-error) 28%, var(--mdt-border));
  }

  .wpn-top-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .wpn-back {
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-weight: 500;
  }

  .wpn-back:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .wpn-save {
    padding: calc(10px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
  }

  .wpn-save:hover {
    opacity: 0.92;
  }

  .wpn-detail-header {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    padding: 0 0 calc(12px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
  }

  .wpn-report-line {
    padding-bottom: calc(8px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
  }

  .wpn-report-id {
    margin: 0;
    font-size: calc(16px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
    line-height: 1.35;
  }

  .wpn-meta-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
  }

  .wpn-meta-item {
    min-width: 0;
  }

  .wpn-status-readout {
    margin: 0;
    display: block;
    width: fit-content;
    max-width: 100%;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    line-height: 1.4;
    text-transform: capitalize;
    color: var(--status-c);
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-left: 3px solid var(--status-c);
    background: color-mix(in srgb, var(--status-c) 9%, var(--mdt-surface-2));
    border-radius: 0 var(--mdt-radius-sm) var(--mdt-radius-sm) 0;
  }

  .wpn-meta-value {
    margin: 0;
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    line-height: 1.4;
  }

  .wpn-meta-dim {
    color: var(--mdt-text-dim);
    font-size: calc(12px * var(--mdt-scale));
    letter-spacing: 0.03em;
  }

  .wpn-header-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    padding-top: calc(10px * var(--mdt-scale));
    margin-top: calc(2px * var(--mdt-scale));
    border-top: 1px solid color-mix(in srgb, var(--mdt-border) 55%, transparent);
  }

  .wpn-header-actions-label {
    flex: 1 1 200px;
    min-width: 0;
  }

  .wpn-header-actions-hint {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.45;
    color: var(--mdt-text-muted);
  }

  .wpn-header-actions-controls {
    flex: 1 1 220px;
    min-width: 0;
    max-width: min(100%, calc(360px * var(--mdt-scale)));
  }

  .wpn-detail-grid {
    display: grid;
    grid-template-columns: 1fr minmax(220px, calc(268px * var(--mdt-scale)));
    gap: calc(18px * var(--mdt-scale));
    align-items: start;
    min-height: 0;
  }

  .wpn-detail-main {
    min-width: 0;
  }

  .wpn-sidebar {
    min-width: 0;
    padding-left: calc(16px * var(--mdt-scale));
    margin-left: calc(2px * var(--mdt-scale));
    border-left: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
  }

  .wpn-stack {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .wpn-section {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
  }

  .wpn-stack > .wpn-section:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .wpn-detail-main .wpn-stack > .wpn-section:first-child,
  .wpn-sidebar .wpn-stack > .wpn-section:first-child {
    padding-top: 0;
  }

  .wpn-section-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .wpn-section-title {
    margin: 0;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .wpn-section-title-block {
    margin: 0 0 calc(4px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .wpn-count {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    padding: calc(1px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    letter-spacing: 0.05em;
  }

  .wpn-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .wpn-inline-hint {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.4;
  }

  .wpn-input,
  .wpn-select,
  .wpn-textarea {
    width: 100%;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font: inherit;
    font-size: calc(13px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    box-shadow: inset 0 1px 0 color-mix(in srgb, #fff 4%, transparent);
  }

  .wpn-input:focus,
  .wpn-select:focus,
  .wpn-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .wpn-input::placeholder,
  .wpn-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .wpn-select {
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='rgba(228,232,239,0.38)' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right calc(10px * var(--mdt-scale)) center;
    padding-right: calc(32px * var(--mdt-scale));
  }

  .wpn-textarea {
    resize: vertical;
    min-height: calc(160px * var(--mdt-scale));
    line-height: 1.55;
  }

  .wpn-textarea-tight {
    min-height: calc(64px * var(--mdt-scale));
  }

  .wpn-spec-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: calc(12px * var(--mdt-scale));
  }

  .wpn-field {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    min-width: 0;
  }

  .wpn-span-2 {
    grid-column: 1 / -1;
  }

  .wpn-thumb-frame {
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    aspect-ratio: 4 / 3;
    overflow: hidden;
    display: grid;
    place-items: center;
    margin-bottom: calc(6px * var(--mdt-scale));
  }

  .wpn-thumb-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .wpn-thumb-fallback {
    color: var(--mdt-accent);
    opacity: 0.45;
  }

  .wpn-assignee {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
  }

  .wpn-assignee-avatar {
    width: calc(32px * var(--mdt-scale));
    height: calc(32px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    display: grid;
    place-items: center;
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .wpn-assignee-text {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .wpn-assignee-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .wpn-assignee-id {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .wpn-sidebar-note {
    margin: 0;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
  }

  .wpn-empty-inline {
    margin: 0;
    padding: calc(8px * var(--mdt-scale)) 0;
    text-align: center;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    opacity: 0.75;
  }

  .wpn-timeline-section {
    gap: calc(8px * var(--mdt-scale));
  }

  .wpn-timeline {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .wpn-timeline-entry {
    display: flex;
    gap: calc(12px * var(--mdt-scale));
    min-height: calc(40px * var(--mdt-scale));
  }

  .wpn-timeline-rail {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: calc(12px * var(--mdt-scale));
    flex-shrink: 0;
    padding-top: calc(4px * var(--mdt-scale));
  }

  .wpn-timeline-dot {
    width: calc(8px * var(--mdt-scale));
    height: calc(8px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-accent);
    flex-shrink: 0;
    box-shadow: 0 0 calc(5px * var(--mdt-scale)) var(--mdt-accent-glow, transparent);
  }

  .wpn-timeline-line {
    width: 1px;
    flex: 1;
    background: var(--mdt-border-2);
    margin-top: calc(4px * var(--mdt-scale));
  }

  .wpn-timeline-body {
    flex: 1;
    min-width: 0;
    padding-bottom: calc(14px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .wpn-timeline-meta {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .wpn-timeline-time {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    opacity: 0.75;
    letter-spacing: 0.04em;
  }

  .wpn-timeline-action {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    color: var(--mdt-text-muted);
  }

  .wpn-timeline-desc {
    margin: 0;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
  }

  .wpn-timeline-note {
    display: block;
    margin-top: calc(4px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .wpn-arrow {
    margin: 0 calc(4px * var(--mdt-scale));
    opacity: 0.5;
  }

  .font-mono {
    font-family: 'Share Tech Mono', 'Courier New', monospace;
  }

  @media (max-width: 1100px) {
    .wpn-meta-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }

  @media (max-width: 960px) {
    .wpn-detail-grid {
      grid-template-columns: 1fr;
      gap: calc(12px * var(--mdt-scale));
    }

    .wpn-sidebar {
      padding-left: 0;
      margin-left: 0;
      border-left: none;
      padding-top: calc(12px * var(--mdt-scale));
      margin-top: calc(4px * var(--mdt-scale));
      border-top: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
    }

    .wpn-table-head {
      display: none;
    }

    .wpn-table-row {
      grid-template-columns: 1fr;
      gap: calc(4px * var(--mdt-scale));
    }

    .wpn-td-serial::before {
      content: 'Serial ';
      font-size: calc(10px * var(--mdt-scale));
      color: var(--mdt-text-muted);
      text-transform: uppercase;
      letter-spacing: 0.06em;
      margin-right: 0.35em;
    }
  }

  @media (max-width: 520px) {
    .wpn-meta-grid {
      grid-template-columns: 1fr;
    }

    .wpn-spec-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
