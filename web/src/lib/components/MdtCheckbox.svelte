<script>
  /**
   * Square checkbox: bind:checked, or controlled via checkedValue + onCheckedChange.
   */
  let {
    checked = $bindable(false),
    checkedValue = undefined,
    onCheckedChange = undefined,
    disabled = false,
    children,
    class: className = '',
  } = $props();
</script>

<label class="mdt-checkbox {className}">
  {#if checkedValue !== undefined}
    <input
      type="checkbox"
      class="mdt-checkbox-input"
      checked={checkedValue}
      {disabled}
      onchange={(e) => onCheckedChange?.(e.currentTarget.checked)}
    />
  {:else}
    <input type="checkbox" class="mdt-checkbox-input" bind:checked {disabled} />
  {/if}
  <span class="mdt-checkbox-box" aria-hidden="true">
    <svg class="mdt-checkbox-tick" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
      <path d="M5 13l4 4L19 7" />
    </svg>
  </span>
  {#if children}
    <span class="mdt-checkbox-label">{@render children()}</span>
  {/if}
</label>
