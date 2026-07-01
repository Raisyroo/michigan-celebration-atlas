import assert from 'node:assert/strict';
import test from 'node:test';
import { isMainModule } from '../scripts/upload-reviewed-flyers.mjs';

test('entrypoint guard matches a Windows-style script path', () => {
  const windowsScriptPath = String.raw`C:\repo\michigan-celebration-atlas\scripts\upload-reviewed-flyers.mjs`;
  const windowsModuleUrl = 'file:///C:/repo/michigan-celebration-atlas/scripts/upload-reviewed-flyers.mjs';

  assert.equal(isMainModule(windowsModuleUrl, windowsScriptPath, { windows: true }), true);
});

test('entrypoint guard rejects a different Windows-style script path', () => {
  const windowsScriptPath = String.raw`C:\repo\michigan-celebration-atlas\scripts\other.mjs`;
  const windowsModuleUrl = 'file:///C:/repo/michigan-celebration-atlas/scripts/upload-reviewed-flyers.mjs';

  assert.equal(isMainModule(windowsModuleUrl, windowsScriptPath, { windows: true }), false);
});
