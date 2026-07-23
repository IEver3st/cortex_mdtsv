<script>
  import { onMount } from 'svelte';
  import { dataStore } from '../lib/stores/data.svelte.js';
  import { mdtStore } from '../lib/stores/mdt.svelte.js';
  import { tabsStore } from '../lib/stores/tabs.svelte.js';
  import { DEFAULT_CHARGES } from '../lib/data/charges.js';
  import { Scale, Search, RefreshCw, Pencil, DollarSign, Clock, Loader2, X } from '@lucide/svelte';

  const CATEGORIES = [
    { id: 'all',          label: 'All Charges' },
    { id: 'traffic',      label: 'Traffic' },
    { id: 'public_order', label: 'Public Order' },
    { id: 'property',     label: 'Property' },
    { id: 'violent',      label: 'Violent' },
    { id: 'weapons',      label: 'Weapons' },
    { id: 'drugs',        label: 'Drugs' },
    { id: 'government',   label: 'Government' },
    { id: 'fraud',        label: 'Fraud' },
    { id: 'other',        label: 'Other' },
  ];

  /** Stripe + badge: traffic-style severity (blue / amber / red). */
  const SEVERITY_STYLES = {
    infraction: { stripe: '#38bdf8', badgeBg: 'rgba(56, 189, 248, 0.14)', badgeFg: '#7dd3fc' },
    misdemeanor: { stripe: 'var(--mdt-warning)', badgeBg: 'rgba(251, 191, 36, 0.14)', badgeFg: 'var(--mdt-warning)' },
    felony: { stripe: 'var(--mdt-error)', badgeBg: 'rgba(248, 113, 113, 0.14)', badgeFg: 'var(--mdt-error)' },
  };

  let mounted = $state(false);
  let searchQuery = $state('');
  let activeCategory = $state('all');
  let charges = $derived(dataStore.chargesList.length ? dataStore.chargesList : DEFAULT_CHARGES);
  let refreshing = $state(false);

  function categoryLabel(catId) {
    return CATEGORIES.find(c => c.id === catId)?.label || catId;
  }

  function chargeDescription(c) {
    const raw = (c.description || c.desc || '').trim();
    if (raw) return raw;
    const cat = categoryLabel(c.category);
    const sev = (c.severity || 'offense').replace(/_/g, ' ');
    return `${c.charge} — ${sev} under ${cat}. Penalties shown below follow departmental sentencing guidelines.`;
  }

  function chargeCodeLine(c) {
    const code = c.code ?? c.penal_code ?? c.pc;
    if (code == null || String(code).trim() === '') return null;
    const s = String(code).trim();
    return /^p\.?\s*c\.?/i.test(s) ? s : `P.C. ${s}`;
  }

  let filteredCharges = $derived.by(() => {
    let result = charges;
    if (activeCategory !== 'all') {
      result = result.filter(c => c.category === activeCategory);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      result = result.filter(c => {
        const codeStr = chargeCodeLine(c);
        return (
          c.charge.toLowerCase().includes(q) ||
          (c.category && c.category.toLowerCase().includes(q)) ||
          chargeDescription(c).toLowerCase().includes(q) ||
          (codeStr && codeStr.toLowerCase().includes(q))
        );
      });
    }
    return result;
  });

  let groupedSections = $derived.by(() => {
    const list = filteredCharges;
    if (activeCategory === 'all') {
      const byCat = new Map();
      for (const c of list) {
        const k = c.category || 'other';
        if (!byCat.has(k)) byCat.set(k, []);
        byCat.get(k).push(c);
      }
      return CATEGORIES.filter(cat => cat.id !== 'all' && (byCat.get(cat.id)?.length))
        .map(cat => ({
          id: cat.id,
          label: cat.label.toUpperCase(),
          items: byCat.get(cat.id) || [],
        }));
    }
    const meta = CATEGORIES.find(c => c.id === activeCategory);
    return [{ id: activeCategory, label: (meta?.label || activeCategory).toUpperCase(), items: list }];
  });

  let categoryCounts = $derived.by(() => {
    const counts = { all: charges.length };
    for (const cat of CATEGORIES) {
      if (cat.id !== 'all') {
        counts[cat.id] = charges.filter(c => c.category === cat.id).length;
      }
    }
    return counts;
  });

  let listSummary = $derived.by(() => {
    const total = charges.length;
    const n = filteredCharges.length;
    if (!searchQuery.trim() && activeCategory === 'all') {
      return { primary: `${total} charge${total === 1 ? '' : 's'}`, secondary: null };
    }
    const parts = [];
    if (activeCategory !== 'all') parts.push(categoryLabel(activeCategory));
    if (searchQuery.trim()) parts.push(`search "${searchQuery.trim()}"`);
    return {
      primary: `Showing ${n} of ${total}`,
      secondary: parts.length ? parts.join(' · ') : null,
    };
  });

  onMount(async () => {
    mounted = true;
    await loadCharges();
  });

  async function loadCharges() {
    await dataStore.fetchCharges();
  }

  async function refreshCharges() {
    if (refreshing) return;
    refreshing = true;
    try {
      await loadCharges();
    } finally {
      refreshing = false;
    }
  }

  function openEditCharges() {
    mdtStore.requestOpenSettingsTab('jail_fines');
    tabsStore.openTab('settings');
  }

  function severityStyle(sev) {
    return SEVERITY_STYLES[sev] || SEVERITY_STYLES.infraction;
  }

  function severityLabel(sev) {
    if (!sev) return 'Offense';
    return String(sev).replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }

  function clearSearch() {
    searchQuery = '';
  }

  function formatMoney(amount) {
    if (!amount) return '$0';
    return '$' + Number(amount).toLocaleString();
  }

  /** Jail units are months (matches Reports charge picker). */
  function formatSentence(charge) {
    const j = charge.jailTime || 0;
    const max = charge.maxJail || 0;
    if (!j && !max) return '—';
    if (max && max !== j) return `${j}–${max}mo`;
    return `${j}mo`;
  }
</script>

<div class="charges-page" class:mounted>
  <header class="page-header">
    <div class="header-top">
      <div class="header-title-block">
        <h1 class="page-title">Penal Code</h1>
        <p class="page-sub">Reference cards — fine, sentence, statutory text</p>
      </div>
      <div class="header-actions">
        <div class="page-count-block font-mono">
          <span class="page-count">{listSummary.primary}</span>
          {#if listSummary.secondary}
            <span class="page-count-sub">{listSummary.secondary}</span>
          {/if}
        </div>
        <button type="button" class="btn-ghost font-mono" onclick={refreshCharges} disabled={refreshing} title="Reload from server">
          {#if refreshing}
            <Loader2 size={14} strokeWidth={2} class="spin" />
          {:else}
            <RefreshCw size={14} strokeWidth={2} />
          {/if}
          Refresh
        </button>
        <button type="button" class="btn-primary font-mono" onclick={openEditCharges} title="Edit fines and jail times">
          <Pencil size={14} strokeWidth={2} />
          Edit charges
        </button>
      </div>
    </div>
    <div class="search-box">
      <Search size={14} strokeWidth={2} aria-hidden="true" />
      <input
        class="search-input font-mono"
        type="search"
        autocomplete="off"
        placeholder="Search charges, codes, descriptions..."
        aria-label="Search penal code charges"
        bind:value={searchQuery}
      />
      {#if searchQuery.trim()}
        <button type="button" class="search-clear font-mono" onclick={clearSearch} title="Clear search" aria-label="Clear search">
          <X size={14} strokeWidth={2} />
        </button>
      {/if}
    </div>
  </header>

  <div class="tabs-wrap">
    <div class="category-tabs" role="tablist" aria-label="Charge categories">
      {#each CATEGORIES as cat (cat.id)}
        <button
          type="button"
          role="tab"
          class="cat-tab font-mono"
          class:active={activeCategory === cat.id}
          aria-selected={activeCategory === cat.id}
          id="penal-tab-{cat.id}"
          onclick={() => (activeCategory = cat.id)}
        >
          {cat.label}
          <span class="cat-count" aria-hidden="true">({categoryCounts[cat.id] ?? 0})</span>
        </button>
      {/each}
    </div>
    <p class="severity-legend font-mono">
      <span class="leg-item"><span class="leg-dot leg-inf"></span> Infraction</span>
      <span class="leg-item"><span class="leg-dot leg-mis"></span> Misdemeanor</span>
      <span class="leg-item"><span class="leg-dot leg-fel"></span> Felony</span>
    </p>
  </div>

  <div class="charge-scroll">
    {#if filteredCharges.length === 0}
      <div class="empty-state">
        <Scale size={32} strokeWidth={1} aria-hidden="true" />
        <span class="empty-text">
          {#if charges.length === 0}
            No charges loaded. Try Refresh.
          {:else}
            No charges match filters. Clear search or pick another category.
          {/if}
        </span>
        {#if charges.length > 0 && (searchQuery.trim() || activeCategory !== 'all')}
          <button type="button" class="btn-ghost font-mono empty-reset" onclick={() => { searchQuery = ''; activeCategory = 'all'; }}>
            Reset filters
          </button>
        {/if}
      </div>
    {:else}
      {#each groupedSections as section (section.id)}
        <section class="charge-section">
          <h2 class="section-heading font-mono">{section.label}</h2>
          <div class="card-grid">
            {#each section.items as charge, i (charge.id)}
              {@const sev = severityStyle(charge.severity)}
              {@const codeLine = chargeCodeLine(charge)}
              <article
                class="penal-card"
                style="--stagger: {i}; --sev-stripe: {sev.stripe}; --badge-bg: {sev.badgeBg}; --badge-fg: {sev.badgeFg};"
              >
                <div class="penal-card-inner">
                  <div class="penal-card-top">
                    <div class="penal-card-head">
                      <div class="penal-card-head-text">
                        {#if codeLine}
                          <span class="penal-code font-mono">{codeLine}</span>
                        {/if}
                        <h3 class="penal-title">{charge.charge}</h3>
                      </div>
                      <span class="sev-badge font-mono">{severityLabel(charge.severity)}</span>
                    </div>
                  </div>

                  <div class="penal-desc-block">
                    <span class="field-label font-mono">Description</span>
                    <p class="penal-desc">{chargeDescription(charge)}</p>
                  </div>

                  <div class="penal-metrics">
                    <div class="metric">
                      <span class="field-label font-mono"><DollarSign size={11} strokeWidth={2} class="metric-ico" /> Fine</span>
                      <span class="metric-value font-mono">{formatMoney(charge.fine)}</span>
                    </div>
                    <div class="metric">
                      <span class="field-label font-mono"><Clock size={11} strokeWidth={2} class="metric-ico" /> Time</span>
                      <span class="metric-value font-mono">{formatSentence(charge)}</span>
                    </div>
                  </div>

                  <div class="penal-foot font-mono" aria-label="Charge metadata">
                    <span>DL pts {charge.points > 0 ? charge.points : '—'}</span>
                    {#if charge.stackable != null}
                      <span>{charge.stackable ? 'Stackable' : 'Non-stackable'}</span>
                    {/if}
                    {#if charge.requiresEvidence != null}
                      <span>{charge.requiresEvidence ? 'Evidence required' : 'No evidence req.'}</span>
                    {/if}
                  </div>
                </div>
              </article>
            {/each}
          </div>
        </section>
      {/each}
    {/if}
  </div>
</div>

<style>
  .charges-page {
    padding: calc(24px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(14px * var(--mdt-scale));
    min-height: 0;
    flex: 1;
    opacity: 0;
  }
  .charges-page.mounted { animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards; }

  .page-header {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }
  .header-top {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: calc(16px * var(--mdt-scale));
    flex-wrap: wrap;
  }
  .header-title-block { min-width: 0; }
  .page-title {
    font-size: calc(22px * var(--mdt-scale));
    font-weight: 700;
    color: var(--mdt-text);
    letter-spacing: -0.02em;
    margin: 0 0 calc(2px * var(--mdt-scale));
  }
  .page-sub {
    margin: 0;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
    max-width: 42ch;
    line-height: 1.45;
  }
  .header-actions {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    flex-wrap: wrap;
  }
  .page-count-block {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: calc(2px * var(--mdt-scale));
    text-align: right;
  }
  .page-count {
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.06em;
    font-variant-numeric: tabular-nums;
  }
  .page-count-sub {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-text-dim);
    letter-spacing: 0.04em;
    max-width: 36ch;
    line-height: 1.35;
  }

  .btn-ghost,
  .btn-primary {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.06em;
    cursor: pointer;
    border: 1px solid var(--mdt-border);
    transition: background 0.2s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.2s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.15s ease, transform 0.12s ease;
  }
  .btn-ghost:active:not(:disabled),
  .btn-primary:active:not(:disabled) {
    transform: scale(0.98);
  }
  .btn-ghost {
    background: var(--mdt-surface);
    color: var(--mdt-text-muted);
  }
  .btn-ghost:hover:not(:disabled) {
    color: var(--mdt-text);
    border-color: var(--mdt-border-2);
    background: var(--mdt-surface-2);
  }
  .btn-primary {
    background: var(--mdt-accent-dim);
    border-color: color-mix(in srgb, var(--mdt-accent) 42%, transparent);
    color: var(--mdt-accent);
  }
  .btn-primary:hover {
    border-color: var(--mdt-accent);
    background: color-mix(in srgb, var(--mdt-accent) 18%, var(--mdt-surface));
  }
  .btn-ghost:disabled { opacity: 0.45; cursor: not-allowed; }

  .search-box {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale)) calc(14px * var(--mdt-scale));
    background: var(--mdt-surface);
    border: 1px solid var(--mdt-border);
    border-radius: var(--mdt-radius);
    color: var(--mdt-text-muted);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }
  .search-clear {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: calc(4px * var(--mdt-scale));
    margin: calc(-4px * var(--mdt-scale)) calc(-6px * var(--mdt-scale)) calc(-4px * var(--mdt-scale)) 0;
    border: none;
    border-radius: var(--mdt-radius-sm);
    background: transparent;
    color: var(--mdt-text-dim);
    cursor: pointer;
    transition: color 0.15s ease, background 0.15s ease;
  }
  .search-clear:hover {
    color: var(--mdt-text);
    background: rgba(255, 255, 255, 0.06);
  }
  .search-input {
    background: none;
    border: none;
    color: var(--mdt-text);
    outline: none;
    font-size: calc(12px * var(--mdt-scale));
    flex: 1;
    min-width: 0;
  }
  .search-input::placeholder { color: var(--mdt-text-muted); }

  :global(.spin) {
    animation: spin 0.7s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .tabs-wrap {
    display: flex;
    flex-direction: column;
    gap: calc(8px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    padding-bottom: calc(8px * var(--mdt-scale));
  }
  .category-tabs {
    display: flex;
    gap: calc(4px * var(--mdt-scale));
    flex-wrap: nowrap;
    overflow-x: auto;
    overflow-y: hidden;
    -webkit-overflow-scrolling: touch;
    scrollbar-width: thin;
    padding: calc(2px * var(--mdt-scale)) calc(4px * var(--mdt-scale)) calc(4px * var(--mdt-scale)) 0;
  }
  .severity-legend {
    margin: 0;
    display: flex;
    flex-wrap: wrap;
    gap: calc(12px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.06em;
    color: var(--mdt-text-muted);
  }
  .leg-item {
    display: inline-flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
  }
  .leg-dot {
    width: calc(6px * var(--mdt-scale));
    height: calc(6px * var(--mdt-scale));
    border-radius: 50%;
    flex-shrink: 0;
  }
  .leg-inf { background: #38bdf8; }
  .leg-mis { background: var(--mdt-warning); }
  .leg-fel { background: var(--mdt-error); }

  .cat-tab {
    display: flex;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(6px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    border: none;
    background: transparent;
    color: var(--mdt-text-muted);
    font-family: 'Share Tech Mono', monospace;
    font-size: calc(10px * var(--mdt-scale));
    cursor: pointer;
    white-space: nowrap;
    letter-spacing: 0.04em;
    transition: color 0.2s cubic-bezier(0.16, 1, 0.3, 1), background 0.2s cubic-bezier(0.16, 1, 0.3, 1), transform 0.12s ease;
  }
  .cat-tab:active { transform: scale(0.98); }
  .cat-tab:hover { color: var(--mdt-text); background: var(--mdt-surface); }
  .cat-tab.active {
    color: var(--mdt-accent);
    background: var(--mdt-accent-dim);
    box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--mdt-accent) 35%, transparent);
  }
  .cat-count {
    font-size: calc(9px * var(--mdt-scale));
    opacity: 0.5;
    font-variant-numeric: tabular-nums;
  }

  .charge-scroll {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding-right: calc(4px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(22px * var(--mdt-scale));
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(48px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-align: center;
  }
  .empty-text { font-size: calc(13px * var(--mdt-scale)); max-width: 40ch; line-height: 1.5; }
  .empty-reset { margin-top: calc(6px * var(--mdt-scale)); }

  .charge-section {
    display: flex;
    flex-direction: column;
    gap: calc(10px * var(--mdt-scale));
  }
  .section-heading {
    margin: 0;
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.14em;
    color: var(--mdt-text-muted);
    font-weight: 600;
  }

  .card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(280px * var(--mdt-scale)), 1fr));
    gap: calc(12px * var(--mdt-scale));
  }

  .penal-card {
    position: relative;
    border-radius: calc(12px * var(--mdt-scale));
    border: 1px solid var(--mdt-border);
    background: var(--mdt-surface);
    box-shadow:
      0 calc(4px * var(--mdt-scale)) calc(20px * var(--mdt-scale)) rgba(15, 17, 22, 0.45),
      inset 0 1px 0 rgba(255, 255, 255, 0.05);
    overflow: hidden;
    animation: cardIn 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: calc(var(--stagger) * 25ms);
    opacity: 0;
    transition: border-color 0.2s cubic-bezier(0.16, 1, 0.3, 1), transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s ease;
  }
  .penal-card::before {
    content: '';
    position: absolute;
    inset: 0 auto 0 0;
    width: calc(4px * var(--mdt-scale));
    background: var(--sev-stripe);
    opacity: 1;
  }
  .penal-card:hover {
    border-color: var(--mdt-border-2);
    transform: translateY(calc(-2px * var(--mdt-scale)));
    box-shadow:
      0 calc(8px * var(--mdt-scale)) calc(24px * var(--mdt-scale)) rgba(15, 17, 22, 0.55),
      inset 0 1px 0 rgba(255, 255, 255, 0.07);
  }
  .penal-card:active {
    transform: translateY(0) scale(0.995);
  }

  .penal-card-inner {
    padding: calc(14px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    padding-left: calc(20px * var(--mdt-scale));
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
  }

  .penal-card-top {
    display: flex;
    flex-direction: column;
    gap: 0;
  }
  .penal-card-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    flex-wrap: wrap;
  }
  .penal-card-head-text {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }
  .sev-badge {
    flex-shrink: 0;
    font-size: calc(8px * var(--mdt-scale));
    letter-spacing: 0.08em;
    text-transform: uppercase;
    font-weight: 600;
    padding: calc(4px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    border-radius: calc(4px * var(--mdt-scale));
    background: var(--badge-bg);
    color: var(--badge-fg);
    border: 1px solid rgba(255, 255, 255, 0.08);
    white-space: nowrap;
    line-height: 1.2;
  }
  .penal-code {
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.06em;
    color: var(--mdt-text-dim);
  }
  .penal-title {
    margin: 0;
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 650;
    color: var(--mdt-text);
    line-height: 1.3;
    letter-spacing: -0.01em;
  }

  .field-label {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    font-weight: 600;
  }
  :global(.metric-ico) {
    opacity: 0.65;
  }

  .penal-desc-block {
    padding: calc(10px * var(--mdt-scale)) calc(12px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: var(--mdt-surface-2);
    border: 1px solid rgba(255, 255, 255, 0.06);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }
  .penal-desc {
    margin: calc(6px * var(--mdt-scale)) 0 0;
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.55;
    color: var(--mdt-text);
    opacity: 0.92;
  }

  .penal-metrics {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: calc(10px * var(--mdt-scale));
  }
  .metric {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale));
    border-radius: var(--mdt-radius-sm);
    background: rgba(10, 12, 16, 0.35);
    border: 1px solid rgba(255, 255, 255, 0.06);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.05);
  }
  .metric-value {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text);
  }
  .metric:first-child .metric-value {
    color: var(--mdt-warning);
  }

  .penal-foot {
    display: flex;
    flex-wrap: wrap;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.05em;
    color: var(--mdt-text-dim);
    padding-top: calc(2px * var(--mdt-scale));
    border-top: 1px dashed var(--mdt-border);
  }
  .penal-foot span {
    padding: calc(2px * var(--mdt-scale)) calc(6px * var(--mdt-scale));
    border-radius: calc(4px * var(--mdt-scale));
    background: rgba(255, 255, 255, 0.03);
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  @keyframes cardIn {
    from {
      opacity: 0;
      transform: translateY(calc(8px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>
