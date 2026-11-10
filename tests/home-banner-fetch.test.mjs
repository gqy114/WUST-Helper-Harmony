// 主页轮播图：接口返回的图片地址状态码异常（404 + 图片字节）时仍要能显示。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = '../entry/src/main/ets';
const source = (path) => readFile(new URL(path, import.meta.url), 'utf8');

test('BannerImageLoader 自行抓取字节解码，不依赖 HTTP 状态码', async () => {
  const loader = await source(`${root}/utils/BannerImageLoader.ets`);
  assert.match(loader, /http\.createHttp\(\)/, '缺少 http 请求');
  assert.match(loader, /expectDataType: http\.HttpDataType\.ARRAY_BUFFER/, '没有按二进制取响应');
  assert.match(loader, /image\.createImageSource\(body\)/, '没有解码响应体');
  assert.match(loader, /createPixelMap\(\)/, '没有生成 PixelMap');
  assert.doesNotMatch(loader, /responseCode\s*!==\s*200/, '不能只认 200；图片字节有效即可');
  assert.match(loader, /BannerImageLoader\.cache\.set/, '缺少缓存');
});

test('主页先展示渐变占位，再用解码后的图片覆盖', async () => {
  const page = await source(`${root}/pages/main/MainPage.ets`);
  assert.match(page, /this\.loadBannerPixels\(\)/, 'banner 拉取后没有异步解码');
  assert.match(page, /private bannerSource\(banner: HomeBanner\): image\.PixelMap \| string/, '缺少图片来源选择');
  const block = page.slice(page.indexOf('// ── Banner ──'), page.indexOf('// ── 公告栏 ──'));
  assert.match(block, /linearGradient/, '图片下方缺少渐变垫底');
  assert.ok(block.indexOf('linearGradient') < block.indexOf('Image(this.bannerSource'), '应先铺渐变再放图片');
  assert.match(block, /\.onError\(\(\) => this\.markBannerFailed\(banner\)\)/, '缺少失败兜底');
});

test('图片解码结果按 banner key 缓存并触发刷新', async () => {
  const page = await source(`${root}/pages/main/MainPage.ets`);
  assert.match(page, /@State private bannerPixels: Map<string, image\.PixelMap> = new Map\(\)/, '缺少 PixelMap 状态');
  assert.match(page, /this\.bannerPixels = next;/, '更新后没有触发界面刷新');
  assert.match(page, /new Map<string, image\.PixelMap>\(this\.bannerPixels\)/, '没有基于旧值复制避免原地修改');
});

test('网络加载失败被隐藏后，自行解码成功要重新显示', async () => {
  const page = await source(`${root}/pages/main/MainPage.ets`);
  assert.match(page, /this\.failedBannerKeys\.indexOf\(key\) < 0 \|\| this\.bannerPixels\.has\(key\)/,
    'visibleBanners 没有放行已解码成功的 banner');
  assert.match(page, /this\.failedBannerKeys = this\.failedBannerKeys\.filter\(\(value: string\) => value !== key\)/,
    '解码成功后没有清除失败标记');
});
