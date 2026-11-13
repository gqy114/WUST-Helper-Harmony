// 图书馆收藏：产品约定只存本机（内容来自服务端，收藏记录不同步）。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, unlink } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const root = '../entry/src/main/ets';
const source = async (path) => readFile(new URL(`${root}/${path}`, import.meta.url), 'utf8');
const favorite = (id, title = `test-${id}`) => ({
  kind: 'article', id, title, link: 'https://example.com', tag: '活动'
});

/** 用内存 Map 模拟 preferences：真实实现里 setSettingString 会再包一层 JSON。 */
async function makeStore(db = new Map(), options = {}) {
  const code = stripTypeScriptTypes(await source('store/LibraryFavorites.ets'), { mode: 'transform' });
  const state = { sid: options.sid === undefined ? '2024001' : options.sid };
  const storage = {
    getStudentId: async () => state.sid,
    getSettingString: async (key, def = '') => {
      if (options.delayedGet) {
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
      const raw = db.has(key) ? db.get(key) : JSON.stringify(def);
      try {
        return JSON.parse(raw);
      } catch {
        return def;
      }
    },
    getSettingBool: async (key, def = false) => {
      const raw = db.has(key) ? db.get(key) : JSON.stringify(def);
      try {
        return JSON.parse(raw) === true;
      } catch {
        return def;
      }
    },
    setSettingBool: async (key, value) => { db.set(key, JSON.stringify(value)); },
    setSettingString: async (key, value) => { db.set(key, JSON.stringify(value)); },
  };
  const context = createContext({ console, JSON, Array });
  const app = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => storage });
  }, { context });
  const mod = new SourceTextModule(code, { context });
  await mod.link((name) => {
    if (name === './AppStorage') return app;
    throw new Error(`Unexpected import: ${name}`);
  });
  await mod.evaluate();
  return { favorites: mod.namespace.LibraryFavorites.getInstance(), db, state };
}

test('收藏只写入本机 preferences，不调用任何网络接口', async () => {
  const { favorites, db } = await makeStore();
  const item = favorite(12, '认识一下吧');

  assert.equal(await favorites.toggle(item), true);
  assert.equal(favorites.has('article', 12), true);
  assert.match(db.get('libraryFavorites_2024001'), /认识一下吧/);

  const store = await source('store/LibraryFavorites.ets');
  assert.doesNotMatch(store, /HttpRequest|LibraryApi|listFavorites|syncFromServer/i, '收藏存储不应包含网络同步逻辑');
  const api = await source('net/LibraryApi.ets');
  assert.doesNotMatch(api, /library\/favorites/, '收藏接口应已移除');
  const page = await source('pages/library/LibraryPage.ets');
  assert.doesNotMatch(page, /syncFromServer|云端同步失败|isLastToggleSynced/, '页面不应再有云端同步逻辑');
});

test('再次点击取消收藏，并从本机删除', async () => {
  const { favorites, db } = await makeStore();
  const item = favorite(12);
  await favorites.toggle(item);
  assert.equal(await favorites.toggle(item), false);
  assert.equal(favorites.has('article', 12), false);
  assert.equal(db.get('libraryFavorites_2024001'), JSON.stringify('[]'));
});

test('收藏按学号隔离，切换账号看不到上一个账号的收藏', async () => {
  const { favorites, state, db } = await makeStore();
  await favorites.toggle(favorite(1));
  assert.equal((await favorites.list()).length, 1);

  state.sid = '2024002';
  assert.deepEqual(Array.from(await favorites.list()), [], '新账号不应看到旧账号收藏');

  state.sid = '2024001';
  assert.deepEqual(Array.from(await favorites.list(), (item) => item.id), [1], '切回原账号收藏仍在');
  assert.ok(db.has('libraryFavorites_2024001'));
});

test('旧版本全局收藏只迁移给第一个账号，之后其他账号为空', async () => {
  const db = new Map([['libraryFavorites', JSON.stringify(JSON.stringify([favorite(3)]))]]);
  const { favorites, state } = await makeStore(db);

  assert.deepEqual(Array.from(await favorites.list(), (item) => item.id), [3]);
  assert.equal(db.get('libraryFavorites'), JSON.stringify('[]'), '迁移后旧 key 应清空');

  state.sid = '2024002';
  assert.deepEqual(Array.from(await favorites.list()), [], '第二个账号不应再次认领旧收藏');
});

test('加载时过滤非法收藏记录', async () => {
  const db = new Map([['libraryFavorites_2024001', JSON.stringify(JSON.stringify([
    favorite(1, '有效'),
    { kind: '', id: 2, title: '无 kind', link: '', tag: '' },
    { kind: 'resource', id: 0, title: '无 id', link: '', tag: '' },
  ]))]]);
  const { favorites } = await makeStore(db);
  assert.deepEqual(Array.from(await favorites.list(), (item) => item.id), [1]);
});

test('未登录时收藏仍然可用，存在旧版全局 key 下', async () => {
  const { favorites, db } = await makeStore(new Map(), { sid: '' });
  await favorites.toggle(favorite(5));
  assert.equal(favorites.has('article', 5), true);
  assert.match(db.get('libraryFavorites'), /test-5/);
});

test('页面刚打开就收藏：并发读取不会覆盖新收藏', async () => {
  const db = new Map([['libraryFavorites_2024001', JSON.stringify(JSON.stringify([favorite(1, '旧收藏')]))]]);
  const { favorites } = await makeStore(db, { delayedGet: true });
  // 不 await list()，直接收藏，模拟“刚打开页面就点收藏”。
  const listing = favorites.list();
  const toggling = favorites.toggle(favorite(2, '新收藏'));
  await listing;
  assert.equal(await toggling, true);
  const saved = JSON.parse(await (async () => {
    const raw = db.get('libraryFavorites_2024001');
    return JSON.parse(raw);
  })());
  assert.deepEqual(saved.map((item) => item.id).sort((a, b) => a - b), [1, 2], '新收藏不能被并发读取覆盖');
});

test('旧数据只迁移一次：已迁移后切换账号不会再认领', async () => {
  const db = new Map([['libraryFavorites', JSON.stringify(JSON.stringify([favorite(3)]))]]);
  const { favorites, state } = await makeStore(db);
  assert.deepEqual(Array.from(await favorites.list(), (item) => item.id), [3]);

  // 手动放回旧 key，模拟历史残留：迁移标记已写完，新账号不应再认领。
  db.set('libraryFavorites', JSON.stringify(JSON.stringify([favorite(9)])));
  state.sid = '2024002';
  assert.deepEqual(Array.from(await favorites.list()), [], '第二个账号不应认领旧数据');
  assert.equal(JSON.parse(db.get('libraryFavoritesMigrationDone')), true, '迁移标记应已写入');
});

test('未登录收藏在重启后仍然存在（不会迁移时被清空）', async () => {
  const db = new Map();
  const first = await makeStore(db, { sid: '' });
  await first.favorites.toggle(favorite(5));

  const second = await makeStore(db, { sid: '' });
  assert.deepEqual(Array.from(await second.favorites.list(), (item) => item.id), [5], '游客收藏不能丢失');
});

test('切号期间完成的收藏只写回原账号，不串到新账号', async () => {
  const db = new Map();
  const { favorites, state } = await makeStore(db, { sid: '2024001', delayedGet: true });
  const toggling = favorites.toggle(favorite(1, 'A 的收藏'));
  await new Promise((resolve) => setTimeout(resolve, 5));
  state.sid = '2024002';
  // 修改应落在发起时所在的 A 账号，B 的 key 不能被创建。
  assert.equal(await toggling, true);
  assert.equal(db.has('libraryFavorites_2024002'), false, 'B 不应被写入 A 的操作');
  const savedA = JSON.parse(JSON.parse(db.get('libraryFavorites_2024001')));
  assert.deepEqual(savedA.map((item) => item.id), [1], 'A 的收藏应写到 A 的 key');
  const listB = await favorites.list();
  assert.deepEqual(Array.from(listB), [], 'B 不应看到 A 的收藏');
});

test('连续快速收藏按顺序写入，不丢数据', async () => {
  const { favorites, db } = await makeStore();
  const results = await Promise.all([favorites.toggle(favorite(1)), favorites.toggle(favorite(2)), favorites.toggle(favorite(3))]);
  assert.deepEqual(results, [true, true, true]);
  const saved = JSON.parse(JSON.parse(db.get('libraryFavorites_2024001')));
  assert.deepEqual(saved.map((item) => item.id).sort((a, b) => a - b), [1, 2, 3]);
});
