<script>
  import { onDestroy, onMount } from 'svelte';
  import {
    ArrowLeft,
    CarFront,
    Crosshair,
    Eye,
    Gauge,
    Helicopter,
    RefreshCw,
    RotateCcw,
    Search,
    Signal,
    SignalZero,
    SwitchCamera,
    Users,
    Video,
    Volume2,
    VolumeX,
  } from '@lucide/svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';

  const FEED_TYPES = [
    { id: 'bodycam', label: 'Body cameras', short: 'Body', icon: Video },
    { id: 'dashcam', label: 'Vehicle cameras', short: 'Vehicle', icon: CarFront },
    { id: 'air', label: 'Air support', short: 'Air', icon: Helicopter },
  ];

  let selectedType = $state('bodycam');
  let searchQuery = $state('');
  let department = $state('all');
  let loading = $state(true);
  let busyFeedId = $state('');
  let errorMessage = $state('');
  let audioEnabled = $state(false);
  let refreshTimer;

  let liveFeeds = $derived(dataStore.liveFeeds || { bodycams: [], dashcams: [], airFeeds: [] });
  let capabilities = $derived(dataStore.liveFeedCapabilities || {});
  let activeFeed = $derived(dataStore.activeBodycamFeed);
  let feedState = $derived(dataStore.cameraFeedState || { state: 'idle' });
  let liveLocation = $derived(dataStore.bodycamLiveLocation || '');

  let bodycams = $derived(liveFeeds.bodycams || []);
  let dashcams = $derived(liveFeeds.dashcams || []);
  let airFeeds = $derived(liveFeeds.airFeeds || []);
  let lockedAirFeeds = $derived(airFeeds.filter((feed) => feed.tracking?.active).length);
  let liveTracking = $derived(feedState.tracking || activeFeed?.tracking || {});
  let liveVisionMode = $derived(feedState.visionMode || activeFeed?.preview?.visionMode || 'normal');
  let liveFov = $derived(Number(feedState.fov ?? activeFeed?.preview?.fov) || 0);
  let currentFeeds = $derived(
    selectedType === 'bodycam' ? bodycams : selectedType === 'dashcam' ? dashcams : airFeeds,
  );

  let departments = $derived.by(() => {
    const values = new Set();
    bodycams.forEach((feed) => {
      const value = String(feed.department || '').trim().toLowerCase();
      if (value) values.add(value);
    });
    return [...values].sort();
  });

  let filteredFeeds = $derived.by(() => {
    const query = searchQuery.trim().toLowerCase();
    return currentFeeds.filter((feed) => {
      if (
        selectedType === 'bodycam' &&
        department !== 'all' &&
        String(feed.department || '').toLowerCase() !== department
      ) {
        return false;
      }
      if (!query) return true;
      return [
        feed.callsign,
        feed.name,
        feed.label,
        feed.plate,
        feed.rank,
        feed.department,
        feed.tracking?.plate,
        feed.tracking?.vehicleLabel,
      ].some((value) => String(value || '').toLowerCase().includes(query));
    });
  });

  let totalViewers = $derived(
    [...bodycams, ...dashcams, ...airFeeds].reduce(
      (total, feed) => total + (Number(feed.viewerCount) || 0),
      0,
    ),
  );

  function countFor(type) {
    if (type === 'bodycam') return bodycams.length;
    if (type === 'dashcam') return dashcams.length;
    return airFeeds.length;
  }

  function titleFor(feed) {
    if (feed.feedType === 'air') return feed.label || feed.callsign || 'Air support';
    if (feed.feedType === 'dashcam') return feed.label || `${feed.callsign || 'Unit'} · ${feed.plate || 'No plate'}`;
    return feed.name || feed.callsign || 'Field unit';
  }

  function detailFor(feed) {
    if (feed.feedType === 'air') {
      return feed.tracking?.active
        ? `Tracking ${feed.tracking.plate || feed.tracking.vehicleLabel || 'target'}`
        : 'No active target lock';
    }
    if (feed.feedType === 'dashcam') return `${feed.name || 'Unknown operator'} · ${feed.plate || 'No plate'}`;
    return `${feed.rank || 'Officer'} · ${String(feed.department || 'police').toUpperCase()}`;
  }

  function airCrewLabel(feed) {
    const crew = [];
    if (feed.operatorSource) crew.push(`Operator ${feed.operatorSource}`);
    if (feed.pilotSource && feed.pilotSource !== feed.operatorSource) crew.push(`Pilot ${feed.pilotSource}`);
    return crew.join(' / ') || 'Crew unavailable';
  }

  function visionLabel(value) {
    const mode = String(value || 'normal').toLowerCase();
    if (mode === 'thermal') return 'Thermal';
    if (mode === 'night' || mode === 'nightvision') return 'Night vision';
    return 'Daylight';
  }

  function typeAvailable(type) {
    if (type === 'bodycam') return capabilities.bodycams !== false;
    if (type === 'dashcam') return capabilities.dashcams !== false;
    return capabilities.airSupport !== false;
  }

  async function refreshFeeds({ quiet = false } = {}) {
    if (!quiet) loading = true;
    errorMessage = '';
    const response = await dataStore.fetchLiveFeeds();
    if (!response?.ok) errorMessage = response?.error || 'Operational feeds could not be loaded.';
    if (!quiet) loading = false;
  }

  async function openFeed(feed, direction = 'front') {
    busyFeedId = feed.feedId;
    errorMessage = '';
    audioEnabled = false;
    const response = await dataStore.viewLiveFeed(feed, direction);
    if (!response?.ok) errorMessage = response?.error || 'The selected feed could not be opened.';
    busyFeedId = '';
  }

  async function closeFeed() {
    busyFeedId = activeFeed?.feedId || 'closing';
    if (audioEnabled) await dataStore.setBodycamAudio(false);
    audioEnabled = false;
    await dataStore.stopCameraView();
    busyFeedId = '';
    await refreshFeeds({ quiet: true });
  }

  async function toggleAudio() {
    const response = await dataStore.setBodycamAudio(!audioEnabled);
    if (response?.ok) {
      audioEnabled = response.enabled === true;
    } else {
      errorMessage = response?.error || 'Proximity audio is unavailable.';
    }
  }

  async function toggleDirection() {
    const response = await dataStore.cameraControl('toggle_direction');
    if (response?.ok && activeFeed) {
      const next = feedState.direction === 'rear' ? 'front' : 'rear';
      dataStore.cameraFeedState = { direction: next };
      dataStore.activeBodycamFeed = { ...activeFeed, direction: next };
    }
  }

  onMount(async () => {
    await refreshFeeds();
    refreshTimer = window.setInterval(() => {
      if (!document.hidden && !activeFeed) void refreshFeeds({ quiet: true });
    }, 30_000);
  });

  onDestroy(() => {
    if (refreshTimer) window.clearInterval(refreshTimer);
    if (activeFeed) void dataStore.stopCameraView();
  });
</script>

{#if activeFeed}
  <section class="live-stage" aria-label={`${titleFor(activeFeed)} live feed`}>
    <div class="live-topbar">
      <div class="live-identity">
        <span class="live-kicker font-mono">CORTEX VISUAL LINK</span>
        <strong>{titleFor(activeFeed)}</strong>
        <span>{detailFor(activeFeed)}</span>
      </div>
      <div class="live-signal" class:signal-warning={feedState.state === 'stale'} role="status">
        {#if feedState.state === 'stale'}
          <SignalZero size={15} />
          <span>Signal delayed</span>
        {:else}
          <Signal size={15} />
          <span>{feedState.state === 'connecting' ? 'Connecting' : 'Secure mirror'}</span>
        {/if}
      </div>
    </div>

    <div class="live-reticle" aria-hidden="true">
      <span></span>
      <span></span>
    </div>

    <div class="live-telemetry font-mono">
      <span>{activeFeed.feedId}</span>
      {#if activeFeed.feedType === 'dashcam'}
        <span>{String(feedState.direction || activeFeed.direction || 'front').toUpperCase()} CAMERA</span>
        {#if feedState.speed != null}<span>{Math.round(Number(feedState.speed) * 2.23694)} MPH</span>{/if}
      {:else if activeFeed.feedType === 'air'}
        <span>{String(liveVisionMode).toUpperCase()}</span>
        <span>FOV {Math.round(liveFov)}°</span>
      {:else}
        <span>BODY CAMERA</span>
      {/if}
      <span>{liveLocation || 'Resolving location…'}</span>
    </div>

    <div class="live-console">
      <div class="console-copy">
        <span class="console-label font-mono">
          {#if activeFeed.feedType === 'air'}READ-ONLY POLCAM MIRROR{:else}LIVE CAMERA CONTROLS{/if}
        </span>
        {#if feedState.state === 'stale'}
          <p>{feedState.detail || 'The source has not delivered a fresh frame yet.'}</p>
        {:else if activeFeed.feedType === 'air' && liveTracking.active}
          <p>
            Target lock: {liveTracking.plate || liveTracking.vehicleLabel || 'unidentified target'}.
            Operator camera, zoom, and vision changes stay synchronized automatically.
          </p>
        {:else if activeFeed.feedType === 'bodycam'}
          <p>WASD adjusts the local observation angle. Q/E zooms and R resets the view.</p>
        {:else if activeFeed.feedType === 'dashcam'}
          <p>Switch between the forward and rear vehicle mounts. Q/E adjusts local zoom.</p>
        {:else}
          <p>Camera transforms are controlled by the active PolCam operator.</p>
        {/if}
      </div>

      <div class="console-actions">
        {#if activeFeed.feedType === 'dashcam'}
          <button type="button" class="btn-secondary" onclick={toggleDirection}>
            <SwitchCamera size={15} />
            {feedState.direction === 'rear' ? 'Front camera' : 'Rear camera'}
          </button>
        {/if}
        {#if activeFeed.feedType === 'bodycam' && capabilities.bodycamAudio && capabilities.bodycamAudioMode === 'proximity'}
          <button type="button" class="btn-secondary" class:active-control={audioEnabled} onclick={toggleAudio}>
            {#if audioEnabled}<Volume2 size={15} />{:else}<VolumeX size={15} />{/if}
            Nearby voice {audioEnabled ? 'on' : 'off'}
          </button>
        {/if}
        {#if activeFeed.feedType !== 'air'}
          <button type="button" class="icon-control" onclick={() => dataStore.cameraControl('reset')} aria-label="Reset camera view" title="Reset camera view">
            <RotateCcw size={15} />
          </button>
        {/if}
        <button type="button" class="btn-exit" onclick={closeFeed} disabled={busyFeedId !== ''}>
          <ArrowLeft size={15} />
          Return to feeds
        </button>
      </div>
    </div>
  </section>
{:else}
  <div class="camera-page">
    <section class="status-strip" aria-label="Camera system summary">
      <div><Video size={14} /><span>Body</span><strong>{bodycams.length}</strong></div>
      <div><CarFront size={14} /><span>Vehicle</span><strong>{dashcams.length}</strong></div>
      <div class:offline={!capabilities.airSupportConnected}><Helicopter size={14} /><span>Air</span><strong>{airFeeds.length}</strong></div>
      <div><Users size={14} /><span>Viewers</span><strong>{totalViewers}</strong></div>
      <div class="system-state" class:offline={!capabilities.airSupportConnected}>
        {#if capabilities.airSupportConnected}<Signal size={14} /> PolCam linked{:else}<SignalZero size={14} /> PolCam offline{/if}
      </div>
      <button type="button" class="refresh-button" onclick={() => refreshFeeds()} disabled={loading} aria-label="Refresh camera feeds" title="Refresh camera feeds">
        <span class:spin={loading}><RefreshCw size={14} /></span>
      </button>
    </section>

    {#if errorMessage || feedState.state === 'disconnected'}
      <div class="notice notice-error" role="alert">
        <SignalZero size={16} />
        <span>{errorMessage || feedState.detail || 'The live feed disconnected.'}</span>
      </div>
    {:else if feedState.availabilityMessage}
      <div class="notice" role="status">
        <Signal size={16} />
        <span>{feedState.availabilityMessage}</span>
      </div>
    {/if}

    <div class="workbench">
      <nav class="feed-nav" aria-label="Feed types">
        {#each FEED_TYPES as type (type.id)}
          {@const TypeIcon = type.icon}
          <button
            type="button"
            class:active={selectedType === type.id}
            disabled={!typeAvailable(type.id)}
            onclick={() => { selectedType = type.id; searchQuery = ''; department = 'all'; }}
          >
            <TypeIcon size={16} />
            <span>{type.label}</span>
            <strong class="font-mono">{countFor(type.id)}</strong>
          </button>
        {/each}
        <div class="nav-note">
          <span class="font-mono">ACCESS RULE</span>
          <p>Only on-duty feeds in your routing bucket are listed. Cross-bucket viewing is opt-in in server configuration.</p>
        </div>
      </nav>

      <section class="feed-register">
        <div class="register-toolbar">
          <div>
            <span class="register-kicker font-mono">{FEED_TYPES.find((type) => type.id === selectedType)?.short} registry</span>
            <h2>{FEED_TYPES.find((type) => type.id === selectedType)?.label}</h2>
          </div>
          <div class="filter-row">
            {#if selectedType === 'bodycam' && departments.length > 1}
              <label>
                <span class="sr-only">Department</span>
                <select bind:value={department}>
                  <option value="all">All departments</option>
                  {#each departments as value (value)}<option value={value}>{value.toUpperCase()}</option>{/each}
                </select>
              </label>
            {/if}
            <label class="search-field">
              <Search size={14} />
              <span class="sr-only">Search feeds</span>
              <input bind:value={searchQuery} type="search" placeholder="Search unit, operator, plate" />
            </label>
          </div>
        </div>

        {#if selectedType === 'air' && capabilities.airSupportConnected}
          <div class="air-summary" aria-label="Air support downlink summary">
            <div><span class="font-mono">DOWNLINK</span><strong>Ready</strong></div>
            <div><span class="font-mono">AIRCRAFT</span><strong>{airFeeds.length} active</strong></div>
            <div><span class="font-mono">TARGET LOCKS</span><strong>{lockedAirFeeds}</strong></div>
            <p>Read-only telemetry mirrors authorized PolCam crews in your routing bucket.</p>
          </div>
        {/if}

        {#if loading}
          <div class="loading-state" aria-busy="true" aria-live="polite">
            <RefreshCw size={20} class="spin" />
            <span>Loading authorised feeds…</span>
          </div>
        {:else if selectedType === 'air' && !capabilities.airSupportConnected}
          <div class="empty-state">
            <SignalZero size={30} />
            <h3>Cortex PolCam is not connected</h3>
            <p>Start the configured PolCam resource to publish synchronized helicopter-camera feeds.</p>
          </div>
        {:else if filteredFeeds.length === 0}
          <div class="empty-state">
            {#if selectedType === 'air'}<Helicopter size={30} />{:else}<SignalZero size={30} />{/if}
            <h3>{selectedType === 'air' ? 'Downlink ready, no aircraft online' : 'No authorised feeds'}</h3>
            <p>
              {currentFeeds.length
                ? 'No feeds match the current filters.'
                : selectedType === 'air'
                  ? 'An aircraft appears here when an authorized PolCam operator activates its camera in your routing bucket.'
                  : 'No on-duty source is currently publishing this camera type.'}
            </p>
          </div>
        {:else if selectedType === 'air'}
          <div class="air-table" role="table" aria-label="Air support live feeds">
            <div class="air-table-head font-mono" role="row">
              <span role="columnheader">Aircraft</span>
              <span role="columnheader">Crew</span>
              <span role="columnheader">Optics</span>
              <span role="columnheader">Target</span>
              <span role="columnheader">Viewers</span>
              <span role="columnheader" class="sr-only">Action</span>
            </div>
            {#each filteredFeeds as feed (feed.feedId)}
              <div class="air-row" role="row">
                <div class="aircraft-cell" role="cell">
                  <span class="channel-id font-mono">{feed.feedId}</span>
                  <strong>{feed.callsign || feed.label || 'Air unit'}</strong>
                  <small>{feed.label || 'Cortex PolCam'}</small>
                </div>
                <div class="air-crew-cell" role="cell">
                  <strong>{feed.callsign || 'Unassigned aircraft'}</strong>
                  <small>{airCrewLabel(feed)}</small>
                </div>
                <div class="air-optics-cell" role="cell">
                  <strong>{visionLabel(feed.preview?.visionMode)}</strong>
                  <small>FOV {Math.round(Number(feed.preview?.fov) || 0)}°</small>
                </div>
                <div class="air-target-cell" class:locked={feed.tracking?.active} role="cell">
                  <Crosshair size={14} />
                  <div>
                    <strong>{feed.tracking?.active ? 'Target locked' : 'Scanning'}</strong>
                    <small>{feed.tracking?.active ? (feed.tracking.plate || feed.tracking.vehicleLabel || 'Unidentified') : 'No active lock'}</small>
                  </div>
                </div>
                <div class="viewers-cell font-mono" role="cell">{Number(feed.viewerCount) || 0}</div>
                <button
                  type="button"
                  class="watch-button"
                  onclick={() => openFeed(feed)}
                  disabled={busyFeedId !== ''}
                  aria-label={`Watch ${titleFor(feed)}`}
                >
                  {#if busyFeedId === feed.feedId}<span class="spin"><RefreshCw size={14} /></span>{:else}<Eye size={14} />{/if}
                  Watch
                </button>
              </div>
            {/each}
          </div>
        {:else}
          <div class="feed-table" role="table" aria-label={`${selectedType} live feeds`}>
            <div class="feed-table-head font-mono" role="row">
              <span role="columnheader">Channel</span>
              <span role="columnheader">Operator / source</span>
              <span role="columnheader">State</span>
              <span role="columnheader">Viewers</span>
              <span role="columnheader" class="sr-only">Action</span>
            </div>
            {#each filteredFeeds as feed (feed.feedId)}
              <div class="feed-row" role="row">
                <div class="channel-cell" role="cell">
                  <span class="channel-id font-mono">{feed.feedId}</span>
                  <strong>{feed.callsign || feed.label || 'Unassigned'}</strong>
                </div>
                <div class="source-cell" role="cell">
                  <strong>{titleFor(feed)}</strong>
                  <span>{detailFor(feed)}</span>
                </div>
                <div class="state-cell" role="cell"><Signal size={13} /><span>Live</span></div>
                <div class="viewers-cell font-mono" role="cell">{Number(feed.viewerCount) || 0}</div>
                <button
                  type="button"
                  class="watch-button"
                  onclick={() => openFeed(feed)}
                  disabled={busyFeedId !== ''}
                  aria-label={`Watch ${titleFor(feed)}`}
                >
                  {#if busyFeedId === feed.feedId}<span class="spin"><RefreshCw size={14} /></span>{:else}<Eye size={14} />{/if}
                  Watch
                </button>
              </div>
            {/each}
          </div>
        {/if}

        <footer class="register-footer">
          {#if selectedType === 'bodycam'}
            <Video size={14} /><span>Officers can use <code>/bodycam</code> to opt their feed in or out. Frames transmit only while watched.</span>
          {:else if selectedType === 'dashcam'}
            <Gauge size={14} /><span>Dashcams appear automatically for on-duty drivers of emergency-class vehicles.</span>
          {:else}
            <Crosshair size={14} /><span>Air feeds mirror the operator's position, FOV, vision mode, and tracking state without taking camera control.</span>
          {/if}
        </footer>
      </section>
    </div>
  </div>
{/if}

<style>
  .font-mono { font-family: 'Share Tech Mono', monospace; }
  .sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }

  .camera-page {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale));
    color: var(--mdt-text);
    overflow: hidden;
  }

  .register-kicker {
    display: inline-flex;
    align-items: center;
    gap: calc(7px * var(--mdt-scale));
    color: var(--mdt-accent);
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: .08em;
  }

  button, input, select { font: inherit; }
  button:focus-visible, input:focus-visible, select:focus-visible { outline: 2px solid var(--mdt-accent); outline-offset: 2px; }

  .watch-button, .btn-exit, .btn-secondary, .icon-control {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(7px * var(--mdt-scale));
    min-height: calc(34px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    cursor: pointer;
  }

  .btn-secondary, .icon-control {
    padding: 0 calc(11px * var(--mdt-scale));
    border: 1px solid var(--mdt-border-2);
    background: var(--mdt-surface-2);
    color: var(--mdt-text-dim);
  }

  .btn-secondary:hover, .icon-control:hover { border-color: var(--mdt-accent); color: var(--mdt-text); }
  button:disabled { opacity: .45; cursor: not-allowed; }

  .status-strip {
    display: flex;
    align-items: stretch;
    min-height: calc(42px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface);
    overflow: hidden;
  }
  .status-strip > div { display: flex; align-items: center; gap: calc(7px * var(--mdt-scale)); padding: 0 calc(14px * var(--mdt-scale)); border-right: 1px solid var(--mdt-border); color: var(--mdt-text-muted); font-size: calc(11px * var(--mdt-scale)); }
  .status-strip strong { color: var(--mdt-text); font-variant-numeric: tabular-nums; }
  .status-strip .system-state { margin-left: auto; border-right: 0; color: var(--mdt-success); }
  .status-strip .offline { color: var(--mdt-warning); }
  .status-strip .refresh-button { display: grid; place-items: center; width: calc(42px * var(--mdt-scale)); flex: 0 0 calc(42px * var(--mdt-scale)); border: 0; border-left: 1px solid var(--mdt-border); background: transparent; color: var(--mdt-text-muted); cursor: pointer; }
  .status-strip .refresh-button:hover:not(:disabled) { color: var(--mdt-accent); background: var(--mdt-surface-2); }

  .notice { display: flex; align-items: center; gap: calc(9px * var(--mdt-scale)); padding: calc(9px * var(--mdt-scale)) calc(11px * var(--mdt-scale)); border: 1px solid var(--mdt-border-2); border-radius: var(--mdt-radius-sm); color: var(--mdt-text-dim); background: var(--mdt-surface); font-size: calc(11px * var(--mdt-scale)); }
  .notice-error { border-color: color-mix(in srgb, var(--mdt-error) 45%, var(--mdt-border)); color: var(--mdt-error); }

  .workbench { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(calc(190px * var(--mdt-scale)), calc(230px * var(--mdt-scale))) minmax(0, 1fr); gap: calc(10px * var(--mdt-scale)); }
  .feed-nav, .feed-register { border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); background: var(--mdt-surface); overflow: hidden; }
  .feed-nav { display: flex; flex-direction: column; min-width: 0; }
  .feed-nav > button { display: grid; grid-template-columns: calc(18px * var(--mdt-scale)) 1fr auto; align-items: center; gap: calc(9px * var(--mdt-scale)); width: 100%; min-height: calc(46px * var(--mdt-scale)); padding: 0 calc(12px * var(--mdt-scale)); border: 0; border-bottom: 1px solid var(--mdt-border); border-left: 2px solid transparent; border-radius: 0; background: transparent; color: var(--mdt-text-muted); text-align: left; cursor: pointer; }
  .feed-nav > button:hover:not(:disabled) { color: var(--mdt-text); background: var(--mdt-surface-2); }
  .feed-nav > button.active { color: var(--mdt-text); border-left-color: var(--mdt-accent); background: var(--mdt-surface-2); }
  .feed-nav > button strong { color: var(--mdt-text-dim); font-size: calc(11px * var(--mdt-scale)); }
  .nav-note { margin-top: auto; padding: calc(14px * var(--mdt-scale)); border-top: 1px solid var(--mdt-border); }
  .nav-note > span { color: var(--mdt-accent); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .08em; }
  .nav-note p { margin: calc(7px * var(--mdt-scale)) 0 0; color: var(--mdt-text-muted); font-size: calc(11px * var(--mdt-scale)); line-height: 1.5; }

  .feed-register { min-width: 0; min-height: 0; display: flex; flex-direction: column; }
  .register-toolbar { display: flex; align-items: center; justify-content: space-between; gap: calc(14px * var(--mdt-scale)); min-height: calc(58px * var(--mdt-scale)); padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .register-toolbar h2 { margin: calc(3px * var(--mdt-scale)) 0 0; font-size: calc(16px * var(--mdt-scale)); }
  .filter-row { display: flex; align-items: center; gap: calc(8px * var(--mdt-scale)); }
  select, .search-field { min-height: calc(34px * var(--mdt-scale)); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text); }
  select { padding: 0 calc(9px * var(--mdt-scale)); font-size: calc(11px * var(--mdt-scale)); }
  .search-field { display: flex; align-items: center; gap: calc(7px * var(--mdt-scale)); width: min(calc(280px * var(--mdt-scale)), 36vw); padding: 0 calc(9px * var(--mdt-scale)); color: var(--mdt-text-muted); }
  .search-field:focus-within { border-color: var(--mdt-accent); }
  .search-field input { flex: 1; min-width: 0; border: 0; background: transparent; color: var(--mdt-text); font-size: calc(11px * var(--mdt-scale)); }

  .air-summary { display: grid; grid-template-columns: repeat(3, auto) minmax(220px, 1fr); align-items: center; gap: 0; min-height: calc(48px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); background: var(--mdt-surface-2); }
  .air-summary > div { display: flex; flex-direction: column; gap: calc(2px * var(--mdt-scale)); padding: calc(7px * var(--mdt-scale)) calc(14px * var(--mdt-scale)); border-right: 1px solid var(--mdt-border); }
  .air-summary span { color: var(--mdt-text-muted); font-size: calc(9px * var(--mdt-scale)); letter-spacing: .08em; }
  .air-summary strong { color: var(--mdt-text-dim); font-size: calc(11px * var(--mdt-scale)); font-weight: 600; }
  .air-summary > div:first-child strong { color: var(--mdt-success); }
  .air-summary p { justify-self: end; max-width: 58ch; margin: 0; padding: 0 calc(14px * var(--mdt-scale)); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); line-height: 1.4; text-align: right; }

  .feed-table, .air-table { flex: 1; min-height: 0; overflow-y: auto; }
  .feed-table-head, .feed-row { display: grid; grid-template-columns: minmax(130px, .8fr) minmax(190px, 1.45fr) minmax(80px, .45fr) minmax(60px, .25fr) minmax(92px, auto); align-items: center; gap: calc(10px * var(--mdt-scale)); }
  .feed-table-head { position: sticky; top: 0; z-index: 2; min-height: calc(34px * var(--mdt-scale)); padding: 0 calc(12px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); background: var(--mdt-surface-2); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .06em; text-transform: uppercase; }
  .feed-row { min-height: calc(62px * var(--mdt-scale)); padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .feed-row:hover { background: color-mix(in srgb, var(--mdt-surface-2) 70%, transparent); }
  .channel-cell, .source-cell { min-width: 0; display: flex; flex-direction: column; gap: calc(3px * var(--mdt-scale)); }
  .channel-id { color: var(--mdt-accent); font-size: calc(10px * var(--mdt-scale)); }
  .channel-cell strong, .source-cell strong { overflow: hidden; color: var(--mdt-text); font-size: calc(12px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .source-cell span { overflow: hidden; color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .state-cell { display: inline-flex; align-items: center; gap: calc(5px * var(--mdt-scale)); color: var(--mdt-success); font-size: calc(10px * var(--mdt-scale)); }
  .viewers-cell { color: var(--mdt-text-dim); font-size: calc(11px * var(--mdt-scale)); }
  .watch-button, .btn-exit { padding: 0 calc(12px * var(--mdt-scale)); border: 0; background: var(--mdt-accent); color: var(--mdt-bg); font-size: calc(10px * var(--mdt-scale)); font-weight: 700; }
  .watch-button:hover:not(:disabled), .btn-exit:hover:not(:disabled) { opacity: .9; }

  .air-table-head, .air-row { display: grid; grid-template-columns: minmax(130px, .8fr) minmax(150px, .9fr) minmax(110px, .65fr) minmax(150px, 1fr) minmax(56px, .25fr) minmax(92px, auto); align-items: center; gap: calc(10px * var(--mdt-scale)); }
  .air-table-head { position: sticky; top: 0; z-index: 2; min-height: calc(34px * var(--mdt-scale)); padding: 0 calc(12px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); background: var(--mdt-surface-2); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .06em; text-transform: uppercase; }
  .air-row { min-height: calc(66px * var(--mdt-scale)); padding: calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .air-row:hover { background: color-mix(in srgb, var(--mdt-surface-2) 70%, transparent); }
  .aircraft-cell, .air-crew-cell, .air-optics-cell { min-width: 0; display: flex; flex-direction: column; gap: calc(3px * var(--mdt-scale)); }
  .aircraft-cell strong, .air-crew-cell strong, .air-optics-cell strong, .air-target-cell strong { overflow: hidden; color: var(--mdt-text); font-size: calc(12px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .aircraft-cell small, .air-crew-cell small, .air-optics-cell small, .air-target-cell small { overflow: hidden; color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .air-target-cell { min-width: 0; display: flex; align-items: center; gap: calc(7px * var(--mdt-scale)); color: var(--mdt-text-muted); }
  .air-target-cell > div { min-width: 0; display: flex; flex-direction: column; gap: calc(3px * var(--mdt-scale)); }
  .air-target-cell.locked, .air-target-cell.locked strong { color: var(--mdt-accent); }

  .loading-state, .empty-state { flex: 1; min-height: calc(220px * var(--mdt-scale)); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: calc(9px * var(--mdt-scale)); padding: calc(24px * var(--mdt-scale)); color: var(--mdt-text-muted); text-align: center; }
  .empty-state h3 { margin: calc(3px * var(--mdt-scale)) 0 0; color: var(--mdt-text-dim); font-size: calc(14px * var(--mdt-scale)); }
  .empty-state p { max-width: 48ch; margin: 0; font-size: calc(11px * var(--mdt-scale)); line-height: 1.5; }
  .register-footer { display: flex; align-items: center; gap: calc(8px * var(--mdt-scale)); min-height: calc(38px * var(--mdt-scale)); padding: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border-top: 1px solid var(--mdt-border); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); line-height: 1.4; }
  .register-footer code { color: var(--mdt-accent); }

  .live-stage { position: fixed; inset: 0; z-index: 60; display: flex; flex-direction: column; justify-content: space-between; padding: calc(20px * var(--mdt-scale)); pointer-events: none; color: var(--mdt-text); }
  .live-topbar, .live-console { pointer-events: auto; border: 1px solid color-mix(in srgb, var(--mdt-text) 16%, transparent); border-radius: var(--mdt-radius); background: color-mix(in srgb, var(--mdt-bg) 88%, transparent); box-shadow: 0 calc(10px * var(--mdt-scale)) calc(30px * var(--mdt-scale)) color-mix(in srgb, var(--mdt-bg) 60%, transparent); }
  .live-topbar { align-self: stretch; display: flex; align-items: center; justify-content: space-between; gap: calc(14px * var(--mdt-scale)); padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border-left: 3px solid var(--mdt-accent); }
  .live-identity { min-width: 0; display: grid; grid-template-columns: auto auto minmax(0, 1fr); align-items: baseline; gap: calc(7px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); }
  .live-kicker { grid-column: 1 / -1; color: var(--mdt-accent); font-size: calc(9px * var(--mdt-scale)); letter-spacing: .1em; }
  .live-identity strong { font-size: calc(13px * var(--mdt-scale)); }
  .live-identity > span:last-child { overflow: hidden; color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .live-signal { display: inline-flex; align-items: center; gap: calc(7px * var(--mdt-scale)); color: var(--mdt-success); font-family: 'Share Tech Mono', monospace; font-size: calc(9px * var(--mdt-scale)); letter-spacing: .08em; text-transform: uppercase; }
  .live-signal.signal-warning { color: var(--mdt-warning); }
  .live-reticle { position: absolute; left: 50%; top: 50%; width: calc(34px * var(--mdt-scale)); height: calc(34px * var(--mdt-scale)); transform: translate(-50%, -50%); opacity: .55; }
  .live-reticle span:first-child { position: absolute; left: 50%; top: 0; width: 1px; height: 100%; background: var(--mdt-text); }
  .live-reticle span:last-child { position: absolute; left: 0; top: 50%; width: 100%; height: 1px; background: var(--mdt-text); }
  .live-telemetry { position: absolute; left: calc(20px * var(--mdt-scale)); bottom: calc(150px * var(--mdt-scale)); display: flex; flex-wrap: wrap; gap: calc(6px * var(--mdt-scale)); max-width: calc(70vw); }
  .live-telemetry span { padding: calc(4px * var(--mdt-scale)) calc(7px * var(--mdt-scale)); border: 1px solid color-mix(in srgb, var(--mdt-text) 18%, transparent); border-radius: var(--mdt-radius-sm); background: color-mix(in srgb, var(--mdt-bg) 78%, transparent); color: var(--mdt-text-dim); font-size: calc(9px * var(--mdt-scale)); }
  .live-console { align-self: stretch; display: flex; align-items: center; justify-content: space-between; gap: calc(18px * var(--mdt-scale)); padding: calc(12px * var(--mdt-scale)); }
  .console-copy { min-width: 0; }
  .console-label { color: var(--mdt-accent); font-size: calc(9px * var(--mdt-scale)); letter-spacing: .1em; }
  .console-copy p { margin: calc(5px * var(--mdt-scale)) 0 0; color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); line-height: 1.45; }
  .console-actions { display: flex; align-items: center; justify-content: flex-end; gap: calc(7px * var(--mdt-scale)); flex-wrap: wrap; }
  .icon-control { width: calc(34px * var(--mdt-scale)); padding: 0; }
  .active-control { border-color: var(--mdt-accent); color: var(--mdt-accent); }

  .spin { animation: spin .8s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  @media (prefers-reduced-motion: reduce) { .spin { animation: none; } }

  @media (max-width: 860px) {
    .camera-page { overflow-y: auto; }
    .status-strip { overflow-x: auto; }
    .status-strip .system-state { margin-left: 0; min-width: max-content; }
    .workbench { grid-template-columns: 1fr; }
    .feed-nav { display: grid; grid-template-columns: repeat(3, 1fr); }
    .feed-nav > button { grid-template-columns: auto 1fr auto; border-bottom: 0; border-right: 1px solid var(--mdt-border); }
    .nav-note { display: none; }
    .register-toolbar { align-items: stretch; flex-direction: column; }
    .filter-row, .search-field { width: 100%; }
    .feed-table-head { display: none; }
    .air-summary { grid-template-columns: repeat(3, 1fr); }
    .air-summary p { display: none; }
    .air-table-head { display: none; }
    .feed-row { grid-template-columns: minmax(0, 1fr) auto; gap: calc(7px * var(--mdt-scale)); }
    .channel-cell, .source-cell { grid-column: 1; }
    .state-cell, .viewers-cell { display: none; }
    .watch-button { grid-column: 2; grid-row: 1 / span 2; }
    .air-row { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto; gap: calc(8px * var(--mdt-scale)); }
    .aircraft-cell { grid-column: 1; grid-row: 1; }
    .air-crew-cell { grid-column: 2; grid-row: 1; }
    .air-optics-cell { grid-column: 1; grid-row: 2; }
    .air-target-cell { grid-column: 2; grid-row: 2; }
    .air-row .viewers-cell { display: none; }
    .air-row .watch-button { grid-column: 3; grid-row: 1 / span 2; }
    .live-console { align-items: stretch; flex-direction: column; }
    .console-actions { justify-content: flex-start; }
    .live-telemetry { bottom: calc(205px * var(--mdt-scale)); max-width: calc(100vw - 40px * var(--mdt-scale)); }
  }

  @media (max-width: 560px) {
    .status-strip > div { padding: 0 calc(10px * var(--mdt-scale)); }
    .status-strip > div span { display: none; }
    .feed-nav > button { grid-template-columns: 1fr; justify-items: center; min-height: calc(58px * var(--mdt-scale)); text-align: center; }
    .feed-nav > button span { font-size: calc(9px * var(--mdt-scale)); }
    .air-summary { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    .air-summary > div { padding-inline: calc(8px * var(--mdt-scale)); }
    .air-row { grid-template-columns: minmax(0, 1fr) auto; }
    .air-crew-cell, .air-optics-cell { display: none; }
    .air-target-cell { grid-column: 1; grid-row: 2; }
    .air-row .watch-button { grid-column: 2; grid-row: 1 / span 2; }
    .live-stage { padding: calc(10px * var(--mdt-scale)); }
    .live-topbar { align-items: flex-start; }
    .live-identity { grid-template-columns: 1fr; }
    .live-telemetry { left: calc(10px * var(--mdt-scale)); bottom: calc(245px * var(--mdt-scale)); }
    .console-actions > button { flex: 1 1 auto; }
  }
</style>
