<script>
  import { mdtStore } from '../stores/mdt.svelte.js';

  let peekTimer = null;

  function handleMouseMove(e) {
    const threshold = 48;
    if (e.clientY <= threshold) {
      if (!mdtStore.peeking && !peekTimer) {
        peekTimer = setTimeout(() => {
          mdtStore.peeking = true;
          peekTimer = null;
        }, 120);
      }
    } else {
      if (peekTimer) {
        clearTimeout(peekTimer);
        peekTimer = null;
      }
      if (mdtStore.peeking) {
        mdtStore.peeking = false;
      }
    }
  }
</script>

<svelte:window onmousemove={handleMouseMove} />
