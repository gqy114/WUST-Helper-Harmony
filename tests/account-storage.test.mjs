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

test('共享课表启用时，个人课表写入无法覆盖已选档案的课程', async () => {
  const { storage } = await createStorage();
  await storage.setStudentId('A');
  await storage.setCurrentArchiveId('shared_example');
  const sharedCourses = courses('共享课程');
  await storage.setCourseArchives([{
    id: 'shared_example', name: '共享课表', semester: '2026-2027-1', courses: sharedCourses, isMine: false
  }]);
  await storage.setCurrentArchiveCourses('shared_example', sharedCourses);
  const originalMarker = storage.getCourseCacheMarker();
  await storage.setCurrentCourses(courses('本人课程'), 'prefetch', 'mine');
  assert.equal(await storage.getCurrentArchiveId(), 'shared_example');
  assert.equal((await storage.getCurrentCourses())[0].courseName, '共享课程');
  assert.equal(storage.getCourseCacheMarker(), originalMarker);
});

test('共享档案读取本档案的实验，刷新共享课程不丢失实验，移除后不再显示', async () => {
  const { storage } = await createStorage();
  await storage.setStudentId('A');
  await storage.setPhysicalExperimentCourses(courses('我的实验').map(course => ({
    ...course, isPhysicalExperiment: true, physicalDate: '2026-11-24'
  })));
  await storage.setCurrentCourses(courses('我的课程'));
  const id = 'shared_example';
  const save = async (name) => storage.setCourseArchives([{
    id, name: '共享档案', semester: '2026-2027-1', courses: courses(name), isMine: false
  }]);
  const names = async () => Array.from(await storage.getCurrentCourses(), course => course.courseName);
  await save('共享课程');
  await storage.setCurrentArchiveId(id);
  await storage.setPhysicalExperimentCourses(courses('导入的实验').map(course => ({
    ...course, isPhysicalExperiment: true, physicalDate: '2026-11-25'
  })));
  assert.deepEqual(await names(), ['共享课程', '导入的实验']);
  await save('刷新后的共享课程');
  assert.deepEqual(await names(), ['刷新后的共享课程', '导入的实验']);
  await storage.setCurrentArchiveCourses(id, courses('刷新后的共享课程'));
  assert.deepEqual(await names(), ['刷新后的共享课程', '导入的实验']);
  await storage.resetCourseCache();
  assert.equal(await storage.removePhysicalExperimentCourses(), 1);
  assert.deepEqual(await names(), ['刷新后的共享课程']);
});

test('删除当前共享档案前先恢复自己的课程，且保留同账号其他档案', async () => {
  const { storage } = await createStorage();
  await storage.setStudentId('A');
  const epoch = storage.getSessionEpoch();
  const mine = { id: 'mine', name: '我的课表', semester: '2026-2027-1', courses: courses('我的课程'), isMine: true };
  const shared = { id: 'shared_example', name: '同学', semester: '2025-2026-2',
    courses: courses('共享课程'), isMine: false, relation: '同学课表' };
  const friend = { ...shared, id: 'archive_friend', relation: '朋友课表' };
  await storage.setCourseArchives([mine, shared, friend]);
  assert.equal(await storage.activateCourseArchive(shared, '2026-03-02', epoch), true);
  assert.equal(await storage.getSettingString('archiveTermStartDate'), '2026-03-02');
  assert.equal((await storage.getCurrentCourses())[0].courseName, '共享课程');
  assert.equal(await storage.removeCourseArchive(shared.id, epoch), false);
  assert.equal(await storage.activateCourseArchive(mine, '2026-09-01', epoch), true);
  assert.equal(await storage.removeCourseArchive(shared.id, epoch), true);
  assert.equal((await storage.getCurrentCourses())[0].courseName, '我的课程');
  assert.deepEqual(Array.from(await storage.getCourseArchives(), item => item.id), [mine.id, friend.id]);
});
