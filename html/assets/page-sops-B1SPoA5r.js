import{E as nt,d as it,y as lt,v as j,w as we,Q as ot,h as e,x as o,z as ct,o as s,m as r,F as E,A as T,C as _,J as d,B as ae,H as dt,I as z,b as l,c as pt,u as v,K as re,i as vt,j as _e,e as Ce,N as ke,a1 as mt,D as m}from"./vendor-svelte-BolpnJ6y.js";import{g as ht,k as ut,ak as ft,b as gt,h as yt,j as xt,z as bt,al as wt,am as _t,an as Ct,ao as kt,ap as It,B as Ie,C as St,H as Et,aq as Tt}from"./vendor-icons-DgjCd7Z9.js";const At={"use-of-force":"UOF","pursuit-policy":"PUR",evidence:"EVI",arrest:"ARR",traffic:"TRF","chain-of-command":"COC"};function se(C){return`SOP-${At[C.category]||"GEN"}-${C.version}`}function Rt(C){return C.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/\*\*(.+?)\*\*/g,"<strong>$1</strong>").replace(/_(.+?)_/g,"<em>$1</em>").replace(/^(\d+\.\s.+)$/gm,'<li class="sop-li">$1</li>').replace(/^- (.+)$/gm,'<li class="sop-li-bullet">$1</li>').replace(/\n\n/g,"<br/><br/>").replace(/\n/g,"<br/>")}var Ot=m('<div class="sidebar-actions font-mono svelte-1apcyhl"><button type="button" class="sidebar-action svelte-1apcyhl"><!> Expand all</button> <span class="sidebar-action-sep svelte-1apcyhl" aria-hidden="true"></span> <button type="button" class="sidebar-action svelte-1apcyhl"><!> Collapse</button></div>'),zt=m('<div class="empty-state svelte-1apcyhl"><!> <div class="empty-copy svelte-1apcyhl"><span class="empty-title svelte-1apcyhl">No matching directives</span> <span class="empty-hint font-mono svelte-1apcyhl">Clear search to show the manual.</span></div></div>'),Nt=m('<li><button type="button"><span class="sop-ref svelte-1apcyhl"> </span> <span class="sop-name svelte-1apcyhl"> </span></button></li>'),Pt=m('<ul class="sop-list svelte-1apcyhl"></ul>'),Ut=m('<div><button type="button" class="chapter-toggle font-mono svelte-1apcyhl"><span><!></span> <!> <span class="chapter-title svelte-1apcyhl"> </span> <span class="chapter-badge svelte-1apcyhl"> </span></button> <!></div>'),Lt=m('<span class="badge-pill font-mono svelte-1apcyhl"><!> </span>'),Dt=m("<!> Issued",1),Ft=m('<div class="reader-body svelte-1apcyhl"><div class="reader-tape font-mono svelte-1apcyhl"><span class="tape-ref svelte-1apcyhl"> </span> <span class="tape-sep svelte-1apcyhl">/</span> <span> </span> <span class="tape-sep svelte-1apcyhl">/</span> <span class="tape-date svelte-1apcyhl"><!> </span></div> <header class="reader-header svelte-1apcyhl"><div class="reader-badges svelte-1apcyhl"><!> <span><!></span></div> <h2 class="reader-title svelte-1apcyhl"> </h2></header> <div class="reader-divider svelte-1apcyhl" aria-hidden="true"></div> <div class="reader-prose svelte-1apcyhl"></div> <footer class="reader-footer font-mono svelte-1apcyhl"><span>Controlled document — verify revision before reliance in reports or testimony.</span></footer></div>'),Mt=m('<div class="reader-placeholder svelte-1apcyhl"><!> <p class="ph-title svelte-1apcyhl">No directive loaded</p> <p class="ph-hint font-mono svelte-1apcyhl">Clear search or pick a directive in the sidebar.</p></div>'),Wt=m(`<div><header class="sops-hero svelte-1apcyhl"><div class="hero-main"><div class="hero-kicker font-mono svelte-1apcyhl">Policy manual</div> <h1 class="hero-title svelte-1apcyhl">Standard Operating Procedures</h1> <p class="hero-lead svelte-1apcyhl">Controlled references for field conduct, custody, evidence, and command. Open a chapter in the sidebar, pick a
        directive. Text matches department issue records.</p></div> <div class="hero-aside svelte-1apcyhl"><div class="hero-stat font-mono svelte-1apcyhl"><span class="stat-value svelte-1apcyhl"> </span> <span class="stat-label svelte-1apcyhl">directives on file</span></div> <label class="search-field svelte-1apcyhl"><span class="visually-hidden svelte-1apcyhl">Search procedures</span> <!> <input class="search-input font-mono svelte-1apcyhl" type="search" placeholder="Search title, body, or SOP code…" autocomplete="off"/></label></div></header> <div class="mobile-toggle font-mono svelte-1apcyhl" role="tablist" aria-label="SOP view"><button type="button" role="tab"><!> Index</button> <button type="button" role="tab"><!> Document</button></div> <div><aside class="docs-sidebar svelte-1apcyhl" aria-label="Table of contents"><div class="sidebar-toolbar svelte-1apcyhl"><div class="sidebar-head font-mono svelte-1apcyhl"><!> Contents</div> <span class="sidebar-meta font-mono svelte-1apcyhl"><!></span></div> <!> <nav class="docs-nav svelte-1apcyhl"><!></nav></aside> <article class="reader-panel svelte-1apcyhl"><!></article></div></div>`);const Bt={hash:"svelte-1apcyhl",code:`.font-mono.svelte-1apcyhl {font-family:'Share Tech Mono', monospace;}.visually-hidden.svelte-1apcyhl {position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0, 0, 0, 0);white-space:nowrap;border:0;}.sops-root.svelte-1apcyhl {--sops-pad: calc(22px * var(--mdt-scale));--sops-gap: calc(14px * var(--mdt-scale));padding:var(--sops-pad);display:flex;flex-direction:column;gap:var(--sops-gap);min-height:0;flex:1;opacity:0;}.sops-root.mounted.svelte-1apcyhl {
    animation: svelte-1apcyhl-sopsFade 0.45s cubic-bezier(0.16, 1, 0.3, 1) forwards;}

  /* Hero — offset stack, not centered billboard */.sops-hero.svelte-1apcyhl {display:grid;grid-template-columns:1fr;gap:calc(18px * var(--mdt-scale));align-items:start;padding-bottom:calc(4px * var(--mdt-scale));border-bottom:1px solid var(--mdt-border);}
  @media (min-width: 900px) {.sops-hero.svelte-1apcyhl {grid-template-columns:minmax(0, 1.15fr) minmax(220px, 320px);align-items:end;}
  }.hero-kicker.svelte-1apcyhl {font-size:calc(10px * var(--mdt-scale));letter-spacing:0.14em;text-transform:uppercase;color:var(--mdt-accent);margin-bottom:calc(6px * var(--mdt-scale));}.hero-title.svelte-1apcyhl {font-size:calc(19px * var(--mdt-scale));font-weight:700;letter-spacing:-0.02em;color:var(--mdt-text);margin:0 0 calc(8px * var(--mdt-scale));line-height:1.15;}.hero-lead.svelte-1apcyhl {font-size:calc(12px * var(--mdt-scale));line-height:1.55;color:var(--mdt-text-dim);max-width:58ch;margin:0;}.hero-aside.svelte-1apcyhl {display:flex;flex-direction:column;gap:calc(12px * var(--mdt-scale));}
  @media (min-width: 900px) {.hero-aside.svelte-1apcyhl {border-left:1px solid var(--mdt-border);padding-left:calc(18px * var(--mdt-scale));}
  }.hero-stat.svelte-1apcyhl {display:flex;flex-direction:column;gap:calc(2px * var(--mdt-scale));padding:0 0 calc(10px * var(--mdt-scale));border-bottom:1px solid var(--mdt-border);}.stat-value.svelte-1apcyhl {font-size:calc(26px * var(--mdt-scale));font-variant-numeric:tabular-nums;color:var(--mdt-text);line-height:1;}.stat-label.svelte-1apcyhl {font-size:calc(10px * var(--mdt-scale));color:var(--mdt-text-muted);letter-spacing:0.04em;}.search-field.svelte-1apcyhl {display:flex;align-items:center;gap:calc(10px * var(--mdt-scale));padding:calc(8px * var(--mdt-scale)) 0;border-bottom:1px solid var(--mdt-border);color:var(--mdt-text-muted);}.search-ico {flex-shrink:0;opacity:0.75;}.search-input.svelte-1apcyhl {flex:1;min-width:0;background:transparent;border:none;outline:none;font-size:calc(11px * var(--mdt-scale));color:var(--mdt-text);}.search-input.svelte-1apcyhl::-moz-placeholder {color:var(--mdt-text-muted);}.search-input.svelte-1apcyhl::placeholder {color:var(--mdt-text-muted);}.mobile-toggle.svelte-1apcyhl {display:flex;gap:0;padding:0;background:transparent;border:none;border-bottom:1px solid var(--mdt-border);border-radius:0;}.mobile-toggle.svelte-1apcyhl button:where(.svelte-1apcyhl) {flex:1;display:inline-flex;align-items:center;justify-content:center;gap:calc(6px * var(--mdt-scale));padding:calc(10px * var(--mdt-scale));border:none;border-radius:0;border-bottom:2px solid transparent;margin-bottom:-1px;background:transparent;color:var(--mdt-text-muted);font-size:calc(10px * var(--mdt-scale));letter-spacing:0.06em;text-transform:uppercase;cursor:pointer;transition:color 0.18s ease,
      border-color 0.18s ease;}.mobile-toggle.svelte-1apcyhl button.mactive:where(.svelte-1apcyhl) {color:var(--mdt-accent);background:transparent;border-bottom-color:var(--mdt-accent);}
  @media (min-width: 1000px) {.mobile-toggle.svelte-1apcyhl {display:none;}
  }.sops-grid.svelte-1apcyhl {display:grid;grid-template-columns:1fr;grid-template-rows:auto 1fr;gap:calc(10px * var(--mdt-scale));min-height:0;flex:1;}
  @media (min-width: 1000px) {.sops-grid.svelte-1apcyhl {grid-template-columns:minmax(240px, 300px) minmax(0, 1fr);grid-template-rows:1fr;gap:0;-moz-column-gap:calc(20px * var(--mdt-scale));column-gap:calc(20px * var(--mdt-scale));}
  }

  @media (max-width: 999px) {.sops-grid.svelte-1apcyhl:not(.show-doc) .reader-panel:where(.svelte-1apcyhl) {display:none;}.sops-grid.show-doc.svelte-1apcyhl .docs-sidebar:where(.svelte-1apcyhl) {display:none;}.sops-grid.show-doc.svelte-1apcyhl .reader-panel:where(.svelte-1apcyhl) {display:flex;min-height:min(calc(70vh * var(--mdt-scale)), calc(520px * var(--mdt-scale)));}
  }.docs-sidebar.svelte-1apcyhl {display:flex;flex-direction:column;min-height:0;min-width:0;}
  @media (min-width: 1000px) {.docs-sidebar.svelte-1apcyhl {max-height:calc(100vh - 220px * var(--mdt-scale));padding-right:calc(4px * var(--mdt-scale));border-right:1px solid var(--mdt-border);}
  }.sidebar-toolbar.svelte-1apcyhl {display:flex;align-items:baseline;justify-content:space-between;gap:calc(10px * var(--mdt-scale));padding-bottom:calc(10px * var(--mdt-scale));border-bottom:1px solid var(--mdt-border);flex-shrink:0;}.sidebar-head.svelte-1apcyhl {display:flex;align-items:center;gap:calc(8px * var(--mdt-scale));font-size:calc(10px * var(--mdt-scale));letter-spacing:0.1em;text-transform:uppercase;color:var(--mdt-text-muted);}.sidebar-meta.svelte-1apcyhl {font-size:calc(10px * var(--mdt-scale));color:var(--mdt-text-muted);font-variant-numeric:tabular-nums;}.sidebar-actions.svelte-1apcyhl {display:flex;flex-wrap:wrap;align-items:center;gap:calc(10px * var(--mdt-scale));padding:calc(8px * var(--mdt-scale)) 0;border-bottom:1px solid var(--mdt-border);flex-shrink:0;}.sidebar-action.svelte-1apcyhl {display:inline-flex;align-items:center;gap:calc(5px * var(--mdt-scale));padding:0;border:none;background:none;font-size:calc(9px * var(--mdt-scale));letter-spacing:0.06em;text-transform:uppercase;color:var(--mdt-text-muted);cursor:pointer;}.sidebar-action.svelte-1apcyhl:hover {color:var(--mdt-accent);}.sidebar-action-sep.svelte-1apcyhl {width:1px;height:calc(12px * var(--mdt-scale));background:var(--mdt-border);}.docs-nav.svelte-1apcyhl {flex:1;min-height:0;overflow-x:hidden;overflow-y:auto;padding-top:calc(4px * var(--mdt-scale));scrollbar-width:thin;}.chapter-group.svelte-1apcyhl {border-bottom:1px solid var(--mdt-border);}.chapter-group.dim.svelte-1apcyhl .chapter-toggle:where(.svelte-1apcyhl):not(:disabled) {color:var(--mdt-text-muted);}.chapter-toggle.svelte-1apcyhl {display:flex;align-items:center;gap:calc(8px * var(--mdt-scale));width:100%;padding:calc(10px * var(--mdt-scale)) calc(2px * var(--mdt-scale)) calc(10px * var(--mdt-scale)) 0;border:none;background:transparent;color:var(--mdt-text);font-size:calc(10px * var(--mdt-scale));letter-spacing:0.05em;text-transform:uppercase;text-align:left;cursor:pointer;}.chapter-toggle.svelte-1apcyhl:disabled {cursor:default;opacity:0.5;}.chapter-toggle.svelte-1apcyhl:not(:disabled):hover {color:var(--mdt-accent);}.chapter-chev-wrap.svelte-1apcyhl {display:inline-flex;flex-shrink:0;transition:transform 0.2s ease;color:var(--mdt-text-muted);}.chapter-chev-wrap.open.svelte-1apcyhl {transform:rotate(90deg);color:var(--mdt-accent);}.chapter-ico {flex-shrink:0;opacity:0.85;}.chapter-title.svelte-1apcyhl {flex:1;min-width:0;font-weight:600;}.chapter-badge.svelte-1apcyhl {font-size:calc(9px * var(--mdt-scale));font-variant-numeric:tabular-nums;color:var(--mdt-text-muted);}.sop-list.svelte-1apcyhl {list-style:none;margin:0;padding:0 0 calc(8px * var(--mdt-scale)) calc(16px * var(--mdt-scale));border-left:1px solid var(--mdt-border);margin-left:calc(9px * var(--mdt-scale));}.sop-link.svelte-1apcyhl {display:flex;flex-direction:column;align-items:flex-start;gap:calc(2px * var(--mdt-scale));width:100%;padding:calc(7px * var(--mdt-scale)) calc(8px * var(--mdt-scale));margin-bottom:calc(1px * var(--mdt-scale));border:none;border-left:2px solid transparent;margin-left:calc(-1px * var(--mdt-scale));padding-left:calc(10px * var(--mdt-scale));background:transparent;text-align:left;cursor:pointer;color:var(--mdt-text-dim);transition:color 0.15s ease,
      border-color 0.15s ease;}.sop-link.svelte-1apcyhl:hover {color:var(--mdt-text);}.sop-link.selected.svelte-1apcyhl {color:var(--mdt-text);border-left-color:var(--mdt-accent);}.sop-ref.svelte-1apcyhl {font-size:calc(9px * var(--mdt-scale));color:var(--mdt-accent);letter-spacing:0.04em;}.sop-name.svelte-1apcyhl {font-family:inherit;font-size:calc(11px * var(--mdt-scale));font-weight:500;line-height:1.35;}.empty-state.svelte-1apcyhl {display:flex;flex-direction:column;align-items:center;justify-content:center;gap:calc(12px * var(--mdt-scale));padding:calc(36px * var(--mdt-scale)) calc(16px * var(--mdt-scale));color:var(--mdt-text-muted);text-align:center;}.empty-copy.svelte-1apcyhl {display:flex;flex-direction:column;gap:calc(4px * var(--mdt-scale));}.empty-title.svelte-1apcyhl {font-size:calc(13px * var(--mdt-scale));font-weight:600;color:var(--mdt-text-dim);}.empty-hint.svelte-1apcyhl {font-size:calc(10px * var(--mdt-scale));color:var(--mdt-text-muted);}.reader-panel.svelte-1apcyhl {display:flex;flex-direction:column;min-height:0;min-width:0;}
  @media (min-width: 1000px) {.reader-panel.svelte-1apcyhl {max-height:calc(100vh - 220px * var(--mdt-scale));}
  }.reader-body.svelte-1apcyhl {flex:1;min-height:0;display:flex;flex-direction:column;min-width:0;}.reader-tape.svelte-1apcyhl {display:flex;flex-wrap:wrap;align-items:center;gap:calc(6px * var(--mdt-scale));padding:calc(8px * var(--mdt-scale)) 0;font-size:calc(10px * var(--mdt-scale));letter-spacing:0.08em;text-transform:uppercase;color:var(--mdt-text-muted);background:transparent;border-bottom:1px solid var(--mdt-border);flex-shrink:0;}.tape-ref.svelte-1apcyhl {color:var(--mdt-accent);font-weight:600;}.tape-sep.svelte-1apcyhl {opacity:0.25;}.tape-date.svelte-1apcyhl {display:inline-flex;align-items:center;gap:calc(5px * var(--mdt-scale));}.reader-header.svelte-1apcyhl {padding:calc(14px * var(--mdt-scale)) 0 0;flex-shrink:0;}.reader-badges.svelte-1apcyhl {display:flex;flex-wrap:wrap;align-items:center;gap:0;margin-bottom:calc(10px * var(--mdt-scale));}.badge-pill.svelte-1apcyhl {display:inline-flex;align-items:center;gap:calc(5px * var(--mdt-scale));padding:0 calc(10px * var(--mdt-scale)) 0 0;margin-right:calc(10px * var(--mdt-scale));border-right:1px solid var(--mdt-border);font-size:calc(9px * var(--mdt-scale));letter-spacing:0.06em;text-transform:uppercase;color:var(--mdt-text-muted);background:transparent;border-top:none;border-bottom:none;border-left:none;border-radius:0;}.badge-pill.svelte-1apcyhl:last-child {border-right:none;margin-right:0;padding-right:0;}.badge-pill.live.svelte-1apcyhl {color:var(--mdt-success);}.reader-title.svelte-1apcyhl {font-size:calc(17px * var(--mdt-scale));font-weight:700;letter-spacing:-0.02em;color:var(--mdt-text);margin:0;line-height:1.2;text-wrap:balance;}.reader-divider.svelte-1apcyhl {height:1px;margin:calc(12px * var(--mdt-scale)) 0 0;background:var(--mdt-border);flex-shrink:0;}.reader-prose.svelte-1apcyhl {flex:1;min-height:0;overflow-y:auto;padding:calc(14px * var(--mdt-scale)) 0 calc(16px * var(--mdt-scale));font-size:calc(12px * var(--mdt-scale));line-height:1.65;color:var(--mdt-text-dim);max-width:72ch;}.reader-prose.svelte-1apcyhl strong {color:var(--mdt-text);font-weight:600;}.reader-prose.svelte-1apcyhl em {color:var(--mdt-accent);font-style:italic;}.reader-prose.svelte-1apcyhl .sop-li,
  .reader-prose.svelte-1apcyhl .sop-li-bullet {display:block;padding-left:calc(14px * var(--mdt-scale));margin:calc(4px * var(--mdt-scale)) 0;border-left:2px solid var(--mdt-border-2);padding-top:calc(2px * var(--mdt-scale));padding-bottom:calc(2px * var(--mdt-scale));}.reader-footer.svelte-1apcyhl {padding:calc(10px * var(--mdt-scale)) 0 0;font-size:calc(9px * var(--mdt-scale));line-height:1.45;color:var(--mdt-text-muted);border-top:1px solid var(--mdt-border);background:transparent;flex-shrink:0;}.reader-placeholder.svelte-1apcyhl {flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:calc(10px * var(--mdt-scale));padding:calc(40px * var(--mdt-scale)) 0;color:var(--mdt-text-muted);border:none;border-radius:0;border-top:1px dashed var(--mdt-border);background:transparent;}.ph-title.svelte-1apcyhl {font-size:calc(14px * var(--mdt-scale));font-weight:600;color:var(--mdt-text-dim);margin:0;}.ph-hint.svelte-1apcyhl {margin:0;font-size:calc(10px * var(--mdt-scale));}

  @keyframes svelte-1apcyhl-sopsFade {
    from {
      opacity: 0;
      transform: translateY(calc(4px * var(--mdt-scale)));
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }`};function jt(C,ne){var be;it(ne,!0),lt(C,Bt);const A=[{id:"use-of-force",label:"Use of Force",icon:ht},{id:"pursuit-policy",label:"Pursuit Policy",icon:ut},{id:"evidence",label:"Evidence Handling",icon:ft},{id:"arrest",label:"Arrest Procedures",icon:gt},{id:"traffic",label:"Traffic Stops",icon:yt},{id:"chain-of-command",label:"Chain of Command",icon:xt}],k=[{id:"uof-1",category:"use-of-force",title:"Force Continuum",version:"3.2",lastUpdated:"2026-03-01",status:"active",content:`**PURPOSE:** Establish guidelines for the escalation and de-escalation of force by all sworn personnel.

**LEVELS OF FORCE (Ascending Order):**
1. **Officer Presence** — Uniformed officer on scene; no force applied.
2. **Verbal Commands** — Clear, calm, direct instructions. "Stop!", "Show your hands!"
3. **Soft Hands / Control Techniques** — Joint locks, escort holds, pressure points.
4. **Hard Hands / Physical Force** — Punches, kicks, takedowns when actively resisted.
5. **Less-Lethal Weapons** — Taser, pepper spray, bean-bag rounds. Document deployment immediately.
6. **Lethal Force** — Authorized ONLY when there is an imminent threat of death or serious bodily harm to the officer or a third party.

**REPORTING:** Any use of force at Level 3 or above requires a Use of Force report filed within the shift. Supervisors must review within 24 hours.`},{id:"uof-2",category:"use-of-force",title:"De-escalation Requirements",version:"2.1",lastUpdated:"2026-02-15",status:"active",content:`**PURPOSE:** Officers shall attempt de-escalation before resorting to force when safe and feasible.

**REQUIREMENTS:**
- Maintain distance and cover when possible.
- Use time as a tactical advantage — there is no rush if no life is in immediate danger.
- Communicate calmly and clearly; repeat instructions.
- Request backup before initiating confrontation with armed/erratic subjects.
- Consider the subject's mental state, language barriers, or medical conditions.

**EXCEPTIONS:** De-escalation is not required when immediate action is necessary to prevent death or serious injury.`},{id:"pp-1",category:"pursuit-policy",title:"Vehicle Pursuit Authorization",version:"4.0",lastUpdated:"2026-03-10",status:"active",content:`**AUTHORIZATION:** Vehicle pursuits are permitted ONLY for violent felonies or when the suspect poses an immediate public safety threat.

**PURSUIT INITIATION:**
1. Notify dispatch immediately with suspect description, vehicle, direction, and reason.
2. Supervisor must authorize continuation within 60 seconds or the pursuit is terminated.
3. Maximum of 3 units in pursuit; all others stage at intersections.

**TERMINATION CRITERIA:**
- Supervisor orders termination.
- Conditions become unsafe (heavy traffic, school zones, residential areas).
- Suspect identity is known and can be apprehended later.
- Officer loses visual contact for more than 15 seconds.

**PIT MANEUVER:** Authorized only by a supervisor at speeds below 40 mph on clear roadways.`},{id:"pp-2",category:"pursuit-policy",title:"Pursuit Reporting",version:"2.0",lastUpdated:"2026-01-20",status:"active",content:`**DOCUMENTATION:** All pursuits require a detailed Pursuit Report filed within 2 hours of termination.

**REQUIRED ELEMENTS:**
- Reason for initiating pursuit.
- Duration, top speed, route taken.
- Number of units involved.
- Outcome (apprehension, termination, crash).
- Any property damage or injuries.
- Body camera footage reference.

**REVIEW:** Pursuit Review Board convenes within 72 hours for any pursuit exceeding 5 minutes or resulting in damage/injury.`},{id:"ev-1",category:"evidence",title:"Evidence Collection & Chain of Custody",version:"3.5",lastUpdated:"2026-02-28",status:"active",content:`**CHAIN OF CUSTODY:** Every piece of evidence must have an unbroken chain of custody from collection to court presentation.

**COLLECTION PROCEDURES:**
1. Photograph evidence in situ before touching.
2. Wear gloves at all times when handling physical evidence.
3. Use designated evidence bags/containers. Label with: case number, date, time, location, collecting officer.
4. For digital evidence: capture screenshots, note timestamps, preserve originals.
5. For biological evidence: use separate containers, keep refrigerated.

**STORAGE:** All evidence is logged into the Evidence Management System (EMS) within 1 hour of collection. Physical items go to the evidence locker; access requires supervisor authorization.`},{id:"ev-2",category:"evidence",title:"Digital Evidence & CCTV Retrieval",version:"1.8",lastUpdated:"2026-03-05",status:"active",content:`**DIGITAL EVIDENCE:**
- All body camera footage is automatically uploaded; officers must tag relevant segments.
- CCTV footage requests must include: case number, locations, time range (±15 min recommended).
- Screenshots and exports must be saved as original format; no editing.

**RETENTION:**
- Routine: 90 days unless attached to a case.
- Active cases: retained for duration of case + 1 year.
- Felony cases: retained for 7 years minimum.

**DELETION:** Only authorized by Records Division supervisor. Requires written documentation.`},{id:"ar-1",category:"arrest",title:"Arrest Procedures & Miranda Rights",version:"5.0",lastUpdated:"2026-03-12",status:"active",content:`**ARREST AUTHORITY:** Officers may arrest when:
- A warrant exists for the individual.
- A crime is committed in the officer's presence.
- Probable cause exists that a felony has been committed.

**MIRANDA WARNING:** Must be given BEFORE custodial interrogation. Failure invalidates statements.

_"You have the right to remain silent. Anything you say can and will be used against you in a court of law. You have the right to an attorney. If you cannot afford an attorney, one will be provided for you."_

**BOOKING PROCEDURES:**
1. Search incident to arrest (pat-down + property inventory).
2. Transport to station in a secure vehicle.
3. Process through booking (prints, photos, charges, property log).
4. Notify dispatch of booking with charges.`},{id:"ar-2",category:"arrest",title:"Juvenile & Vulnerable Person Procedures",version:"2.3",lastUpdated:"2026-02-01",status:"active",content:`**JUVENILES (Under 18):**
- Contact parent/guardian immediately upon detention.
- Do not interrogate without parent/guardian or attorney present.
- Transport separately from adult detainees.
- File juvenile incident report (separate from adult system).

**VULNERABLE PERSONS:**
- Individuals with mental health crises: request Crisis Intervention Team (CIT) officer if available.
- Individuals with disabilities: provide reasonable accommodations.
- Elderly individuals: assess medical needs before transport.
- Non-English speakers: request interpreter; do not rely on bystanders.`},{id:"ts-1",category:"traffic",title:"Traffic Stop Procedures",version:"3.1",lastUpdated:"2026-03-08",status:"active",content:`**INITIATION:**
1. Activate emergency lights (and siren if needed).
2. Notify dispatch: location, vehicle description, plate number, number of occupants.
3. Select a safe location — well-lit, away from intersections, shoulder of road when possible.

**APPROACH:**
- Driver side or passenger side approach depending on traffic conditions.
- Maintain awareness of all occupants.
- Request license, registration, and insurance.
- Body camera must be active for the entire stop.

**CITATIONS:**
- Explain the violation clearly.
- Offer verbal/written warning when appropriate for minor infractions.
- Issue citation through the MDT system with correct charge codes.
- Inform the driver of their court date or online payment options.`},{id:"ts-2",category:"traffic",title:"DUI / Impaired Driving Protocol",version:"2.5",lastUpdated:"2026-02-20",status:"active",content:`**INDICATORS:**
- Swerving, inconsistent speed, failure to maintain lane.
- Odor of alcohol/marijuana, slurred speech, bloodshot eyes.
- Difficulty producing documents.

**FIELD SOBRIETY TESTS (FSTs):**
1. Horizontal Gaze Nystagmus (HGN).
2. Walk and Turn.
3. One-Leg Stand.

**BREATHALYZER:** Administer roadside PBT if FSTs indicate impairment. PBT results are probable cause only — not admissible in court.

**ARREST & BOOKING:** At station, administer Evidential Breath Test (EBT) or request blood draw. Document BAC, all observations, and FST performance in the DUI report.`},{id:"cc-1",category:"chain-of-command",title:"Rank Structure & Authority",version:"1.5",lastUpdated:"2026-01-15",status:"active",content:`**RANK HIERARCHY (Ascending):**
1. **Cadet / Recruit** — In training; no independent authority.
2. **Officer** — Patrol and response duties; full arrest authority.
3. **Corporal (CPL)** — Senior officer; may lead a patrol team.
4. **Sergeant (SGT)** — First-line supervisor; approves reports, authorizes pursuits.
5. **Lieutenant (LT)** — Division commander; manages units and personnel.
6. **Captain (CPT)** — Bureau commander; strategic oversight.
7. **Deputy Chief** — Heads a major division (Operations, Investigations, Admin).
8. **Chief of Police** — Final authority on department policy and operations.

**ACTING RANKS:** When a supervisor is unavailable, the next senior officer assumes acting authority and must log this in the MDT.`},{id:"cc-2",category:"chain-of-command",title:"Internal Complaints & IA Procedures",version:"2.0",lastUpdated:"2026-02-10",status:"active",content:`**FILING A COMPLAINT:**
- Any citizen or officer may file a formal complaint.
- Complaints are submitted in writing to Internal Affairs (IA) or the Watch Commander.
- Anonymous complaints are accepted but carry lower investigative priority.

**INVESTIGATION PROCESS:**
1. IA assigns a case number and investigating officer (not involved with the incident).
2. Interviews conducted within 10 business days.
3. Evidence reviewed: body camera, CAD records, witness statements.
4. Finding categories: Sustained, Not Sustained, Exonerated, Unfounded.

**DISCIPLINE:** Progressive discipline applies — counseling → written reprimand → suspension → termination. Severity depends on the nature of the violation.`}];let ie=j(!1),N=j(""),h=j(we(new Set(A[0]?[A[0].id]:[]))),y=j(we(((be=k[0])==null?void 0:be.id)??null)),x=j("index"),u=v(()=>!!e(N).trim()),P=v(()=>{let t=k;if(e(N).trim()){const a=e(N).trim().toLowerCase();t=t.filter(n=>n.title.toLowerCase().includes(a)||n.content.toLowerCase().includes(a)||n.category.toLowerCase().includes(a)||se(n).toLowerCase().includes(a))}return t}),Se=v(()=>{const t={};for(const a of A)t[a.id]=k.filter(n=>n.category===a.id).length;return t}),f=v(()=>e(y)?k.find(t=>t.id===e(y))??null:null);ot(()=>{const t=e(P);if(!t.length){o(y,null);return}if((!e(y)||!t.some(a=>a.id===e(y)))&&(o(y,t[0].id,!0),!e(u))){const a=new Set(e(h));a.add(t[0].category),o(h,a,!0)}}),ct(()=>{o(ie,!0)});function Ee(t){return A.find(a=>a.id===t)}function Te(t){if(o(y,t,!0),o(x,"document"),!e(u)){const a=k.find(n=>n.id===t);if(a){const n=new Set(e(h));n.add(a.category),o(h,n,!0)}}}function Ae(t,a){return e(u)?a>0:e(h).has(t)}function Re(t){if(e(u))return;const a=new Set(e(h));a.has(t)?a.delete(t):a.add(t),o(h,a,!0)}function Oe(){o(h,new Set(A.map(t=>t.id)),!0)}function ze(){o(h,new Set,!0)}function Ne(t){return e(P).filter(a=>a.category===t)}var $=Wt();let le;var oe=r($),Pe=s(r(oe),2),ce=r(Pe),Ue=r(ce),Le=r(Ue),De=s(ce,2),de=s(r(De),2);bt(de,{size:14,strokeWidth:2,class:"search-ico","aria-hidden":"true"});var Fe=s(de,2),pe=s(oe,2),U=r(pe);let ve;var Me=r(U);wt(Me,{size:14,strokeWidth:2});var G=s(U,2);let me;var We=r(G);_t(We,{size:14,strokeWidth:2});var he=s(pe,2);let ue;var fe=r(he),ge=r(fe),ye=r(ge),Be=r(ye);Ct(Be,{size:14,strokeWidth:2});var He=s(ye,2),qe=r(He);{var je=t=>{var a=re();T(()=>d(a,`${e(P).length??""} match${e(P).length===1?"":"es"}`)),l(t,a)},Ge=t=>{var a=re();T(()=>d(a,`${k.length??""} directives`)),l(t,a)};E(qe,t=>{e(u)?t(je):t(Ge,-1)})}var xe=s(ge,2);{var Ve=t=>{var a=Ot(),n=r(a),b=r(n);kt(b,{size:12,strokeWidth:2,"aria-hidden":"true"});var c=s(n,4),L=r(c);It(L,{size:12,strokeWidth:2,"aria-hidden":"true"}),z("click",n,Oe),z("click",c,ze),l(t,a)};E(xe,t=>{e(u)||t(Ve)})}var Ye=s(xe,2),Ke=r(Ye);{var $e=t=>{var a=zt(),n=r(a);Ie(n,{size:28,strokeWidth:1.25}),l(t,a)},Je=t=>{var a=vt(),n=_e(a);Ce(n,17,()=>A,b=>b.id,(b,c)=>{const L=v(()=>e(c).icon),I=v(()=>Ne(e(c).id)),D=v(()=>Ae(e(c).id,e(I).length)),F=v(()=>e(Se)[e(c).id]??0);var R=Ut();let V;var w=r(R),O=r(w);let M;var J=r(O);St(J,{size:14,strokeWidth:2,"aria-hidden":"true"});var W=s(O,2);ke(W,()=>e(L),(S,i)=>{i(S,{size:13,strokeWidth:2,class:"chapter-ico","aria-hidden":"true"})});var B=s(W,2),Q=r(B),Z=s(B,2),X=r(Z),ee=s(w,2);{var te=S=>{var i=Pt();Ce(i,21,()=>e(I),p=>p.id,(p,g)=>{var H=Nt(),q=r(H);let Y;var K=r(q),tt=r(K),at=s(K,2),rt=r(at);T(st=>{Y=_(q,1,"sop-link font-mono svelte-1apcyhl",null,Y,{selected:e(y)===e(g).id}),d(tt,st),d(rt,e(g).title)},[()=>se(e(g))]),z("click",q,()=>Te(e(g).id)),l(p,H)}),l(S,i)};E(ee,S=>{e(D)&&e(I).length>0&&S(te)})}T(()=>{V=_(R,1,"chapter-group svelte-1apcyhl",null,V,{dim:!e(u)&&e(F)===0}),ae(w,"aria-expanded",e(D)),w.disabled=!e(u)&&e(F)===0,M=_(O,1,"chapter-chev-wrap svelte-1apcyhl",null,M,{open:e(D)}),d(Q,e(c).label),d(X,e(u)?e(I).length:e(F))}),z("click",w,()=>Re(e(c).id)),l(b,R)}),l(t,a)};E(Ke,t=>{e(P).length===0?t($e):t(Je,-1)})}var Qe=s(fe,2),Ze=r(Qe);{var Xe=t=>{const a=v(()=>Ee(e(f).category));var n=Ft(),b=r(n),c=r(b),L=r(c),I=s(c,4),D=r(I),F=s(I,4),R=r(F);Et(R,{size:11,strokeWidth:2});var V=s(R),w=s(b,2),O=r(w),M=r(O);{var J=i=>{const p=v(()=>e(a).icon);var g=Lt(),H=r(g);ke(H,()=>e(p),(Y,K)=>{K(Y,{size:12,strokeWidth:2})});var q=s(H);T(()=>d(q,` ${e(a).label??""}`)),l(i,g)};E(M,i=>{e(a)&&i(J)})}var W=s(M,2);let B;var Q=r(W);{var Z=i=>{var p=Dt(),g=_e(p);Tt(g,{size:12,strokeWidth:2}),l(i,p)},X=i=>{var p=re("Draft");l(i,p)};E(Q,i=>{e(f).status==="active"?i(Z):i(X,-1)})}var ee=s(O,2),te=r(ee),S=s(w,4);mt(S,()=>Rt(e(f).content),!0),T(i=>{d(L,i),d(D,`Rev. ${e(f).version??""}`),d(V,` ${e(f).lastUpdated??""}`),B=_(W,1,"badge-pill font-mono svelte-1apcyhl",null,B,{live:e(f).status==="active"}),d(te,e(f).title)},[()=>se(e(f))]),l(t,n)},et=t=>{var a=Mt(),n=r(a);Ie(n,{size:36,strokeWidth:1}),l(t,a)};E(Ze,t=>{e(f)?t(Xe):t(et,-1)})}T(()=>{le=_($,1,"sops-root svelte-1apcyhl",null,le,{mounted:e(ie)}),d(Le,k.length),ae(U,"aria-selected",e(x)==="index"),ve=_(U,1,"svelte-1apcyhl",null,ve,{mactive:e(x)==="index"}),ae(G,"aria-selected",e(x)==="document"),me=_(G,1,"svelte-1apcyhl",null,me,{mactive:e(x)==="document"}),ue=_(he,1,"sops-grid svelte-1apcyhl",null,ue,{"show-doc":e(x)==="document"})}),dt(Fe,()=>e(N),t=>o(N,t)),z("click",U,()=>o(x,"index")),z("click",G,()=>o(x,"document")),l(C,$),pt()}nt(["click"]);export{jt as S};
