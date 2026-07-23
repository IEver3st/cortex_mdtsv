<script>
  import { onDestroy, onMount } from 'svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { Video, RefreshCw, Plus, X, Power, Trash2 } from '@lucide/svelte';
  import CctvCameraCard from '../lib/components/cctv/CctvCameraCard.svelte';

  let loading = $state(true);
  let actionBusy = $state(false);
  let mode = $state('grid');
  let addFormOpen = $state(false);
  let createLabel = $state('');
  let createModel = $state('security_cam_03');
  let errorMessage = $state('');
  let locationFilter = $state('all');
  let searchQuery = $state('');
  let feedClock = $state('');

  let cameras = $derived(dataStore.cctvCameras || []);
  let cameraModels = $derived(dataStore.cameraModels || []);
  let canManage = $derived(dataStore.cctvCanManage === true);
  let activeFeed = $derived(dataStore.activeCameraFeed);
  let onlineCount = $derived(cameras.filter((camera) => camera.isOnline !== false).length);

  function locationKey(camera) {
    return camera?.type && String(camera.type).trim() !== '' ? String(camera.type) : 'other';
  }

  function formatLocationLabel(key) {
    if (key === 'all') return 'All';
    if (key === 'other') return 'Other';
    const map = {
      bank: 'Bank',
      store: 'Stores',
      placed: 'Field',
    };
    if (map[key]) return map[key];
    return key.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }

  let locationKeys = $derived.by(() => {
    const set = new Set();
    for (const c of cameras) {
      set.add(locationKey(c));
    }
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  });

  let filteredCameras = $derived.by(() => {
    let list = cameras;
    if (locationFilter !== 'all') {
      list = list.filter((c) => locationKey(c) === locationFilter);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      list = list.filter((c) =>
        (c.label || '').toLowerCase().includes(q) ||
        (c.id || '').toLowerCase().includes(q) ||
        (c.model || '').toLowerCase().includes(q)
      );
    }
    return list;
  });

  $effect(() => {
    if (mode !== 'feed') return;
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
    if (!activeFeed && mode === 'feed') {
      mode = 'grid';
    }
  });

  async function boot() {
    loading = true;
    errorMessage = '';

    const cameraResp = await dataStore.fetchCctvCameras();
    const modelsResp = await dataStore.fetchCameraModels();

    if (!cameraResp?.ok) {
      errorMessage = cameraResp?.error || 'Failed to load CCTV cameras.';
    }

    if (!modelsResp?.ok && !errorMessage) {
      errorMessage = modelsResp?.error || 'Failed to load camera models.';
    }

    if (modelsResp?.ok && cameraModels.length > 0 && !cameraModels.find((entry) => entry.value === createModel)) {
      createModel = cameraModels[0].value;
    }

    loading = false;
  }

  onMount(async () => {
    await boot();
  });

  onDestroy(() => {
    dataStore.stopCameraView();
  });

  async function openCamera(cameraId) {
    actionBusy = true;
    errorMessage = '';

    const resp = await dataStore.viewCamera(cameraId);
    if (resp?.ok) {
      mode = 'feed';
    } else {
      errorMessage = resp?.error || 'Failed to open camera feed.';
    }

    actionBusy = false;
  }

  async function closeFeed() {
    actionBusy = true;
    await dataStore.stopCameraView();
    mode = 'grid';
    actionBusy = false;
  }

  async function createCamera() {
    if (!createLabel.trim() || !createModel || actionBusy) return;

    actionBusy = true;
    errorMessage = '';

    const resp = await dataStore.createStaticCamera({
      label: createLabel.trim(),
      model: createModel,
    });

    if (!resp?.ok) {
      errorMessage = resp?.error || 'Failed to create camera.';
      actionBusy = false;
      return;
    }

    createLabel = '';
    addFormOpen = false;
    await dataStore.fetchCctvCameras();
    actionBusy = false;
  }

  async function toggleCameraState(camera) {
    if (!canManage || actionBusy) return;

    actionBusy = true;
    errorMessage = '';

    const resp = await dataStore.setCameraOnline(camera.id, camera.isOnline === false);
    if (!resp?.ok) {
      errorMessage = resp?.error || 'Failed to change camera state.';
    }

    await dataStore.fetchCctvCameras();
    actionBusy = false;
  }

  async function removeCamera(camera) {
    if (!canManage || actionBusy) return;

    actionBusy = true;
    errorMessage = '';

    const resp = await dataStore.deleteCamera(camera.id);
    if (!resp?.ok) {
      errorMessage = resp?.error || 'Failed to delete camera.';
    }

    await dataStore.fetchCctvCameras();
    if (activeFeed?.id === camera.id) {
      mode = 'grid';
    }

    actionBusy = false;
  }

  function controlCamera(action) {
    dataStore.cameraControl(action);
  }
</script>

<div class="cctv-page" class:feed-live={mode === 'feed'}>
  {#if mode === 'list'}
    <header class="page-header">
      <div class="header-info">
        <h2 class="page-title">CCTV Network</h2>
        <p class="page-subtitle">Static surveillance cameras and live feed controls</p>
      </div>
      <div class="header-actions">
        <div class="action-item is-static">
          <span class="action-dot success"></span>
          <span class="action-label">{onlineCount} online</span>
        </div>
        <div class="action-sep"></div>
        <div class="action-item is-static">
          <span class="action-dot accent"></span>
          <span class="action-label">{cameras.length} total</span>
        </div>
        {#if canManage}
          <div class="action-sep"></div>
          <button class="action-item" onclick={() => { addFormOpen = !addFormOpen; errorMessage = ''; }} disabled={actionBusy}>
            <span class="action-label">{addFormOpen ? 'Close' : 'Add Camera'}</span>
          </button>
        {/if}
        <div class="action-sep"></div>
        <button class="action-icon" onclick={boot} disabled={loading || actionBusy} title="Refresh">
          <RefreshCw size={16} />
        </button>
      </div>
    </header>

    {#if errorMessage}
      <div class="error-banner">
        <X size={16} />
        <span>{errorMessage}</span>
      </div>
    {/if}

    {#if addFormOpen && canManage}
      <section class="create-panel">
        <div class="create-fields">
          <label class="field">
            <span class="field-label">Camera Label</span>
            <input class="field-input" type="text" placeholder="Mission Row Lobby" bind:value={createLabel} />
          </label>
          <label class="field">
            <span class="field-label">Camera Model</span>
            <select class="field-select" bind:value={createModel}>
              {#each cameraModels as model (model.value)}
                <option value={model.value}>{model.label}</option>
              {/each}
            </select>
          </label>
        </div>
        <div class="create-footer">
          <p class="create-hint">Placement uses your current position and facing direction.</p>
          <button class="btn-primary" onclick={createCamera} disabled={actionBusy || !createLabel.trim() || !createModel}>
            <Plus size={12} />
            Create Camera
          </button>
        </div>
      </section>
    {/if}

    <!-- Search & Filters -->
    <div class="controls-row">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
        <input type="text" class="search-input" placeholder="Search by label, ID, model..." bind:value={searchQuery} />
      </div>
      <div class="filter-pills">
        <button class="filter-pill" class:active={locationFilter === 'all'} onclick={() => locationFilter = 'all'}>All</button>
        {#each locationKeys as lk (lk)}
          <button class="filter-pill" class:active={locationFilter === lk} onclick={() => locationFilter = lk}>{formatLocationLabel(lk)}</button>
        {/each}
      </div>
    </div>

    <div class="section-divider" aria-hidden="true"></div>

    {#if loading}
      <div class="empty-state">
        <div class="loading-pulse"></div>
        <span>Loading CCTV cameras...</span>
      </div>
    {:else if filteredCameras.length === 0}
      <div class="empty-state">
        <Video size={48} />
        <span class="empty-text">No cameras found</span>
        <span class="empty-sub">{canManage ? 'Use Add Camera to place the first one.' : ''}</span>
      </div>
    {:else}
      <section class="camera-grid-cctv">
        {#each filteredCameras as camera, i (camera.id)}
          <CctvCameraCard
            {camera}
            {canManage}
            disabled={actionBusy}
            onView={openCamera}
            onToggle={toggleCameraState}
            onRemove={removeCamera}
            --idx={i}
          />
        {/each}
      </section>
    {/if}
  {:else}
    <!-- Fullscreen CCTV overlay (game renders behind transparent NUI) -->
    <section class="ctv-immersive" aria-label="Camera feed">
      <div class="ctv-corners" aria-hidden="true">
        <span class="ctv-corner tl"></span>
        <span class="ctv-corner tr"></span>
        <span class="ctv-corner bl"></span>
        <span class="ctv-corner br"></span>
      </div>

      <header class="ctv-hud ctv-hud--tl" aria-label="Feed timestamp">
        <time class="ctv-ts-hud font-mono" datetime="">{feedClock}</time>
      </header>

      <header class="ctv-hud ctv-hud--tr" aria-label="Feed status">
        <div class="ctv-status">
          {#if activeFeed}
            <span class="ctv-cam-id">CCTV {String(activeFeed.id).slice(-6).toUpperCase()}</span>
          {:else}
            <span class="ctv-cam-id">CCTV ------</span>
          {/if}
          <span class="ctv-rec" aria-label="Recording active">
            <span class="ctv-rec-dot" aria-hidden="true"></span>
            REC
          </span>
        </div>
      </header>

      <div class="ctv-bottom-center">
        {#if activeFeed}
          <div class="ctv-meta">
            <div class="ctv-meta-line">
              <span class="ctv-label">{activeFeed.label}</span>
              <span class="ctv-type">{activeFeed.type || 'Unknown'} · {activeFeed.model}</span>
            </div>
          </div>
        {/if}

        <div class="ctv-dock" aria-label="Keyboard controls">
          <button type="button" class="ctv-exit" onclick={() => closeFeed()} disabled={actionBusy}>Exit</button>
          <div class="ctv-keybar">
            <div class="ctv-key-group">
              <span class="ctv-klabel">Up / Down</span>
              <kbd class="ctv-k">W</kbd>
              <kbd class="ctv-k">S</kbd>
            </div>
            <div class="ctv-key-group">
              <span class="ctv-klabel">Left / Right</span>
              <kbd class="ctv-k">A</kbd>
              <kbd class="ctv-k">D</kbd>
            </div>
            <div class="ctv-key-group">
              <span class="ctv-klabel">Zoom in/out</span>
              <kbd class="ctv-k">Q</kbd>
              <kbd class="ctv-k">E</kbd>
            </div>
            <div class="ctv-key-group">
              <span class="ctv-klabel">Reset</span>
              <kbd class="ctv-k">R</kbd>
            </div>
            <div class="ctv-key-group">
              <span class="ctv-klabel">Faster</span>
              <kbd class="ctv-k ctv-k-wide">SHIFT</kbd>
            </div>
            <div class="ctv-key-group">
              <span class="ctv-klabel">Slower</span>
              <kbd class="ctv-k ctv-k-wide">CTRL</kbd>
            </div>
          </div>
          <div class="ctv-dock-actions">
            {#if activeFeed && canManage}
              <button
                type="button"
                class="ctv-admin-btn"
                onclick={() => toggleCameraState(activeFeed)}
                disabled={actionBusy}
              >
                <Power size={12} />
                {activeFeed.isOnline === false ? 'Bring Online' : 'Take Offline'}
              </button>
              <button class="ctv-admin-btn danger" type="button" onclick={() => removeCamera(activeFeed)} disabled={actionBusy}>
                <Trash2 size={12} />
                Delete
              </button>
            {/if}
          </div>
        </div>
      </div>
    </section>
  {/if}
</div>

<style>
  .cctv-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(16px * var(--mdt-scale));
    height: 100%;
    min-height: 100%;
    box-sizing: border-box;
    background: var(--mdt-bg);
    animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  .cctv-page.feed-live {
    padding: 0;
    gap: 0;
    background: transparent;
    overflow: hidden;
    height: 100%;
    min-height: 0;
  }

  .font-mono {
    font-family: 'Share Tech Mono', ui-monospace, monospace;
  }

  /* ─── Header ─── */
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: stretch;
    gap: 0;
    padding: 0;
    padding-bottom: calc(12px * var(--mdt-scale));
    margin: 0;
    background: transparent;
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    border-radius: 0;
  }

  .header-info {
    padding: calc(14px * var(--mdt-scale)) 0;
    display: flex;
    flex-direction: column;
    justify-content: center;
    flex: 1;
    min-width: 0;
  }

  .page-title {
    font-size: calc(22px * var(--mdt-scale));
    color: var(--mdt-text);
    letter-spacing: -0.02em;
    font-weight: 700;
  }

  .page-subtitle {
    margin-top: calc(4px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .header-actions {
    display: flex;
    align-items: stretch;
    gap: 0;
  }

  .action-item {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: 0 calc(14px * var(--mdt-scale));
    background: transparent;
    border: none;
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease;
  }

  .action-item:hover:not(:disabled) { background: var(--mdt-surface-2); }
  .action-item:disabled { opacity: 0.4; cursor: not-allowed; }

  .action-item.is-static {
    cursor: default;
    color: var(--mdt-text-dim);
  }

  .action-item.is-static:hover { background: transparent; }

  .action-sep {
    width: 1px;
    align-self: stretch;
    background: var(--mdt-border);
    margin: calc(10px * var(--mdt-scale)) 0;
  }

  .action-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: calc(42px * var(--mdt-scale));
    background: transparent;
    border: none;
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
    padding: calc(6px * var(--mdt-scale));
  }

  .action-icon:hover { background: var(--mdt-surface-2); color: var(--mdt-text); }
  .action-icon:disabled { opacity: 0.4; cursor: not-allowed; }

  .action-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }

  .action-dot.accent {
    background: var(--mdt-accent);
    animation: pulse-dot 2s ease-in-out infinite;
  }

  .action-dot.success {
    background: var(--mdt-success);
    animation: pulse-dot 2s ease-in-out infinite;
  }

  .action-label {
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 600;
    white-space: nowrap;
  }

  .error-banner {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    border: 1px solid color-mix(in srgb, var(--mdt-error) 25%, var(--mdt-border));
    background: color-mix(in srgb, var(--mdt-error) 8%, transparent);
    color: var(--mdt-error);
    border-radius: var(--mdt-radius);
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
  }

  .error-banner :global(svg) {
    width: calc(16px * var(--mdt-scale));
    height: calc(16px * var(--mdt-scale));
    flex-shrink: 0;
  }

  /* ─── Create Panel ─── */
  .create-panel {
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    border-radius: var(--mdt-radius);
    padding: calc(14px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .create-fields {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: calc(12px * var(--mdt-scale));
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .field-label {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-weight: 600;
  }

  .field-input,
  .field-select {
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    border-radius: var(--mdt-radius-sm);
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    transition: border-color 0.15s ease;
  }

  .field-input:focus,
  .field-select:focus {
    outline: none;
    border-color: color-mix(in srgb, var(--mdt-accent) 50%, var(--mdt-border));
  }

  .create-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(12px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .create-hint {
    color: var(--mdt-text-muted);
    font-size: calc(11px * var(--mdt-scale));
    margin: 0;
  }

  .btn-primary {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface-2);
    color: var(--mdt-text);
    border-radius: var(--mdt-radius-sm);
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    font-family: inherit;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s ease, border-color 0.15s ease, transform 0.1s ease;
  }

  .btn-primary:hover:not(:disabled) {
    background: var(--mdt-surface-3);
    border-color: color-mix(in srgb, var(--mdt-accent) 35%, var(--mdt-border));
  }

  .btn-primary:active:not(:disabled) {
    transform: scale(0.96);
  }

  .btn-primary:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  /* ─── Search & Filters ─── */
  .controls-row {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    flex-wrap: wrap;
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
    flex: 1;
    max-width: calc(320px * var(--mdt-scale));
  }

  .search-box svg {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .search-input {
    background: none;
    border: none;
    outline: none;
    color: var(--mdt-text);
    font-family: inherit;
    font-size: calc(12px * var(--mdt-scale));
    width: 100%;
  }

  .search-input::placeholder { color: var(--mdt-text-muted); }

  .filter-pills {
    display: flex;
    gap: 0;
    border: 1px solid var(--mdt-border);
  }

  .filter-pill {
    padding: calc(5px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: none;
    border-right: 1px solid var(--mdt-border);
    border-radius: 0;
    background: transparent;
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10px * var(--mdt-scale));
    cursor: pointer;
    transition: color 0.15s ease, background 0.15s ease;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .filter-pill:last-child { border-right: none; }

  .filter-pill:hover { color: var(--mdt-text); background: var(--mdt-surface-2); }
  .filter-pill.active { color: var(--mdt-accent); background: var(--mdt-accent-dim); }

  .section-divider {
    flex-shrink: 0;
    height: 1px;
    background: var(--mdt-border);
    width: 100%;
  }

  /* ─── Empty State ─── */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(48px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-align: center;
  }

  .empty-state :global(svg) {
    width: calc(48px * var(--mdt-scale));
    height: calc(48px * var(--mdt-scale));
    opacity: 0.3;
  }

  .empty-text { font-size: calc(14px * var(--mdt-scale)); font-weight: 500; }
  .empty-sub { font-size: calc(11px * var(--mdt-scale)); max-width: calc(300px * var(--mdt-scale)); }

  .loading-pulse {
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    border-radius: 50%;
    border: 2px solid var(--mdt-border);
    border-top-color: var(--mdt-accent);
    animation: spin 0.8s linear infinite;
  }

  /* ─── Grid ─── */
  .camera-grid-cctv {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(304px * var(--mdt-scale)), 1fr));
    gap: calc(14px * var(--mdt-scale));
    overflow-y: auto;
    padding-right: calc(2px * var(--mdt-scale));
  }

  /* ─── Fullscreen CCTV overlay ─── */
  .ctv-immersive {
    --ctv-frame-inset: calc(18px * var(--mdt-scale));
    --ctv-corner-arm: calc(34px * var(--mdt-scale));
    --ctv-hud-gap: calc(8px * var(--mdt-scale));
    position: fixed;
    inset: 0;
    z-index: 50;
    pointer-events: none;
    font-family: 'Bahnschrift', 'Segoe UI', 'Helvetica Neue', sans-serif;
  }

  .ctv-corners {
    position: absolute;
    inset: var(--ctv-frame-inset);
    z-index: 3;
    pointer-events: none;
  }

  .ctv-corner {
    position: absolute;
    width: var(--ctv-corner-arm);
    height: var(--ctv-corner-arm);
    border: 2px solid rgba(255, 255, 255, 0.48);
    box-sizing: border-box;
    filter: drop-shadow(0 0 calc(6px * var(--mdt-scale)) rgba(0, 0, 0, 0.45));
  }

  .ctv-corner.tl {
    top: 0;
    left: 0;
    border-right: none;
    border-bottom: none;
    border-radius: 1px 0 0 0;
  }

  .ctv-corner.tr {
    top: 0;
    right: 0;
    border-left: none;
    border-bottom: none;
    border-radius: 0 1px 0 0;
  }

  .ctv-corner.bl {
    bottom: 0;
    left: 0;
    border-right: none;
    border-top: none;
    border-radius: 0 0 0 1px;
  }

  .ctv-corner.br {
    bottom: 0;
    right: 0;
    border-left: none;
    border-top: none;
    border-radius: 0 0 1px 0;
  }

  .ctv-hud {
    position: absolute;
    z-index: 4;
    pointer-events: none;
    text-shadow: 0 1px calc(10px * var(--mdt-scale)) rgba(0, 0, 0, 0.88);
  }

  .ctv-hud--tl {
    top: var(--ctv-frame-inset);
    left: var(--ctv-frame-inset);
    padding:
      calc(var(--ctv-corner-arm) + var(--ctv-hud-gap))
      var(--ctv-hud-gap)
      var(--ctv-hud-gap)
      calc(var(--ctv-corner-arm) + var(--ctv-hud-gap));
  }

  .ctv-hud--tr {
    top: var(--ctv-frame-inset);
    right: var(--ctv-frame-inset);
    padding:
      calc(var(--ctv-corner-arm) + var(--ctv-hud-gap))
      calc(var(--ctv-corner-arm) + var(--ctv-hud-gap))
      var(--ctv-hud-gap)
      var(--ctv-hud-gap);
  }

  .ctv-ts-hud {
    display: block;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 500;
    letter-spacing: 0.06em;
    color: rgba(255, 255, 255, 0.5);
    white-space: nowrap;
  }

  .ctv-status {
    display: inline-flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-end;
    gap: calc(8px * var(--mdt-scale));
    max-width: min(calc(42vw), calc(280px * var(--mdt-scale)));
  }

  .ctv-cam-id {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 600;
    letter-spacing: 0.12em;
    color: rgba(255, 255, 255, 0.58);
    white-space: nowrap;
  }

  .ctv-rec {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.12em;
    color: #fca5a5;
    white-space: nowrap;
  }

  .ctv-rec-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    background: #ef4444;
    animation: pulse-dot 1s ease-in-out infinite;
  }

  .ctv-bottom-center {
    position: absolute;
    left: 50%;
    bottom: calc(var(--ctv-frame-inset) + var(--ctv-hud-gap));
    transform: translateX(-50%);
    z-index: 4;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    width: min(
      calc(100% - 2 * (var(--ctv-frame-inset) + var(--ctv-corner-arm) + var(--ctv-hud-gap))),
      calc(1100px * var(--mdt-scale))
    );
    pointer-events: none;
  }

  .ctv-meta {
    max-width: 100%;
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
    text-align: center;
    text-shadow: 0 1px 14px rgba(0, 0, 0, 0.9);
    pointer-events: none;
  }

  .ctv-meta-line {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: calc(8px * var(--mdt-scale));
    justify-content: center;
  }

  .ctv-label {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: rgba(255, 255, 255, 0.92);
  }

  .ctv-type {
    font-size: calc(11px * var(--mdt-scale));
    color: rgba(255, 255, 255, 0.55);
  }

  .ctv-dock {
    --ctv-dock-tilt: 32deg;
    position: relative;
    isolation: isolate;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: center;
    gap: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    width: 100%;
    padding: calc(12px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    overflow: hidden;
    background: rgba(6, 8, 12, 0.28);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: calc(12px * var(--mdt-scale));
    box-shadow:
      0 calc(8px * var(--mdt-scale)) calc(28px * var(--mdt-scale)) rgba(0, 0, 0, 0.35),
      inset 0 1px 0 rgba(255, 255, 255, 0.06);
    backdrop-filter: blur(14px) saturate(1.15);
    -webkit-backdrop-filter: blur(14px) saturate(1.15);
    pointer-events: auto;
  }

  .ctv-dock::before {
    content: '';
    position: absolute;
    inset: -40% -20%;
    z-index: 0;
    pointer-events: none;
    opacity: 0.9;
    background: repeating-linear-gradient(
      var(--ctv-dock-tilt),
      transparent 0,
      transparent calc(11px * var(--mdt-scale)),
      rgba(148, 156, 168, 0.14) calc(11px * var(--mdt-scale)),
      rgba(148, 156, 168, 0.14) calc(12px * var(--mdt-scale))
    );
    mask-image: linear-gradient(
      180deg,
      rgba(0, 0, 0, 0.35) 0%,
      rgba(0, 0, 0, 0.85) 18%,
      rgba(0, 0, 0, 0.85) 82%,
      rgba(0, 0, 0, 0.35) 100%
    );
  }

  .ctv-dock::after {
    content: '';
    position: absolute;
    inset: 0;
    z-index: 0;
    pointer-events: none;
    background: linear-gradient(
      180deg,
      rgba(255, 255, 255, 0.04) 0%,
      transparent 42%,
      rgba(0, 0, 0, 0.12) 100%
    );
  }

  .ctv-dock > :global(*) {
    position: relative;
    z-index: 1;
  }

  .ctv-exit {
    pointer-events: auto;
    flex-shrink: 0;
    margin-top: calc(2px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: 1px solid rgba(255, 255, 255, 0.35);
    border-radius: calc(8px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.92);
    color: #0a0a0a;
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    cursor: pointer;
    box-shadow: 0 1px 0 rgba(0, 0, 0, 0.2);
    backdrop-filter: blur(6px);
  }

  .ctv-exit:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .ctv-keybar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: center;
    gap: calc(12px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    flex: 1 1 auto;
    min-width: min(100%, calc(520px * var(--mdt-scale)));
  }

  .ctv-key-group {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }

  .ctv-klabel {
    font-size: calc(12px * var(--mdt-scale));
    font-weight: 500;
    color: rgba(255, 255, 255, 0.88);
    letter-spacing: 0.02em;
    white-space: nowrap;
    text-shadow: 0 1px 8px rgba(0, 0, 0, 0.65);
  }

  .ctv-klabel::after {
    content: ':';
    margin-left: 1px;
    opacity: 0.9;
  }

  .ctv-k {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: calc(26px * var(--mdt-scale));
    min-width: calc(28px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) calc(9px * var(--mdt-scale));
    border-radius: calc(7px * var(--mdt-scale));
    border: 1px solid rgba(255, 255, 255, 0.28);
    background: rgba(255, 255, 255, 0.9);
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 800;
    color: #0a0a0a;
    letter-spacing: 0.04em;
    line-height: 1;
    box-shadow: 0 1px 0 rgba(0, 0, 0, 0.18);
    backdrop-filter: blur(4px);
  }

  .ctv-k-wide {
    min-width: auto;
    padding-left: calc(11px * var(--mdt-scale));
    padding-right: calc(11px * var(--mdt-scale));
  }

  .ctv-dock-actions {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .ctv-admin-btn {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(11px * var(--mdt-scale));
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: calc(8px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.9);
    color: #0a0a0a;
    font-family: inherit;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 800;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    cursor: pointer;
    box-shadow: 0 1px 0 rgba(0, 0, 0, 0.18);
    backdrop-filter: blur(6px);
  }

  .ctv-admin-btn :global(svg) {
    width: calc(14px * var(--mdt-scale));
    height: calc(14px * var(--mdt-scale));
  }

  .ctv-admin-btn.danger {
    outline: 2px solid color-mix(in srgb, var(--mdt-error) 50%, transparent);
    outline-offset: 1px;
  }

  .ctv-admin-btn:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(4px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes pulse-dot {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  @media (max-width: 720px) {
    .ctv-dock {
      flex-direction: column;
      align-items: stretch;
    }

    .ctv-keybar {
      justify-content: flex-start;
    }

    .ctv-dock-actions {
      justify-content: center;
    }

    .create-fields {
      grid-template-columns: 1fr;
    }

    .camera-grid-cctv {
      grid-template-columns: 1fr;
    }
  }
</style>
