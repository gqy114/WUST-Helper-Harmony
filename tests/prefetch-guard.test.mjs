// 启动页预取的账号隔离测试：
// 预取请求在途时如果切换了账号，返回的旧课表不能再写进新账号的缓存。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function createService() {
  const writes = [];
  let switched = false;
  const context = createContext({ console, setTimeout, clearTimeout });

  const storage = new SyntheticModule(['AppStorage'], function () {
    const instance = {
      getStudentId: async () => (switched ? 'new-sid' : 'old-sid'),
      getCourseAsHome: async () => true,
      getToken: async () => 'token',
      getIsGraduate: async () => false,
      getSemester: async () => '2026-2027-1',
      getPassword: async () => 'pwd',
      getTermStartDate: async () => '2026-08-31',
      setTermStartDate: async () => {},
      setCurrentCourses: async (list) => { writes.push(list); },
    };
    this.setExport('AppStorage', { getInstance: () => instance });
  });
  const session = new SyntheticModule(['TeachingSessionService'], function () {
    this.setExport('TeachingSessionService', { ensureSession: async () => true });
  });
  const courseApi = new SyntheticModule(['CourseApi'], function () {
    this.setExport('CourseApi', {
      getCourseTable: async () => {
        // 请求发出后账号被切换
        switched = true;
        await delay(20);
        return { code: 200, data: [{ courseName: '高等数学' }] };
      },
      getGraduateCourseTable: async () => {
        switched = true;
        await delay(20);
        return { code: 200, data: [{ courseName: '高等数学' }] };
      },
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
  return { writes, service: service.namespace.LaunchPrefetchService, context };
}

test('预取期间切换账号时不写课表缓存', async () => {
  const { writes, service } = await createService();
  service.start();
  await service.awaitPrefetch(3000);
  assert.equal(writes.length, 0, `不应写入 ${writes.length} 次课表缓存`);
  assert.equal(service.coursePrefetchedRecently(), false);
});

test('启动页预取在校验身份后才写缓存', async () => {
  const code = await source('../entry/src/main/ets/service/LaunchPrefetchService.ets');
  assert.match(code, /expectedSid: string/);
  assert.match(code, /currentSid !== expectedSid/);
  assert.match(code, /discard result/);
});

test('课表页先等预取结束再决定是否复用', async () => {
  const code = await source('../entry/src/main/ets/pages/course/CoursePage.ets');
  assert.match(code, /await LaunchPrefetchService\.awaitPrefetch\(\)/);
  assert.match(code, /await this\.loadCurrentArchiveCourses\(\)/);
});
