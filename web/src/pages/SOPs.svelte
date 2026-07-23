<script module>
  const CAT_REF = {
    'use-of-force': 'UOF',
    'pursuit-policy': 'PUR',
    evidence: 'EVI',
    arrest: 'ARR',
    traffic: 'TRF',
    'chain-of-command': 'COC',
  };

  function docReference(sop) {
    const code = CAT_REF[sop.category] || 'GEN';
    return `SOP-${code}-${sop.version}`;
  }

  function renderMarkdown(text) {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/_(.+?)_/g, '<em>$1</em>')
      .replace(/^(\d+\.\s.+)$/gm, '<li class="sop-li">$1</li>')
      .replace(/^- (.+)$/gm, '<li class="sop-li-bullet">$1</li>')
      .replace(/\n\n/g, '<br/><br/>')
      .replace(/\n/g, '<br/>');
  }
</script>

<script>
  import { onMount } from 'svelte';
  import {
    BookOpen,
    Search,
    Shield,
    AlertTriangle,
    FileText,
    Scale,
    Car,
    Link2,
    Clock,
    CheckCircle,
    ListTree,
    ChevronRight,
    LayoutList,
    FileType,
    ChevronsDownUp,
    ChevronsUpDown,
  } from '@lucide/svelte';

  const CATEGORIES = [
    { id: 'use-of-force', label: 'Use of Force', icon: Shield },
    { id: 'pursuit-policy', label: 'Pursuit Policy', icon: Car },
    { id: 'evidence', label: 'Evidence Handling', icon: Link2 },
    { id: 'arrest', label: 'Arrest Procedures', icon: Scale },
    { id: 'traffic', label: 'Traffic Stops', icon: AlertTriangle },
    { id: 'chain-of-command', label: 'Chain of Command', icon: FileText },
  ];

  const MOCK_SOPS = [
    {
      id: 'uof-1',
      category: 'use-of-force',
      title: 'Force Continuum',
      version: '3.2',
      lastUpdated: '2026-03-01',
      status: 'active',
      content: `**PURPOSE:** Establish guidelines for the escalation and de-escalation of force by all sworn personnel.\n\n**LEVELS OF FORCE (Ascending Order):**\n1. **Officer Presence** — Uniformed officer on scene; no force applied.\n2. **Verbal Commands** — Clear, calm, direct instructions. "Stop!", "Show your hands!"\n3. **Soft Hands / Control Techniques** — Joint locks, escort holds, pressure points.\n4. **Hard Hands / Physical Force** — Punches, kicks, takedowns when actively resisted.\n5. **Less-Lethal Weapons** — Taser, pepper spray, bean-bag rounds. Document deployment immediately.\n6. **Lethal Force** — Authorized ONLY when there is an imminent threat of death or serious bodily harm to the officer or a third party.\n\n**REPORTING:** Any use of force at Level 3 or above requires a Use of Force report filed within the shift. Supervisors must review within 24 hours.`,
    },
    {
      id: 'uof-2',
      category: 'use-of-force',
      title: 'De-escalation Requirements',
      version: '2.1',
      lastUpdated: '2026-02-15',
      status: 'active',
      content: `**PURPOSE:** Officers shall attempt de-escalation before resorting to force when safe and feasible.\n\n**REQUIREMENTS:**\n- Maintain distance and cover when possible.\n- Use time as a tactical advantage — there is no rush if no life is in immediate danger.\n- Communicate calmly and clearly; repeat instructions.\n- Request backup before initiating confrontation with armed/erratic subjects.\n- Consider the subject's mental state, language barriers, or medical conditions.\n\n**EXCEPTIONS:** De-escalation is not required when immediate action is necessary to prevent death or serious injury.`,
    },
    {
      id: 'pp-1',
      category: 'pursuit-policy',
      title: 'Vehicle Pursuit Authorization',
      version: '4.0',
      lastUpdated: '2026-03-10',
      status: 'active',
      content: `**AUTHORIZATION:** Vehicle pursuits are permitted ONLY for violent felonies or when the suspect poses an immediate public safety threat.\n\n**PURSUIT INITIATION:**\n1. Notify dispatch immediately with suspect description, vehicle, direction, and reason.\n2. Supervisor must authorize continuation within 60 seconds or the pursuit is terminated.\n3. Maximum of 3 units in pursuit; all others stage at intersections.\n\n**TERMINATION CRITERIA:**\n- Supervisor orders termination.\n- Conditions become unsafe (heavy traffic, school zones, residential areas).\n- Suspect identity is known and can be apprehended later.\n- Officer loses visual contact for more than 15 seconds.\n\n**PIT MANEUVER:** Authorized only by a supervisor at speeds below 40 mph on clear roadways.`,
    },
    {
      id: 'pp-2',
      category: 'pursuit-policy',
      title: 'Pursuit Reporting',
      version: '2.0',
      lastUpdated: '2026-01-20',
      status: 'active',
      content: `**DOCUMENTATION:** All pursuits require a detailed Pursuit Report filed within 2 hours of termination.\n\n**REQUIRED ELEMENTS:**\n- Reason for initiating pursuit.\n- Duration, top speed, route taken.\n- Number of units involved.\n- Outcome (apprehension, termination, crash).\n- Any property damage or injuries.\n- Body camera footage reference.\n\n**REVIEW:** Pursuit Review Board convenes within 72 hours for any pursuit exceeding 5 minutes or resulting in damage/injury.`,
    },
    {
      id: 'ev-1',
      category: 'evidence',
      title: 'Evidence Collection & Chain of Custody',
      version: '3.5',
      lastUpdated: '2026-02-28',
      status: 'active',
      content: `**CHAIN OF CUSTODY:** Every piece of evidence must have an unbroken chain of custody from collection to court presentation.\n\n**COLLECTION PROCEDURES:**\n1. Photograph evidence in situ before touching.\n2. Wear gloves at all times when handling physical evidence.\n3. Use designated evidence bags/containers. Label with: case number, date, time, location, collecting officer.\n4. For digital evidence: capture screenshots, note timestamps, preserve originals.\n5. For biological evidence: use separate containers, keep refrigerated.\n\n**STORAGE:** All evidence is logged into the Evidence Management System (EMS) within 1 hour of collection. Physical items go to the evidence locker; access requires supervisor authorization.`,
    },
    {
      id: 'ev-2',
      category: 'evidence',
      title: 'Digital Evidence & CCTV Retrieval',
      version: '1.8',
      lastUpdated: '2026-03-05',
      status: 'active',
      content: `**DIGITAL EVIDENCE:**\n- All body camera footage is automatically uploaded; officers must tag relevant segments.\n- CCTV footage requests must include: case number, locations, time range (±15 min recommended).\n- Screenshots and exports must be saved as original format; no editing.\n\n**RETENTION:**\n- Routine: 90 days unless attached to a case.\n- Active cases: retained for duration of case + 1 year.\n- Felony cases: retained for 7 years minimum.\n\n**DELETION:** Only authorized by Records Division supervisor. Requires written documentation.`,
    },
    {
      id: 'ar-1',
      category: 'arrest',
      title: 'Arrest Procedures & Miranda Rights',
      version: '5.0',
      lastUpdated: '2026-03-12',
      status: 'active',
      content: `**ARREST AUTHORITY:** Officers may arrest when:\n- A warrant exists for the individual.\n- A crime is committed in the officer's presence.\n- Probable cause exists that a felony has been committed.\n\n**MIRANDA WARNING:** Must be given BEFORE custodial interrogation. Failure invalidates statements.\n\n_"You have the right to remain silent. Anything you say can and will be used against you in a court of law. You have the right to an attorney. If you cannot afford an attorney, one will be provided for you."_\n\n**BOOKING PROCEDURES:**\n1. Search incident to arrest (pat-down + property inventory).\n2. Transport to station in a secure vehicle.\n3. Process through booking (prints, photos, charges, property log).\n4. Notify dispatch of booking with charges.`,
    },
    {
      id: 'ar-2',
      category: 'arrest',
      title: 'Juvenile & Vulnerable Person Procedures',
      version: '2.3',
      lastUpdated: '2026-02-01',
      status: 'active',
      content: `**JUVENILES (Under 18):**\n- Contact parent/guardian immediately upon detention.\n- Do not interrogate without parent/guardian or attorney present.\n- Transport separately from adult detainees.\n- File juvenile incident report (separate from adult system).\n\n**VULNERABLE PERSONS:**\n- Individuals with mental health crises: request Crisis Intervention Team (CIT) officer if available.\n- Individuals with disabilities: provide reasonable accommodations.\n- Elderly individuals: assess medical needs before transport.\n- Non-English speakers: request interpreter; do not rely on bystanders.`,
    },
    {
      id: 'ts-1',
      category: 'traffic',
      title: 'Traffic Stop Procedures',
      version: '3.1',
      lastUpdated: '2026-03-08',
      status: 'active',
      content: `**INITIATION:**\n1. Activate emergency lights (and siren if needed).\n2. Notify dispatch: location, vehicle description, plate number, number of occupants.\n3. Select a safe location — well-lit, away from intersections, shoulder of road when possible.\n\n**APPROACH:**\n- Driver side or passenger side approach depending on traffic conditions.\n- Maintain awareness of all occupants.\n- Request license, registration, and insurance.\n- Body camera must be active for the entire stop.\n\n**CITATIONS:**\n- Explain the violation clearly.\n- Offer verbal/written warning when appropriate for minor infractions.\n- Issue citation through the MDT system with correct charge codes.\n- Inform the driver of their court date or online payment options.`,
    },
    {
      id: 'ts-2',
      category: 'traffic',
      title: 'DUI / Impaired Driving Protocol',
      version: '2.5',
      lastUpdated: '2026-02-20',
      status: 'active',
      content: `**INDICATORS:**\n- Swerving, inconsistent speed, failure to maintain lane.\n- Odor of alcohol/marijuana, slurred speech, bloodshot eyes.\n- Difficulty producing documents.\n\n**FIELD SOBRIETY TESTS (FSTs):**\n1. Horizontal Gaze Nystagmus (HGN).\n2. Walk and Turn.\n3. One-Leg Stand.\n\n**BREATHALYZER:** Administer roadside PBT if FSTs indicate impairment. PBT results are probable cause only — not admissible in court.\n\n**ARREST & BOOKING:** At station, administer Evidential Breath Test (EBT) or request blood draw. Document BAC, all observations, and FST performance in the DUI report.`,
    },
    {
      id: 'cc-1',
      category: 'chain-of-command',
      title: 'Rank Structure & Authority',
      version: '1.5',
      lastUpdated: '2026-01-15',
      status: 'active',
      content: `**RANK HIERARCHY (Ascending):**\n1. **Cadet / Recruit** — In training; no independent authority.\n2. **Officer** — Patrol and response duties; full arrest authority.\n3. **Corporal (CPL)** — Senior officer; may lead a patrol team.\n4. **Sergeant (SGT)** — First-line supervisor; approves reports, authorizes pursuits.\n5. **Lieutenant (LT)** — Division commander; manages units and personnel.\n6. **Captain (CPT)** — Bureau commander; strategic oversight.\n7. **Deputy Chief** — Heads a major division (Operations, Investigations, Admin).\n8. **Chief of Police** — Final authority on department policy and operations.\n\n**ACTING RANKS:** When a supervisor is unavailable, the next senior officer assumes acting authority and must log this in the MDT.`,
    },
    {
      id: 'cc-2',
      category: 'chain-of-command',
      title: 'Internal Complaints & IA Procedures',
      version: '2.0',
      lastUpdated: '2026-02-10',
      status: 'active',
      content: `**FILING A COMPLAINT:**\n- Any citizen or officer may file a formal complaint.\n- Complaints are submitted in writing to Internal Affairs (IA) or the Watch Commander.\n- Anonymous complaints are accepted but carry lower investigative priority.\n\n**INVESTIGATION PROCESS:**\n1. IA assigns a case number and investigating officer (not involved with the incident).\n2. Interviews conducted within 10 business days.\n3. Evidence reviewed: body camera, CAD records, witness statements.\n4. Finding categories: Sustained, Not Sustained, Exonerated, Unfounded.\n\n**DISCIPLINE:** Progressive discipline applies — counseling → written reprimand → suspension → termination. Severity depends on the nature of the violation.`,
    },
  ];

  let mounted = $state(false);
  let searchQuery = $state('');
  /** @type {Set<string>} */
  let expandedCats = $state(new Set(CATEGORIES[0] ? [CATEGORIES[0].id] : []));
  let selectedSopId = $state(MOCK_SOPS[0]?.id ?? null);
  /** @type {'index' | 'document'} */
  let mobilePane = $state('index');

  let searching = $derived(Boolean(searchQuery.trim()));

  let filteredSops = $derived.by(() => {
    let result = MOCK_SOPS;
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      result = result.filter(
        (s) =>
          s.title.toLowerCase().includes(q) ||
          s.content.toLowerCase().includes(q) ||
          s.category.toLowerCase().includes(q) ||
          docReference(s).toLowerCase().includes(q)
      );
    }
    return result;
  });

  let categoryCounts = $derived.by(() => {
    const counts = {};
    for (const cat of CATEGORIES) {
      counts[cat.id] = MOCK_SOPS.filter((s) => s.category === cat.id).length;
    }
    return counts;
  });

  let selectedSop = $derived.by(() => {
    if (!selectedSopId) return null;
    return MOCK_SOPS.find((s) => s.id === selectedSopId) ?? null;
  });

  $effect(() => {
    const list = filteredSops;
    if (!list.length) {
      selectedSopId = null;
      return;
    }
    if (!selectedSopId || !list.some((s) => s.id === selectedSopId)) {
      selectedSopId = list[0].id;
      if (!searching) {
        const next = new Set(expandedCats);
        next.add(list[0].category);
        expandedCats = next;
      }
    }
  });

  onMount(() => {
    mounted = true;
  });

  function categoryMeta(catId) {
    return CATEGORIES.find((c) => c.id === catId);
  }

  function selectSop(id) {
    selectedSopId = id;
    mobilePane = 'document';
    if (!searching) {
      const sop = MOCK_SOPS.find((s) => s.id === id);
      if (sop) {
        const next = new Set(expandedCats);
        next.add(sop.category);
        expandedCats = next;
      }
    }
  }

  function chapterOpen(catId, count) {
    if (searching) return count > 0;
    return expandedCats.has(catId);
  }

  function toggleChapter(catId) {
    if (searching) return;
    const next = new Set(expandedCats);
    if (next.has(catId)) next.delete(catId);
    else next.add(catId);
    expandedCats = next;
  }

  function expandAllChapters() {
    expandedCats = new Set(CATEGORIES.map((c) => c.id));
  }

  function collapseAllChapters() {
    expandedCats = new Set();
  }

  function sopsInChapter(catId) {
    return filteredSops.filter((s) => s.category === catId);
  }
</script>

<div class="sops-root" class:mounted>
  <header class="sops-hero">
    <div class="hero-main">
      <div class="hero-kicker font-mono">Policy manual</div>
      <h1 class="hero-title">Standard Operating Procedures</h1>
      <p class="hero-lead">
        Controlled references for field conduct, custody, evidence, and command. Open a chapter in the sidebar, pick a
        directive. Text matches department issue records.
      </p>
    </div>
    <div class="hero-aside">
      <div class="hero-stat font-mono">
        <span class="stat-value">{MOCK_SOPS.length}</span>
        <span class="stat-label">directives on file</span>
      </div>
      <label class="search-field">
        <span class="visually-hidden">Search procedures</span>
        <Search size={14} strokeWidth={2} class="search-ico" aria-hidden="true" />
        <input
          class="search-input font-mono"
          type="search"
          placeholder="Search title, body, or SOP code…"
          bind:value={searchQuery}
          autocomplete="off"
        />
      </label>
    </div>
  </header>

  <div class="mobile-toggle font-mono" role="tablist" aria-label="SOP view">
    <button type="button" role="tab" aria-selected={mobilePane === 'index'} class:mactive={mobilePane === 'index'} onclick={() => (mobilePane = 'index')}>
      <LayoutList size={14} strokeWidth={2} /> Index
    </button>
    <button type="button" role="tab" aria-selected={mobilePane === 'document'} class:mactive={mobilePane === 'document'} onclick={() => (mobilePane = 'document')}>
      <FileType size={14} strokeWidth={2} /> Document
    </button>
  </div>

  <div class="sops-grid" class:show-doc={mobilePane === 'document'}>
    <aside class="docs-sidebar" aria-label="Table of contents">
      <div class="sidebar-toolbar">
        <div class="sidebar-head font-mono">
          <ListTree size={14} strokeWidth={2} />
          Contents
        </div>
        <span class="sidebar-meta font-mono">
          {#if searching}
            {filteredSops.length} match{filteredSops.length === 1 ? '' : 'es'}
          {:else}
            {MOCK_SOPS.length} directives
          {/if}
        </span>
      </div>
      {#if !searching}
        <div class="sidebar-actions font-mono">
          <button type="button" class="sidebar-action" onclick={expandAllChapters}>
            <ChevronsDownUp size={12} strokeWidth={2} aria-hidden="true" /> Expand all
          </button>
          <span class="sidebar-action-sep" aria-hidden="true"></span>
          <button type="button" class="sidebar-action" onclick={collapseAllChapters}>
            <ChevronsUpDown size={12} strokeWidth={2} aria-hidden="true" /> Collapse
          </button>
        </div>
      {/if}

      <nav class="docs-nav">
        {#if filteredSops.length === 0}
          <div class="empty-state">
            <BookOpen size={28} strokeWidth={1.25} />
            <div class="empty-copy">
              <span class="empty-title">No matching directives</span>
              <span class="empty-hint font-mono">Clear search to show the manual.</span>
            </div>
          </div>
        {:else}
          {#each CATEGORIES as cat (cat.id)}
            {@const Icon = cat.icon}
            {@const items = sopsInChapter(cat.id)}
            {@const open = chapterOpen(cat.id, items.length)}
            {@const total = categoryCounts[cat.id] ?? 0}
            <div class="chapter-group" class:dim={!searching && total === 0}>
              <button
                type="button"
                class="chapter-toggle font-mono"
                aria-expanded={open}
                disabled={!searching && total === 0}
                onclick={() => toggleChapter(cat.id)}
              >
                <span class="chapter-chev-wrap" class:open>
                  <ChevronRight size={14} strokeWidth={2} aria-hidden="true" />
                </span>
                <Icon size={13} strokeWidth={2} class="chapter-ico" aria-hidden="true" />
                <span class="chapter-title">{cat.label}</span>
                <span class="chapter-badge">{searching ? items.length : total}</span>
              </button>
              {#if open && items.length > 0}
                <ul class="sop-list">
                  {#each items as sop (sop.id)}
                    <li>
                      <button
                        type="button"
                        class="sop-link font-mono"
                        class:selected={selectedSopId === sop.id}
                        onclick={() => selectSop(sop.id)}
                      >
                        <span class="sop-ref">{docReference(sop)}</span>
                        <span class="sop-name">{sop.title}</span>
                      </button>
                    </li>
                  {/each}
                </ul>
              {/if}
            </div>
          {/each}
        {/if}
      </nav>
    </aside>

    <!-- Reader -->
    <article class="reader-panel">
      {#if selectedSop}
        {@const catMeta = categoryMeta(selectedSop.category)}
        <div class="reader-body">
          <div class="reader-tape font-mono">
            <span class="tape-ref">{docReference(selectedSop)}</span>
            <span class="tape-sep">/</span>
            <span>Rev. {selectedSop.version}</span>
            <span class="tape-sep">/</span>
            <span class="tape-date"><Clock size={11} strokeWidth={2} /> {selectedSop.lastUpdated}</span>
          </div>
          <header class="reader-header">
            <div class="reader-badges">
              {#if catMeta}
                {@const CatIcon = catMeta.icon}
                <span class="badge-pill font-mono">
                  <CatIcon size={12} strokeWidth={2} />
                  {catMeta.label}
                </span>
              {/if}
              <span class="badge-pill font-mono" class:live={selectedSop.status === 'active'}>
                {#if selectedSop.status === 'active'}
                  <CheckCircle size={12} strokeWidth={2} /> Issued
                {:else}
                  Draft
                {/if}
              </span>
            </div>
            <h2 class="reader-title">{selectedSop.title}</h2>
          </header>
          <div class="reader-divider" aria-hidden="true"></div>
          <div class="reader-prose">
            {@html renderMarkdown(selectedSop.content)}
          </div>
          <footer class="reader-footer font-mono">
            <span>Controlled document — verify revision before reliance in reports or testimony.</span>
          </footer>
        </div>
      {:else}
        <div class="reader-placeholder">
          <BookOpen size={36} strokeWidth={1} />
          <p class="ph-title">No directive loaded</p>
          <p class="ph-hint font-mono">Clear search or pick a directive in the sidebar.</p>
        </div>
      {/if}
    </article>
  </div>
</div>

<style>
  .font-mono {
    font-family: 'Share Tech Mono', monospace;
  }
  .visually-hidden {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }

  .sops-root {
    --sops-pad: calc(22px * var(--mdt-scale));
    --sops-gap: calc(14px * var(--mdt-scale));
    padding: var(--sops-pad);
    display: flex;
    flex-direction: column;
    gap: var(--sops-gap);
    min-height: 0;
    flex: 1;
    opacity: 0;
  }
  .sops-root.mounted {
    animation: sopsFade 0.45s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }

  /* Hero — offset stack, not centered billboard */
  .sops-hero {
    display: grid;
    grid-template-columns: 1fr;
    gap: calc(18px * var(--mdt-scale));
    align-items: start;
    padding-bottom: calc(4px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }
  @media (min-width: 900px) {
    .sops-hero {
      grid-template-columns: minmax(0, 1.15fr) minmax(220px, 320px);
      align-items: end;
    }
  }

  .hero-kicker {
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--mdt-accent);
    margin-bottom: calc(6px * var(--mdt-scale));
  }
  .hero-title {
    font-size: calc(19px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.02em;
    color: var(--mdt-text);
    margin: 0 0 calc(8px * var(--mdt-scale));
    line-height: 1.15;
  }
  .hero-lead {
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.55;
    color: var(--mdt-text-dim);
    max-width: 58ch;
    margin: 0;
  }

  .hero-aside {
    display: flex;
    flex-direction: column;
    gap: calc(12px * var(--mdt-scale));
  }
  @media (min-width: 900px) {
    .hero-aside {
      border-left: 1px solid var(--mdt-border);
      padding-left: calc(18px * var(--mdt-scale));
    }
  }
  .hero-stat {
    display: flex;
    flex-direction: column;
    gap: calc(2px * var(--mdt-scale));
    padding: 0 0 calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
  }
  .stat-value {
    font-size: calc(26px * var(--mdt-scale));
    font-variant-numeric: tabular-nums;
    color: var(--mdt-text);
    line-height: 1;
  }
  .stat-label {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    letter-spacing: 0.04em;
  }

  .search-field {
    display: flex;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) 0;
    border-bottom: 1px solid var(--mdt-border);
    color: var(--mdt-text-muted);
  }
  :global(.search-ico) {
    flex-shrink: 0;
    opacity: 0.75;
  }
  .search-input {
    flex: 1;
    min-width: 0;
    background: transparent;
    border: none;
    outline: none;
    font-size: calc(11px * var(--mdt-scale));
    color: var(--mdt-text);
  }
  .search-input::placeholder {
    color: var(--mdt-text-muted);
  }

  .mobile-toggle {
    display: flex;
    gap: 0;
    padding: 0;
    background: transparent;
    border: none;
    border-bottom: 1px solid var(--mdt-border);
    border-radius: 0;
  }
  .mobile-toggle button {
    flex: 1;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(10px * var(--mdt-scale));
    border: none;
    border-radius: 0;
    border-bottom: 2px solid transparent;
    margin-bottom: -1px;
    background: transparent;
    color: var(--mdt-text-muted);
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.06em;
    text-transform: uppercase;
    cursor: pointer;
    transition:
      color 0.18s ease,
      border-color 0.18s ease;
  }
  .mobile-toggle button.mactive {
    color: var(--mdt-accent);
    background: transparent;
    border-bottom-color: var(--mdt-accent);
  }
  @media (min-width: 1000px) {
    .mobile-toggle {
      display: none;
    }
  }

  .sops-grid {
    display: grid;
    grid-template-columns: 1fr;
    grid-template-rows: auto 1fr;
    gap: calc(10px * var(--mdt-scale));
    min-height: 0;
    flex: 1;
  }
  @media (min-width: 1000px) {
    .sops-grid {
      grid-template-columns: minmax(240px, 300px) minmax(0, 1fr);
      grid-template-rows: 1fr;
      gap: 0;
      column-gap: calc(20px * var(--mdt-scale));
    }
  }

  @media (max-width: 999px) {
    .sops-grid:not(.show-doc) .reader-panel {
      display: none;
    }
    .sops-grid.show-doc .docs-sidebar {
      display: none;
    }
    .sops-grid.show-doc .reader-panel {
      display: flex;
      min-height: min(calc(70vh * var(--mdt-scale)), calc(520px * var(--mdt-scale)));
    }
  }

  .docs-sidebar {
    display: flex;
    flex-direction: column;
    min-height: 0;
    min-width: 0;
  }
  @media (min-width: 1000px) {
    .docs-sidebar {
      max-height: calc(100vh - 220px * var(--mdt-scale));
      padding-right: calc(4px * var(--mdt-scale));
      border-right: 1px solid var(--mdt-border);
    }
  }

  .sidebar-toolbar {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: calc(10px * var(--mdt-scale));
    padding-bottom: calc(10px * var(--mdt-scale));
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
  }
  .sidebar-head {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
  }
  .sidebar-meta {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    font-variant-numeric: tabular-nums;
  }

  .sidebar-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) 0;
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
  }
  .sidebar-action {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: 0;
    border: none;
    background: none;
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    cursor: pointer;
  }
  .sidebar-action:hover {
    color: var(--mdt-accent);
  }
  .sidebar-action-sep {
    width: 1px;
    height: calc(12px * var(--mdt-scale));
    background: var(--mdt-border);
  }

  .docs-nav {
    flex: 1;
    min-height: 0;
    overflow-x: hidden;
    overflow-y: auto;
    padding-top: calc(4px * var(--mdt-scale));
    scrollbar-width: thin;
  }

  .chapter-group {
    border-bottom: 1px solid var(--mdt-border);
  }
  .chapter-group.dim .chapter-toggle:not(:disabled) {
    color: var(--mdt-text-muted);
  }

  .chapter-toggle {
    display: flex;
    align-items: center;
    gap: calc(8px * var(--mdt-scale));
    width: 100%;
    padding: calc(10px * var(--mdt-scale)) calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) 0;
    border: none;
    background: transparent;
    color: var(--mdt-text);
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.05em;
    text-transform: uppercase;
    text-align: left;
    cursor: pointer;
  }
  .chapter-toggle:disabled {
    cursor: default;
    opacity: 0.5;
  }
  .chapter-toggle:not(:disabled):hover {
    color: var(--mdt-accent);
  }

  .chapter-chev-wrap {
    display: inline-flex;
    flex-shrink: 0;
    transition: transform 0.2s ease;
    color: var(--mdt-text-muted);
  }
  .chapter-chev-wrap.open {
    transform: rotate(90deg);
    color: var(--mdt-accent);
  }
  :global(.chapter-ico) {
    flex-shrink: 0;
    opacity: 0.85;
  }
  .chapter-title {
    flex: 1;
    min-width: 0;
    font-weight: 600;
  }
  .chapter-badge {
    font-size: calc(9px * var(--mdt-scale));
    font-variant-numeric: tabular-nums;
    color: var(--mdt-text-muted);
  }

  .sop-list {
    list-style: none;
    margin: 0;
    padding: 0 0 calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    border-left: 1px solid var(--mdt-border);
    margin-left: calc(9px * var(--mdt-scale));
  }
  .sop-link {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: calc(2px * var(--mdt-scale));
    width: 100%;
    padding: calc(7px * var(--mdt-scale)) calc(8px * var(--mdt-scale));
    margin-bottom: calc(1px * var(--mdt-scale));
    border: none;
    border-left: 2px solid transparent;
    margin-left: calc(-1px * var(--mdt-scale));
    padding-left: calc(10px * var(--mdt-scale));
    background: transparent;
    text-align: left;
    cursor: pointer;
    color: var(--mdt-text-dim);
    transition:
      color 0.15s ease,
      border-color 0.15s ease;
  }
  .sop-link:hover {
    color: var(--mdt-text);
  }
  .sop-link.selected {
    color: var(--mdt-text);
    border-left-color: var(--mdt-accent);
  }
  .sop-ref {
    font-size: calc(9px * var(--mdt-scale));
    color: var(--mdt-accent);
    letter-spacing: 0.04em;
  }
  .sop-name {
    font-family: inherit;
    font-size: calc(11px * var(--mdt-scale));
    font-weight: 500;
    line-height: 1.35;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(12px * var(--mdt-scale));
    padding: calc(36px * var(--mdt-scale)) calc(16px * var(--mdt-scale));
    color: var(--mdt-text-muted);
    text-align: center;
  }
  .empty-copy {
    display: flex;
    flex-direction: column;
    gap: calc(4px * var(--mdt-scale));
  }
  .empty-title {
    font-size: calc(13px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
  }
  .empty-hint {
    font-size: calc(10px * var(--mdt-scale));
    color: var(--mdt-text-muted);
  }

  .reader-panel {
    display: flex;
    flex-direction: column;
    min-height: 0;
    min-width: 0;
  }
  @media (min-width: 1000px) {
    .reader-panel {
      max-height: calc(100vh - 220px * var(--mdt-scale));
    }
  }

  .reader-body {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .reader-tape {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: calc(6px * var(--mdt-scale));
    padding: calc(8px * var(--mdt-scale)) 0;
    font-size: calc(10px * var(--mdt-scale));
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    background: transparent;
    border-bottom: 1px solid var(--mdt-border);
    flex-shrink: 0;
  }
  .tape-ref {
    color: var(--mdt-accent);
    font-weight: 600;
  }
  .tape-sep {
    opacity: 0.25;
  }
  .tape-date {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
  }

  .reader-header {
    padding: calc(14px * var(--mdt-scale)) 0 0;
    flex-shrink: 0;
  }
  .reader-badges {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0;
    margin-bottom: calc(10px * var(--mdt-scale));
  }
  .badge-pill {
    display: inline-flex;
    align-items: center;
    gap: calc(5px * var(--mdt-scale));
    padding: 0 calc(10px * var(--mdt-scale)) 0 0;
    margin-right: calc(10px * var(--mdt-scale));
    border-right: 1px solid var(--mdt-border);
    font-size: calc(9px * var(--mdt-scale));
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--mdt-text-muted);
    background: transparent;
    border-top: none;
    border-bottom: none;
    border-left: none;
    border-radius: 0;
  }
  .badge-pill:last-child {
    border-right: none;
    margin-right: 0;
    padding-right: 0;
  }
  .badge-pill.live {
    color: var(--mdt-success);
  }
  .reader-title {
    font-size: calc(17px * var(--mdt-scale));
    font-weight: 700;
    letter-spacing: -0.02em;
    color: var(--mdt-text);
    margin: 0;
    line-height: 1.2;
    text-wrap: balance;
  }

  .reader-divider {
    height: 1px;
    margin: calc(12px * var(--mdt-scale)) 0 0;
    background: var(--mdt-border);
    flex-shrink: 0;
  }

  .reader-prose {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: calc(14px * var(--mdt-scale)) 0 calc(16px * var(--mdt-scale));
    font-size: calc(12px * var(--mdt-scale));
    line-height: 1.65;
    color: var(--mdt-text-dim);
    max-width: 72ch;
  }
  .reader-prose :global(strong) {
    color: var(--mdt-text);
    font-weight: 600;
  }
  .reader-prose :global(em) {
    color: var(--mdt-accent);
    font-style: italic;
  }
  .reader-prose :global(.sop-li),
  .reader-prose :global(.sop-li-bullet) {
    display: block;
    padding-left: calc(14px * var(--mdt-scale));
    margin: calc(4px * var(--mdt-scale)) 0;
    border-left: 2px solid var(--mdt-border-2);
    padding-top: calc(2px * var(--mdt-scale));
    padding-bottom: calc(2px * var(--mdt-scale));
  }

  .reader-footer {
    padding: calc(10px * var(--mdt-scale)) 0 0;
    font-size: calc(9px * var(--mdt-scale));
    line-height: 1.45;
    color: var(--mdt-text-muted);
    border-top: 1px solid var(--mdt-border);
    background: transparent;
    flex-shrink: 0;
  }

  .reader-placeholder {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: calc(10px * var(--mdt-scale));
    padding: calc(40px * var(--mdt-scale)) 0;
    color: var(--mdt-text-muted);
    border: none;
    border-radius: 0;
    border-top: 1px dashed var(--mdt-border);
    background: transparent;
  }
  .ph-title {
    font-size: calc(14px * var(--mdt-scale));
    font-weight: 600;
    color: var(--mdt-text-dim);
    margin: 0;
  }
  .ph-hint {
    margin: 0;
    font-size: calc(10px * var(--mdt-scale));
  }

  @keyframes sopsFade {
    from {
      opacity: 0;
      transform: translateY(calc(4px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>
