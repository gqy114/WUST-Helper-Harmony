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
  const writes = { remove: 0, courses: 0 };
  let storeSnapshot = [];
  const storage = {
    getCurrentCourses: async () => current.slice(),
    // 真实实现里「清空实验缓存 + 重写课表」在同一个写入任务中完成。
    removePhysicalExperimentCourses: async () => {
      const kept = current.filter((course) => course.isPhysicalExperiment !== true);
      const removed = current.length - kept.length;
      if (removed > 0) {
        writes.remove += 1;
        current = kept;
      }
      return removed;
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
  assert.equal(writes.remove, 1);
  assert.equal(page.hasTimetableExperiments, false);
  assert.deepEqual(storeSnapshot().map((item) => item.courseName), ['高等数学', '大学物理']);
  assert.equal(toasts.at(-1), '已移除2门实验课程');
});

test('课表里没有实验课程时不写存储，只提示', async () => {
  const { page, toasts, writes, storeSnapshot } = await makePage([regular('高等数学')]);
  await page.removeFromTimetable();
  assert.equal(writes.remove, 0);
  assert.equal(page.hasTimetableExperiments, false);
  assert.deepEqual(storeSnapshot(), [], '没有可删条目时不应刷新课表');
  assert.equal(toasts.at(-1), '课表中没有实验课程');
});

test('移除后再次调用不会重复写存储', async () => {
  const { page, writes } = await makePage([experiment('实验4-18')]);
  await page.removeFromTimetable();
  assert.equal(writes.remove, 1);
  await page.removeFromTimetable();
  assert.equal(writes.remove, 1);
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
  assert.match(code, /removePhysicalExperimentCourses\(\)/, '移除应走原子方法，而不是分两步写');
  assert.doesNotMatch(code, /setPhysicalExperimentCourses\(\[\]\)/, '不能再单独清空实验缓存');
  assert.match(code, /AppStorage\.setOrCreate<number>\('courseDataVersion', Date\.now\(\)\)/, '移除后应通知课表刷新');
});

test('移除在同一个写入任务里完成，避免实验课被迁移回课表', async () => {
  const storeSource = await source('../entry/src/main/ets/store/AppStorage.ts');
  const found = storeSource.match(/  async removePhysicalExperimentCourses\(\): Promise<number> \{[\s\S]*?\r?\n  \}/);
  assert.ok(found, 'AppStorage.removePhysicalExperimentCourses 未找到');

  const writes = [];
  const context = createContext({ console, JSON, Date, Number, Array });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestStore {\n${found[0]}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const store = new mod.namespace.TestStore();
  store.courseCacheMarker = '';
  store.isPhysicalExperimentCourse = (course) => course.isPhysicalExperiment === true;
  store.getStoredCourses = async () => [regular('高等数学'), experiment('实验4-18'), regular('大学物理')];
  store.putStr = async (key, value) => { writes.push([key, value]); };
  // 写入队列是同步执行的：不存在「清空实验缓存 → 读旧课表迁移 → 合并回课表」的中间态。
  store.enqueueCourseWrite = async (task) => task();

  const removed = await store.removePhysicalExperimentCourses();
  assert.equal(removed, 1);
  assert.deepEqual(writes.map((item) => item[0]), ['physicalExperimentCourses', 'currentCourses']);
  assert.equal(writes[0][1], '[]', '应先清空实验课缓存');
  assert.deepEqual(JSON.parse(writes[1][1]).map((item) => item.courseName), ['高等数学', '大学物理']);
  assert.match(store.courseCacheMarker, /^remove_experiments_/, '应更新写入标记');
});

test('没有实验课时原子方法不写存储', async () => {
  const storeSource = await source('../entry/src/main/ets/store/AppStorage.ts');
  const found = storeSource.match(/  async removePhysicalExperimentCourses\(\): Promise<number> \{[\s\S]*?\r?\n  \}/);
  const writes = [];
  const context = createContext({ console, JSON, Date, Number, Array });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestStore {\n${found[0]}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const store = new mod.namespace.TestStore();
  store.courseCacheMarker = 'unchanged';
  store.isPhysicalExperimentCourse = (course) => course.isPhysicalExperiment === true;
  store.getStoredCourses = async () => [regular('高等数学')];
  store.putStr = async (key, value) => { writes.push([key, value]); };
  store.enqueueCourseWrite = async (task) => task();

  assert.equal(await store.removePhysicalExperimentCourses(), 0);
  assert.deepEqual(writes, []);
  assert.equal(store.courseCacheMarker, 'unchanged');
});

// ---------------------------------------------------------------------------
// 删除已导入的实验日程
// ---------------------------------------------------------------------------

async function makeCalendarPage(initialIds, failingIds = [], initialKeys = []) {
  const pageSource = await source(pagePath);
  const found = pageSource.match(/  private async removeFromCalendar\(\): Promise<void> \{[\s\S]*?\r?\n  \}/);
  assert.ok(found, 'removeFromCalendar 方法未找到');

  const toasts = [];
  const deleted = [];
  const settingWrites = {};
  const storage = {
    getSettingString: async (key) => {
      if (key === 'physicalExperimentCalendarEventIds') return JSON.stringify(initialIds);
      if (key === 'physicalExperimentCalendarKeys') return JSON.stringify(initialKeys);
      return '';
    },
    setSettingString: async (key, value) => { settingWrites[key] = value; },
  };
  const context = createContext({
    console,
    JSON,
    Number,
    Array,
    PreferenceStorage: { getInstance: () => storage },
    promptAction: { showToast: ({ message }) => toasts.push(message) },
    calendarManager: {
      getCalendarManager: () => ({
        getCalendar: async () => ({
          deleteEvent: async (id) => {
            if (failingIds.indexOf(id) >= 0) throw new Error('event not found');
            deleted.push(id);
          },
        }),
      }),
    },
    getContext: () => ({}),
  });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestPage {\n${found[0]}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();
  const page = new mod.namespace.TestPage();
  page.removingCalendar = false;
  page.hasCalendarEvents = true;
  page.requestCalendarPermission = async () => true;
  return { page, toasts, deleted, settingWrites };
}

test('删除日程按保存的事件 id 逐条删除并清空记录', async () => {
  const { page, toasts, deleted, settingWrites } = await makeCalendarPage([11, 12, 13]);
  await page.removeFromCalendar();

  assert.deepEqual(deleted, [11, 12, 13]);
  assert.equal(settingWrites['physicalExperimentCalendarEventIds'], '');
  assert.equal(settingWrites['physicalExperimentCalendarKeys'], '', '删除后要允许重新导入');
  assert.equal(page.hasCalendarEvents, false);
  assert.equal(toasts.at(-1), '已删除3条实验日程');
});

test('没有保存的日程时不删除，只提示', async () => {
  const { page, toasts, deleted, settingWrites } = await makeCalendarPage([]);
  await page.removeFromCalendar();
  assert.deepEqual(deleted, []);
  assert.equal(settingWrites['physicalExperimentCalendarEventIds'], undefined);
  assert.equal(page.hasCalendarEvents, false);
  assert.equal(toasts.at(-1), '没有需要删除的实验日程');
});

test('删除失败的那条保留记录，其余日程正常删除', async () => {
  const { page, toasts, deleted, settingWrites } = await makeCalendarPage([21, 22, 23], [22]);
  await page.removeFromCalendar();
  assert.deepEqual(deleted, [21, 23]);
  assert.equal(settingWrites['physicalExperimentCalendarEventIds'], '[22]', '失败条目不能被清掉');
  assert.equal(page.hasCalendarEvents, true, '还有未删除的日程');
  assert.equal(toasts.at(-1), '已删除2条，1条删除失败已保留记录，可重试');
});

test('删除失败时保留对应的事件 key，避免重新导入重复', async () => {
  const keys = ['k21', 'k22', 'k23'];
  const { page, settingWrites } = await makeCalendarPage([21, 22, 23], [22], keys);
  await page.removeFromCalendar();
  assert.deepEqual(JSON.parse(settingWrites['physicalExperimentCalendarKeys']), ['k22']);
});

test('删除新版日程时保留旧版只有 key 的导入记录', async () => {
  const keys = ['legacy-k1', 'legacy-k2', 'new-k31', 'new-k32'];
  const { page, deleted, settingWrites } = await makeCalendarPage([31, 32], [], keys);
  await page.removeFromCalendar();

  assert.deepEqual(deleted, [31, 32]);
  assert.equal(settingWrites['physicalExperimentCalendarEventIds'], '');
  assert.deepEqual(JSON.parse(settingWrites['physicalExperimentCalendarKeys']), ['legacy-k1', 'legacy-k2'],
    '旧版去重 key 不能随新版日程一起清除');
});

test('新版日程部分删除失败时同时保留旧版 key 和失败项 key', async () => {
  const keys = ['legacy-k1', 'new-k41', 'new-k42'];
  const { page, settingWrites } = await makeCalendarPage([41, 42], [42], keys);
  await page.removeFromCalendar();

  assert.deepEqual(JSON.parse(settingWrites['physicalExperimentCalendarEventIds']), [42]);
  assert.deepEqual(JSON.parse(settingWrites['physicalExperimentCalendarKeys']), ['legacy-k1', 'new-k42']);
});

test('页面提供删除日程按钮、确认弹窗，并在导入时记录事件 id', async () => {
  const code = await source(pagePath);
  assert.match(code, /Button\('删除实验日程'\)/, '缺少删除日程按钮');
  assert.match(code, /if \(this\.hasCalendarEvents\)/, '按钮应只在有已导入日程时显示');
  assert.match(code, /Text\('删除实验日程？'\)/, '缺少确认弹窗');
  assert.match(code, /只会删除通过本应用导入到系统日历的实验日程/, '确认弹窗缺少说明');
  assert.match(code, /physicalExperimentCalendarEventIds/, '导入时应记录日历事件 id');
  assert.match(code, /const eventId = await calendar\.addEvent\(event\);/, '导入时没有保存 addEvent 返回值');
  assert.match(code, /await calendar\.deleteEvent\(ids\[i\]\)/, '删除时应按事件 id 删除');
  assert.match(code, /private async refreshCalendarState\(storage: PreferenceStorage\): Promise<void>/, '缺少日程状态刷新方法');
});
// ---------------------------------------------------------------------------
// 并发：移除实验课与读取课表交错
// ---------------------------------------------------------------------------

function extractMethod(sourceText, signature) {
  const start = sourceText.indexOf(signature);
  assert.ok(start >= 0, `未找到方法：${signature}`);
  const brace = sourceText.indexOf('{', start);
  let depth = 0;
  for (let i = brace; i < sourceText.length; i++) {
    if (sourceText[i] === '{') depth++;
    else if (sourceText[i] === '}') {
      depth--;
      if (depth === 0) return sourceText.slice(start, i + 1);
    }
  }
  throw new Error(`方法括号不匹配：${signature}`);
}

async function makeConcurrentStore(initialCourses, options = {}) {
  const storeSource = await source('../entry/src/main/ets/store/AppStorage.ts');
  const methods = [
    extractMethod(storeSource, '  async removePhysicalExperimentCourses(): Promise<number> {'),
    extractMethod(storeSource, '  async getPhysicalExperimentCourses(): Promise<CourseData[]> {'),
    extractMethod(storeSource, '  private async readPhysicalExperimentCoursesUnlocked(): Promise<CourseData[]> {'),
    extractMethod(storeSource, '  async getCurrentCourses(): Promise<CourseData[]> {'),
    extractMethod(storeSource, '  private async readCurrentCoursesUnlocked(): Promise<CourseData[]> {'),
  ].join('\n');

  const pauseOnClear = options.pauseOnClear === true;
  let current = initialCourses.slice();
  let experiments = initialCourses.filter((course) => course.isPhysicalExperiment === true);
  let paused = false;
  let released = false;
  let resume = () => {};
  const gate = new Promise((resolve) => { resume = resolve; });

  const context = createContext({ console, JSON, Date, Number, Array });
  const mod = new SourceTextModule(stripTypeScriptTypes(`export class TestStore {\n${methods}\n}`, { mode: 'transform' }), { context });
  await mod.link(() => { throw new Error('No imports expected'); });
  await mod.evaluate();

  const store = new mod.namespace.TestStore();
  store.courseWriteChain = Promise.resolve();
  store.courseCacheMarker = '';
  store.enqueueCourseWrite = function (task) {
    const run = this.courseWriteChain.then(task, task);
    this.courseWriteChain = run.then(() => {}, () => {});
    return run;
  };
  store.getStoredCourses = async (key) => (key === 'currentCourses' ? current.slice() : experiments.slice());
  store.putStr = async (key, value) => {
    if (key === 'physicalExperimentCourses') {
      experiments = JSON.parse(value);
      // 复现评审步骤：清空实验缓存后暂停，给并发读取留出插入窗口。
      if (pauseOnClear && !paused && !released && value === '[]') {
        paused = true;
        await gate;
      }
      return;
    }
    current = JSON.parse(value);
  };
  store.isPhysicalExperimentCourse = (course) => course.isPhysicalExperiment === true;
  store.mergePhysicalExperiments = (courses, experimentList) => {
    const merged = courses.slice();
    for (const experiment of experimentList) {
      const duplicated = merged.some((course) => course.courseName === experiment.courseName &&
        course.physicalDate === experiment.physicalDate &&
        course.dayOfWeek === experiment.dayOfWeek && course.startPeriod === experiment.startPeriod);
      if (!duplicated) merged.push(experiment);
    }
    return merged;
  };

  return {
    store,
    isPaused: () => paused,
    release: () => { released = true; resume(); },
    current: () => current.slice(),
    experiments: () => experiments.slice(),
  };
}

test('并发读取不能把已移除的实验课迁移回课表', async () => {
  const env = await makeConcurrentStore([
    regular('高等数学'), experiment('实验4-18'), regular('大学物理'),
  ], { pauseOnClear: true });

  const removal = env.store.removePhysicalExperimentCourses();
  // 等到「实验缓存已清空、课表尚未重写」的暂停点。
  while (!env.isPaused()) await new Promise((resolve) => setTimeout(resolve, 1));

  const concurrentRead = env.store.getPhysicalExperimentCourses();
  env.release();

  const removed = await removal;
  const experimentsAfter = await concurrentRead;
  assert.equal(removed, 1);
  assert.deepEqual(experimentsAfter, [], '并发读取不应迁移回任何实验课');
  assert.deepEqual(env.current().map((course) => course.courseName), ['高等数学', '大学物理']);

  const list = await env.store.getCurrentCourses();
  assert.deepEqual(list.map((course) => course.courseName), ['高等数学', '大学物理']);
});

test('先发起课表读取再移除，最终结果也不含实验课', async () => {
  const env = await makeConcurrentStore([regular('高等数学'), experiment('实验4-18')]);
  const read = env.store.getCurrentCourses();
  const removal = env.store.removePhysicalExperimentCourses();
  await Promise.all([read, removal]);
  const list = await env.store.getCurrentCourses();
  assert.deepEqual(list.map((course) => course.courseName), ['高等数学']);
});