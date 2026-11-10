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
  const ark = new SyntheticModule(['preferences'], function () { this.setExport('preferences', {}); }, { context: ctx });
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
  return { storage, db };
}

test('老用户升级后头像和昵称各自迁移一次，两个都能读到', async () => {
  const { storage, db } = await loadStorage();
  await storage.setStudentId('A');
  db.set('avatarUrl', JSON.stringify('https://example.invalid/old-avatar'));
  db.set('userName', JSON.stringify('旧昵称'));

  assert.equal(await storage.getAvatarUrl(), 'https://example.invalid/old-avatar');
  assert.equal(await storage.getUserName(), '旧昵称', '昵称不能被头像的迁移标记挡住');
  assert.equal(db.get('avatarUrl_A'), JSON.stringify('https://example.invalid/old-avatar'));
  assert.equal(db.get('userName_A'), JSON.stringify('旧昵称'));
});

test('旧数据只归属于首个账号，切到新账号后读不到', async () => {
  const { storage, db } = await loadStorage();
  await storage.setStudentId('A');
  db.set('avatarUrl', JSON.stringify('https://example.invalid/old-avatar'));
  db.set('userName', JSON.stringify('旧昵称'));
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
