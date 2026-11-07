/**
 * 低层 HTTP 封装，对应原 Android 端 OkHttp + CommonRequest
 */
import { http } from '@kit.NetworkKit';
import { AppStorage } from '../store/AppStorage';

const TAG = 'HttpRequest';

export type HttpMethod = 'GET' | 'POST';

export interface RequestResult<T> {
  response: http.HttpResponse;
  data: T;
}

interface BackendTarget {
  url: string;
  index: number;
}

export class HttpRequest {
  private static readonly BACKENDS: string[] = [
    'https://lyzyy.love:8081',
    'http://port.happylandmc.cc:52144'
  ];
  private static preferredBackend: number = 0;

  static getPreferredBackendBase(): string {
    return HttpRequest.BACKENDS[HttpRequest.preferredBackend];
  }

  private static backendTargets(url: string, pinBackend: boolean = false,
    secure: boolean = false): BackendTarget[] {
    const mainMatch = url.match(/^https?:\/\/(?:www\.)?lyzyy\.love(?::8081)?(?=\/|$)/i);
    const backupMatch = url.match(/^http:\/\/port\.happylandmc\.cc:52144(?=\/|$)/i);
    const matched = mainMatch?.[0] || backupMatch?.[0] || '';
    if (!matched) return [{ url, index: -1 }];
    if (pinBackend) {
      const pinned = [{ url, index: backupMatch ? 1 : 0 }];
      return secure ? pinned.filter((item: BackendTarget) => item.url.startsWith('https://')) : pinned;
    }
    const path = url.substring(matched.length);
    const first = HttpRequest.preferredBackend;
    const second = first === 0 ? 1 : 0;
    const targets: BackendTarget[] = [
      { url: `${HttpRequest.BACKENDS[first]}${path}`, index: first },
      { url: `${HttpRequest.BACKENDS[second]}${path}`, index: second }
    ];
    // 含学号/密码/令牌的请求只允许走证书校验过的 HTTPS 节点，
    // 不允许因为节点故障或首选节点切换而降级到 HTTP。
    return secure ? targets.filter((item: BackendTarget) => item.url.startsWith('https://')) : targets;
  }

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
      /** 多步骤会话必须固定在创建会话的节点，不参与故障切换。 */
      pinBackend?: boolean;
      /** 自定义读取超时；研究生登录/课表要后端现登录，耗时明显长于普通接口。 */
      readTimeoutMs?: number;
      /** 敏感请求（学号、密码、令牌）：只允许 HTTPS 节点。 */
      secure?: boolean;
    },
  ): Promise<RequestResult<T>> {
    {
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

      let requestUrl = url;
      let requestMethod = method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST;
      if (await HttpRequest.shouldUseCampusProxy(url)) {
        extraData = JSON.stringify({ method, url, headers: header, body: extraData ?? '' });
        requestUrl = 'https://lyzyy.love:8081/CampusProxy/Support/request';
        requestMethod = http.RequestMethod.POST;
        header = { 'Content-Type': 'application/json' };
        console.info(TAG, `campus proxy enabled for ${method} ${url}`);
      }

      const targets = HttpRequest.backendTargets(requestUrl, options?.pinBackend ?? false,
        options?.secure ?? false);
      if (targets.length === 0) {
        // 敏感请求找不到 HTTPS 节点时直接失败，绝不降级到 HTTP。
        throw new Error('sensitive request requires https backend');
      }
      for (let index = 0; index < targets.length; index++) {
        const target = targets[index];
        const httpRequest = http.createHttp();
        try {
          const response = await httpRequest.request(target.url, {
            method: requestMethod,
            header,
            extraData,
            expectDataType: options?.expectDataType ?? http.HttpDataType.STRING,
            // 多节点按顺序尝试，单节点连接超时不宜过长。
            connectTimeout: 10000,
            readTimeout: options?.readTimeoutMs ?? 20000
          });
          console.info(TAG, `${method} ${target.url} responseCode=${response.responseCode}`);
          const unavailable = response.responseCode === 502 || response.responseCode === 503 || response.responseCode === 504;
          if (target.index >= 0 && unavailable && index + 1 < targets.length) {
            HttpRequest.preferredBackend = targets[index + 1].index;
            // 写请求可能已经到达后端，不在公共层自动重放；下次请求使用新首选节点。
            if (method === 'GET') continue;
          } else if (target.index >= 0 && !unavailable) {
            HttpRequest.preferredBackend = target.index;
          }
          let data: T;
          try {
            data = JSON.parse(response.result as string) as T;
          } catch {
            // 教务取数接口在解析链第一步返回 HTML 页面串，不是 JSON。
            data = response.result as T;
          }
          return { response, data };
        } catch (err) {
          console.error(TAG, `网络请求异常 ${target.url}：${JSON.stringify(err)}`);
          if (target.index >= 0 && index + 1 < targets.length) {
            HttpRequest.preferredBackend = targets[index + 1].index;
            if (method === 'GET') continue;
          }
          throw err;
        } finally {
          httpRequest.destroy();
        }
      }
      throw new Error('all backend nodes unavailable');
    }
  }

  private static async shouldUseCampusProxy(url: string): Promise<boolean> {
    const enabled = await AppStorage.getInstance().getSettingBool('useCampusProxy', false);
    return enabled && /^https:\/\/([a-z0-9-]+\.)*wust\.edu\.cn(?::\d+)?(?:\/|$)/i.test(url);
  }

  /** post json请求 */
  static async postJson<T>(
    url: string,
    body: Record<string, string>,
    extraHeaders?: Record<string, string>,
    readTimeoutMs?: number,
    secure: boolean = false,
  ): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'POST', {
      body,
      headers: extraHeaders,
      isForm:false,
      readTimeoutMs,
      secure
    });
  }

  /** 发送到 URL 指定的节点，用于必须保持同一服务端会话的多步骤请求。 */
  static async postJsonPinned<T>(
    url: string,
    body: Record<string, string>,
    extraHeaders?: Record<string, string>,
    secure: boolean = false,
  ): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'POST', {
      body,
      headers: extraHeaders,
      isForm: false,
      pinBackend: true,
      secure
    });
  }

  /** post form表单，登录要用这个！ */
  static async postForm<T>(
    url: string,
    body: Record<string, string>,
    extraHeaders?: Record<string, string>,
    secure: boolean = false,
  ): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'POST', {
      body,
      headers: extraHeaders,
      isForm:true,
      secure
    });
  }

  static async get<T>(
    url: string,
    extraHeaders?: Record<string, string>,
    secure: boolean = false,
  ): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'GET', { headers: extraHeaders, secure });
  }

  static async postRawJson<T>(url: string, jsonBody: string, extraHeaders?: Record<string, string>,
    secure: boolean = false): Promise<RequestResult<T>> {
    return HttpRequest.request<T>(url, 'POST', {
      headers: extraHeaders,
      expectDataType: http.HttpDataType.STRING,
      rawBody: jsonBody,
      secure
    });
  }
}



