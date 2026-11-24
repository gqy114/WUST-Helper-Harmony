import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('刷新同一门课时，条目标识随教室、教师或下课时间变化', async () => {
  const carousel = await source('../entry/src/main/ets/widget/DailyWidgetCarousel.ets');
  const match = carousel.match(/\(course: DailyWidgetCourse, index: number\) => (.+)\)/);
  assert.ok(match);
  const key = new Function('course', 'index', 'return ' + match[1]);
  const lesson = { name: '线性代数', start: '08:20', end: '10:00', details: '教一楼 · 王老师' };
  for (const change of [{ end: '10:15' }, { details: '教三楼 · 王老师' }, { details: '教一楼 · 李老师' }]) {
    assert.notEqual(key(lesson, 0), key({ ...lesson, ...change }, 0));
  }
});
