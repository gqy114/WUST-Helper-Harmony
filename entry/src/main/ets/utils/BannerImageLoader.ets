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
  // 当前轮播展示的 URL 和解码尺寸；淘汰时跳过，避免释放使用中的图片。
  private static activeKeys: string[] = [];
  private static totalBytes: number = 0;
  private static readonly failedAt: Map<string, number> = new Map();

  static setActive(keys: string[]): void {
    BannerImageLoader.activeKeys = keys.slice();
    BannerImageLoader.evictIfNeeded();
  }

  static owns(pixelMap: image.PixelMap): boolean {
    for (const entry of BannerImageLoader.cache.values()) {
      if (entry.pixelMap === pixelMap) return true;
    }
    return false;
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

  private static isActive(key: string): boolean {
    return BannerImageLoader.activeKeys.indexOf(key) >= 0;
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
        if (!BannerImageLoader.isActive(pair[0])) {
          victimKey = pair[0];
          victim = pair[1];
          break;
        }
      }
      if (!victim) {
        // 调用方只保护当前显示的一张；即使误传多个键，缓存也必须维持上限。
        const oldest = BannerImageLoader.cache.entries().next();
        if (oldest.done) break;
        victimKey = oldest.value[0];
        victim = oldest.value[1];
      }
      BannerImageLoader.cache.delete(victimKey);
      BannerImageLoader.totalBytes = Math.max(0, BannerImageLoader.totalBytes - victim.bytes);
      victim.pixelMap.release();
    }
  }

  static displayKey(url: string, width: number, height: number): string {
    const decodeWidth = Math.max(1, Math.min(Math.round(width > 0 ? width : 360), MAX_DECODE_WIDTH));
    const decodeHeight = Math.max(1, Math.min(Math.round(height > 0 ? height : 150), MAX_DECODE_HEIGHT));
    return `${url.trim()}@${decodeWidth}x${decodeHeight}`;
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
      const status = response.responseCode;
      // 部分图床用 404 返回有效图片，交给解码器判断；HTML 等错误响应无法解码。
      if (status !== 404 && (status < 200 || status >= 300)) return undefined;
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
    const cacheKey = BannerImageLoader.displayKey(key, width, height);
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
      if (bytes > MAX_CACHE_BYTES) {
        pixelMap.release();
        return undefined;
      }
      const entry: BannerCacheEntry = { pixelMap, bytes };
      BannerImageLoader.cache.set(cacheKey, entry);
      BannerImageLoader.totalBytes += bytes;
      BannerImageLoader.evictIfNeeded();
      BannerImageLoader.failedAt.delete(cacheKey);
      return BannerImageLoader.cache.has(cacheKey) ? pixelMap : undefined;
    })();
    BannerImageLoader.inflight.set(cacheKey, task);
    try {
      return await task;
    } finally {
      BannerImageLoader.inflight.delete(cacheKey);
    }
  }
}
