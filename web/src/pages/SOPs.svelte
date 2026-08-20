<script module>
  function renderMarkdown(value) {
    return String(value || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/_(.+?)_/g, '<em>$1</em>')
      .replace(/^(\d+\.\s.+)$/gm, '<span class="sop-line">$1</span>')
      .replace(/^- (.+)$/gm, '<span class="sop-line">• $1</span>')
      .replace(/\n\n/g, '<br><br>')
      .replace(/\n/g, '<br>');
  }
</script>

<script>
  import { onMount } from 'svelte';
  import {
    BookOpen,
    BookOpenCheck,
    Check,
    ChevronRight,
    FileWarning,
    Landmark,
    RefreshCw,
    Search,
  } from '@lucide/svelte';
  import { isEnvBrowser, nuiPost } from '../lib/utils/nui.js';
  import { tabsStore } from '../lib/stores/tabs.svelte.js';

  let sops = $state([]);
  let acknowledgements = $state([]);
  let selectedId = $state('');
  let searchQuery = $state('');
  let category = $state('all');
  let loading = $state(true);
  let acknowledging = $state(false);
  let errorMessage = $state('');
  let canManage = $state(false);

  let categories = $derived.by(() => {
    const counts = new Map();
    sops.forEach((sop) => {
      const value = String(sop.category || 'general');
      counts.set(value, (counts.get(value) || 0) + 1);
    });
    return [...counts.entries()].sort(([left], [right]) => left.localeCompare(right));
  });

  let filteredSops = $derived.by(() => {
    const query = searchQuery.trim().toLowerCase();
    return sops.filter((sop) => {
      if (category !== 'all' && String(sop.category || 'general') !== category) return false;
      if (!query) return true;
      return [sop.title, sop.reference, sop.summary, sop.content, sop.category]
        .some((value) => String(value || '').toLowerCase().includes(query));
    });
  });

  let selectedSop = $derived(
    filteredSops.find((sop) => String(sop.id) === String(selectedId)) || filteredSops[0] || null,
  );
  function acknowledgementFor(sop) {
    return acknowledgements.find((row) => (
      String(row.sopId) === String(sop?.id)
      && Number(row.sopVersion) === Number(sop?.version || 1)
    )) || null;
  }

  let selectedAcknowledgement = $derived(acknowledgementFor(selectedSop));

  function formatCategory(value) {
    return String(value || 'general').replaceAll('-', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
  }

  function formatDate(value) {
    if (!value) return 'Not recorded';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString();
  }

  async function loadSops() {
    loading = true;
    errorMessage = '';
    let recordsResponse;
    let acknowledgementResponse;
    if (isEnvBrowser()) {
      recordsResponse = {
        ok: true,
        canManage: true,
        records: [
          { id: 'sop:1', title: 'Vehicle Pursuit', category: 'pursuit-policy', reference: 'SOP-PUR-1.0', summary: 'Risk-balanced pursuit and termination requirements.', content: '**PURPOSE:** Establish a safe, reviewable pursuit standard.\n\n1. Notify dispatch immediately.\n2. Continuously balance apprehension need against public risk.\n3. Obey supervisor direction and document the complete event.', status: 'active', visibility: 'all', version: 1, updatedAt: new Date().toISOString(), createdBy: { name: 'Cortex MDT', callsign: 'SYSTEM' } },
          { id: 'sop:2', title: 'Evidence and Chain of Custody', category: 'evidence', reference: 'SOP-EVI-1.0', summary: 'Collection, packaging, access, and transfer controls.', content: '**COLLECTION:** Photograph items before collection when practical.\n\n- Package items separately.\n- Record every transfer.\n- Keep digital originals unaltered.', status: 'active', visibility: 'all', version: 1, updatedAt: new Date().toISOString(), createdBy: { name: 'Cortex MDT', callsign: 'SYSTEM' } },
        ],
      };
      acknowledgementResponse = { ok: true, acknowledgements: [] };
    } else {
      [recordsResponse, acknowledgementResponse] = await Promise.all([
        nuiPost('cortex_mdt:getFeatureRecords', { kind: 'sops', limit: 250 }),
        nuiPost('cortex_mdt:getSopAcknowledgements', {}),
      ]);
    }

    if (recordsResponse?.ok) {
      sops = recordsResponse.records || [];
      canManage = recordsResponse.canManage === true;
      if (!sops.some((sop) => String(sop.id) === String(selectedId))) selectedId = String(sops[0]?.id || '');
    } else {
      errorMessage = recordsResponse?.error || 'Department directives could not be loaded.';
    }
    if (acknowledgementResponse?.ok) acknowledgements = acknowledgementResponse.acknowledgements || [];
    loading = false;
  }

  async function acknowledge() {
    if (!selectedSop || acknowledging) return;
    acknowledging = true;
    const response = isEnvBrowser()
      ? { ok: true, acknowledgement: { sopId: selectedSop.id, sopVersion: selectedSop.version || 1, acknowledgedAt: new Date().toISOString() } }
      : await nuiPost('cortex_mdt:acknowledgeSop', { id: selectedSop.id });
    if (response?.ok) {
      acknowledgements = [
        response.acknowledgement,
        ...acknowledgements.filter((row) => String(row.sopId) !== String(selectedSop.id)),
      ];
    } else {
      errorMessage = response?.error || 'The directive could not be acknowledged.';
    }
    acknowledging = false;
  }

  onMount(loadSops);
</script>

<div class="sops-page">
  {#if errorMessage}
    <div class="error-banner" role="alert"><FileWarning size={16} />{errorMessage}</div>
  {/if}

  <div class="sops-workspace">
    <aside class="manual-index">
      <div class="index-title">
        <div class="index-summary">
          <span class="font-mono">POLICY INDEX</span>
          <strong>{filteredSops.length === sops.length ? `${sops.length} directives` : `${filteredSops.length} of ${sops.length}`}</strong>
        </div>
        <div class="index-actions">
          {#if canManage}
            <button type="button" class="icon-button" onclick={() => tabsStore.openTab('command')} aria-label="Manage directives" title="Manage directives"><Landmark size={14} /></button>
          {/if}
          <button type="button" class="icon-button" onclick={loadSops} disabled={loading} aria-label="Refresh directives" title="Refresh directives"><span class:spin={loading}><RefreshCw size={14} /></span></button>
        </div>
      </div>
      <label class="search-control"><Search size={14} /><span class="sr-only">Search directives</span><input bind:value={searchQuery} type="search" placeholder="Title, body, or SOP code" /></label>
      <div class="category-filter" aria-label="Directive categories">
        <button type="button" class:active={category === 'all'} onclick={() => (category = 'all')}><span>All directives</span><strong class="font-mono">{sops.length}</strong></button>
        {#each categories as [value, count] (value)}
          <button type="button" class:active={category === value} onclick={() => (category = value)}><span>{formatCategory(value)}</span><strong class="font-mono">{count}</strong></button>
        {/each}
      </div>
      <div class="document-list">
        {#if loading}
          <div class="list-state" aria-busy="true"><span class="spin"><RefreshCw size={18} /></span>Loading directives…</div>
        {:else if filteredSops.length === 0}
          <div class="list-state"><FileWarning size={18} />No matching directives.</div>
        {:else}
          {#each filteredSops as sop (sop.id)}
            <button type="button" class="document-link" class:active={String(selectedSop?.id) === String(sop.id)} onclick={() => (selectedId = String(sop.id))}>
              <span class="document-code font-mono">{sop.reference || sop.id}</span>
              <strong>{sop.title}</strong>
              <span>{formatCategory(sop.category)}</span>
              {#if acknowledgementFor(sop)}<Check size={14} />{:else}<ChevronRight size={14} />{/if}
            </button>
          {/each}
        {/if}
      </div>
    </aside>

    <article class="document-reader">
      {#if selectedSop}
        <div class="reader-tape font-mono">
          <span>{selectedSop.reference || selectedSop.id}</span>
          <span>REV {selectedSop.version || 1}</span>
          <span>{String(selectedSop.status || 'active').toUpperCase()}</span>
          <span>{formatDate(selectedSop.updatedAt || selectedSop.createdAt)}</span>
        </div>
        <header class="reader-header">
          <span class="reader-category font-mono">{formatCategory(selectedSop.category)}</span>
          <h2>{selectedSop.title}</h2>
          {#if selectedSop.summary}<p>{selectedSop.summary}</p>{/if}
        </header>
        <div class="reader-body">{@html renderMarkdown(selectedSop.content)}</div>
        <footer class="reader-footer">
          <div><span class="font-mono">ISSUED BY</span><strong>{selectedSop.updatedBy?.name || selectedSop.createdBy?.name || 'Cortex MDT'}</strong></div>
          {#if selectedAcknowledgement}
            <span class="ack-state"><BookOpenCheck size={15} /> Acknowledged {formatDate(selectedAcknowledgement.acknowledgedAt)}</span>
          {:else}
            <button type="button" class="ack-button" onclick={acknowledge} disabled={acknowledging}><BookOpenCheck size={15} />{acknowledging ? 'Recording…' : 'Acknowledge this revision'}</button>
          {/if}
        </footer>
      {:else}
        <div class="reader-empty"><BookOpen size={34} /><h2>No directive selected</h2><p>Choose a document from the policy index.</p></div>
      {/if}
    </article>
  </div>
</div>

<style>
  .font-mono { font-family: 'Share Tech Mono', monospace; }
  .sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
  .sops-page { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: calc(10px * var(--mdt-scale)); padding: calc(12px * var(--mdt-scale)); color: var(--mdt-text); overflow: hidden; }
  button, input { font: inherit; }
  button:focus-visible, input:focus-visible { outline: 2px solid var(--mdt-accent); outline-offset: 2px; }
  button:disabled { opacity: .45; cursor: not-allowed; }
  .error-banner { display: flex; align-items: center; gap: calc(8px * var(--mdt-scale)); padding: calc(8px * var(--mdt-scale)) calc(10px * var(--mdt-scale)); border: 1px solid color-mix(in srgb, var(--mdt-error) 45%, var(--mdt-border)); border-radius: var(--mdt-radius-sm); color: var(--mdt-error); font-size: calc(10px * var(--mdt-scale)); }

  .sops-workspace { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(calc(280px * var(--mdt-scale)), calc(340px * var(--mdt-scale))) minmax(0, 1fr); gap: calc(10px * var(--mdt-scale)); }
  .manual-index, .document-reader { border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius); background: var(--mdt-surface); overflow: hidden; }
  .manual-index { min-height: 0; display: flex; flex-direction: column; }
  .index-title { display: flex; align-items: center; justify-content: space-between; gap: calc(10px * var(--mdt-scale)); padding: calc(11px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .index-summary { min-width: 0; display: flex; flex-direction: column; gap: calc(3px * var(--mdt-scale)); }
  .index-summary span { color: var(--mdt-accent); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .08em; }
  .index-summary strong { color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); font-weight: 500; }
  .index-actions { display: flex; align-items: center; gap: calc(5px * var(--mdt-scale)); }
  .icon-button { display: inline-flex; align-items: center; justify-content: center; width: calc(30px * var(--mdt-scale)); height: calc(30px * var(--mdt-scale)); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text-muted); cursor: pointer; }
  .icon-button:hover:not(:disabled) { color: var(--mdt-text); border-color: var(--mdt-accent); }
  .search-control { display: flex; align-items: center; gap: calc(7px * var(--mdt-scale)); margin: calc(9px * var(--mdt-scale)) calc(10px * var(--mdt-scale)); padding: 0 calc(8px * var(--mdt-scale)); min-height: calc(33px * var(--mdt-scale)); border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text-muted); }
  .search-control:focus-within { border-color: var(--mdt-accent); }
  .search-control input { flex: 1; min-width: 0; border: 0; background: transparent; color: var(--mdt-text); font-size: calc(11px * var(--mdt-scale)); }
  .category-filter { display: flex; gap: calc(2px * var(--mdt-scale)); margin: 0 calc(10px * var(--mdt-scale)) calc(9px * var(--mdt-scale)); padding: calc(3px * var(--mdt-scale)); overflow-x: auto; border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-chrome); }
  .category-filter button { display: inline-flex; align-items: center; gap: calc(6px * var(--mdt-scale)); flex: 0 0 auto; padding: calc(6px * var(--mdt-scale)) calc(8px * var(--mdt-scale)); border: 0; border-radius: var(--mdt-radius-sm); background: transparent; color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); cursor: pointer; }
  .category-filter button:hover { color: var(--mdt-text); background: var(--mdt-surface-2); }
  .category-filter button.active { color: var(--mdt-text); background: var(--mdt-surface-3); box-shadow: inset 0 -2px 0 var(--mdt-accent); }
  .category-filter strong { color: var(--mdt-text-muted); font-size: calc(9px * var(--mdt-scale)); }
  .document-list { flex: 1; min-height: 0; overflow-y: auto; }
  .document-link { position: relative; display: flex; flex-direction: column; gap: calc(3px * var(--mdt-scale)); width: 100%; min-height: calc(68px * var(--mdt-scale)); padding: calc(8px * var(--mdt-scale)) calc(28px * var(--mdt-scale)) calc(8px * var(--mdt-scale)) calc(12px * var(--mdt-scale)); border: 0; border-bottom: 1px solid var(--mdt-border); border-left: 2px solid transparent; border-radius: 0; background: transparent; color: var(--mdt-text-muted); text-align: left; cursor: pointer; }
  .document-link:hover { background: var(--mdt-surface-2); }
  .document-link.active { border-left-color: var(--mdt-accent); background: var(--mdt-surface-2); }
  .document-link :global(svg:last-child) { position: absolute; right: calc(9px * var(--mdt-scale)); top: 50%; transform: translateY(-50%); color: var(--mdt-success); }
  .document-code { color: var(--mdt-accent); font-size: calc(9px * var(--mdt-scale)); letter-spacing: .05em; }
  .document-link strong { overflow: hidden; color: var(--mdt-text); font-size: calc(12px * var(--mdt-scale)); text-overflow: ellipsis; white-space: nowrap; }
  .document-link > span:last-of-type { font-size: calc(10px * var(--mdt-scale)); }
  .list-state { min-height: calc(170px * var(--mdt-scale)); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: calc(8px * var(--mdt-scale)); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); }

  .document-reader { min-width: 0; min-height: 0; display: flex; flex-direction: column; overflow-y: auto; padding: 0 calc(20px * var(--mdt-scale)) calc(16px * var(--mdt-scale)); }
  .reader-tape { position: sticky; top: 0; z-index: 2; display: flex; flex-wrap: wrap; align-items: center; gap: calc(6px * var(--mdt-scale)) calc(15px * var(--mdt-scale)); min-height: calc(38px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); background: var(--mdt-surface); color: var(--mdt-text-muted); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .07em; }
  .reader-tape span:first-child { color: var(--mdt-accent); }
  .reader-header { padding: calc(18px * var(--mdt-scale)) 0 calc(14px * var(--mdt-scale)); border-bottom: 1px solid var(--mdt-border); }
  .reader-category { color: var(--mdt-accent); font-size: calc(10px * var(--mdt-scale)); letter-spacing: .08em; text-transform: uppercase; }
  .reader-header h2 { margin: calc(6px * var(--mdt-scale)) 0 0; font-size: calc(19px * var(--mdt-scale)); line-height: 1.25; }
  .reader-header p { max-width: 72ch; margin: calc(7px * var(--mdt-scale)) 0 0; color: var(--mdt-text-muted); font-size: calc(12px * var(--mdt-scale)); line-height: 1.5; }
  .reader-body { flex: 1; max-width: 78ch; padding: calc(18px * var(--mdt-scale)) 0; color: var(--mdt-text-dim); font-size: calc(12px * var(--mdt-scale)); line-height: 1.75; }
  .reader-body :global(strong) { color: var(--mdt-text); }
  .reader-body :global(em) { color: var(--mdt-accent); }
  .reader-body :global(.sop-line) { display: block; margin: calc(5px * var(--mdt-scale)) 0; padding-left: calc(12px * var(--mdt-scale)); border-left: 2px solid var(--mdt-border-2); }
  .reader-footer { display: flex; align-items: flex-end; justify-content: space-between; gap: calc(12px * var(--mdt-scale)); padding-top: calc(12px * var(--mdt-scale)); border-top: 1px solid var(--mdt-border); }
  .reader-footer > div { display: flex; flex-direction: column; gap: calc(3px * var(--mdt-scale)); }
  .reader-footer > div span { color: var(--mdt-text-muted); font-size: calc(9px * var(--mdt-scale)); letter-spacing: .08em; }
  .reader-footer > div strong { color: var(--mdt-text-dim); font-size: calc(11px * var(--mdt-scale)); }
  .ack-button { display: inline-flex; align-items: center; justify-content: center; gap: calc(7px * var(--mdt-scale)); min-height: calc(34px * var(--mdt-scale)); padding: 0 calc(12px * var(--mdt-scale)); border: 0; border-radius: var(--mdt-radius-sm); background: var(--mdt-accent); color: var(--mdt-bg); font-size: calc(10px * var(--mdt-scale)); font-weight: 700; cursor: pointer; }
  .ack-state { display: inline-flex; align-items: center; gap: calc(7px * var(--mdt-scale)); color: var(--mdt-success); font-size: calc(10px * var(--mdt-scale)); }
  .reader-empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: calc(8px * var(--mdt-scale)); color: var(--mdt-text-muted); text-align: center; }
  .reader-empty h2 { margin: 0; color: var(--mdt-text-dim); font-size: calc(15px * var(--mdt-scale)); }
  .reader-empty p { margin: 0; font-size: calc(10px * var(--mdt-scale)); }
  .spin { animation: spin .8s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  @media (prefers-reduced-motion: reduce) { .spin { animation: none; } }
  @media (max-width: 900px) {
    .sops-page { overflow-y: auto; }
    .sops-workspace { flex: 0 0 auto; display: flex; flex-direction: column; }
    .manual-index { flex: 0 0 calc(300px * var(--mdt-scale)); min-height: calc(240px * var(--mdt-scale)); max-height: calc(400px * var(--mdt-scale)); }
    .document-reader { flex: 0 0 auto; min-height: calc(480px * var(--mdt-scale)); }
  }
  @media (max-width: 580px) {
    .reader-footer { align-items: stretch; flex-direction: column; }
  }
</style>
