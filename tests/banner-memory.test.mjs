// 首页轮播图内存：按显示尺寸解码、并发合并、LRU 淘汰并释放。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { createContext, SourceTextModule, SyntheticModule } from 'node:vm';

const source = (path) => readFile(new URL(`../entry/src/main/ets/${path}`, import.meta.url), 'utf8');

test('BannerImageLoader 按显示尺寸解码并合并并发请求', async () => {
  const loader = await source('utils/BannerImageLoader.ets');
  assert.match(loader, /MAX_CACHE_BYTES: number = 24 \* 1024 \* 1024/, '缺少缓存上限');
  assert.match(loader, /Math\.min\(1, decodeWidth \/ size\.width, decodeHeight \/ size\.height\)/, '没有按显示尺寸解码');
  assert.match(loader, /private static readonly inflight: Map<string, Promise<image\.PixelMap \| undefined>>/, '缺少并发请求合并');
  assert.match(loader, /BannerImageLoader\.inflight\.get\(cacheKey\)/, '并发请求没有复用');
});

test('缓存超限时按 LRU 淘汰且跳过展示中的图片', async () => {
  const loader = await source('utils/BannerImageLoader.ets');
  assert.match(loader, /setActive\(keys: string\[\]\)/, '缺少展示中 URL 标记');
  assert.match(loader, /!BannerImageLoader\.isActive\(pair\[0\]\)/, '淘汰没有跳过展示中的图片');
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

test('只加载当前横幅，未解码时用本地占位，404 图片仍可解码', async () => {
  const page = await source('pages/main/MainPage.ets');
  const loader = await source('utils/BannerImageLoader.ets');
  assert.match(loader, /status !== 404 &&/);
  assert.match(page, /const banner = this\.activeBanner\(\)/);
  assert.match(page, /this\.pendingBannerKeys\.has\(key\)/);
  assert.match(page, /return this\.bannerPixel\(banner\) \?\? \$r\('app\.media\.default_banner'\)/);
});

test('同一图片更换解码尺寸时只保护当前尺寸，旧尺寸按上限释放', async () => {
  const context = createContext({ console });
  const mod = new SourceTextModule(stripTypeScriptTypes(await source('utils/BannerImageLoader.ets'), {
    mode: 'transform',
  }), { context });
  const http = {
    createHttp: () => ({ request: async () => ({ responseCode: 200, result: new ArrayBuffer(10) }), destroy() {} }),
    RequestMethod: { GET: 1 }, HttpDataType: { ARRAY_BUFFER: 1 },
  };
  let released = 0;
  const sizes = [];
  const image = { createImageSource: () => ({
    getImageInfo: async () => ({ size: { width: 1200, height: 600 } }),
    createPixelMap: async options => {
      sizes.push([options.desiredSize.width, options.desiredSize.height]);
      return { getPixelBytesNumber: () => 9 * 1024 * 1024, release: () => released++ };
    },
    release() {},
  }) };
  await mod.link(path => {
    const [name, dependency] = path === '@kit.NetworkKit' ? ['http', http] : ['image', image];
    return new SyntheticModule([name], function () { this.setExport(name, dependency); }, { context });
  });
  await mod.evaluate();
  const loader = mod.namespace.BannerImageLoader;
  const url = 'https://example.test/banner';
  for (const width of [700, 900, 1100]) {
    loader.setActive([loader.displayKey(url, width, 300)]);
    const bitmap = await loader.load(url, width, 300);
    assert.ok(loader.owns(bitmap));
    assert.ok(loader.totalBytes <= 24 * 1024 * 1024);
  }
  assert.equal(released, 1);
  assert.deepEqual(sizes, [[600, 300], [600, 300], [600, 300]]);
});
