let _tick = $state(0);
let _pending = $state(null);

/** Queue opening Reports → create form with prefilled fields */
export function queueReportsCompose(payload) {
  _pending = payload;
  _tick++;
}

export const reportsCompose = {
  get tick() {
    return _tick;
  },
  consume() {
    const p = _pending;
    _pending = null;
    return p;
  },
};
