import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const pageSource = fs.readFileSync(
  new URL('../entry/src/main/ets/pages/course/BackgroundSetting.ets', import.meta.url),
  'utf8'
);
const serviceSource = fs.readFileSync(
  new URL('../entry/src/main/ets/utils/ScheduleBackgroundService.ets', import.meta.url),
  'utf8'
);

test('schedule background is copied out of the temporary PhotoPicker URI', () => {
  assert.doesNotMatch(pageSource, /this\.bgImage\s*=\s*result\.photoUris\[0\]/);
  assert.match(pageSource, /ScheduleBackgroundService\.persist\(context, result\.photoUris\[0\]\)/);
  assert.match(serviceSource, /context\.filesDir/);
  assert.match(serviceSource, /fileIo\.openSync\(sourceUri, fileIo\.OpenMode\.READ_ONLY\)/);
  assert.match(serviceSource, /fileIo\.copyFileSync\(sourceFile\.fd, targetFile\.fd\)/);
  assert.match(serviceSource, /return `file:\/\/\$\{targetPath\}`/);
});

test('replaced and cleared schedule backgrounds remove only app-owned files', () => {
  assert.match(pageSource, /ScheduleBackgroundService\.removeOwned\(context, oldImage\)/);
  assert.match(pageSource, /private async clearBackgroundImage\(\)/);
  assert.match(serviceSource, /if \(!path\.startsWith\(directoryPrefix\)\)/);
});
