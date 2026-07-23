<script>
  import { onMount } from 'svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { Car, Plus, User, AlertTriangle, Check, Clock3, ShieldAlert } from '@lucide/svelte';

  let mounted = $state(false);
  let showManualForm = $state(false);
  let submitting = $state(false);
  let feedback = $state('');

  let form = $state({
    plate: '',
    model: '',
    color: '',
    vehicleClass: '',
    year: '',
  });

  let vehicles = $derived(dataStore.standaloneVehicles || []);
  let civ = $derived(mdtStore.civilian || {});
  let canRegister = $derived(!!dataStore.standaloneCivilianState.activeCitizenId);

  onMount(() => {
    mounted = true;
    dataStore.fetchStandaloneCivilianState();
  });

  function resetForm() {
    form = {
      plate: '',
      model: '',
      color: '',
      vehicleClass: '',
      year: '',
    };
  }

  function setFeedback(message) {
    feedback = message || '';
  }

  async function submitManualRegistration() {
    if (!canRegister) {
      setFeedback('Claim a civilian before registering a vehicle.');
      return;
    }

    submitting = true;
    const response = await dataStore.registerStandaloneVehicle({ ...form });
    submitting = false;

    if (response?.ok) {
      setFeedback(`Registered ${response.vehicle?.plate || form.plate.trim().toUpperCase()} to ${civ.fullName || civ.firstName || 'your active civilian'}.`);
      showManualForm = false;
      resetForm();
      return;
    }

    setFeedback(response?.error || 'Unable to register vehicle.');
  }

  async function registerCurrentVehicle() {
    if (!canRegister) {
      setFeedback('Claim a civilian before registering a vehicle.');
      return;
    }

    submitting = true;
    const response = await dataStore.registerCurrentStandaloneVehicle({});
    submitting = false;

    if (response?.ok) {
      setFeedback(`Registered current vehicle ${response.vehicle?.plate || ''}.`.trim());
      return;
    }

    setFeedback(response?.error || 'Unable to register the current vehicle.');
  }

  function statusColor(status) {
    if (status === 'valid') return 'var(--mdt-success)';
    if (status === 'suspended' || status === 'stolen') return 'var(--mdt-error)';
    return 'var(--mdt-warning)';
  }

  function statusBg(status) {
    if (status === 'valid') return 'rgba(52, 211, 153, 0.1)';
    if (status === 'suspended' || status === 'stolen') return 'rgba(248, 113, 113, 0.1)';
    return 'rgba(251, 191, 36, 0.1)';
  }

  function statusLabel(status) {
    if (status === 'valid') return 'REGISTERED';
    return String(status || 'unregistered').replace('_', ' ').toUpperCase();
  }
</script>

<div class="civ-vehicles" class:mounted>
  <div class="page-header">
    <div>
      <h1 class="page-title">My Vehicles</h1>
      <p class="page-subtitle">Register vehicles to your currently claimed civilian profile.</p>
    </div>
    <span class="page-count font-mono">{vehicles.length} on file</span>
  </div>

  <div class="owner-toolbar" class:disabled={!canRegister}>
    <div class="owner-block">
      <div class="owner-icon-wrap">
        <User size={18} strokeWidth={1.5} />
      </div>
      <div class="owner-copy">
        <span class="owner-label font-mono">Active owner</span>
        <strong>{canRegister ? (civ.fullName || `${civ.firstName || ''} ${civ.lastName || ''}`.trim()) : 'No claimed civilian selected'}</strong>
        <span class="owner-meta font-mono">{canRegister ? civ.citizenId : 'Claim a persona to continue'}</span>
      </div>
    </div>
    <div class="toolbar-actions">
      <button type="button" class="veh-btn veh-btn-primary" onclick={registerCurrentVehicle} disabled={submitting || !canRegister}>
        <Car size={14} strokeWidth={1.8} />
        <span>{submitting ? 'Working...' : 'Register current'}</span>
      </button>
      <button type="button" class="veh-btn veh-btn-neutral" onclick={() => { showManualForm = !showManualForm; setFeedback(''); }} disabled={submitting || !canRegister}>
        <Plus size={14} strokeWidth={1.8} />
        <span>{showManualForm ? 'Close manual' : 'Manual entry'}</span>
      </button>
    </div>
  </div>

  {#if feedback}
    <div class="feedback-banner">{feedback}</div>
  {/if}

  {#if showManualForm}
    <div class="manual-form-card">
      <div class="form-header">
        <h2>Manual Vehicle Registration</h2>
        <span class="font-mono">LINKED TO {civ.citizenId || 'NONE'}</span>
      </div>

      <div class="form-grid">
        <label class="form-field">
          <span class="field-label font-mono">Plate</span>
          <input bind:value={form.plate} class="field-input font-mono" placeholder="84LSA219" maxlength="16" />
        </label>
        <label class="form-field">
          <span class="field-label font-mono">Model</span>
          <input bind:value={form.model} class="field-input" placeholder="Karin Sultan RS" />
        </label>
        <label class="form-field">
          <span class="field-label font-mono">Color</span>
          <input bind:value={form.color} class="field-input" placeholder="Midnight Blue" />
        </label>
        <label class="form-field">
          <span class="field-label font-mono">Class</span>
          <input bind:value={form.vehicleClass} class="field-input" placeholder="Sports" />
        </label>
        <label class="form-field">
          <span class="field-label font-mono">Year</span>
          <input bind:value={form.year} class="field-input font-mono" placeholder="2024" maxlength="4" />
        </label>
      </div>

      <div class="form-actions">
        <button type="button" class="veh-btn veh-btn-neutral" onclick={resetForm} disabled={submitting}>Reset</button>
        <button type="button" class="veh-btn veh-btn-primary" onclick={submitManualRegistration} disabled={submitting || !canRegister}>
          <Check size={14} strokeWidth={2} />
          <span>{submitting ? 'Saving...' : 'Save registration'}</span>
        </button>
      </div>
    </div>
  {/if}

  <div class="vehicle-list">
    {#if !canRegister}
      <div class="empty-state">
        <ShieldAlert size={34} strokeWidth={1.2} />
        <span class="empty-title">No active civilian claimed</span>
        <span class="empty-text">Claim or generate a civilian from the dashboard, then return here to register vehicles.</span>
      </div>
    {:else if vehicles.length === 0}
      <div class="empty-state">
        <Car size={32} strokeWidth={1} />
        <span class="empty-title">No vehicles on file</span>
        <span class="empty-text">Use manual registration or capture the vehicle you are currently sitting in.</span>
      </div>
    {:else}
      {#each vehicles as veh, i (veh.id || veh.vehicle_id || veh.plate || i)}
        <div class="vehicle-card" style="--stagger: {i}">
          <div class="veh-icon-wrap">
            <Car size={20} strokeWidth={1.5} />
          </div>

          <div class="veh-main">
            <div class="veh-top-row">
              <div>
                <span class="veh-model">{veh.model || 'Unknown Vehicle'}</span>
                <span class="veh-owner font-mono">OWNER {veh.owner_name || civ.fullName || civ.citizenId}</span>
              </div>
              <span class="veh-status font-mono" style="color: {statusColor(veh.registration_status)}; background: {statusBg(veh.registration_status)};">
                {#if veh.registration_status === 'valid'}
                  <Check size={10} strokeWidth={3} />
                {:else if veh.registration_status === 'suspended' || veh.registration_status === 'stolen'}
                  <AlertTriangle size={10} strokeWidth={2.5} />
                {:else}
                  <Clock3 size={10} strokeWidth={2.5} />
                {/if}
                {statusLabel(veh.registration_status)}
              </span>
            </div>

            <div class="veh-details font-mono">
              <div class="veh-detail">
                <span class="veh-detail-label">PLATE</span>
                <span class="veh-detail-value">{veh.plate}</span>
              </div>
              <div class="veh-detail-sep"></div>
              <div class="veh-detail">
                <span class="veh-detail-label">COLOR</span>
                <span class="veh-detail-value">{veh.color || 'Unknown'}</span>
              </div>
              <div class="veh-detail-sep"></div>
              <div class="veh-detail">
                <span class="veh-detail-label">CLASS</span>
                <span class="veh-detail-value">{veh.vehicle_class || 'Unknown'}</span>
              </div>
              <div class="veh-detail-sep"></div>
              <div class="veh-detail">
                <span class="veh-detail-label">YEAR</span>
                <span class="veh-detail-value">{veh.year || 'N/A'}</span>
              </div>
              <div class="veh-detail-sep"></div>
              <div class="veh-detail">
                <span class="veh-detail-label">REG. EXPIRES</span>
                <span class="veh-detail-value">{veh.reg_expiry || veh.regExpiry || 'N/A'}</span>
              </div>
            </div>
          </div>
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .civ-vehicles {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    opacity: 0;
  }

  .civ-vehicles.mounted {
    animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .page-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
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
  }

  .page-count {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.06em;
    font-variant-numeric: tabular-nums;
    text-transform: uppercase;
  }

  .owner-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
    flex-wrap: wrap;
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    background: var(--mdt-surface);
  }

  .owner-toolbar.disabled {
    opacity: 0.6;
  }

  .owner-block {
    display: flex;
    align-items: center;
    gap: calc(14px * var(--mdt-scale));
    min-width: 0;
    flex: 1 1 calc(220px * var(--mdt-scale));
  }

  .owner-icon-wrap {
    width: calc(42px * var(--mdt-scale));
    height: calc(42px * var(--mdt-scale));
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--mdt-radius);
    background: var(--mdt-accent-dim);
    border: 1px solid var(--mdt-border-2);
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .owner-copy {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    min-width: 0;
  }

  .owner-label {
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.12em;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
  }

  .owner-copy strong {
    font-size: calc(15px * var(--mdt-scale));
    color: var(--mdt-text);
  }

  .owner-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    letter-spacing: 0.08em;
  }

  .toolbar-actions {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-wrap: wrap;
    justify-content: flex-end;
  }

  .veh-btn {
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

  .veh-btn-neutral {
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
  }

  .veh-btn-neutral:hover:not(:disabled) {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    color: var(--mdt-accent);
  }

  .veh-btn-primary {
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 55%, var(--mdt-border));
    color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-accent) 18%, var(--mdt-surface-2));
    box-shadow: inset 0 1px 0 color-mix(in srgb, var(--mdt-accent) 12%, transparent);
  }

  .veh-btn-primary:hover:not(:disabled) {
    transform: translateY(calc(-1px * var(--mdt-scale)));
    border-color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-accent) 28%, var(--mdt-surface-2));
  }

  .veh-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .feedback-banner {
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid rgba(96, 165, 250, 0.16);
    background: rgba(96, 165, 250, 0.08);
    color: var(--mdt-text-dim);
    font-size: calc(12px * var(--mdt-scale));
  }

  .manual-form-card {
    padding: calc(18px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
  }

  .form-header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
  }

  .form-header h2 {
    margin: 0;
    font-size: calc(16px * var(--mdt-scale));
    color: var(--mdt-text);
  }

  .form-header span {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-accent);
    letter-spacing: 0.1em;
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: calc(12px * var(--mdt-scale));
  }

  .form-field {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .field-label {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .field-input {
    width: 100%;
    padding: calc(11px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    outline: none;
  }

  .field-input:focus {
    border-color: var(--mdt-accent);
  }

  .form-actions {
    display: flex;
    justify-content: flex-end;
    gap: calc(10px * var(--mdt-scale));
  }

  .vehicle-list {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .vehicle-card {
    display: flex;
    align-items: flex-start;
    gap: calc(14px * var(--mdt-scale));
    padding: calc(16px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    animation: cardIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--stagger) * 60ms);
    opacity: 0;
    transition: border-color 0.2s ease;
  }

  .vehicle-card:hover {
    border-color: var(--mdt-accent);
  }

  .veh-icon-wrap {
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    background: var(--mdt-accent-dim);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--mdt-accent);
  }

  .veh-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
  }

  .veh-top-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
  }

  .veh-model {
    display: block;
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .veh-owner {
    display: inline-block;
    margin-top: calc(2px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.08em;
  }

  .veh-status {
    display: flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.1em;
    font-weight: 600;
    padding: calc(3px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .veh-details {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .veh-detail {
    display: flex;
    flex-direction: column;
    gap: calc(1px * var(--mdt-scale));
  }

  .veh-detail-label {
    font-size: calc(8px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.12em;
  }

  .veh-detail-value {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-dim);
  }

  .veh-detail-sep {
    width: 1px;
    height: calc(20px * var(--mdt-scale));
    background: var(--mdt-border);
    flex-shrink: 0;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(40px * var(--mdt-scale));
    border: 1px dashed rgba(96, 165, 250, 0.18);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
    text-align: center;
  }

  .empty-title {
    font-size: calc(14px * var(--mdt-scale));
    color: var(--mdt-text);
    font-weight: 600;
  }

  .empty-text {
    max-width: calc(420px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.5;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(8px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes cardIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @media (max-width: 900px) {
    .form-grid {
      grid-template-columns: 1fr;
    }

    .page-header,
    .form-header,
    .veh-top-row {
      flex-direction: column;
      align-items: flex-start;
    }

    .owner-toolbar {
      flex-direction: column;
      align-items: stretch;
    }

    .toolbar-actions,
    .form-actions {
      width: 100%;
      justify-content: stretch;
    }

    .toolbar-actions :global(button),
    .form-actions :global(button) {
      flex: 1;
    }
  }
</style>
