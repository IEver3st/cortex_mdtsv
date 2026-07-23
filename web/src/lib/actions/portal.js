/**
 * Reparents the node to `document.body` (or `target`) so `position: fixed` modals
 * stack above later DOM siblings (e.g. dashboard grid vs. quick-actions prelude).
 * @param {HTMLElement} node
 * @param {ParentNode} [target]
 * @returns {import('svelte/action').ActionReturn}
 */
export function portal(node, target = document.body) {
  target.appendChild(node);
  return {
    destroy() {
      if (node.parentNode) node.parentNode.removeChild(node);
    },
  };
}
