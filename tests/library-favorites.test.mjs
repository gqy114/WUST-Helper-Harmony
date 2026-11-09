// 图书馆服务端收藏：接口调用、离线队列与按学号隔离的本地缓存。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

function apiContext() {
  const calls = [];
  const replies = { get: { data: {} }, post: { data: {} } };
  const context = createContext({ console, JSON, Array, String });
  const http = new SyntheticModule(['HttpRequest'], function () {
    this.setExport('HttpRequest', {
      request: async () => ({ data: {} }),
      get: async (url, headers) => {
        calls.push({ method: 'GET', url, headers });
        return replies.get;
      },
      postRawJson: async (url, body, headers) => {
        calls.push({ method: 'POST', url, body, headers });
        return replies.post;
      },
    });
  }, { context });
  const model = new SyntheticModule(['LibraryLoanItem'], function () {
    this.setExport('LibraryLoanItem', undefined);
  }, { context });
  return { context, calls, replies, http, model };
}

async function loadApi(token = 'wh_at_demo', replies = {}) {
  const ctx = apiContext();
  const storage = {
    getAppAuthAccessToken: async () => token,
  };
  const app = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => storage });
  }, { context: ctx.context });
  const code = stripTypeScriptTypes(await source(`${root}/net/LibraryApi.ets`), { mode: 'transform' });
  const mod = new SourceTextModule(code, { context: ctx.context });
  await mod.link((name) => {
    if (name === './HttpRequest') return ctx.http;
    if (name === '../model/LibraryLoanModel') return ctx.model;
    if (name === '../store/AppStorage') return app;
    throw new Error(`Unexpected import: ${name}`);
  });
  await mod.evaluate();
  if (replies.get) ctx.replies.get = replies.get;
  if (replies.post) ctx.replies.post = replies.post;
  return { api: mod.namespace.LibraryApi, calls: ctx.calls, replies: ctx.replies };
}

test('服务端收藏：带登录令牌请求 /api/v1/library/favorites', async () => {
  const { api, calls, replies } = await loadApi();
  replies.get = { data: { code: 200, message: 'Success', data: { items: [{ kind: 'article', itemId: 12 }] } } };
  const list = await api.listFavorites();
  assert.equal(calls[0].method, 'GET');
  assert.match(calls[0].url, /\/api\/v1\/library\/favorites$/);
  assert.equal(calls[0].headers.Authorization, 'Bearer wh_at_demo');
  assert.deepEqual(Array.from(list, (item) => item.itemId), [12]);
});

test('服务端收藏：未登录不发请求并回退本机缓存', async () => {
  const { api, calls } = await loadApi('');
  assert.equal(await api.listFavorites(), null);
  assert.equal(await api.addFavorite({ kind: 'article', itemId: 1, title: 't', link: '', tag: '' }), false);
  assert.equal(calls.length, 0);
});

test('服务端收藏：新增与删除走 POST，itemId 保持数字', async () => {
  const { api, calls, replies } = await loadApi();
  replies.post = { data: { code: 200, message: 'Success', data: true } };
  assert.equal(await api.addFavorite({ kind: 'resource', itemId: 9, title: '知网', link: 'https://x', tag: '资源' }), true);
  assert.equal(calls[0].method, 'POST');
  assert.match(calls[0].url, /\/api\/v1\/library\/favorites$/);
  const body = JSON.parse(calls[0].body);
  assert.deepEqual(body, { kind: 'resource', itemId: 9, title: '知网', link: 'https://x', tag: '资源' });
  assert.equal(typeof body.itemId, 'number');

  assert.equal(await api.removeFavorite('resource', 9), true);
  assert.match(calls[1].url, /\/api\/v1\/library\/favorites\/remove$/);
  assert.deepEqual(JSON.parse(calls[1].body), { kind: 'resource', itemId: 9 });
});

test('服务端收藏：401 视为接口不可用而不是空列表', async () => {
  const { api, replies } = await loadApi();
  replies.get = { data: { code: 401, message: 'Unauthorized', data: null } };
  assert.equal(await api.listFavorites(), null);
});

async function loadFavorites(options = {}) {
  const {
    initialRaw = '[]', sid = '', serverOk = true, remoteItems = [],
  } = options;
  const store = new Map();
  const key = sid ? `libraryFavorites_${sid}` : 'libraryFavorites';
  store.set(key, JSON.stringify(JSON.stringify(initialRaw)));
  const storage = {
    getStudentId: async () => sid,
    getSettingString: async (name, def) => {
      const raw = store.has(name) ? store.get(name) : JSON.stringify(def);
      try {
        return JSON.parse(raw);
      } catch {
        return def;
      }
    },
    setSettingString: async (name, value) => { store.set(name, JSON.stringify(value)); },
  };
  const calls = [];
  const server = {
    addFavorite: async (item) => { calls.push({ op: 'add', item }); return serverOk; },
    removeFavorite: async (kind, id) => { calls.push({ op: 'remove', kind, id }); return serverOk; },
    listFavorites: async () => (serverOk ? remoteItems.map((item) => ({ ...item })) : null),
  };
  const context = createContext({ console, JSON, Array, String });
  const app = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => storage });
  }, { context });
  const libraryApi = new SyntheticModule(['LibraryApi', 'LibraryFavoriteEntry'], function () {
    this.setExport('LibraryApi', server);
    this.setExport('LibraryFavoriteEntry', undefined);
  }, { context });
  const code = stripTypeScriptTypes(await source(`${root}/store/LibraryFavorites.ets`), { mode: 'transform' });
  const mod = new SourceTextModule(code, { context });
  await mod.link((name) => {
    if (name === './AppStorage') return app;
    if (name === '../net/LibraryApi') return libraryApi;
    throw new Error(`Unexpected import: ${name}`);
  });
  await mod.evaluate();
  return { favorites: mod.namespace.LibraryFavorites.getInstance(), store, calls };
}

test('在线收藏：写入服务端并记录同步成功', async () => {
  const { favorites, calls } = await loadFavorites({ remoteItems: [] });
  const item = { kind: 'article', id: 12, title: '认识一下吧', link: 'https://a', tag: '活动' };
  assert.equal(await favorites.toggle(item), true);
  assert.equal(calls[0].op, 'add');
  assert.equal(calls[0].item.itemId, 12);
  assert.equal(favorites.isLastToggleSynced(), true);
  assert.equal(favorites.isSynced(), true);
  assert.deepEqual(Array.from(await favorites.list(), (value) => value.id), [12]);
});

test('离线收藏：本机可用、进入待同步队列', async () => {
  const { favorites, calls } = await loadFavorites({ serverOk: false });
  const item = { kind: 'article', id: 7, title: '断网收藏', link: 'https://a', tag: '通知' };
  assert.equal(await favorites.toggle(item), true);
  assert.equal(favorites.isLastToggleSynced(), false);
  assert.equal(favorites.has('article', 7), true);
  assert.equal(calls.length, 1);
});

test('离线期间的操作会在联网后补发', async () => {
  const offline = await loadFavorites({ serverOk: false });
  await offline.favorites.toggle({ kind: 'article', id: 7, title: '断网收藏', link: 'https://a', tag: '通知' });
  assert.equal(offline.favorites.has('article', 7), true);
});

test('联网后拉取云端列表覆盖本机', async () => {
  const online = await loadFavorites({
    remoteItems: [{ kind: 'resource', itemId: 3, title: '知网', link: 'https://x', tag: '资源' }],
    initialRaw: [{ kind: 'article', id: 7, title: '旧缓存', link: 'https://a', tag: '通知' }],
  });
  assert.equal(await online.favorites.syncFromServer(), true);
  assert.equal(online.favorites.isSynced(), true);
  assert.deepEqual(Array.from(await online.favorites.list(), (item) => item.kind), ['resource']);
});

test('服务端不可用时不覆盖本机收藏', async () => {
  const offline = await loadFavorites({
    serverOk: false,
    initialRaw: [{ kind: 'article', id: 7, title: '旧缓存', link: 'https://a', tag: '通知' }],
  });
  assert.equal(await offline.favorites.syncFromServer(), false);
  assert.equal(offline.favorites.isSynced(), false);
  assert.deepEqual(Array.from(await offline.favorites.list(), (item) => item.id), [7]);
});

test('本机缓存按学号隔离，不串账号', async () => {
  const { favorites } = await loadFavorites({
    sid: '2024001',
    initialRaw: [{ kind: 'article', id: 5, title: '我的', link: 'https://a', tag: '通知' }],
  });
  assert.deepEqual(Array.from(await favorites.list(), (item) => item.id), [5]);
});

test('未按学号隔离的旧缓存会迁移到当前账号', async () => {
  const store = new Map();
  store.set('libraryFavorites', JSON.stringify(JSON.stringify([
    { kind: 'article', id: 2, title: '旧收藏', link: 'https://a', tag: '通知' },
  ])));
  const storage = {
    getStudentId: async () => '2024002',
    getSettingString: async (name, def) => {
      const raw = store.has(name) ? store.get(name) : JSON.stringify(def);
      try {
        return JSON.parse(raw);
      } catch {
        return def;
      }
    },
    setSettingString: async (name, value) => { store.set(name, JSON.stringify(value)); },
  };
  const context = createContext({ console, JSON, Array, String });
  const app = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => storage });
  }, { context });
  const libraryApi = new SyntheticModule(['LibraryApi', 'LibraryFavoriteEntry'], function () {
    this.setExport('LibraryApi', {
      addFavorite: async () => false,
      removeFavorite: async () => false,
      listFavorites: async () => null,
    });
    this.setExport('LibraryFavoriteEntry', undefined);
  }, { context });
  const code = stripTypeScriptTypes(await source(`${root}/store/LibraryFavorites.ets`), { mode: 'transform' });
  const mod = new SourceTextModule(code, { context });
  await mod.link((name) => {
    if (name === './AppStorage') return app;
    if (name === '../net/LibraryApi') return libraryApi;
    throw new Error(`Unexpected import: ${name}`);
  });
  await mod.evaluate();
  const favorites = mod.namespace.LibraryFavorites.getInstance();
  assert.deepEqual(Array.from(await favorites.list(), (item) => item.id), [2]);
  assert.ok(store.has('libraryFavorites_2024002'), '旧缓存应迁移到按学号的键');
});
