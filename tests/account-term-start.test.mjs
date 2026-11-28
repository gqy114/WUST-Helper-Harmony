import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('开学日期按账号隔离，切号后桌面卡片不沿用上一个账号', async () => {
  const storage = await source('store/AppStorage.ts');
  assert.match(storage, /getAccountTermStartDate\(studentId: string, semester: string\)/, '缺少账号开学日期读取');
  assert.match(storage, /setAccountTermStartDate\(studentId: string, semester: string, value: string\)/, '缺少账号开学日期写入');
  const widget = await source('widget/WidgetData.ets');
  assert.match(widget, /getWidgetSchedule\(formId\)/, '组件没有读取绑定档案');
  assert.match(storage, /getAccountTermStartDate\(studentId, semester\)/, '本人档案没有读取当前账号开学日期');
  assert.doesNotMatch(widget, /archiveId === 'mine' \? await storage\.getTermStartDate\(\)/, '组件仍回退全局开学日期');
  const page = await source('pages/course/CoursePage.ets');
  assert.match(page, /setAccountTermStartDate\(sid, semester, termStart\)/, '课程页没有写入账号开学日期');
});

test('刷新我的课表时不再读取共享档案的开学日期', async () => {
  const page = await source('pages/course/CoursePage.ets');
  assert.match(page, /archiveId === 'mine'[\s\S]{0,80}getAccountTermStartDate/, '我的课表没有优先使用账号日期');
  assert.match(page, /archiveId === 'mine'[\s\S]{0,220}getSharedArchiveTermStartDate/, '共享档案仍会走全局日期回退');
});
