import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

async function createStorage() {
  const context = createContext({ console, JSON, Date, Number, Array, Promise, Map, Set });
  const ark = new SyntheticModule(['preferences'], function () { this.setExport('preferences', {}); }, { context });
  const ability = new SyntheticModule(['common'], function () { this.setExport('common', {}); }, { context });
  const model = new SyntheticModule(['ScheduleSettings','DEFAULT_SETTINGS','CourseArchive','CourseData'], function () {
    for (const key of ['ScheduleSettings','DEFAULT_SETTINGS','CourseArchive','CourseData']) this.setExport(key, key === 'DEFAULT_SETTINGS' ? {} : undefined);
  }, { context });
  const source = await readFile(new URL('../entry/src/main/ets/store/AppStorage.ts', import.meta.url), 'utf8');
  const module = new SourceTextModule(stripTypeScriptTypes(source, { mode: 'transform' }), { context });
  await module.link(name => name === '@kit.ArkData' ? ark : name === '@kit.AbilityKit' ? ability : model);
  await module.evaluate();
  const storage = module.namespace.AppStorage.getInstance();
  const db = new Map();
  storage.kvStore = { get: async (key, fallback) => db.has(key) ? db.get(key) : fallback,
    put: async (key, value) => { db.set(key, value); }, flush: async () => {} };
  return storage;
}

test('refreshing the same account preserves existing app authentication', async () => {
  const storage = await createStorage();
  await storage.setStudentId('A');
  await storage.setAppAuthAccessToken('token-A');
  await storage.setAppAuthRefreshToken('refresh-A');
  await storage.setStudentId('A');
  assert.equal(await storage.getAppAuthAccessToken(), 'token-A');
  assert.equal(await storage.getAppAuthRefreshToken(), 'refresh-A');
});

test('same student ID with a changed student type does not retain the old app token', async () => {
  const storage = await createStorage();
  await storage.setIsGraduate(false);
  await storage.setStudentId('A');
  await storage.setAppAuthAccessToken('undergraduate-token');
  await storage.setIsGraduate(true);
  await storage.setStudentId('A');
  assert.equal(await storage.getAppAuthAccessToken(), '');
});

test('a student type change during an account write remains pending for the next account update', async () => {
  const storage = await createStorage();
  await storage.setStudentId('A');
  await storage.setAppAuthAccessToken('old-token');
  let signal, release;
  const blocked = new Promise(resolve => { signal = resolve; });
  const resume = new Promise(resolve => { release = resolve; });
  const put = storage.kvStore.put;
  let shouldPause = true;
  storage.kvStore.put = async (key, value) => {
    if (shouldPause && key === 'studentId' && value === JSON.stringify('A')) {
      shouldPause = false; signal(); await resume;
    }
    await put(key, value);
  };
  const sameAccountUpdate = storage.setStudentId('A');
  await blocked;
  await storage.setIsGraduate(true);
  release(); await sameAccountUpdate;
  await storage.setStudentId('A');
  assert.equal(await storage.getAppAuthAccessToken(), '');
});

test('a restore that starts while switching accounts cannot leave the previous account token', async () => {
  const storage = await createStorage();
  await storage.setStudentId('A');
  await storage.setAppAuthAccessToken('old-A');
  let paused, release;
  const blocked = new Promise(resolve => { paused = resolve; });
  const resume = new Promise(resolve => { release = resolve; });
  const put = storage.kvStore.put;
  let shouldPause = true;
  storage.kvStore.put = async (key, value) => {
    if (shouldPause && key === 'appAuthRefreshToken' && value === JSON.stringify('')) {
      shouldPause = false; paused(); await resume;
    }
    await put(key, value);
  };
  const switching = storage.setStudentId('B');
  await blocked;
  const epoch = storage.getSessionEpoch();
  const saved = await storage.setAppAuthTokensIfSession(epoch, 'A', 'late-A', 'late-refresh-A', 1, 2);
  release();
  await switching;
  assert.equal(saved, false);
  assert.equal(await storage.getStudentId(), 'B');
  assert.equal(await storage.getAppAuthAccessToken(), '');
  assert.equal(await storage.getAppAuthRefreshToken(), '');
});
