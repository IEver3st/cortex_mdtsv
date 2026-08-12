<script>
  let { transparentContent = false, children } = $props();
</script>

<div class="bezel-frame">
  <div class="bezel-inner" class:transparent-content={transparentContent}>
    {@render children?.()}
  </div>
</div>

<style>
  .bezel-frame {
    position: absolute;
    inset: calc(24px * var(--mdt-scale));
    border-radius: calc(14px * var(--mdt-scale));
    padding: var(--mdt-bezel-width);
    background: var(--mdt-bezel);
    box-shadow: var(--mdt-bezel-shadow);
    overflow: hidden;
    display: flex;
  }

  .bezel-frame::before {
    content: '';
    position: absolute;
    inset: 0;
    border-radius: inherit;
    border: 1px solid var(--mdt-bezel-edge);
    pointer-events: none;
  }

  /* Specular highlight along top edge — aluminum reflection */
  .bezel-frame::after {
    content: '';
    position: absolute;
    top: 0;
    left: 10%;
    right: 10%;
    height: 1px;
    background: linear-gradient(
      90deg,
      transparent 0%,
      rgba(255, 255, 255, 0.30) 30%,
      rgba(255, 255, 255, 0.45) 50%,
      rgba(255, 255, 255, 0.30) 70%,
      transparent 100%
    );
    pointer-events: none;
  }

  .bezel-inner {
    flex: 1;
    border-radius: calc(11px * var(--mdt-scale));
    background: var(--mdt-bg);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    position: relative;
  }

  .bezel-inner.transparent-content {
    background: transparent;
  }
</style>
