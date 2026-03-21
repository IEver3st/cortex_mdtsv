<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { User, MapPin, Calendar, Phone, Mail, Fingerprint, Shield, Trash2 } from 'lucide-svelte';

  let mounted = $state(false);
  let deleting = $state(false);
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
  });

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

  const fields = [
    { key: 'citizenId', label: 'Citizen ID', icon: Fingerprint, mono: true },
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
      <button class="return-btn" onclick={() => mdtStore.activePage = 'civ-dashboard'}>Return to Dashboard</button>
    </div>
  {:else}
    <div class="id-actions">
      <span class="id-chip font-mono">{civ.generated ? 'GENERATED' : 'CUSTOM'}</span>
      <button class="delete-btn" onclick={handleDelete} disabled={deleting}>
        <Trash2 size={14} strokeWidth={1.8} />
        <span>{deleting ? 'Deleting...' : 'Delete Civilian'}</span>
      </button>
    </div>

    <div class="id-card">
      <div class="id-card-header">
        <div class="id-card-badge">
          <div class="id-avatar">
            <User size={36} strokeWidth={1.2} />
          </div>
        </div>
        <div class="id-card-name">
          <h1 class="id-full-name">{identity.firstName} {identity.lastName}</h1>
          <span class="id-citizen-tag font-mono">{identity.citizenId}</span>
        </div>
        <div class="id-card-status">
          <span class="id-status-dot"></span>
          <span class="id-status-label font-mono">VALID</span>
        </div>
      </div>

      <div class="id-card-divider"></div>

      <div class="id-card-body">
        <div class="id-section-title font-mono">PERSONAL INFORMATION</div>
        <div class="id-fields">
          {#each fields as field (field.key)}
            {@const Icon = field.icon}
            <div class="id-field">
              <div class="id-field-icon">
                <Icon size={14} strokeWidth={1.5} />
              </div>
              <div class="id-field-content">
                <span class="id-field-label font-mono">{field.label}</span>
                <span class="id-field-value" class:font-mono={field.mono}>{identity[field.key] || '--'}</span>
              </div>
            </div>
          {/each}
        </div>
      </div>

      <div class="id-card-footer font-mono">
        <span>LOS SANTOS MUNICIPAL GOVERNMENT</span>
        <span class="id-footer-sep">|</span>
        <span>CITIZEN IDENTIFICATION RECORD</span>
      </div>
    </div>
  {/if}
</div>

<style>
  .civ-identity {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    opacity: 0;
  }

  .civ-identity.mounted {
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .id-actions {
    width: 100%;
    max-width: calc(640px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
  }

  .id-chip {
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: calc(999px * var(--mdt-scale));
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    color: var(--civ-gold, var(--mdt-accent));
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.1em;
  }

  .delete-btn,
  .return-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: calc(999px * var(--mdt-scale));
    border: 1px solid rgba(248, 113, 113, 0.3);
    background: rgba(248, 113, 113, 0.08);
    color: var(--mdt-error);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.18s ease, transform 0.18s ease;
  }

  .return-btn {
    border-color: var(--civ-border, var(--mdt-border));
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
  }

  .delete-btn:hover:enabled,
  .return-btn:hover {
    transform: translateY(calc(-1px * var(--mdt-scale)));
  }

  .delete-btn:disabled {
    opacity: 0.6;
    cursor: wait;
  }

  .id-empty {
    width: 100%;
    max-width: calc(640px * var(--mdt-scale));
    padding: calc(28px * var(--mdt-scale));
    border-radius: var(--mdt-radius-lg);
    background: var(--mdt-surface);
    border: 1px solid var(--civ-border, var(--mdt-border));
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .id-empty-title {
    font-size: calc(15px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 600;
  }

  .id-card {
    width: 100%;
    max-width: calc(640px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--civ-border, var(--mdt-border));
    border-radius: var(--mdt-radius-lg);
    overflow: hidden;
  }

  .id-card-header {
    display: flex;
    align-items: center;
    gap: calc(16px * var(--mdt-scale));
    padding: calc(24px * var(--mdt-scale));
    background: linear-gradient(135deg, rgba(201, 168, 76, 0.06) 0%, transparent 60%);
  }

  .id-card-badge {
    position: relative;
  }

  .id-avatar {
    width: calc(64px * var(--mdt-scale));
    height: calc(64px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-2);
    border: 2px solid var(--civ-border, var(--mdt-border-2));
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--mdt-text-dim);
    flex-shrink: 0;
  }

  .id-card-name {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }

  .id-full-name {
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--civ-cream, var(--mdt-text));
    letter-spacing: -0.01em;
    line-height: 1.1;
  }

  .id-citizen-tag {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--civ-gold, var(--mdt-accent));
    letter-spacing: 0.08em;
  }

  .id-card-status {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: rgba(52, 211, 153, 0.1);
    border: 1px solid rgba(52, 211, 153, 0.2);
    border-radius: calc(16px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .id-status-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-success);
    box-shadow: 0 0 6px rgba(52, 211, 153, 0.5);
  }

  .id-status-label {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-success);
    letter-spacing: 0.12em;
    font-weight: 600;
  }

  .id-card-divider {
    height: 1px;
    background: linear-gradient(90deg, transparent, var(--civ-border, var(--mdt-border)), transparent);
  }

  .id-card-body {
    padding: calc(20px * var(--mdt-scale)) calc(24px * var(--mdt-scale));
  }

  .id-section-title {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--civ-gold, var(--mdt-accent));
    letter-spacing: 0.2em;
    margin-bottom: calc(16px * var(--mdt-scale));
    opacity: 0.7;
  }

  .id-fields {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: calc(12px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
  }

  .id-field {
    display: flex;
    align-items: flex-start;
    gap: calc(10px * var(--mdt-scale));
  }

  .id-field-icon {
    width: calc(28px * var(--mdt-scale));
    height: calc(28px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--civ-gold, var(--mdt-accent));
    margin-top: calc(2px * var(--mdt-scale));
  }

  .id-field-content {
    display: flex;
    flex-direction: column;
    gap: calc(1px * var(--mdt-scale));
    min-width: 0;
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

  .id-card-footer {
    padding: calc(12px * var(--mdt-scale)) calc(24px * var(--mdt-scale));
    border-top: 1px solid var(--civ-border, var(--mdt-border));
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(10px * var(--mdt-scale));
    font-size: calc(8px * var(--mdt-scale));
    letter-spacing: 0.25em;
    color: var(--mdt-text-muted);
    opacity: 0.5;
    text-transform: uppercase;
  }

  .id-footer-sep {
    opacity: 0.3;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(8px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
