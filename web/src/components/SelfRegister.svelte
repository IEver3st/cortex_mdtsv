<script>
  import { X, UserRound, AlertTriangle, Zap, Image } from '@lucide/svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';

  let { onClose, onSuccess } = $props();

  let firstName = $state('');
  let lastName = $state('');
  let dob = $state('');
  let nationality = $state('');
  let mugshot = $state('');
  let hasWarrant = $state(false);
  let hasSpeedingPrior = $state(false);
  let notes = $state('');
  let saving = $state(false);
  let error = $state('');

  const nationalities = [
    'San Andreas',
    'United States',
    'Canadian',
    'British',
    'Mexican',
    'Australian',
    'French',
    'German',
    'Italian',
    'Japanese',
    'Chinese',
    'Korean',
    'Other',
  ];

  async function handleSubmit() {
    if (!firstName.trim() || !lastName.trim()) {
      error = 'First name and last name are required.';
      return;
    }

    saving = true;
    error = '';

    const response = await dataStore.registerStandaloneCivilian({
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      dob: dob || null,
      nationality: nationality || null,
      mugshot: mugshot.trim() || null,
      hasWarrant,
      hasSpeedingPrior,
      notes: notes.trim() || null,
    });

    saving = false;

    if (response?.ok) {
      onSuccess?.(response.citizen);
      onClose();
    } else {
      error = response?.error || 'Failed to register civilian.';
    }
  }

  function handleBackdropClick(e) {
    if (e.target === e.currentTarget) {
      onClose();
    }
  }

  function handleBackdropKeydown(e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      onClose();
    }
  }
</script>

<div
  class="modal-backdrop"
  onclick={handleBackdropClick}
  onkeydown={handleBackdropKeydown}
  role="dialog"
  aria-modal="true"
  aria-label="Self Register Civilian"
  tabindex="0"
>
  <div class="modal-panel">
    <div class="modal-header">
      <div class="header-content">
        <div class="header-icon">
          <UserRound size={24} strokeWidth={1.5} />
        </div>
        <div class="header-text">
          <h2 class="modal-title">Self Register</h2>
          <span class="modal-subtitle">Create your civilian identity</span>
        </div>
      </div>
      <button class="close-btn" onclick={onClose} aria-label="Close">
        <X size={20} strokeWidth={2} />
      </button>
    </div>

    <div class="modal-body">
      {#if error}
        <div class="error-banner">
          <AlertTriangle size={16} strokeWidth={2} />
          <span>{error}</span>
        </div>
      {/if}

      <form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
        <div class="form-section">
          <h3 class="section-title">Personal Information</h3>

          <div class="form-row">
            <div class="form-group">
              <label class="form-label" for="firstName">First Name</label>
              <input
                type="text"
                id="firstName"
                class="form-input"
                placeholder="Enter first name"
                bind:value={firstName}
                required
              />
            </div>
            <div class="form-group">
              <label class="form-label" for="lastName">Last Name</label>
              <input
                type="text"
                id="lastName"
                class="form-input"
                placeholder="Enter last name"
                bind:value={lastName}
                required
              />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label class="form-label" for="dob">Date of Birth</label>
              <input
                type="date"
                id="dob"
                class="form-input"
                bind:value={dob}
              />
            </div>
            <div class="form-group">
              <label class="form-label" for="nationality">Nationality</label>
              <select id="nationality" class="form-input form-select" bind:value={nationality}>
                <option value="">Select nationality...</option>
                {#each nationalities as nat}
                  <option value={nat}>{nat}</option>
                {/each}
              </select>
            </div>
          </div>
        </div>

        <div class="form-section">
          <h3 class="section-title">Profile</h3>

          <div class="form-group">
            <label class="form-label" for="mugshot">
              <Image size={14} strokeWidth={1.5} />
              Profile Picture URL
            </label>
            <input
              type="url"
              id="mugshot"
              class="form-input"
              placeholder="https://example.com/photo.jpg"
              bind:value={mugshot}
            />
          </div>
        </div>

        <div class="form-section">
          <h3 class="section-title">Criminal Record Flags</h3>

          <div class="toggle-group">
            <label class="toggle-item">
              <div class="toggle-info">
                <AlertTriangle size={16} strokeWidth={1.5} class="toggle-icon toggle-warn" />
                <span class="toggle-label">Active Warrant</span>
              </div>
              <input type="checkbox" class="toggle-checkbox" bind:checked={hasWarrant} />
              <div class="toggle-switch" class:toggle-active={hasWarrant}>
                <div class="toggle-thumb"></div>
              </div>
            </label>

            <label class="toggle-item">
              <div class="toggle-info">
                <Zap size={16} strokeWidth={1.5} class="toggle-icon toggle-speed" />
                <span class="toggle-label">Speeding Prior</span>
              </div>
              <input type="checkbox" class="toggle-checkbox" bind:checked={hasSpeedingPrior} />
              <div class="toggle-switch" class:toggle-active={hasSpeedingPrior}>
                <div class="toggle-thumb"></div>
              </div>
            </label>
          </div>
        </div>

        <div class="form-section">
          <div class="form-group">
            <label class="form-label" for="notes">Additional Notes</label>
            <textarea
              id="notes"
              class="form-textarea"
              placeholder="Any additional information about your character..."
              bind:value={notes}
              rows="3"
            ></textarea>
          </div>
        </div>
      </form>
    </div>

    <div class="modal-footer">
      <button class="btn-cancel" onclick={onClose} disabled={saving}>
        Cancel
      </button>
      <button class="btn-submit" onclick={handleSubmit} disabled={saving || !firstName.trim() || !lastName.trim()}>
        {saving ? 'Registering...' : 'Register Civilian'}
      </button>
    </div>
  </div>
</div>

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(6, 8, 12, 0.85);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    animation: fadeIn 0.2s ease-out forwards;
  }

  .modal-panel {
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: calc(14px * var(--mdt-scale, 1));
    width: calc(520px * var(--mdt-scale, 1));
    max-width: calc(90vw * var(--mdt-scale, 1));
    max-height: calc(90vh * var(--mdt-scale, 1));
    overflow: hidden;
    display: flex;
    flex-direction: column;
    box-shadow:
      0 0 80px rgba(0, 0, 0, 0.5),
      0 40px 100px rgba(0, 0, 0, 0.7);
    animation: slideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes slideIn {
    from { opacity: 0; transform: scale(0.95) translateY(20px); }
    to { opacity: 1; transform: scale(1) translateY(0); }
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(20px * var(--mdt-scale, 1)) calc(24px * var(--mdt-scale, 1));
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-accent-dim);
  }

  .header-content {
    display: flex;
    align-items: center;
    gap: calc(14px * var(--mdt-scale, 1));
  }

  .header-icon {
    width: calc(44px * var(--mdt-scale, 1));
    height: calc(44px * var(--mdt-scale, 1));
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--mdt-accent-dim);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 20%, transparent);
    border-radius: calc(10px * var(--mdt-scale, 1));
    color: var(--mdt-accent);
  }

  .header-text {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale, 1));
  }

  .modal-title {
    font-size: calc(18px * var(--mdt-scale, 1));
    font-weight: 700;
    color: var(--mdt-text);
    margin: 0;
    letter-spacing: 0.02em;
  }

  .modal-subtitle {
    font-size: calc(11px * var(--mdt-scale, 1));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .close-btn {
    width: calc(36px * var(--mdt-scale, 1));
    height: calc(36px * var(--mdt-scale, 1));
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: calc(8px * var(--mdt-scale, 1));
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
  }

  .close-btn:hover {
    background: rgba(255, 255, 255, 0.08);
    color: var(--mdt-text);
  }

  .modal-body {
    padding: calc(24px * var(--mdt-scale, 1));
    overflow-y: auto;
    flex: 1;
  }

  .error-banner {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale, 1));
    padding: calc(12px * var(--mdt-scale, 1)) calc(14px * var(--mdt-scale, 1));
    background: rgba(248, 113, 113, 0.1);
    border: 1px solid rgba(248, 113, 113, 0.25);
    border-radius: calc(8px * var(--mdt-scale, 1));
    color: #f87171;
    font-size: calc(12px * var(--mdt-scale, 1));
    margin-bottom: calc(18px * var(--mdt-scale, 1));
    animation: fadeIn 0.2s ease-out forwards;
  }

  .form-section {
    margin-bottom: calc(24px * var(--mdt-scale, 1));
  }

  .form-section:last-child {
    margin-bottom: 0;
  }

  .section-title {
    font-size: calc(10px * var(--mdt-scale, 1));
    font-weight: 700;
    color: var(--mdt-accent);
    text-transform: uppercase;
    letter-spacing: 0.12em;
    margin: 0 0 calc(14px * var(--mdt-scale, 1)) 0;
    padding-bottom: calc(8px * var(--mdt-scale, 1));
    border-bottom: 1px solid color-mix(in srgb, var(--mdt-accent) 12%, transparent);
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(12px * var(--mdt-scale, 1));
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale, 1));
    margin-bottom: calc(12px * var(--mdt-scale, 1));
  }

  .form-group:last-child {
    margin-bottom: 0;
  }

  .form-label {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale, 1));
    font-size: calc(10px * var(--mdt-scale, 1));
    font-weight: 600;
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .form-input {
    width: 100%;
    padding: calc(10px * var(--mdt-scale, 1)) calc(12px * var(--mdt-scale, 1));
    border-radius: calc(8px * var(--mdt-scale, 1));
    border: 1px solid var(--mdt-border);
    background: rgba(0, 0, 0, 0.3);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale, 1));
    outline: none;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .form-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-input:focus {
    border-color: var(--mdt-accent);
    box-shadow: 0 0 0 3px var(--mdt-accent-dim);
  }

  .form-select {
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='rgba(228,232,239,0.38)' stroke-width='2'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 12px center;
    padding-right: calc(36px * var(--mdt-scale, 1));
  }

  .form-select option {
    background: var(--mdt-surface);
    color: var(--mdt-text);
  }

  .form-textarea {
    width: 100%;
    resize: vertical;
    padding: calc(10px * var(--mdt-scale, 1)) calc(12px * var(--mdt-scale, 1));
    border-radius: calc(8px * var(--mdt-scale, 1));
    border: 1px solid var(--mdt-border);
    background: rgba(0, 0, 0, 0.3);
    color: var(--mdt-text);
    font-family: 'Outfit', sans-serif;
    font-size: calc(13px * var(--mdt-scale, 1));
    line-height: 1.5;
    outline: none;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
    min-height: calc(80px * var(--mdt-scale, 1));
  }

  .form-textarea::placeholder {
    color: var(--mdt-text-muted);
  }

  .form-textarea:focus {
    border-color: var(--mdt-accent);
    box-shadow: 0 0 0 3px var(--mdt-accent-dim);
  }

  .toggle-group {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale, 1));
  }

  .toggle-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(14px * var(--mdt-scale, 1)) calc(16px * var(--mdt-scale, 1));
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid var(--mdt-border);
    border-radius: calc(10px * var(--mdt-scale, 1));
    cursor: pointer;
    transition: background 0.15s ease, border-color 0.15s ease;
  }

  .toggle-item:hover {
    background: rgba(0, 0, 0, 0.35);
    border-color: color-mix(in srgb, var(--mdt-accent) 20%, transparent);
  }

  .toggle-info {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale, 1));
  }


  .toggle-label {
    font-size: calc(13px * var(--mdt-scale, 1));
    font-weight: 500;
    color: var(--mdt-text);
  }

  .toggle-checkbox {
    display: none;
  }

  .toggle-switch {
    width: calc(44px * var(--mdt-scale, 1));
    height: calc(24px * var(--mdt-scale, 1));
    background: rgba(255, 255, 255, 0.08);
    border-radius: calc(999px * var(--mdt-scale, 1));
    position: relative;
    transition: background 0.2s ease;
    flex-shrink: 0;
  }

  .toggle-switch.toggle-active {
    background: var(--mdt-accent-dim);
  }

  .toggle-thumb {
    position: absolute;
    top: calc(2px * var(--mdt-scale, 1));
    left: calc(2px * var(--mdt-scale, 1));
    width: calc(20px * var(--mdt-scale, 1));
    height: calc(20px * var(--mdt-scale, 1));
    background: var(--mdt-text-muted);
    border-radius: 50%;
    transition: left 0.2s ease, background 0.2s ease, box-shadow 0.2s ease;
  }

  .toggle-switch.toggle-active .toggle-thumb {
    left: calc(22px * var(--mdt-scale, 1));
    background: var(--mdt-accent);
    box-shadow: 0 0 8px var(--mdt-accent-glow);
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: calc(10px * var(--mdt-scale, 1));
    padding: calc(18px * var(--mdt-scale, 1)) calc(24px * var(--mdt-scale, 1));
    border-top: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
  }

  .btn-cancel,
  .btn-submit {
    padding: calc(10px * var(--mdt-scale, 1)) calc(20px * var(--mdt-scale, 1));
    border-radius: calc(8px * var(--mdt-scale, 1));
    font-family: 'Outfit', sans-serif;
    font-size: calc(12px * var(--mdt-scale, 1));
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease, border-color 0.15s ease;
    letter-spacing: 0.04em;
  }

  .btn-cancel {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--mdt-text-muted);
  }

  .btn-cancel:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.08);
    color: var(--mdt-text);
  }

  .btn-submit {
    background: var(--mdt-accent-dim);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 30%, transparent);
    color: var(--mdt-accent);
  }

  .btn-submit:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-accent) 20%, transparent);
    border-color: var(--mdt-accent);
  }

  .btn-cancel:disabled,
  .btn-submit:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-submit:active:not(:disabled) {
    transform: scale(0.96);
  }
</style>
