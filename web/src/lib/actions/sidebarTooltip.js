/** Fixed tooltip for collapsed sidebar; escapes overflow scroll clipping. */
export function sidebarTooltip(node, text) {
  let tip = null;

  function position() {
    if (!tip) return;
    const r = node.getBoundingClientRect();
    const pad = 8;
    tip.style.left = `${r.right + pad}px`;
    tip.style.top = `${r.top + r.height / 2}px`;
  }

  function show() {
    if (!text || tip) return;
    tip = document.createElement('div');
    tip.className = 'mdt-sidebar-tooltip';
    tip.setAttribute('role', 'tooltip');
    tip.textContent = text;
    document.body.appendChild(tip);
    position();
  }

  function hide() {
    tip?.remove();
    tip = null;
  }

  function onScrollOrResize() {
    hide();
  }

  function onEnter() {
    show();
  }

  function onLeave() {
    hide();
  }

  node.addEventListener('mouseenter', onEnter);
  node.addEventListener('mouseleave', onLeave);
  node.addEventListener('focus', onEnter);
  node.addEventListener('blur', onLeave);
  window.addEventListener('scroll', onScrollOrResize, true);
  window.addEventListener('resize', onScrollOrResize);

  return {
    update(newText) {
      text = newText;
      if (tip && text) tip.textContent = text;
      if (tip && !text) hide();
    },
    destroy() {
      hide();
      node.removeEventListener('mouseenter', onEnter);
      node.removeEventListener('mouseleave', onLeave);
      node.removeEventListener('focus', onEnter);
      node.removeEventListener('blur', onLeave);
      window.removeEventListener('scroll', onScrollOrResize, true);
      window.removeEventListener('resize', onScrollOrResize);
    },
  };
}
