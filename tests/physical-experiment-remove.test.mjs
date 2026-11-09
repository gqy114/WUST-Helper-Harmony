// 物理实验课表「一键移除」的行为与界面接线测试。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule } from 'node:vm';

const pagePath = '../entry/src/main/ets/pages/course/PhysicalExperimentPage.ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

const regular = (name) => ({ courseName: name, dayOfWeek: 1, startPeriod: 1, endPeriod: 2, weekRanges: '1-16' });
const experiment = (name) => ({ courseName: name, dayOfWeek: 2, startPeriod: 3, endPeriod: 4, weekRanges: '1-16', isPhysicalExperiment: true });

async function makePage(initialCourses) {
  const pageSource = await source(pagePath);
  const found = pageSource.match(/  private async removeFromTimetable\(\): Promise<void> \{[\s\S]*?\r?\n  \}/);
  assert.ok(found, 'removeFromTimetable 方法未找到');

  const toasts = [];
  let current = initialCourses.slice();
  const writes = { experiments: 0, courses: 0 };
  let storeSnapshot = [];
  const storage = {
    getCurrentCourses: async () => current.slice(),
    setPhysicalExperimentCourses: async (list) => {
      writes.experiments += 1;
      assert.equal(list.length, 0, '移除时应清空实验课缓存');
    },
    setCurrentCourses: async (list) => {
      writes.courses += 1;
      current = list.slice();
    },
  };
  const context = createContext({
    console,
    JSON,
    Date,
    Number,
    Array,
    PreferenceStorage: { getInstance: () => storage },
    promptAction: { showToast: ({ message }) => toasts.push(message) },
    AppStorage: { setOrCreate: () => {} },
  });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestPage {\n${found[0]}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const page = new mod.namespace.TestPage();
  page.removing = false;
  page.hasTimetableExperiments = true;
  page.store = { setCourses: (list) => { storeSnapshot = list.slice(); } };
  return { page, toasts, writes, current: () => current, storeSnapshot: () => storeSnapshot };
}

test('移除只删实验课程，其他课程和顺序保持不变', async () => {
  const { page, toasts, writes, current, storeSnapshot } = await makePage([
    regular('高等数学'), experiment('实验4-18'), regular('大学物理'), experiment('实验4-12'),
  ]);
  await page.removeFromTimetable();

  const names = current().map((item) => item.courseName);
  assert.deepEqual(names, ['高等数学', '大学物理']);
  assert.equal(writes.experiments, 1);
  assert.equal(writes.courses, 1);
  assert.equal(page.hasTimetableExperiments, false);
  assert.deepEqual(storeSnapshot().map((item) => item.courseName), ['高等数学', '大学物理']);
  assert.equal(toasts.at(-1), '已移除2门实验课程');
});

test('课表里没有实验课程时不写存储，只提示', async () => {
  const { page, toasts, writes } = await makePage([regular('高等数学')]);
  await page.removeFromTimetable();
  assert.equal(writes.experiments, 0);
  assert.equal(writes.courses, 0);
  assert.equal(page.hasTimetableExperiments, false);
  assert.equal(toasts.at(-1), '课表中没有实验课程');
});

test('移除后再次调用不会重复写存储', async () => {
  const { page, writes } = await makePage([experiment('实验4-18')]);
  await page.removeFromTimetable();
  assert.equal(writes.courses, 1);
  await page.removeFromTimetable();
  assert.equal(writes.courses, 1);
});

test('页面提供移除按钮、确认弹窗，并在导入/进入时刷新状态', async () => {
  const code = await source(pagePath);
  assert.match(code, /Button\('移除实验课表'\)/, '缺少移除按钮');
  assert.match(code, /if \(this\.hasTimetableExperiments\)/, '按钮应只在课表有实验课时显示');
  assert.match(code, /Text\('移除实验课表？'\)/, '缺少确认弹窗');
  assert.match(code, /只会移除从物理实验导入的课程/, '确认弹窗缺少说明');
  assert.match(code, /private async refreshTimetableState\(storage: PreferenceStorage\): Promise<void>/, '缺少状态刷新方法');
  assert.match(code, /this\.hasTimetableExperiments = current\.some\(/, '进入页面时应检查课表');
  assert.match(code, /this\.hasTimetableExperiments = saved\.some\(/, '导入后应刷新按钮状态');
  assert.match(code, /course\.isPhysicalExperiment !== true/, '移除时应只过滤实验课程');
  assert.match(code, /setPhysicalExperimentCourses\(\[\]\)/, '移除时应清空实验课缓存');
  assert.match(code, /AppStorage\.setOrCreate<number>\('courseDataVersion', Date\.now\(\)\)/, '移除后应通知课表刷新');
});
