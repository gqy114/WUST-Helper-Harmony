// 图书馆模块：接口筛选逻辑、收藏存储与页面接线测试。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

async function loadApi() {
  const code = stripTypeScriptTypes(await source(`${root}/net/LibraryApi.ets`), { mode: 'transform' });
  const context = createContext({ console, JSON, Array, Date, Number, String, isNaN });
  const http = new SyntheticModule(['HttpRequest'], function () {
    this.setExport('HttpRequest', { request: async () => ({ data: {} }) });
  }, { context });
  const model = new SyntheticModule(['LibraryLoanItem'], function () {
    this.setExport('LibraryLoanItem', undefined);
  }, { context });
  const app = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', {
      getInstance: () => ({ getAppAuthAccessToken: async () => '', getStudentId: async () => '' }),
    });
  }, { context });
  const mod = new SourceTextModule(code, { context });
  await mod.link((name) => {
    if (name === './HttpRequest') return http;
    if (name === '../model/LibraryLoanModel') return model;
    if (name === '../store/AppStorage') return app;
    throw new Error(`Unexpected import: ${name}`);
  });
  await mod.evaluate();
  return mod.namespace;
}

test('首页推荐只保留 show=1 且有图片/链接的条目', async () => {
  const api = await loadApi();
  const items = [
    { id: 2, pictureLink: 'a.jpg', articleLink: 'https://a', show: 1 },
    { id: 3, pictureLink: 'b.jpg', articleLink: 'https://b', show: 1 },
    { id: 22, pictureLink: 'c.jpg', articleLink: 'https://c', show: 0 },
    { id: 23, show: 1 },
  ];
  const visible = api.visibleHomeArticles(items);
  assert.deepEqual(Array.from(visible, (item) => item.id), [2, 3]);
});

test('活动资讯只保留 show=1 且有标题或链接的条目', async () => {
  const api = await loadApi();
  const rows = [
    { id: 12, title: '认识一下吧', tag: '活动', show: 1 },
    { id: 11, title: '隐藏条目', tag: '活动', show: 0 },
    { id: 5, title: '国庆开放安排', tag: '通知', show: 1 },
    { id: 9, show: 1 },
  ];
  assert.deepEqual(Array.from(api.visibleArticles(rows), (row) => row.id), [12, 5]);
});

test('标签与资源分组标题按后端取值映射', async () => {
  const api = await loadApi();
  assert.equal(api.articleTagLabel('活动'), '活动');
  assert.equal(api.articleTagLabel('讲座'), '讲座');
  assert.equal(api.articleTagLabel('通知'), '通知');
  assert.equal(api.articleTagLabel(''), '通知');
  assert.equal(api.articleTagLabel('其他'), '其他');
  assert.equal(api.resourceTypeLabel(1), '中文资源');
  assert.equal(api.resourceTypeLabel(2), '外文资源');
  assert.equal(api.resourceTypeLabel(3), '开放资源');
  assert.equal(api.resourceTypeLabel(4), '智能服务');
  assert.equal(api.resourceTypeLabel(9), '其他资源');
});

async function loadFavorites(initialRaw = '[]', options = {}) {
  const { delayedRead = false, studentId = '', token = 'wh_at_test' } = options;
  const code = stripTypeScriptTypes(await source(`${root}/store/LibraryFavorites.ets`), { mode: 'transform' });
  const store = new Map();
  // AppStorage 的 setSettingString 会再包一层 JSON，和真实存储保持一致。
  store.set('libraryFavorites', JSON.stringify(JSON.stringify(initialRaw)));
  const storage = {
    getStudentId: async () => studentId,
    getAppAuthAccessToken: async () => token,
    getSettingString: async (key, def) => {
      if (delayedRead) {
        // 模拟磁盘读取慢：页面刚打开、收藏还没读完时用户就点了收藏。
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
      const raw = store.has(key) ? store.get(key) : JSON.stringify(def);
      try {
        return JSON.parse(raw);
      } catch {
        return def;
      }
    },
    setSettingString: async (key, value) => { store.set(key, JSON.stringify(value)); },
    getSettingBool: async (key, def) => {
      const raw = store.has(key) ? store.get(key) : JSON.stringify(def);
      try {
        return JSON.parse(raw) === true;
      } catch {
        return def;
      }
    },
    setSettingBool: async (key, value) => { store.set(key, JSON.stringify(value)); },
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
  return { favorites: mod.namespace.LibraryFavorites.getInstance(), store };
}

test('收藏只使用本机存储，不发任何网络请求', async () => {
  const { favorites } = await loadFavorites([], { studentId: '', token: 'stale_token' });
  const item = { kind: 'article', id: 12, title: '本地收藏', link: 'https://a', tag: '活动' };

  assert.equal(await favorites.toggle(item), true);
  assert.equal(favorites.has('article', 12), true);
});

test('收藏可添加、可取消，并立即写入 preferences', async () => {
  const { favorites, store } = await loadFavorites();
  const item = { kind: 'article', id: 12, title: '认识一下吧', link: 'https://a', tag: '活动' };

  assert.equal(await favorites.toggle(item), true, '第一次应是收藏');
  assert.equal(favorites.has('article', 12), true);
  assert.deepEqual(JSON.parse(JSON.stringify(await favorites.list())), [item]);
  assert.match(store.get('libraryFavorites'), /认识一下吧/);

  assert.equal(await favorites.toggle(item), false, '再点一次应取消收藏');
  assert.equal(favorites.has('article', 12), false);
  assert.deepEqual(Array.from(await favorites.list()), []);
});

test('旧收藏还没读完就添加新收藏，不会覆盖原有收藏', async () => {
  const existing = { kind: 'resource', id: 3, title: '知网', link: 'https://x', tag: '资源' };
  const { favorites, store } = await loadFavorites([existing], { delayedRead: true });
  // 不等 list()：直接收藏，模拟「刚打开页面就点收藏」。
  assert.equal(await favorites.toggle({ kind: 'article', id: 12, title: '新收藏', link: 'https://a', tag: '活动' }), true);
  const saved = JSON.parse(JSON.parse(store.get('libraryFavorites')));
  assert.deepEqual(saved.map((item) => item.id).sort((a, b) => a - b), [3, 12], '旧收藏不能被覆盖');
});

test('连续快速点收藏，写入按顺序生效', async () => {
  const { favorites, store } = await loadFavorites();
  const first = favorites.toggle({ kind: 'article', id: 1, title: '一', link: 'https://1', tag: '通知' });
  const second = favorites.toggle({ kind: 'article', id: 2, title: '二', link: 'https://2', tag: '通知' });
  assert.deepEqual([await first, await second], [true, true]);
  const saved = JSON.parse(JSON.parse(store.get('libraryFavorites')));
  assert.deepEqual(saved.map((item) => item.id).sort((a, b) => a - b), [1, 2]);
});

test('加载时过滤非法收藏记录，重复项只保留一次', async () => {
  const { favorites } = await loadFavorites([
    { kind: 'article', id: 1, title: '有效', link: 'https://a', tag: '通知' },
    { kind: '', id: 2, title: '无 kind', link: '', tag: '' },
    { kind: 'resource', id: 0, title: '无 id', link: '', tag: '' },
  ]);
  const list = await favorites.list();
  assert.deepEqual(Array.from(list, (item) => item.id), [1]);
});

test('页面接入三个真实接口、bell 图标与收藏，占位 tab 全部替换', async () => {
  const page = await source(`${root}/pages/library/LibraryPage.ets`);
  const api = await source(`${root}/net/LibraryApi.ets`);
  assert.match(api, /api\/wx\/notice\/new/, '缺少最新通知接口');
  assert.match(api, /api\/wx\/home\/getHomeArticle/, '缺少首页推荐接口');
  assert.match(api, /api\/wx\/article\/getArticleList/, '缺少活动资讯接口');
  assert.match(api, /api\/wx\/resource\/getResourcesList/, '缺少资源导航接口');
  assert.match(api, /resourceType=\$\{resourceType\}/, '资源导航没有传 resourceType');

  assert.match(page, /\$r\('app\.media\.bell'\)/, '页面没有使用 bell 图标');
  assert.match(page, /LibraryApi\.latestNotice\(\)/, '公告通知 tab 没有调用接口');
  assert.match(page, /LibraryApi\.homeArticles\(\)/, '首页推荐 tab 没有调用接口');
  assert.match(page, /LibraryApi\.articles\(\)/, '活动资讯 tab 没有调用接口');
  assert.match(page, /LibraryApi\.resources\(0\)/, '资源导航 tab 没有调用接口');
  assert.match(page, /LibraryFavorites\.getInstance\(\)/, '没有接入收藏存储');
  assert.match(page, /private tabErrors: string\[\]/, '缺少按栏目保存的错误状态');
  assert.match(page, /this\.errorText = this\.tabErrors\[index\]/, '切回栏目时应恢复错误状态');
  assert.match(page, /this\.tabsLoaded\[index\] = false/, '加载失败时应允许重新加载');
  assert.doesNotMatch(page, /this\.emptyContent\(\)/, '不应再有占位空内容分支');
  for (const title of ['我的收藏', '公告通知', '首页推荐', '活动资讯', '资源导航']) {
    assert.match(page, new RegExp(`'${title}'`), `缺少 tab：${title}`);
  }
});
