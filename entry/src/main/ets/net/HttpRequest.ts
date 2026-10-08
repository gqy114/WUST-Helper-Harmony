/**
 * 低层 HTTP 封装，对应原 Android 端 OkHttp + CommonRequest
 */
import { http } from '@kit.NetworkKit';

const TAG = 'HttpRequest';

export type HttpMethod = 'GET' | 'POST';

export interface RequestResult<T> {
  response: http.HttpResponse;
  data: T;
}

export class HttpRequest {
  static async request<T>(
    url: string,
    method: HttpMethod,
    options?: {
      headers?: Record<string, string>;
      body?: Record<string, string>;
      expectDataType?: http.HttpDataType;
      /** form表单，true代表application/x‑www‑form‑urlencoded */
      isForm?: boolean;
    },
  ): Promise<RequestResult<T>> {
    const httpRequest = http.createHttp();
    try {
      let header: Record<string, string> = {
        Platform: 'android',
        ...options?.headers,
      };

      let extraData: string | undefined;
      if (options?.body) {
        if (options.isForm) {
          // form‑urlencoded表单格式，用于登录
          header['Content‑Type'] = 'application/x‑www‑form‑urlencoded';
          extraData = Object.entries(options.body)
            .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
            .join('&');
        } else {
          header['Content‑Type'] = 'application/json';
          extraData = JSON.stringify(options.body);
        }
      }

      const response = await httpRequest.request(url, {
        method: method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header,
        extraData,
        expectDataType: options?.expectDataType ?? http.HttpDataType.OBJECT,
        connectTimeout:10000,
        readTimeout:10000
      });
      const data = JSON.parse(response.result as string) as T;
      return { response, data };
    } catch (err) {
      console.error(TAG, "网络请求异常：", JSON.stringify(err));
      throw err; //抛出给上层处理弹窗
    } finally {
      httpRequest.destroy();
    }
  }

  /** post json请求 */
  static async postJson<T>(
    url: string,
    body: Record<string, string>,
    extraHeaders?: Record<string, string>,
  ): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'POST', {
      body,
      headers: extraHeaders,
      isForm:false
    });
  }

  /** post form表单，登录要用这个！ */
  static async postForm<T>(
    url: string,
    body: Record<string, string>,
    extraHeaders?: Record<string, string>,
  ): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'POST', {
      body,
      headers: extraHeaders,
      isForm:true
    });
  }

  static async get<T>(
    url: string,
    extraHeaders?: Record<string, string>,
  ): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'GET', { headers: extraHeaders });
  }
}