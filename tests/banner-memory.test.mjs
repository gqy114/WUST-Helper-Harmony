// 首页轮播图内存：按显示尺寸解码、并发合并、LRU 淘汰并释放。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('BannerImageLoader 按显示尺寸解码并合并并发请求', async () => {
  const loader = await source('utils/BannerImageLoader.ets');
  assert.match(loader, /MAX_CACHE_BYTES: number = 24 \* 1024 \* 1024/, '缺少缓存上限');
  assert.match(loader, /desiredSize: \{ width: decodeWidth, height: decodeHeight \}/, '没有按显示尺寸解码');
  assert.match(loader, /private static readonly inflight: Map<string, Promise<image\.PixelMap \| undefined>>/, '缺少并发请求合并');
  assert.match(loader, /BannerImageLoader\.inflight\.get\(cacheKey\)/, '并发请求没有复用');
});

test('缓存超限时按 LRU 淘汰且跳过展示中的图片', async () => {
  const loader = await source('utils/BannerImageLoader.ets');
  assert.match(loader, /setActive\(urls: string\[\]\)/, '缺少展示中 URL 标记');
  assert.match(loader, /!BannerImageLoader\.isActive\(pair\[1\]\.url\)/, '淘汰没有跳过展示中的图片');
  assert.match(loader, /victim\.pixelMap\.release\(\)/, '淘汰时没有释放 PixelMap');
  assert.match(loader, /BannerImageLoader\.totalBytes -= victim\.bytes|totalBytes - victim\.bytes/, '没有维护缓存字节数');
});

test('MainPage 传入实际显示尺寸并标记当前轮播 URL', async () => {
  const page = await source('pages/main/MainPage.ets');
  assert.match(page, /syncActiveBanner\(\)/, '没有标记当前轮播');
  assert.match(page, /BannerImageLoader\.load\(banner\.imageUrl, width, height\)/, '没有按显示尺寸加载');
  assert.match(page, /screen\.width - 32 \* screen\.densityPixels/, '宽度未按屏幕尺寸换算');
  assert.match(page, /150 \* display\.getDefaultDisplaySync\(\)\.densityPixels/, '高度未按 150vp 换算');
});
