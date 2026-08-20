const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (relPath) => fs.readFileSync(path.join(root, relPath), 'utf8');

test('feature parity records use durable namespaced storage', () => {
  const parity = read('server/parity.lua');
  const store = read('server/storage/sessionStore.lua');
  assert.match(store, /cortex_mdt:persistent_namespaces:v2/);
  assert.match(store, /LocalStorage\.set\(STORAGE_KEY,\s*SessionStore\.state\)/);
  assert.match(parity, /Store\.set\(featureNamespace\(kind\),\s*record\.id,\s*record\)/);
  assert.match(parity, /Store\.list\(featureNamespace\(kind\)\)/);
});

test('management-only parity mutations are server-authorized', () => {
  const source = read('server/parity.lua');
  assert.match(source, /local MANAGED_ONLY_CREATE\s*=\s*\{/);
  assert.match(source, /MANAGED_ONLY_CREATE\[kind\]\s+and\s+not canManage\(source\)/);
  assert.match(source, /updateFeatureRecord[\s\S]*?if not canManage\(source\) then/);
  assert.match(source, /deleteFeatureRecord[\s\S]*?if not canManage\(source\) then/);
  assert.match(source, /IsPlayerAceAllowed\(source,\s*ace\)/);
});

test('parity payloads are bounded and reject malformed numeric and URL input', () => {
  const source = read('server/parity.lua');
  assert.match(source, /boundedString\([^\n]+title[^\n]+160/);
  assert.match(source, /boundedString\([^\n]+content[^\n]+12000/);
  assert.match(source, /finiteNumber\([^\n]+score[^\n]+0,\s*10/);
  assert.match(source, /finiteNumber\([^\n]+radius[^\n]+25,\s*5000/);
  assert.match(source, /entry:match\('\^https\?\:\/\/'\)/);
  assert.match(source, /boundedUrlArray\(payload\.evidence,\s*8,\s*512\)/);
});

test('parity updates enforce optimistic versions', () => {
  const source = read('server/parity.lua');
  assert.match(source, /expectedVersion\s+and\s+expectedVersion\s*~=\s*tonumber\(existing\.version\)/);
  assert.match(source, /code\s*=\s*'version_conflict'/);
  assert.match(source, /record\.version\s*=\s*\(tonumber\(existing\.version\)\s+or\s+0\)\s*\+\s*1/);
});

test('public complaints are bounded, private, throttled, and avoid transient source identity', () => {
  const source = read('server/parity.lua');
  assert.match(source, /now\s*-\s*last\s*<\s*30000/);
  assert.match(source, /#content\s*<\s*20/);
  assert.match(source, /visibility\s*=\s*'management'/);
  assert.match(source, /reporterContact\s*=\s*boundedString/);
  assert.match(source, /sessionActorIdentifiers\[source\]/);
  assert.doesNotMatch(source, /source:%s/);
});

test('SOP acknowledgement is tied to the exact revision', () => {
  const server = read('server/parity.lua');
  const reader = read('web/src/pages/SOPs.svelte');
  assert.match(server, /sopVersion\s*=\s*tonumber\(sop\.version\)\s+or\s+1/);
  assert.match(reader, /Number\(row\.sopVersion\)\s*===\s*Number\(sop\?\.version\s*\|\|\s*1\)/);
});

test('bodycam frames are source-bound and world-plausibility checked', () => {
  const source = read('server/cameras.lua');
  assert.match(source, /RegisterNetEvent\('cortex_mdtsv:bodycamFrame',[\s\S]*?local sourceId = source/);
  assert.match(source, /not bodycamIsEnabledFor\(sourceId\)\s+or\s+not officerIsOnDuty\(sourceId\)/);
  assert.match(source, /\(dx \* dx\) \+ \(dy \* dy\) \+ \(dz \* dz\) > 25\.0/);
  assert.match(source, /minimumInterval[\s\S]*?minimumInterval - 15/);
});

test('live feeds recheck duty and routing bucket separation', () => {
  const source = read('server/cameras.lua');
  assert.match(source, /if not officerIsOnDuty\(source\) then[\s\S]*?code = 'off_duty'/);
  assert.match(source, /sameRoutingBucket\(viewer,\s*feed\.source,\s*getDashcamConfig\(\)\.allowCrossRoutingBuckets\)/);
  assert.match(source, /sameRoutingBucket\(viewer,\s*feed\.operatorSource,\s*getAirSupportConfig\(\)\.allowCrossRoutingBuckets\)/);
  assert.match(source, /sameRoutingBucket\(viewer,\s*targetSource,\s*getBodycamConfig\(\)\.allowCrossRoutingBuckets\)/);
});

test('a viewer may reopen its current feed at capacity without duplicating membership', () => {
  const source = read('server/cameras.lua');
  assert.match(source, /alreadyWatching\s*=\s*currentView\s+and\s+currentView\.kind\s*==\s*'bodycam'/);
  assert.match(source, /not alreadyWatching\s+and\s+getBodycamViewerCount/);
  assert.match(source, /bodycamViewers\[feed\.source\]\[source\]\s*=\s*true/);
});

test('stale feeds and all viewer lifecycle paths clean up', () => {
  const source = read('server/cameras.lua');
  assert.match(source, /now\s*-\s*lastFrame\s*>\s*staleAfter/);
  assert.match(source, /AddEventHandler\('playerDropped'/);
  assert.match(source, /AddEventHandler\('onResourceStop'/);
  assert.match(source, /clearViewer\(sourceId\)/);
  assert.match(source, /forceStopCameraView\(viewerSource\)/);
});

test('air support is read-only and sourced from Cortex PolCam exports', () => {
  const server = read('server/cameras.lua');
  const client = read('client/cameras.lua');
  const page = read('web/src/pages/Bodycams.svelte');
  assert.match(server, /GetActiveAirFeeds\(\)/);
  assert.match(server, /GetAirFeedById\(feedId\)/);
  assert.match(server, /sanitizeAirFeed/);
  assert.match(client, /setMirroredVisionMode\(frame\.visionMode\)/);
  assert.match(client, /fov\s*=\s*frame\.preview\s+and\s+frame\.preview\.fov\s+or\s+frame\.fov/);
  assert.match(client, /if activeView\.kind == 'air' then return end/);
  assert.match(page, /class="air-table"/);
  assert.match(page, /feedState\.tracking\s*\|\|\s*activeFeed\?\.tracking/);
  assert.match(page, /feedState\.fov\s*\?\?/);
});

test('live feed listing does not abort on the client-only vehicle class native', () => {
  const server = read('server/cameras.lua');
  assert.doesNotMatch(server, /\bGetVehicleClass\s*\(/);
  assert.match(server, /local dashcamOk, dashcams\s*=\s*pcall\(buildDashcamRows\)/);
  assert.match(server, /if not dashcamOk or type\(dashcams\) ~= 'table' then dashcams = \{\} end/);
  assert.match(server, /local airFeeds\s*=\s*buildAirFeedRows\(source\)/);
  assert.match(server, /airFeeds\s*=\s*airFeeds/);
});

test('dashcams apply configured model offsets from server-derived model hashes', () => {
  const server = read('server/cameras.lua');
  const client = read('client/cameras.lua');
  assert.match(server, /modelHash\s*=\s*GetEntityModel\(vehicle\)/);
  assert.match(client, /config\.modelOffsets/);
  assert.match(client, /GetHashKey\(modelName\)/);
  assert.match(client, /resolveDashcamOffset\(modelHash,\s*direction\)/);
  assert.match(client, /applyDashcamOffset\(coords,\s*heading,\s*activeView\.direction,\s*frame\.modelHash\s+or\s+activeView\.modelHash\)/);
});

test('MDT PTT integration is removed from the UI and client bridge', () => {
  const client = read('client/main.lua');
  const toolbar = read('web/src/lib/components/Toolbar.svelte');
  const app = read('web/src/App.svelte');
  const config = read('shared/config.lua');
  assert.doesNotMatch(toolbar, /RadioPTT/);
  assert.doesNotMatch(toolbar, /Hold PTT/);
  assert.doesNotMatch(client, /radioPTT|sendRadioConfig|setRadioTalking/);
  assert.doesNotMatch(app, /radioConfig/);
  assert.doesNotMatch(config, /Config\.Radio/);
});

test('dispatch map uses the ox_mdt tile grid and initializes reactive overlays', () => {
  const component = read('web/src/lib/components/DispatchMap.svelte');
  assert.match(component, /https:\/\/s\.rsg\.sc\/sc\/images\/games\/GTAV\/map\/game\/\{z\}\/\{x\}\/\{y\}\.jpg/);
  assert.match(component, /L\.tileLayer\(OX_TILE_URL/);
  assert.match(component, /let mapReady = \$state\(false\)/);
  assert.match(component, /if \(!mapReady \|\| !mapInstance\) return/);
});

test('standalone complaint command and civilian portal share the public callback', () => {
  const client = read('client/main.lua');
  const app = read('web/src/App.svelte');
  const services = read('web/src/pages/CivilianServices.svelte');
  assert.match(client, /publicComplaintCommand/);
  assert.match(client, /exports\('openComplaint'/);
  assert.match(client, /RegisterNUICallback\('cortex_mdt:openComplaint'/);
  assert.match(app, /cortex_mdt:showComplaint/);
  assert.match(services, /cortex_mdt:openComplaint/);
  assert.match(app, /complaintReturnFocus[\s\S]*?await tick\(\)[\s\S]*?returnFocus\.focus/);
  assert.match(read('web/src/lib/components/ComplaintForm.svelte'), /tick\(\)\.then\(\(\) => firstInput\?\.focus\(\)\)/);
});

test('page dialogs consume Escape before the MDT shell closes', () => {
  const app = read('web/src/App.svelte');
  const command = read('web/src/pages/Command.svelte');
  assert.match(app, /if \(e\.defaultPrevented\) return/);
  assert.match(app, /querySelector\('\[role="dialog"\]\[aria-modal="true"\]'\)/);
  assert.match(command, /event\.key === 'Escape'[\s\S]*?event\.preventDefault\(\)[\s\S]*?closeEditor\(\)/);
  assert.match(command, /await tick\(\)[\s\S]*?trigger\?\.focus\?\.\(\)/);
});
