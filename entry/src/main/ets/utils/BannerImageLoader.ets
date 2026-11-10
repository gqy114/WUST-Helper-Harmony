import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';

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
  private static readonly failed: Set<string> = new Set();

  static async load(url: string): Promise<image.PixelMap | undefined> {
    const key = (url || '').trim();
    if (!key) return undefined;
    const cached = BannerImageLoader.cache.get(key);
    if (cached) return cached;
    if (BannerImageLoader.failed.has(key)) return undefined;
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
      const body = response.result as ArrayBuffer;
      if (!body || body.byteLength === 0) {
        BannerImageLoader.failed.add(key);
        return undefined;
      }
      const source = image.createImageSource(body);
      const pixelMap = await source.createPixelMap();
      source.release();
      if (!pixelMap) {
        BannerImageLoader.failed.add(key);
        return undefined;
      }
      BannerImageLoader.cache.set(key, pixelMap);
      return pixelMap;
    } catch (error) {
      console.warn('BannerImageLoader', `load banner failed: ${key} ${JSON.stringify(error)}`);
      BannerImageLoader.failed.add(key);
      return undefined;
    } finally {
      if (request) request.destroy();
    }
  }
}
