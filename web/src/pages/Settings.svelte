<script>
  import { onMount } from 'svelte';
  import { themeStore } from '../lib/stores/theme.svelte.js';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import {
    Palette,
    Users,
    Megaphone,
    Settings as SettingsIcon,
    ScrollText,
    Search,
    Save,
    Trash2,
    ChevronDown,
    ChevronRight,
    Pin,
    PinOff,
    X,
    Plus,
    Shield,
    AlertCircle,
    Check,
    Loader2,
    Keyboard,
    RotateCcw,
  } from 'lucide-svelte';
  import { hotkeysStore } from '../lib/stores/hotkeys.svelte.js';

  const TABS = [
    { id: 'appearance', label: 'Appearance', icon: Palette },
    { id: 'hotkeys', label: 'Hotkeys', icon: Keyboard },
    { id: 'roster', label: 'Roster', icon: Users },
    { id: 'announcements', label: 'Announcements', icon: Megaphone },
    { id: 'system', label: 'System', icon: SettingsIcon },
    { id: 'audit', label: 'Audit Logs', icon: ScrollText },
  ];

  const STATUS_OPTIONS = ['active', 'suspended', 'inactive'];

  let activeTab = $state('appearance');
  let mounted = $state(false);

  let avatarInput = $state(mdtStore.settings.avatarUrl || '');
  let callsignInput = $state(mdtStore.settings.callsign || '');

  let rosterSearch = $state('');
  let expandedOfficer = $state(null);
  let rosterSaving = $state(false);
  let editRank = $state('');
  let editCallsign = $state('');
  let editDepartment = $state('');
  let editCerts = $state([]);
  let editStatus = $state('active');

  let annTitle = $state('');
  let annContent = $state('');
  let annDepartment = $state('');
  let annPinned = $state(false);
  let annSaving = $state(false);
  let annDeleting = $state(null);

  let settingSaving = $state(null);
  let localSettings = $state({});

  let auditSearch = $state('');
  let auditPage = $state(1);
  let auditLoading = $state(false);
  let expandedLog = $state(null);

  let recordingHotkey = $state(null);
  let recordedCombo = $state('');

  let roster = $derived(dataStore.adminRoster || []);
  let config = $derived(dataStore.configData || {});
  let announcements = $derived(dataStore.dashboardAnnouncements || []);
  let settings = $derived(dataStore.adminSettings || {});
  let auditLogs = $derived(dataStore.adminAuditLogs || []);

  let filteredRoster = $derived.by(() => {
    if (!rosterSearch.trim()) return roster;
    const q = rosterSearch.toLowerCase();
    return roster.filter(o =>
      `${o.first_name} ${o.last_name}`.toLowerCase().includes(q) ||
      (o.callsign && o.callsign.toLowerCase().includes(q)) ||
      (o.rank && o.rank.toLowerCase().includes(q)) ||
      (o.department && o.department.toLowerCase().includes(q))
    );
  });

  let filteredLogs = $derived.by(() => {
    if (!auditSearch.trim()) return auditLogs;
    const q = auditSearch.toLowerCase();
    return auditLogs.filter(l =>
      `${l.first_name} ${l.last_name}`.toLowerCase().includes(q) ||
      (l.action && l.action.toLowerCase().includes(q)) ||
      (l.callsign && l.callsign.toLowerCase().includes(q)) ||
      (l.category && l.category.toLowerCase().includes(q))
    );
  });

  let departments = $derived(config.departments || []);
  let certifications = $derived(config.certifications || []);

  function ranksForDept(dept) {
    if (!config.ranks) return [];
    return config.ranks[dept] || config.ranks['default'] || [];
  }

  function selectTheme(themeId) {
    themeStore.apply(themeId);
    mdtStore.settings = { theme: themeId };
  }

  function saveAvatar() {
    mdtStore.settings = { avatarUrl: avatarInput || null };
    mdtStore.officer = { avatar: avatarInput || null };
  }

  function saveCallsign() {
    const trimmed = callsignInput.trim();
    mdtStore.settings = { callsign: trimmed || '' };
    if (trimmed) {
      mdtStore.officer = { callsign: trimmed };
    }
  }

  function switchTab(tabId) {
    activeTab = tabId;
    if (tabId === 'roster' && roster.length === 0) {
      dataStore.fetchRoster();
      if (!config.departments) dataStore.fetchConfig();
    }
    if (tabId === 'announcements' && announcements.length === 0) {
      dataStore.fetchDashboard();
    }
    if (tabId === 'system') {
      dataStore.fetchSettings().then(() => {
        localSettings = { ...dataStore.adminSettings };
      });
    }
    if (tabId === 'audit' && auditLogs.length === 0) {
      auditPage = 1;
      loadAuditLogs();
    }
  }

  function expandOfficer(officer) {
    if (expandedOfficer === officer.id) {
      expandedOfficer = null;
      return;
    }
    expandedOfficer = officer.id;
    editRank = officer.rank || '';
    editCallsign = officer.callsign || '';
    editDepartment = officer.department || '';
    editCerts = officer.certifications ? [...officer.certifications] : [];
    editStatus = officer.status || 'active';
  }

  function toggleCert(cert) {
    if (editCerts.includes(cert)) {
      editCerts = editCerts.filter(c => c !== cert);
    } else {
      editCerts = [...editCerts, cert];
    }
  }

  async function saveOfficer(officerId) {
    rosterSaving = true;
    await dataStore.updateOfficer({
      officerId,
      rank: editRank,
      callsign: editCallsign,
      department: editDepartment,
      certifications: editCerts,
      status: editStatus,
    });
    await dataStore.fetchRoster();
    expandedOfficer = null;
    rosterSaving = false;
  }

  async function submitAnnouncement() {
    if (!annTitle.trim() || !annContent.trim()) return;
    annSaving = true;
    await dataStore.createAnnouncement({
      title: annTitle,
      content: annContent,
      department: annDepartment || null,
      pinned: annPinned,
    });
    annTitle = '';
    annContent = '';
    annDepartment = '';
    annPinned = false;
    await dataStore.fetchDashboard();
    annSaving = false;
  }

  async function removeAnnouncement(id) {
    annDeleting = id;
    await dataStore.deleteAnnouncement(id);
    await dataStore.fetchDashboard();
    annDeleting = null;
  }

  async function saveSetting(key) {
    settingSaving = key;
    await dataStore.updateSetting(key, localSettings[key]);
    settingSaving = null;
  }

  async function loadAuditLogs() {
    auditLoading = true;
    await dataStore.fetchAuditLogs(auditPage, auditSearch || null);
    auditLoading = false;
  }

  function loadMoreLogs() {
    auditPage += 1;
    loadAuditLogs();
  }

  function formatDate(dateStr) {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }

  function formatDateTime(dateStr) {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  function statusColor(status) {
    if (status === 'active') return 'var(--mdt-success)';
    if (status === 'suspended') return 'var(--mdt-error)';
    return 'var(--mdt-text-muted)';
  }

  function startRecording(action) {
    recordingHotkey = action;
    recordedCombo = '';
  }

  function cancelRecording() {
    recordingHotkey = null;
    recordedCombo = '';
  }

  function handleHotkeyKeydown(e) {
    if (!recordingHotkey) return;
    e.preventDefault();
    e.stopPropagation();

    if (e.key === 'Escape') {
      cancelRecording();
      return;
    }

    const modifiers = [];
    if (e.ctrlKey || e.metaKey) modifiers.push('Ctrl');
    if (e.shiftKey) modifiers.push('Shift');
    if (e.altKey) modifiers.push('Alt');

    const key = e.key;
    if (['Control', 'Shift', 'Alt', 'Meta'].includes(key)) {
      recordedCombo = modifiers.join('+') + '+...';
      return;
    }

    let keyName = key;
    if (key === 'Tab') keyName = 'Tab';
    else if (key.length === 1) keyName = key.toUpperCase();

    const combo = [...modifiers, keyName].join('+');
    hotkeysStore.updateBinding(recordingHotkey, combo);
    recordingHotkey = null;
    recordedCombo = '';
  }

  onMount(() => {
    mounted = true;
  });
</script>

<div class="settings-page" class:mounted>
  <h2 class="page-title">Settings</h2>

  <div class="tab-bar">
    {#each TABS as tab (tab.id)}
      <button
        class="tab-btn"
        class:active={activeTab === tab.id}
        onclick={() => switchTab(tab.id)}
      >
        <tab.icon size={15} strokeWidth={1.8} />
        <span class="tab-label">{tab.label}</span>
        {#if activeTab === tab.id}
          <div class="tab-indicator"></div>
        {/if}
      </button>
    {/each}
  </div>

  <div class="tab-content">
    {#if activeTab === 'appearance'}
      <div class="content-panel" class:mounted>
        <section class="settings-section">
          <h3 class="section-title">Accent Theme</h3>
          <p class="section-desc">Choose an accent color for the MDT interface.</p>
          <div class="theme-grid">
            {#each themeStore.themes as theme (theme.id)}
              <button
                class="theme-swatch"
                class:active={themeStore.current === theme.id}
                style="--swatch: {theme.accent}"
                onclick={() => selectTheme(theme.id)}
                title={theme.label}
              >
                <span class="swatch-dot"></span>
                <span class="swatch-label">{theme.label}</span>
              </button>
            {/each}
          </div>
        </section>

        <section class="settings-section">
          <h3 class="section-title">Avatar</h3>
          <p class="section-desc">Paste an image URL to set your profile avatar.</p>
          <div class="avatar-form">
            <div class="avatar-preview">
              {#if avatarInput}
                <img src={avatarInput} alt="Preview" class="avatar-img" />
              {:else}
                <div class="avatar-empty">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <circle cx="12" cy="8" r="4" /><path d="M20 21a8 8 0 00-16 0" />
                  </svg>
                </div>
              {/if}
            </div>
            <div class="avatar-input-group">
              <input
                type="text"
                class="text-input"
                placeholder="https://example.com/avatar.png"
                bind:value={avatarInput}
                onkeydown={(e) => { if (e.key === 'Enter') saveAvatar(); }}
              />
              <button class="btn-primary" onclick={saveAvatar}>
                <Save size={13} strokeWidth={2} />
                Save
              </button>
            </div>
          </div>
        </section>

        <section class="settings-section">
          <h3 class="section-title">Callsign</h3>
          <p class="section-desc">Override your officer callsign displayed in the MDT. Leave blank to use the server-assigned callsign.</p>
          <div class="callsign-form">
            <input
              type="text"
              class="text-input mono"
              placeholder="e.g. 1-A-12"
              bind:value={callsignInput}
              onkeydown={(e) => { if (e.key === 'Enter') saveCallsign(); }}
            />
            <button class="btn-primary" onclick={saveCallsign}>
              <Save size={13} strokeWidth={2} />
              Save
            </button>
          </div>
        </section>
      </div>

    {:else if activeTab === 'hotkeys'}
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="content-panel" class:mounted onkeydown={handleHotkeyKeydown}>
        <section class="settings-section">
          <h3 class="section-title">Keyboard Shortcuts</h3>
          <p class="section-desc">Customize hotkeys for tab navigation. Click a binding to record a new shortcut. Press Escape to cancel.</p>

          <div class="hotkey-list">
            {#each Object.entries(hotkeysStore.labels) as [action, label] (action)}
              <div class="hotkey-row">
                <div class="hotkey-info">
                  <span class="hotkey-label">{label}</span>
                  <span class="hotkey-desc">{hotkeysStore.descriptions[action]}</span>
                </div>
                <div class="hotkey-binding-wrap">
                  {#if recordingHotkey === action}
                    <button class="hotkey-binding recording" onblur={cancelRecording}>
                      <span class="hotkey-recording-pulse"></span>
                      <span class="hotkey-recording-text">{recordedCombo || 'Press keys...'}</span>
                    </button>
                  {:else}
                    <button class="hotkey-binding" onclick={() => startRecording(action)}>
                      {#each hotkeysStore.bindings[action].split('+') as part, i}
                        <kbd class="hotkey-key">{part}</kbd>
                        {#if i < hotkeysStore.bindings[action].split('+').length - 1}
                          <span class="hotkey-plus">+</span>
                        {/if}
                      {/each}
                    </button>
                  {/if}
                  {#if hotkeysStore.bindings[action] !== hotkeysStore.defaults[action]}
                    <button
                      class="hotkey-reset"
                      onclick={() => hotkeysStore.updateBinding(action, hotkeysStore.defaults[action])}
                      title="Reset to default"
                    >
                      <RotateCcw size={11} strokeWidth={2} />
                    </button>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        </section>

        <section class="settings-section">
          <h3 class="section-title">Quick Reference</h3>
          <p class="section-desc">Additional shortcuts that are always available.</p>
          <div class="hotkey-list">
            <div class="hotkey-row static">
              <div class="hotkey-info">
                <span class="hotkey-label">Go to Tab 1-9</span>
                <span class="hotkey-desc">Jump directly to a tab by its position</span>
              </div>
              <div class="hotkey-binding-wrap">
                <span class="hotkey-binding static">
                  <kbd class="hotkey-key">Ctrl</kbd>
                  <span class="hotkey-plus">+</span>
                  <kbd class="hotkey-key">1</kbd>
                  <span class="hotkey-range">-</span>
                  <kbd class="hotkey-key">9</kbd>
                </span>
              </div>
            </div>
            <div class="hotkey-row static">
              <div class="hotkey-info">
                <span class="hotkey-label">Middle-click Tab</span>
                <span class="hotkey-desc">Close a tab by middle-clicking it</span>
              </div>
              <div class="hotkey-binding-wrap">
                <span class="hotkey-binding static">
                  <kbd class="hotkey-key">Middle Mouse</kbd>
                </span>
              </div>
            </div>
          </div>
        </section>

        <div class="hotkey-reset-all">
          <button class="btn-secondary" onclick={() => hotkeysStore.resetToDefaults()}>
            <RotateCcw size={13} strokeWidth={2} />
            Reset All to Defaults
          </button>
        </div>
      </div>

    {:else if activeTab === 'roster'}
      <div class="content-panel wide" class:mounted>
        <div class="panel-header">
          <div class="search-box">
            <Search size={14} strokeWidth={2} />
            <input
              type="text"
              class="search-input"
              placeholder="Search officers..."
              bind:value={rosterSearch}
            />
            {#if rosterSearch}
              <button class="search-clear" onclick={() => rosterSearch = ''}>
                <X size={12} strokeWidth={2} />
              </button>
            {/if}
          </div>
          <span class="result-count">{filteredRoster.length} officers</span>
        </div>

        <div class="roster-table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th class="th-expand"></th>
                <th>Name</th>
                <th>Callsign</th>
                <th>Rank</th>
                <th>Department</th>
                <th>Status</th>
                <th>Certifications</th>
              </tr>
            </thead>
            <tbody>
              {#each filteredRoster as officer (officer.id)}
                <tr
                  class="roster-row"
                  class:expanded={expandedOfficer === officer.id}
                  onclick={() => expandOfficer(officer)}
                >
                  <td class="td-expand">
                    {#if expandedOfficer === officer.id}
                      <ChevronDown size={14} strokeWidth={2} />
                    {:else}
                      <ChevronRight size={14} strokeWidth={2} />
                    {/if}
                  </td>
                  <td class="td-name">
                    {#if officer.avatar}
                      <img src={officer.avatar} alt="" class="roster-avatar" />
                    {:else}
                      <div class="roster-avatar-empty">
                        <Shield size={11} strokeWidth={2} />
                      </div>
                    {/if}
                    {officer.first_name} {officer.last_name}
                  </td>
                  <td class="td-mono">{officer.callsign || '—'}</td>
                  <td>{officer.rank || '—'}</td>
                  <td>{officer.department || '—'}</td>
                  <td>
                    <span class="status-badge" style="--badge-color: {statusColor(officer.status)}">
                      {officer.status || 'active'}
                    </span>
                  </td>
                  <td class="td-certs">
                    {#if officer.certifications?.length}
                      {#each officer.certifications as cert}
                        <span class="cert-pill">{cert}</span>
                      {/each}
                    {:else}
                      <span class="text-muted">None</span>
                    {/if}
                  </td>
                </tr>
                {#if expandedOfficer === officer.id}
                  <tr class="edit-row">
                    <td colspan="7">
                      <div class="edit-form">
                        <div class="edit-grid">
                          <div class="edit-field">
                            <label class="field-label">Rank</label>
                            <select class="field-select" bind:value={editRank}>
                              <option value="">Select rank</option>
                              {#each ranksForDept(editDepartment) as rank}
                                <option value={rank}>{rank}</option>
                              {/each}
                              {#if editRank && !ranksForDept(editDepartment).includes(editRank)}
                                <option value={editRank}>{editRank}</option>
                              {/if}
                            </select>
                          </div>
                          <div class="edit-field">
                            <label class="field-label">Callsign</label>
                            <input type="text" class="field-input" bind:value={editCallsign} placeholder="e.g. 1-A-12" />
                          </div>
                          <div class="edit-field">
                            <label class="field-label">Department</label>
                            <select class="field-select" bind:value={editDepartment}>
                              <option value="">Select department</option>
                              {#each departments as dept}
                                <option value={dept}>{dept}</option>
                              {/each}
                              {#if editDepartment && !departments.includes(editDepartment)}
                                <option value={editDepartment}>{editDepartment}</option>
                              {/if}
                            </select>
                          </div>
                          <div class="edit-field">
                            <label class="field-label">Status</label>
                            <select class="field-select" bind:value={editStatus}>
                              {#each STATUS_OPTIONS as s}
                                <option value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
                              {/each}
                            </select>
                          </div>
                        </div>
                        <div class="edit-field wide">
                          <label class="field-label">Certifications</label>
                          <div class="cert-checks">
                            {#each certifications as cert}
                              <label class="cert-check">
                                <input
                                  type="checkbox"
                                  checked={editCerts.includes(cert)}
                                  onchange={() => toggleCert(cert)}
                                />
                                <span class="cert-check-label">{cert}</span>
                              </label>
                            {/each}
                            {#if certifications.length === 0}
                              <span class="text-muted">No certifications configured</span>
                            {/if}
                          </div>
                        </div>
                        <div class="edit-actions">
                          <button class="btn-primary" onclick={() => saveOfficer(officer.id)} disabled={rosterSaving}>
                            {#if rosterSaving}
                              <Loader2 size={13} strokeWidth={2} class="spin" />
                            {:else}
                              <Save size={13} strokeWidth={2} />
                            {/if}
                            Save Changes
                          </button>
                          <button class="btn-secondary" onclick={() => expandedOfficer = null}>
                            Cancel
                          </button>
                        </div>
                      </div>
                    </td>
                  </tr>
                {/if}
              {/each}
              {#if filteredRoster.length === 0}
                <tr>
                  <td colspan="7" class="empty-row">
                    <div class="empty-state">
                      <Users size={28} strokeWidth={1.2} />
                      <span>No officers found</span>
                    </div>
                  </td>
                </tr>
              {/if}
            </tbody>
          </table>
        </div>
      </div>

    {:else if activeTab === 'announcements'}
      <div class="content-panel" class:mounted>
        <section class="settings-section">
          <h3 class="section-title">Create Announcement</h3>
          <div class="ann-form">
            <div class="ann-row">
              <div class="ann-field grow">
                <label class="field-label">Title</label>
                <input type="text" class="field-input" bind:value={annTitle} placeholder="Announcement title" />
              </div>
              <div class="ann-field">
                <label class="field-label">Department</label>
                <select class="field-select" bind:value={annDepartment}>
                  <option value="">All Departments</option>
                  {#each departments as dept}
                    <option value={dept}>{dept}</option>
                  {/each}
                </select>
              </div>
            </div>
            <div class="ann-field">
              <label class="field-label">Content</label>
              <textarea class="field-textarea" bind:value={annContent} placeholder="Write announcement content..." rows="4"></textarea>
            </div>
            <div class="ann-footer">
              <label class="pin-toggle">
                <input type="checkbox" bind:checked={annPinned} />
                <Pin size={13} strokeWidth={2} />
                <span>Pin announcement</span>
              </label>
              <button class="btn-primary" onclick={submitAnnouncement} disabled={annSaving || !annTitle.trim() || !annContent.trim()}>
                {#if annSaving}
                  <Loader2 size={13} strokeWidth={2} class="spin" />
                {:else}
                  <Plus size={13} strokeWidth={2} />
                {/if}
                Publish
              </button>
            </div>
          </div>
        </section>

        <section class="settings-section">
          <h3 class="section-title">Active Announcements</h3>
          {#if announcements.length === 0}
            <div class="empty-state compact">
              <Megaphone size={24} strokeWidth={1.2} />
              <span>No announcements yet</span>
            </div>
          {:else}
            <div class="ann-list">
              {#each announcements as ann (ann.id)}
                <div class="ann-card">
                  <div class="ann-card-header">
                    <div class="ann-card-title-row">
                      {#if ann.pinned}
                        <Pin size={13} strokeWidth={2} class="pin-icon" />
                      {/if}
                      <span class="ann-card-title">{ann.title}</span>
                    </div>
                    <button
                      class="btn-icon danger"
                      onclick={() => removeAnnouncement(ann.id)}
                      disabled={annDeleting === ann.id}
                      title="Delete announcement"
                    >
                      {#if annDeleting === ann.id}
                        <Loader2 size={13} strokeWidth={2} class="spin" />
                      {:else}
                        <Trash2 size={13} strokeWidth={2} />
                      {/if}
                    </button>
                  </div>
                  <p class="ann-card-content">{ann.content}</p>
                  <div class="ann-card-meta">
                    {#if ann.author}
                      <span class="ann-meta-item">{ann.author}</span>
                    {/if}
                    {#if ann.department}
                      <span class="ann-meta-item">{ann.department}</span>
                    {/if}
                    <span class="ann-meta-item">{formatDate(ann.created_at)}</span>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </section>
      </div>

    {:else if activeTab === 'system'}
      <div class="content-panel" class:mounted>
        <section class="settings-section">
          <h3 class="section-title">System Configuration</h3>
          <p class="section-desc">Manage global MDT settings. Changes are saved individually.</p>

          <div class="sys-fields">
            <div class="sys-field">
              <div class="sys-field-header">
                <label class="field-label">Message of the Day</label>
                <button
                  class="btn-save-sm"
                  onclick={() => saveSetting('motd')}
                  disabled={settingSaving === 'motd'}
                >
                  {#if settingSaving === 'motd'}
                    <Loader2 size={12} strokeWidth={2} class="spin" />
                  {:else}
                    <Save size={12} strokeWidth={2} />
                  {/if}
                  Save
                </button>
              </div>
              <textarea
                class="field-textarea"
                bind:value={localSettings.motd}
                placeholder="Welcome message displayed on the dashboard..."
                rows="3"
              ></textarea>
            </div>

            <div class="sys-row">
              <div class="sys-field">
                <div class="sys-field-header">
                  <label class="field-label">Report Prefix</label>
                  <button
                    class="btn-save-sm"
                    onclick={() => saveSetting('report_prefix')}
                    disabled={settingSaving === 'report_prefix'}
                  >
                    {#if settingSaving === 'report_prefix'}
                      <Loader2 size={12} strokeWidth={2} class="spin" />
                    {:else}
                      <Save size={12} strokeWidth={2} />
                    {/if}
                    Save
                  </button>
                </div>
                <input
                  type="text"
                  class="field-input mono"
                  bind:value={localSettings.report_prefix}
                  placeholder="RPT"
                />
              </div>

              <div class="sys-field">
                <div class="sys-field-header">
                  <label class="field-label">Case Prefix</label>
                  <button
                    class="btn-save-sm"
                    onclick={() => saveSetting('case_prefix')}
                    disabled={settingSaving === 'case_prefix'}
                  >
                    {#if settingSaving === 'case_prefix'}
                      <Loader2 size={12} strokeWidth={2} class="spin" />
                    {:else}
                      <Save size={12} strokeWidth={2} />
                    {/if}
                    Save
                  </button>
                </div>
                <input
                  type="text"
                  class="field-input mono"
                  bind:value={localSettings.case_prefix}
                  placeholder="CASE"
                />
              </div>

              <div class="sys-field">
                <div class="sys-field-header">
                  <label class="field-label">Evidence Prefix</label>
                  <button
                    class="btn-save-sm"
                    onclick={() => saveSetting('evidence_prefix')}
                    disabled={settingSaving === 'evidence_prefix'}
                  >
                    {#if settingSaving === 'evidence_prefix'}
                      <Loader2 size={12} strokeWidth={2} class="spin" />
                    {:else}
                      <Save size={12} strokeWidth={2} />
                    {/if}
                    Save
                  </button>
                </div>
                <input
                  type="text"
                  class="field-input mono"
                  bind:value={localSettings.evidence_prefix}
                  placeholder="EV"
                />
              </div>
            </div>
          </div>
        </section>
      </div>

    {:else if activeTab === 'audit'}
      <div class="content-panel wide" class:mounted>
        <div class="panel-header">
          <div class="search-box">
            <Search size={14} strokeWidth={2} />
            <input
              type="text"
              class="search-input"
              placeholder="Search by officer or action..."
              bind:value={auditSearch}
              onkeydown={(e) => { if (e.key === 'Enter') { auditPage = 1; loadAuditLogs(); } }}
            />
            {#if auditSearch}
              <button class="search-clear" onclick={() => { auditSearch = ''; auditPage = 1; loadAuditLogs(); }}>
                <X size={12} strokeWidth={2} />
              </button>
            {/if}
          </div>
        </div>

        <div class="audit-table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th class="th-expand"></th>
                <th>Date</th>
                <th>Officer</th>
                <th>Action</th>
                <th>Category</th>
                <th>Target</th>
              </tr>
            </thead>
            <tbody>
              {#each filteredLogs as log (log.id)}
                <tr
                  class="audit-row"
                  class:expanded={expandedLog === log.id}
                  onclick={() => expandedLog = expandedLog === log.id ? null : log.id}
                >
                  <td class="td-expand">
                    {#if expandedLog === log.id}
                      <ChevronDown size={14} strokeWidth={2} />
                    {:else}
                      <ChevronRight size={14} strokeWidth={2} />
                    {/if}
                  </td>
                  <td class="td-date">{formatDateTime(log.created_at)}</td>
                  <td class="td-officer">
                    <span class="log-callsign">{log.callsign || '—'}</span>
                    {log.first_name} {log.last_name}
                  </td>
                  <td>
                    <span class="action-tag">{log.action}</span>
                  </td>
                  <td class="td-category">{log.category || '—'}</td>
                  <td class="td-mono">{log.target_type ? `${log.target_type}#${log.target_id}` : '—'}</td>
                </tr>
                {#if expandedLog === log.id}
                  <tr class="details-row">
                    <td colspan="6">
                      <div class="details-panel">
                        <span class="details-label">Details</span>
                        <pre class="details-json">{JSON.stringify(log.details, null, 2)}</pre>
                      </div>
                    </td>
                  </tr>
                {/if}
              {/each}
              {#if filteredLogs.length === 0 && !auditLoading}
                <tr>
                  <td colspan="6" class="empty-row">
                    <div class="empty-state">
                      <ScrollText size={28} strokeWidth={1.2} />
                      <span>No audit logs found</span>
                    </div>
                  </td>
                </tr>
              {/if}
              {#if auditLoading}
                <tr>
                  <td colspan="6" class="empty-row">
                    <div class="empty-state">
                      <Loader2 size={22} strokeWidth={2} class="spin" />
                      <span>Loading logs...</span>
                    </div>
                  </td>
                </tr>
              {/if}
            </tbody>
          </table>
        </div>

        {#if filteredLogs.length > 0 && !auditLoading}
          <div class="pagination-bar">
            <button class="btn-secondary" onclick={loadMoreLogs}>
              Load More
            </button>
            <span class="page-info">Page {auditPage}</span>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .settings-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale));
    opacity: 0;
    transform: translateY(calc(6px * var(--mdt-scale)));
    animation: fadeIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    height: 100%;
    overflow: hidden;
  }

  .settings-page.mounted {
    opacity: 1;
    transform: none;
  }

  .page-title {
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
    flex-shrink: 0;
  }

  .tab-bar {
    display: flex;
    align-items: center;
    gap: calc(2px * var(--mdt-scale));
    border-bottom: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    padding-bottom: 0;
    flex-shrink: 0;
    overflow-x: auto;
  }

  .tab-btn {
    position: relative;
    display: flex;
    align-items: center;
    gap: calc(7px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    padding-bottom: calc(12px * var(--mdt-scale));
    background: none;
    border: none;
    color: var(--mdt-text-muted);
    font-family: inherit;
    font-size: calc(12.5px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: color 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    white-space: nowrap;
  }

  .tab-btn:hover {
    color: var(--mdt-text-dim);
  }

  .tab-btn.active {
    color: var(--mdt-accent);
  }

  .tab-indicator {
    position: absolute;
    bottom: calc(-1px * var(--mdt-scale));
    left: calc(12px * var(--mdt-scale));
    right: calc(12px * var(--mdt-scale));
    height: calc(2px * var(--mdt-scale));
    background: var(--mdt-accent);
    border-radius: calc(1px * var(--mdt-scale));
  }

  .tab-label {
    pointer-events: none;
  }

  .tab-content {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    min-height: 0;
  }

  .content-panel {
    max-width: calc(620px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(28px * var(--mdt-scale));
    animation: panelIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .content-panel.wide {
    max-width: none;
  }

  .settings-section {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }

  .section-title {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    letter-spacing: 0.02em;
  }

  .section-desc {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.4;
  }

  .theme-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(130px * var(--mdt-scale)), 1fr));
    gap: calc(8px * var(--mdt-scale));
  }

  .theme-swatch {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface-2);
    cursor: pointer;
    transition: border-color 0.15s ease, background 0.15s ease, transform 0.1s ease;
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .theme-swatch:hover {
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-3);
  }

  .theme-swatch:active {
    transform: scale(0.97);
  }

  .theme-swatch.active {
    border-color: var(--swatch);
    box-shadow: 0 0 calc(10px * var(--mdt-scale)) rgba(0, 0, 0, 0.3),
                inset 0 0 0 calc(1px * var(--mdt-scale)) rgba(255, 255, 255, 0.05);
  }

  .swatch-dot {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--swatch);
    flex-shrink: 0;
    box-shadow: 0 0 calc(6px * var(--mdt-scale)) color-mix(in srgb, var(--swatch) 40%, transparent);
  }

  .swatch-label {
    font-weight: 500;
    white-space: nowrap;
  }

  .avatar-form {
    display: flex;
    align-items: flex-start;
    gap: calc(14px * var(--mdt-scale));
  }

  .avatar-preview {
    width: calc(56px * var(--mdt-scale));
    height: calc(56px * var(--mdt-scale));
    border-radius: 50%;
    border: calc(2px * var(--mdt-scale)) solid var(--mdt-border-2);
    background: var(--mdt-surface-2);
    overflow: hidden;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .avatar-empty {
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .avatar-empty svg {
    width: 100%;
    height: 100%;
  }

  .avatar-input-group {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .callsign-form {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .callsign-form .text-input {
    flex: 1;
    max-width: calc(240px * var(--mdt-scale));
  }

  .text-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
  }

  .text-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .text-input:focus {
    border-color: var(--mdt-accent);
  }

  .btn-primary {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    align-self: flex-start;
    padding: calc(7px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: none;
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    font-family: inherit;
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
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: border-color 0.15s ease, background 0.15s ease, transform 0.1s ease;
  }

  .btn-secondary:hover {
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-3);
  }

  .btn-secondary:active {
    transform: scale(0.97);
  }

  .btn-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .btn-icon:hover {
    border-color: var(--mdt-border-2);
    color: var(--mdt-text-dim);
    background: var(--mdt-surface-3);
  }

  .btn-icon.danger:hover {
    border-color: var(--mdt-error);
    color: var(--mdt-error);
    background: rgba(239, 68, 68, 0.08);
  }

  .btn-icon:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-save-sm {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-accent);
    background: rgba(0, 0, 0, 0.2);
    color: var(--mdt-accent);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .btn-save-sm:hover {
    background: var(--mdt-accent);
    color: var(--mdt-bg);
  }

  .btn-save-sm:active {
    transform: scale(0.97);
  }

  .btn-save-sm:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .panel-header {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    margin-bottom: calc(12px * var(--mdt-scale));
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex: 1;
    max-width: calc(360px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    transition: border-color 0.15s ease;
  }

  .search-box:focus-within {
    border-color: var(--mdt-accent);
  }

  .search-input {
    flex: 1;
    background: none;
    border: none;
    outline: none;
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
  }

  .search-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .search-clear {
    display: flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    color: var(--mdt-text-muted);
    cursor: pointer;
    padding: calc(2px * var(--mdt-scale));
    border-radius: calc(3px * var(--mdt-scale));
    transition: color 0.15s ease;
  }

  .search-clear:hover {
    color: var(--mdt-text);
  }

  .result-count {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', monospace;
    white-space: nowrap;
  }

  .roster-table-wrap,
  .audit-table-wrap {
    overflow-x: auto;
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface);
  }

  .data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: calc(12px * var(--mdt-scale));
  }

  .data-table thead tr {
    background: var(--mdt-surface-2);
    border-bottom: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
  }

  .data-table th {
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    text-align: left;
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    white-space: nowrap;
  }

  .data-table td {
    padding: calc(9px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    vertical-align: middle;
    border-bottom: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
  }

  .th-expand {
    width: calc(32px * var(--mdt-scale));
  }

  .td-expand {
    color: var(--mdt-text-muted);
    cursor: pointer;
    width: calc(32px * var(--mdt-scale));
  }

  .roster-row,
  .audit-row {
    cursor: pointer;
    transition: background 0.12s ease;
  }

  .roster-row:hover,
  .audit-row:hover {
    background: var(--mdt-surface-2);
  }

  .roster-row.expanded,
  .audit-row.expanded {
    background: var(--mdt-surface-2);
  }

  .td-name {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    white-space: nowrap;
  }

  .roster-avatar {
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    border-radius: 50%;
    object-fit: cover;
    flex-shrink: 0;
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
  }

  .roster-avatar-empty {
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-3);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .td-mono {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(11.5px * var(--mdt-scale));
    letter-spacing: 0.02em;
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    color: var(--badge-color);
    background: color-mix(in srgb, var(--badge-color) 12%, transparent);
    border: calc(1px * var(--mdt-scale)) solid color-mix(in srgb, var(--badge-color) 25%, transparent);
    letter-spacing: 0.02em;
  }

  .td-certs {
    display: flex;
    flex-wrap: wrap;
    gap: calc(4px * var(--mdt-scale));
    align-items: center;
  }

  .cert-pill {
    display: inline-flex;
    align-items: center;
    padding: calc(2px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    border-radius: calc(8px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-accent) 10%, transparent);
    border: calc(1px * var(--mdt-scale)) solid color-mix(in srgb, var(--mdt-accent) 20%, transparent);
    white-space: nowrap;
  }

  .text-muted {
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
  }

  .edit-row td {
    padding: 0;
    border-bottom: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
  }

  .edit-form {
    padding: calc(16px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-top: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    animation: slideDown 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .edit-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: calc(12px * var(--mdt-scale));
  }

  .edit-field {
    display: flex;
    flex-direction: column;
    gap: calc(5px * var(--mdt-scale));
  }

  .edit-field.wide {
    grid-column: 1 / -1;
  }

  .field-label {
    font-size: calc(10.5px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .field-input {
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    width: 100%;
    box-sizing: border-box;
  }

  .field-input.mono {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(12px * var(--mdt-scale));
    letter-spacing: 0.04em;
  }

  .field-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .field-input:focus {
    border-color: var(--mdt-accent);
  }

  .field-select {
    padding: calc(7px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    cursor: pointer;
    width: 100%;
    box-sizing: border-box;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%23888' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right calc(8px * var(--mdt-scale)) center;
    padding-right: calc(28px * var(--mdt-scale));
  }

  .field-select:focus {
    border-color: var(--mdt-accent);
  }

  .field-select option {
    background: var(--mdt-surface);
    color: var(--mdt-text);
  }

  .field-textarea {
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    background: var(--mdt-surface);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
    transition: border-color 0.15s ease;
    resize: vertical;
    width: 100%;
    box-sizing: border-box;
    line-height: 1.5;
  }

  .field-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .field-textarea:focus {
    border-color: var(--mdt-accent);
  }

  .cert-checks {
    display: flex;
    flex-wrap: wrap;
    gap: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
  }

  .cert-check {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    cursor: pointer;
  }

  .cert-check input[type="checkbox"] {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    accent-color: var(--mdt-accent);
    cursor: pointer;
  }

  .cert-check-label {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .edit-actions {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding-top: calc(4px * var(--mdt-scale));
  }

  .empty-row {
    padding: calc(32px * var(--mdt-scale)) !important;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-size: calc(12px * var(--mdt-scale));
    padding: calc(20px * var(--mdt-scale));
  }

  .empty-state.compact {
    padding: calc(28px * var(--mdt-scale));
    border: calc(1px * var(--mdt-scale)) dashed var(--mdt-border);
    border-radius: var(--mdt-radius);
  }

  .ann-form {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(16px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    border-radius: var(--mdt-radius);
  }

  .ann-row {
    display: flex;
    gap: calc(12px * var(--mdt-scale));
  }

  .ann-field {
    display: flex;
    flex-direction: column;
    gap: calc(5px * var(--mdt-scale));
    min-width: calc(160px * var(--mdt-scale));
  }

  .ann-field.grow {
    flex: 1;
  }

  .ann-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .pin-toggle {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    cursor: pointer;
  }

  .pin-toggle input[type="checkbox"] {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    accent-color: var(--mdt-accent);
    cursor: pointer;
  }

  .ann-list {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .ann-card {
    padding: calc(14px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    transition: border-color 0.15s ease;
  }

  .ann-card:hover {
    border-color: var(--mdt-border-2);
  }

  .ann-card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    margin-bottom: calc(8px * var(--mdt-scale));
  }

  .ann-card-title-row {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    color: var(--mdt-accent);
    min-width: 0;
  }

  .ann-card-title {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ann-card-content {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    line-height: 1.5;
    margin-bottom: calc(10px * var(--mdt-scale));
    white-space: pre-wrap;
    word-break: break-word;
  }

  .ann-card-meta {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .ann-meta-item {
    font-size: calc(10.5px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', monospace;
  }

  .sys-fields {
    display: flex;
    flex-direction: column;
    gap: calc(18px * var(--mdt-scale));
  }

  .sys-field {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .sys-field-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
  }

  .sys-row {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: calc(14px * var(--mdt-scale));
  }

  .td-date {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    white-space: nowrap;
  }

  .td-officer {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    white-space: nowrap;
  }

  .log-callsign {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10.5px * var(--mdt-scale));
    color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-accent) 10%, transparent);
    padding: calc(1px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: calc(4px * var(--mdt-scale));
    border: calc(1px * var(--mdt-scale)) solid color-mix(in srgb, var(--mdt-accent) 18%, transparent);
  }

  .td-category {
    text-transform: capitalize;
  }

  .action-tag {
    display: inline-flex;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(4px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    color: var(--mdt-text);
    background: var(--mdt-surface-3);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    font-family: 'Share Tech Mono', monospace;
    letter-spacing: 0.02em;
  }

  .details-row td {
    padding: 0;
  }

  .details-panel {
    padding: calc(14px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border-top: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    animation: slideDown 0.2s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .details-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    display: block;
    margin-bottom: calc(8px * var(--mdt-scale));
  }

  .details-json {
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    background: var(--mdt-surface);
    padding: calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    overflow-x: auto;
    white-space: pre;
    margin: 0;
    line-height: 1.5;
    max-height: calc(200px * var(--mdt-scale));
    overflow-y: auto;
  }

  .pagination-bar {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(14px * var(--mdt-scale));
    padding-top: calc(14px * var(--mdt-scale));
  }

  .page-info {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', monospace;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes panelIn {
    from { opacity: 0; transform: translateX(calc(8px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateX(0); }
  }

  @keyframes slideDown {
    from { opacity: 0; max-height: 0; }
    to { opacity: 1; max-height: calc(500px * var(--mdt-scale)); }
  }

  :global(.spin) {
    animation: spinAnim 0.8s linear infinite;
  }

  @keyframes spinAnim {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  /* ─── Hotkeys Tab Styles ─── */

  .hotkey-list {
    display: flex;
    flex-direction: column;
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
  }

  .hotkey-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    gap: calc(16px * var(--mdt-scale));
    border-bottom: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    transition: background 0.12s ease;
  }

  .hotkey-row:last-child {
    border-bottom: none;
  }

  .hotkey-row:not(.static):hover {
    background: var(--mdt-surface-2);
  }

  .hotkey-info {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .hotkey-label {
    font-size: calc(12.5px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .hotkey-desc {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .hotkey-binding-wrap {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .hotkey-binding {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border-2);
    background: var(--mdt-surface-2);
    cursor: pointer;
    transition: border-color 0.15s ease, background 0.15s ease, box-shadow 0.15s ease;
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    white-space: nowrap;
  }

  .hotkey-binding:not(.static):hover {
    border-color: var(--mdt-accent);
    background: var(--mdt-surface-3);
    box-shadow: 0 0 calc(8px * var(--mdt-scale)) var(--mdt-accent-glow);
  }

  .hotkey-binding.recording {
    border-color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    box-shadow: 0 0 calc(12px * var(--mdt-scale)) var(--mdt-accent-glow);
    animation: recordPulse 1.5s ease-in-out infinite;
  }

  .hotkey-binding.static {
    cursor: default;
    opacity: 0.7;
  }

  .hotkey-recording-pulse {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-accent);
    animation: blink 0.8s ease-in-out infinite;
  }

  .hotkey-recording-text {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-accent);
    font-weight: 500;
  }

  .hotkey-key {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: calc(2px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: calc(3px * var(--mdt-scale));
    background: var(--mdt-surface-3);
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10.5px * var(--mdt-scale));
    color: var(--mdt-text);
    line-height: 1.4;
    min-width: calc(20px * var(--mdt-scale));
    text-align: center;
    box-shadow: 0 calc(1px * var(--mdt-scale)) 0 rgba(0, 0, 0, 0.3);
  }

  .hotkey-plus {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    margin: 0 calc(1px * var(--mdt-scale));
  }

  .hotkey-range {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    margin: 0 calc(2px * var(--mdt-scale));
  }

  .hotkey-reset {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(24px * var(--mdt-scale));
    height: calc(24px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: calc(1px * var(--mdt-scale)) solid transparent;
    background: transparent;
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition: all 0.15s ease;
    padding: 0;
  }

  .hotkey-reset:hover {
    border-color: var(--mdt-border);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .hotkey-reset-all {
    padding-top: calc(8px * var(--mdt-scale));
  }

  @keyframes recordPulse {
    0%, 100% { box-shadow: 0 0 calc(8px * var(--mdt-scale)) var(--mdt-accent-glow); }
    50% { box-shadow: 0 0 calc(16px * var(--mdt-scale)) var(--mdt-accent-glow); }
  }

  @keyframes blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }
</style>
