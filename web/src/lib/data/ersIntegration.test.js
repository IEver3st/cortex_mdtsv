import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../../../..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');

test('ERS integration server file is loaded by manifest', () => {
  const manifest = read('fxmanifest.lua');

  assert.match(manifest, /server\/ers\.lua/);
});

test('ERS integration listens for night_ers ped and vehicle events', () => {
  const ers = read('server/ers.lua');

  assert.match(ers, /ErsIntegration::OnFirstNPCInteraction/);
  assert.match(ers, /ErsIntegration::OnPullover/);
  assert.match(ers, /ErsIntegration::OnFirstVehicleInteraction/);
  assert.match(ers, /upsertErsPed/);
  assert.match(ers, /upsertErsVehicle/);
});

test('local mode exposes external citizen and vehicle upserts for ERS', () => {
  const localMode = read('server/localMode.lua');

  assert.match(localMode, /function LocalMode\.upsertExternalCitizen/);
  assert.match(localMode, /function LocalMode\.upsertExternalVehicle/);
});

test('ERS biometric login uses bounded shift confirmation waits', () => {
  const main = read('server/main.lua');

  assert.match(main, /ERS_SHIFT_CONFIRM_TIMEOUT_MS = 1800/);
  assert.match(main, /ERS_SHIFT_RETRY_TIMEOUT_MS = 1000/);
  assert.doesNotMatch(main, /waitForErsShiftState\(source, ersResource, true, 'police', 5000\)/);
  assert.doesNotMatch(main, /waitForErsShiftState\(source, ersResource, false, 'police', 5000\)/);
});
