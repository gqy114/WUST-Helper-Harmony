// 教务会话并发去重测试：两个调用同时刷新时只允许发出一次登录请求。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });

async function createSession() {
  const calls = [];
  const context = createContext({ console });
  const storage = new SyntheticModule(['AppStorage'], function () {
    const instance = {
      getToken: async () => '',
      getStudentId: async () => { await new Promise((r) => setTimeout(r, 5)); return '20240001'; },
      getPassword: async () => { await new Promise((r) => setTimeout(r, 5)); return 'pwd'; },
      getIsGraduate: async () => false,
      setIsLogin: async () => {},
    };
    this.setExport('AppStorage', { getInstance: () => instance });
  });
  const api = new SyntheticModule(['ApiService'], function () {
    this.setExport('ApiService', {
      refreshUndergradToken: async () => {
        calls.push('undergrad');
        await new Promise((r) => setTimeout(r, 20));
        return true;
      },
      refreshGraduateToken: async () => {
        calls.push('graduate');
        await new Promise((r) => setTimeout(r, 20));
        return true;
      },
    });
  });
  const session = new SourceTextModule(transform(await source('../entry/src/main/ets/service/TeachingSessionService.ts')));
  await session.link((name) => {
    if (name === '../net/ApiService') return api;
    if (name === '../store/AppStorage') return storage;
    throw new Error(`Unexpected import: ${name}`);
  });
  await session.evaluate();
  return { calls, service: session.namespace.TeachingSessionService, context };
}

test('并发 ensureSession 只发出一次登录请求', async () => {
  const { calls, service } = await createSession();
  const results = await Promise.all([service.ensureSession(true), service.ensureSession(true)]);
  assert.deepEqual(results, [true, true]);
  assert.equal(calls.length, 1, `登录请求次数=${calls.length}`);
});
