import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

function fixture(run) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'timezy-config-'));
  try {
    fs.mkdirSync(path.join(root, 'scripts'));
    fs.mkdirSync(path.join(root, 'Config'));
    fs.copyFileSync(new URL('../scripts/prepare-config.mjs', import.meta.url), path.join(root, 'scripts/prepare-config.mjs'));
    run(root, () => spawnSync(process.execPath, [path.join(root, 'scripts/prepare-config.mjs')], { encoding: 'utf8' }));
  } finally {
    assert.equal(path.dirname(path.resolve(root)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(root).startsWith('timezy-config-'));
    fs.rmSync(root, { recursive: true, force: true });
  }
}

function firebase(bundle = 'com.timezy.app', reversed = 'com.googleusercontent.apps.test') {
  return `<plist><dict><key>BUNDLE_ID</key><string>${bundle}</string><key>REVERSED_CLIENT_ID</key><string>${reversed}</string><key>CLIENT_ID</key><string>test-client</string><key>GOOGLE_APP_ID</key><string>test-app</string></dict></plist>`;
}

test('local-only build gets permissions and fallback callback scheme', () => fixture((root, run) => {
  assert.equal(run().status, 0);
  const plist = fs.readFileSync(path.join(root, 'Config/Info.plist'), 'utf8');
  assert.match(plist, /NSMicrophoneUsageDescription/);
  assert.match(plist, /NSSpeechRecognitionUsageDescription/);
  assert.match(plist, /com.timezy.unconfigured/);
}));

test('valid Firebase config copies resource and installs callback scheme', () => fixture((root, run) => {
  fs.writeFileSync(path.join(root, 'Config/GoogleService-Info.plist'), firebase());
  assert.equal(run().status, 0);
  assert.match(fs.readFileSync(path.join(root, 'Config/Info.plist'), 'utf8'), /com.googleusercontent.apps.test/);
  assert.equal(fs.readFileSync(path.join(root, 'Sources/Resources/GoogleService-Info.plist'), 'utf8'), firebase());
}));

test('wrong bundle ID and invalid callback scheme fail before packaging', () => fixture((root, run) => {
  fs.writeFileSync(path.join(root, 'Config/GoogleService-Info.plist'), firebase('com.wrong.app'));
  assert.notEqual(run().status, 0);
  fs.writeFileSync(path.join(root, 'Config/GoogleService-Info.plist'), firebase('com.timezy.app', 'bad<scheme'));
  assert.notEqual(run().status, 0);
}));

test('removing configuration does not leave another project bundled', () => fixture((root, run) => {
  fs.writeFileSync(path.join(root, 'Config/GoogleService-Info.plist'), firebase());
  assert.equal(run().status, 0);
  fs.unlinkSync(path.join(root, 'Config/GoogleService-Info.plist'));
  assert.equal(run().status, 0);
  assert.equal(fs.existsSync(path.join(root, 'Sources/Resources/GoogleService-Info.plist')), false);
}));
