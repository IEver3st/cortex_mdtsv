<script>
  import { onMount } from 'svelte';
  import { Sparkles, UserRound, ChevronRight, Fingerprint, Check } from '@lucide/svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import SelfRegister from '../components/SelfRegister.svelte';
  import PortalRippleBackdrop from '../components/PortalRippleBackdrop.svelte';

  const ACCESS_GHOST_LEN = 12;
  const ACCESS_TICK_MS = 95;

  let loading = $state(true);
  let generating = $state(false);
  let showSelfRegister = $state(false);
  let introComplete = $state(false);
  let accessGhost = $state('');
  let bioPhase = $state('idle');
  let biometricError = $state('');

  let standaloneState = $derived(dataStore.standaloneCivilianState);
  let portalCitizens = $derived(dataStore.standaloneCitizens);
  let hasRestorableCivilian = $derived(
    portalCitizens.some((c) => c.claimed === true && c.isOwner === true) ||
      !!standaloneState.activeCitizenId,
  );

  const citySeal = `${import.meta.env.BASE_URL}LosSantosSeal.webp`;

  let usernameLine = $derived(
    (mdtStore.gameUsername || '').trim() || '—',
  );

  onMount(() => {
    const run = async () => {
      loading = true;
      await dataStore.fetchStandaloneCivilianState();
      loading = false;
    };
    void run();

    const filler = '·'.repeat(ACCESS_GHOST_LEN);
    let i = 0;
    const id = setInterval(() => {
      i += 1;
      accessGhost = filler.slice(0, i);
      if (i >= ACCESS_GHOST_LEN) {
        clearInterval(id);
        introComplete = true;
      }
    }, ACCESS_TICK_MS);
    return () => clearInterval(id);
  });

  async function handleGenerate() {
    if (generating || standaloneState.standaloneEnabled === false || !introComplete) return;
    generating = true;
    const response = await dataStore.generateStandaloneCivilian();
    generating = false;

    if (response?.ok && response.citizen?.citizenId) {
      await handleEnter(response.citizen.citizenId);
    }
  }

  async function handleEnter(citizenId) {
    const response = await dataStore.claimStandaloneCivilian(citizenId);
    if (response?.ok) {
      mdtStore.login();
    }
  }

  async function handleSelfRegisterSuccess(citizen) {
    if (citizen?.citizenId) {
      await handleEnter(citizen.citizenId);
    }
  }

  async function handleBiometric() {
    if (bioPhase !== 'idle' || !introComplete || standaloneState.standaloneEnabled === false) return;

    biometricError = '';
    bioPhase = 'scanning';
    await new Promise((r) => setTimeout(r, 1800));

    await dataStore.fetchStandaloneCivilianState();

    const citizens = dataStore.standaloneCitizens;
    const activeId = dataStore.standaloneCivilianState.activeCitizenId;
    let row =
      activeId &&
      citizens.find(
        (c) => (c.citizenId === activeId || c.citizen_id === activeId) && c.claimed && c.isOwner,
      );
    if (!row) {
      row = citizens.find((c) => c.claimed === true && c.isOwner === true) || null;
    }

    if (!row?.citizenId) {
      bioPhase = 'idle';
      biometricError = 'No claimed civilian found. Generate or self-register.';
      return;
    }

    if (!mdtStore.civilian?.citizenId) {
      mdtStore.civilian = { ...mdtStore.civilian, ...row };
    }

    bioPhase = 'verified';
    await new Promise((r) => setTimeout(r, 600));
    mdtStore.login();
    bioPhase = 'idle';
  }
</script>

<div class="login-root">
  <PortalRippleBackdrop layout="diagonal" seed={0x636976696c} />
  <div class="terminal-modal">
    <div class="modal-header">
      <div class="badge-glow-wrap">
        <img src={citySeal} alt="City of Los Santos seal" class="dept-badge dept-badge--seal" />
      </div>

      <div class="title-section">
        <div class="dept-pill font-mono">CIVILIAN SERVICES</div>
        <h1 class="main-title font-mono">CIVILIAN PORTAL</h1>
      </div>
    </div>

    <div class="terminal-rule"></div>

    <div class="inputs-section font-mono">
      <div class="input-group">
        <label class="input-label" for="civilian-username">USERNAME</label>
        <div class="input-wrapper">
          <input
            id="civilian-username"
            type="text"
            class="terminal-input"
            value={usernameLine}
            readonly
          />
        </div>
      </div>

      <div class="input-group">
        <label class="input-label" for="access-line">ACCESS</label>
        <div class="input-wrapper">
          <input
            id="access-line"
            type="password"
            class="terminal-input"
            bind:value={accessGhost}
            readonly
            autocomplete="off"
          />
        </div>
      </div>
    </div>

    {#if standaloneState.standaloneEnabled === false && !loading}
      <div class="status-indicator status-indicator-error font-mono">
        <span class="status-text text-error">{standaloneState.error || 'Standalone civilian portal requires framework mode `standalone`.'}</span>
      </div>
    {/if}

    {#if bioPhase !== 'idle'}
      <div class="status-indicator font-mono">
        <span class="status-dot" class:dot-scanning={bioPhase === 'scanning'} class:dot-verified={bioPhase === 'verified'}></span>
        {#if bioPhase === 'scanning'}
          <span class="status-text text-scanning">SCANNING BIOMETRICS...</span>
        {:else if bioPhase === 'verified'}
          <span class="status-text text-verified">ACCESS GRANTED</span>
        {/if}
      </div>
    {/if}

    {#if biometricError}
      <div class="status-indicator status-indicator-error font-mono">
        <span class="status-text text-error">{biometricError}</span>
      </div>
    {/if}

    <button
      type="button"
      class="action-btn font-mono"
      class:action-btn--locked={loading ||
        standaloneState.standaloneEnabled === false ||
        !introComplete ||
        !hasRestorableCivilian ||
        bioPhase !== 'idle'}
      class:scanning={bioPhase === 'scanning'}
      class:verified={bioPhase === 'verified'}
      onclick={handleBiometric}
      disabled={loading ||
        standaloneState.standaloneEnabled === false ||
        !introComplete ||
        !hasRestorableCivilian ||
        bioPhase !== 'idle'}
    >
      <div class="btn-icon">
        {#if bioPhase === 'verified'}
          <Check size={22} strokeWidth={2.35} />
        {:else}
          <Fingerprint size={34} strokeWidth={1.75} />
        {/if}
      </div>
      <span class="btn-text">
        {#if bioPhase === 'idle'}
          LOG IN WITH BIOMETRICS
        {:else if bioPhase === 'scanning'}
          VERIFYING IDENTITY
        {:else}
          ESTABLISHING SESSION
        {/if}
      </span>
      <div class="btn-arrow">
        <ChevronRight size={16} strokeWidth={2.1} />
      </div>
    </button>

    <div
      class="action-split"
      class:action-split--locked={loading || standaloneState.standaloneEnabled === false || !introComplete || bioPhase !== 'idle'}
    >
      <button
        type="button"
        class="split-btn split-btn--left"
        onclick={handleGenerate}
        disabled={loading ||
          standaloneState.standaloneEnabled === false ||
          !introComplete ||
          generating ||
          bioPhase !== 'idle'}
      >
        <span class="split-btn-icon" aria-hidden="true">
          <Sparkles size={22} strokeWidth={1.85} />
        </span>
        <span class="split-btn-label">{generating ? 'GENERATING…' : 'NEW CIVILIAN'}</span>
      </button>
      <span class="split-divider" aria-hidden="true"></span>
      <button
        type="button"
        class="split-btn split-btn--right"
        onclick={() => {
          showSelfRegister = true;
        }}
        disabled={loading ||
          standaloneState.standaloneEnabled === false ||
          !introComplete ||
          bioPhase !== 'idle'}
      >
        <span class="split-btn-icon" aria-hidden="true">
          <UserRound size={24} strokeWidth={1.75} />
        </span>
        <span class="split-btn-label">SELF REGISTER</span>
      </button>
    </div>

    <div class="modal-footer font-mono"></div>
  </div>
</div>

{#if showSelfRegister}
  <SelfRegister onClose={() => (showSelfRegister = false)} onSuccess={handleSelfRegisterSuccess} />
{/if}

<style>
  /* ── Root (matches officer Login.svelte) ───────────────────────── */
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
    from {
      opacity: 0;
      transform: scale(0.95) translateY(20px);
    }
    to {
      opacity: 1;
      transform: scale(1) translateY(0);
    }
  }

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
    0%,
    100% {
      transform: translateY(0);
    }
    50% {
      transform: translateY(-5px);
    }
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

  .terminal-rule {
    width: 100%;
    height: 1px;
    background: linear-gradient(
      90deg,
      transparent,
      var(--term-border) 20%,
      var(--term-accent) 50%,
      var(--term-border) 80%,
      transparent
    );
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

  .inputs-section {
    display: flex;
    flex-direction: column;
    gap: calc(20px * var(--mdt-scale, 1));
    margin-bottom: calc(24px * var(--mdt-scale, 1));
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

  .status-indicator {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: calc(10px * var(--mdt-scale, 1));
    margin-bottom: calc(16px * var(--mdt-scale, 1));
  }

  .status-indicator-error {
    margin-top: calc(-8px * var(--mdt-scale, 1));
    margin-bottom: calc(18px * var(--mdt-scale, 1));
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
    animation: bioBlink 0.5s infinite alternate;
  }

  .status-dot.dot-verified {
    background: #34d399;
    opacity: 1;
    box-shadow: 0 0 10px rgba(52, 211, 153, 0.5);
  }

  @keyframes bioBlink {
    from {
      opacity: 0.5;
    }
    to {
      opacity: 1;
    }
  }

  .status-text {
    font-size: calc(11px * var(--mdt-scale, 1));
    letter-spacing: 0.12em;
  }

  .text-scanning {
    color: var(--term-accent);
    animation: bioBlink 0.5s infinite alternate;
    letter-spacing: 0.2em;
  }

  .text-verified {
    color: #34d399;
    letter-spacing: 0.2em;
  }

  .text-error {
    color: #fca5a5;
    letter-spacing: 0.06em;
    text-align: center;
    line-height: 1.45;
  }

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
    font-family: inherit;
  }

  .action-btn + .action-split {
    margin-top: calc(12px * var(--mdt-scale, 1));
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

  .action-split {
    display: flex;
    flex-direction: row;
    align-items: stretch;
    width: 100%;
    border-radius: calc(6px * var(--mdt-scale, 1));
    overflow: hidden;
    border: 1px solid rgba(2, 132, 199, 0.4);
    background: rgba(2, 132, 199, 0.2);
    box-shadow: none;
  }

  .action-split--locked {
    opacity: 0.55;
    pointer-events: none;
  }

  .split-divider {
    width: 1px;
    flex-shrink: 0;
    background: rgba(2, 132, 199, 0.35);
  }

  .split-btn {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(6px * var(--mdt-scale, 1));
    padding: calc(14px * var(--mdt-scale, 1)) calc(10px * var(--mdt-scale, 1));
    border: none;
    background: transparent;
    color: #bae6fd;
    cursor: pointer;
    font-family: inherit;
    transition: background 0.2s ease, color 0.2s ease;
  }

  .split-btn:hover:not(:disabled) {
    background: rgba(2, 132, 199, 0.3);
    color: #e0f2fe;
  }

  .split-btn:disabled {
    color: #6b7280;
    cursor: not-allowed;
  }

  .split-btn-icon {
    display: flex;
    color: rgba(186, 230, 253, 0.9);
  }

  .split-btn:disabled .split-btn-icon {
    color: #6b7280;
  }

  .split-btn-label {
    font-size: calc(12px * var(--mdt-scale, 1));
    font-weight: 600;
    letter-spacing: 0.12em;
    text-align: center;
    line-height: 1.25;
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

  .modal-footer {
    margin-top: calc(40px * var(--mdt-scale, 1));
    font-size: 0;
    color: var(--term-text-muted);
    text-align: center;
    letter-spacing: 0.4em;
    opacity: 0.4;
    text-transform: uppercase;
  }

  .modal-footer::before {
    content: 'ENCRYPTED CONNECTION • CITY OF LOS SANTOS';
    font-size: calc(9px * var(--mdt-scale, 1));
  }
</style>
