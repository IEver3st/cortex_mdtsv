<script>
  import { onMount } from 'svelte';
  import { UserRoundPlus, ChevronRight, BadgeCheck, Sparkles, Trash2 } from 'lucide-svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { dataStore } from '../lib/stores/data.svelte.js';

  let loading = $state(true);
  let generating = $state(false);
  let busyCitizenId = $state(null);
  let standaloneState = $derived(dataStore.standaloneCivilianState);
  let personas = $derived(dataStore.standaloneCitizens || []);

  const citySeal = `${import.meta.env.BASE_URL}LosSantosSeal.webp`;

  onMount(async () => {
    loading = true;
    await dataStore.fetchStandaloneCivilianState();
    loading = false;
  });

  async function handleGenerate() {
    generating = true;
    const response = await dataStore.generateStandaloneCivilian();
    generating = false;

    if (response?.ok && response.citizen?.citizenId) {
      await handleEnter(response.citizen.citizenId);
    }
  }

  async function handleEnter(citizenId) {
    busyCitizenId = citizenId;
    const response = await dataStore.claimStandaloneCivilian(citizenId);
    busyCitizenId = null;

    if (response?.ok) {
      mdtStore.login();
    }
  }

  async function handleDelete(citizenId) {
    if (!window.confirm('Delete this standalone civilian from the current server session?')) {
      return;
    }

    busyCitizenId = citizenId;
    await dataStore.deleteStandaloneCivilian(citizenId);
    busyCitizenId = null;
  }

  function buttonLabel(persona) {
    if (busyCitizenId === persona.citizenId) {
      return 'Applying...';
    }

    if (persona.isActive) {
      return 'Enter MDT';
    }

    if (persona.isOwner) {
      return 'Use Civilian';
    }

    return 'Claim & Enter';
  }

  function hasDeleteAccess(persona) {
    return persona.isOwner || persona.claimed === false;
  }

  function formatMeta(persona) {
    return [persona.dateOfBirth, persona.occupation, persona.phone].filter(Boolean).join(' | ');
  }
</script>

<div class="login-root">
  <div class="bg-wash" aria-hidden="true"></div>
  <div class="grid-overlay" aria-hidden="true"></div>
  <div class="vignette" aria-hidden="true"></div>

  <div class="terminal-modal persona-modal">
    <div class="seal-ring-wrap">
      <div class="seal-ring">
        <div class="seal-ring-track"></div>
        <div class="seal-ring-glow ring-active"></div>
      </div>
      <img src={citySeal} alt="City of Los Santos seal" class="city-seal" />
    </div>

    <div class="title-block">
      <div class="city-label font-mono">CITY OF LOS SANTOS</div>
      <h1 class="main-title">Civilian Intake</h1>
      <h2 class="sub-title font-mono">STANDALONE ROLEPLAY PERSONAS</h2>
    </div>

    <div class="divider-wrap">
      <div class="divider-line"></div>
      <div class="divider-diamond"></div>
      <div class="divider-line"></div>
    </div>

    <div class="info-strip font-mono">
      <div class="info-item">
        <span class="info-dot"></span>
        <span>SESSION SCOPED</span>
      </div>
      <div class="info-sep"></div>
      <div class="info-item">
        <span class="info-dot info-dot-warn"></span>
        <span>{standaloneState.standaloneEnabled === false ? 'STANDALONE MODE REQUIRED' : 'GENERATE, CLAIM, ENTER'}</span>
      </div>
    </div>

    {#if loading}
      <div class="status-message font-mono">LOADING PERSONAS...</div>
    {:else if standaloneState.standaloneEnabled === false}
      <div class="disabled-state">
        <p class="disabled-copy">Standalone civilian management is only available when the MDT framework mode resolves to `standalone`.</p>
        <div class="auth-btn">
          <div class="btn-icon-wrap">
            <BadgeCheck size={22} strokeWidth={1.8} />
          </div>
          <span class="btn-label">STANDALONE DISABLED</span>
          <div class="btn-chevron">
            <ChevronRight size={16} strokeWidth={2} />
          </div>
        </div>
      </div>
    {:else}
      <div class="persona-actions">
        <button class="auth-btn" onclick={handleGenerate} disabled={generating}>
          <div class="btn-icon-wrap">
            <Sparkles size={22} strokeWidth={1.8} />
          </div>
          <span class="btn-label">{generating ? 'GENERATING CIVILIAN...' : 'GENERATE NEW CIVILIAN'}</span>
          <div class="btn-chevron">
            <ChevronRight size={16} strokeWidth={2} />
          </div>
        </button>
      </div>

      <div class="persona-list">
        {#if personas.length === 0}
          <div class="empty-persona">
            <UserRoundPlus size={30} strokeWidth={1.5} />
            <span>Create a civilian to enter the standalone MDT.</span>
          </div>
        {:else}
          {#each personas as persona (persona.citizenId)}
            <div class="persona-card">
              <div class="persona-copy">
                <div class="persona-top">
                  <div>
                    <h3 class="persona-name">{persona.fullName}</h3>
                    <span class="persona-id font-mono">{persona.citizenId}</span>
                  </div>
                  <span class="persona-status font-mono" class:persona-status-active={persona.isActive}>
                    {persona.isActive ? 'ACTIVE' : persona.claimed ? 'CLAIMED' : 'READY'}
                  </span>
                </div>
                <span class="persona-meta font-mono">{formatMeta(persona)}</span>
                <span class="persona-address">{persona.address}</span>
              </div>
              <div class="persona-buttons">
                <button class="persona-enter" onclick={() => handleEnter(persona.citizenId)} disabled={busyCitizenId === persona.citizenId}>
                  {buttonLabel(persona)}
                </button>
                {#if hasDeleteAccess(persona)}
                  <button class="persona-delete" onclick={() => handleDelete(persona.citizenId)} disabled={busyCitizenId === persona.citizenId}>
                    <Trash2 size={14} strokeWidth={1.8} />
                  </button>
                {/if}
              </div>
            </div>
          {/each}
        {/if}
      </div>
    {/if}

    <div class="footer-row font-mono">
      <span>LOS SANTOS MUNICIPAL GOVERNMENT</span>
      <span class="footer-sep">|</span>
      <span>SESSION-LIMITED IDENTITIES</span>
    </div>
  </div>
</div>

<style>
  .login-root {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #06080c;
    overflow: hidden;
    animation: civEnter 0.7s cubic-bezier(0.16, 1, 0.3, 1) forwards;

    --civ-gold: #c9a84c;
    --civ-gold-dim: rgba(201, 168, 76, 0.12);
    --civ-gold-glow: rgba(201, 168, 76, 0.35);
    --civ-cream: #f0e6d0;
    --civ-slate: #8b9bb4;
    --civ-surface: rgba(12, 15, 22, 0.94);
    --civ-border: rgba(201, 168, 76, 0.15);
    --civ-text: #d4d8e0;
    --civ-text-muted: #6b7a90;
  }

  @keyframes civEnter {
    from { opacity: 0; transform: scale(0.94) translateY(24px); }
    to { opacity: 1; transform: scale(1) translateY(0); }
  }

  .bg-wash {
    position: absolute;
    inset: 0;
    background:
      radial-gradient(ellipse 80% 60% at 50% 30%, rgba(201, 168, 76, 0.06) 0%, transparent 70%),
      radial-gradient(ellipse 60% 40% at 50% 80%, rgba(100, 120, 160, 0.04) 0%, transparent 60%);
    pointer-events: none;
  }

  .grid-overlay {
    position: absolute;
    inset: 0;
    background-image:
      linear-gradient(rgba(201, 168, 76, 0.02) 1px, transparent 1px),
      linear-gradient(90deg, rgba(201, 168, 76, 0.02) 1px, transparent 1px);
    background-size: 40px 40px;
    mask-image: radial-gradient(ellipse 70% 60% at 50% 50%, black 20%, transparent 80%);
    pointer-events: none;
  }

  .vignette {
    position: absolute;
    inset: 0;
    background: radial-gradient(ellipse 80% 70% at 50% 50%, transparent 30%, rgba(6, 8, 12, 0.7) 100%);
    pointer-events: none;
  }

  .terminal-modal {
    position: relative;
    z-index: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    background: var(--civ-surface);
    border: 1px solid var(--civ-border);
    border-radius: calc(12px * var(--mdt-scale, 1));
    padding: calc(52px * var(--mdt-scale, 1)) calc(44px * var(--mdt-scale, 1)) calc(36px * var(--mdt-scale, 1));
    box-shadow:
      0 0 60px rgba(201, 168, 76, 0.06),
      0 30px 80px rgba(0, 0, 0, 0.6),
      inset 0 1px 0 rgba(201, 168, 76, 0.08);
  }

  .persona-modal {
    width: calc(620px * var(--mdt-scale, 1));
    max-height: calc(860px * var(--mdt-scale, 1));
    overflow: hidden;
  }

  .seal-ring-wrap {
    position: relative;
    width: calc(120px * var(--mdt-scale, 1));
    height: calc(120px * var(--mdt-scale, 1));
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: calc(28px * var(--mdt-scale, 1));
  }

  .seal-ring {
    position: absolute;
    inset: calc(-6px * var(--mdt-scale, 1));
    border-radius: 50%;
    overflow: hidden;
  }

  .seal-ring-track {
    position: absolute;
    inset: 0;
    border: calc(2px * var(--mdt-scale, 1)) solid rgba(201, 168, 76, 0.15);
    border-radius: 50%;
  }

  .seal-ring-glow {
    position: absolute;
    inset: calc(-2px * var(--mdt-scale, 1));
    border: calc(3px * var(--mdt-scale, 1)) solid transparent;
    border-top-color: var(--civ-gold);
    border-radius: 50%;
    opacity: 1;
    animation: ringRotate 1.2s linear infinite;
    filter: drop-shadow(0 0 8px rgba(201, 168, 76, 0.35));
  }

  @keyframes ringRotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .city-seal {
    position: relative;
    z-index: 2;
    width: calc(100px * var(--mdt-scale, 1));
    height: calc(100px * var(--mdt-scale, 1));
    object-fit: contain;
    filter: drop-shadow(0 0 16px rgba(201, 168, 76, 0.2));
    animation: sealFloat 7s ease-in-out infinite;
  }

  @keyframes sealFloat {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(calc(-4px * var(--mdt-scale, 1))); }
  }

  .title-block {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(8px * var(--mdt-scale, 1));
    text-align: center;
  }

  .city-label {
    font-size: calc(10px * var(--mdt-scale, 1));
    font-weight: 700;
    letter-spacing: 0.4em;
    color: var(--civ-gold);
    text-transform: uppercase;
    opacity: 0.85;
  }

  .main-title {
    font-size: calc(38px * var(--mdt-scale, 1));
    font-weight: 300;
    color: var(--civ-cream);
    letter-spacing: 0.08em;
    margin: 0;
    line-height: 1;
  }

  .sub-title {
    font-size: calc(11px * var(--mdt-scale, 1));
    color: var(--civ-slate);
    letter-spacing: 0.35em;
    margin: 0;
    opacity: 0.7;
  }

  .divider-wrap {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale, 1));
    width: 100%;
    margin: calc(30px * var(--mdt-scale, 1)) 0;
  }

  .divider-line {
    flex: 1;
    height: 1px;
    background: linear-gradient(90deg, transparent, var(--civ-border), transparent);
  }

  .divider-diamond {
    width: calc(8px * var(--mdt-scale, 1));
    height: calc(8px * var(--mdt-scale, 1));
    background: var(--civ-gold);
    transform: rotate(45deg);
    opacity: 0.5;
    box-shadow: 0 0 8px rgba(201, 168, 76, 0.35);
  }

  .info-strip {
    display: flex;
    align-items: center;
    gap: calc(14px * var(--mdt-scale, 1));
    margin-bottom: calc(22px * var(--mdt-scale, 1));
    font-size: calc(9.5px * var(--mdt-scale, 1));
    letter-spacing: 0.12em;
    color: var(--civ-text-muted);
  }

  .info-item {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale, 1));
  }

  .info-dot {
    width: calc(6px * var(--mdt-scale, 1));
    height: calc(6px * var(--mdt-scale, 1));
    border-radius: 50%;
    background: #34d399;
    box-shadow: 0 0 6px rgba(52, 211, 153, 0.5);
  }

  .info-dot-warn {
    background: var(--civ-gold);
    box-shadow: 0 0 6px rgba(201, 168, 76, 0.35);
    animation: dotPulse 2s ease-in-out infinite;
  }

  @keyframes dotPulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  .info-sep {
    width: 1px;
    height: calc(12px * var(--mdt-scale, 1));
    background: rgba(201, 168, 76, 0.15);
  }

  .status-message {
    margin-bottom: calc(16px * var(--mdt-scale, 1));
    color: var(--civ-gold);
    letter-spacing: 0.18em;
  }

  .persona-actions {
    width: 100%;
    margin-bottom: calc(18px * var(--mdt-scale, 1));
  }

  .auth-btn,
  .persona-enter,
  .persona-delete {
    border-radius: calc(999px * var(--mdt-scale, 1));
    font-family: inherit;
    font-size: calc(10.5px * var(--mdt-scale, 1));
    font-weight: 700;
    letter-spacing: 0.08em;
    cursor: pointer;
    transition: transform 0.18s ease, opacity 0.18s ease;
  }

  .auth-btn {
    width: 100%;
    display: grid;
    grid-template-columns: calc(48px * var(--mdt-scale, 1)) 1fr calc(40px * var(--mdt-scale, 1));
    align-items: center;
    background: rgba(201, 168, 76, 0.12);
    border: 1px solid rgba(201, 168, 76, 0.25);
    color: var(--civ-cream);
    padding: calc(16px * var(--mdt-scale, 1)) calc(20px * var(--mdt-scale, 1));
  }

  .auth-btn:hover:enabled,
  .persona-enter:hover:enabled,
  .persona-delete:hover:enabled {
    transform: translateY(calc(-1px * var(--mdt-scale, 1)));
  }

  .auth-btn:disabled,
  .persona-enter:disabled,
  .persona-delete:disabled {
    opacity: 0.55;
    cursor: wait;
  }

  .btn-icon-wrap {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    color: var(--civ-gold);
  }

  .btn-label {
    text-align: center;
    font-size: calc(12px * var(--mdt-scale, 1));
    font-weight: 600;
    letter-spacing: 0.15em;
  }

  .btn-chevron {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    color: rgba(201, 168, 76, 0.5);
  }

  .persona-list {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale, 1));
    max-height: calc(340px * var(--mdt-scale, 1));
    overflow-y: auto;
    padding-right: calc(4px * var(--mdt-scale, 1));
  }

  .persona-card {
    display: flex;
    align-items: center;
    gap: calc(14px * var(--mdt-scale, 1));
    padding: calc(14px * var(--mdt-scale, 1));
    border-radius: calc(10px * var(--mdt-scale, 1));
    border: 1px solid rgba(201, 168, 76, 0.14);
    background: rgba(255, 255, 255, 0.02);
  }

  .persona-copy {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale, 1));
  }

  .persona-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale, 1));
  }

  .persona-name {
    font-size: calc(18px * var(--mdt-scale, 1));
    font-weight: 600;
    color: var(--civ-cream);
    margin: 0;
  }

  .persona-id {
    display: inline-block;
    margin-top: calc(2px * var(--mdt-scale, 1));
    color: var(--civ-gold);
    font-size: calc(10px * var(--mdt-scale, 1));
    letter-spacing: 0.1em;
  }

  .persona-status {
    padding: calc(4px * var(--mdt-scale, 1)) calc(8px * var(--mdt-scale, 1));
    border-radius: calc(999px * var(--mdt-scale, 1));
    background: rgba(201, 168, 76, 0.12);
    color: var(--civ-gold);
    font-size: calc(9px * var(--mdt-scale, 1));
    letter-spacing: 0.12em;
    flex-shrink: 0;
  }

  .persona-status-active {
    background: rgba(52, 211, 153, 0.12);
    color: #34d399;
  }

  .persona-meta {
    color: var(--civ-slate);
    font-size: calc(9.5px * var(--mdt-scale, 1));
    letter-spacing: 0.1em;
  }

  .persona-address {
    color: var(--civ-text);
    font-size: calc(12px * var(--mdt-scale, 1));
    opacity: 0.82;
  }

  .persona-buttons {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale, 1));
  }

  .persona-enter {
    border: 1px solid rgba(201, 168, 76, 0.28);
    background: rgba(201, 168, 76, 0.12);
    color: var(--civ-cream);
    padding: calc(10px * var(--mdt-scale, 1)) calc(14px * var(--mdt-scale, 1));
  }

  .persona-delete {
    border: 1px solid rgba(248, 113, 113, 0.24);
    background: rgba(248, 113, 113, 0.08);
    color: #f87171;
    width: calc(36px * var(--mdt-scale, 1));
    height: calc(36px * var(--mdt-scale, 1));
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0;
  }

  .empty-persona,
  .disabled-state {
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(12px * var(--mdt-scale, 1));
    padding: calc(24px * var(--mdt-scale, 1));
    border-radius: calc(10px * var(--mdt-scale, 1));
    border: 1px dashed rgba(201, 168, 76, 0.18);
    color: var(--civ-text-muted);
    text-align: center;
  }

  .disabled-copy {
    margin: 0 0 calc(6px * var(--mdt-scale, 1));
    color: var(--civ-text);
    line-height: 1.5;
  }

  .footer-row {
    margin-top: calc(32px * var(--mdt-scale, 1));
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale, 1));
    font-size: calc(8.5px * var(--mdt-scale, 1));
    letter-spacing: 0.35em;
    color: var(--civ-text-muted);
    opacity: 0.4;
    text-transform: uppercase;
  }

  .footer-sep {
    opacity: 0.3;
  }
</style>
