// 考试倒计时缓存按学号 + 学期隔离：切账号/切学期都不能读到旧数据。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('考试倒计时缓存 key 同时包含学号和学期', async () => {
  const data = await source('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /private static examStorageKey\(sid: string, term: string\): string/, '缺少按学号+学期生成 key');
  assert.match(data, /`\$\{EXAM_KEY\}_\$\{account\}_\$\{semester\}`/, 'key 未同时带学号与学期');
  assert.match(data, /getExamCountdowns\(storage: AppStorage, sid: string = '', term: string = ''\)/, '读取未接受学期');
  assert.match(data, /setExamCountdowns\(storage: AppStorage, items: WidgetCountdownItem\[\], sid: string,\s*term: string\)/, '写入未带学期');
});

test('卡片读取时使用当前账号与当前学期', async () => {
  const data = await source('entry/src/main/ets/widget/WidgetData.ets');
  assert.match(data, /const sid = \(await storage\.getStudentId\(\)\)\.trim\(\);/, '卡片读取没有取当前学号');
  assert.match(data, /let term = \(await storage\.getSemester\(\)\)\.trim\(\);/, '卡片读取没有取当前学期');
  assert.match(data, /getExamCountdowns\(storage, sid, term\)/, '卡片读取没有传学号+学期');
});

test('同步期间切账号或切学期，丢弃旧结果', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /const sid = \(await storage\.getStudentId\(\)\)\.trim\(\);/, '同步前没有记录学号');
  assert.match(page, /if \(\(await storage\.getStudentId\(\)\)\.trim\(\) !== sid\)/, '同步后没有校验账号');
  assert.match(page, /if \(termBeforeSave !== term/, '落盘前没有校验学期');
  assert.match(page, /setExamCountdowns\(storage, items, sid, term\)/, '写入缓存没有带学期');
});

test('设置页读取考试缓存也按当前账号与学期', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /let cachedTerm = \(await storage\.getSemester\(\)\)\.trim\(\);\s*if \(!cachedTerm\) cachedTerm = \(await storage\.getSelectSemester\(\)\)\.trim\(\);\s*this\.examCountdowns = await WidgetPrefs\.getExamCountdowns\(storage, sid, cachedTerm\)/,
    '设置页读取没有按账号+学期隔离');
});

test('同步完成时的刷新请求会排队执行，不会被跳过', async () => {
  const page = await source('entry/src/main/ets/pages/profile/WidgetSettingsPage.ets');
  assert.match(page, /private refreshChain: Promise<void> = Promise\.resolve\(\);/, '缺少刷新队列');
  assert.match(page, /const run = this\.refreshChain\.then\(/, '刷新没有入队');
  assert.doesNotMatch(page, /if \(this\.busy\) return;/, '仍在刷新期间直接丢弃请求');
  assert.match(page, /this\.refreshChain = run\.then/, '刷新队列没有串起来');
});
