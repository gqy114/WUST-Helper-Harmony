// 读取认证令牌期间切号：必须拿不到旧/新账号的令牌来发送旧账号数据。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

async function createStorage() {
  const context = createContext({ console, JSON, Date, Number, Array, Promise, Map, Set });
  const ark = new SyntheticModule(['preferences'], function () { this.setExport('preferences', {}); }, { context });
  const ability = new SyntheticModule(['common'], function () { this.setExport('common', {}); }, { context });
  const model = new SyntheticModule(['ScheduleSettings', 'DEFAULT_SETTINGS', 'CourseArchive', 'CourseData'], function () {
    for (const key of ['ScheduleSettings', 'DEFAULT_SETTINGS', 'CourseArchive', 'CourseData']) {
      this.setExport(key, key === 'DEFAULT_SETTINGS' ? {} : undefined);
    }
  }, { context });
  const source = await readFile(new URL('../entry/src/main/ets/store/AppStorage.ts', import.meta.url), 'utf8');
  const module = new SourceTextModule(stripTypeScriptTypes(source, { mode: 'transform' }), { context });
  await module.link((name) => name === '@kit.ArkData' ? ark : name === '@kit.AbilityKit' ? ability : model);
  await module.evaluate();
  const storage = module.namespace.AppStorage.getInstance();
  const db = new Map();
  storage.kvStore = {
    get: async (key, fallback) => db.has(key) ? db.get(key) : fallback,
    put: async (key, value) => { db.set(key, value); },
    flush: async () => {},
  };
  return storage;
}

test('切号后读取令牌返回空串，不会把旧账号令牌发给新账号', async () => {
  const storage = await createStorage();
  await storage.setStudentId('A');
  const epochA = storage.getSessionEpoch();
  await storage.setAppAuthAccessToken('token-A');
  await storage.setStudentId('B');
  assert.equal(await storage.getAppAuthAccessTokenForSession(epochA, 'A'), '');
});

test('读取令牌期间切号：即使读到旧值也返回空串', async () => {
  const storage = await createStorage();
  await storage.setStudentId('A');
  const epochA = storage.getSessionEpoch();
  await storage.setAppAuthAccessToken('token-A');

  const get = storage.kvStore.get;
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  storage.kvStore.get = async (key, fallback) => {
    if (key === 'appAuthAccessToken') {
      await gate;
    }
    return get(key, fallback);
  };

  const reading = storage.getAppAuthAccessTokenForSession(epochA, 'A');
  await new Promise(resolve => setTimeout(resolve, 20));
  await storage.setStudentId('B');
  release();
  assert.equal(await reading, '');
});

test('昵称同步读取令牌使用会话校验，读取后再复核账号', async () => {
  const page = await readFile(new URL('../entry/src/main/ets/pages/profile/EditNamePage.ets', import.meta.url), 'utf8');
  const guarded = page.match(/getAppAuthAccessTokenForSession\(session\.epoch, session\.sid\)/g) || [];
  assert.ok(guarded.length >= 2, '两处令牌读取都应使用会话校验');
  assert.doesNotMatch(page, /token = \(await storage\.getAppAuthAccessToken\(\)\)\.trim\(\)/,
    '不应再直接读取当前账号令牌');
});
