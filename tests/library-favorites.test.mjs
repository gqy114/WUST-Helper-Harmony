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
    initialRaw = '[]', sid = '', serverOk = true, remoteItems = [], store: sharedStore, sidRef,
    alreadySynced = false, listDelayMs = 0, addDelayMs = 0, legacyRaw = null,
  } = options;
  const store = sharedStore || new Map();
  const currentSid = () => (sidRef ? sidRef.sid : sid);
  const key = currentSid() ? `libraryFavorites_${currentSid()}` : 'libraryFavorites';
  if (!sharedStore) {
    store.set(key, JSON.stringify(JSON.stringify(initialRaw)));
    if (alreadySynced) {
      store.set(`${key}_synced`, JSON.stringify(true));
    }
  }
  if (legacyRaw !== null) {
    store.set('libraryFavorites', JSON.stringify(JSON.stringify(legacyRaw)));
  }
  const storage = {
    getStudentId: async () => currentSid(),
    getSettingString: async (name, def) => {
      const raw = store.has(name) ? store.get(name) : JSON.stringify(def);
      try {
        return JSON.parse(raw);
      } catch {
        return def;
      }
    },
    setSettingString: async (name, value) => { store.set(name, JSON.stringify(value)); },
    getSettingBool: async (name, def) => {
      const raw = store.has(name) ? store.get(name) : JSON.stringify(def);
      try {
        return JSON.parse(raw) === true;
      } catch {
        return def;
      }
    },
    setSettingBool: async (name, value) => { store.set(name, JSON.stringify(value)); },
  };
  const calls = [];
  const serverItems = remoteItems.map((item) => ({ ...item }));
  const server = {
    addFavorite: async (item) => {
      calls.push({ op: 'add', item, sid: currentSid() });
      if (addDelayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, addDelayMs));
      }
      if (!serverOk) return false;
      if (!serverItems.some((value) => value.kind === item.kind && value.itemId === item.itemId)) {
        serverItems.push({ ...item });
      }
      return true;
    },
    removeFavorite: async (kind, id) => {
      calls.push({ op: 'remove', kind, id });
      if (!serverOk) return false;
      const index = serverItems.findIndex((value) => value.kind === kind && value.itemId === id);
      if (index >= 0) serverItems.splice(index, 1);
      return true;
    },
    listFavorites: async () => {
      if (listDelayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, listDelayMs));
      }
      return serverOk ? serverItems.map((item) => ({ ...item })) : null;
    },
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

test('离线收藏在重启后仍然补发，不会丢失', async () => {
  const store = new Map();
  const sidRef = { sid: '2024001' };
  const first = await loadFavorites({ sidRef, store, serverOk: false });
  await first.favorites.toggle({ kind: 'article', id: 9, title: '离线收藏', link: 'https://a', tag: '通知' });
  const pending = JSON.parse(JSON.parse(store.get('libraryFavorites_2024001_pending')));
  assert.equal(pending.adds.length, 1, '待同步队列应写入 preferences');

  // 重启：新的模块实例从磁盘读回收藏与待同步队列，此时网络已恢复。
  const second = await loadFavorites({ sidRef, store, serverOk: true });
  assert.equal(await second.favorites.syncFromServer(), true);
  assert.deepEqual(second.calls.filter((call) => call.op === 'add').map((call) => call.item.itemId), [9]);
  assert.deepEqual(Array.from(await second.favorites.list(), (item) => item.id), [9], '同步后收藏仍在');
  assert.equal(JSON.parse(second.store.get('libraryFavorites_2024001_pending')), '',
    '补发成功后清空队列');
});

test('切换账号后不会看到上一个账号的收藏', async () => {
  const sidRef = { sid: '2024001' };
  const store = new Map();
  const loaded = await loadFavorites({ sidRef, store });
  await loaded.favorites.toggle({ kind: 'article', id: 5, title: 'A 的收藏', link: 'https://a', tag: '通知' });
  assert.deepEqual(Array.from(await loaded.favorites.list(), (item) => item.id), [5]);

  store.set('libraryFavorites_2024002',
    JSON.stringify(JSON.stringify([{ kind: 'resource', id: 3, title: 'B 的收藏', link: 'https://x', tag: '资源' }])));
  sidRef.sid = '2024002';

  const list = await loaded.favorites.list();
  assert.deepEqual(Array.from(list, (item) => item.id), [3], '只应看到新账号的收藏');
  assert.equal(loaded.favorites.has('article', 5), false, '上一个账号的收藏不能出现');
  assert.deepEqual(JSON.parse(JSON.parse(store.get('libraryFavorites_2024001'))),
    [{ kind: 'article', id: 5, title: 'A 的收藏', link: 'https://a', tag: '通知' }],
    'A 的收藏要保留在自己的 key 里');
});

test('联网后拉取云端列表覆盖本机', async () => {
  const online = await loadFavorites({
    remoteItems: [{ kind: 'resource', itemId: 3, title: '知网', link: 'https://x', tag: '资源' }],
    initialRaw: [{ kind: 'article', id: 7, title: '旧缓存', link: 'https://a', tag: '通知' }],
    alreadySynced: true,
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

test('离线收藏后又取消，不会留下待补发操作', async () => {
  const store = new Map();
  const loaded = await loadFavorites({ sid: '2024003', store, serverOk: false });
  const item = { kind: 'article', id: 11, title: '临时收藏', link: '', tag: '通知' };
  assert.equal(await loaded.favorites.toggle(item), true);
  assert.equal(await loaded.favorites.toggle(item), false);
  assert.equal(JSON.parse(loaded.store.get('libraryFavorites_2024003_pending')), '', '待补发队列应为空');
  assert.deepEqual(Array.from(await loaded.favorites.list()), []);
});

test('本机缓存按学号隔离，不串账号', async () => {
  const { favorites } = await loadFavorites({
    sid: '2024001',
    initialRaw: [{ kind: 'article', id: 5, title: '我的', link: 'https://a', tag: '通知' }],
  });
  assert.deepEqual(Array.from(await favorites.list(), (item) => item.id), [5]);
});

test('旧全局收藏迁移给首个账号，首次同步先上传不会被清空', async () => {
  const legacy = [{ kind: 'article', id: 2, title: '旧收藏', link: 'https://a', tag: '通知' }];
  const store = new Map();
  const loaded = await loadFavorites({ sid: '2024002', store, legacyRaw: legacy });
  assert.deepEqual(Array.from(await loaded.favorites.list(), (item) => item.id), [2]);

  assert.equal(await loaded.favorites.syncFromServer(), true);
  assert.deepEqual(loaded.calls.filter((call) => call.op === 'add').map((call) => call.item.itemId), [2],
    '旧收藏应补传到服务端');
  assert.deepEqual(Array.from(await loaded.favorites.list(), (item) => item.id), [2], '同步后收藏仍在');
  assert.equal(JSON.parse(store.get('libraryFavoritesMigrationOwner')), '2024002', '旧收藏归属首个账号');
});

test('旧全局收藏不会被第二个账号再次认领', async () => {
  const legacy = [{ kind: 'article', id: 2, title: '旧收藏', link: 'https://a', tag: '通知' }];
  const store = new Map();
  const first = await loadFavorites({ sid: '2024001', store, legacyRaw: legacy });
  assert.deepEqual(Array.from(await first.favorites.list(), (item) => item.id), [2]);

  const second = await loadFavorites({ sid: '2024002', store });
  assert.deepEqual(Array.from(await second.favorites.list()), [], 'B 不能继承 A 的旧收藏');

  const again = await loadFavorites({ sid: '2024001', store });
  assert.deepEqual(Array.from(await again.favorites.list(), (item) => item.id), [2],
    'A 重新登录仍能看到自己的收藏');
});

test('补发过程中切换账号，剩余收藏不会发到新账号', async () => {
  const store = new Map();
  const sidRef = { sid: '2024001' };
  const offline = await loadFavorites({ sidRef, store, serverOk: false });
  const first = { kind: 'article', id: 1, title: 'A1', link: 'https://a', tag: '通知' };
  const second = { kind: 'article', id: 2, title: 'A2', link: 'https://b', tag: '通知' };
  await offline.favorites.toggle(first);
  await offline.favorites.toggle(second);

  // 重启后网络恢复，但补发请求很慢：第一条还没返回时切换账号。
  const online = await loadFavorites({ sidRef, store, serverOk: true, addDelayMs: 30 });
  const syncing = online.favorites.syncFromServer();
  await new Promise((resolve) => setTimeout(resolve, 5));
  sidRef.sid = '2024002';

  assert.equal(await syncing, false, '切号后应中止同步');
  const addCalls = online.calls.filter((call) => call.op === 'add');
  assert.equal(addCalls.length, 1, '切号后不能再补发 A 的剩余收藏');
  assert.ok(addCalls.every((call) => call.sid === '2024001'), '请求必须在 A 的登录态下发出');
  const pendingA = JSON.parse(JSON.parse(online.store.get('libraryFavorites_2024001_pending')));
  assert.deepEqual(pendingA.adds.map((item) => item.id).sort((a, b) => a - b), [1, 2],
    '未确认的补发仍留在 A 自己的队列里');
  assert.equal(online.store.has('libraryFavorites_2024002_pending'), false,
    'B 不应产生 A 的待补发数据');
});

test('同步过程中切换账号，旧账号结果不会写进新账号', async () => {
  const sidRef = { sid: '2024001' };
  const store = new Map();
  const loaded = await loadFavorites({
    sidRef, store, listDelayMs: 30,
    initialRaw: [{ kind: 'article', id: 5, title: 'A 的收藏', link: 'https://a', tag: '通知' }],
  });
  const syncing = loaded.favorites.syncFromServer();
  await new Promise((resolve) => setTimeout(resolve, 5));
  store.set('libraryFavorites_2024002',
    JSON.stringify(JSON.stringify([{ kind: 'resource', id: 3, title: 'B 的收藏', link: 'https://x', tag: '资源' }])));
  sidRef.sid = '2024002';

  const result = await syncing;
  assert.equal(result, false, '账号已切换，旧同步应放弃');
  assert.deepEqual(Array.from(await loaded.favorites.list(), (item) => item.id), [3], 'B 只看到自己的收藏');
  assert.deepEqual(JSON.parse(JSON.parse(store.get('libraryFavorites_2024002'))),
    [{ kind: 'resource', id: 3, title: 'B 的收藏', link: 'https://x', tag: '资源' }],
    '旧账号数据不能覆盖新账号');
});
