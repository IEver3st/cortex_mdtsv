import test from 'node:test';
import assert from 'node:assert/strict';

import { DEFAULT_CHARGES, applyChargePatch } from './charges.js';

test('applyChargePatch updates penalty fields for matching charge id', () => {
  const original = DEFAULT_CHARGES.find((charge) => charge.id === 1);

  assert.ok(original, 'expected default charge with id 1');

  const updated = applyChargePatch(DEFAULT_CHARGES, {
    chargeId: 1,
    fine: 999,
    jailTime: 12,
    maxJail: 24,
  });

  const patched = updated.find((charge) => charge.id === 1);

  assert.equal(patched.fine, 999);
  assert.equal(patched.jailTime, 12);
  assert.equal(patched.maxJail, 24);
  assert.equal(patched.charge, original.charge);
  assert.notEqual(updated, DEFAULT_CHARGES);
});
