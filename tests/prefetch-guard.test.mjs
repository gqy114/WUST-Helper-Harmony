// 启动页预取的账号隔离测试：
// 预取请求在途时切换账号/学期，旧课表不能再写进新账号的缓存；
// 即使写入过程中发生切换，也要回滚。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * scenario:
 *  - 'switch-during-request'：请求返回前切号（版本号变化）
 *  - 'switch-during-write'：写入过程中的异步阶段切号
 */
async function createService(scenario) {
  const writes = [];
  const resets = [];
  let epoch = 0;
  let switched = false;
  const context = createContext({ console, setTimeout, clearTimeout });

  const storage = new SyntheticModule(['AppStorage'], function () {
    const instance = {
      getSessionEpoch: () => epoch,
      getStudentId: async () => (switched ? 'new-sid' : 'old-sid'),
      getCourseAsHome: async () => true,
      getToken: async () => 'token',
      getIsGraduate: async () => false,
      getSemester: async () => '2026-2027-1',
      getPassword: async () => 'pwd',
      getTermStartDate: async () => '2026-08-31',
      setTermStartDate: async () => {},
      setCurrentCourses: async (list) => {
        if (scenario === 'switch-during-write') {
          // 模拟写入期间用户切号：版本号先变，写入随后落盘
          switched = true;
          epoch += 1;
        }
        await delay(10);
        writes.push(list);
      },
      resetCourseCache: async () => { resets.push(1); },
    };
    this.setExport('AppStorage', { getInstance: () => instance });
  });
  const session = new SyntheticModule(['TeachingSessionService'], function () {
    this.setExport('TeachingSessionService', { ensureSession: async () => true });
  });
  const courseApi = new SyntheticModule(['CourseApi'], function () {
    const fetchCourses = async () => {
      if (scenario === 'switch-during-request') {
        switched = true;
        epoch += 1;
      }
      await delay(20);
      return { code: 200, data: [{ courseName: '高等数学' }] };
    };
    this.setExport('CourseApi', {
      getCourseTable: fetchCourses,
      getGraduateCourseTable: fetchCourses,
      getTermStartDate: async () => ({ code: 200, data: { year: 2026, month: 8, day: 31 } }),
    });
  });
  const homeApi = new SyntheticModule(['HomeContentApi'], function () {
    this.setExport('HomeContentApi', { preload: async () => {} });
  });
  const model = new SyntheticModule(['CourseData'], function () {
    this.setExport('CourseData', undefined);
  });

  const service = new SourceTextModule(transform(await source('../entry/src/main/ets/service/LaunchPrefetchService.ets')));
  await service.link((name) => {
    if (name === '../store/AppStorage') return storage;
    if (name === './TeachingSessionService') return session;
    if (name === '../net/CourseApi') return courseApi;
    if (name === '../net/HomeContentApi') return homeApi;
    if (name === '../model/CourseModel') return model;
    throw new Error(`Unexpected import: ${name}`);
  });
  await service.evaluate();
  return { writes, resets, service: service.namespace.LaunchPrefetchService, context };
}

test('预取期间切换账号/学期时不写课表缓存', async () => {
  const { writes, service } = await createService('switch-during-request');
  service.start();
  await service.awaitPrefetch(3000);
  assert.equal(writes.length, 0, `不应写入 ${writes.length} 次课表缓存`);
  assert.equal(service.coursePrefetchedRecently('new-sid', false, '2026-2027-1'), false);
});

test('写入过程中切换账号时回滚预取结果', async () => {
  const { writes, resets, service } = await createService('switch-during-write');
  service.start();
  await service.awaitPrefetch(3000);
  assert.equal(resets.length >= 1, true, '切号后应清空刚写入的课表');
  assert.equal(service.coursePrefetchedRecently('new-sid', false, '2026-2027-1'), false);
});

test('预取状态绑定账号、身份和学期', async () => {
  const code = await source('../entry/src/main/ets/service/LaunchPrefetchService.ets');
  assert.match(code, /static coursePrefetchedRecently\(sid: string, graduate: boolean, semester: string\)/);
  assert.match(code, /prefetchedSid === sid/);
  assert.match(code, /prefetchedSemester === semester/);
  assert.match(code, /getSessionEpoch\(\) !== epoch/);
  assert.match(code, /resetCourseCache\(\)/);
});

test('课表页先等预取结束再决定是否复用', async () => {
  const code = await source('../entry/src/main/ets/pages/course/CoursePage.ets');
  assert.match(code, /await LaunchPrefetchService\.awaitPrefetch\(\)/);
  assert.match(code, /await this\.loadCurrentArchiveCourses\(\)/);
});
