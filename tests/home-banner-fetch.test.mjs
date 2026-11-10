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

test('断网恢复后可以重试，失败状态有有效期', async () => {
  const loader = await source(`${root}/utils/BannerImageLoader.ets`);
  assert.match(loader, /const RETRY_AFTER_MS: number = 30_000;/, '失败没有重试窗口');
  assert.match(loader, /private static recentlyFailed\(/, '没有按时间判断是否可重试');
  assert.match(loader, /BannerImageLoader\.failedAt\.delete\(key\)/, '过期或成功后没有清理失败状态');
  assert.match(loader, /static clearFailures\(\)/, '缺少重新进入页面时的清理入口');
  const page = await source(`${root}/pages/main/MainPage.ets`);
  assert.match(page, /BannerImageLoader\.clearFailures\(\)/, '重新拉取轮播图时没有清掉可重试的失败');
});

test('返回仍在运行的首页会触发失败图片重试', async () => {
  const page = await source(`${root}/pages/main/MainPage.ets`);
  const onShow = page.slice(page.indexOf('onPageShow(): void {'), page.indexOf('aboutToDisappear') > 0 ? page.indexOf('aboutToDisappear') : page.indexOf('private bannerKey'));
  assert.match(onShow, /this\.homeBanners\.some\(/, 'onPageShow 没有检查缺失的轮播图');
  assert.match(onShow, /BannerImageLoader\.clearFailures\(\)/, 'onPageShow 没有清掉失败缓存');
  assert.match(onShow, /this\.loadBannerPixels\(\)/, 'onPageShow 没有重新发起加载');
  // 已完全加载时不再重复下载
  assert.match(page, /private bannerLoading: boolean = false;/, '缺少并发保护');
});
