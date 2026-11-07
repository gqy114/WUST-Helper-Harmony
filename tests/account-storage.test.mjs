// 账号隔离的存储行为测试：直接跑真实 AppStorage 代码（preferences 用内存假实现）。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });

async function createStorage() {
  const store = new Map();
  let holdCurrentCourses = false;
  let releasePut = null;
  const context = createContext({ console });
  const arkData = new SyntheticModule(['preferences'], function () {
    this.setExport('preferences', {
      getPreferences: async () => ({
        get: async (key, def) => (store.has(key) ? store.get(key) : def),
        put: async (key, value) => {
          if (holdCurrentCourses && key === 'currentCourses') {
            await new Promise((resolve) => { releasePut = resolve; });
          }
          store.set(key, value);
        },
        flush: async () => {},
      }),
    });
  });
  const abilityKit = new SyntheticModule(['common'], function () {
    this.setExport('common', {});
  });
  const model = new SyntheticModule(
    ['ScheduleSettings', 'DEFAULT_SETTINGS', 'CourseArchive', 'CourseData'],
    function () {
      this.setExport('ScheduleSettings', undefined);
      this.setExport('DEFAULT_SETTINGS', undefined);
      this.setExport('CourseArchive', undefined);
      this.setExport('CourseData', undefined);
    });

  const storageModule = new SourceTextModule(transform(await source('../entry/src/main/ets/store/AppStorage.ts')));
  await storageModule.link((name) => {
    if (name === '@kit.ArkData') return arkData;
    if (name === '@kit.AbilityKit') return abilityKit;
    if (name === '../model/CourseModel') return model;
    throw new Error(`Unexpected import: ${name}`);
  });
  await storageModule.evaluate();
  const storage = storageModule.namespace.AppStorage.getInstance();
  await storage.init({});
  const control = {
    holdCurrentCourses() { holdCurrentCourses = true; },
    release() {
      holdCurrentCourses = false;
      const resolve = releasePut;
      releasePut = null;
      if (resolve) resolve();
    },
    get waiting() { return releasePut !== null; },
  };
  return { storage, store, control };
}

const courses = (name) => [{
  courseName: name, teacher: '', location: '', dayOfWeek: 1, startPeriod: 1,
  endPeriod: 2, weekRanges: '1-16', color: '#fff',
}];

const legacyData = () => [{
  id: 'archive_1', name: 'A导入的课表', semester: '2025-2026-1', courses: courses('旧课'),
}];

test('切换账号期间完成的旧写入会被丢弃，不覆盖新账号课表', async () => {
  const { storage } = await createStorage();
  await storage.setStudentId('A');
  await storage.setCurrentCourses(courses('A的课'), 'writeA');

  // A 的异步写入刚开始，就切换到 B（epoch 变化）
  const pending = storage.setCurrentCourses(courses('迟到的A课'), 'writeLate');
  await storage.setStudentId('B');
  await pending;

  const saved = await storage.getCurrentCourses();
  assert.equal(saved.some((item) => item.courseName === '迟到的A课'), false);
});

test('A 的写入卡在落盘阶段时，B 保存完成后不会被覆盖', async () => {
  const { storage, control } = await createStorage();
  await storage.setStudentId('A');
  await storage.setCurrentCourses(courses('A的课'), 'mA');

  control.holdCurrentCourses();
  const aWrite = storage.setCurrentCourses(courses('迟到的A课'), 'mA2');
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(control.waiting, true, 'A 应卡在最终落盘阶段');

  await storage.setStudentId('B');
  const bWrite = storage.setCurrentCourses(courses('B的课'), 'mB');
  control.release();
  await aWrite;
  await bWrite;

  const saved = await storage.getCurrentCourses();
  assert.equal(saved.some((item) => item.courseName === 'B的课'), true, 'B 的课表应保留');
  assert.equal(saved.some((item) => item.courseName === '迟到的A课'), false, 'A 的旧数据不应残留');
});

test('旧预取的回滚排在新课表写入之后也不会清空新课表', async () => {
  const { storage } = await createStorage();
  await storage.setStudentId('A');
  await storage.setSemester('2025-2026-1');
  await storage.setCurrentCourses(courses('旧学期课'), 'prefetch_old');

  // 切换学期：新课表的写入先入队
  await storage.setSemester('2025-2026-2');
  const newWrite = storage.setCurrentCourses(courses('新学期课'), 'new_semester');
  // 旧预取此时才回滚：判断必须发生在队列内，看到的是新课表的标记
  const rolledBack = await storage.resetCourseCacheIfMarker('prefetch_old');
  await newWrite;

  assert.equal(rolledBack, false, '不是自己的写入就不应清空');
  const saved = await storage.getCurrentCourses();
  assert.equal(saved.some((item) => item.courseName === '新学期课'), true, '新课表不能被清空');
});

test('条件清空：仍是自己的写入时才清空', async () => {
  const { storage } = await createStorage();
  await storage.setStudentId('A');
  await storage.setCurrentCourses(courses('我的课'), 'mine');
  const rolledBack = await storage.resetCourseCacheIfMarker('mine');
  assert.equal(rolledBack, true);
  const saved = await storage.getCurrentCourses();
  assert.equal(saved.length, 0, '自己的写入应被清空');
});

test('旧档案只被升级后的第一个账号认领一次，其它账号看不到', async () => {
  const { storage, store } = await createStorage();
  store.set('courseArchives', JSON.stringify(JSON.stringify(legacyData())));

  await storage.setStudentId('A');
  const aArchives = await storage.getCourseArchives();
  assert.equal(aArchives.length, 1, '第一个账号应认领旧档案');

  await storage.setStudentId('B');
  const bArchives = await storage.getCourseArchives();
  assert.equal(bArchives.length, 0, 'B 不应看到 A 的旧档案');
});

test('登录即认领：A 没打开档案页就切到 B，B 也不会认领', async () => {
  const { storage, store } = await createStorage();
  store.set('courseArchives', JSON.stringify(JSON.stringify(legacyData())));
  await storage.setStudentId('A');
  await storage.setStudentId('B');
  const bArchives = await storage.getCourseArchives();
  assert.equal(bArchives.length, 0, 'B 不应认领 A 的旧档案');
});

test('升级时已登录：启动 init 就完成认领', async () => {
  const { storage, store } = await createStorage();
  store.set('courseArchives', JSON.stringify(JSON.stringify(legacyData())));
  store.set('studentId', JSON.stringify('A'));
  // 模拟升级后首次启动
  await storage.init({});
  await storage.setStudentId('B');
  const bArchives = await storage.getCourseArchives();
  assert.equal(bArchives.length, 0, 'B 不应认领 A 的旧档案');
});

test('未登录时不认领旧档案', async () => {
  const { storage, store } = await createStorage();
  store.set('courseArchives', JSON.stringify(JSON.stringify(legacyData())));
  const archives = await storage.getCourseArchives();
  assert.equal(archives.length, 1);
  await storage.setStudentId('C');
  const claimed = await storage.getCourseArchives();
  assert.equal(claimed.length, 1, '登录后由当前账号认领');
});
