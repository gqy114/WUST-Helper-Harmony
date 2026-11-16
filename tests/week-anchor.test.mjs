// 周次校准：以「校准时刻 + 校准周次」为锚点自动推进，并迁移旧版绝对周次。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('校准后的周次按周自动推进，不受旧学期开始日期影响', async () => {
  const page = await source('entry/src/main/ets/pages/course/CoursePage.ets');
  assert.match(page, /weekAnchorTimestamp/, '缺少校准锚点时间');
  assert.match(page, /weekAnchorWeek/, '缺少校准锚点周次');
  assert.match(page, /const anchorWeekday = \(anchorDate\.getDay\(\) \+ 6\) % 7;/, '没有按周一作为自然周边界');
  assert.match(page, /Math\.floor\(\(passedDays \+ anchorWeekday\) \/ 7\)/, '没有按跨过的周一数推进');
  assert.match(page, /anchorWeek \+ elapsedWeeks/, '没有在锚点周次上加经过周数');
});

test('校准动作写入锚点，不再依赖学期开始日期算 offset', async () => {
  const page = await source('entry/src/main/ets/pages/course/CoursePage.ets');
  assert.match(page, /AppStorage\.setOrCreate\('weekAnchorTimestamp', now\)/, '校准没有写锚点时间');
  assert.match(page, /AppStorage\.setOrCreate\('weekAnchorWeek', week\)/, '校准没有写锚点周次');
  assert.doesNotMatch(page, /const offset = week - this\.calcCurrentWeek\(\);/, '仍在使用旧的 offset 方案');
});

test('旧版保存的手动周次会迁移成锚点', async () => {
  const page = await source('entry/src/main/ets/pages/course/CoursePage.ets');
  assert.match(page, /getSettingNumber\('adjustedCurrentWeek', 0\)/, '没有读取旧版绝对周次');
  assert.match(page, /if \(legacyWeek >= 1\)/, '没有迁移旧版周次');
  assert.match(page, /setSettingNumber\('weekAnchorWeek', legacyWeek\)/, '旧数据没有写入锚点');
});
