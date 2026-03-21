<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { isEnvBrowser } from '../lib/utils/nui.js';
  import { Car, AlertTriangle, Check, Clock } from 'lucide-svelte';

  let mounted = $state(false);
  let vehicles = $state([]);

  onMount(() => {
    mounted = true;
    if (isEnvBrowser()) {
      vehicles = [
        { id: 1, model: 'Vapid Dominator', plate: 'ABC-1234', color: 'Matte Black', year: '2024', status: 'registered', insurance: 'Active', regExpiry: '2026-12-01' },
        { id: 2, model: 'Karin Sultan RS', plate: 'XKR-9981', color: 'Midnight Blue', year: '2023', status: 'registered', insurance: 'Active', regExpiry: '2026-06-15' },
        { id: 3, model: 'Pegassi Zentorno', plate: 'ZEN-0077', color: 'Racing Red', year: '2025', status: 'impounded', insurance: 'Lapsed', regExpiry: '2025-02-28' },
      ];
    }
  });

  function statusColor(status) {
    if (status === 'registered') return 'var(--mdt-success)';
    if (status === 'impounded') return 'var(--mdt-error)';
    return 'var(--mdt-warning)';
  }

  function statusBg(status) {
    if (status === 'registered') return 'rgba(52, 211, 153, 0.1)';
    if (status === 'impounded') return 'rgba(248, 113, 113, 0.1)';
    return 'rgba(251, 191, 36, 0.1)';
  }
</script>

<div class="civ-vehicles" class:mounted>
  <div class="page-header">
    <h1 class="page-title">My Vehicles</h1>
    <span class="page-count font-mono">{vehicles.length} registered</span>
  </div>

  <div class="vehicle-list">
    {#if vehicles.length === 0}
      <div class="empty-state">
        <Car size={32} strokeWidth={1} />
        <span class="empty-text">No vehicles registered to your identity</span>
      </div>
    {:else}
      {#each vehicles as veh, i}
        <div class="vehicle-card" style="--stagger: {i}">
          <div class="veh-icon-wrap">
            <Car size={20} strokeWidth={1.5} />
          </div>

          <div class="veh-main">
            <div class="veh-top-row">
              <span class="veh-model">{veh.model}</span>
              <span
                class="veh-status font-mono"
                style="color: {statusColor(veh.status)}; background: {statusBg(veh.status)};"
              >
                {#if veh.status === 'registered'}
                  <Check size={10} strokeWidth={3} />
                {:else if veh.status === 'impounded'}
                  <AlertTriangle size={10} strokeWidth={2.5} />
                {:else}
                  <Clock size={10} strokeWidth={2.5} />
                {/if}
                {veh.status.toUpperCase()}
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
                <span class="veh-detail-value">{veh.color}</span>
              </div>
              <div class="veh-detail-sep"></div>
              <div class="veh-detail">
                <span class="veh-detail-label">YEAR</span>
                <span class="veh-detail-value">{veh.year}</span>
              </div>
              <div class="veh-detail-sep"></div>
              <div class="veh-detail">
                <span class="veh-detail-label">INSURANCE</span>
                <span class="veh-detail-value">{veh.insurance}</span>
              </div>
              <div class="veh-detail-sep"></div>
              <div class="veh-detail">
                <span class="veh-detail-label">REG. EXPIRES</span>
                <span class="veh-detail-value">{veh.regExpiry}</span>
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
    align-items: baseline;
    justify-content: space-between;
  }

  .page-title {
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--civ-cream, var(--mdt-text));
    letter-spacing: -0.01em;
  }

  .page-count {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.06em;
    text-transform: uppercase;
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
    border: 1px solid var(--civ-border, var(--mdt-border));
    border-radius: var(--mdt-radius);
    animation: cardIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--stagger) * 60ms);
    opacity: 0;
    transition: border-color 0.2s ease;
  }

  .vehicle-card:hover {
    border-color: var(--civ-gold, var(--mdt-accent));
  }

  .veh-icon-wrap {
    width: calc(40px * var(--mdt-scale));
    height: calc(40px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--civ-gold, var(--mdt-accent));
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
    font-size: calc(15px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
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
    background: var(--civ-border, var(--mdt-border));
    flex-shrink: 0;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(48px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    opacity: 0.5;
  }

  .empty-text {
    font-size: calc(13px * var(--mdt-scale));
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(calc(8px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }

  @keyframes cardIn {
    from { opacity: 0; transform: translateY(calc(6px * var(--mdt-scale))); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
