import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';

/**
 * 临时失败（断网/超时）只短时间屏蔽，避免恢复网络后整个进程都不再重试。
 */
const RETRY_AFTER_MS: number = 30_000;

/**
 * Banner 图片加载器。
 *
 * 后端配置的图床偶尔会出现「HTTP 状态码不是 200，但响应体是完整图片」的情况
 * （例如 img-blog.csdnimg.cn 对部分资源返回 404 + 图片字节）。
 * ArkUI 的 Image 组件看到 404 会直接放弃渲染，所以这里自己取字节再解码：
 * 只要响应体是合法图片就展示，完全失败才回退占位。
 */
export class BannerImageLoader {
  private static readonly cache: Map<string, image.PixelMap> = new Map();
  // 记录失败时间而不是永久失败：断网恢复、重新进入首页都应该能重试。
  private static readonly failedAt: Map<string, number> = new Map();

  /** 重新拉取轮播图时调用，清掉可重试的失败状态（成功的图片缓存保留）。 */
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

  static async load(url: string): Promise<image.PixelMap | undefined> {
    const key = (url || '').trim();
    if (!key) return undefined;
    const cached = BannerImageLoader.cache.get(key);
    if (cached) return cached;
    if (BannerImageLoader.recentlyFailed(key)) return undefined;
    let request: http.HttpRequest | undefined = undefined;
    try {
      request = http.createHttp();
      const response = await request.request(key, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 20000,
        usingCache: true,
      });
      // 只接受 2xx：图床对失效图片会返回 404 + “图片违规”占位图，不能当轮播图显示。
      const status = response.responseCode;
      if (status < 200 || status >= 300) {
        BannerImageLoader.markFailed(key);
        return undefined;
      }
      const body = response.result as ArrayBuffer;
      if (!body || body.byteLength === 0) {
        BannerImageLoader.markFailed(key);
        return undefined;
      }
      const source = image.createImageSource(body);
      const pixelMap = await source.createPixelMap();
      source.release();
      if (!pixelMap) {
        BannerImageLoader.markFailed(key);
        return undefined;
      }
      BannerImageLoader.failedAt.delete(key);
      BannerImageLoader.cache.set(key, pixelMap);
      return pixelMap;
    } catch (error) {
      console.warn('BannerImageLoader', `load banner failed: ${key} ${JSON.stringify(error)}`);
      BannerImageLoader.markFailed(key);
      return undefined;
    } finally {
      if (request) request.destroy();
    }
  }
}
