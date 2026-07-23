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
    Lock,
    Scale,
    IdCard,
    Volume2,
  } from '@lucide/svelte';
  import { previewMdtSound } from '../lib/utils/mdtSounds.js';
  import MdtSwitch from '../lib/components/MdtSwitch.svelte';
  import MdtCheckbox from '../lib/components/MdtCheckbox.svelte';
  import { hotkeysStore, normalizeHotkeyBinding } from '../lib/stores/hotkeys.svelte.js';
  import { tabsStore } from '../lib/stores/tabs.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';

  const TABS = [
    { id: 'appearance', label: 'Appearance', icon: Palette },
    { id: 'hotkeys', label: 'Hotkeys', icon: Keyboard },
    { id: 'roster', label: 'Roster', icon: Users },
    { id: 'permissions', label: 'Permissions', icon: Lock },
    { id: 'jail_fines', label: 'Jail & Fines', icon: Scale },
    { id: 'licenses', label: 'Licenses', icon: IdCard },
    { id: 'announcements', label: 'Announcements', icon: Megaphone },
    { id: 'system', label: 'System', icon: SettingsIcon },
    { id: 'audit', label: 'Audit Logs', icon: ScrollText },
  ];

  const STATUS_OPTIONS = ['active', 'suspended', 'terminated', 'loa'];

  const UI_CLICK_PRESETS = [
    { id: 'exec_navigate', label: 'SecuroServ (Navigate)' },
    { id: 'warehouse_mouse', label: 'Warehouse (Mouse click)' },
    { id: 'hangar_click', label: 'Hangar (Click special)' },
  ];

  function patchMdtSounds(patch) {
    mdtStore.updateSettings({
      sounds: { ...mdtStore.settings.sounds, ...patch },
    });
  }

  let activeTab = $state('appearance');
  let mounted = $state(false);

  let officer = $derived(mdtStore.officer);
  let usesLocalProfilePersistence = $derived((officer?.frameworkMode || '').toLowerCase() !== 'qbx');
  let isStandaloneFramework = $derived((officer?.frameworkMode || '').toLowerCase() === 'standalone');

  let avatarInput = $state('');
  let callsignInput = $state('');
  let displayFirstInput = $state('');
  let displayLastInput = $state('');
  let lastProfileSnapshot = $state('');

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

  // ─── Permissions State ───
  const PERMISSION_CATEGORIES = ['dispatch', 'records', 'investigations', 'admin'];
  const CHANNEL_LIST = ['dispatch', 'tac-1', 'tac-2', 'tac-3', 'department', 'inter-agency'];
  let permRoles = $state([]);
  let permSaving = $state(false);
  let permNewRoleName = $state('');
  let permExpandedRole = $state(null);

  // ─── Jail & Fines State ───
  let jfCharges = $state([]);
  let jfSearch = $state('');
  let jfSaving = $state(null);
  let jfEditingId = $state(null);
  let jfEditFine = $state(0);
  let jfEditJail = $state(0);
  let jfEditMaxJail = $state(0);

  let filteredJfCharges = $derived.by(() => {
    if (!jfSearch.trim()) return jfCharges;
    const q = jfSearch.toLowerCase();
    return jfCharges.filter(c => c.charge.toLowerCase().includes(q) || c.category?.toLowerCase().includes(q));
  });

  // ─── Licenses State ───
  let licenseTypes = $derived(dataStore.licenseTypesList || []);
  let licSaving = $state(false);
  let licNewName = $state('');
  let licNewDesc = $state('');

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
    mdtStore.updateSettings({ theme: themeId });
  }

  $effect(() => {
    const nextAvatar = (usesLocalProfilePersistence ? (mdtStore.settings.avatarUrl || officer?.avatar) : officer?.avatar) || '';
    const nextCallsign = (usesLocalProfilePersistence ? (mdtStore.settings.callsign || officer?.callsign) : officer?.callsign) || '';
    const nextDisplayFirst =
      isStandaloneFramework && usesLocalProfilePersistence
        ? String(mdtStore.settings.officerDisplayFirstName || '').trim() || (officer?.firstName || '')
        : '';
    const nextDisplayLast =
      isStandaloneFramework && usesLocalProfilePersistence
        ? String(mdtStore.settings.officerDisplayLastName || '').trim() || (officer?.lastName || '')
        : '';
    const nextSnapshot = `${usesLocalProfilePersistence ? 'local' : 'server'}:${nextAvatar}:${nextCallsign}:${isStandaloneFramework ? `${nextDisplayFirst}:${nextDisplayLast}` : '-'}`;

    if (!mounted || lastProfileSnapshot !== nextSnapshot) {
      avatarInput = nextAvatar;
      callsignInput = nextCallsign;
      if (isStandaloneFramework) {
        displayFirstInput = nextDisplayFirst;
        displayLastInput = nextDisplayLast;
      }
      lastProfileSnapshot = nextSnapshot;
    }
  });

  async function saveAvatar() {
    const nextAvatar = avatarInput.trim();

    if (usesLocalProfilePersistence) {
      await mdtStore.updateSettings({ avatarUrl: nextAvatar || null });
    }

    const resp = await dataStore.saveOfficerAvatar(nextAvatar || null);
    if (resp?.ok) {
      mdtStore.officer = { ...mdtStore.officer, avatar: nextAvatar || null };
      await dataStore.fetchRoster();
    }
  }

  async function saveCallsign() {
    const trimmed = callsignInput.trim();

    const activeOfficer = mdtStore.officer;
    const resp = await dataStore.registerOfficer({
      firstName: activeOfficer.firstName,
      lastName: activeOfficer.lastName,
      rank: activeOfficer.rank,
      callsign: trimmed || activeOfficer.callsign || '',
      departmentKey: activeOfficer.departmentKey || activeOfficer.department,
    });

    if (!resp?.ok) {
      return;
    }

    if (usesLocalProfilePersistence) {
      await mdtStore.updateSettings({ callsign: trimmed || '' });
    }

    mdtStore.officer = {
      ...activeOfficer,
      officerId: resp.officerId || activeOfficer.officerId || null,
      callsign: trimmed || activeOfficer.callsign || '',
    };

    await Promise.all([
      dataStore.fetchUnits(),
      dataStore.fetchDashboard(),
      dataStore.fetchDispatch(),
      dataStore.fetchBodycams(),
    ]);
  }

  async function saveDisplayName() {
    if (!isStandaloneFramework) return;

    const f = displayFirstInput.trim();
    const l = displayLastInput.trim();
    const activeOfficer = mdtStore.officer;
    const useFramework = !f && !l;

    const payload = useFramework
      ? { ...dataStore.buildOfficerProfilePayload(activeOfficer, { forceFrameworkDisplayName: true }) }
      : {
          firstName: f,
          lastName: l,
          rank: activeOfficer.rank,
          callsign: activeOfficer.callsign || '',
          departmentKey: activeOfficer.departmentKey || activeOfficer.department,
        };

    const resp = await dataStore.registerOfficer(payload);
    if (!resp?.ok) return;

    await mdtStore.updateSettings({
      officerDisplayFirstName: f,
      officerDisplayLastName: l,
    });

    const oid = resp.officerId || activeOfficer.officerId;
    await Promise.all([dataStore.fetchUnits(), dataStore.fetchRoster()]);

    let row =
      (dataStore.unitsList || []).find((u) => String(u.officer_id) === String(oid)) ||
      (dataStore.adminRoster || []).find((o) => String(o.id) === String(oid));

    const nextFirst = row
      ? String(row.first_name || row.firstName || '').trim()
      : f || String(activeOfficer.firstName || '').trim();
    const nextLast = row
      ? String(row.last_name || row.lastName || '').trim()
      : l || String(activeOfficer.lastName || '').trim();

    mdtStore.officer = {
      ...activeOfficer,
      officerId: oid || activeOfficer.officerId,
      firstName: nextFirst || activeOfficer.firstName,
      lastName: nextLast || activeOfficer.lastName,
    };

    await dataStore.fetchDashboard();
  }

  $effect(() => {
    if (tabsStore.activePage !== 'settings') return;
    mdtStore.settingsDeepLinkSeq;
    const pending = mdtStore.consumePendingSettingsTab();
    if (pending && TABS.some((t) => t.id === pending)) {
      switchTab(pending);
    }
  });

  function switchTab(tabId) {
    activeTab = tabId;
    if (tabId === 'roster') {
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
    if (tabId === 'permissions' && permRoles.length === 0) {
      loadPermissions();
    }
    if (tabId === 'jail_fines' && jfCharges.length === 0) {
      loadJailFines();
    }
    if (tabId === 'licenses' && licenseTypes.length === 0) {
      loadLicenses();
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
    const result = await dataStore.createAnnouncement({
      title: annTitle,
      content: annContent,
      department: annDepartment || null,
      pinned: annPinned,
    });
    if (result?.ok) {
      annTitle = '';
      annContent = '';
      annDepartment = '';
      annPinned = false;
    }
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

  // ─── Permissions Functions ───
  async function loadPermissions() {
    if (isEnvBrowser()) {
      permRoles = [
        { id: 1, name: 'Officer', permissions: { dispatch: true, records: true, investigations: false, admin: false }, channels: ['dispatch', 'tac-1'] },
        { id: 2, name: 'Sergeant', permissions: { dispatch: true, records: true, investigations: true, admin: false }, channels: ['dispatch', 'tac-1', 'tac-2', 'department'] },
        { id: 3, name: 'Lieutenant', permissions: { dispatch: true, records: true, investigations: true, admin: true }, channels: ['dispatch', 'tac-1', 'tac-2', 'tac-3', 'department', 'inter-agency'] },
        { id: 4, name: 'Admin', permissions: { dispatch: true, records: true, investigations: true, admin: true }, channels: ['dispatch', 'tac-1', 'tac-2', 'tac-3', 'department', 'inter-agency'] },
      ];
      return;
    }
    const resp = await dataStore.fetchPermissionRoles?.();
    if (resp?.ok && resp.roles) permRoles = resp.roles;
  }

  function togglePermission(roleIndex, perm) {
    permRoles = permRoles.map((r, i) => {
      if (i !== roleIndex) return r;
      return { ...r, permissions: { ...r.permissions, [perm]: !r.permissions[perm] } };
    });
  }

  function toggleChannel(roleIndex, channel) {
    permRoles = permRoles.map((r, i) => {
      if (i !== roleIndex) return r;
      const channels = r.channels.includes(channel)
        ? r.channels.filter(c => c !== channel)
        : [...r.channels, channel];
      return { ...r, channels };
    });
  }

  async function savePermissions() {
    permSaving = true;
    if (!isEnvBrowser()) {
      await dataStore.updatePermissionRoles?.(permRoles);
    }
    permSaving = false;
  }

  async function addPermRole() {
    if (!permNewRoleName.trim()) return;
    permRoles = [...permRoles, {
      id: Date.now(),
      name: permNewRoleName.trim(),
      permissions: { dispatch: false, records: false, investigations: false, admin: false },
      channels: [],
    }];
    permNewRoleName = '';
  }

  function removePermRole(index) {
    permRoles = permRoles.filter((_, i) => i !== index);
  }

  // ─── Jail & Fines Functions ───
  async function loadJailFines() {
    await dataStore.fetchCharges();
    jfCharges = [...dataStore.chargesList];
  }

  function startEditCharge(charge) {
    jfEditingId = charge.id;
    jfEditFine = charge.fine;
    jfEditJail = charge.jailTime;
    jfEditMaxJail = charge.maxJail;
  }

  function cancelEditCharge() {
    jfEditingId = null;
  }

  async function saveChargeEdit(charge) {
    jfSaving = charge.id;
    jfCharges = jfCharges.map(c => {
      if (c.id !== charge.id) return c;
      return { ...c, fine: Number(jfEditFine), jailTime: Number(jfEditJail), maxJail: Number(jfEditMaxJail) };
    });
    await dataStore.updateCharge?.({
      chargeId: charge.id,
      fine: Number(jfEditFine),
      jailTime: Number(jfEditJail),
      maxJail: Number(jfEditMaxJail),
    });
    jfCharges = [...dataStore.chargesList];
    jfEditingId = null;
    jfSaving = null;
  }

  // ─── License Functions ───
  async function loadLicenses() {
    await dataStore.fetchLicenseTypes();
  }

  async function addLicense() {
    if (!licNewName.trim()) return;
    licSaving = true;
    await dataStore.createLicenseType({
      name: licNewName.trim(),
      description: licNewDesc.trim(),
    });
    licNewName = '';
    licNewDesc = '';
    licSaving = false;
  }

  async function toggleLicenseActive(lic) {
    await dataStore.updateLicenseType({
      id: lic.id,
      active: lic.active ? 0 : 1,
    });
  }

  async function removeLicense(lic) {
    await dataStore.deleteLicenseType(lic.id);
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

  function hotkeyParts(action) {
    return normalizeHotkeyBinding(hotkeysStore.bindings[action], hotkeysStore.defaults[action]).split('+');
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

        {#if isStandaloneFramework}
          <section class="settings-section">
            <h3 class="section-title">Officer name</h3>
            <p class="section-desc">
              Custom first and last name for this MDT (rank line, units, reports). Saved locally on this PC. Clear both fields and save to restore the default name from standalone / FiveM.
            </p>
            <div class="display-name-form">
              <input
                type="text"
                class="text-input"
                placeholder="First name"
                bind:value={displayFirstInput}
                onkeydown={(e) => {
                  if (e.key === 'Enter') saveDisplayName();
                }}
              />
              <input
                type="text"
                class="text-input"
                placeholder="Last name"
                bind:value={displayLastInput}
                onkeydown={(e) => {
                  if (e.key === 'Enter') saveDisplayName();
                }}
              />
              <button class="btn-primary" onclick={saveDisplayName}>
                <Save size={13} strokeWidth={2} />
                Save
              </button>
            </div>
          </section>
        {/if}

        <section class="settings-section" data-mdt-no-ui-sound>
          <h3 class="section-title sound-title">
            <Volume2 size={15} strokeWidth={1.8} />
            Sound effects
          </h3>
          <p class="section-desc">
            GTA frontend sounds for MDT. Stored locally (same as theme). Master off silences gameplay hooks; Preview always plays.
          </p>

          <div class="sound-controls">
            <div class="sound-row">
              <label class="sound-label" for="sound-master">Master</label>
              <span class="sound-row-actions">
                <MdtSwitch
                  id="sound-master"
                  checked={mdtStore.settings.sounds?.master ?? true}
                  onCheckedChange={(v) => patchMdtSounds({ master: v })}
                />
              </span>
            </div>

            <div class="sound-row">
              <label class="sound-label" for="sound-biometric">Biometric login</label>
              <span class="sound-row-actions">
                <MdtSwitch
                  id="sound-biometric"
                  checked={mdtStore.settings.sounds?.biometric ?? true}
                  onCheckedChange={(v) => patchMdtSounds({ biometric: v })}
                />
                <button type="button" class="btn-sound-preview" onclick={() => previewMdtSound('biometric')}>Preview</button>
              </span>
            </div>

            <div class="sound-row">
              <label class="sound-label" for="sound-status">Unit status change</label>
              <span class="sound-row-actions">
                <MdtSwitch
                  id="sound-status"
                  checked={mdtStore.settings.sounds?.status ?? true}
                  onCheckedChange={(v) => patchMdtSounds({ status: v })}
                />
                <button type="button" class="btn-sound-preview" onclick={() => previewMdtSound('status')}>Preview</button>
              </span>
            </div>

            <div class="sound-row">
              <label class="sound-label" for="sound-dashboard">Dashboard (first load after login)</label>
              <span class="sound-row-actions">
                <MdtSwitch
                  id="sound-dashboard"
                  checked={mdtStore.settings.sounds?.dashboard ?? true}
                  onCheckedChange={(v) => patchMdtSounds({ dashboard: v })}
                />
                <button type="button" class="btn-sound-preview" onclick={() => previewMdtSound('dashboard')}>Preview</button>
              </span>
            </div>

            <div class="sound-row">
              <label class="sound-label" for="sound-ui-click">UI clicks (buttons / nav)</label>
              <span class="sound-row-actions">
                <MdtSwitch
                  id="sound-ui-click"
                  checked={mdtStore.settings.sounds?.uiClick ?? true}
                  onCheckedChange={(v) => patchMdtSounds({ uiClick: v })}
                />
                <button type="button" class="btn-sound-preview" onclick={() => previewMdtSound('ui_click')}>Preview</button>
              </span>
            </div>

            <div class="sound-preset-row">
              <span class="sound-label">UI click preset</span>
              <select
                class="text-input sound-preset-select"
                value={mdtStore.settings.sounds?.uiClickPreset || 'exec_navigate'}
                onchange={(e) => patchMdtSounds({ uiClickPreset: e.currentTarget.value })}
              >
                {#each UI_CLICK_PRESETS as p (p.id)}
                  <option value={p.id}>{p.label}</option>
                {/each}
              </select>
            </div>

            <div class="sound-row">
              <label class="sound-label" for="sound-logout">Logout</label>
              <span class="sound-row-actions">
                <MdtSwitch
                  id="sound-logout"
                  checked={mdtStore.settings.sounds?.logout ?? true}
                  onCheckedChange={(v) => patchMdtSounds({ logout: v })}
                />
                <button type="button" class="btn-sound-preview" onclick={() => previewMdtSound('logout')}>Preview</button>
              </span>
            </div>
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
                      {#each hotkeyParts(action) as part, i (`${action}:${i}:${part}`)}
                        <kbd class="hotkey-key">{part}</kbd>
                        {#if i < hotkeyParts(action).length - 1}
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
                              <MdtCheckbox
                                class="cert-check"
                                checkedValue={editCerts.includes(cert)}
                                onCheckedChange={() => toggleCert(cert)}
                              >
                                {#snippet children()}
                                  <span class="cert-check-label">{cert}</span>
                                {/snippet}
                              </MdtCheckbox>
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
              <MdtCheckbox class="pin-toggle" bind:checked={annPinned}>
                {#snippet children()}
                  <span class="pin-toggle-inner">
                    <Pin size={13} strokeWidth={2} />
                    <span>Pin announcement</span>
                  </span>
                {/snippet}
              </MdtCheckbox>
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
                <label class="field-label">Toolbar line / quotes</label>
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
                placeholder="One line = one word or quote. Multiple lines = random line every ~45s in the toolbar center."
                rows="6"
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

    {:else if activeTab === 'permissions'}
      <div class="content-panel" class:mounted>
        <section class="settings-section">
          <h3 class="section-title">Role-Based Permissions</h3>
          <p class="section-desc">Configure what each role can access and which radio channels they can interact with.</p>

          <div class="perm-roles">
            {#each permRoles as role, ri (role.id)}
              <div class="perm-role-card">
                <div class="perm-role-header">
                  <button class="perm-role-toggle" onclick={() => permExpandedRole = permExpandedRole === role.id ? null : role.id}>
                    {#if permExpandedRole === role.id}
                      <ChevronDown size={14} strokeWidth={2} />
                    {:else}
                      <ChevronRight size={14} strokeWidth={2} />
                    {/if}
                    <span class="perm-role-name">{role.name}</span>
                  </button>
                  <button class="btn-remove-sm" onclick={() => removePermRole(ri)}>
                    <Trash2 size={12} strokeWidth={2} />
                  </button>
                </div>

                {#if permExpandedRole === role.id}
                  <div class="perm-role-body">
                    <div class="perm-section">
                      <span class="perm-section-label">Permissions</span>
                      <div class="perm-toggles">
                        {#each PERMISSION_CATEGORIES as perm (perm)}
                          <label class="perm-toggle-item">
                            <input
                              type="checkbox"
                              class="mdt-checkbox-input"
                              checked={role.permissions[perm]}
                              onchange={() => togglePermission(ri, perm)}
                            />
                            <span class="mdt-checkbox-box" aria-hidden="true">
                              <svg class="mdt-checkbox-tick" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                <path d="M5 13l4 4L19 7" />
                              </svg>
                            </span>
                            <span class="perm-toggle-label">{perm}</span>
                          </label>
                        {/each}
                      </div>
                    </div>

                    <div class="perm-section">
                      <span class="perm-section-label">Channel Access</span>
                      <div class="perm-toggles">
                        {#each CHANNEL_LIST as ch (ch)}
                          <label class="perm-toggle-item">
                            <input
                              type="checkbox"
                              class="mdt-checkbox-input"
                              checked={role.channels.includes(ch)}
                              onchange={() => toggleChannel(ri, ch)}
                            />
                            <span class="mdt-checkbox-box" aria-hidden="true">
                              <svg class="mdt-checkbox-tick" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                <path d="M5 13l4 4L19 7" />
                              </svg>
                            </span>
                            <span class="perm-toggle-label">{ch}</span>
                          </label>
                        {/each}
                      </div>
                    </div>
                  </div>
                {/if}
              </div>
            {/each}
          </div>

          <div class="perm-add-row">
            <input type="text" class="field-input" placeholder="New role name..." bind:value={permNewRoleName} onkeydown={(e) => { if (e.key === 'Enter') addPermRole(); }} />
            <button class="btn-secondary" onclick={addPermRole} disabled={!permNewRoleName.trim()}>
              <Plus size={14} strokeWidth={2} /> Add Role
            </button>
          </div>

          <button class="btn-save" onclick={savePermissions} disabled={permSaving}>
            <Save size={14} strokeWidth={2} />
            {permSaving ? 'Saving...' : 'Save Permissions'}
          </button>
        </section>
      </div>

    {:else if activeTab === 'jail_fines'}
      <div class="content-panel wide" class:mounted>
        <section class="settings-section">
          <h3 class="section-title">Jail & Fines</h3>
          <p class="section-desc">Edit charge penalties. Changes apply to future reports only.</p>

          <div class="panel-header">
            <div class="search-box">
              <Search size={14} strokeWidth={2} />
              <input type="text" class="search-input" placeholder="Search charges..." bind:value={jfSearch} />
              {#if jfSearch}
                <button class="search-clear" onclick={() => jfSearch = ''}>
                  <X size={12} strokeWidth={2} />
                </button>
              {/if}
            </div>
          </div>

          <div class="audit-table-wrap">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Charge</th>
                  <th>Category</th>
                  <th>Severity</th>
                  <th>Jail (mo)</th>
                  <th>Max Jail</th>
                  <th>Fine ($)</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {#each filteredJfCharges as charge (charge.id)}
                  <tr class="audit-row">
                    <td class="td-charge-name">{charge.charge}</td>
                    <td class="td-category">{charge.category?.replace(/_/g, ' ')}</td>
                    <td>
                      <span class="severity-badge" class:infraction={charge.severity === 'infraction'} class:misdemeanor={charge.severity === 'misdemeanor'} class:felony={charge.severity === 'felony'}>
                        {charge.severity}
                      </span>
                    </td>
                    {#if jfEditingId === charge.id}
                      <td><input type="number" class="field-input compact" bind:value={jfEditJail} min="0" /></td>
                      <td><input type="number" class="field-input compact" bind:value={jfEditMaxJail} min="0" /></td>
                      <td><input type="number" class="field-input compact" bind:value={jfEditFine} min="0" /></td>
                      <td class="td-actions">
                        <button class="btn-save-sm" onclick={() => saveChargeEdit(charge)} disabled={jfSaving === charge.id}>
                          <Check size={12} strokeWidth={2} />
                        </button>
                        <button class="btn-cancel-sm" onclick={cancelEditCharge}>
                          <X size={12} strokeWidth={2} />
                        </button>
                      </td>
                    {:else}
                      <td class="td-mono">{charge.jailTime}</td>
                      <td class="td-mono">{charge.maxJail}</td>
                      <td class="td-mono">${(charge.fine || 0).toLocaleString()}</td>
                      <td class="td-actions">
                        <button class="btn-edit-sm" onclick={() => startEditCharge(charge)} title="Edit penalties">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                        </button>
                      </td>
                    {/if}
                  </tr>
                {/each}
                {#if filteredJfCharges.length === 0}
                  <tr>
                    <td colspan="7" class="empty-row">
                      <div class="empty-state">
                        <Scale size={28} strokeWidth={1.2} />
                        <span>No charges found</span>
                      </div>
                    </td>
                  </tr>
                {/if}
              </tbody>
            </table>
          </div>
        </section>
      </div>

    {:else if activeTab === 'licenses'}
      <div class="content-panel" class:mounted>
        <section class="settings-section">
          <h3 class="section-title">License Management</h3>
          <p class="section-desc">Configure available license types that can be assigned to citizens.</p>

          <div class="license-list">
            {#each licenseTypes as lic (lic.id)}
              <div class="license-card" class:inactive={!lic.active}>
                <div class="license-info">
                  <span class="license-name">{lic.name}</span>
                  <span class="license-desc">{lic.description || 'No description'}</span>
                </div>
                <div class="license-actions">
                  <button class="perm-toggle-btn" class:active={lic.active} onclick={() => toggleLicenseActive(lic)} title={lic.active ? 'Disable' : 'Enable'}>
                    {#if lic.active}
                      <Check size={12} strokeWidth={2} />
                    {:else}
                      <X size={12} strokeWidth={2} />
                    {/if}
                    {lic.active ? 'Active' : 'Inactive'}
                  </button>
                  <button class="btn-remove-sm" onclick={() => removeLicense(lic)}>
                    <Trash2 size={12} strokeWidth={2} />
                  </button>
                </div>
              </div>
            {/each}
          </div>

          <div class="license-add-form">
            <input type="text" class="field-input" placeholder="License name..." bind:value={licNewName} />
            <input type="text" class="field-input" placeholder="Description (optional)..." bind:value={licNewDesc} />
            <button class="btn-secondary" onclick={addLicense} disabled={!licNewName.trim() || licSaving}>
              <Plus size={14} strokeWidth={2} /> Add License
            </button>
          </div>
        </section>
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
    transform: scale(0.96);
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

  .display-name-form {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .display-name-form .text-input {
    flex: 1;
    min-width: calc(120px * var(--mdt-scale));
    max-width: calc(200px * var(--mdt-scale));
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
    transform: scale(0.96);
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
    transform: scale(0.96);
  }

  .btn-icon {
    position: relative;
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
    transition: border-color 0.15s ease, color 0.15s ease, background 0.15s ease;
  }
  .btn-icon::after {
    content: '';
    position: absolute;
    inset: calc(-6px * var(--mdt-scale));
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
    transition: background 0.15s ease, color 0.15s ease;
  }

  .btn-save-sm:hover {
    background: var(--mdt-accent);
    color: var(--mdt-bg);
  }

  .btn-save-sm:active {
    transform: scale(0.96);
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
    border: calc(1px * var(--mdt-scale)) solid var(--mdt-border);
    flex-shrink: 0;
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

  :global(.cert-check.mdt-checkbox) {
    gap: calc(6px * var(--mdt-scale));
  }

  :global(.cert-check.mdt-checkbox .mdt-checkbox-label) {
    font-weight: 500;
    color: inherit;
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

  :global(.pin-toggle.mdt-checkbox) {
    gap: calc(6px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .pin-toggle-inner {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  :global(.pin-toggle.mdt-checkbox .mdt-checkbox-label) {
    font-weight: 500;
    color: inherit;
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
    transition: border-color 0.15s ease, background 0.15s ease, color 0.15s ease;
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

  /* ─── Permissions Tab ─── */
  .perm-roles {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .perm-role-card {
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface);
    overflow: hidden;
  }

  .perm-role-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
  }

  .perm-role-toggle {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    background: none;
    border: none;
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
  }

  .perm-role-body {
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-top: 1px solid var(--mdt-border);
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    animation: slideDown 0.2s ease forwards;
  }

  .perm-section {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .perm-section-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .perm-toggles {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6px * var(--mdt-scale));
  }

  .perm-toggle-item {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    font-size: calc(11px * var(--mdt-scale));
    cursor: pointer;
    transition: border-color 0.12s ease, background 0.12s ease, color 0.12s ease;
    text-transform: capitalize;
  }

  .perm-toggle-item:has(.mdt-checkbox-input:checked) {
    border-color: color-mix(in srgb, var(--mdt-accent) 30%, transparent);
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
  }

  .perm-toggle-item .mdt-checkbox-box {
    border-color: var(--mdt-border);
    background: var(--mdt-surface-3);
  }

  .perm-toggle-item .mdt-checkbox-input:checked + .mdt-checkbox-box {
    background: var(--mdt-accent);
    border-color: var(--mdt-accent);
  }

  .perm-add-row {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
    margin-top: calc(8px * var(--mdt-scale));
  }

  .perm-add-row .field-input {
    flex: 1;
  }

  .btn-save {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    background: var(--mdt-accent);
    color: var(--mdt-bg);
    border: none;
    border-radius: var(--mdt-radius);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    align-self: flex-start;
    margin-top: calc(8px * var(--mdt-scale));
    transition: opacity 0.15s ease;
  }

  .btn-save:hover { opacity: 0.9; }
  .btn-save:disabled { opacity: 0.4; cursor: not-allowed; }

  .btn-remove-sm {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(26px * var(--mdt-scale));
    height: calc(26px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-error) 20%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-error) 8%, transparent);
    color: var(--mdt-error);
    border-radius: var(--mdt-radius-sm);
    cursor: pointer;
    padding: 0;
    transition: background 0.12s ease;
  }

  .btn-remove-sm:hover {
    background: color-mix(in srgb, var(--mdt-error) 15%, transparent);
  }

  .btn-cancel-sm {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(26px * var(--mdt-scale));
    height: calc(26px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    border-radius: var(--mdt-radius-sm);
    cursor: pointer;
    padding: 0;
    transition: color 0.12s ease;
  }

  .btn-cancel-sm:hover { color: var(--mdt-text); }

  .btn-edit-sm {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(26px * var(--mdt-scale));
    height: calc(26px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    border-radius: var(--mdt-radius-sm);
    cursor: pointer;
    padding: 0;
    transition: color 0.12s ease, border-color 0.12s ease;
  }

  .btn-edit-sm:hover {
    color: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 25%, transparent);
  }

  .td-actions {
    display: flex;
    gap: calc(4px * var(--mdt-scale));
    justify-content: flex-end;
  }

  .td-charge-name {
    font-weight: 500;
    color: var(--mdt-text);
  }

  .field-input.compact {
    width: calc(80px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    font-family: 'Share Tech Mono', monospace;
  }

  /* Severity badges for jail_fines */
  .severity-badge {
    display: inline-flex;
    padding: calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(99px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    text-transform: capitalize;
    border: 1px solid transparent;
  }

  .severity-badge.infraction {
    color: var(--mdt-text-muted);
    background: rgba(228, 232, 239, 0.08);
    border-color: rgba(228, 232, 239, 0.15);
  }

  .severity-badge.misdemeanor {
    color: var(--mdt-warning);
    background: rgba(251, 191, 36, 0.1);
    border-color: rgba(251, 191, 36, 0.2);
  }

  .severity-badge.felony {
    color: var(--mdt-error);
    background: rgba(248, 113, 113, 0.1);
    border-color: rgba(248, 113, 113, 0.2);
  }

  /* ─── Licenses Tab ─── */
  .license-list {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .license-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface);
    transition: opacity 0.15s ease;
  }

  .license-card.inactive {
    opacity: 0.5;
  }

  .license-info {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
  }

  .license-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .license-desc {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .license-actions {
    display: flex;
    gap: calc(6px * var(--mdt-scale));
    align-items: center;
  }

  .perm-toggle-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    font-family: inherit;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
    transition: border-color 0.12s ease, color 0.12s ease, background 0.12s ease;
  }

  .perm-toggle-btn.active {
    color: var(--mdt-success);
    border-color: color-mix(in srgb, var(--mdt-success) 25%, transparent);
    background: color-mix(in srgb, var(--mdt-success) 10%, transparent);
  }

  .license-add-form {
    display: flex;
    gap: calc(8px * var(--mdt-scale));
    align-items: center;
    margin-top: calc(10px * var(--mdt-scale));
  }

  .license-add-form .field-input {
    flex: 1;
  }

  .sound-title {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .sound-controls {
    display: flex;
    flex-direction: column;
    gap: 0;
    padding-top: calc(4px * var(--mdt-scale));
  }

  .sound-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) 0;
    border-bottom: 1px solid var(--mdt-border);
    font-size: calc(12px * var(--mdt-scale));
  }

  .sound-row:last-of-type {
    border-bottom: none;
  }

  .sound-label {
    flex: 1;
    color: var(--mdt-text);
    cursor: pointer;
    font-weight: inherit;
  }

  .sound-row-actions {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .btn-sound-preview {
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    font-family: inherit;
    font-size: calc(10px * var(--mdt-scale));
    cursor: pointer;
  }

  .btn-sound-preview:hover {
    color: var(--mdt-text);
    border-color: var(--mdt-border-2);
  }

  .sound-preset-row {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) 0 calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .sound-preset-row .sound-label {
    font-size: calc(12px * var(--mdt-scale));
  }

  .sound-preset-select {
    width: 100%;
    max-width: 320px;
  }
</style>
