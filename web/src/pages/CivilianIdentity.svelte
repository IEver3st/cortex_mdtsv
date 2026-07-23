<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { User, MapPin, Calendar, Phone, Mail, Fingerprint, Shield, Trash2, Pencil, Check, X, Image } from '@lucide/svelte';

  let mounted = $state(false);
  let deleting = $state(false);
  let editing = $state(false);
  let saving = $state(false);
  let editData = $state({});
  let civ = $derived(mdtStore.civilian);

  let identity = $derived({
    firstName: civ.firstName || '',
    lastName: civ.lastName || '',
    citizenId: civ.citizenId || '',
    dateOfBirth: civ.dateOfBirth || civ.dob || '',
    gender: civ.gender || '',
    phone: civ.phone || '',
    email: civ.email || '',
    address: civ.address || '',
    nationality: civ.nationality || '',
    height: civ.height || '',
    eyeColor: civ.eyeColor || civ.eye_color || '',
    bloodType: civ.bloodType || civ.blood_type || '',
    emergencyContact: civ.emergencyContact || civ.emergency_contact || '',
    mugshot: civ.mugshot || '',
  });

  let sourceLabel = $derived(civ.generated ? 'System generated' : 'Self-registered');

  onMount(() => {
    mounted = true;
    if (!isEnvBrowser()) {
      dataStore.fetchStandaloneCivilianState();
    }
  });

  async function handleDelete() {
    if (!identity.citizenId || deleting) {
      return;
    }

    if (!window.confirm(`Delete ${identity.firstName} ${identity.lastName}? This only removes the civilian for the current server session.`)) {
      return;
    }

    deleting = true;
    const response = await dataStore.deleteStandaloneCivilian(identity.citizenId);
    deleting = false;

    if (!response?.ok) {
      return;
    }

    if (response.civilian?.citizenId) {
      mdtStore.activePage = 'civ-dashboard';
    } else {
      mdtStore.logout();
    }
  }

  function startEditing() {
    editData = { ...identity };
    editing = true;
  }

  function cancelEditing() {
    editing = false;
    editData = {};
  }

  async function saveEditing() {
    saving = true;
    if (isEnvBrowser()) {
      mdtStore.civilian = { ...civ, ...editData };
      editing = false;
    } else {
      const resp = await dataStore.updateStandaloneCivilian({ citizenId: identity.citizenId, ...editData });
      if (resp?.ok) {
        editing = false;
      }
    }
    saving = false;
  }

  const EDITABLE_KEYS = new Set(['mugshot', 'dateOfBirth', 'gender', 'phone', 'email', 'address', 'nationality', 'height', 'eyeColor', 'bloodType', 'emergencyContact']);

  const fields = [
    { key: 'citizenId', label: 'Citizen ID', icon: Fingerprint, mono: true },
    { key: 'mugshot', label: 'Profile photo URL', icon: Image },
    { key: 'dateOfBirth', label: 'Date of Birth', icon: Calendar },
    { key: 'gender', label: 'Gender', icon: User },
    { key: 'phone', label: 'Phone', icon: Phone, mono: true },
    { key: 'email', label: 'Email', icon: Mail },
    { key: 'address', label: 'Address', icon: MapPin },
    { key: 'nationality', label: 'Nationality', icon: Shield },
    { key: 'height', label: 'Height', icon: User },
    { key: 'eyeColor', label: 'Eye Color', icon: User },
    { key: 'bloodType', label: 'Blood Type', icon: User, mono: true },
    { key: 'emergencyContact', label: 'Emergency Contact', icon: Phone },
  ];
</script>

<div class="civ-identity" class:mounted>
  {#if !identity.citizenId}
    <div class="id-empty">
      <span class="id-empty-title">No active civilian selected</span>
      <button type="button" class="id-btn id-btn-neutral" onclick={() => mdtStore.activePage = 'civ-dashboard'}>Return to Dashboard</button>
    </div>
  {:else}
    <div class="page-header">
      <div>
        <h1 class="page-title">My Identity</h1>
        <p class="page-subtitle">
          <span class="subtitle-id font-mono">{identity.citizenId}</span>
          <span class="subtitle-sep" aria-hidden="true"></span>
          <span class="subtitle-source">{sourceLabel}</span>
        </p>
      </div>
      <div class="header-actions">
        {#if editing}
          <button type="button" class="id-btn id-btn-primary" onclick={saveEditing} disabled={saving}>
            <Check size={14} strokeWidth={1.8} />
            <span>{saving ? 'Saving...' : 'Save'}</span>
          </button>
          <button type="button" class="id-btn id-btn-neutral" onclick={cancelEditing} disabled={saving}>
            <X size={14} strokeWidth={1.8} />
            <span>Cancel</span>
          </button>
        {:else}
          <button type="button" class="id-btn id-btn-neutral" onclick={startEditing}>
            <Pencil size={14} strokeWidth={1.8} />
            <span>Edit</span>
          </button>
        {/if}
        <button type="button" class="id-btn id-btn-danger" onclick={handleDelete} disabled={deleting}>
          <Trash2 size={14} strokeWidth={1.8} />
          <span>{deleting ? 'Deleting...' : 'Delete civilian'}</span>
        </button>
      </div>
    </div>

    <div class="identity-hero">
      <div class="hero-avatar">
        {#if identity.mugshot?.trim()}
          <img class="hero-avatar-img" src={identity.mugshot.trim()} alt="" referrerpolicy="no-referrer" />
        {:else}
          <User size={32} strokeWidth={1.2} />
        {/if}
      </div>
      <div class="hero-copy">
        <h2 class="hero-name">{identity.firstName} {identity.lastName}</h2>
        <div class="hero-meta font-mono">
          <span class="hero-meta-label">Citizen</span>
          <span class="hero-meta-dot"></span>
          <span>{identity.citizenId}</span>
        </div>
      </div>
    </div>

    <div class="fields-panel">
      <div class="fields-panel-head">
        <span class="fields-panel-title font-mono">Personal information</span>
      </div>
      <div class="fields-grid">
        {#each fields as field (field.key)}
          {@const Icon = field.icon}
          {@const editable = editing && EDITABLE_KEYS.has(field.key)}
          <div class="id-field">
            <div class="id-field-icon">
              <Icon size={14} strokeWidth={1.5} />
            </div>
            <div class="id-field-content">
              <span class="id-field-label font-mono">{field.label}</span>
              {#if editable}
                <input
                  class="id-field-input"
                  class:font-mono={field.mono}
                  value={editData[field.key] || ''}
                  oninput={(e) => (editData[field.key] = e.target.value)}
                />
              {:else}
                <span class="id-field-value" class:font-mono={field.mono}>{identity[field.key] || '—'}</span>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    </div>

    <p class="id-footnote font-mono">Los Santos Municipal Government · Citizen identification record</p>
  {/if}
</div>

<style>
  .civ-identity {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: calc(16px * var(--mdt-scale));
    min-height: 0;
    opacity: 0;
  }

  .civ-identity.mounted {
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .page-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .page-title {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
    margin: 0;
  }

  .page-subtitle {
    margin: calc(4px * var(--mdt-scale)) 0 0;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: calc(8px * var(--mdt-scale));
  }

  .subtitle-id {
    color: var(--mdt-accent);
    letter-spacing: 0.06em;
  }

  .subtitle-sep {
    width: calc(3px * var(--mdt-scale));
    height: calc(3px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-text-muted);
    flex-shrink: 0;
  }

  .subtitle-source {
    letter-spacing: 0.04em;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: wrap;
    justify-content: flex-end;
  }

  .id-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.18s ease, opacity 0.18s ease, border-color 0.18s ease, background 0.18s ease, color 0.18s ease;
    white-space: nowrap;
  }

  .id-btn-neutral {
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .id-btn-neutral:hover:not(:disabled) {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    color: var(--mdt-accent);
  }

  .id-btn-primary {
    border: 1px solid color-mix(in srgb, var(--mdt-success) 55%, var(--mdt-border));
    color: var(--mdt-success);
    background: color-mix(in srgb, var(--mdt-success) 18%, var(--mdt-surface-2));
    box-shadow: inset 0 1px 0 color-mix(in srgb, var(--mdt-success) 12%, transparent);
  }

  .id-btn-primary:hover:not(:disabled) {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: var(--mdt-success);
    background: color-mix(in srgb, var(--mdt-success) 28%, var(--mdt-surface-2));
  }

  .id-btn-danger {
    border: 1px solid color-mix(in srgb, var(--mdt-error) 55%, var(--mdt-border));
    color: var(--mdt-error);
    background: color-mix(in srgb, var(--mdt-error) 18%, var(--mdt-surface-2));
    box-shadow: inset 0 1px 0 color-mix(in srgb, var(--mdt-error) 12%, transparent);
  }

  .id-btn-danger:hover:not(:disabled) {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: var(--mdt-error);
    background: color-mix(in srgb, var(--mdt-error) 28%, var(--mdt-surface-2));
    color: color-mix(in srgb, var(--mdt-error) 92%, white);
  }

  .id-btn:disabled {
    opacity: 0.5;
    cursor: wait;
  }

  .identity-hero {
    display: flex;
    align-items: center;
    gap: calc(16px * var(--mdt-scale));
    padding: calc(16px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 22%, var(--mdt-border));
    border-radius: var(--mdt-radius);
    background: linear-gradient(
      135deg,
      color-mix(in srgb, var(--mdt-accent) 10%, transparent),
      color-mix(in srgb, var(--mdt-surface) 88%, transparent)
    );
  }

  .hero-avatar {
    width: calc(72px * var(--mdt-scale));
    height: calc(72px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border-2);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--mdt-text-dim);
    flex-shrink: 0;
    overflow: hidden;
  }

  .hero-avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  .hero-copy {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .hero-name {
    margin: 0;
    font-size: calc(18px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
    line-height: 1.15;
  }

  .hero-meta {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(11px * var(--mdt-scale));
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .hero-meta-label {
    color: var(--mdt-accent);
    font-weight: 600;
  }

  .hero-meta-dot {
    width: calc(3px * var(--mdt-scale));
    height: calc(3px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-text-muted);
  }

  .fields-panel {
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  .fields-panel-head {
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
  }

  .fields-panel-title {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-dim);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .fields-grid {
    padding: calc(16px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(260px * var(--mdt-scale)), 1fr));
    gap: calc(14px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
  }

  .id-field {
    display: flex;
    align-items: flex-start;
    gap: calc(10px * var(--mdt-scale));
    min-width: 0;
  }

  .id-field-icon {
    width: calc(30px * var(--mdt-scale));
    height: calc(30px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-accent-dim);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--mdt-accent);
    margin-top: calc(2px * var(--mdt-scale));
  }

  .id-field-content {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
    flex: 1;
  }

  .id-field-label {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .id-field-value {
    font-size: calc(13px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .id-field-input {
    width: 100%;
    padding: calc(8px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    outline: none;
    transition: border-color 0.2s ease;
  }

  .id-field-input:focus {
    border-color: var(--mdt-accent);
  }

  .id-footnote {
    margin: 0;
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    opacity: 0.55;
    text-align: center;
  }

  .id-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(40px * var(--mdt-scale));
    border: 1px dashed color-mix(in srgb, var(--mdt-accent) 22%, var(--mdt-border));
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
    text-align: center;
  }

  .id-empty-title {
    font-size: calc(14px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 600;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(calc(8px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @media (max-width: 720px) {
    .page-header {
      flex-direction: column;
      align-items: stretch;
    }

    .header-actions {
      justify-content: stretch;
    }

    .header-actions .id-btn {
      flex: 1;
    }

    .identity-hero {
      flex-direction: column;
      align-items: flex-start;
    }
  }
</style>
