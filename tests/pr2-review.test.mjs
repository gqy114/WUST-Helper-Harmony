// PR #2 审核回归测试。每个用例对应 REVIEW.md 中的一条问题；
// 这些断言在修复前的 PR 版本上失败，修复后通过。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = async (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });
const response = (status, data) => ({ response: { responseCode: status }, data });

async function createBooks(routes) {
  const calls = [];
  const http = new SyntheticModule(['HttpRequest'], function () {
    this.setExport('HttpRequest', {
      get: async (url) => { calls.push({ method: 'GET', url }); return routes(url); },
      postJson: async (url, body) => {
        calls.push({ method: 'POST', url, body });
        return response(200, { code: 200, data: {} });
      }
    });
  });
  const storage = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => ({ getAppAuthAccessToken: async () => 'test-token' }) });
  });
  const wall = new SourceTextModule(transform(await source('../entry/src/main/ets/net/CampusWallApi.ets')));
  await wall.link((name) => {
    if (name === './HttpRequest') return http;
    if (name === '../store/AppStorage') return storage;
    throw new Error(`Unexpected import: ${name}`);
  });
  await wall.evaluate();
  const bridge = new SyntheticModule(['CampusWallApi', 'CampusWallBookTrade', 'CampusWallPost', 'CampusWallReply', 'decodeHtmlEntities'], function () {
    this.setExport('CampusWallApi', wall.namespace.CampusWallApi);
    this.setExport('decodeHtmlEntities', wall.namespace.decodeHtmlEntities);
    for (const name of ['CampusWallBookTrade', 'CampusWallPost', 'CampusWallReply']) this.setExport(name, undefined);
  });
  const books = new SourceTextModule(transform(await source('../entry/src/main/ets/net/SecondHandBookApi.ets')));
  await books.link((name) => {
    if (name === './HttpRequest') return http;
    if (name === '../store/AppStorage') return storage;
    if (name === './CampusWallApi') return bridge;
    throw new Error(`Unexpected import: ${name}`);
  });
  await books.evaluate();
  return { calls, books: books.namespace.SecondHandBookApi };
}

// ---------------------------------------------------------------------------
// 问题 3：详情接口只返回部分字段时，不能丢弃列表里已有的商品字段。
// ---------------------------------------------------------------------------
test('partial listing detail response is merged instead of replacing the listing', async () => {
  const { books } = await createBooks((url) => {
    if (url.endsWith('/secondhand/listings/12')) {
      return response(200, { code: 200, data: { listing: { contact: 'QQ：12345678' } } });
    }
    if (url.endsWith('/secondhand/listings/12/replies')) return response(200, { code: 200, data: [] });
    throw new Error(`unexpected request: ${url}`);
  });
  const detail = await books.detail({ id: 12, sellerId: 'seller-12', price: 9.9, bookTitle: '高等数学', contact: 'QQ：111' });
  assert.equal(detail.listing.id, 12, '商品 ID 必须保留，否则无法留言');
  assert.equal(detail.listing.sellerId, 'seller-12');
  assert.equal(detail.listing.price, 9.9);
  assert.equal(detail.listing.bookTitle, '高等数学');
  assert.equal(detail.listing.contact, 'QQ：12345678', '详情补回的联系方式应生效');
});

// ---------------------------------------------------------------------------
// 问题 2：书籍详情里的单条 listing 没有核对 ID，不能当作当前商品。
// ---------------------------------------------------------------------------
test('book detail single listing with another id is ignored', async () => {
  const { books } = await createBooks((url) => {
    if (url.endsWith('/secondhand/listings/12')) throw new Error('detail endpoint missing');
    if (url.endsWith('/secondhand/books/5')) {
      return response(200, { code: 200, data: { book: { id: 5, title: '线性代数' }, listings: [], listing: { id: 99, sellerId: 'other', price: 1, contact: 'QQ：999' } } });
    }
    if (url.endsWith('/secondhand/listings/12/replies')) return response(200, { code: 200, data: [] });
    throw new Error(`unexpected request: ${url}`);
  });
  const detail = await books.detail({ id: 12, bookId: 5, sellerId: 'seller-12', price: 10, contact: 'QQ：111' });
  assert.equal(detail.listing.id, 12);
  assert.equal(detail.listing.sellerId, 'seller-12', '不能换成另一位卖家的资料');
  assert.equal(detail.listing.price, 10);
  assert.equal(detail.listing.contact, 'QQ：111', '不能换成另一位卖家的联系方式');
  assert.equal(detail.book.title, '线性代数');
});

test('book detail listing array still requires a matching id', async () => {
  const { books } = await createBooks((url) => {
    if (url.endsWith('/secondhand/listings/12')) throw new Error('detail endpoint missing');
    if (url.endsWith('/secondhand/books/5')) {
      return response(200, { code: 200, data: { listings: [{ id: 99, sellerId: 'other', price: 1, contact: 'QQ：999' }] } });
    }
    if (url.endsWith('/secondhand/listings/12/replies')) return response(200, { code: 200, data: [] });
    throw new Error(`unexpected request: ${url}`);
  });
  const detail = await books.detail({ id: 12, bookId: 5, sellerId: 'seller-12', price: 10, contact: 'QQ：111' });
  assert.equal(detail.listing.id, 12);
  assert.equal(detail.listing.contact, 'QQ：111');
});

test('matching book detail listing is merged and keeps the requested listing', async () => {
  const { books } = await createBooks((url) => {
    if (url.endsWith('/secondhand/listings/12')) throw new Error('detail endpoint missing');
    if (url.endsWith('/secondhand/books/5')) {
      return response(200, { code: 200, data: { book: { id: 5, title: '线性代数' }, listings: [{ id: 12, price: 8, contact: 'QQ：222' }] } });
    }
    if (url.endsWith('/secondhand/listings/12/replies')) return response(200, { code: 200, data: [] });
    throw new Error(`unexpected request: ${url}`);
  });
  const detail = await books.detail({ id: 12, bookId: 5, sellerId: 'seller-12', price: 10, bookTitle: '线性代数', contact: 'QQ：111' });
  assert.equal(detail.listing.id, 12);
  assert.equal(detail.listing.sellerId, 'seller-12', '详情缺失的卖家信息由列表数据补齐');
  assert.equal(detail.listing.price, 8, '详情里的最新价格可以覆盖');
  assert.equal(detail.listing.contact, 'QQ：222');
});

// ---------------------------------------------------------------------------
// 问题 4：联系类型与号码分开存放时不能丢失类型。
// ---------------------------------------------------------------------------
test('contact type from post.contactType combines with extra.contactValue', async () => {
  const { books } = await createBooks(() => { throw new Error('no request expected'); });
  const listing = books.fromCommunityPost({
    id: 7, studentId: 's1', contactType: 'QQ', extra: JSON.stringify({ contactValue: '12345678' })
  });
  assert.equal(listing.contact, 'QQ：12345678', '旧版组合结果为 QQ：12345678');
});

test('contact type from bookTrade combines with a contact stored elsewhere', async () => {
  const { books } = await createBooks(() => { throw new Error('no request expected'); });
  const listing = books.fromCommunityPost({
    id: 8, studentId: 's1', bookTrade: { contactType: '微信' }, extra: JSON.stringify({ contact: 'wx_123' })
  });
  assert.equal(listing.contact, '微信：wx_123');
});

test('a type belonging to another contact is not applied to the chosen number', async () => {
  const { books } = await createBooks(() => { throw new Error('no request expected'); });
  const listing = books.fromCommunityPost({
    id: 9, studentId: 's1', contactType: 'QQ', contact: '111',
    extra: JSON.stringify({ contactValue: '222' })
  });
  assert.equal(listing.contact, 'QQ：111');
});

test('already formatted contact values are not prefixed twice', async () => {
  const { books } = await createBooks(() => { throw new Error('no request expected'); });
  const listing = books.fromCommunityPost({
    id: 10, studentId: 's1', contactType: 'QQ', contact: 'QQ：333'
  });
  assert.equal(listing.contact, 'QQ：333');
});

// ---------------------------------------------------------------------------
// 问题 1：刷新列表必须让旧的分页请求失效。
// ---------------------------------------------------------------------------
async function wallPageHarness() {
  const pageSource = await source('../entry/src/main/ets/pages/campus/CampusWallPage.ets');
  const extract = (name) => {
    const match = pageSource.match(new RegExp(`  private (?:async )?${name}\\([^)]*\\)[^{]*\\{[\\s\\S]*?\\r?\\n  \\}`));
    assert.ok(match, `actual page ${name} method not found`);
    return match[0];
  };
  const pending = [];
  const requests = [];
  const toasts = [];
  const context = createContext({
    Number, Error, Array, String,
    CampusWallApi: { list: async (page, tag) => {
      requests.push({ page, tag });
      return new Promise((resolve) => { pending.push({ page, resolve }); });
    } },
    promptAction: { showToast: ({ message }) => toasts.push(message) }
  });
  const module = new SourceTextModule(transform(`export class TestPage {\n${extract('load')}\n${extract('loadMore')}\n${extract('appendUniquePosts')}\n}`), { context });
  await module.link(() => { throw new Error('No imports expected'); });
  await module.evaluate();
  const page = new module.namespace.TestPage();
  Object.assign(page, { loading: false, loadingMore: false, posts: [], currentPage: 2, hasMore: true, pageSize: 20, requestGeneration: 0 });
  return {
    page, requests, toasts,
    resolvePage: (pageNumber, items) => {
      const index = pending.findIndex((item) => item.page === pageNumber);
      assert.ok(index >= 0, `page ${pageNumber} request was not issued`);
      const entry = pending.splice(index, 1)[0];
      entry.resolve(items);
    }
  };
}

const ids = (posts) => Array.from(posts, (post) => post.id);

test('a refresh invalidates the in-flight page request that started before it', async () => {
  const { page, requests, resolvePage } = await wallPageHarness();
  const more = page.loadMore();           // 请求第 3 页，挂起
  assert.deepEqual(requests.map((item) => item.page), [3]);
  const refresh = page.load();            // 返回页面触发刷新，重置到第 1 页
  assert.deepEqual(requests.map((item) => item.page), [3, 1]);
  resolvePage(1, [{ id: 1 }, { id: 2 }]);
  await refresh;
  assert.equal(page.currentPage, 1);
  assert.deepEqual(ids(page.posts), [1, 2]);

  resolvePage(3, [{ id: 101 }, { id: 102 }]);  // 旧的第 3 页此时才返回
  await more;
  assert.equal(page.currentPage, 1, '旧分页响应不能把页码改回 3');
  assert.deepEqual(ids(page.posts), [1, 2], '旧分页数据不能混入刷新后的列表');
  assert.equal(page.loadingMore, false, '旧响应结束后不应残留 loadingMore');
  assert.equal(page.loading, false);
});

test('a stale first-page response does not overwrite a newer refresh', async () => {
  const { page, resolvePage } = await wallPageHarness();
  const first = page.load();              // 第 1 次刷新
  const second = page.load();             // 第 2 次刷新（例如快速返回两次）
  resolvePage(1, [{ id: 1 }]);
  await first;
  assert.equal(page.currentPage, 1);
  assert.deepEqual(ids(page.posts), [], '过期首屏响应不能写回');
  assert.equal(page.loading, true, '新刷新仍在进行中');
  resolvePage(1, [{ id: 5 }, { id: 6 }]);
  await second;
  assert.deepEqual(ids(page.posts), [5, 6]);
  assert.equal(page.loading, false);
});

test('every campus list page guards load and loadMore with a request generation', async () => {
  const pages = ['CampusWallPage', 'CampusHelpPage', 'CampusLostPage', 'CampusMatchPage', 'CampusCatPage', 'SecondHandBookPage'];
  for (const name of pages) {
    const text = await source(`../entry/src/main/ets/pages/campus/${name}.ets`);
    assert.match(text, /private requestGeneration: number = 0;/, `${name} 缺少请求代次`);
    const load = text.match(/  private async load\(\): Promise<void> \{[\s\S]*?\r?\n  \}/)?.[0];
    const loadMore = text.match(/  private async loadMore\(\): Promise<void> \{[\s\S]*?\r?\n  \}/)?.[0];
    assert.ok(load, `${name} load 方法未找到`);
    assert.ok(loadMore, `${name} loadMore 方法未找到`);
    assert.match(load, /const generation = \+\+this\.requestGeneration;/);
    assert.match(load, /generation !== this\.requestGeneration/);
    assert.match(loadMore, /const generation = this\.requestGeneration;/);
    assert.match(loadMore, /generation !== this\.requestGeneration/);
    // 每个 await 之后都要有代次校验（try 与 catch 各一处）；
    // 二手书页同时分页“原生列表”和“社区列表”，因此是两倍。
    const guards = (loadMore.match(/generation !== this\.requestGeneration/g) || []).length;
    assert.ok(guards >= (name === 'SecondHandBookPage' ? 4 : 2), `${name} 每个分页响应都要校验代次`);
  }
});
