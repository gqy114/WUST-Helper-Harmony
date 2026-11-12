// 考试倒计时缓存按学号隔离：切账号时不能把 A 的考试写进 B 的卡片。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('考试倒计时缓存按学号分 key', async () => {
  const data = await source('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /private static examStorageKey\(sid: string\): string/, '缺少按学号生成 key');
  assert.match(data, /`\$\{EXAM_KEY\}_\$\{sid\}`/, 'key 未带学号');
  assert.match(data, /getExamCountdowns\(storage: AppStorage, sid: string = ''\)/, '读取未接受学号');
  assert.match(data, /setExamCountdowns\(storage: AppStorage, items: WidgetCountdownItem\[\], sid: string\)/, '写入未带学号');
});

test('读取卡片数据时使用当前账号的考试缓存', async () => {
  const data = await source('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /const sid = \(await storage\.getStudentId\(\)\)\.trim\(\);/, '卡片读取没有取当前学号');
  assert.match(data, /getExamCountdowns\(storage, sid\)/, '卡片读取没有传入学号');
});

test('同步期间切换账号，丢弃旧账号的考试结果', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /const sid = \(await storage\.getStudentId\(\)\)\.trim\(\);/, '同步前没有记录学号');
  assert.match(page, /if \(\(await storage\.getStudentId\(\)\)\.trim\(\) !== sid\)/, '同步后没有校验账号是否变化');
  assert.match(page, /setExamCountdowns\(storage, items, sid\)/, '写入缓存时没有带学号');
});

test('设置页读取考试缓存也按当前账号', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /const sid = \(await storage\.getStudentId\(\)\)\.trim\(\);\s*this\.examCountdowns = await WidgetPrefs\.getExamCountdowns\(storage, sid\)/,
    '设置页读取没有按账号隔离');
});
