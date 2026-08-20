const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (relPath) => fs.readFileSync(path.join(root, relPath), 'utf8');

test('standalone duty is sourced from the persisted MDT unit state', () => {
  const source = read('server/framework/standalone/provider.lua');
  assert.match(source, /getOfficerUnitRow/);
  assert.match(source, /local status = unit and trim\(unit\.status\):lower\(\) or 'off_duty'/);
  assert.match(source, /return status ~= '' and status ~= 'off_duty'/);
  assert.match(source, /officer\.status = 'off_duty'/);
});

test('MDT exposes a narrow authoritative duty contract for PolCam', () => {
  const manifest = read('fxmanifest.lua');
  const integration = read('server/integrations/polcam.lua');
  assert.match(manifest, /server\/integrations\/polcam\.lua/);
  assert.match(integration, /exports\('getOfficerDutyState'/);
  assert.match(integration, /exports\('isPlayerOnMdtDuty'/);
  assert.match(integration, /pcall\(framework\.isOnDuty, source\)/);
  assert.match(integration, /onDuty = false/);
});

test('air support requires on-duty operator and pilot in every access path', () => {
  const source = read('server/cameras.lua');
  assert.match(source, /local function airFeedCrewIsOnDuty\(feed\)/);
  assert.match(source, /config\.requireOperatorOnDuty ~= false/);
  assert.match(source, /config\.requirePilotOnDuty ~= false/);
  assert.match(source, /if not pilotSource or pilotSource <= 0 then[\s\S]*?return false/);
  assert.match(source, /buildAirFeedRows[\s\S]*?airFeedCrewIsOnDuty\(feed\)/);
  assert.match(source, /getAirFeedById[\s\S]*?not airFeedCrewIsOnDuty\(sanitized\)/);
  assert.match(source, /for feedId, viewers in pairs\(airFeedViewers\)[\s\S]*?airFeedCrewIsOnDuty\(feed\)/);
  assert.match(source, /elseif feedType == 'air'[\s\S]*?not airFeedCrewIsOnDuty\(feed\)/);
});

test('air support duty requirements default to enabled', () => {
  const source = read('shared/config.lua');
  assert.match(source, /Config\.AirSupport\s*=\s*\{[\s\S]*?requireOperatorOnDuty\s*=\s*true/);
  assert.match(source, /Config\.AirSupport\s*=\s*\{[\s\S]*?requirePilotOnDuty\s*=\s*true/);
});
