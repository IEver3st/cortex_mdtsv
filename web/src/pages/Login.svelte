<script>
  import { onMount } from 'svelte';
  import { Check, Fingerprint, ChevronRight } from '@lucide/svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { playMdtSound } from '../lib/utils/mdtSounds.js';
  import { getDepartmentBrand } from '../lib/utils/branding.js';
  import PortalRippleBackdrop from '../components/PortalRippleBackdrop.svelte';

  const PASSWORD_LEN = 12;
  const PASSWORD_TICK_MS = 95;

  let phase = $state('idle');
  let biometricError = $state('');
  let introComplete = $state(false);
  let passwordGhost = $state('');

  let officer = $derived(mdtStore.officer);
  let brand = $derived(getDepartmentBrand(officer));
  let isErsMode = $derived((officer?.frameworkMode || '').toLowerCase() === 'ers');
  let officerDisplayName = $derived(
    [officer?.firstName, officer?.lastName].filter(Boolean).join(' ').trim() || 'Unknown',
  );

  onMount(() => {
    const filler = 'x'.repeat(PASSWORD_LEN);
    let i = 0;
    const id = setInterval(() => {
      i += 1;
      passwordGhost = filler.slice(0, i);
      if (i >= PASSWORD_LEN) {
        clearInterval(id);
        introComplete = true;
      }
    }, PASSWORD_TICK_MS);
    return () => clearInterval(id);
  });

  async function handleBiometric() {
    if (phase !== 'idle' || !introComplete) return;

    biometricError = '';
    phase = 'scanning';
    await new Promise(r => setTimeout(r, 1800));

    if (isErsMode) {
      const ersResp = await dataStore.ersBiometricLogin();

      if (!ersResp?.ok) {
        phase = 'idle';
        biometricError = ersResp?.error || 'Unable to authenticate with ERS biometrics.';
        return;
      }

      if (ersResp?.officer) {
        mdtStore.officer = ersResp.officer;
      }
    }

    phase = 'verified';
    playMdtSound('biometric');
    await new Promise(r => setTimeout(r, 600));

    mdtStore.login();

    const activeOfficer = mdtStore.officer;
    const resp = await dataStore.registerOfficer({
      firstName: activeOfficer.firstName,
      lastName: activeOfficer.lastName,
      rank: activeOfficer.rank,
      callsign: activeOfficer.callsign,
      departmentKey: activeOfficer.departmentKey,
    });
    if (resp?.ok && resp.officerId) {
      mdtStore.officer = { ...mdtStore.officer, officerId: resp.officerId };
    }
    await Promise.all([
      dataStore.fetchUnits(),
      dataStore.fetchDashboard(),
    ]);
  }
</script>

<div class="login-root">
  <PortalRippleBackdrop layout="iso" seed={0x636f7274} />
  <!-- Terminal Modal -->
  <div class="terminal-modal">
    <!-- Header Section -->
    <div class="modal-header">
      <div class="badge-glow-wrap">
        <img
          src={brand.src}
          alt={brand.alt}
          class="dept-badge"
          class:dept-badge--logo={brand.variant === 'logo'}
          class:dept-badge--seal={brand.variant === 'seal'}
        />
      </div>
      
      <div class="title-section">
        <div class="dept-pill font-mono">LOS SANTOS POLICE DEPARTMENT</div>
        <h1 class="main-title font-mono">CORTEX MDT</h1>
      </div>
    </div>

    <!-- Rule Divider -->
    <div class="terminal-rule"></div>

    <!-- Inputs Section -->
    <div class="inputs-section font-mono">
      <div class="input-group">
        <label class="input-label" for="officer-id">OFFICER ID</label>
        <div class="input-wrapper">
          <input
            id="officer-id"
            type="text"
            class="terminal-input"
            value={officerDisplayName}
            readonly
          />
        </div>
      </div>

      <div class="input-group">
        <label class="input-label" for="password">PASSWORD</label>
        <div class="input-wrapper">
          <input
            id="password"
            type="password"
            class="terminal-input"
            bind:value={passwordGhost}
            readonly
            autocomplete="off"
          />
        </div>
      </div>
    </div>

    <!-- Status Row (moved inside or above button) -->
    {#if phase !== 'idle'}
    <div class="status-indicator font-mono">
      <span class="status-dot" class:dot-scanning={phase === 'scanning'} class:dot-verified={phase === 'verified'}></span>
      {#if phase === 'scanning'}
        <span class="status-text text-scanning">SCANNING BIOMETRICS...</span>
      {:else if phase === 'verified'}
        <span class="status-text text-verified">ACCESS GRANTED</span>
      {/if}
    </div>
    {/if}

    {#if biometricError}
    <div class="status-indicator status-indicator-error font-mono">
      <span class="status-text text-error">{biometricError}</span>
    </div>
    {/if}

    <!-- Action Button -->
    <button
      class="action-btn font-mono"
      class:action-btn--locked={!introComplete}
      class:scanning={phase === 'scanning'}
      class:verified={phase === 'verified'}
      onclick={handleBiometric}
      disabled={phase !== 'idle' || !introComplete}
    >
      <div class="btn-icon">
        {#if phase === 'verified'}
          <Check size={22} strokeWidth={2.35} />
        {:else}
          <Fingerprint size={34} strokeWidth={1.75} />
        {/if}
      </div>
      <span class="btn-text">
        {#if phase === 'idle'}
          LOG IN WITH BIOMETRICS
        {:else if phase === 'scanning'}
          VERIFYING IDENTITY
        {:else}
          ESTABLISHING CONNECTION
        {/if}
      </span>
      <div class="btn-arrow">
        <ChevronRight size={16} strokeWidth={2.1} />
      </div>
    </button>
  </div>
</div>

<style>
  /* ── Root ───────────────────────────────────────── */
  .login-root {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(10, 12, 16, 0.92);
    overflow: hidden;
    animation: loginEnter 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    --term-accent: #00ffcc;
    --term-accent-dim: rgba(0, 255, 204, 0.15);
    --term-accent-glow: rgba(0, 255, 204, 0.4);
    --term-bg: #0a0c10;
    --term-border: rgba(0, 255, 204, 0.2);
    --term-text: #e0f2fe;
    --term-text-muted: #7dd3fc;
  }

  @keyframes loginEnter {
    from { opacity: 0; transform: scale(0.95) translateY(20px); }
    to   { opacity: 1; transform: scale(1) translateY(0); }
  }

  /* ── Ambient background ─────────────────────────── */
  /* ── Terminal Modal ─────────────────────────────── */
  .terminal-modal {
    position: relative;
    z-index: 1;
    display: flex;
    flex-direction: column;
    width: calc(440px * var(--mdt-scale, 1));
    background: rgba(28, 30, 38, 0.96);
    border: none;
    border-radius: calc(8px * var(--mdt-scale, 1));
    padding: calc(48px * var(--mdt-scale, 1)) calc(40px * var(--mdt-scale, 1)) calc(32px * var(--mdt-scale, 1));
    box-shadow: 0 28px 72px rgba(0, 0, 0, 0.72);
    backdrop-filter: blur(10px);
  }

  /* ── Header ─────────────────────────────────────── */
  .modal-header {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(24px * var(--mdt-scale, 1));
    text-align: center;
  }

  .badge-glow-wrap {
    position: relative;
    width: calc(100px * var(--mdt-scale, 1));
    height: calc(100px * var(--mdt-scale, 1));
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .dept-badge {
    position: relative;
    z-index: 2;
    width: 100%;
    height: 100%;
    object-fit: contain;
    animation: badgeFloat 6s ease-in-out infinite;
  }

  @keyframes badgeFloat {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-5px); }
  }

  .title-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(10px * var(--mdt-scale, 1));
  }

  .dept-pill {
    color: color-mix(in srgb, var(--term-accent) 76%, white 24%);
    padding: 0;
    font-size: calc(10px * var(--mdt-scale, 1));
    font-weight: 700;
    letter-spacing: 0.32em;
    text-transform: uppercase;
    line-height: 1;
  }

  .main-title {
    font-size: calc(36px * var(--mdt-scale, 1));
    font-weight: 400;
    color: #ffffff;
    letter-spacing: 0.15em;
    margin: 0;
    text-shadow: 0 0 20px rgba(255, 255, 255, 0.2);
  }

  /* ── Divider ────────────────────────────────────── */
  .terminal-rule {
    width: 100%;
    height: 1px;
    background: linear-gradient(90deg, transparent, var(--term-border) 20%, var(--term-accent) 50%, var(--term-border) 80%, transparent);
    margin: calc(32px * var(--mdt-scale, 1)) 0;
    opacity: 0.5;
    position: relative;
  }

  .terminal-rule::after {
    content: '';
    position: absolute;
    top: -2px;
    left: 50%;
    transform: translateX(-50%);
    width: 12px;
    height: 5px;
    background: var(--term-accent);
    border-radius: 2px;
    box-shadow: 0 0 10px var(--term-accent-glow);
  }

  /* ── Inputs Section ─────────────────────────────── */
  .inputs-section {
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale, 1));
    margin-bottom: calc(32px * var(--mdt-scale, 1));
  }

  .input-group {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale, 1));
  }

  .input-label {
    font-size: calc(11px * var(--mdt-scale, 1));
    color: var(--term-text-muted);
    letter-spacing: 0.15em;
  }

  .input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
  }

  .terminal-input {
    width: 100%;
    background: rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--term-text);
    padding: calc(14px * var(--mdt-scale, 1)) calc(16px * var(--mdt-scale, 1));
    font-size: calc(14px * var(--mdt-scale, 1));
    font-family: inherit;
    letter-spacing: 0.1em;
    border-radius: calc(4px * var(--mdt-scale, 1));
    outline: none;
    transition: border-color 0.2s ease, box-shadow 0.2s ease;
  }

  .terminal-input:focus {
    border-color: var(--term-accent);
    box-shadow: 0 0 15px var(--term-accent-dim) inset;
  }

  /* ── Status Indicator ───────────────────────────── */
  .status-indicator {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(10px * var(--mdt-scale, 1));
    margin-bottom: calc(16px * var(--mdt-scale, 1));
  }

  .status-dot {
    width: calc(8px * var(--mdt-scale, 1));
    height: calc(8px * var(--mdt-scale, 1));
    border-radius: 50%;
    background: var(--term-text-muted);
    opacity: 0.5;
  }

  .status-dot.dot-scanning {
    background: var(--term-accent);
    opacity: 1;
    box-shadow: 0 0 8px var(--term-accent-glow);
    animation: blink 0.5s infinite alternate;
  }

  .status-dot.dot-verified {
    background: #34d399;
    opacity: 1;
    box-shadow: 0 0 10px rgba(52, 211, 153, 0.5);
  }

  @keyframes blink {
    from { opacity: 0.5; }
    to { opacity: 1; }
  }

  .status-text {
    font-size: calc(11px * var(--mdt-scale, 1));
    letter-spacing: 0.2em;
  }

  .text-scanning { color: var(--term-accent); animation: blink 0.5s infinite alternate; }
  .text-verified { color: #34d399; }
  .status-indicator-error {
    margin-top: calc(-6px * var(--mdt-scale, 1));
    margin-bottom: calc(14px * var(--mdt-scale, 1));
  }

  .text-error {
    color: #fca5a5;
    letter-spacing: 0.08em;
    text-align: center;
  }

  /* ── Action Button ──────────────────────────────── */
  .action-btn {
    width: 100%;
    display: grid;
    grid-template-columns: calc(44px * var(--mdt-scale, 1)) minmax(0, 1fr) calc(44px * var(--mdt-scale, 1));
    align-items: center;
    background: rgba(2, 132, 199, 0.2);
    border: 1px solid rgba(2, 132, 199, 0.4);
    color: #bae6fd;
    padding: calc(16px * var(--mdt-scale, 1)) calc(20px * var(--mdt-scale, 1));
    border-radius: calc(6px * var(--mdt-scale, 1));
    cursor: pointer;
    transition:
      background 0.45s cubic-bezier(0.16, 1, 0.3, 1),
      border-color 0.45s cubic-bezier(0.16, 1, 0.3, 1),
      color 0.45s cubic-bezier(0.16, 1, 0.3, 1),
      transform 0.3s cubic-bezier(0.16, 1, 0.3, 1),
      box-shadow 0.45s ease;
    position: relative;
    overflow: hidden;
  }

  .action-btn--locked {
    background: rgba(55, 65, 81, 0.35);
    border-color: rgba(75, 85, 99, 0.55);
    color: #9ca3af;
    cursor: not-allowed;
    box-shadow: none;
  }

  .action-btn--locked .btn-icon,
  .action-btn--locked .btn-arrow {
    color: #9ca3af;
  }

  .action-btn::before {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.05), transparent);
    transform: translateX(-100%);
    transition: transform 0.5s ease;
  }

  .action-btn:hover:not(:disabled) {
    background: rgba(2, 132, 199, 0.3);
    border-color: rgba(2, 132, 199, 0.6);
    box-shadow: 0 0 20px rgba(2, 132, 199, 0.2);
    transform: translateY(-2px);
  }

  .action-btn:hover:not(:disabled)::before {
    transform: translateX(100%);
  }

  .action-btn:active:not(:disabled) {
    transform: translateY(1px);
  }

  .action-btn.scanning {
    background: var(--term-accent-dim);
    border-color: var(--term-accent);
    color: var(--term-accent);
    cursor: wait;
  }

  .action-btn.verified {
    background: rgba(52, 211, 153, 0.15);
    border-color: #34d399;
    color: #34d399;
  }

  .btn-icon {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    width: calc(48px * var(--mdt-scale, 1));
    height: calc(36px * var(--mdt-scale, 1));
    color: #d9f1ff;
  }

  .btn-icon :global(svg) {
    display: block;
    flex-shrink: 0;
  }

  .btn-text {
    text-align: center;
    font-size: calc(13px * var(--mdt-scale, 1));
    font-weight: 600;
    letter-spacing: 0.15em;
  }

  .btn-arrow {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    width: calc(44px * var(--mdt-scale, 1));
    color: rgba(186, 230, 253, 0.78);
    transition: transform 0.3s ease;
  }

  .btn-arrow :global(svg) {
    display: block;
    flex-shrink: 0;
  }

  .action-btn:hover:not(:disabled) .btn-arrow {
    transform: translateX(4px);
  }
</style>
