import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });

async function makePage() {
  const calls = [], toasts = [];
  const mock = { calls, toasts, pending: null, result: { response: { responseCode: 200 }, data: { code: 200,
    data: { contactType: 'qq', contactValue: '123456' } } }, fail: false };
  const context = createContext({ console, Number, Error, JSON, String, Object, Array, Set, parseInt, isNaN,
    promptAction: { showToast: ({ message }) => toasts.push(message) } });
  const http = new SyntheticModule(['HttpRequest'], function () {
    this.setExport('HttpRequest', { get: async (url, headers, secure) => {
      calls.push({ url, headers, secure });
      if (mock.fail) throw new Error('网络不可用');
      if (mock.pending) await mock.pending;
      return mock.result;
    } });
  }, { context });
  const storage = new SyntheticModule(['AppStorage'], function () {
    this.setExport('AppStorage', { getInstance: () => ({ getAppAuthAccessToken: async () => 'fake-token' }) });
  }, { context });
  const wall = new SourceTextModule(transform(await source('../entry/src/main/ets/net/CampusWallApi.ets')), { context });
  await wall.link((name) => name === './HttpRequest' ? http : storage);
  await wall.evaluate();
  const bridge = new SyntheticModule(['CampusWallApi', 'CampusWallBookTrade', 'CampusWallPost', 'CampusWallReply', 'decodeHtmlEntities'], function () {
    this.setExport('CampusWallApi', wall.namespace.CampusWallApi);
    this.setExport('decodeHtmlEntities', wall.namespace.decodeHtmlEntities);
    for (const name of ['CampusWallBookTrade', 'CampusWallPost', 'CampusWallReply']) this.setExport(name, undefined);
  }, { context });
  const books = new SourceTextModule(transform(await source('../entry/src/main/ets/net/SecondHandBookApi.ets')), { context });
  await books.link((name) => name === './HttpRequest' ? http : name === '../store/AppStorage' ? storage : bridge);
  await books.evaluate();
  context.SecondHandBookApi = books.namespace.SecondHandBookApi;
  const pageSource = await source('../entry/src/main/ets/pages/campus/SecondHandBookDetailPage.ets');
  const method = pageSource.match(/  private async openSellerContact\(\): Promise<void> \{[\s\S]*?\r?\n  \}/)?.[0];
  assert.ok(method, 'page contact method missing');
  const pageModule = new SourceTextModule(transform(`export class TestPage {\n${method}\n}`), { context });
  await pageModule.link(() => { throw new Error('unexpected import'); });
  await pageModule.evaluate();
  const page = new pageModule.namespace.TestPage();
  const post = { id: 73, studentId: 'fake-seller', tag: 'book_trade',
    extra: JSON.stringify({ priceCents: 1140, saleStatus: 'available' }) };
  Object.assign(page, { listing: books.namespace.SecondHandBookApi.fromCommunityPost(post),
    communityPostId: 73, contactOpen: false, contactLoading: false });
  return { page, mock, books: books.namespace.SecondHandBookApi };
}

test('hidden community contact is fetched using post ID and shown after tapping', async () => {
  const { page, mock } = await makePage();
  page.listing.id = 999; // Listing ID and community post ID are different.
  assert.equal(page.listing.contact, '');
  await page.openSellerContact();
  assert.equal(mock.calls.length, 1);
  assert.match(mock.calls[0].url, /\/campus-wall\/posts\/73\/contact$/);
  assert.equal(mock.calls[0].headers.Authorization, 'Bearer fake-token');
  assert.equal(mock.calls[0].secure, true);
  assert.equal(page.listing.contact, 'qq：123456');
  assert.equal(page.contactOpen, true);
  assert.equal(page.contactLoading, false);
});

test('existing community and native contacts open without a new request', async () => {
  const { page, mock } = await makePage();
  page.listing.contact = '微信：test-id';
  await page.openSellerContact();
  assert.equal(page.listing.contact, '微信：test-id');
  assert.equal(page.contactOpen, true);
  page.contactOpen = false;
  page.communityPostId = 0;
  page.listing = { id: 999, source: 'secondhand', contact: '电话：12345' };
  await page.openSellerContact();
  assert.equal(page.contactOpen, true);
  assert.equal(mock.calls.length, 0);
});

test('invalid or missing post IDs never query a different listing ID', async () => {
  const { page, mock } = await makePage();
  page.listing.id = 999;
  page.communityPostId = 0;
  await page.openSellerContact();
  assert.equal(mock.calls.length, 0);
  assert.equal(page.contactOpen, false);
  assert.match(mock.toasts.at(-1), /帖子信息不完整/);
});

test('server failures do not pretend contact is unpublished and remain retryable', async () => {
  const { page, mock } = await makePage();
  for (const [status, code, expected] of [[200, 401, /登录/], [200, 409, /售出/],
    [404, 404, /不存在|不可用/], [500, 500, /获取联系方式失败/]]) {
    mock.result = { response: { responseCode: status }, data: { code, message: 'failure' } };
    await page.openSellerContact();
    assert.equal(page.contactOpen, false);
    assert.equal(page.contactLoading, false);
    assert.match(mock.toasts.at(-1), expected);
  }
  mock.fail = true;
  await page.openSellerContact();
  assert.equal(page.contactOpen, false);
  assert.equal(page.contactLoading, false);
  mock.fail = false;
  mock.result = { response: { responseCode: 200 }, data: { code: 0,
    data: { contactType: 'wechat', contactValue: 'test-id' } } };
  await page.openSellerContact();
  assert.equal(page.contactOpen, true);
  assert.equal(page.listing.contact, 'wechat：test-id');
});

test('incomplete success response is not treated as a valid contact', async () => {
  const { page, mock } = await makePage();
  mock.result = { response: { responseCode: 200 }, data: { code: 200, data: { contactType: 'qq' } } };
  await page.openSellerContact();
  assert.equal(page.contactOpen, false);
  assert.match(mock.toasts.at(-1), /联系方式暂不可用/);
});

test('repeated taps while loading make only one request', async () => {
  const { page, mock } = await makePage();
  let release;
  mock.pending = new Promise(resolve => { release = resolve; });
  const first = page.openSellerContact();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(page.contactLoading, true);
  await page.openSellerContact();
  assert.equal(mock.calls.length, 1);
  release();
  await first;
  assert.equal(page.contactOpen, true);
  assert.equal(page.contactLoading, false);
});
