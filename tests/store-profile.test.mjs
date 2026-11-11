// 账号资料分账号存储：旧全局数据迁移只发生一次，且头像/昵称各自迁移。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../entry/src/main/ets/', import.meta.url));

async function loadStorage() {
  const ctx = createContext({ console, JSON, Date, Number, Array, Promise, Map, Set });
  let currentPreferences;
  const ark = new SyntheticModule(['preferences'], function () {
    this.setExport('preferences', { getPreferences: async () => currentPreferences });
  }, { context: ctx });
  const ability = new SyntheticModule(['common'], function () { this.setExport('common', {}); }, { context: ctx });
  const course = new SyntheticModule(['ScheduleSettings', 'DEFAULT_SETTINGS', 'CourseArchive', 'CourseData'], function () {
    this.setExport('ScheduleSettings', undefined);
    this.setExport('DEFAULT_SETTINGS', {});
    this.setExport('CourseArchive', undefined);
    this.setExport('CourseData', undefined);
  }, { context: ctx });
  const code = await readFile(`${root}/store/AppStorage.ts`, 'utf8');
  const mod = new SourceTextModule(stripTypeScriptTypes(code, { mode: 'transform' }), { context: ctx });
  await mod.link((name) => name === '@kit.ArkData' ? ark : name === '@kit.AbilityKit' ? ability : course);
  await mod.evaluate();
  const storage = mod.namespace.AppStorage.getInstance();
  const db = new Map();
  storage.kvStore = {
    get: async (key, fallback) => db.has(key) ? db.get(key) : fallback,
    put: async (key, value) => { db.set(key, value); },
    flush: async () => {},
  };
  currentPreferences = storage.kvStore;
  return { storage, db };
}

test('老用户升级后头像和昵称各自迁移一次，两个都能读到', async () => {
  const { storage, db } = await loadStorage();
  db.set('avatarUrl', JSON.stringify('https://example.invalid/old-avatar'));
  db.set('userName', JSON.stringify('旧昵称'));
  await storage.setStudentId('A');

  assert.equal(await storage.getAvatarUrl(), 'https://example.invalid/old-avatar');
  assert.equal(await storage.getUserName(), '旧昵称', '昵称不能被头像的迁移标记挡住');
  assert.equal(db.get('avatarUrl_A'), JSON.stringify('https://example.invalid/old-avatar'));
  assert.equal(db.get('userName_A'), JSON.stringify('旧昵称'));
});

test('旧数据只归属于首个账号，切到新账号后读不到', async () => {
  const { storage, db } = await loadStorage();
  db.set('avatarUrl', JSON.stringify('https://example.invalid/old-avatar'));
  db.set('userName', JSON.stringify('旧昵称'));
  await storage.setStudentId('A');
  await storage.getAvatarUrl();
  await storage.getUserName();

  await storage.setStudentId('B');
  assert.equal(await storage.getAvatarUrl(), '');
  assert.equal(await storage.getUserName(), '');
});

test('写入按账号分 key，旧账号写入不影响新账号', async () => {
  const { storage } = await loadStorage();
  await storage.setStudentId('A');
  const epochA = storage.getSessionEpoch();
  await storage.setStudentId('B');
  await storage.setUserName('B 的昵称');

  const saved = await storage.setUserNameForAccount(epochA, 'A', 'A 的昵称');
  assert.equal(saved, false, '切号后旧账号的排队写入应被丢弃');
  assert.equal(await storage.getUserName(), 'B 的昵称');
});


test('首个账号未打开资料页就切号：旧头像和昵称不会被新账号认领', async () => {
  const { storage, db } = await loadStorage();
  db.set('avatarUrl', JSON.stringify('https://example.invalid/A-old'));
  db.set('userName', JSON.stringify('A-old-name'));
  await storage.setStudentId('A');
  await storage.setStudentId('B');
  assert.equal(await storage.getAvatarUrl(), '');
  assert.equal(await storage.getUserName(), '');
  await storage.setStudentId('A');
  assert.equal(await storage.getAvatarUrl(), 'https://example.invalid/A-old');
  assert.equal(await storage.getUserName(), 'A-old-name');
});

test('首个账号已有分账号资料时，保留新资料并阻止其他账号认领旧全局资料', async () => {
  const { storage, db } = await loadStorage();
  db.set('avatarUrl', JSON.stringify('https://example.invalid/A-old'));
  db.set('userName', JSON.stringify('A-old-name'));
  db.set('avatarUrl_A', JSON.stringify('https://example.invalid/A-new'));
  db.set('userName_A', JSON.stringify('A-new-name'));
  await storage.setStudentId('A');
  assert.equal(await storage.getAvatarUrl(), 'https://example.invalid/A-new');
  assert.equal(await storage.getUserName(), 'A-new-name');
  await storage.setStudentId('B');
  assert.equal(await storage.getAvatarUrl(), '');
  assert.equal(await storage.getUserName(), '');
});

test('未登录时不认领旧资料，后续首个登录账号可以认领', async () => {
  const { storage, db } = await loadStorage();
  db.set('userName', JSON.stringify('legacy-name'));
  await storage.setStudentId('');
  assert.equal(db.has('profileScopedMigrated_userName'), false);
  await storage.setStudentId('A');
  assert.equal(await storage.getUserName(), 'legacy-name');
});

test('升级后已有登录账号时，初始化认领资料，即使不打开资料页再切号也不泄漏', async () => {
  const { storage, db } = await loadStorage();
  db.set('studentId', JSON.stringify('A'));
  db.set('avatarUrl', JSON.stringify('https://example.invalid/A-old'));
  db.set('userName', JSON.stringify('A-old-name'));
  await storage.init({});
  await storage.setStudentId('B');
  assert.equal(await storage.getAvatarUrl(), '');
  assert.equal(await storage.getUserName(), '');
  await storage.setStudentId('A');
  assert.equal(await storage.getAvatarUrl(), 'https://example.invalid/A-old');
  assert.equal(await storage.getUserName(), 'A-old-name');
});

test('写昵称期间切号不会把旧输入写给新账号', async () => {
  const { storage } = await loadStorage();
  await storage.setStudentId('A');
  const originalGet = storage.kvStore.get;
  let pause = true;
  let signal, release;
  const waiting = new Promise(resolve => { signal = resolve; });
  const resume = new Promise(resolve => { release = resolve; });
  storage.kvStore.get = async (key, fallback) => {
    const result = await originalGet(key, fallback);
    if (key === 'studentId' && pause) {
      pause = false;
      signal();
      await resume;
    }
    return result;
  };
  const write = storage.setUserName('A-new-name');
  await waiting;
  await storage.setStudentId('B');
  release();
  await write;
  assert.equal(await storage.getUserName(), '');
});

test('研究生登录先保存当前学号，再访问按账号存储的昵称', async () => {
  const code = await readFile(`${root}/pages/login/LoginPage.ets`, 'utf8');
  const start = code.indexOf('const gdata = resp.data as GraduateLoginDataContent;');
  const end = code.indexOf("console.info(TAG, 'graduate login, credentials saved');", start);
  assert.ok(start >= 0 && end > start);
  const block = code.slice(start, end);
  assert.ok(block.indexOf('this.saveLoginData(') < block.indexOf('s.getUserName()'));
  assert.ok(block.indexOf('s.getUserName()') >= 0);
});
