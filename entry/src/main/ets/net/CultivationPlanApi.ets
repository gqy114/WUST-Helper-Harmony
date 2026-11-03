import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
import { TeachingSessionService } from '../service/TeachingSessionService';

interface CultivationPlanResponse {
  code?: number;
  message?: string;
  msg?: string;
  data?: string;
}

interface CultivationPlanHeaders extends Record<string, string> {
  Accept: string;
  Cookie: string;
  Authorization: string;
  Token: string;
}

/** 培养方案正文接口。返回完整 HTML，不能使用主修进度统计接口代替。 */
export class CultivationPlanApi {
  private static readonly UNDERGRADUATE_URLS: string[] = [
    'https://lyzyy.love:8081/UnderGraduate/Support/getTrainingPlanPage',
    'http://port.happylandmc.cc:52144/UnderGraduate/Support/getTrainingPlanPage'
  ];

  private static successful(code: number | undefined): boolean {
    return code === undefined || code === 0 || code === 200 || code === 10000 || code === 11000;
  }

  private static async teachingCookie(forceRefresh: boolean = false): Promise<string> {
    const storage = AppStorage.getInstance();
    let cookie = (await storage.getToken()).trim();
    if (forceRefresh || cookie.length === 0) {
      const refreshed = await TeachingSessionService.ensureSession(true);
      if (refreshed) cookie = (await storage.getToken()).trim();
    }
    if (cookie.length === 0) throw new Error('教务登录状态已失效，暂时无法获取培养方案');
    return cookie;
  }

  private static async fetchUndergraduate(retry: boolean = true): Promise<string> {
    const cookie = await CultivationPlanApi.teachingCookie(false);
    const headers: CultivationPlanHeaders = {
      Accept: 'application/json',
      Cookie: cookie,
      Authorization: `Bearer ${cookie}`,
      Token: cookie
    };
    let lastMessage: string = '';
    let unauthorized: boolean = false;

    for (const url of CultivationPlanApi.UNDERGRADUATE_URLS) {
      try {
        const result = await HttpRequest.request<CultivationPlanResponse>(url, 'GET', {
          headers,
          pinBackend: true
        });
        const response = result.data;
        const message = response?.message || response?.msg || '';
        const currentUnauthorized = result.response.responseCode === 401 ||
          result.response.responseCode === 403 || response?.code === 401 || response?.code === 403 ||
          /unauthorized|missing cookie|登录状态|登录失效/i.test(message);
        unauthorized = unauthorized || currentUnauthorized;
        if (response && CultivationPlanApi.successful(response.code) &&
          typeof response.data === 'string' && response.data.trim().length > 0) {
          return response.data;
        }
        if (message.trim().length > 0) lastMessage = message;
      } catch (error) {
        if (error instanceof Error && error.message.trim().length > 0) lastMessage = error.message;
      }
    }

    if (unauthorized && retry) {
      await CultivationPlanApi.teachingCookie(true);
      return CultivationPlanApi.fetchUndergraduate(false);
    }
    if (unauthorized) throw new Error('教务登录状态已失效，请稍后重试');
    throw new Error(lastMessage || '培养方案加载失败');
  }

  private static async fetchGraduate(): Promise<string> {
    const storage = AppStorage.getInstance();
    const result = await HttpRequest.postJson<string>('https://www.lyzyy.love:8007/cultivation-plan', {
      student_id: await storage.getStudentId(),
      password: await storage.getPassword()
    });
    if (typeof result.data === 'string' && result.data.trim().length > 0) return result.data;

    const response = result.data as CultivationPlanResponse;
    if (typeof response?.data === 'string' && response.data.trim().length > 0) return response.data;
    throw new Error(response?.message || response?.msg || '培养方案数据为空');
  }

  static async fetchHtml(): Promise<string> {
    const storage = AppStorage.getInstance();
    if (await storage.getIsGraduate()) return CultivationPlanApi.fetchGraduate();
    return CultivationPlanApi.fetchUndergraduate();
  }
}
