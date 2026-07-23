<script>
  import { onMount } from 'svelte';

  /**
   * @typedef {'iso' | 'meridian' | 'diagonal' | 'rings' | 'weave'} TopoLayout
   * @typedef {{ d: string; opacity: number }} ContourPath
   */

  /** @type {{ layout?: TopoLayout; seed?: number }} */
  let { layout = 'iso', seed = 0x746f706f } = $props();

  /** @param {number} s */
  function mulberry32(s) {
    return function () {
      let t = (s += 0x6d2b79f5);
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /** @param {() => number} next */
  function makeTopoWobble(next) {
    const a1 = 0.65 + next() * 1.35;
    const a2 = 0.22 + next() * 0.78;
    const a3 = 0.08 + next() * 0.42;
    const p1 = next() * Math.PI * 2;
    const p2 = next() * Math.PI * 2;
    const p3 = next() * Math.PI * 2;
    return (/** @param {number} u */ u) => {
      const nx = (u / 100) * Math.PI * 2;
      return (
        a1 * Math.sin(nx * 0.95 + p1) +
        a2 * Math.sin(nx * 1.85 + p2) +
        a3 * Math.sin(nx * 3.1 + p3)
      );
    };
  }

  /** @param {() => number} next — wobble by normalized param 0..1 around loop */
  function makeRingWobble(next) {
    const a1 = 0.35 + next() * 0.95;
    const a2 = 0.12 + next() * 0.55;
    const a3 = 0.05 + next() * 0.28;
    const p1 = next() * Math.PI * 2;
    const p2 = next() * Math.PI * 2;
    const p3 = next() * Math.PI * 2;
    return (/** @param {number} t */ t) => {
      const nx = t * Math.PI * 2;
      return (
        a1 * Math.sin(nx * 2.2 + p1) + a2 * Math.sin(nx * 4.1 + p2) + a3 * Math.sin(nx * 6.3 + p3)
      );
    };
  }

  /** @param {number} baseY @param {(u: number) => number} wobble */
  function buildIsoD(baseY, wobble) {
    const steps = 96;
    let d = '';
    for (let i = 0; i <= steps; i += 1) {
      const x = (i / steps) * 100;
      let y = baseY + wobble(x);
      y = Math.min(97.5, Math.max(2.5, y));
      const xs = x.toFixed(2);
      const ys = y.toFixed(2);
      d += i === 0 ? `M ${xs} ${ys}` : ` L ${xs} ${ys}`;
    }
    return d;
  }

  /** @param {number} baseX @param {(u: number) => number} wobble */
  function buildMeridianD(baseX, wobble) {
    const steps = 96;
    let d = '';
    for (let i = 0; i <= steps; i += 1) {
      const y = (i / steps) * 100;
      let x = baseX + wobble(y);
      x = Math.min(97.5, Math.max(2.5, x));
      const xs = x.toFixed(2);
      const ys = y.toFixed(2);
      d += i === 0 ? `M ${xs} ${ys}` : ` L ${xs} ${ys}`;
    }
    return d;
  }

  /** @param {number} cx @param {number} cy @param {number} baseR @param {(t: number) => number} wobbleT */
  function buildRingD(cx, cy, baseR, wobbleT) {
    const steps = 100;
    let d = '';
    for (let i = 0; i <= steps; i += 1) {
      const t = i / steps;
      const theta = t * Math.PI * 2;
      const dr = wobbleT(t);
      const r = Math.max(2, baseR + dr);
      const x = cx + r * Math.cos(theta);
      const y = cy + r * Math.sin(theta);
      const xs = x.toFixed(2);
      const ys = y.toFixed(2);
      d += i === 0 ? `M ${xs} ${ys}` : ` L ${xs} ${ys}`;
    }
    return d;
  }

  /** @param {() => number} next @param {number} n */
  function generateIso(next, n) {
    /** @type {ContourPath[]} */
    const out = [];
    const bandLo = 10;
    const bandHi = 90;
    for (let i = 0; i < n; i += 1) {
      const t = n <= 1 ? 0.5 : i / (n - 1);
      const baseY = bandLo + t * (bandHi - bandLo) + (next() - 0.5) * 2.8;
      const wobble = makeTopoWobble(next);
      out.push({
        d: buildIsoD(baseY, wobble),
        opacity: 0.09 + next() * 0.09,
      });
    }
    return out;
  }

  /** @param {() => number} next @param {number} n */
  function generateMeridian(next, n) {
    /** @type {ContourPath[]} */
    const out = [];
    const bandLo = 10;
    const bandHi = 90;
    for (let i = 0; i < n; i += 1) {
      const t = n <= 1 ? 0.5 : i / (n - 1);
      const baseX = bandLo + t * (bandHi - bandLo) + (next() - 0.5) * 2.8;
      const wobble = makeTopoWobble(next);
      out.push({
        d: buildMeridianD(baseX, wobble),
        opacity: 0.09 + next() * 0.09,
      });
    }
    return out;
  }

  /** @param {() => number} next */
  function generateRings(next) {
    /** @type {ContourPath[]} */
    const out = [];
    const cx = 28 + next() * 44;
    const cy = 28 + next() * 44;
    const n = 12;
    for (let i = 0; i < n; i += 1) {
      const baseR = 6 + i * 6.2 + (next() - 0.5) * 2;
      const wobble = makeRingWobble(next);
      out.push({
        d: buildRingD(cx, cy, baseR, wobble),
        opacity: 0.085 + next() * 0.085,
      });
    }
    return out;
  }

  /** @param {() => number} next */
  function generateWeave(next) {
    const h = generateIso(next, 8).map((c) => ({ ...c, opacity: c.opacity * 0.88 }));
    const v = generateMeridian(next, 8).map((c) => ({ ...c, opacity: c.opacity * 0.72 }));
    return [...h, ...v];
  }

  /** @type {ContourPath[]} */
  let contours = $state([]);

  onMount(() => {
    const next = mulberry32(seed >>> 0);
    /** @type {ContourPath[]} */
    let list = [];
    switch (layout) {
      case 'meridian':
        list = generateMeridian(next, 13);
        break;
      case 'diagonal':
        list = generateIso(next, 13);
        break;
      case 'rings':
        list = generateRings(next);
        break;
      case 'weave':
        list = generateWeave(next);
        break;
      case 'iso':
      default:
        list = generateIso(next, 13);
        break;
    }
    contours = list;
  });
</script>

<div class="topo-host" data-layout={layout}>
  <div class="topo-svg-frame" class:topo-svg-frame--tilt={layout === 'diagonal'}>
    <svg class="topo-svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      {#each contours as c, i (i)}
        <path
          class="topo-line"
          d={c.d}
          fill="none"
          stroke="#ffffff"
          stroke-opacity={c.opacity}
          vector-effect="non-scaling-stroke"
        />
      {/each}
    </svg>
  </div>
  <div class="topo-vignette"></div>
</div>

<style>
  .topo-host {
    position: absolute;
    inset: 0;
    z-index: 0;
    pointer-events: none;
    overflow: hidden;
  }

  .topo-svg-frame {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
  }

  .topo-svg-frame--tilt {
    inset: -14%;
    width: 128%;
    height: 128%;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%) rotate(-15deg) scale(1.06);
    transform-origin: center;
  }

  .topo-svg {
    width: 100%;
    height: 100%;
    display: block;
  }

  .topo-line {
    stroke-width: 0.65px;
    stroke-linecap: round;
    stroke-linejoin: round;
  }

  .topo-vignette {
    position: absolute;
    inset: 0;
    background: radial-gradient(
      ellipse 92% 82% at 50% 45%,
      transparent 0%,
      rgba(10, 12, 16, 0.78) 100%
    );
    pointer-events: none;
  }

  .topo-host[data-layout='meridian'] .topo-vignette {
    background: radial-gradient(
      ellipse 88% 92% at 55% 50%,
      transparent 0%,
      rgba(10, 12, 16, 0.76) 100%
    );
  }

  .topo-host[data-layout='diagonal'] .topo-vignette {
    background: radial-gradient(
      ellipse 100% 70% at 48% 40%,
      transparent 0%,
      rgba(10, 12, 16, 0.8) 100%
    );
  }

  .topo-host[data-layout='rings'] .topo-vignette {
    background: radial-gradient(
      circle 55% at 42% 48%,
      transparent 0%,
      rgba(10, 12, 16, 0.5) 52%,
      rgba(10, 12, 16, 0.82) 100%
    );
  }

  .topo-host[data-layout='weave'] .topo-vignette {
    background: radial-gradient(
      ellipse 85% 85% at 50% 50%,
      transparent 0%,
      rgba(10, 12, 16, 0.82) 100%
    );
  }
</style>
