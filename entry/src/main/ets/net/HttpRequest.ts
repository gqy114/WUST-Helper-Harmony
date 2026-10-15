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
      rawBody?: string;
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
      if (options?.rawBody !== undefined) {
        header['Content-Type'] = 'application/json';
        extraData = options.rawBody;
      } else if (options?.body) {
        if (options.isForm) {
          // form‑urlencoded表单格式，用于登录
          header['Content-Type'] = 'application/x-www-form-urlencoded';
          extraData = Object.entries(options.body)
            .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
            .join('&');
        } else {
          header['Content-Type'] = 'application/json';
          extraData = JSON.stringify(options.body);
        }
      }

      const response = await httpRequest.request(url, {
        method: method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header,
        extraData,
        expectDataType: options?.expectDataType ?? http.HttpDataType.STRING,
        // 教务登录接口偶尔需要较长时间完成统一认证，10 秒会被鸿蒙网络层直接中止。
        connectTimeout:30000,
        readTimeout:30000
      });
      console.info(TAG, `${method} ${url} responseCode=${response.responseCode}`);
      let data: T;
      try {
        data = JSON.parse(response.result as string) as T;
      } catch {
        // 教务取数接口在解析链第一步返回 HTML 页面串，不是 JSON。
        data = response.result as T;
      }
      return { response, data };
    } catch (err) {
      console.error(TAG, `网络请求异常：${JSON.stringify(err)}`);
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

  static async postRawJson<T>(url: string, jsonBody: string, extraHeaders?: Record<string, string>): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'POST', { headers: extraHeaders, expectDataType: http.HttpDataType.STRING, rawBody: jsonBody });
  }
}
