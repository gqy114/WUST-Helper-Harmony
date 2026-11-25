import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { SourceTextModule } from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';

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

test('拖动、缩放与导出共用同一裁剪坐标，横图能够填满竖向课表', async () => {
  const code = await readFile(new URL('../entry/src/main/ets/utils/ScheduleBackgroundCrop.ts', import.meta.url), 'utf8');
  const module = new SourceTextModule(stripTypeScriptTypes(code));
  await module.link(() => {});
  await module.evaluate();
  const { coverScale, cropOffset, sourceCrop } = module.namespace;
  const scale = coverScale(1200, 800, 200, 400);
  assert.equal(scale, 0.5);
  assert.equal(cropOffset(500, 1200 * scale, 200), 200);
  assert.deepEqual({ ...sourceCrop(1200, 800, 200, 400, 1, 200, 0) },
    { x: 0, y: 0, width: 400, height: 800 });
  assert.deepEqual({ ...sourceCrop(1200, 800, 200, 400, 2, -100, 40) },
    { x: 600, y: 160, width: 200, height: 400 });
  assert.deepEqual({ ...sourceCrop(600, 1200, 200, 400, 1, 0, 0) },
    { x: 0, y: 0, width: 600, height: 1200 });
});

test('课表页测量显示比例，并以白框标出固定裁剪区域', async () => {
  const course = await readFile(new URL('../entry/src/main/ets/pages/course/CoursePage.ets', import.meta.url), 'utf8');
  assert.match(course, /params: \{ aspect: this\.backgroundAspect \}/);
  assert.match(course, /this\.backgroundAspect = width \/ height/);
  assert.match(pageSource, /return this\.frameWidth \/ this\.aspect/);
  assert.match(pageSource, /border\(\{ width: 2, color: '#FFFFFF' \}\)/);
  assert.match(pageSource, /if \(this\.aspect <= 0\)/);
});
