<script>
  import { tick } from 'svelte';
  import { Check, FileWarning, Link, Plus, Send, ShieldAlert, Trash2, X } from '@lucide/svelte';
  import { isEnvBrowser, nuiPost } from '../utils/nui.js';

  let { show = false, defaults = {}, onClose = () => {} } = $props();

  const CATEGORIES = [
    ['misconduct', 'Misconduct'],
    ['excessive-force', 'Excessive force'],
    ['corruption', 'Corruption'],
    ['negligence', 'Negligence'],
    ['discrimination', 'Discrimination'],
    ['other', 'Other'],
  ];

  const DEPARTMENTS = [
    ['police', 'Los Santos Police Department'],
    ['sheriff', 'Blaine County Sheriff Office'],
    ['highway', 'San Andreas Highway Patrol'],
  ];

  let dialogEl = $state(null);
  let firstInput = $state(null);
  let wasOpen = $state(false);
  let reporterName = $state('');
  let reporterContact = $state('');
  let subjectName = $state('');
  let subjectId = $state('');
  let department = $state('police');
  let category = $state('misconduct');
  let incidentAt = $state('');
  let location = $state('');
  let summary = $state('');
  let content = $state('');
  let witnesses = $state('');
  let evidenceDraft = $state('');
  let evidence = $state([]);
  let submitting = $state(false);
  let submittedId = $state('');
  let errorMessage = $state('');

  const today = new Date().toISOString().slice(0, 10);
  let canSubmit = $derived(reporterName.trim().length > 0 && content.trim().length >= 20 && !submitting);

  function resetForm() {
    reporterName = String(defaults?.reporterName || '').slice(0, 120);
    reporterContact = '';
    subjectName = '';
    subjectId = '';
    department = 'police';
    category = 'misconduct';
    incidentAt = '';
    location = '';
    summary = '';
    content = '';
    witnesses = '';
    evidenceDraft = '';
    evidence = [];
    submitting = false;
    submittedId = '';
    errorMessage = '';
  }

  $effect(() => {
    if (show && !wasOpen) {
      resetForm();
      void tick().then(() => firstInput?.focus());
    }
    wasOpen = show;
  });

  function addEvidence() {
    const value = evidenceDraft.trim();
    if (!/^https?:\/\//i.test(value)) {
      errorMessage = 'Evidence links must start with http:// or https://.';
      return;
    }
    if (value.length > 512 || evidence.includes(value) || evidence.length >= 8) return;
    evidence = [...evidence, value];
    evidenceDraft = '';
    errorMessage = '';
  }

  function removeEvidence(value) {
    evidence = evidence.filter((entry) => entry !== value);
  }

  async function close() {
    if (submitting) return;
    await nuiPost('cortex_mdt:closeComplaint');
    onClose();
  }

  async function submit(event) {
    event.preventDefault();
    if (!canSubmit) return;
    submitting = true;
    errorMessage = '';

    const payload = {
      reporterName: reporterName.trim(),
      reporterContact: reporterContact.trim(),
      subjectName: subjectName.trim(),
      subjectId: subjectId.trim(),
      department,
      category,
      incidentAt,
      location: location.trim(),
      summary: summary.trim(),
      content: content.trim(),
      witnesses: witnesses.trim(),
      evidence,
    };
    const response = isEnvBrowser()
      ? { ok: true, complaintId: 'ia:preview' }
      : await nuiPost('cortex_mdt:submitPublicComplaint', payload);

    if (response?.ok) {
      submittedId = String(response.complaintId || 'Filed');
    } else {
      errorMessage = response?.error || 'The complaint could not be filed. Please try again.';
    }
    submitting = false;
  }

  function handleWindowKeydown(event) {
    if (!show) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      void close();
      return;
    }
    if (event.key !== 'Tab' || !dialogEl) return;
    const focusable = [...dialogEl.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [href], [tabindex]:not([tabindex="-1"])')];
    if (!focusable.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }
</script>

<svelte:window onkeydown={handleWindowKeydown} />

{#if show}
  <div class="complaint-backdrop" role="presentation" onclick={(event) => { if (event.target === event.currentTarget) void close(); }}>
    <div class="complaint-dialog" role="dialog" aria-modal="true" aria-labelledby="complaint-title" aria-describedby="complaint-description" tabindex="-1" bind:this={dialogEl}>
      <header>
        <div class="dialog-heading">
          <span class="heading-mark"><ShieldAlert size={18} /></span>
          <div>
            <span class="eyebrow font-mono">PUBLIC INTAKE / INTERNAL AFFAIRS</span>
            <h2 id="complaint-title">File a personnel complaint</h2>
          </div>
        </div>
        <button type="button" class="icon-button" onclick={close} aria-label="Close complaint form"><X size={16} /></button>
      </header>

      {#if submittedId}
        <section class="success-state" aria-live="polite">
          <span class="success-mark"><Check size={24} /></span>
          <span class="eyebrow font-mono">SUBMISSION RECORDED</span>
          <h3>Your complaint has been filed.</h3>
          <p>Internal Affairs can review the record without exposing it to the general officer portal.</p>
          <div class="reference-block"><span>Reference</span><strong class="font-mono">{submittedId}</strong></div>
          <button type="button" class="primary-button" onclick={close}>Done</button>
        </section>
      {:else}
        <p id="complaint-description" class="privacy-note">This form is available without officer access. Submissions are stored as management-only Internal Affairs records.</p>

        {#if errorMessage}
          <div class="error-banner" role="alert"><FileWarning size={15} /><span>{errorMessage}</span></div>
        {/if}

        <form onsubmit={submit}>
          <div class="form-grid">
            <label>
              <span>Your name *</span>
              <input bind:this={firstInput} bind:value={reporterName} maxlength="120" autocomplete="name" required />
            </label>
            <label>
              <span>Contact information</span>
              <input bind:value={reporterContact} maxlength="160" autocomplete="email" placeholder="Phone, email, or preferred contact" />
            </label>
            <label>
              <span>Officer or employee</span>
              <input bind:value={subjectName} maxlength="160" placeholder="Name or unit, if known" />
            </label>
            <label>
              <span>Badge / personnel ID</span>
              <input bind:value={subjectId} maxlength="96" placeholder="Optional" />
            </label>
            <label>
              <span>Department</span>
              <select bind:value={department}>{#each DEPARTMENTS as [value, label]}<option {value}>{label}</option>{/each}</select>
            </label>
            <label>
              <span>Category</span>
              <select bind:value={category}>{#each CATEGORIES as [value, label]}<option {value}>{label}</option>{/each}</select>
            </label>
            <label>
              <span>Incident date</span>
              <input bind:value={incidentAt} type="date" max={today} />
            </label>
            <label>
              <span>Location</span>
              <input bind:value={location} maxlength="180" placeholder="Street, facility, or area" />
            </label>
            <label class="wide">
              <span>Short summary</span>
              <input bind:value={summary} maxlength="1200" placeholder="One-line description of the concern" />
            </label>
            <label class="wide">
              <span>What happened? *</span>
              <textarea bind:value={content} minlength="20" maxlength="12000" rows="7" required placeholder="Describe what happened, when it happened, and who was involved."></textarea>
              <small class:warning={content.length > 0 && content.trim().length < 20}>{content.length}/12000 · minimum 20 characters</small>
            </label>
            <label class="wide">
              <span>Witnesses</span>
              <textarea bind:value={witnesses} maxlength="1600" rows="2" placeholder="Names and contact details, if available"></textarea>
            </label>
            <div class="wide evidence-field">
              <span class="field-label">Evidence links</span>
              <div class="evidence-entry">
                <span><Link size={14} /></span>
                <input bind:value={evidenceDraft} maxlength="512" inputmode="url" placeholder="https://…" onkeydown={(event) => { if (event.key === 'Enter') { event.preventDefault(); addEvidence(); } }} />
                <button type="button" class="secondary-button" onclick={addEvidence} disabled={!evidenceDraft.trim() || evidence.length >= 8}><Plus size={14} /> Add</button>
              </div>
              {#if evidence.length}
                <div class="evidence-list">
                  {#each evidence as url (url)}
                    <div><span class="font-mono">{url}</span><button type="button" onclick={() => removeEvidence(url)} aria-label={`Remove ${url}`}><Trash2 size={13} /></button></div>
                  {/each}
                </div>
              {/if}
            </div>
          </div>

          <footer>
            <span>Required fields are marked with an asterisk.</span>
            <div>
              <button type="button" class="secondary-button" onclick={close} disabled={submitting}>Cancel</button>
              <button type="submit" class="primary-button" disabled={!canSubmit}><Send size={14} />{submitting ? 'Filing…' : 'File complaint'}</button>
            </div>
          </footer>
        </form>
      {/if}
    </div>
  </div>
{/if}

<style>
  .font-mono { font-family: 'Share Tech Mono', monospace; }
  .complaint-backdrop { position: fixed; inset: 0; z-index: 12000; display: grid; place-items: center; padding: 24px; background: color-mix(in srgb, #000 68%, transparent); }
  .complaint-dialog { width: min(820px, calc(100vw - 32px)); max-height: min(900px, calc(100vh - 32px)); display: flex; flex-direction: column; overflow: hidden; border: 1px solid var(--mdt-border-2); border-radius: var(--mdt-radius); background: var(--mdt-bg); color: var(--mdt-text); box-shadow: 0 24px 70px rgba(0, 0, 0, .58); }
  .complaint-dialog > header { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 14px 16px; border-bottom: 1px solid var(--mdt-border); background: var(--mdt-chrome); }
  .dialog-heading { display: flex; align-items: center; gap: 11px; min-width: 0; }
  .heading-mark { display: grid; place-items: center; width: 36px; height: 36px; flex: 0 0 auto; border: 1px solid color-mix(in srgb, var(--mdt-accent) 35%, var(--mdt-border)); border-radius: var(--mdt-radius-sm); color: var(--mdt-accent); background: var(--mdt-accent-dim); }
  .eyebrow { color: var(--mdt-accent); font-size: 9px; letter-spacing: .1em; }
  h2 { margin: 3px 0 0; font-size: 18px; }
  button, input, select, textarea { font: inherit; }
  button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible { outline: 2px solid var(--mdt-accent); outline-offset: 2px; }
  button:disabled { opacity: .45; cursor: not-allowed; }
  .icon-button { display: grid; place-items: center; width: 34px; height: 34px; flex: 0 0 auto; border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text-muted); cursor: pointer; }
  .privacy-note { margin: 0; padding: 10px 16px; border-bottom: 1px solid var(--mdt-border); color: var(--mdt-text-muted); background: var(--mdt-surface); font-size: 11px; line-height: 1.5; }
  .error-banner { display: flex; align-items: center; gap: 8px; margin: 12px 16px 0; padding: 9px 10px; border: 1px solid color-mix(in srgb, var(--mdt-error) 42%, var(--mdt-border)); border-radius: var(--mdt-radius-sm); color: var(--mdt-error); font-size: 11px; }
  form { min-height: 0; display: flex; flex-direction: column; }
  .form-grid { min-height: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px 14px; padding: 16px; overflow-y: auto; }
  label, .evidence-field { display: flex; flex-direction: column; gap: 5px; min-width: 0; }
  label > span, .field-label { color: var(--mdt-text-muted); font-size: 9px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }
  .wide { grid-column: 1 / -1; }
  input, select, textarea { width: 100%; box-sizing: border-box; border: 1px solid var(--mdt-border); border-radius: var(--mdt-radius-sm); background: var(--mdt-surface-2); color: var(--mdt-text); }
  input, select { min-height: 36px; padding: 0 10px; }
  textarea { padding: 9px 10px; resize: vertical; line-height: 1.5; }
  input::placeholder, textarea::placeholder { color: var(--mdt-text-muted); }
  small { align-self: flex-end; color: var(--mdt-text-muted); font-size: 9px; }
  small.warning { color: var(--mdt-warning); }
  .evidence-entry { display: grid; grid-template-columns: 34px minmax(0, 1fr) auto; }
  .evidence-entry > span { display: grid; place-items: center; border: 1px solid var(--mdt-border); border-right: 0; border-radius: var(--mdt-radius-sm) 0 0 var(--mdt-radius-sm); color: var(--mdt-text-muted); background: var(--mdt-surface); }
  .evidence-entry input { border-radius: 0; }
  .evidence-entry .secondary-button { border-left: 0; border-radius: 0 var(--mdt-radius-sm) var(--mdt-radius-sm) 0; }
  .evidence-list { display: flex; flex-direction: column; border: 1px solid var(--mdt-border); border-bottom: 0; }
  .evidence-list > div { display: flex; align-items: center; gap: 8px; min-height: 32px; padding-left: 9px; border-bottom: 1px solid var(--mdt-border); color: var(--mdt-text-dim); background: var(--mdt-surface); }
  .evidence-list span { flex: 1; min-width: 0; overflow: hidden; font-size: 9px; text-overflow: ellipsis; white-space: nowrap; }
  .evidence-list button { display: grid; place-items: center; align-self: stretch; width: 34px; border: 0; border-left: 1px solid var(--mdt-border); background: transparent; color: var(--mdt-text-muted); cursor: pointer; }
  form > footer { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 16px; border-top: 1px solid var(--mdt-border); background: var(--mdt-chrome); }
  form > footer > span { color: var(--mdt-text-muted); font-size: 9px; }
  form > footer > div { display: flex; gap: 8px; }
  .primary-button, .secondary-button { min-height: 34px; display: inline-flex; align-items: center; justify-content: center; gap: 7px; padding: 0 12px; border-radius: var(--mdt-radius-sm); font-size: 10px; font-weight: 700; cursor: pointer; }
  .primary-button { border: 0; background: var(--mdt-accent); color: var(--mdt-bg); }
  .secondary-button { border: 1px solid var(--mdt-border-2); background: var(--mdt-surface-2); color: var(--mdt-text-dim); }
  .primary-button:hover:not(:disabled) { opacity: .9; }
  .secondary-button:hover:not(:disabled), .icon-button:hover { border-color: var(--mdt-accent); color: var(--mdt-text); }
  .success-state { display: flex; flex-direction: column; align-items: center; gap: 9px; padding: 42px 24px; text-align: center; }
  .success-mark { display: grid; place-items: center; width: 48px; height: 48px; margin-bottom: 5px; border: 1px solid color-mix(in srgb, var(--mdt-success) 42%, var(--mdt-border)); border-radius: var(--mdt-radius); color: var(--mdt-success); background: color-mix(in srgb, var(--mdt-success) 10%, var(--mdt-surface)); }
  .success-state h3 { margin: 0; font-size: 18px; }
  .success-state p { max-width: 52ch; margin: 0; color: var(--mdt-text-muted); font-size: 11px; line-height: 1.5; }
  .reference-block { min-width: 230px; display: flex; flex-direction: column; gap: 4px; margin: 8px 0; padding: 10px 14px; border-top: 1px solid var(--mdt-border); border-bottom: 1px solid var(--mdt-border); }
  .reference-block span { color: var(--mdt-text-muted); font-size: 9px; text-transform: uppercase; }
  .reference-block strong { color: var(--mdt-accent); font-size: 15px; }
  @media (max-width: 620px) {
    .complaint-backdrop { padding: 8px; }
    .complaint-dialog { width: calc(100vw - 16px); max-height: calc(100vh - 16px); }
    .form-grid { grid-template-columns: 1fr; }
    .wide { grid-column: 1; }
    form > footer { align-items: stretch; flex-direction: column; }
    form > footer > div { width: 100%; }
    form > footer button { flex: 1; }
  }
</style>
