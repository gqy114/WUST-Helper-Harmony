// 主页轮播图：图片地址补全与加载失败兜底。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

async function loadApi(bannerRows = []) {
  const code = stripTypeScriptTypes(await source(`${root}/net/HomeContentApi.ets`), { mode: 'transform' });
  const context = createContext({ console, JSON, Date, Array, String });
  const http = new SyntheticModule(['HttpRequest'], function () {
    this.setExport('HttpRequest', {
      get: async () => ({ data: { code: 200, message: 'Success', data: bannerRows } }),
    });
  }, { context });
  const mod = new SourceTextModule(code, { context });
  await mod.link((name) => {
    if (name === './HttpRequest') return http;
    throw new Error(`Unexpected import: ${name}`);
  });
  await mod.evaluate();
  return mod.namespace.HomeContentApi;
}

test('相对地址补全为本站域名，协议相对地址补 https', async () => {
  const api = await loadApi([
    { actid: 1, title: 'a', imgUrl: '/upload/a.png' },
    { actid: 2, title: 'b', imgUrl: 'upload/b.png' },
    { actid: 3, title: 'c', imgUrl: '//cdn.example.com/c.png' },
    { actid: 4, title: 'd', imgUrl: 'https://cdn.example.com/d.png' },
  ]);
  const banners = await api.banners();
  assert.deepEqual(Array.from(banners, (item) => item.imageUrl), [
    'https://lyzyy.love/upload/a.png',
    'https://lyzyy.love/upload/b.png',
    'https://cdn.example.com/c.png',
    'https://cdn.example.com/d.png',
  ]);
});

test('没有图片地址的 banner 会被过滤', async () => {
  const api = await loadApi([
    { actid: 1, title: '无图', imgUrl: '' },
    { actid: 2, title: '有图', imgUrl: 'https://cdn.example.com/b.png' },
  ]);
  const banners = await api.banners();
  assert.deepEqual(Array.from(banners, (item) => item.id), [2]);
});

test('页面在图片加载失败时移除该 banner，全部失败退回占位样式', async () => {
  const page = await source(`${root}/pages/main/MainPage.ets`);
  assert.match(page, /private failedBannerKeys: string\[\]/, '缺少失败 banner 状态');
  assert.match(page, /private visibleBanners\(\): HomeBanner\[\]/, '渲染应只使用可用 banner');
  assert.match(page, /\.onError\(\(\) => this\.markBannerFailed\(banner\)\)/, '图片加载失败没有兜底');
  assert.match(page, /this\.failedBannerKeys = this\.failedBannerKeys\.concat\(\[key\]\)/, '失败后应移除该 banner');
  assert.match(page, /this\.failedBannerKeys = \[\];/, '重新拉取 banner 时应重置失败状态');
  assert.match(page, /if \(this\.visibleBanners\(\)\.length > 0\)/, '全部失败时应显示渐变占位');
  assert.match(page, /\.autoPlay\(this\.visibleBanners\(\)\.length > 1\)/, '轮播应按可用 banner 数量决定');
});
