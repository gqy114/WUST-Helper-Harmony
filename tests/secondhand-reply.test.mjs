import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = async (path) => readFile(new URL(path, import.meta.url), 'utf8');
const transform = (code) => stripTypeScriptTypes(code, { mode: 'transform' });
const response = (status, data) => ({ response: { responseCode: status }, data });

async function createApis() {
  const mock = { calls: [], postResponse: response(200, { code: 200, data: {} }),
    getResponse: response(200, { code: 200, data: [] }) };
  const http = new SyntheticModule(['HttpRequest'], function () {
    this.setExport('HttpRequest', {
      postJson: async (url, body, headers) => { mock.calls.push({ method: 'POST', url, body, headers }); return mock.postResponse; },
      get: async (url, headers) => { mock.calls.push({ method: 'GET', url, headers }); return mock.getResponse; }
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
  // Node's type stripper retains ordinary imports that ArkTS uses for types.
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
  return { mock, wall: wall.namespace.CampusWallApi, books: books.namespace.SecondHandBookApi };
}

test('native and community replies post to distinct correct endpoints', async () => {
  const { mock, wall, books } = await createApis();
  await books.reply(12, '卖家本人回复');
  await wall.reply(77, '社区帖子回复');
  assert.match(mock.calls[0].url, /\/secondhand\/listings\/12\/replies$/);
  assert.match(mock.calls[1].url, /\/campus-wall\/posts\/77\/replies$/);
  assert.deepEqual(mock.calls.map(call => call.body.content), ['卖家本人回复', '社区帖子回复']);
  assert.equal(mock.calls[0].headers.Authorization, 'Bearer test-token');
  assert.equal(mock.calls[1].headers.Authorization, 'Bearer test-token');
});

test('both reply APIs accept the supported success codes', async () => {
  const { mock, wall, books } = await createApis();
  for (const code of [0, 200]) {
    mock.postResponse = response(200, { code, data: { id: 1 } });
    await books.reply(12, 'ok');
    await wall.reply(77, 'ok');
  }
});

test('both reply APIs reject HTTP failures, non-JSON and business errors', async () => {
  const { mock, wall, books } = await createApis();
  for (const result of [
    response(404, '404 page not found'), response(500, 'internal server error'),
    response(200, 'not JSON'), response(200, null), response(200, {}),
    response(200, { code: 403, message: '没有权限' }), response(200, { code: 404, message: '没有该帖子' })
  ]) {
    mock.postResponse = result;
    await assert.rejects(books.reply(12, 'keep'));
    await assert.rejects(wall.reply(77, 'keep'));
  }
});

test('after a native reply, strict reload detects a failed reply-list request', async () => {
  const { mock, books } = await createApis();
  mock.getResponse = response(200, { code: 200, data: [{ id: 1, content: '卖家本人回复' }] });
  const detail = await books.detail({ id: 12 }, true);
  assert.equal(detail.replies.length, 1);
  assert.equal(detail.replies[0].content, '卖家本人回复');
  mock.getResponse = response(404, '404 page not found');
  assert.equal((await books.detail({ id: 12 })).replies.length, 0);
  await assert.rejects(books.detail({ id: 12 }, true), /留言刷新失败/);
});

async function pageHarness() {
  const pageSource = await source('../entry/src/main/ets/pages/campus/SecondHandBookDetailPage.ets');
  const method = pageSource.match(/  private async sendReply\(\): Promise<void> \{[\s\S]*?\r?\n  \}/)?.[0];
  assert.ok(method, 'actual page sendReply method not found');
  const calls = [], toasts = [];
  const mock = { calls, toasts, fail: false, refreshed: true };
  const context = createContext({
    Number, Error,
    CampusWallApi: { reply: async (id, content) => { calls.push({ source: 'community', id, content }); if (mock.fail) throw new Error('测试错误'); } },
    SecondHandBookApi: { reply: async (id, content) => { calls.push({ source: 'native', id, content }); if (mock.fail) throw new Error('测试错误'); } },
    promptAction: { showToast: ({ message }) => toasts.push(message) }
  });
  const module = new SourceTextModule(transform(`export class TestPage {\n${method}\n}`), { context });
  await module.link(() => { throw new Error('No imports expected'); });
  await module.evaluate();
  const page = new module.namespace.TestPage();
  Object.assign(page, { replyText: '卖家本人留言', sending: false, listing: { id: 12, sellerId: 'self' },
    communityPostId: 0, myStudentId: 'self', replyOpen: true,
    load: async (...args) => { calls.push({ source: 'reload', args }); return mock.refreshed; } });
  return { page, mock };
}

test('seller can reply to own native listing and reload persisted replies', async () => {
  const { page, mock } = await pageHarness();
  await page.sendReply();
  assert.deepEqual(mock.calls[0], { source: 'native', id: 12, content: '卖家本人留言' });
  assert.deepEqual(mock.calls[1], { source: 'reload', args: [false, true] });
  assert.equal(page.replyText, '');
  assert.equal(page.replyOpen, false);
  assert.equal(mock.toasts.at(-1), '留言成功');
});

test('another user can still reply to a native listing', async () => {
  const { page, mock } = await pageHarness();
  page.listing.sellerId = 'another-user';
  await page.sendReply();
  assert.deepEqual(mock.calls[0], { source: 'native', id: 12, content: '卖家本人留言' });
  assert.equal(mock.toasts.at(-1), '留言成功');
});

test('seller replies to community post using post ID, never listing ID', async () => {
  const { page, mock } = await pageHarness();
  page.listing = { id: 12, source: 'community', sellerId: 'self' };
  page.communityPostId = 77;
  await page.sendReply();
  assert.deepEqual(mock.calls[0], { source: 'community', id: 77, content: '卖家本人留言' });
});

test('failed sends keep the draft open and do not refresh', async () => {
  const { page, mock } = await pageHarness();
  mock.fail = true;
  await page.sendReply();
  assert.equal(page.replyText, '卖家本人留言');
  assert.equal(page.replyOpen, true);
  assert.equal(page.sending, false);
  assert.equal(mock.calls.length, 1);
  assert.equal(mock.toasts.at(-1), '测试错误');
});

test('missing community post ID does not send to unrelated listing ID', async () => {
  const { page, mock } = await pageHarness();
  page.listing = { id: 12, source: 'community' };
  page.communityPostId = 0;
  await page.sendReply();
  assert.equal(mock.calls.length, 0);
  assert.equal(page.replyText, '卖家本人留言');
  assert.match(mock.toasts.at(-1), /帖子信息不完整/);
});

test('a successful send reports when the subsequent refresh fails', async () => {
  const { page, mock } = await pageHarness();
  mock.refreshed = false;
  await page.sendReply();
  assert.equal(mock.toasts.at(-1), '留言已发送，刷新失败，请稍后重试');
});

test('a changed draft is not erased while an earlier reply is in flight', async () => {
  const pageSource = await source('../entry/src/main/ets/pages/campus/SecondHandBookDetailPage.ets');
  const method = pageSource.match(/  private async sendReply\(\): Promise<void> \{[\s\S]*?\r?\n  \}/)?.[0];
  let resolveSend;
  const pending = new Promise(resolve => { resolveSend = resolve; });
  const context = createContext({ Number, Error, CampusWallApi: {},
    SecondHandBookApi: { reply: async () => pending }, promptAction: { showToast: () => {} } });
  const module = new SourceTextModule(transform(`export class TestPage {\n${method}\n}`), { context });
  await module.link(() => { throw new Error('No imports expected'); });
  await module.evaluate();
  const page = new module.namespace.TestPage();
  Object.assign(page, { replyText: '第一条', sending: false, listing: { id: 12 }, communityPostId: 0,
    replyOpen: true, load: async () => true });
  const send = page.sendReply();
  page.replyText = '正在编辑的下一条';
  resolveSend();
  await send;
  assert.equal(page.replyText, '正在编辑的下一条');
  assert.equal(page.replyOpen, true);
});
