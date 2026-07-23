<script>
  import { onMount } from 'svelte';
  import {
    Users,
    User,
    Search,
    Phone,
    Car,
    FileText,
    AlertTriangle,
    ShieldAlert,
    Image,
    RefreshCw,
    Clock,
    Building2,
    Scale,
    IdCard,
    Megaphone,
    Calendar,
    Briefcase,
    Mail,
    MapPin,
    Fingerprint,
    ChevronRight,
    X,
  } from '@lucide/svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import MdtSelect from '../lib/components/MdtSelect.svelte';

  const FLAG_DEFS = [
    { key: 'violent', label: 'Violent', tone: 'danger' },
    { key: 'felon', label: 'Felon', tone: 'warning' },
    { key: 'active_warrant', label: 'Active Warrant', tone: 'warning' },
    { key: 'medical_alert', label: 'Medical Alert', tone: 'info' },
    { key: 'mental_health', label: 'Mental Health', tone: 'info' },
    { key: 'gang_affiliated', label: 'Gang Affiliated', tone: 'danger' },
    { key: 'known_armed', label: 'Known Armed', tone: 'danger' },
    { key: 'missing_person', label: 'Missing Person', tone: 'info' },
  ];

  const LICENSE_STATUS_SELECT = [
    { value: 'valid', label: 'Valid' },
    { value: 'suspended', label: 'Suspended' },
    { value: 'revoked', label: 'Revoked' },
    { value: 'expired', label: 'Expired' },
  ];
  const COMMON_LICENSE_TYPES = $derived.by(() => {
    const types = dataStore.licenseTypesList || [];
    if (!types.length) return ['Driver', 'Weapon', 'Pilot', 'Hunting', 'Fishing', 'Business'];
    return types.filter((t) => t.active).map((t) => t.name);
  });
  const PROFILE_TABS = [
    { id: 'profile', label: 'Profile', icon: User },
    { id: 'vehicles', label: 'Vehicles', icon: Car },
    { id: 'reports', label: 'Reports', icon: FileText },
    { id: 'warrants', label: 'Warrants', icon: Scale },
    { id: 'licenses', label: 'Licenses', icon: IdCard },
    { id: 'bolos', label: 'Bolos', icon: Megaphone },
  ];

  let loading = $state(false);
  let saving = $state(false);
  let licenseSaving = $state(false);
  let searchQuery = $state('');
  let errorMessage = $state('');
  let activeTab = $state('profile');
  let debounceTimer = $state(null);

  let notesInput = $state('');
  let mugshotInput = $state('');
  let newTagInput = $state('');
  let tagDrafts = $state([]);
  let tagMenu = $state({ open: false, x: 0, y: 0, index: -1 });
  let editedFlags = $state([]);

  const TAG_COLOR_OPTIONS = [
    { id: 'red', label: 'Red' },
    { id: 'orange', label: 'Orange' },
    { id: 'yellow', label: 'Yellow' },
    { id: 'green', label: 'Green' },
    { id: 'cyan', label: 'Cyan' },
    { id: 'blue', label: 'Blue' },
    { id: 'purple', label: 'Purple' },
    { id: 'white', label: 'White' },
  ];
  const TAG_COLOR_IDS = new Set(TAG_COLOR_OPTIONS.map((o) => o.id));
  let licensesDraft = $state([]);
  let newLicenseType = $state('');

  let results = $derived(dataStore.citizenSearchResults || []);
  let citizen = $derived(dataStore.selectedCitizen);
  let vehicles = $derived(dataStore.citizenVehicles || []);
  let licenses = $derived(dataStore.citizenLicenses || []);
  let reports = $derived(dataStore.citizenReports || []);
  let warrants = $derived(dataStore.citizenWarrants || []);
  let bolos = $derived(dataStore.citizenBolos || []);
  let recentlyViewed = $derived(dataStore.recentCitizens || []);

  let selectedFlagSet = $derived(new Set(editedFlags));
  let missingLicenseTypes = $derived(COMMON_LICENSE_TYPES.filter((type) => !licensesDraft.find((license) => license.type === type)));
  let newLicenseOptions = $derived.by(() => {
    if (missingLicenseTypes.length === 0) {
      return [{ value: '', label: 'All common license types on file' }];
    }
    return [{ value: '', label: 'Add common license…' }, ...missingLicenseTypes.map((type) => ({ value: type, label: type }))];
  });
  let stats = $derived({
    properties: citizen?.property_count ?? 0,
    arrests: citizen?.arrest_count ?? citizen?.stats?.arrestCount ?? 0,
    vehicles: citizen?.stats?.vehicleCount ?? vehicles.length,
    reports: citizen?.stats?.reportCount ?? reports.length,
  });

  let tabCounts = $derived({
    vehicles: vehicles.length,
    reports: reports.length,
    warrants: warrants.length,
    licenses: licensesDraft.length,
    bolos: bolos.length,
  });

  let warrantAlert = $derived(
    warrants.some((w) => String(w.status || '').toLowerCase() === 'active'),
  );

  $effect(() => {
    if (!citizen) {
      return;
    }

    notesInput = citizen.notes || '';
    mugshotInput = citizen.mugshot || '';
    tagDrafts = normalizeTagEntries(citizen.tags || []);
    editedFlags = [...(citizen.flags || [])];
    licensesDraft = (licenses || []).map((license) => ({
      id: license.id ?? null,
      type: license.type || '',
      status: license.status || 'valid',
      expires_at: license.expires_at ? String(license.expires_at).slice(0, 10) : '',
    }));
  });

  function scheduleSearch() {
    if (debounceTimer) clearTimeout(debounceTimer);
    if (!searchQuery.trim()) {
      dataStore.clearCitizenSearch();
      return;
    }

    debounceTimer = setTimeout(async () => {
      loading = true;
      errorMessage = '';
      const response = await dataStore.searchCitizens(searchQuery.trim());
      if (!response?.ok) {
        errorMessage = response?.error || 'Unable to search citizens.';
      }
      loading = false;
    }, 250);
  }

  async function openCitizen(citizenId) {
    loading = true;
    errorMessage = '';
    activeTab = 'profile';
    const response = await dataStore.getCitizen(citizenId);
    if (!response?.ok) {
      errorMessage = response?.error || 'Unable to load citizen profile.';
    }
    loading = false;
  }

  function resetProfile() {
    dataStore.clearCitizenSearch();
    errorMessage = '';
    activeTab = 'profile';
    searchQuery = '';
  }

  function toggleFlag(flagKey) {
    if (selectedFlagSet.has(flagKey)) {
      editedFlags = editedFlags.filter((flag) => flag !== flagKey);
      return;
    }

    editedFlags = [...editedFlags, flagKey];
  }

  function normalizeTagEntries(raw) {
    if (!raw?.length) return [];
    return raw
      .map((t) => {
        if (typeof t === 'string') return { label: t.trim(), color: 'blue' };
        const label = String(t?.label ?? '').trim();
        const c = String(t?.color ?? 'blue').toLowerCase();
        return { label, color: TAG_COLOR_IDS.has(c) ? c : 'blue' };
      })
      .filter((x) => x.label);
  }

  function addTagFromInput() {
    const label = newTagInput.trim();
    if (!label) return;
    if (tagDrafts.some((x) => x.label.toLowerCase() === label.toLowerCase())) return;
    tagDrafts = [...tagDrafts, { label, color: 'blue' }];
    newTagInput = '';
  }

  function onNewTagKeydown(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      addTagFromInput();
    }
  }

  function openTagColorMenu(e, index) {
    e.preventDefault();
    e.stopPropagation();
    const pad = 8;
    const mw = 200;
    const mh = 300;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    let x = e.clientX;
    let y = e.clientY;
    if (x + mw > vw - pad) x = vw - mw - pad;
    if (x < pad) x = pad;
    if (y + mh > vh - pad) y = vh - mh - pad;
    if (y < pad) y = pad;
    tagMenu = { open: true, x, y, index };
  }

  function applyTagColor(color) {
    const i = tagMenu.index;
    if (i < 0 || i >= tagDrafts.length) {
      tagMenu = { open: false, x: 0, y: 0, index: -1 };
      return;
    }
    tagDrafts = tagDrafts.map((t, j) => (j === i ? { ...t, color } : t));
    tagMenu = { open: false, x: 0, y: 0, index: -1 };
  }

  function closeTagMenu() {
    if (tagMenu.open) tagMenu = { open: false, x: 0, y: 0, index: -1 };
  }

  async function saveProfile() {
    if (!citizen) return;

    saving = true;
    errorMessage = '';

    const response = await dataStore.updateCitizen({
      citizenId: citizen.citizen_id,
      notes: notesInput.trim(),
      mugshot: mugshotInput.trim(),
      flags: editedFlags,
      tags: tagDrafts.map((t) => ({ label: t.label, color: t.color })),
    });

    if (!response?.ok) {
      errorMessage = response?.error || 'Unable to save citizen profile.';
    }

    saving = false;
  }

  function addLicenseType() {
    const type = newLicenseType.trim();
    if (!type || licensesDraft.find((license) => license.type === type)) {
      return;
    }

    licensesDraft = [
      ...licensesDraft,
      {
        id: null,
        type,
        status: 'valid',
        expires_at: '',
      },
    ];
    newLicenseType = '';
  }

  function removeLicenseType(type) {
    licensesDraft = licensesDraft.filter((license) => license.type !== type);
  }

  async function saveLicenses() {
    if (!citizen) return;

    licenseSaving = true;
    errorMessage = '';

    const response = await dataStore.updateCitizenLicenses(citizen.citizen_id, licensesDraft.map((license) => ({
      type: license.type,
      status: license.status,
      expires_at: license.expires_at || null,
    })));

    if (!response?.ok) {
      errorMessage = response?.error || 'Unable to save license changes.';
    }

    licenseSaving = false;
  }

  function formatDate(value) {
    if (!value) return 'Unavailable';
    try {
      const date = new Date(value);
      return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString();
    } catch {
      return value;
    }
  }

  function formatDateTime(value) {
    if (!value) return 'Unavailable';
    try {
      const date = new Date(value);
      return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
    } catch {
      return value;
    }
  }

  function statusTone(status) {
    const normalized = String(status || '').toLowerCase();
    if (['valid', 'registered', 'closed', 'served', 'cleared'].includes(normalized)) return 'good';
    if (['suspended', 'active', 'pending', 'flagged'].includes(normalized)) return 'warn';
    if (['revoked', 'expired', 'stolen', 'destroyed', 'invalid'].includes(normalized)) return 'danger';
    return 'neutral';
  }

  function readCitizenDetail(key) {
    if (!citizen) return '';
    const direct = citizen[key] || citizen[`${key}_value`];
    if (direct) return direct;
    const ersDetails = citizen.properties?.ersPersonalDetails;
    if (ersDetails?.[key]) return ersDetails[key];
    return '';
  }

  function normalizeFlagList(raw) {
    if (Array.isArray(raw)) return raw;
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }
    return [];
  }

  function citizenRowId(row) {
    return row.citizen_id || row.citizenId || '';
  }

  function initialsFrom(first, last) {
    const a = String(first || '').trim().charAt(0);
    const b = String(last || '').trim().charAt(0);
    return (a + b || '?').toUpperCase();
  }

  function formatViewedAgo(ts) {
    if (ts == null || Number.isNaN(Number(ts))) return '';
    const s = Math.floor((Date.now() - Number(ts)) / 1000);
    if (s < 45) return 'Just now';
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    if (s < 604800) return `${Math.floor(s / 86400)}d ago`;
    return formatDateTime(ts);
  }

  function clipFingerprint(fp, max = 16) {
    const t = String(fp || '').trim();
    if (!t) return '';
    return t.length > max ? `${t.slice(0, max)}…` : t;
  }

  /** @param {Record<string, unknown>} c */
  function formatRecordUpdated(c) {
    const v = c?.updated_at;
    if (!v) return '\u2014';
    try {
      const d = new Date(String(v));
      return Number.isNaN(d.getTime()) ? String(v) : d.toISOString();
    } catch {
      return String(v);
    }
  }

  function flagTone(flag) {
    return FLAG_DEFS.find((d) => d.key === flag)?.tone || 'neutral';
  }

  function clearLookupSearch() {
    searchQuery = '';
    dataStore.clearCitizenSearch();
    errorMessage = '';
  }

  onMount(() => {
    dataStore.clearCitizenSearch();
    dataStore.fetchLicenseTypes();
  });
</script>

<svelte:window onclick={closeTagMenu} />
<div class="cp-page">
  {#if !citizen}
    <section class="cp-lookup" aria-label="Citizen registry search">
      <div class="cp-lookup-toolbar">
        <div class="cp-lookup-heading">
          <div class="cp-eyebrow">
            <Users size={13} strokeWidth={2} />
            <span>Registry</span>
          </div>
          <h2 class="cp-lookup-h1">Citizens</h2>
          <p class="cp-lookup-desc">Search by legal name, phone, fingerprint hash, or citizen ID.</p>
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
            <span class="cp-lookup-hint"><Fingerprint size={11} strokeWidth={2} /> Print</span>
            <span class="cp-lookup-hint"><Phone size={11} strokeWidth={2} /> Phone</span>
            <span class="cp-lookup-hint"><IdCard size={11} strokeWidth={2} /> ID</span>
            <span class="cp-lookup-hint"><User size={11} strokeWidth={2} /> Name</span>
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
              {#each recentlyViewed as entry (entry.citizen_id)}
                {@const rfRecent = normalizeFlagList(entry.flags)}
                <li>
                  <button type="button" class="cp-aside-row" onclick={() => openCitizen(entry.citizen_id)}>
                    <div class="cp-aside-av" aria-hidden="true">
                      {#if entry.mugshot}
                        <img src={entry.mugshot} alt="" />
                      {:else}
                        <span>{initialsFrom(entry.first_name, entry.last_name)}</span>
                      {/if}
                    </div>
                    <div class="cp-aside-mid">
                      <span class="cp-aside-name">{entry.first_name} {entry.last_name}</span>
                      <span class="cp-aside-sub mono">{entry.citizen_id}</span>
                      <span class="cp-aside-meta">
                        {#if entry.viewedAt}{formatViewedAgo(entry.viewedAt)}{/if}
                        {#if entry.viewedAt && entry.occupation}<span class="cp-aside-dot"></span>{/if}
                        {#if entry.occupation}{entry.occupation}{/if}
                      </span>
                      {#if rfRecent.length}
                        <div class="cp-flag-strip">
                          {#each rfRecent.slice(0, 2) as flag (flag)}
                            <span class="cp-flag-tag" class:danger={flagTone(flag) === 'danger'} class:warning={flagTone(flag) === 'warning'} class:info={flagTone(flag) === 'info'}>
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
              <div class="cp-lookup-tr cp-lookup-tr-head" aria-hidden="true">
                <span class="cp-lookup-td cp-td-subject">Subject</span>
                <span class="cp-lookup-td cp-td-id">Citizen ID</span>
                <span class="cp-lookup-td cp-td-phone">Phone</span>
                <span class="cp-lookup-td cp-td-flags">Flags</span>
                <span class="cp-lookup-td cp-td-go"></span>
              </div>
              {#each results as row (row.id || citizenRowId(row))}
                {@const rf = normalizeFlagList(row.flags)}
                <button type="button" class="cp-lookup-tr cp-lookup-tr-data" onclick={() => openCitizen(citizenRowId(row))}>
                  <span class="cp-lookup-td cp-td-subject">
                    <span class="cp-lookup-av" aria-hidden="true">
                      {#if row.mugshot}
                        <img src={row.mugshot} alt="" />
                      {:else}
                        <span>{initialsFrom(row.first_name, row.last_name)}</span>
                      {/if}
                    </span>
                    <span class="cp-lookup-subject-text">
                      <span class="cp-lookup-legal">{row.first_name} {row.last_name}</span>
                      <span class="cp-lookup-subline">
                        {#if row.dob}<Calendar size={10} strokeWidth={2} />{formatDate(row.dob)}{/if}
                        {#if row.dob && row.gender}<span class="cp-aside-dot"></span>{/if}
                        {#if row.gender}{row.gender}{/if}
                        {#if row.occupation || row.job_title}
                          <span class="cp-aside-dot"></span>
                          <Briefcase size={10} strokeWidth={2} />
                          {row.occupation || row.job_title}
                        {/if}
                      </span>
                    </span>
                  </span>
                  <span class="cp-lookup-td cp-td-id mono">{citizenRowId(row)}</span>
                  <span class="cp-lookup-td cp-td-phone">
                    <Phone size={11} strokeWidth={2} />
                    <span class="cp-lookup-phone-txt">{row.phone || '—'}</span>
                  </span>
                  <span class="cp-lookup-td cp-td-flags">
                    {#if rf.length}
                      <span class="cp-flag-strip">
                        {#each rf.slice(0, 3) as flag (flag)}
                          <span class="cp-flag-tag" class:danger={flagTone(flag) === 'danger'} class:warning={flagTone(flag) === 'warning'} class:info={flagTone(flag) === 'info'}>
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
              <Users size={20} strokeWidth={2} />
              <span>Results appear here. Use <span class="mono">Recent</span> to reopen last viewed files.</span>
            </div>
          {/if}
        </div>
      </div>
    </section>
  {:else}
    <section class="cp-stack cp-stack-profile cit-record">
      <div class="cit-detail-mode">
        <div class="cit-detail-top-bar">
          <button type="button" class="cit-back-btn" onclick={resetProfile}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path d="M19 12H5M12 19l-7-7 7-7" />
            </svg>
            <span>Back to registry</span>
          </button>
          <button type="button" class="cit-btn-save" onclick={saveProfile} disabled={saving}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z" />
              <polyline points="17 21 17 13 7 13 7 21" />
              <polyline points="7 3 7 8 15 8" />
            </svg>
            <span>{saving ? 'Saving…' : 'Save profile'}</span>
          </button>
        </div>

        {#if errorMessage}
          <div class="cp-error cp-error-tight">{errorMessage}</div>
        {/if}

        <div class="cit-detail-header">
          <div class="cit-detail-id-line">
            <span class="cit-detail-meta-label">Citizen ID</span>
            <p class="cit-detail-record-id font-mono">{citizen.citizen_id}</p>
          </div>
          <div class="cit-detail-meta-grid">
            <div class="cit-detail-meta-item">
              <span class="cit-detail-meta-label">Full name</span>
              <p class="cit-detail-meta-value">{citizen.first_name} {citizen.last_name}</p>
            </div>
            <div class="cit-detail-meta-item">
              <span class="cit-detail-meta-label">Date of birth</span>
              <p class="cit-detail-meta-value">{formatDate(citizen.dob)}</p>
            </div>
            <div class="cit-detail-meta-item">
              <span class="cit-detail-meta-label">Gender</span>
              <p class="cit-detail-meta-value">{citizen.gender || '\u2014'}</p>
            </div>
            <div class="cit-detail-meta-item">
              <span class="cit-detail-meta-label">Updated</span>
              <p class="cit-detail-meta-value cit-detail-meta-mono font-mono">{formatRecordUpdated(citizen)}</p>
            </div>
          </div>
        </div>

        <div class="cit-detail-grid">
          <div class="cit-detail-main">
            {#if activeTab === 'profile'}
              <div class="cit-detail-stack">
                <div class="cit-detail-section">
                  <label class="cit-form-label" for="cit-notes">Officer notes</label>
                  <span class="cit-field-hint">Internal only — not visible to the subject.</span>
                  <textarea
                    id="cit-notes"
                    class="cit-form-textarea cit-narrative-textarea"
                    bind:value={notesInput}
                    rows="10"
                    placeholder="Add internal notes…"
                  ></textarea>
                </div>

                <div class="cit-detail-section">
                  <label class="cit-form-label" for="cit-mug-url">Mugshot URL</label>
                  <span class="cit-field-hint">Direct image link — updates the sidebar preview.</span>
                  <input
                    id="cit-mug-url"
                    class="cit-form-input"
                    bind:value={mugshotInput}
                    type="url"
                    placeholder="https://example.com/mugshot.png"
                    autocomplete="off"
                  />
                </div>

                <div class="cit-detail-section">
                  <div class="cit-section-header">
                    <h3 class="cit-section-label">Tags</h3>
                    <span class="cit-section-count font-mono">{tagDrafts.length}</span>
                  </div>
                  <p class="cit-field-hint cit-field-hint-tight">Enter or Add — right-click a tag to change color.</p>
                  <div class="cp-tag-chips cit-tag-chips">
                    {#each tagDrafts as tag, ti (`${tag.label}-${ti}`)}
                      <button
                        type="button"
                        class="cp-tag-chip cp-tag-{tag.color}"
                        onclick={(e) => e.preventDefault()}
                        oncontextmenu={(e) => openTagColorMenu(e, ti)}
                      >
                        {tag.label}
                      </button>
                    {/each}
                  </div>
                  <div class="cit-tag-add-row">
                    <input
                      bind:value={newTagInput}
                      type="text"
                      placeholder="New tag…"
                      onkeydown={onNewTagKeydown}
                    />
                    <button type="button" class="cit-btn-add" onclick={addTagFromInput}>Add</button>
                  </div>
                </div>

                <div class="cit-detail-section cit-detail-section-last">
                  <div class="cit-section-header">
                    <h3 class="cit-section-label">Risk flags</h3>
                  </div>
                  <p class="cit-field-hint cit-field-hint-tight">Quick markers for stops and dispatch.</p>
                  <div class="cp-flag-grid cp-flag-grid-dense cit-flag-grid">
                    {#each FLAG_DEFS as flag (flag.key)}
                      <button
                        type="button"
                        class="cp-flag"
                        class:on={selectedFlagSet.has(flag.key)}
                        class:danger={flag.tone === 'danger'}
                        class:warning={flag.tone === 'warning'}
                        class:info={flag.tone === 'info'}
                        onclick={() => toggleFlag(flag.key)}
                      >
                        <ShieldAlert size={12} strokeWidth={2} />
                        {flag.label}
                      </button>
                    {/each}
                  </div>
                </div>
              </div>
            {:else if activeTab === 'vehicles'}
              <div class="cit-subtab-head">
                <h3 class="cit-subtab-title">Vehicles</h3>
              </div>
              <div class="cit-detail-scroll">
              {#if vehicles.length}
                <div class="cp-sheet cp-sheet-flush">
                  <div class="cp-row cp-row-head cp-grid-veh">
                    <span>Plate</span>
                    <span>Model</span>
                    <span>Status</span>
                  </div>
                  {#each vehicles as vehicle (vehicle.id || vehicle.plate)}
                    <div class="cp-row cp-grid-veh">
                      <span class="mono"><Car size={13} strokeWidth={2} /> {vehicle.plate}</span>
                      <span>{vehicle.model || vehicle.make || 'Unknown vehicle'}</span>
                      <span class={`cp-status ${statusTone(vehicle.registration_status)}`}>{vehicle.registration_status || 'unknown'}</span>
                    </div>
                  {/each}
                </div>
              {:else}
                <div class="cp-empty cp-empty-tight">No vehicles linked.</div>
              {/if}
            </div>
          {:else if activeTab === 'reports'}
            <div class="cit-subtab-head">
              <h3 class="cit-subtab-title">Reports</h3>
            </div>
            <div class="cit-detail-scroll">
              {#if reports.length}
                <div class="cp-sheet cp-sheet-flush">
                  <div class="cp-row cp-row-head cp-grid-reports">
                    <span>Report</span>
                    <span>Role</span>
                    <span>Status</span>
                    <span>Date</span>
                  </div>
                  {#each reports as report (report.id || report.report_number)}
                    <div class="cp-row cp-grid-reports">
                      <span class="mono"><FileText size={13} strokeWidth={2} /> {report.report_number || report.id}</span>
                      <span>{report.role || 'Linked'}</span>
                      <span class={`cp-status ${statusTone(report.status)}`}>{report.status || 'unknown'}</span>
                      <span>{formatDate(report.created_at)}</span>
                    </div>
                  {/each}
                </div>
              {:else}
                <div class="cp-empty cp-empty-tight">No linked reports.</div>
              {/if}
            </div>
          {:else if activeTab === 'warrants'}
            <div class="cit-subtab-head">
              <h3 class="cit-subtab-title">Warrants</h3>
            </div>
            <div class="cit-detail-scroll">
              {#if warrants.length}
                <div class="cp-sheet cp-sheet-flush">
                  <div class="cp-row cp-row-head cp-grid-warrants">
                    <span>Charges</span>
                    <span>Status</span>
                    <span>Created</span>
                  </div>
                  {#each warrants as warrant (warrant.id)}
                    <div class="cp-row cp-grid-warrants">
                      <span>{Array.isArray(warrant.charges) ? warrant.charges.join(', ') : warrant.description || 'Charge details unavailable'}</span>
                      <span class={`cp-status ${statusTone(warrant.status)}`}>{warrant.status || 'unknown'}</span>
                      <span>{formatDate(warrant.created_at)}</span>
                    </div>
                  {/each}
                </div>
              {:else}
                <div class="cp-empty cp-empty-tight">No warrants on file.</div>
              {/if}
            </div>
          {:else if activeTab === 'licenses'}
            <div class="cit-subtab-head">
              <div>
                <h3 class="cit-subtab-title">Licenses</h3>
                <p class="cit-subtab-sub">Status & expiry</p>
              </div>
              <button type="button" class="cp-btn cp-btn-save-licenses" onclick={saveLicenses} disabled={licenseSaving}>
                {licenseSaving ? 'Saving…' : 'Save licenses'}
              </button>
            </div>
            <div class="cit-detail-scroll">
              <div class="cp-license-add">
                <MdtSelect bind:value={newLicenseType} options={newLicenseOptions} disabled={missingLicenseTypes.length === 0} />
                <button type="button" class="cp-btn" onclick={addLicenseType} disabled={!newLicenseType.trim() || missingLicenseTypes.length === 0}>
                  Add
                </button>
              </div>
              {#if licensesDraft.length}
                <div class="cp-license-list">
                  {#each licensesDraft as license, index (license.id || `${license.type}-${index}`)}
                    <div class="cp-license-row">
                      <div class="cp-license-type">
                        <span class="cp-k">Type</span>
                        <strong>{license.type}</strong>
                      </div>
                      <label class="cp-field cp-field-tight">
                        <span class="cp-k">Status</span>
                        <MdtSelect bind:value={license.status} options={LICENSE_STATUS_SELECT} compact />
                      </label>
                      <label class="cp-field cp-field-tight">
                        <span class="cp-k">Expiry</span>
                        <input bind:value={license.expires_at} type="date" />
                      </label>
                      <button type="button" class="cp-btn cp-btn-ghost" onclick={() => removeLicenseType(license.type)}>Remove</button>
                    </div>
                  {/each}
                </div>
              {:else}
                <div class="cp-empty cp-empty-tight">No licenses on file yet.</div>
              {/if}
            </div>
          {:else if activeTab === 'bolos'}
            <div class="cit-subtab-head">
              <h3 class="cit-subtab-title">Bolos</h3>
            </div>
            <div class="cit-detail-scroll">
              {#if bolos.length}
                <div class="cp-sheet cp-sheet-flush">
                  <div class="cp-row cp-row-head cp-grid-reports">
                    <span>Title</span>
                    <span>Type</span>
                    <span>Status</span>
                    <span>Created</span>
                  </div>
                  {#each bolos as bolo (bolo.id)}
                    <div class="cp-row cp-grid-reports">
                      <span>{bolo.title || bolo.description || 'BOLO'}</span>
                      <span>{bolo.type || 'general'}</span>
                      <span class={`cp-status ${statusTone(bolo.status)}`}>{bolo.status || 'unknown'}</span>
                      <span>{formatDateTime(bolo.created_at)}</span>
                    </div>
                  {/each}
                </div>
              {:else}
                <div class="cp-empty cp-empty-tight">No BOLOs linked.</div>
              {/if}
            </div>
            {/if}
          </div>

          <aside class="cit-detail-sidebar" aria-label="Record summary and navigation">
            <div class="cit-sidebar-subject">
            <div class="cit-sidebar-photo">
              {#if mugshotInput}
                <img class="cit-sidebar-photo-img" src={mugshotInput} alt={`${citizen.first_name} ${citizen.last_name}`} />
              {:else}
                <div class="cit-sidebar-photo-ph">
                  <Image size={36} strokeWidth={1.75} />
                </div>
              {/if}
            </div>
            <div class="cit-sidebar-titles">
              <div class="cit-sidebar-eyebrow">
                <Users size={12} strokeWidth={2} />
                <span>Subject record</span>
              </div>
              <p class="cit-sidebar-legal">{citizen.first_name} {citizen.last_name}</p>
              <p class="cit-sidebar-meta-line">
                <span>{citizen.gender || '—'}</span>
                <span class="cit-sidebar-dot" aria-hidden="true"></span>
                <span>{formatDate(citizen.dob)}</span>
              </p>
              <dl class="cp-subject-readonly cit-sidebar-dl">
                <div class="cp-subject-readonly-row">
                  <dt>Nationality</dt>
                  <dd>{readCitizenDetail('nationality') || '—'}</dd>
                </div>
                <div class="cp-subject-readonly-row cp-subject-readonly-row-wide">
                  <dt><MapPin size={10} strokeWidth={2} /> Address</dt>
                  <dd>{readCitizenDetail('address') || '—'}</dd>
                </div>
                <div class="cp-subject-readonly-row">
                  <dt><Mail size={10} strokeWidth={2} /> E-mail</dt>
                  <dd class="cp-subject-wrap">{readCitizenDetail('email') || '—'}</dd>
                </div>
                <div class="cp-subject-readonly-row">
                  <dt>Fingerprint</dt>
                  <dd class="mono">{citizen.fingerprint || '—'}</dd>
                </div>
                <div class="cp-subject-readonly-row">
                  <dt>Occupation</dt>
                  <dd>{citizen.occupation || citizen.job_title || 'Unlisted'}</dd>
                </div>
              </dl>
            </div>
          </div>
          {#if warrantAlert}
            <div class="cp-glance cp-glance-danger">
              <AlertTriangle size={14} strokeWidth={2} />
              <span>Active warrant on file</span>
            </div>
          {/if}
          <div class="cp-stat-strip" role="group" aria-label="Quick counts">
            <div class="cp-stat-mini">
              <span class="cp-stat-mini-k"><Phone size={10} strokeWidth={2} /> Phone</span>
              <span class="cp-stat-mini-v cp-stat-mini-phone">{citizen.phone || '—'}</span>
            </div>
            <span class="cp-stat-div" aria-hidden="true"></span>
            <div class="cp-stat-mini">
              <span class="cp-stat-mini-k"><Building2 size={10} strokeWidth={2} /> Prop</span>
              <span class="cp-stat-mini-n">{stats.properties}</span>
            </div>
            <span class="cp-stat-div" aria-hidden="true"></span>
            <div class="cp-stat-mini">
              <span class="cp-stat-mini-k">Arr</span>
              <span class="cp-stat-mini-n">{stats.arrests}</span>
            </div>
            <span class="cp-stat-div" aria-hidden="true"></span>
            <div class="cp-stat-mini">
              <span class="cp-stat-mini-k">Rpts</span>
              <span class="cp-stat-mini-n">{stats.reports}</span>
            </div>
          </div>

          <nav class="cp-side-nav" aria-label="Record sections">
            {#each PROFILE_TABS as tab (tab.id)}
              {@const NavIcon = tab.icon}
              <button
                type="button"
                class="cp-nav-item"
                class:active={activeTab === tab.id}
                onclick={() => activeTab = tab.id}
              >
                <span class="cp-nav-ico">
                  <NavIcon size={15} strokeWidth={2} />
                </span>
                <span class="cp-nav-label">{tab.label}</span>
                {#if tab.id !== 'profile' && tabCounts[tab.id] !== undefined}
                  <span class="cp-nav-badge">{tabCounts[tab.id]}</span>
                {/if}
              </button>
            {/each}
          </nav>

          {#if warrants.length && activeTab !== 'warrants'}
            <div class="cp-glance cp-glance-muted">
              <span class="cp-k">Warrants glance</span>
              <p class="cp-glance-body">{warrants.length} on file — latest {formatDate(warrants[0]?.created_at)}</p>
            </div>
          {/if}
        </aside>
      </div>
      </div>
    </section>
    {#if tagMenu.open}
      <div class="cp-tag-menu" style="left: {tagMenu.x}px; top: {tagMenu.y}px;" tabindex="-1">
        <div class="cp-tag-menu-title">Tag color</div>
        {#each TAG_COLOR_OPTIONS as opt (opt.id)}
          <button type="button" class="cp-tag-menu-opt" role="menuitem" onclick={() => applyTagColor(opt.id)}>
            <span class="cp-tag-swatch cp-tag-swatch-{opt.id}" aria-hidden="true"></span>
            {opt.label}
          </button>
        {/each}
      </div>
    {/if}
  {/if}
</div>

<style>
  /* Citizens — tiered surfaces, minimal “cards”, rail + workbench layout */
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

  .cp-stack {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }

  .cp-stack-profile {
    flex: 1;
    min-height: 0;
  }

  /* Citizen record detail — aligned with Cases detail-mode (case file layout) */
  .cit-record.cit-record {
    gap: 0;
  }

  .cit-detail-mode {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
    animation: citFadeIn 0.22s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  @keyframes citFadeIn {
    from {
      opacity: 0;
      transform: translateY(calc(4px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .cit-detail-top-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    flex-wrap: wrap;
    flex-shrink: 0;
  }

  .cit-back-btn {
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
  }

  .cit-back-btn svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .cit-back-btn:hover {
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .cit-back-btn:active {
    transform: scale(0.98);
  }

  .cit-btn-save {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
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
    flex-shrink: 0;
  }

  .cit-btn-save svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .cit-btn-save:hover:not(:disabled) {
    opacity: 0.92;
  }

  .cit-btn-save:active:not(:disabled) {
    transform: scale(0.98);
  }

  .cit-btn-save:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  :global([data-theme='cortex']) .cit-btn-save {
    box-shadow: 0 calc(2px * var(--mdt-scale)) calc(12px * var(--mdt-scale)) color-mix(in srgb, var(--mdt-accent) 28%, transparent);
  }

  .cit-detail-header {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    padding: 0 0 calc(12px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
    flex-shrink: 0;
  }

  .cit-detail-id-line {
    padding-bottom: calc(8px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
  }

  .cit-detail-meta-label {
    display: block;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    margin: 0 0 calc(6px * var(--mdt-scale));
    font-family: 'Outfit', sans-serif;
  }

  .cit-detail-record-id {
    margin: 0;
    font-size: calc(17px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
    line-height: 1.35;
  }

  .cit-detail-meta-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
  }

  @media (max-width: 1100px) {
    .cit-detail-meta-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }

  @media (max-width: 520px) {
    .cit-detail-meta-grid {
      grid-template-columns: 1fr;
    }
  }

  .cit-detail-meta-item {
    min-width: 0;
  }

  .cit-detail-meta-value {
    margin: 0;
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 500;
    line-height: 1.4;
    font-family: 'Outfit', sans-serif;
  }

  .cit-detail-meta-mono {
    color: var(--mdt-text-dim);
    font-size: calc(12px * var(--mdt-scale));
    letter-spacing: 0.04em;
  }

  .cit-detail-grid {
    display: grid;
    grid-template-columns: 1fr minmax(220px, calc(272px * var(--mdt-scale)));
    gap: calc(18px * var(--mdt-scale));
    align-items: stretch;
    min-height: 0;
    flex: 1;
  }

  .cit-detail-main {
    display: flex;
    flex-direction: column;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
  }

  .cit-detail-stack {
    display: flex;
    flex-direction: column;
    gap: 0;
    padding: calc(4px * var(--mdt-scale)) calc(14px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    overflow-y: auto;
    flex: 1;
    min-height: 0;
  }

  .cit-detail-section {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
  }

  .cit-detail-stack > .cit-detail-section:first-child {
    padding-top: calc(8px * var(--mdt-scale));
  }

  .cit-detail-section-last {
    border-bottom: none;
    padding-bottom: calc(4px * var(--mdt-scale));
  }

  .cit-form-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'Outfit', sans-serif;
  }

  .cit-field-hint {
    margin: calc(-2px * var(--mdt-scale)) 0 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.35;
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .cit-field-hint-tight {
    margin-top: calc(-4px * var(--mdt-scale));
  }

  .cit-form-input,
  .cit-form-textarea {
    width: 100%;
    box-sizing: border-box;
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

  .cit-form-input::placeholder,
  .cit-form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .cit-form-input:focus,
  .cit-form-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .cit-form-textarea {
    resize: vertical;
    line-height: 1.55;
    min-height: calc(64px * var(--mdt-scale));
  }

  .cit-narrative-textarea {
    min-height: calc(200px * var(--mdt-scale));
    line-height: 1.6;
  }

  .cit-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .cit-section-label {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.07em;
    font-family: 'Outfit', sans-serif;
  }

  .cit-section-count {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
  }

  .cit-tag-chips {
    margin-top: calc(2px * var(--mdt-scale));
  }

  .cit-tag-add-row {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: stretch;
    margin-top: calc(6px * var(--mdt-scale));
  }

  .cit-tag-add-row input {
    flex: 1;
    min-width: 0;
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font: inherit;
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale));
  }

  .cit-tag-add-row input:focus {
    outline: none;
    border-color: var(--mdt-accent);
  }

  .cit-btn-add {
    flex-shrink: 0;
    border-radius: var(--mdt-radius-sm);
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    font-family: 'Outfit', sans-serif;
    font-weight: 600;
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 28%, transparent);
    background: color-mix(in srgb, var(--mdt-accent) 14%, transparent);
    color: var(--mdt-accent);
    cursor: pointer;
    transition:
      background 0.12s ease,
      transform 0.1s ease;
  }

  .cit-btn-add:hover {
    background: color-mix(in srgb, var(--mdt-accent) 22%, transparent);
  }

  .cit-btn-add:active {
    transform: scale(0.98);
  }

  .cit-flag-grid {
    margin-top: calc(2px * var(--mdt-scale));
  }

  .cit-subtab-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    flex-shrink: 0;
  }

  .cit-subtab-title {
    margin: 0;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    font-family: 'Outfit', sans-serif;
  }

  .cit-subtab-sub {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Outfit', sans-serif;
  }

  .cit-detail-scroll {
    padding: calc(12px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    overflow-y: auto;
    flex: 1;
    min-height: 0;
    background: linear-gradient(180deg, var(--mdt-surface) 0%, color-mix(in srgb, var(--mdt-surface-2) 35%, var(--mdt-surface)) 100%);
  }

  .cit-detail-sidebar {
    display: flex;
    flex-direction: column;
    gap: 0;
    min-width: 0;
    padding-left: calc(16px * var(--mdt-scale));
    margin-left: calc(2px * var(--mdt-scale));
    border-left: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
  }

  .cit-sidebar-subject {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) 0 calc(12px * var(--mdt-scale));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
    flex-shrink: 0;
  }

  .cit-sidebar-photo {
    width: 100%;
    align-self: stretch;
  }

  .cit-sidebar-photo-img,
  .cit-sidebar-photo-ph {
    width: 100%;
    height: auto;
    aspect-ratio: 1;
    max-height: min(calc(168px * var(--mdt-scale)), 38cqi);
    border-radius: var(--mdt-radius-sm);
    border: 1px solid var(--mdt-border);
    object-fit: cover;
    box-sizing: border-box;
  }

  .cit-sidebar-photo-ph {
    display: grid;
    place-items: center;
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
  }

  .cit-sidebar-eyebrow {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    margin-bottom: calc(4px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    font-family: 'Outfit', sans-serif;
  }

  .cit-sidebar-legal {
    margin: 0;
    font-family: 'Unbounded', 'Outfit', system-ui, sans-serif;
    font-size: calc(17px * var(--mdt-scale));
    font-weight: 650;
    letter-spacing: -0.02em;
    line-height: 1.2;
    color: var(--mdt-text);
  }

  .cit-sidebar-meta-line {
    margin: calc(6px * var(--mdt-scale)) 0 0;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    font-family: 'Outfit', sans-serif;
  }

  .cit-sidebar-dot {
    width: 3px;
    height: 3px;
    border-radius: 50%;
    background: var(--mdt-text-muted);
    opacity: 0.65;
  }

  .cit-sidebar-dl {
    margin-top: calc(8px * var(--mdt-scale));
    padding-top: calc(10px * var(--mdt-scale));
    border-top: 1px dashed color-mix(in srgb, var(--mdt-border) 88%, transparent);
  }

  .cit-detail-sidebar .cp-stat-strip {
    padding: calc(8px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 72%, transparent);
  }

  .cit-detail-sidebar .cp-side-nav {
    padding: calc(8px * var(--mdt-scale)) 0;
    flex: 1;
    min-height: 0;
  }

  .cit-detail-sidebar .cp-glance-muted:last-child {
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  @media (max-width: 960px) {
    .cit-detail-grid {
      grid-template-columns: 1fr;
      gap: calc(12px * var(--mdt-scale));
    }

    .cit-detail-sidebar {
      padding-left: 0;
      margin-left: 0;
      border-left: none;
      padding-top: calc(12px * var(--mdt-scale));
      margin-top: calc(4px * var(--mdt-scale));
      border-top: 1px solid color-mix(in srgb, var(--mdt-border) 65%, transparent);
      order: -1;
      max-height: min(44vh, 460px);
    }

    .cit-detail-main {
      order: 0;
      min-height: min(52vh, 520px);
    }
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

  .cp-display {
    margin: 0;
    font-family: 'Unbounded', 'Outfit', system-ui, sans-serif;
    font-size: calc(26px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.02em;
  }

  /* Citizen registry — compact split layout, table results, rectangular flags */
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
    font-family: 'Unbounded', sans-serif;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .cp-aside-av img {
    width: 100%;
    height: 100%;
    object-fit: cover;
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
    color: var(--mdt-accent);
    font-weight: 600;
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
    grid-template-columns: minmax(0, 1.5fr) minmax(0, 0.72fr) minmax(0, 0.88fr) minmax(0, 1fr) calc(28px * var(--mdt-scale));
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    font-size: calc(11px * var(--mdt-scale));
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
    font-family: 'Unbounded', sans-serif;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-accent);
  }

  .cp-lookup-av img {
    width: 100%;
    height: 100%;
    object-fit: cover;
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

  .cp-td-id {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-accent);
    word-break: break-all;
  }

  .cp-td-phone {
    display: inline-flex;
    align-items: flex-start;
    gap: calc(4px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .cp-td-phone :global(svg) {
    flex-shrink: 0;
    margin-top: calc(2px * var(--mdt-scale));
    opacity: 0.65;
  }

  .cp-lookup-phone-txt {
    word-break: break-all;
    line-height: 1.35;
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

    .cp-lookup-tr {
      min-width: calc(480px * var(--mdt-scale));
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

  .cp-empty {
    padding: calc(28px * var(--mdt-scale));
    text-align: center;
    color: var(--mdt-text-muted);
    font-size: calc(14px * var(--mdt-scale));
    background: var(--mdt-surface);
    border-radius: calc(12px * var(--mdt-scale));
    border: 1px dashed var(--mdt-border);
  }

  .cp-empty-tight {
    padding: calc(16px * var(--mdt-scale));
    font-size: calc(13px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
  }

  .cp-sheet {
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    overflow: hidden;
  }

  .cp-sheet-flush {
    border-radius: calc(8px * var(--mdt-scale));
  }

  .cp-row {
    display: grid;
    grid-template-columns: 1.5fr 1fr 1fr 1fr 1.2fr;
    gap: calc(12px * var(--mdt-scale));
    align-items: center;
    padding: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    font-size: calc(13px * var(--mdt-scale));
  }

  .cp-row:first-child {
    border-top: 0;
  }

  .cp-row-head {
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    border-top: 0;
  }

  .cp-grid-reports {
    grid-template-columns: 1.5fr 0.8fr 0.8fr 0.9fr;
  }

  .cp-grid-warrants {
    grid-template-columns: 1.8fr 0.8fr 0.8fr;
  }

  .cp-grid-veh {
    grid-template-columns: 1fr 1.2fr 0.75fr;
  }

  .cp-subject-readonly {
    margin: calc(8px * var(--mdt-scale)) 0 0;
    padding-top: calc(8px * var(--mdt-scale));
    border-top: 1px dashed color-mix(in srgb, var(--mdt-border) 88%, transparent);
    width: 100%;
    max-width: 100%;
    text-align: left;
  }

  .cp-subject-readonly-row {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    gap: calc(8px * var(--mdt-scale));
    align-items: baseline;
    margin-top: calc(4px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
  }

  .cp-subject-readonly-row:first-of-type {
    margin-top: 0;
  }

  .cp-subject-readonly-row dt {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    margin: 0;
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    white-space: nowrap;
  }

  .cp-subject-readonly-row dt :global(svg) {
    flex-shrink: 0;
    opacity: 0.88;
  }

  .cp-subject-readonly-row-wide {
    align-items: start;
  }

  .cp-subject-readonly-row dd {
    margin: 0;
    color: var(--mdt-text-dim);
    word-break: break-word;
  }

  .cp-subject-wrap {
    overflow-wrap: anywhere;
  }

  .cp-tag-chips {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
    min-height: calc(4px * var(--mdt-scale));
  }

  .cp-tag-chip {
    display: inline-flex;
    align-items: center;
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    border: 1px solid transparent;
    background: var(--mdt-surface-3);
    color: #fff;
    cursor: context-menu;
    transition: transform 0.12s ease, box-shadow 0.12s ease;
  }

  .cp-tag-chip:hover {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    box-shadow: 0 calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) color-mix(in srgb, var(--mdt-bg) 40%, transparent);
  }

  .cp-tag-red {
    border-color: #dc2626;
    background: #dc2626;
    color: #fff;
  }
  .cp-tag-orange {
    border-color: #ea580c;
    background: #ea580c;
    color: #fff;
  }
  .cp-tag-yellow {
    border-color: #ca8a04;
    background: #ca8a04;
    color: #fff;
  }
  .cp-tag-green {
    border-color: #16a34a;
    background: #16a34a;
    color: #fff;
  }
  .cp-tag-cyan {
    border-color: #0891b2;
    background: #0891b2;
    color: #fff;
  }
  .cp-tag-blue {
    border-color: #2563eb;
    background: #2563eb;
    color: #fff;
  }
  .cp-tag-purple {
    border-color: #9333ea;
    background: #9333ea;
    color: #fff;
  }
  .cp-tag-white {
    border-color: #64748b;
    background: #64748b;
    color: #fff;
  }

  .cp-tag-menu {
    position: fixed;
    z-index: 5000;
    min-width: calc(168px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface);
    box-shadow:
      0 calc(12px * var(--mdt-scale)) calc(40px * var(--mdt-scale)) color-mix(in srgb, var(--mdt-bg) 55%, transparent),
      0 0 0 1px color-mix(in srgb, var(--mdt-accent) 12%, transparent);
  }

  .cp-tag-menu-title {
    padding: calc(4px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .cp-tag-menu-opt {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    width: 100%;
    padding: calc(7px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border: 0;
    border-radius: calc(8px * var(--mdt-scale));
    background: transparent;
    color: var(--mdt-text);
    font: inherit;
    font-size: calc(12px * var(--mdt-scale));
    cursor: pointer;
    text-align: left;
  }

  .cp-tag-menu-opt:hover {
    background: var(--mdt-surface-3);
  }

  .cp-tag-swatch {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    border-radius: 50%;
    border: 1px solid color-mix(in srgb, var(--mdt-border) 80%, transparent);
    flex-shrink: 0;
  }

  .cp-tag-swatch-red {
    background: #ef4444;
  }
  .cp-tag-swatch-orange {
    background: #f97316;
  }
  .cp-tag-swatch-yellow {
    background: #eab308;
  }
  .cp-tag-swatch-green {
    background: #22c55e;
  }
  .cp-tag-swatch-cyan {
    background: #06b6d4;
  }
  .cp-tag-swatch-blue {
    background: #3b82f6;
  }
  .cp-tag-swatch-purple {
    background: #a855f7;
  }
  .cp-tag-swatch-white {
    background: #f8fafc;
  }

  .cp-stat-strip {
    display: flex;
    flex-wrap: wrap;
    align-items: stretch;
    gap: 0;
    padding: calc(6px * var(--mdt-scale)) 0;
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-border) 90%, transparent);
    row-gap: calc(4px * var(--mdt-scale));
  }

  .cp-stat-mini {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    padding: 0 calc(8px * var(--mdt-scale));
    min-width: 0;
    flex: 1 1 auto;
  }

  .cp-stat-mini:first-child {
    padding-left: 0;
    flex: 1 1 140px;
  }

  .cp-stat-mini-k {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    font-size: calc(8px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    white-space: nowrap;
  }

  .cp-stat-mini-k :global(svg) {
    flex-shrink: 0;
    opacity: 0.85;
  }

  .cp-stat-mini-n {
    font-family: 'Share Tech Mono', 'JetBrains Mono', ui-monospace, monospace;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: -0.02em;
    line-height: 1.15;
    color: var(--mdt-text);
    font-variant-numeric: tabular-nums;
  }

  .cp-stat-mini-phone {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    line-height: 1.2;
    word-break: break-all;
    color: var(--mdt-text-dim);
    font-family: inherit;
  }

  .cp-stat-div {
    align-self: stretch;
    width: 1px;
    margin: calc(2px * var(--mdt-scale)) 0;
    background: color-mix(in srgb, var(--mdt-border) 75%, transparent);
    flex-shrink: 0;
  }

  .cp-k-row {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
  }

  .cp-glance {
    margin: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) 0;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.35;
  }

  .cp-glance-danger {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    background: color-mix(in srgb, var(--mdt-error) 14%, var(--mdt-surface));
    border: 1px solid color-mix(in srgb, var(--mdt-error) 40%, var(--mdt-border));
    color: var(--mdt-error);
    font-weight: 600;
  }

  .cp-glance-muted {
    background: var(--mdt-surface-3);
    border: 1px dashed var(--mdt-border);
    color: var(--mdt-text-dim);
  }

  .cp-glance-body {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .cp-side-nav {
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }

  .cp-nav-item {
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    border: 1px solid transparent;
    background: transparent;
    color: var(--mdt-text-dim);
    font: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    text-align: left;
    cursor: pointer;
    transition:
      background 0.12s ease,
      border-color 0.12s ease,
      color 0.12s ease;
  }

  .cp-nav-item:hover {
    background: color-mix(in srgb, var(--mdt-surface-3) 80%, transparent);
    color: var(--mdt-text);
  }

  .cp-nav-item.active {
    background: var(--mdt-surface);
    border-color: var(--mdt-border-2);
    color: var(--mdt-text);
    box-shadow: 0 1px 0 color-mix(in srgb, var(--mdt-accent) 25%, transparent);
  }

  .cp-nav-ico {
    display: flex;
    color: var(--mdt-text-muted);
  }

  .cp-nav-item.active .cp-nav-ico {
    color: var(--mdt-accent);
  }

  .cp-nav-badge {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    padding: calc(2px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border);
    color: var(--mdt-text-muted);
  }

  .cp-nav-item.active .cp-nav-badge {
    border-color: color-mix(in srgb, var(--mdt-accent) 35%, var(--mdt-border));
    color: var(--mdt-text);
  }

  @keyframes cp-rot {
    to {
      transform: rotate(360deg);
    }
  }

  .cp-btn-save-licenses {
    border-color: color-mix(in srgb, #f59e0b 45%, var(--mdt-border));
    background: linear-gradient(145deg, #fbbf24 0%, #d97706 55%, #b45309 100%);
    color: #1c1917;
    font-weight: 600;
    box-shadow: 0 calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) color-mix(in srgb, #d97706 30%, transparent);
  }

  .cp-btn-save-licenses:hover:not(:disabled) {
    filter: brightness(1.05);
  }

  .cp-k {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .cp-field {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .cp-field input {
    padding: calc(11px * var(--mdt-scale)) calc(13px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
    font: inherit;
  }

  .cp-field-tight input[type='date'] {
    padding: calc(9px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
  }

  .cp-split {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(12px * var(--mdt-scale));
  }

  .cp-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
    font: inherit;
    font-weight: 500;
    cursor: pointer;
  }

  .cp-btn:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .cp-btn-accent {
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    background: linear-gradient(135deg, color-mix(in srgb, var(--mdt-accent) 88%, var(--mdt-bg)), color-mix(in srgb, var(--mdt-accent) 55%, var(--mdt-bg)));
    color: var(--mdt-bg);
  }

  :global([data-theme='cortex']) .cp-btn-accent {
    color: #1a1410;
  }

  .cp-btn-ghost {
    background: transparent;
    border-style: dashed;
    align-self: center;
  }

  .cp-flag-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: calc(8px * var(--mdt-scale));
  }

  .cp-flag-grid-dense {
    grid-template-columns: repeat(auto-fill, minmax(calc(118px * var(--mdt-scale)), 1fr));
    gap: calc(6px * var(--mdt-scale));
  }

  .cp-flag {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(9px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    color: var(--mdt-text-dim);
    font: inherit;
    font-size: calc(11px * var(--mdt-scale));
    cursor: pointer;
    text-align: left;
    transition: border-color 0.12s ease, background 0.12s ease, color 0.12s ease, box-shadow 0.12s ease;
  }

  .cp-flag.on {
    color: #fff;
    box-shadow: 0 calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) color-mix(in srgb, var(--mdt-bg) 45%, transparent);
  }

  .cp-flag.on :global(svg) {
    stroke: #fff;
    opacity: 0.95;
  }

  .cp-flag.on.info {
    border-color: #2563eb;
    background: #2563eb;
  }

  .cp-flag.on.warning {
    border-color: #d97706;
    background: #d97706;
  }

  .cp-flag.on.danger {
    border-color: #dc2626;
    background: #dc2626;
  }

  .cp-tags {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
  }

  .cp-status {
    display: inline-flex;
    align-items: center;
    padding: calc(3px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    border: 1px solid var(--mdt-border);
    width: fit-content;
  }

  .cp-status.good {
    color: var(--mdt-success);
    border-color: color-mix(in srgb, var(--mdt-success) 35%, transparent);
    background: color-mix(in srgb, var(--mdt-success) 10%, var(--mdt-surface));
  }

  .cp-status.warn {
    color: var(--mdt-warning);
    border-color: color-mix(in srgb, var(--mdt-warning) 35%, transparent);
    background: color-mix(in srgb, var(--mdt-warning) 10%, var(--mdt-surface));
  }

  .cp-status.danger {
    color: var(--mdt-error);
    border-color: color-mix(in srgb, var(--mdt-error) 35%, transparent);
    background: color-mix(in srgb, var(--mdt-error) 10%, var(--mdt-surface));
  }

  .cp-status.neutral {
    color: var(--mdt-text-dim);
  }

  .cp-license-add {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: calc(8px * var(--mdt-scale));
    margin-bottom: calc(10px * var(--mdt-scale));
    align-items: start;
  }

  .cp-license-list {
    display: flex;
    flex-direction: column;
    gap: 0;
    border: 1px solid var(--mdt-border);
    border-radius: calc(10px * var(--mdt-scale));
    overflow: hidden;
    background: var(--mdt-surface);
  }

  .cp-license-row {
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(0, 0.95fr) minmax(0, 0.95fr) auto;
    gap: calc(12px * var(--mdt-scale));
    align-items: end;
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
  }

  .cp-license-row:first-child {
    border-top: 0;
  }

  .cp-license-row:nth-child(even) {
    background: color-mix(in srgb, var(--mdt-surface-3) 35%, var(--mdt-surface));
  }

  .cp-license-type strong {
    display: block;
    margin-top: calc(4px * var(--mdt-scale));
    font-size: calc(15px * var(--mdt-scale));
  }

  .mono {
    font-family: 'Share Tech Mono', 'Courier New', monospace;
  }

  .muted {
    color: var(--mdt-text-muted);
  }

  @media (max-width: 980px) {
    .cp-split,
    .cp-license-add,
    .cp-license-row {
      grid-template-columns: 1fr;
    }

    .cp-row,
    .cp-grid-reports,
    .cp-grid-warrants,
    .cp-grid-veh {
      grid-template-columns: 1fr;
    }
  }
</style>
