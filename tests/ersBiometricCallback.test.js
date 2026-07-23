const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

test('server registers ERS biometric login callback', () => {
  const serverMain = fs.readFileSync(path.join(root, 'server', 'main.lua'), 'utf8');

  assert.match(
    serverMain,
    /lib\.callback\.register\(\s*['"]cortex_mdt:ersBiometricLogin['"]/,
    'cortex_mdt:ersBiometricLogin must be registered server-side'
  );
});
