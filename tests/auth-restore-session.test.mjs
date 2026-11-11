// 认证恢复期间切号：旧请求的令牌/头像不能写到新账号。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../entry/src/main/ets/', import.meta.url));

async function loadStorage() {
  const ctx = createContext({ console, JSON, Date, Number, Array, Promise, Map, Set });
  const ark = new SyntheticModule(['preferences'], function () {
    this.setExport('preferences', {});
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
  return { storage, db };
}

test('认证结果返回前切号：旧令牌被丢弃，新账号不会拿到旧令牌', async () => {
  const { storage } = await loadStorage();
  await storage.setStudentId('A');
  const epochA = storage.getSessionEpoch();
  await storage.setStudentId('B');

  const saved = await storage.setAppAuthTokensIfSession(epochA, 'A', 'token-A', 'refresh-A', 1, 2);
  assert.equal(saved, false, '切号后的旧认证写入应被拒绝');
  assert.equal(await storage.getAppAuthAccessToken(), '', '新账号不能读到旧账号令牌');
});

test('ApiService 认证恢复使用会话校验写入，头像按发起账号保存', async () => {
  const api = await readFile(`${root}/net/ApiService.ts`, 'utf8');
  assert.match(api, /const sessionEpoch = storage\.getSessionEpoch\(\);/, '没有固定认证恢复的会话');
  assert.match(api, /storage\.setAppAuthTokensIfSession\(sessionEpoch, studentId/, '令牌写入没有会话校验');
  assert.match(api, /account changed during auth restore, tokens discarded/, '切号后没有丢弃认证结果');
  assert.match(api, /setAvatarUrlForAccount\(sessionEpoch, studentId/, '头像没有按发起账号写入');
});

test('切号前的认证写入在新学号落盘前完成，切号后不会残留旧令牌', async () => {
  const { storage, db } = await loadStorage();
  await storage.setStudentId('A');
  const epochA = storage.getSessionEpoch();

  let release;
  const gate = new Promise(resolve => { release = resolve; });
  let paused = false;
  const originalPut = storage.kvStore.put;
  storage.kvStore.put = async (key, value) => {
    if (!paused && key === 'appAuthAccessToken' && value === JSON.stringify('token-A')) {
      paused = true;
      await gate;
    }
    await originalPut(key, value);
  };

  const restore = storage.setAppAuthTokensIfSession(epochA, 'A', 'token-A', 'refresh-A', 1, 2);
  await new Promise(resolve => setTimeout(resolve, 20));
  const switching = storage.setStudentId('B');
  await new Promise(resolve => setTimeout(resolve, 20));
  release();

  const saved = await restore;
  await switching;
  assert.equal(saved, true, '切号前已开始的写入应完成，不应被误判');
  assert.equal(await storage.getStudentId(), 'B');
  assert.equal(await storage.getAppAuthAccessToken(), '', '切号必须清掉旧账号令牌');
  assert.equal(db.get('studentId'), JSON.stringify('B'));
});
