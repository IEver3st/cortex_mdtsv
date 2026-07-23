<script>
  import { onMount } from 'svelte';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import {
    Building2,
    FileSignature,
    Car,
    UserCheck,
    MapPin,
    Phone,
    ChevronRight,
    Clock,
    ScrollText,
  } from '@lucide/svelte';

  let mounted = $state(false);

  const services = [
    { id: 'id-renewal',   label: 'ID Card Renewal',           icon: UserCheck,     desc: 'Renew your Los Santos citizen identification card',     status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'veh-reg',      label: 'Vehicle Registration',      icon: Car,           desc: 'Register a new vehicle or renew existing registration', status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'name-change',  label: 'Legal Name Change',         icon: FileSignature, desc: 'Submit a petition for legal name change',               status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'address',      label: 'Address Change',            icon: MapPin,        desc: 'Update your residential address on file',               status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'business-lic', label: 'Business License',          icon: Building2,     desc: 'Apply for or renew a business operating license',       status: 'Coming Soon', statusColor: 'var(--mdt-text-muted)' },
    { id: 'non-emergency',label: 'Non-Emergency Reports',     icon: Phone,         desc: 'File noise complaints, property damage, and more',      status: 'Coming Soon', statusColor: 'var(--mdt-text-muted)' },
  ];

  const hoursSlots = [
    { day: 'Monday — Friday', time: '8:00 AM — 5:00 PM', closed: false },
    { day: 'Saturday', time: '9:00 AM — 1:00 PM', closed: false },
    { day: 'Sunday', time: 'Closed', closed: true },
  ];

  onMount(() => {
    mounted = true;
  });

  function handleServiceClick(serviceId) {
    if (serviceId === 'veh-reg') {
      mdtStore.activePage = 'civ-vehicles';
    }
  }
</script>

<div class="civ-services" class:mounted>
  <section class="hours-hero" aria-label="City Hall hours">
    <div class="hours-hero-accent" aria-hidden="true"></div>
    <div class="hours-hero-top">
      <div class="hours-hero-brand">
        <div class="hours-hero-icon">
          <Building2 size={20} strokeWidth={1.5} />
        </div>
        <div class="hours-hero-text">
          <span class="hours-kicker font-mono">Los Santos City Hall</span>
          <h2 class="hours-title">Hours of operation</h2>
        </div>
      </div>
    </div>
    <div class="hours-strip" role="list">
      {#each hoursSlots as slot (slot.day)}
        <div class="hours-slot" class:hours-slot--closed={slot.closed} role="listitem">
          <span class="hours-slot-day font-mono">{slot.day}</span>
          <span
            class="hours-slot-time"
            class:hours-closed={slot.closed}
          >
            {slot.time}
          </span>
        </div>
      {/each}
    </div>
    <p class="hours-foot font-mono">
      Online citizen services available 24/7 through this portal — in-person visits follow the schedule above.
    </p>
  </section>

  <header class="page-header">
    <div>
      <h1 class="page-title">City Services</h1>
      <p class="page-subtitle">
        <span class="page-sub-mono font-mono">Municipal portal</span>
        <span class="page-sub-sep" aria-hidden="true"></span>
        <span>Los Santos municipal government</span>
      </p>
    </div>
    <span class="page-tag font-mono">self-service</span>
  </header>

  <section class="panel services-panel">
    <div class="panel-header">
      <div class="panel-title-row">
        <ScrollText size={13} class="panel-icon" />
        <h2 class="panel-title">Available services</h2>
      </div>
      <span class="panel-eyebrow font-mono">{services.length} listings</span>
    </div>

    <div class="services-list">
      {#each services as svc, i (svc.id || i)}
        {@const Icon = svc.icon}
        <button
          class="service-row"
          style="--stagger: {i}"
          disabled={svc.status === 'Coming Soon'}
          onclick={() => handleServiceClick(svc.id)}
        >
          <div class="svc-icon-wrap">
            <Icon size={20} strokeWidth={1.5} />
          </div>
          <div class="svc-body">
            <div class="svc-top">
              <span class="svc-label">{svc.label}</span>
              <span
                class="svc-status font-mono"
                style="color: {svc.statusColor};"
              >
                {#if svc.status === 'Coming Soon'}
                  <Clock size={10} strokeWidth={2} />
                {/if}
                {svc.status.toUpperCase()}
              </span>
            </div>
            <p class="svc-desc">{svc.desc}</p>
          </div>
          <div class="svc-arrow">
            <ChevronRight size={16} strokeWidth={2} />
          </div>
        </button>
      {/each}
    </div>
  </section>
</div>

<style>
  .civ-services {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    padding: calc(18px * var(--mdt-scale)) calc(22px * var(--mdt-scale));
    overflow-y: auto;
    opacity: 0;
    min-height: 0;
  }

  .civ-services.mounted {
    animation: fadeIn 0.38s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  /* ── City Hall hours (top) ───────────────────────────── */
  .hours-hero {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 22%, var(--mdt-border));
    background: linear-gradient(
      145deg,
      color-mix(in srgb, var(--mdt-accent) 10%, var(--mdt-surface-2)) 0%,
      var(--mdt-surface-2) 55%
    );
    box-shadow: 0 calc(1px * var(--mdt-scale)) 0 color-mix(in srgb, var(--mdt-accent) 12%, transparent);
    flex-shrink: 0;
  }

  .hours-hero-accent {
    position: absolute;
    left: 0;
    top: calc(10px * var(--mdt-scale));
    bottom: calc(10px * var(--mdt-scale));
    width: calc(3px * var(--mdt-scale));
    border-radius: 0 var(--mdt-radius-sm) var(--mdt-radius-sm) 0;
    background: linear-gradient(
      180deg,
      var(--mdt-accent),
      color-mix(in srgb, var(--mdt-accent) 45%, var(--mdt-surface-3))
    );
  }

  .hours-hero-top {
    padding-left: calc(10px * var(--mdt-scale));
  }

  .hours-hero-brand {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
  }

  .hours-hero-icon {
    width: calc(44px * var(--mdt-scale));
    height: calc(44px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-accent) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 28%, transparent);
  }

  .hours-hero-text {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    min-width: 0;
  }

  .hours-kicker {
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--mdt-accent);
  }

  .hours-title {
    margin: 0;
    font-size: calc(17px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.02em;
    line-height: 1.2;
  }

  .hours-strip {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 0;
    margin-left: calc(4px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    overflow: hidden;
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
  }

  .hours-slot {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-right: 1px solid var(--mdt-border);
  }

  .hours-slot:last-child {
    border-right: none;
  }

  .hours-slot-day {
    font-size: calc(9px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }

  .hours-slot-time {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
    line-height: 1.3;
  }

  .hours-slot--closed .hours-slot-time {
    font-weight: 700;
  }

  .hours-closed {
    color: var(--mdt-error);
  }

  .hours-foot {
    margin: 0;
    padding-left: calc(10px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    line-height: 1.45;
    color: var(--mdt-text-muted);
    letter-spacing: 0.03em;
  }

  /* ── Page header ───────────────────────────────────── */
  .page-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(14px * var(--mdt-scale));
    padding-bottom: calc(2px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
  }

  .page-title {
    margin: 0;
    font-size: calc(20px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.01em;
  }

  .page-subtitle {
    margin: calc(5px * var(--mdt-scale)) 0 0;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .page-sub-mono {
    color: var(--mdt-text-dim);
    letter-spacing: 0.06em;
    text-transform: uppercase;
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
  }

  .page-sub-sep {
    width: calc(3px * var(--mdt-scale));
    height: calc(3px * var(--mdt-scale));
    border-radius: 50%;
    background: var(--mdt-text-muted);
  }

  .page-tag {
    flex-shrink: 0;
    margin-top: calc(2px * var(--mdt-scale));
    padding: calc(5px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    border: 1px solid color-mix(in srgb, var(--mdt-accent) 35%, transparent);
    border-radius: var(--mdt-radius-sm);
  }

  /* ── Panel (matches civilian dashboard) ────────────── */
  .panel {
    display: flex;
    flex-direction: column;
    background: var(--mdt-surface-2);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    overflow: hidden;
    min-height: 0;
    flex: 1;
  }

  .services-panel {
    animation: cardIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) 0.05s both;
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    flex-shrink: 0;
  }

  .panel-title-row {
    display: flex;
    align-items: center;
    gap: calc(7px * var(--mdt-scale));
  }

  .panel-title-row :global(.panel-icon),
  .panel-title-row :global(svg) {
    width: calc(13px * var(--mdt-scale));
    height: calc(13px * var(--mdt-scale));
    color: var(--mdt-accent);
    flex-shrink: 0;
  }

  .panel-title {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text-dim);
    text-transform: uppercase;
    letter-spacing: 0.07em;
  }

  .panel-eyebrow {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  .services-list {
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    min-height: 0;
  }

  .service-row {
    display: flex;
    align-items: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(12px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    border-left: calc(3px * var(--mdt-scale)) solid transparent;
    background: transparent;
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    width: 100%;
    transition:
      background 0.15s ease,
      border-left-color 0.15s ease;
    animation: rowIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) backwards;
    animation-delay: calc(60ms + var(--stagger) * 40ms);
  }

  .service-row:last-child {
    border-bottom: none;
  }

  .service-row:hover:not(:disabled) {
    background: color-mix(in srgb, var(--mdt-surface-3) 88%, transparent);
    border-left-color: color-mix(in srgb, var(--mdt-accent) 65%, transparent);
  }

  .service-row:active:not(:disabled) {
    transform: scale(0.998);
  }

  .service-row:disabled {
    opacity: 0.48;
    cursor: not-allowed;
  }

  .svc-icon-wrap {
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

  .service-row:disabled .svc-icon-wrap {
    color: var(--mdt-text-muted);
    background: color-mix(in srgb, var(--mdt-text-muted) 8%, transparent);
  }

  .svc-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(3px * var(--mdt-scale));
  }

  .svc-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
  }

  .svc-label {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }

  .svc-status {
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.1em;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .svc-desc {
    margin: 0;
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.45;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .svc-arrow {
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    transition: transform 0.18s ease, color 0.18s ease;
  }

  .service-row:hover:not(:disabled) .svc-arrow {
    color: var(--mdt-accent);
    transform: translateX(calc(3px * var(--mdt-scale)));
  }

  @media (max-width: 520px) {
    .hours-strip {
      grid-template-columns: 1fr;
    }

    .hours-slot {
      border-right: none;
      border-bottom: 1px solid var(--mdt-border);
    }

    .hours-slot:last-child {
      border-bottom: none;
    }
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(calc(6px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes cardIn {
    from {
      opacity: 0;
      transform: translateY(calc(5px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes rowIn {
    from {
      opacity: 0;
      transform: translateX(calc(-4px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }
</style>
