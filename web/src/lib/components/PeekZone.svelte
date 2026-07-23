<script>
  import { mdtStore } from '../stores/mdt.svelte.js';

  function setPeeking(nextState) {
    mdtStore.peeking = nextState;
  }
</script>

<button
  class="peek-zone"
  type="button"
  aria-label="Hover to peek past the MDT and see your surroundings"
  onmouseenter={() => setPeeking(true)}
  onmouseleave={() => setPeeking(false)}
  onfocus={() => setPeeking(true)}
  onblur={() => setPeeking(false)}
></button>

<style>
  .peek-zone {
    position: absolute;
    top: calc(26px * var(--mdt-scale));
    left: 50%;
    transform: translateX(-50%);
    width: calc(200px * var(--mdt-scale));
    height: calc(18px * var(--mdt-scale));
    border: none;
    border-radius: 999px;
    background: transparent;
    box-shadow: none;
    cursor: pointer;
    opacity: 0.78;
    transition: opacity 0.18s ease, transform 0.18s ease;
    z-index: 30;
  }

  .peek-zone::after {
    content: '';
    position: absolute;
    inset: calc(6px * var(--mdt-scale)) calc(28px * var(--mdt-scale));
    border-radius: 999px;
    background: rgba(228, 232, 239, 0.22);
    transition: background 0.18s ease;
  }

  .peek-zone:hover,
  .peek-zone:focus-visible {
    opacity: 1;
    transform: translateX(-50%) scale(1.02);
  }

  .peek-zone:hover::after,
  .peek-zone:focus-visible::after {
    background: rgba(228, 232, 239, 0.34);
  }
</style>
