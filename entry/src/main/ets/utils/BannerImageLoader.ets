import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';

/**
 * 临时失败（断网/超时）只短时间屏蔽，避免恢复网络后整个进程都不再重试。
 */
const RETRY_AFTER_MS: number = 30_000;
/** 轮播图解码缓存上限，超出后按 LRU 淘汰不在展示中的图片。 */
const MAX_CACHE_BYTES: number = 24 * 1024 * 1024;
const MAX_DECODE_WIDTH: number = 1440;
const MAX_DECODE_HEIGHT: number = 720;

interface BannerCacheEntry {
  url: string;
  pixelMap: image.PixelMap;
  bytes: number;
}

/**
 * Banner 图片加载器。
 *
 * - 按实际显示尺寸解码，避免原图直接进内存；
 * - 同一 URL + 尺寸的并发请求合并；
 * - 全局 LRU 缓存，超过上限时释放不再展示的 PixelMap。
 */
export class BannerImageLoader {
  private static readonly cache: Map<string, BannerCacheEntry> = new Map();
  private static readonly inflight: Map<string, Promise<image.PixelMap | undefined>> = new Map();
  // 当前轮播仍可能展示的 URL；淘汰时跳过，避免释放使用中的图片。
  private static activeUrls: string[] = [];
  private static totalBytes: number = 0;
  private static readonly failedAt: Map<string, number> = new Map();

  static setActive(urls: string[]): void {
    BannerImageLoader.activeUrls = urls.slice();
    BannerImageLoader.evictIfNeeded();
  }

  static clearFailures(): void {
    BannerImageLoader.failedAt.clear();
  }

  private static recentlyFailed(key: string): boolean {
    const at = BannerImageLoader.failedAt.get(key);
    if (at === undefined) return false;
    if (Date.now() - at >= RETRY_AFTER_MS) {
      BannerImageLoader.failedAt.delete(key);
      return false;
    }
    return true;
  }

  private static markFailed(key: string): void {
    BannerImageLoader.failedAt.set(key, Date.now());
  }

  private static isActive(url: string): boolean {
    return BannerImageLoader.activeUrls.indexOf(url) >= 0;
  }

  private static touch(key: string, entry: BannerCacheEntry): void {
    BannerImageLoader.cache.delete(key);
    BannerImageLoader.cache.set(key, entry);
  }

  private static evictIfNeeded(): void {
    while (BannerImageLoader.totalBytes > MAX_CACHE_BYTES) {
      let victimKey = '';
      let victim: BannerCacheEntry | undefined = undefined;
      for (const pair of BannerImageLoader.cache) {
        if (!BannerImageLoader.isActive(pair[1].url)) {
          victimKey = pair[0];
          victim = pair[1];
          break;
        }
      }
      if (!victim) break;
      BannerImageLoader.cache.delete(victimKey);
      BannerImageLoader.totalBytes = Math.max(0, BannerImageLoader.totalBytes - victim.bytes);
      victim.pixelMap.release();
    }
  }

  private static cacheKey(url: string, width: number, height: number): string {
    return `${url}@${width}x${height}`;
  }

  private static async fetchPixelMap(url: string, width: number, height: number): Promise<image.PixelMap | undefined> {
    let request: http.HttpRequest | undefined = undefined;
    try {
      request = http.createHttp();
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 20000,
        usingCache: true,
      });
      // 某些图床会返回 404 但响应体是完整图片，只以字节能解码为准。
      const body = response.result as ArrayBuffer;
      if (!body || body.byteLength === 0) return undefined;
      const source = image.createImageSource(body);
      try {
        const decodeWidth = Math.max(1, Math.min(Math.round(width), MAX_DECODE_WIDTH));
        const decodeHeight = Math.max(1, Math.min(Math.round(height), MAX_DECODE_HEIGHT));
        const pixelMap = await source.createPixelMap({
          desiredSize: { width: decodeWidth, height: decodeHeight }
        });
        return pixelMap;
      } finally {
        source.release();
      }
    } catch (error) {
      console.warn('BannerImageLoader', `load banner failed: ${JSON.stringify(error)}`);
      return undefined;
    } finally {
      if (request) request.destroy();
    }
  }

  static async load(url: string, displayWidth: number = 0, displayHeight: number = 0): Promise<image.PixelMap | undefined> {
    const key = (url || '').trim();
    if (!key) return undefined;
    const width = displayWidth > 0 ? displayWidth : 360;
    const height = displayHeight > 0 ? displayHeight : 150;
    const cacheKey = BannerImageLoader.cacheKey(key, Math.round(width), Math.round(height));
    const cached = BannerImageLoader.cache.get(cacheKey);
    if (cached) {
      BannerImageLoader.touch(cacheKey, cached);
      return cached.pixelMap;
    }
    if (BannerImageLoader.recentlyFailed(cacheKey)) return undefined;

    const pending = BannerImageLoader.inflight.get(cacheKey);
    if (pending) return pending;

    const task: Promise<image.PixelMap | undefined> = (async (): Promise<image.PixelMap | undefined> => {
      const pixelMap = await BannerImageLoader.fetchPixelMap(key, width, height);
      if (!pixelMap) {
        BannerImageLoader.markFailed(cacheKey);
        return undefined;
      }
      const bytes = pixelMap.getPixelBytesNumber();
      const entry: BannerCacheEntry = { url: key, pixelMap, bytes };
      BannerImageLoader.cache.set(cacheKey, entry);
      BannerImageLoader.totalBytes += bytes;
      BannerImageLoader.evictIfNeeded();
      BannerImageLoader.failedAt.delete(cacheKey);
      return pixelMap;
    })();
    BannerImageLoader.inflight.set(cacheKey, task);
    try {
      return await task;
    } finally {
      BannerImageLoader.inflight.delete(cacheKey);
    }
  }
}
