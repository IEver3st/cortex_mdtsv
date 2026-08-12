<script>
  import { onMount } from 'svelte';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';
  import { isUnitOnDuty } from '../utils/helpers.js';

  let { calls = [], units = [], selectedCallId = null, onSelectCall = () => {} } = $props();

  let mapContainer;
  let mapInstance = null;
  let callMarkers = new Map();
  let unitMarkers = new Map();
  let hasInitialView = false;
  let lastFocusKey = null;

  const OX_MAP_CENTER = [-119.43, 58.84];
  const OX_LAT_PR_100 = 1.421;
  const OX_MIN_ZOOM = 2;
  const OX_MAX_ZOOM = 7;
  const OX_STARTUP_ZOOM = 5;
  const OX_MAP_BOUNDS = L.latLngBounds(L.latLng(0.0, 128.0), L.latLng(-192.0, 0.0));

  function gameToMap(x, y) {
    const scale = OX_LAT_PR_100 / 100;
    return [OX_MAP_CENTER[0] + scale * y, OX_MAP_CENTER[1] + scale * x];
  }

  function severityTone(severity) {
    const s = String(severity || '').trim().toLowerCase();
    if (s === 'critical') return 'critical';
    if (s === 'high') return 'high';
    if (s === 'low') return 'low';
    return 'medium';
  }

  function createCallIcon(tone, selected) {
    const toneColors = {
      critical: '#ef4444',
      high: '#f97316',
      medium: '#eab308',
      low: '#22c55e',
    };
    const color = toneColors[tone] || toneColors.medium;
    const size = selected ? 24 : 18;
    const border = selected ? '3px solid #fff' : '2px solid rgba(255,255,255,0.6)';
    const shadow = selected ? '0 0 12px ' + color : '0 0 6px rgba(0,0,0,0.4)';

    return L.divIcon({
      className: 'dispatch-call-marker',
      html: `<span style="
        display:block;width:${size}px;height:${size}px;
        background:${color};border:${border};border-radius:50%;
        box-shadow:${shadow};
      "></span>`,
      iconSize: [size, size],
      iconAnchor: [size / 2, size / 2],
    });
  }

  function createUnitIcon(active) {
    const color = active ? '#3b82f6' : '#6b7280';
    return L.divIcon({
      className: 'dispatch-unit-marker',
      html: `<span style="
        display:block;width:12px;height:12px;
        background:${color};border:2px solid rgba(255,255,255,0.7);border-radius:50%;
        box-shadow:0 0 4px rgba(0,0,0,0.3);
      "></span>`,
      iconSize: [12, 12],
      iconAnchor: [6, 6],
    });
  }

  function isUnitActive(unit) {
    return isUnitOnDuty(unit?.status);
  }

  function createPopup(title, subtitle) {
    const wrapper = document.createElement('div');
    wrapper.style.fontSize = '12px';
    const heading = document.createElement('strong');
    heading.textContent = String(title || 'Unknown');
    wrapper.append(heading, document.createElement('br'), document.createTextNode(String(subtitle || '')));
    return wrapper;
  }

  onMount(() => {
    if (!mapContainer) return;

    mapInstance = L.map(mapContainer, {
      center: OX_MAP_CENTER,
      zoom: OX_STARTUP_ZOOM,
      minZoom: OX_MIN_ZOOM,
      maxZoom: OX_MAX_ZOOM,
      maxBounds: OX_MAP_BOUNDS,
      maxBoundsViscosity: 1.0,
      zoomControl: false,
      preferCanvas: true,
      crs: L.CRS.Simple,
      attributionControl: false,
    });

    requestAnimationFrame(() => {
      mapInstance.invalidateSize(false);
    });

    return () => {
      mapInstance.remove();
      mapInstance = null;
    };
  });

  export function focusCoords(coords, zoom = OX_MAX_ZOOM) {
    if (!mapInstance || !coords) return;
    const point = gameToMap(coords.x, coords.y);
    mapInstance.flyTo(point, zoom, { duration: 0.45 });
  }

  $effect(() => {
    if (!mapInstance) return;

    // Update call markers
    const currentCallIds = new Set();
    for (const call of calls) {
      if (!call.coords) continue;
      const latlng = gameToMap(call.coords.x, call.coords.y);
      const tone = severityTone(call.severity);
      const selected = call.id === selectedCallId;
      currentCallIds.add(call.id);

      if (callMarkers.has(call.id)) {
        const marker = callMarkers.get(call.id);
        marker.setLatLng(latlng);
        marker.setIcon(createCallIcon(tone, selected));
        marker.setPopupContent(createPopup(`${call.code || ''} - ${call.title || ''}`, call.location));
      } else {
        const marker = L.marker(latlng, { icon: createCallIcon(tone, selected) });
        marker.on('click', () => onSelectCall(call.id));
        marker.bindPopup(createPopup(`${call.code || ''} - ${call.title || ''}`, call.location));
        marker.addTo(mapInstance);
        callMarkers.set(call.id, marker);
      }
    }

    // Remove stale call markers
    for (const [id, marker] of callMarkers) {
      if (!currentCallIds.has(id)) {
        marker.remove();
        callMarkers.delete(id);
      }
    }
  });

  $effect(() => {
    if (!mapInstance) return;

    // Update unit markers
    const currentSources = new Set();
    for (const unit of units) {
      if (!unit.coords) continue;
      const latlng = gameToMap(unit.coords.x, unit.coords.y);
      const active = isUnitActive(unit);
      const key = String(unit.unitId || unit.source || unit.callsign);
      currentSources.add(key);

      if (unitMarkers.has(key)) {
        const marker = unitMarkers.get(key);
        marker.setLatLng(latlng);
        marker.setIcon(createUnitIcon(active));
        marker.setPopupContent(createPopup(unit.callsign || unit.name, unit.availability));
      } else {
        const marker = L.marker(latlng, { icon: createUnitIcon(active) });
        marker.bindPopup(createPopup(unit.callsign || unit.name, unit.availability));
        marker.addTo(mapInstance);
        unitMarkers.set(key, marker);
      }
    }

    // Remove stale unit markers
    for (const [key, marker] of unitMarkers) {
      if (!currentSources.has(key)) {
        marker.remove();
        unitMarkers.delete(key);
      }
    }
  });

  // Focus on selected call
  $effect(() => {
    if (!mapInstance || !selectedCallId) {
      lastFocusKey = null;
      return;
    }

    const call = calls.find((c) => c.id === selectedCallId);
    if (!call?.coords) return;

    const latlng = gameToMap(call.coords.x, call.coords.y);
    const focusKey = `${call.id}:${latlng[0]}:${latlng[1]}`;
    if (lastFocusKey === focusKey) return;

    mapInstance.stop();
    if (lastFocusKey) {
      mapInstance.flyTo(latlng, OX_MAX_ZOOM, { duration: 0.35 });
    } else {
      mapInstance.setView(latlng, OX_MAX_ZOOM, { animate: false });
    }
    hasInitialView = true;
    lastFocusKey = focusKey;
  });

  // Initial viewport fit
  $effect(() => {
    if (!mapInstance || hasInitialView || selectedCallId) return;

    const allPoints = [];
    for (const call of calls) {
      if (call.coords) allPoints.push(gameToMap(call.coords.x, call.coords.y));
    }
    for (const unit of units) {
      if (unit.coords) allPoints.push(gameToMap(unit.coords.x, unit.coords.y));
    }

    if (allPoints.length === 0) return;

    mapInstance.stop();
    if (allPoints.length === 1) {
      mapInstance.setView(allPoints[0], OX_STARTUP_ZOOM, { animate: false });
    } else {
      mapInstance.fitBounds(L.latLngBounds(allPoints), {
        animate: false,
        maxZoom: OX_STARTUP_ZOOM,
        padding: [28, 28],
      });
    }
    hasInitialView = true;
  });
</script>

<div class="dispatch-map-wrap" bind:this={mapContainer}></div>

<style>
  .dispatch-map-wrap {
    width: 100%;
    height: 100%;
    min-height: 200px;
    border-radius: var(--mdt-radius);
    overflow: hidden;
    background-color: var(--mdt-bg);
    background-image:
      linear-gradient(rgba(148, 163, 184, 0.1) 1px, transparent 1px),
      linear-gradient(90deg, rgba(148, 163, 184, 0.1) 1px, transparent 1px),
      radial-gradient(circle at 50% 48%, rgba(59, 130, 246, 0.11), transparent 58%);
    background-size: 32px 32px, 32px 32px, 100% 100%;
  }

  :global(.dispatch-call-marker),
  :global(.dispatch-unit-marker) {
    background: none !important;
    border: none !important;
  }

  :global(.leaflet-popup-content-wrapper) {
    background: rgba(28, 30, 38, 0.95) !important;
    color: #e2e8f0 !important;
    border: 1px solid rgba(99, 102, 241, 0.3) !important;
    border-radius: 8px !important;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5) !important;
    font-family: inherit !important;
  }

  :global(.leaflet-popup-tip) {
    background: rgba(28, 30, 38, 0.95) !important;
    border: 1px solid rgba(99, 102, 241, 0.3) !important;
  }

  :global(.leaflet-popup-close-button) {
    color: #94a3b8 !important;
  }

  :global(.leaflet-control-zoom) {
    display: none !important;
  }
</style>
