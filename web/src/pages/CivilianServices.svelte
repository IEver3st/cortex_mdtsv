<script>
  import { onMount } from 'svelte';
  import { Building2, FileSignature, Car, UserCheck, MapPin, Phone, ChevronRight, Clock } from 'lucide-svelte';

  let mounted = $state(false);

  const services = [
    { id: 'id-renewal',   label: 'ID Card Renewal',           icon: UserCheck,     desc: 'Renew your Los Santos citizen identification card',     status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'veh-reg',      label: 'Vehicle Registration',      icon: Car,           desc: 'Register a new vehicle or renew existing registration', status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'name-change',  label: 'Legal Name Change',         icon: FileSignature, desc: 'Submit a petition for legal name change',               status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'address',      label: 'Address Change',            icon: MapPin,        desc: 'Update your residential address on file',               status: 'Available',  statusColor: 'var(--mdt-success)' },
    { id: 'business-lic', label: 'Business License',          icon: Building2,     desc: 'Apply for or renew a business operating license',       status: 'Coming Soon', statusColor: 'var(--mdt-text-muted)' },
    { id: 'non-emergency',label: 'Non-Emergency Reports',     icon: Phone,         desc: 'File noise complaints, property damage, and more',      status: 'Coming Soon', statusColor: 'var(--mdt-text-muted)' },
  ];

  onMount(() => {
    mounted = true;
  });
</script>

<div class="civ-services" class:mounted>
  <div class="page-header">
    <h1 class="page-title">City Services</h1>
    <span class="page-subtitle font-mono">LOS SANTOS MUNICIPAL GOVERNMENT</span>
  </div>

  <div class="services-grid">
    {#each services as svc, i}
      {@const Icon = svc.icon}
      <button
        class="service-card"
        style="--stagger: {i}"
        disabled={svc.status === 'Coming Soon'}
      >
        <div class="svc-icon-wrap">
          <Icon size={22} strokeWidth={1.5} />
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

  <div class="hours-panel">
    <div class="hours-header font-mono">
      <Building2 size={14} strokeWidth={1.5} />
      <span>CITY HALL HOURS</span>
    </div>
    <div class="hours-grid font-mono">
      <div class="hours-row">
        <span class="hours-day">Monday — Friday</span>
        <span class="hours-time">8:00 AM — 5:00 PM</span>
      </div>
      <div class="hours-row">
        <span class="hours-day">Saturday</span>
        <span class="hours-time">9:00 AM — 1:00 PM</span>
      </div>
      <div class="hours-row">
        <span class="hours-day">Sunday</span>
        <span class="hours-time hours-closed">Closed</span>
      </div>
    </div>
    <div class="hours-footer font-mono">
      Online services available 24/7 through the Citizen Services Portal
    </div>
  </div>
</div>

<style>
  .civ-services {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(18px * var(--mdt-scale));
    opacity: 0;
  }

  .civ-services.mounted {
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

  .page-subtitle {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.15em;
    text-transform: uppercase;
  }

  .services-grid {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .service-card {
    display: flex;
    align-items: center;
    gap: calc(14px * var(--mdt-scale));
    padding: calc(16px * var(--mdt-scale)) calc(18px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--civ-border, var(--mdt-border));
    border-radius: var(--mdt-radius);
    cursor: pointer;
    font-family: 'Outfit', sans-serif;
    text-align: left;
    width: 100%;
    transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    animation: cardIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--stagger) * 50ms);
    opacity: 0;
  }

  .service-card:hover:not(:disabled) {
    background: var(--mdt-surface-2);
    border-color: var(--civ-gold, var(--mdt-accent));
    transform: translateX(calc(4px * var(--mdt-scale)));
  }

  .service-card:active:not(:disabled) {
    transform: scale(0.99);
  }

  .service-card:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .svc-icon-wrap {
    width: calc(44px * var(--mdt-scale));
    height: calc(44px * var(--mdt-scale));
    border-radius: var(--mdt-radius);
    background: var(--civ-accent-dim, var(--mdt-accent-dim));
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: var(--civ-gold, var(--mdt-accent));
  }

  .service-card:disabled .svc-icon-wrap {
    color: var(--mdt-text-muted);
    background: var(--mdt-surface-3);
  }

  .svc-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
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
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: calc(4px * var(--mdt-scale));
    flex-shrink: 0;
  }

  .svc-desc {
    font-size: calc(12px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    line-height: 1.4;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .svc-arrow {
    color: var(--mdt-text-muted);
    flex-shrink: 0;
    transition: transform 0.2s ease, color 0.2s ease;
  }

  .service-card:hover:not(:disabled) .svc-arrow {
    color: var(--civ-gold, var(--mdt-accent));
    transform: translateX(calc(3px * var(--mdt-scale)));
  }

  .hours-panel {
    background: var(--mdt-surface);
    border: 1px solid var(--civ-border, var(--mdt-border));
    border-radius: var(--mdt-radius);
    padding: calc(16px * var(--mdt-scale)) calc(20px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }

  .hours-header {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.15em;
    color: var(--civ-gold, var(--mdt-accent));
    font-weight: 600;
  }

  .hours-grid {
    display: flex;
    flex-direction: column;
    gap: calc(6px * var(--mdt-scale));
  }

  .hours-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: calc(12px * var(--mdt-scale));
    padding: calc(4px * var(--mdt-scale)) 0;
  }

  .hours-day {
    color: var(--mdt-text-dim);
  }

  .hours-time {
    color: var(--mdt-text);
  }

  .hours-closed {
    color: var(--mdt-error);
  }

  .hours-footer {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.02em;
    padding-top: calc(8px * var(--mdt-scale));
    border-top: 1px solid var(--civ-border, var(--mdt-border));
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
