const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

function read(relPath) {
  return fs.readFileSync(path.join(root, relPath), 'utf8');
}

function exists(relPath) {
  return fs.existsSync(path.join(root, relPath));
}

function walk(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walk(fullPath));
    } else {
      results.push(fullPath);
    }
  }
  return results;
}

const expectedFiles = [
  'server/core.lua',
  'server/callbackRegistry.lua',
  'server/storage/localStorage.lua',
  'server/storage/sessionStore.lua',
  'server/storage/profilePrefs.lua',
  'server/storage/sqlStore.lua',
  'server/framework/common.lua',
  'server/framework/qbox/provider.lua',
  'server/framework/standalone/provider.lua',
  'server/framework/ers/provider.lua',
  'server/pages/dashboard.lua',
  'server/pages/dispatch.lua',
  'server/pages/units.lua',
  'server/pages/roster.lua',
  'server/pages/citizens.lua',
  'server/pages/civilian.lua',
  'server/pages/vehicles.lua',
  'server/pages/reports.lua',
  'server/pages/cases.lua',
  'server/pages/evidence.lua',
  'server/pages/bolos.lua',
  'server/pages/warrants.lua',
  'server/pages/weapons.lua',
  'server/pages/charges.lua',
  'server/pages/leaderboard.lua',
  'server/pages/cctv.lua',
  'server/pages/bodycams.lua',
  'server/pages/fto.lua',
  'server/pages/sops.lua',
  'server/pages/settings.lua',
  'server/pages/search.lua',
  'server/pages/citations.lua',
  'server/pages/index.lua',
  'server/integrations/ersIntake.lua',
  'server/integrations/dispatchBridge.lua',
];

const providerFiles = [
  'server/framework/qbox/provider.lua',
  'server/framework/standalone/provider.lua',
  'server/framework/ers/provider.lua',
];

const providerMethods = [
  'getMode',
  'getOfficer',
  'getCivilian',
  'isOnDuty',
  'setDuty',
  'getStableIdentifier',
  'getDepartment',
];

test('modular backend files exist', () => {
  const missing = expectedFiles.filter((relPath) => !exists(relPath));
  assert.deepEqual(missing, []);
});

test('fxmanifest loads modular server files before legacy page bootstrap', () => {
  const manifest = read('fxmanifest.lua');

  for (const relPath of [
    'server/core.lua',
    'server/callbackRegistry.lua',
    'server/storage/localStorage.lua',
    'server/storage/sessionStore.lua',
    'server/storage/profilePrefs.lua',
    'server/storage/sqlStore.lua',
    'server/framework/common.lua',
    'server/pages/index.lua',
    'server/data.lua',
  ]) {
    assert.match(manifest, new RegExp(relPath.replace(/[./]/g, '\\$&')));
  }
});

test('framework providers expose common interface', () => {
  for (const relPath of providerFiles) {
    const source = read(relPath);
    for (const method of providerMethods) {
      assert.match(source, new RegExp(`function\\s+Provider\\.${method}\\s*\\(`), `${relPath} missing ${method}`);
    }
  }
});

test('core module owns shared primitives', () => {
  const source = read('server/core.lua');
  for (const method of [
    'trim',
    'lower',
    'normalizePlate',
    'normalizeStatus',
    'nowIso',
    'epoch',
    'safeJsonEncode',
    'ok',
    'fail',
    'page',
    'clampString',
    'clampNumber',
    'sanitizeUrl',
    'makeId',
    'getPlayerIdentifier',
    'audit',
    'requireOfficer',
    'requireAdmin',
  ]) {
    assert.match(source, new RegExp(`function\\s+Core\\.${method}\\s*\\(`), `core missing ${method}`);
  }
});

test('page modules declare page-owned callback contracts', () => {
  const pages = {
    dashboard: ['cortex_mdt:getDashboard', 'cortex_mdt:sendDashboardChat'],
    dispatch: ['cortex_mdt:getDispatch', 'cortex_mdt:attachDispatchCall'],
    units: ['cortex_mdt:getUnits', 'cortex_mdt:updateUnitStatus', 'cortex_mdt:goOnDuty', 'cortex_mdt:goOffDuty'],
    roster: ['cortex_mdt:getRoster', 'cortex_mdt:updateOfficerAdmin'],
    citizens: ['cortex_mdt:searchCitizens', 'cortex_mdt:getCitizen', 'cortex_mdt:updateCitizen'],
    civilian: ['cortex_mdt:getStandaloneCivilianState', 'cortex_mdt:getCivilianRecords'],
    vehicles: ['cortex_mdt:searchVehicles', 'cortex_mdt:getVehicle', 'cortex_mdt:impoundVehicle'],
    reports: ['cortex_mdt:getReports', 'cortex_mdt:getReport', 'cortex_mdt:createReport'],
    cases: ['cortex_mdt:getCases', 'cortex_mdt:getCase', 'cortex_mdt:createCase'],
    evidence: ['cortex_mdt:getEvidence', 'cortex_mdt:getEvidenceRecord', 'cortex_mdt:updateEvidence'],
    bolos: ['cortex_mdt:getBolos', 'cortex_mdt:createBolo'],
    warrants: ['cortex_mdt:getWarrants', 'cortex_mdt:createWarrant'],
    weapons: ['cortex_mdt:searchWeapons', 'cortex_mdt:getWeapon', 'cortex_mdt:createWeapon'],
    charges: ['cortex_mdt:getCharges', 'cortex_mdt:updateCharge'],
    leaderboard: ['cortex_mdt:getLeaderboard'],
    cctv: ['cortex_mdt:getCameras', 'cortex_mdt:viewCamera'],
    bodycams: ['cortex_mdt:getBodycams', 'cortex_mdt:viewBodycam'],
    fto: ['cortex_mdt:getFtoRecords', 'cortex_mdt:createFtoRecord', 'cortex_mdt:updateFtoRecord'],
    sops: ['cortex_mdt:getSops'],
    settings: ['cortex_mdt:getSettings', 'cortex_mdt:updateSetting', 'cortex_mdt:saveOfficerAvatar'],
    search: ['cortex_mdt:globalSearch'],
    citations: ['cortex_mdt:issueCitation', 'cortex_mdt:getCitation'],
  };

  for (const [page, callbacks] of Object.entries(pages)) {
    const source = read(`server/pages/${page}.lua`);
    assert.match(source, /^return\s+function\s*\(ctx\)/m, `${page} must return page registration function`);
    assert.match(source, /registerPage\(/, `${page} does not register page contract`);
    for (const callbackName of callbacks) {
      assert.match(source, new RegExp(callbackName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')), `${page} missing ${callbackName}`);
    }
  }
});

test('every NUI server post maps to a Lua callback handler or client bridge', () => {
  const webFiles = walk(path.join(root, 'web', 'src')).filter((file) => /\.(js|svelte)$/.test(file));
  const luaFiles = [
    ...walk(path.join(root, 'client')),
    ...walk(path.join(root, 'server')),
  ].filter((file) => /\.lua$/.test(file));

  const nuiPosts = new Set();
  for (const file of webFiles) {
    const source = fs.readFileSync(file, 'utf8');
    for (const match of source.matchAll(/nuiPost\(\s*['"](cortex_mdt:[^'"]+)['"]/g)) {
      nuiPosts.add(match[1]);
    }
  }

  const luaCallbacks = new Set();
  for (const file of luaFiles) {
    const source = fs.readFileSync(file, 'utf8');
    for (const match of source.matchAll(/['"](cortex_mdt:[^'"]+)['"]/g)) {
      luaCallbacks.add(match[1]);
    }
  }

  const missing = [...nuiPosts].filter((name) => !luaCallbacks.has(name)).sort();
  assert.deepEqual(missing, []);
});

test('data.lua is bootstrap-aware instead of only a giant callback bucket', () => {
  const source = read('server/data.lua');
  assert.match(source, /CortexMdtPageContracts/, 'data.lua must load or expose page contracts');
});
