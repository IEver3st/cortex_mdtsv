<script>
  import { onDestroy, onMount } from 'svelte';
  import {
    Video,
    Search,
    RefreshCw,
    Eye,
    Volume2,
    VolumeX,
    Radio,
    VideoOff,
    Users,
  } from '@lucide/svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';

  let loading = $state(true);
  let busy = $state(false);
  let mode = $state('list');
  let errorMessage = $state('');
  let refreshHandle = null;
  let previewCacheBust = $state(0);

  const PREVIEW_POLL_MIN_MS = 120_000;
  const PREVIEW_POLL_MAX_MS = 180_000;
  let audioEnabled = $state({});
  let searchQuery = $state('');
  let filterDept = $state('all');

  let bodycams = $derived(dataStore.bodycamsList || []);
  let activeBodycam = $derived(dataStore.activeBodycamFeed);
  let officer = $derived(mdtStore.officer);

  let filteredBodycams = $derived.by(() => {
    let list = bodycams;
    if (filterDept !== 'all') {
      list = list.filter((b) => (b.department || '').toLowerCase() === filterDept);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      list = list.filter(
        (b) =>
          (b.name || '').toLowerCase().includes(q) ||
          (b.callsign || '').toLowerCase().includes(q) ||
          (b.rank || '').toLowerCase().includes(q),
      );
    }
    return list;
  });

  let departments = $derived.by(() => {
    const depts = new Set();
    bodycams.forEach((b) => {
      if (b.department) depts.add(b.department.toLowerCase());
    });
    return [...depts].sort();
  });

  let myBodycam = $derived.by(() => {
    return bodycams.find(
      (b) =>
        b.callsign === officer.callsign ||
        b.name === `${officer.firstName} ${officer.lastName}`,
    );
  });

  let totalViewers = $derived(
    bodycams.reduce((n, b) => n + (Number(b.viewerCount) || 0), 0),
  );

  let liveLocation = $derived(dataStore.bodycamLiveLocation || '');
  let feedClock = $state('');

  $effect(() => {
    if (mode !== 'feed') {
      return;
    }
    const tick = () => {
      feedClock = new Date().toLocaleString('en-US', {
        hour12: false,
        month: '2-digit',
        day: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      });
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  });

  $effect(() => {
    if (mode === 'feed' && !activeBodycam) {
      mode = 'list';
    }
  });

  async function loadBodycams() {
    const resp = await dataStore.fetchBodycams();
    if (!resp?.ok) {
      errorMessage = resp?.error || 'Failed to load bodycams.';
    } else {
      previewCacheBust = Date.now();
    }
    return resp;
  }

  function pickPollDelay() {
    return PREVIEW_POLL_MIN_MS + Math.random() * (PREVIEW_POLL_MAX_MS - PREVIEW_POLL_MIN_MS);
  }

  function scheduleBodycamPoll() {
    refreshHandle = setTimeout(async () => {
      const resp = await dataStore.fetchBodycams();
      if (resp?.ok) previewCacheBust = Date.now();
      scheduleBodycamPoll();
    }, pickPollDelay());
  }

  onMount(async () => {
    loading = true;
    errorMessage = '';
    await loadBodycams();
    loading = false;
    scheduleBodycamPoll();
  });

  onDestroy(() => {
    if (refreshHandle) {
      clearTimeout(refreshHandle);
    }
    dataStore.stopCameraView();
  });

  async function viewBodycam(source) {
    busy = true;
    errorMessage = '';

    const resp = await dataStore.viewBodycam(source);
    if (resp?.ok) {
      mode = 'feed';
    } else {
      errorMessage = resp?.error || 'Unable to open bodycam feed.';
    }

    busy = false;
  }

  async function backToList() {
    busy = true;
    await dataStore.stopCameraView();
    mode = 'list';
    busy = false;
  }

  async function toggleAudio(source) {
    const next = !audioEnabled[source];
    audioEnabled = { ...audioEnabled, [source]: next };
    await dataStore.setBodycamAudio(next);
  }

  function isOwnFeed(bodycam) {
    return (
      bodycam.callsign === officer.callsign ||
      bodycam.name === `${officer.firstName} ${officer.lastName}`
    );
  }

  function nameInitials(name) {
    const parts = (name || '').trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) return '?';
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  function previewSrc(url) {
    if (!url) return '';
    const sep = url.includes('?') ? '&' : '?';
    return `${url}${sep}mdtprev=${previewCacheBust}`;
  }

  function clearSearch() {
    searchQuery = '';
  }
</script>

<div class="bc-page" class:feed-live={mode === 'feed'}>
  {#if errorMessage && mode === 'feed'}
    <div class="bc-error bc-error-float" role="alert">{errorMessage}</div>
  {/if}
  {#if mode === 'list'}
    <section class="bc-shell" aria-label="Bodycam channels">
      <header class="bc-toolbar">
        <div class="bc-toolbar-r1">
          <div class="bc-eyebrow">
            <Video size={13} strokeWidth={2} />
            <span>Field ops</span>
          </div>
          <label class="bc-field-label" for="bc-search-input">Find officer</label>
        </div>
        <div class="bc-toolbar-r2">
          <div class="bc-toolbar-lead">
            <h2 class="bc-h1">Bodycams</h2>
            <p class="bc-desc">
              Grid shows slow-refresh stills. <strong class="bc-desc-em">Watch live</strong> opens the in-world feed; pan
              WASD, zoom Q/E, reset R. Audio per card when live.
            </p>
          </div>
          <div class="bc-toolbar-search">
            <div class="bc-field">
              <span class="bc-field-ico" aria-hidden="true"><Search size={15} strokeWidth={2} /></span>
              <input
                id="bc-search-input"
                type="search"
                placeholder="Name, callsign, or rank"
                autocomplete="off"
                bind:value={searchQuery}
              />
              {#if searchQuery.trim()}
                <button type="button" class="bc-field-clear" onclick={clearSearch} aria-label="Clear search">
                  <span aria-hidden="true">×</span>
                </button>
              {/if}
            </div>
            <p class="bc-field-help">Filters the list below; stats row tracks active channels.</p>
          </div>
        </div>
      </header>

      <div class="bc-control-row">
        <div class="bc-stat-strip" aria-label="Summary">
          <div class="bc-stat">
            <span class="bc-stat-k"><Radio size={11} strokeWidth={2} /> Channels</span>
            <span class="bc-stat-n font-mono">{bodycams.length}</span>
          </div>
          <span class="bc-stat-div" aria-hidden="true"></span>
          <div class="bc-stat">
            <span class="bc-stat-k"><Eye size={11} strokeWidth={2} /> Filtered</span>
            <span class="bc-stat-n font-mono">{filteredBodycams.length}</span>
          </div>
          <span class="bc-stat-div" aria-hidden="true"></span>
          <div class="bc-stat">
            <span class="bc-stat-k"><Users size={11} strokeWidth={2} /> Watching</span>
            <span class="bc-stat-n font-mono">{totalViewers}</span>
          </div>
          {#if myBodycam}
            <span class="bc-stat-div" aria-hidden="true"></span>
            <button
              type="button"
              class="bc-my-feed"
              onclick={() => viewBodycam(myBodycam.source)}
              disabled={busy}
            >
              <span class="bc-my-dot" aria-hidden="true"></span>
              Open my bodycam
            </button>
          {/if}
        </div>

        <div class="bc-control-end">
          <span class="bc-field-label bc-dept-lbl" id="bc-dept-label">Department</span>
          <div class="bc-segment" role="group" aria-labelledby="bc-dept-label">
            <button
              type="button"
              class="bc-seg-btn"
              class:sel={filterDept === 'all'}
              onclick={() => (filterDept = 'all')}
            >
              All depts
            </button>
            {#each departments as dept (dept)}
              <button
                type="button"
                class="bc-seg-btn"
                class:sel={filterDept === dept}
                onclick={() => (filterDept = dept)}
              >
                {dept.toUpperCase()}
              </button>
            {/each}
          </div>
          <button
            type="button"
            class="bc-icon-btn"
            onclick={loadBodycams}
            disabled={loading || busy}
            title="Pull latest channels and preview frames"
            aria-label="Refresh channel list"
          >
            <span class="bc-refresh-ico" class:bc-spin={loading}>
              <RefreshCw size={16} strokeWidth={2} />
            </span>
          </button>
        </div>
      </div>

      {#if errorMessage}
        <div class="bc-error" role="alert">{errorMessage}</div>
      {/if}

      {#if loading}
        <div class="bc-grid bc-grid-skel" aria-busy="true" aria-label="Loading channels">
          {#each Array(6) as _, i (i)}
            <div class="bc-skel-card" style="--sk: {i}">
              <div class="bc-skel-preview"></div>
              <div class="bc-skel-body">
                <div class="bc-skel-av"></div>
                <div class="bc-skel-lines">
                  <div class="bc-skel-line w1"></div>
                  <div class="bc-skel-line w2"></div>
                </div>
              </div>
            </div>
          {/each}
        </div>
      {:else if filteredBodycams.length === 0}
        <div class="bc-empty" role="status">
          <div class="bc-empty-ico" aria-hidden="true"><VideoOff size={40} strokeWidth={1.25} /></div>
          <p class="bc-empty-title">No channels match</p>
          <p class="bc-empty-sub">
            {#if bodycams.length === 0}
              Units appear when on duty with bodycams enabled. Try refresh, or widen filters.
            {:else}
              Adjust search or department filters, or clear the search box.
            {/if}
          </p>
          {#if searchQuery.trim() || filterDept !== 'all'}
            <button type="button" class="bc-empty-reset" onclick={() => { clearSearch(); filterDept = 'all'; }}>
              Reset filters
            </button>
          {/if}
        </div>
      {:else}
        <section class="bc-grid" aria-label="Bodycam channels">
          {#each filteredBodycams as bodycam, i (bodycam.source)}
            {@const isOwn = isOwnFeed(bodycam)}
            {@const hasAudio = audioEnabled[bodycam.source]}
            <article class="bc-card" class:own={isOwn} style="--idx: {i}">
              <div class="bc-card-preview">
                {#if bodycam.avatar}
                  <img
                    class="bc-preview-img"
                    src={previewSrc(bodycam.avatar)}
                    alt=""
                    loading="lazy"
                    decoding="async"
                  />
                {:else}
                  <div class="bc-preview-fallback" style="--preview-h: {(Number(bodycam.source) || 0) * 47 % 360}">
                    <span class="bc-preview-initials font-mono">{nameInitials(bodycam.name)}</span>
                  </div>
                {/if}
                <div class="bc-preview-glass" aria-hidden="true"></div>
                <div class="bc-preview-top">
                  <span class="bc-cam-id font-mono">CAM {String(bodycam.source).padStart(3, '0')}</span>
                  <span class="bc-preview-pill">
                    <span class="bc-preview-dot" aria-hidden="true"></span>
                    Preview
                  </span>
                </div>
                <div class="bc-preview-mid">
                  <span class="bc-preview-callsign font-mono">{bodycam.callsign}</span>
                </div>
                <div class="bc-preview-bot">
                  <span class="bc-hud-muted font-mono">Still · ~2–3 min</span>
                  <span class="bc-hud-muted font-mono">{bodycam.viewerCount || 0} watching</span>
                </div>
              </div>

              <div class="bc-card-body">
                <div class="bc-officer">
                  <div class="bc-avatar">
                    {#if bodycam.avatar}
                      <img class="bc-avatar-img" src={bodycam.avatar} alt="" />
                    {:else}
                      <span class="bc-avatar-ix font-mono">{nameInitials(bodycam.name)}</span>
                    {/if}
                  </div>
                  <div class="bc-officer-text">
                    <div class="bc-name-row">
                      <span class="bc-name">{bodycam.name}</span>
                      {#if isOwn}
                        <span class="bc-you">You</span>
                      {/if}
                    </div>
                    <span class="bc-meta font-mono"
                      >{bodycam.rank} · {String(bodycam.department || '').toUpperCase()}</span
                    >
                  </div>
                </div>

                <div class="bc-card-actions">
                  <button
                    type="button"
                    class="bc-audio"
                    class:active={hasAudio}
                    onclick={() => toggleAudio(bodycam.source)}
                    title={hasAudio ? 'Mute audio for this channel' : 'Unmute audio for this channel'}
                    aria-label={hasAudio ? 'Mute audio for this channel' : 'Unmute audio for this channel'}
                    aria-pressed={hasAudio}
                  >
                    {#if hasAudio}
                      <Volume2 size={15} strokeWidth={2} />
                    {:else}
                      <VolumeX size={15} strokeWidth={2} />
                    {/if}
                  </button>
                  <button
                    type="button"
                    class="bc-btn-watch"
                    onclick={() => viewBodycam(bodycam.source)}
                    disabled={busy}
                  >
                    <Eye size={15} strokeWidth={2} />
                    Watch live
                  </button>
                </div>
                <p class="bc-card-foot">
                  Opens live view over the game world; use Exit (bottom) to return here.
                </p>
              </div>
            </article>
          {/each}
        </section>
      {/if}
    </section>
  {:else}
    <section class="bcam-immersive" aria-label="Bodycam feed">
      <div class="bcam-corners" aria-hidden="true">
        <span class="bcam-corner tl"></span>
        <span class="bcam-corner tr"></span>
        <span class="bcam-corner bl"></span>
        <span class="bcam-corner br"></span>
      </div>

      <header class="bcam-hud bcam-hud--tl" aria-label="Feed timestamp">
        <time class="bcam-ts-hud font-mono" datetime="">{feedClock}</time>
      </header>

      <header class="bcam-hud bcam-hud--tr" aria-label="Feed status">
        <div class="bcam-status">
          {#if activeBodycam}
            <span class="bcam-cam-id">BODYCAM {String(activeBodycam.source).padStart(3, '0')}</span>
          {:else}
            <span class="bcam-cam-id">BODYCAM ---</span>
          {/if}
          <span class="bcam-rec" aria-label="Recording active">
            <span class="bcam-rec-dot" aria-hidden="true"></span>
            REC
          </span>
        </div>
      </header>

      <div class="bcam-bottom-center">
        {#if activeBodycam}
          <div class="bcam-meta">
            <div class="bcam-meta-line">
              <span class="bcam-callsign font-mono">{activeBodycam.callsign}</span>
              <span class="bcam-name-inline">{activeBodycam.name}</span>
            </div>
            <div class="bcam-loc font-mono" title="Target officer position">{liveLocation || 'Locating…'}</div>
          </div>
        {/if}

        <div class="bcam-dock" aria-label="Live feed controls">
          <div class="bcam-dock-top">
            <button
              type="button"
              class="bcam-exit"
              onclick={() => backToList()}
              disabled={busy}
              title="Return to channel list"
            >
              Back to list
            </button>
            <p class="bcam-dock-lede">
              Camera rides on the officer feed below; audio toggle applies to this session only.
            </p>
          </div>
          <div class="bcam-key-section">
            <span class="bcam-section-label">Aim</span>
            <div class="bcam-keybar">
              <div class="bcam-key-group">
                <span class="bcam-klabel">Up / Down</span>
                <kbd class="bcam-k">W</kbd>
                <kbd class="bcam-k">S</kbd>
              </div>
              <div class="bcam-key-group">
                <span class="bcam-klabel">Left / Right</span>
                <kbd class="bcam-k">A</kbd>
                <kbd class="bcam-k">D</kbd>
              </div>
              <div class="bcam-key-group">
                <span class="bcam-klabel">Zoom</span>
                <kbd class="bcam-k">Q</kbd>
                <kbd class="bcam-k">E</kbd>
              </div>
              <div class="bcam-key-group">
                <span class="bcam-klabel">Reset view</span>
                <kbd class="bcam-k">R</kbd>
              </div>
            </div>
          </div>
          <div class="bcam-key-section">
            <span class="bcam-section-label">Speed</span>
            <div class="bcam-keybar bcam-keybar-compact">
              <div class="bcam-key-group">
                <span class="bcam-klabel">Faster pan</span>
                <kbd class="bcam-k bcam-k-wide">SHIFT</kbd>
              </div>
              <div class="bcam-key-group">
                <span class="bcam-klabel">Slower pan</span>
                <kbd class="bcam-k bcam-k-wide">CTRL</kbd>
              </div>
            </div>
          </div>
          <div class="bcam-dock-actions">
            {#if activeBodycam}
              <button
                type="button"
                class="bcam-audio"
                class:active={audioEnabled[activeBodycam.source]}
                onclick={() => toggleAudio(activeBodycam.source)}
                aria-pressed={!!audioEnabled[activeBodycam.source]}
              >
                {#if audioEnabled[activeBodycam.source]}
                  <Volume2 size={14} strokeWidth={2} />
                  On
                {:else}
                  <VolumeX size={14} strokeWidth={2} />
                  Off
                {/if}
              </button>
            {/if}
          </div>
        </div>
      </div>
    </section>
  {/if}
</div>

<style>
  /* Bodycams — aligned with Citizens registry: cp-page rhythm, tiered surfaces */
  .bc-page {
    --bc-ctl-h: calc(40px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    color: var(--mdt-text);
    flex: 1;
    min-height: 0;
    width: 100%;
    container-type: inline-size;
    container-name: bc-page;
    animation: bc-fade-in 0.32s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .bc-page.feed-live {
    padding: 0;
    gap: 0;
    background: transparent;
    overflow: hidden;
    animation: none;
  }

  .bc-shell {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
  }

  .bc-toolbar {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    padding-bottom: calc(16px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }

  .bc-toolbar-r1 {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(min(100%, calc(240px * var(--mdt-scale))), calc(360px * var(--mdt-scale)));
    gap: calc(12px * var(--mdt-scale)) calc(24px * var(--mdt-scale));
    align-items: end;
    min-width: 0;
  }

  .bc-toolbar-r1 .bc-field-label {
    margin: 0;
  }

  .bc-toolbar-r2 {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(min(100%, calc(240px * var(--mdt-scale))), calc(360px * var(--mdt-scale)));
    gap: calc(8px * var(--mdt-scale)) calc(24px * var(--mdt-scale));
    align-items: start;
    min-width: 0;
  }

  .bc-toolbar-lead {
    min-width: 0;
    padding-left: calc(12px * var(--mdt-scale));
    border-left: 2px solid color-mix(in srgb, var(--mdt-accent) 55%, transparent);
  }

  .bc-toolbar-search {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    min-width: 0;
  }

  .bc-eyebrow {
    display: inline-flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .bc-h1 {
    margin: 0;
    font-family: 'Unbounded', 'Outfit', system-ui, sans-serif;
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.03em;
    line-height: 1.15;
    color: var(--mdt-text);
  }

  .bc-desc {
    margin: calc(8px * var(--mdt-scale)) 0 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.55;
    color: var(--mdt-text-muted);
    max-width: 52ch;
  }

  .bc-desc-em {
    font-weight: 600;
    color: color-mix(in srgb, var(--mdt-accent) 82%, var(--mdt-text-dim));
  }

  .bc-field-label {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--mdt-text-dim);
  }

  .bc-field-help {
    margin: 0;
    font-size: calc(10px * var(--mdt-scale));
    line-height: 1.35;
    color: var(--mdt-text-muted);
  }

  .bc-field {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
  }

  .bc-field:focus-within {
    border-color: color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.06),
      0 0 0 1px color-mix(in srgb, var(--mdt-accent) 18%, transparent);
  }

  .bc-field-ico {
    display: flex;
    flex-shrink: 0;
    opacity: 0.85;
  }

  .bc-field input {
    flex: 1;
    min-width: 0;
    border: 0;
    outline: none;
    background: transparent;
    color: var(--mdt-text);
    font: inherit;
    font-size: calc(12px * var(--mdt-scale));
  }

  .bc-field-clear {
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
    font-size: calc(16px * var(--mdt-scale));
    line-height: 1;
  }

  .bc-field-clear:hover {
    color: var(--mdt-text);
    background: var(--mdt-surface-3);
  }

  .bc-control-row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    min-height: 0;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: calc(12px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: color-mix(in srgb, var(--mdt-surface) 92%, var(--mdt-bg));
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }

  .bc-stat-strip {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0;
    flex: 1;
    min-width: min(100%, calc(280px * var(--mdt-scale)));
  }

  .bc-stat {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: 0 calc(12px * var(--mdt-scale));
    min-width: 0;
  }

  .bc-stat:first-child {
    padding-left: 0;
  }

  .bc-stat-k {
    display: inline-flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    white-space: nowrap;
  }

  .bc-stat-k :global(svg) {
    flex-shrink: 0;
    opacity: 0.85;
  }

  .bc-stat-n {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: -0.02em;
    color: var(--mdt-text);
    font-variant-numeric: tabular-nums;
  }

  .bc-stat-div {
    align-self: center;
    height: calc(22px * var(--mdt-scale));
    width: 1px;
    margin: 0;
    background: color-mix(in srgb, var(--mdt-border) 75%, transparent);
    flex-shrink: 0;
  }

  .bc-my-feed {
    margin-left: calc(2px * var(--mdt-scale));
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    min-height: var(--bc-ctl-h);
    padding: 0 calc(14px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 40%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-accent-dim) 65%, var(--mdt-surface-2));
    color: var(--mdt-text);
    font: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition:
      background 0.15s ease,
      border-color 0.15s ease,
      transform 0.1s ease;
  }

  .bc-my-feed:hover:not(:disabled) {
    border-color: color-mix(in srgb, var(--mdt-accent) 55%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-accent-dim) 100%, var(--mdt-surface-2));
  }

  .bc-my-feed:active:not(:disabled) {
    transform: scale(0.98);
  }

  .bc-my-feed:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .bc-my-dot {
    width: calc(7px * var(--mdt-scale));
    height: calc(7px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-accent);
    animation: bc-pulse-dot 2s ease-in-out infinite;
  }

  .bc-control-end {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .bc-dept-lbl {
    margin: 0;
    flex-shrink: 0;
  }

  .bc-segment {
    display: inline-flex;
    align-items: stretch;
    border: 1px solid var(--mdt-border);
    border-radius: calc(10px * var(--mdt-scale));
    overflow: hidden;
    background: var(--mdt-surface);
    min-height: var(--bc-ctl-h);
  }

  .bc-seg-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: var(--bc-ctl-h);
    padding: 0 calc(14px * var(--mdt-scale));
    border: none;
    border-right: 1px solid var(--mdt-border);
    background: transparent;
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', ui-monospace, monospace;
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.04em;
    cursor: pointer;
    transition: color 0.12s ease, background 0.12s ease;
  }

  .bc-seg-btn:last-child {
    border-right: none;
  }

  .bc-seg-btn:hover {
    color: var(--mdt-text);
    background: var(--mdt-surface-2);
  }

  .bc-seg-btn.sel {
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
  }

  .bc-seg-btn:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--mdt-accent) 55%, transparent);
    outline-offset: 1px;
    position: relative;
    z-index: 1;
  }

  .bc-seg-btn:active {
    transform: scale(0.99);
  }

  .bc-icon-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: var(--bc-ctl-h);
    height: var(--bc-ctl-h);
    box-sizing: border-box;
    padding: 0;
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition:
      color 0.12s ease,
      background 0.12s ease,
      border-color 0.12s ease;
  }

  .bc-icon-btn:hover:not(:disabled) {
    color: var(--mdt-text);
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-3);
  }

  .bc-icon-btn:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--mdt-accent) 65%, transparent);
    outline-offset: 2px;
  }

  .bc-icon-btn:active:not(:disabled) {
    transform: scale(0.98);
  }

  .bc-icon-btn:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .bc-refresh-ico {
    display: flex;
    align-items: center;
    justify-content: center;
    color: inherit;
  }

  .bc-refresh-ico.bc-spin {
    animation: bc-rot 0.75s linear infinite;
  }

  .bc-error {
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid color-mix(in srgb, var(--mdt-error) 45%, transparent);
    background: color-mix(in srgb, var(--mdt-error) 12%, var(--mdt-surface));
    color: var(--mdt-error);
    font-size: calc(12px * var(--mdt-scale));
  }

  .bc-error-float {
    position: fixed;
    top: calc(72px * var(--mdt-scale));
    left: 50%;
    transform: translateX(-50%);
    z-index: 80;
    max-width: min(92vw, calc(420px * var(--mdt-scale)));
    margin: 0;
    pointer-events: auto;
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.06),
      0 calc(8px * var(--mdt-scale)) calc(28px * var(--mdt-scale)) rgba(0, 0, 0, 0.45);
  }

  .bc-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(min(100%, calc(300px * var(--mdt-scale))), 1fr));
    gap: calc(12px * var(--mdt-scale));
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: calc(4px * var(--mdt-scale)) calc(2px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) 0;
    align-content: start;
  }

  .bc-grid-skel {
    pointer-events: none;
  }

  .bc-skel-card {
    border: 1px solid var(--mdt-border);
    border-radius: calc(12px * var(--mdt-scale));
    background: var(--mdt-surface);
    overflow: hidden;
    animation: bc-card-in 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--sk) * 55ms);
    opacity: 0;
  }

  .bc-skel-preview {
    height: calc(168px * var(--mdt-scale));
    background: linear-gradient(
      110deg,
      var(--mdt-surface-3) 0%,
      var(--mdt-surface-2) 40%,
      var(--mdt-surface-3) 80%
    );
    background-size: 200% 100%;
    animation: bc-shimmer 1.2s ease-in-out infinite;
    animation-delay: calc(var(--sk) * 80ms);
  }

  .bc-skel-body {
    display: flex;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale));
  }

  .bc-skel-av {
    width: calc(38px * var(--mdt-scale));
    height: calc(38px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-3);
    flex-shrink: 0;
  }

  .bc-skel-lines {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    justify-content: center;
    min-width: 0;
  }

  .bc-skel-line {
    height: calc(10px * var(--mdt-scale));
    border-radius: 4px;
    background: var(--mdt-surface-3);
  }

  .bc-skel-line.w1 {
    width: 72%;
  }
  .bc-skel-line.w2 {
    width: 48%;
  }

  .bc-empty {
    flex: 1;
    min-height: calc(200px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(28px * var(--mdt-scale));
    text-align: center;
    color: var(--mdt-text-muted);
    background: var(--mdt-surface);
    border-radius: calc(12px * var(--mdt-scale));
    border: 1px dashed var(--mdt-border);
  }

  .bc-empty-ico {
    opacity: 0.35;
    margin-bottom: calc(4px * var(--mdt-scale));
  }

  .bc-empty-title {
    margin: 0;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
  }

  .bc-empty-sub {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.45;
    max-width: 40ch;
  }

  .bc-empty-reset {
    margin-top: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: calc(10px * var(--mdt-scale));
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-3);
    color: var(--mdt-text);
    font: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    cursor: pointer;
  }

  .bc-empty-reset:hover {
    border-color: color-mix(in srgb, var(--mdt-accent) 35%, var(--mdt-border));
  }

  .bc-card {
    border: 1px solid var(--mdt-border);
    border-radius: calc(12px * var(--mdt-scale));
    background: var(--mdt-surface);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    transition:
      border-color 0.18s ease,
      box-shadow 0.18s ease,
      transform 0.14s cubic-bezier(0.16, 1, 0.3, 1);
    animation: bc-card-in 0.38s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--idx) * 45ms);
    opacity: 0;
  }

  .bc-card:hover {
    border-color: var(--mdt-border-2);
    box-shadow: 0 calc(8px * var(--mdt-scale)) calc(24px * var(--mdt-scale)) color-mix(in srgb, var(--mdt-bg) 55%, transparent);
    transform: translateY(calc(-2px * var(--mdt-scale)));
  }

  .bc-card.own {
    border-color: color-mix(in srgb, var(--mdt-accent) 38%, var(--mdt-border));
    box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--mdt-accent) 12%, transparent);
  }

  .bc-card-preview {
    position: relative;
    height: calc(172px * var(--mdt-scale));
    background: var(--mdt-bg);
    overflow: hidden;
  }

  .bc-preview-img {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
    filter: saturate(0.9) contrast(1.05) brightness(0.93);
    transform: scale(1.02);
  }

  .bc-preview-fallback {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background:
      radial-gradient(ellipse at 30% 20%, hsl(var(--preview-h) 42% 40% / 0.35), transparent 55%),
      linear-gradient(165deg, var(--mdt-surface) 0%, var(--mdt-bg) 100%);
  }

  .bc-preview-initials {
    font-size: calc(34px * var(--mdt-scale));
    font-weight: 700;
    color: rgba(255, 255, 255, 0.18);
    letter-spacing: 0.1em;
  }

  .bc-preview-glass {
    position: absolute;
    inset: 0;
    pointer-events: none;
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.1),
      inset 0 0 0 1px rgba(255, 255, 255, 0.04);
    border-bottom: 1px solid var(--mdt-border);
  }

  .bc-preview-top {
    position: absolute;
    top: calc(8px * var(--mdt-scale));
    left: calc(10px * var(--mdt-scale));
    right: calc(10px * var(--mdt-scale));
    display: flex;
    justify-content: space-between;
    align-items: center;
    z-index: 2;
  }

  .bc-cam-id {
    font-size: calc(9px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.38);
    letter-spacing: 0.1em;
  }

  .bc-preview-pill {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(2px * var(--mdt-scale)) calc(7px * var(--mdt-scale));
    border-radius: calc(6px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 28%, transparent);
    background: color-mix(in srgb, var(--mdt-bg) 45%, transparent);
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.08em;
    color: var(--mdt-accent);
    font-family: 'Share Tech Mono', ui-monospace, monospace;
  }

  .bc-preview-dot {
    width: calc(5px * var(--mdt-scale));
    height: calc(5px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-accent);
    opacity: 0.9;
    animation: bc-pulse-dot 2s ease-in-out infinite;
  }

  .bc-preview-mid {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1;
  }

  .bc-preview-callsign {
    font-size: calc(26px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.12);
    font-weight: 700;
    letter-spacing: 0.06em;
    text-shadow: 0 1px 14px rgba(0, 0, 0, 0.75);
  }

  .bc-preview-bot {
    position: absolute;
    bottom: calc(8px * var(--mdt-scale));
    left: calc(10px * var(--mdt-scale));
    right: calc(10px * var(--mdt-scale));
    display: flex;
    justify-content: space-between;
    z-index: 2;
  }

  .bc-hud-muted {
    font-size: calc(9px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.32);
    letter-spacing: 0.04em;
  }

  .bc-card-body {
    padding: calc(12px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }

  .bc-officer {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    min-width: 0;
  }

  .bc-avatar {
    width: calc(38px * var(--mdt-scale));
    height: calc(38px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-surface-3);
    border: 1px solid var(--mdt-border);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    overflow: hidden;
  }

  .bc-avatar-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .bc-avatar-ix {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-dim);
    letter-spacing: 0.04em;
  }

  .bc-officer-text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
  }

  .bc-name-row {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    min-width: 0;
  }

  .bc-name {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .bc-you {
    flex-shrink: 0;
    padding: calc(2px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: calc(4px * var(--mdt-scale));
    background: var(--mdt-accent-dim);
    color: var(--mdt-accent);
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 22%, transparent);
  }

  .bc-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.03em;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .bc-card-actions {
    display: flex;
    align-items: stretch;
    gap: calc(8px * var(--mdt-scale));
    min-height: var(--bc-ctl-h);
  }

  .bc-card-foot {
    margin: 0;
    font-size: calc(10px * var(--mdt-scale));
    line-height: 1.45;
    color: var(--mdt-text-muted);
    padding: calc(10px * var(--mdt-scale)) 0 0;
    border-top: 1px solid color-mix(in srgb, var(--mdt-border) 70%, transparent);
  }

  .bc-audio {
    display: flex;
    align-items: center;
    justify-content: center;
    flex: 0 0 var(--bc-ctl-h);
    width: var(--bc-ctl-h);
    min-height: var(--bc-ctl-h);
    max-height: var(--bc-ctl-h);
    padding: 0;
    box-sizing: border-box;
    border: 1px solid var(--mdt-border);
    border-radius: calc(10px * var(--mdt-scale));
    background: var(--mdt-surface-2);
    color: var(--mdt-text-muted);
    cursor: pointer;
    transition:
      color 0.12s ease,
      border-color 0.12s ease,
      background 0.12s ease;
  }

  .bc-audio:hover {
    color: var(--mdt-text);
    border-color: var(--mdt-border-2);
  }

  .bc-audio.active {
    color: var(--mdt-accent);
    border-color: color-mix(in srgb, var(--mdt-accent) 32%, transparent);
    background: var(--mdt-accent-dim);
  }

  .bc-audio:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--mdt-accent) 50%, transparent);
    outline-offset: 2px;
  }

  .bc-audio:active {
    transform: scale(0.98);
  }

  .bc-btn-watch {
    flex: 1;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
    min-height: var(--bc-ctl-h);
    max-height: var(--bc-ctl-h);
    padding: 0 calc(14px * var(--mdt-scale));
    box-sizing: border-box;
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-border));
    border-radius: calc(10px * var(--mdt-scale));
    background: linear-gradient(
      135deg,
      color-mix(in srgb, var(--mdt-accent) 88%, var(--mdt-bg)),
      color-mix(in srgb, var(--mdt-accent) 52%, var(--mdt-bg))
    );
    color: var(--mdt-bg);
    font: inherit;
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition:
      filter 0.12s ease,
      transform 0.1s cubic-bezier(0.16, 1, 0.3, 1);
  }

  :global([data-theme='cortex']) .bc-btn-watch {
    color: #141820;
  }

  .bc-btn-watch:hover:not(:disabled) {
    filter: brightness(1.06);
  }

  .bc-btn-watch:active:not(:disabled) {
    transform: scale(0.98);
  }

  .bc-btn-watch:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .bc-btn-watch:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--mdt-accent) 70%, transparent);
    outline-offset: 2px;
  }

  @container bc-page (max-width: 720px) {
    .bc-toolbar-r1,
    .bc-toolbar-r2 {
      grid-template-columns: 1fr;
    }

    .bc-toolbar-r1 {
      align-items: start;
    }

    .bc-control-row {
      flex-direction: column;
      align-items: stretch;
    }

    .bc-stat-strip {
      width: 100%;
    }

    .bc-control-end {
      justify-content: flex-start;
    }
  }

  /* Live overlay (game view) */
  .bcam-immersive {
    --bcam-frame-inset: calc(18px * var(--mdt-scale));
    --bcam-corner-arm: calc(34px * var(--mdt-scale));
    --bcam-hud-gap: calc(8px * var(--mdt-scale));
    position: fixed;
    inset: 0;
    z-index: 50;
    pointer-events: none;
    font-family: 'Bahnschrift', 'Segoe UI', 'Helvetica Neue', sans-serif;
  }

  .bcam-corners {
    position: absolute;
    inset: var(--bcam-frame-inset);
    z-index: 3;
    pointer-events: none;
  }

  .bcam-corner {
    position: absolute;
    width: var(--bcam-corner-arm);
    height: var(--bcam-corner-arm);
    border: 2px solid rgba(255, 255, 255, 0.48);
    box-sizing: border-box;
    filter: drop-shadow(0 0 calc(6px * var(--mdt-scale)) rgba(0, 0, 0, 0.45));
  }

  .bcam-corner.tl {
    top: 0;
    left: 0;
    border-right: none;
    border-bottom: none;
  }

  .bcam-corner.tr {
    top: 0;
    right: 0;
    border-left: none;
    border-bottom: none;
  }

  .bcam-corner.bl {
    bottom: 0;
    left: 0;
    border-right: none;
    border-top: none;
  }

  .bcam-corner.br {
    bottom: 0;
    right: 0;
    border-left: none;
    border-top: none;
  }

  .bcam-hud {
    position: absolute;
    z-index: 4;
    pointer-events: none;
    text-shadow: 0 1px calc(10px * var(--mdt-scale)) rgba(0, 0, 0, 0.88);
  }

  .bcam-hud--tl {
    top: var(--bcam-frame-inset);
    left: var(--bcam-frame-inset);
    padding:
      calc(var(--bcam-corner-arm) + var(--bcam-hud-gap))
      var(--bcam-hud-gap)
      var(--bcam-hud-gap)
      calc(var(--bcam-corner-arm) + var(--bcam-hud-gap));
  }

  .bcam-hud--tr {
    top: var(--bcam-frame-inset);
    right: var(--bcam-frame-inset);
    padding:
      calc(var(--bcam-corner-arm) + var(--bcam-hud-gap))
      calc(var(--bcam-corner-arm) + var(--bcam-hud-gap))
      var(--bcam-hud-gap)
      var(--bcam-hud-gap);
  }

  .bcam-ts-hud {
    display: block;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    letter-spacing: 0.06em;
    color: rgba(255, 255, 255, 0.5);
    white-space: nowrap;
  }

  .bcam-status {
    display: inline-flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-end;
    gap: calc(8px * var(--mdt-scale));
    max-width: min(calc(42vw), calc(280px * var(--mdt-scale)));
  }

  .bcam-exit {
    pointer-events: auto;
    flex-shrink: 0;
    padding: calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border: 1px solid rgba(255, 255, 255, 0.35);
    border-radius: calc(10px * var(--mdt-scale));
    background: color-mix(in srgb, #f8fafc 96%, var(--mdt-surface-2));
    color: #0f172a;
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    cursor: pointer;
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.55),
      0 2px 0 rgba(15, 23, 42, 0.12);
    transition: transform 0.1s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .bcam-exit:hover:not(:disabled) {
    filter: brightness(1.04);
  }

  .bcam-exit:active:not(:disabled) {
    transform: scale(0.98);
  }

  .bcam-exit:focus-visible {
    outline: 2px solid rgba(96, 165, 250, 0.85);
    outline-offset: 2px;
  }

  .bcam-exit:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .bcam-bottom-center {
    position: absolute;
    left: 50%;
    bottom: calc(var(--bcam-frame-inset) + var(--bcam-hud-gap));
    transform: translateX(-50%);
    z-index: 4;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    width: min(
      calc(100% - 2 * (var(--bcam-frame-inset) + var(--bcam-corner-arm) + var(--bcam-hud-gap))),
      calc(1100px * var(--mdt-scale))
    );
    pointer-events: none;
  }

  .bcam-meta {
    max-width: 100%;
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
    text-align: center;
    text-shadow: 0 1px 14px rgba(0, 0, 0, 0.9);
    pointer-events: none;
  }

  .bcam-dock {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: calc(12px * var(--mdt-scale));
    width: 100%;
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: rgba(15, 23, 42, 0.82);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: calc(12px * var(--mdt-scale));
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.06),
      0 calc(12px * var(--mdt-scale)) calc(40px * var(--mdt-scale)) rgba(0, 0, 0, 0.55);
    pointer-events: auto;
  }

  .bcam-dock-top {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    width: 100%;
  }

  .bcam-dock-lede {
    margin: 0;
    flex: 1;
    min-width: min(100%, calc(280px * var(--mdt-scale)));
    font-size: calc(11px * var(--mdt-scale));
    line-height: 1.45;
    font-weight: 500;
    color: rgba(248, 250, 252, 0.72);
    text-shadow: 0 1px 10px rgba(0, 0, 0, 0.85);
  }

  .bcam-key-section {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
    width: 100%;
  }

  .bcam-section-label {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.38);
  }

  .bcam-keybar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-start;
    gap: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    width: 100%;
  }

  .bcam-keybar-compact {
    gap: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
  }

  .bcam-cam-id {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.12em;
    color: rgba(255, 255, 255, 0.58);
    white-space: nowrap;
  }

  .bcam-rec {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.12em;
    color: #fca5a5;
    white-space: nowrap;
  }

  .bcam-rec-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: #ef4444;
    animation: bc-pulse-dot 1s ease-in-out infinite;
  }

  .bcam-key-group {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .bcam-klabel {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    color: #fff;
    letter-spacing: 0.02em;
    white-space: nowrap;
  }

  .bcam-klabel::after {
    content: ':';
    margin-left: 1px;
    opacity: 0.9;
  }

  .bcam-k {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: calc(26px * var(--mdt-scale));
    min-width: calc(28px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(9px * var(--mdt-scale));
    border-radius: calc(7px * var(--mdt-scale));
    border: none;
    background: #f1f5f9;
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 800;
    color: #0f172a;
    letter-spacing: 0.04em;
    line-height: 1;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.65);
  }

  .bcam-k-wide {
    min-width: auto;
    padding-left: calc(11px * var(--mdt-scale));
    padding-right: calc(11px * var(--mdt-scale));
  }

  .bcam-meta-line {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    justify-content: center;
    gap: calc(8px * var(--mdt-scale));
  }

  .bcam-callsign {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 700;
    color: rgba(255, 255, 255, 0.92);
    letter-spacing: 0.06em;
  }

  .bcam-name-inline {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: rgba(255, 255, 255, 0.88);
  }

  .bcam-loc {
    font-size: calc(11px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.62);
    letter-spacing: 0.03em;
  }

  .bcam-dock-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
    padding-top: calc(4px * var(--mdt-scale));
    border-top: 1px solid rgba(255, 255, 255, 0.1);
  }

  .bcam-audio {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: calc(8px * var(--mdt-scale));
    background: #f1f5f9;
    color: #0f172a;
    font-family: inherit;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    cursor: pointer;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.5);
  }

  .bcam-audio.active {
    outline: 2px solid color-mix(in srgb, var(--mdt-accent) 70%, transparent);
    outline-offset: 1px;
  }

  @media (max-width: 720px) {
    .bcam-dock-top {
      flex-direction: column;
      align-items: stretch;
    }

    .bcam-keybar {
      justify-content: flex-start;
    }

    .bcam-dock-actions {
      justify-content: center;
    }
  }

  .font-mono {
    font-family: 'Share Tech Mono', 'JetBrains Mono', ui-monospace, monospace;
  }

  @keyframes bc-fade-in {
    from {
      opacity: 0;
      transform: translateY(calc(4px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes bc-card-in {
    from {
      opacity: 0;
      transform: translateY(calc(10px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes bc-pulse-dot {
    0%,
    100% {
      opacity: 1;
    }
    50% {
      opacity: 0.35;
    }
  }

  @keyframes bc-rot {
    to {
      transform: rotate(360deg);
    }
  }

  @keyframes bc-shimmer {
    0% {
      background-position: 200% 0;
    }
    100% {
      background-position: -200% 0;
    }
  }
</style>
