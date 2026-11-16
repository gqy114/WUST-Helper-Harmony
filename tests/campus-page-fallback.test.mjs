// 校园资讯改用后端 /News/Support 原生列表，不再加载 wustlinghang 网页。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main';
const source = (path) => readFile(new URL(`${root}/ets/${path}`, import.meta.url), 'utf8');

test('校园页通过后端校园资讯接口拉取列表', async () => {
  const code = await source('pages/campus/CampusPage.ets');
  assert.match(code, /CampusNewsApi\.articles\(/, '没有调用校园资讯列表接口');
  assert.doesNotMatch(code, /Web\(\{ src: 'https:\/\/news\.wustlinghang\.cn'/, '仍在直接加载旧网页');
  assert.match(code, /Text\('旧版入口'\)/, '接口不可用时没有保留旧入口');
  assert.match(code, /Text\('重试'\)/, '加载失败缺少重试入口');
});

test('校园页加载失败时仍保留本地校园服务入口', async () => {
  const code = await source('pages/campus/CampusPage.ets');
  const routes = [
    'pages/campus/SchoolCalendarPage',
    'pages/campus/SchoolBusPage',
    'pages/campus/YellowPagesPage',
    'pages/course/PhysicalExperimentPage'
  ];
  for (const route of routes) {
    assert.match(code, new RegExp(route.replaceAll('/', '\\/')), `缺少本地入口：${route}`);
  }
});

test('点资讯进入详情页，详情页注册到 main_pages', async () => {
  const page = await source('pages/campus/CampusPage.ets');
  assert.match(page, /pages\/campus\/CampusNewsDetailPage/, '没有跳转资讯详情页');
  const pages = await source('../resources/base/profile/main_pages.json');
  assert.match(pages, /pages\/campus\/CampusNewsDetailPage/, '详情页没有注册');
});

test('资讯详情从后端接口读取，并编码后再 loadData', async () => {
  const page = await source('pages/campus/CampusNewsDetailPage.ets');
  assert.match(page, /CampusNewsApi\.detail\(/, '详情没有调用后端接口');
  assert.match(page, /encodeURIComponent\(document\)/, 'loadData 前没有编码 # 号');
  assert.doesNotMatch(page, /news\.wustlinghang\.cn/, '详情仍在加载旧网页');
});

test('校园资讯接口走 /News/Support，包含列表、详情、搜索', async () => {
  const api = await source('net/CampusNewsApi.ets');
  assert.match(api, /\/News\/Support/, '接口前缀不是 /News\/Support');
  assert.match(api, /\/articles/, '缺少资讯列表/详情接口');
  assert.match(api, /\/search/, '缺少搜索接口');
  assert.match(api, /page_size/, '缺少分页参数');
});

test('主节点 404 时校园资讯自动切换备用节点', async () => {
  const api = await source('net/CampusNewsApi.ets');
  assert.match(api, /const BACKUP = 'http:\/\/port\.happylandmc\.cc:52144\/News\/Support'/, '缺少备用节点');
  assert.match(api, /const urls: string\[\] = \[`\$\{PRIMARY\}\$\{path\}`, `\$\{BACKUP\}\$\{path\}`\]/, '没有依次尝试主备节点');
});
