import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
import { ApiService } from './ApiService';

interface AppTokenResponse {
  code: number;
  message?: string;
  data?: string;
}

interface VolunteerLoginResponse {
  code?: number;
  msg?: string;
  message?: string;
  data?: string;
}

interface VolunteerEnvelope<T> {
  code?: number;
  msg?: string;
  message?: string;
  data?: T;
}

export interface VolunteerHourCodeInfo {
  activityId: string;
  volunteerCheckId: string;
  participateDate: string;
  activityName: string;
  volunteerTimes: number[];
  crater: string;
}

interface RawHourCodeInfo {
  activityId?: string | number;
  volunteerCheckId?: string | number;
  participateDate?: string;
  activityName?: string;
  volunteerTimes?: number[] | string[];
  crater?: string;
}

export class VolunteerApi {
  private static readonly APP_BASE: string = 'https://lyzyy.love:8081/api/v1';
  private static readonly VOLUNTEER_BASE: string = 'https://volunteer-api.wustlinghang.cn/volunteer';
  private static volunteerToken: string = '';

  private static async getAppAccessToken(): Promise<string> {
    const storage = AppStorage.getInstance();
    let token: string = (await storage.getAppAuthAccessToken()).trim();
    if (token.length === 0) {
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      token = (await storage.getAppAuthAccessToken()).trim();
    }
    if (token.length === 0) throw new Error('登录状态已失效，请重新登录');
    return token;
  }

  private static async login(force: boolean = false, retryAppAuth: boolean = true): Promise<string> {
    if (!force && VolunteerApi.volunteerToken.length > 0) return VolunteerApi.volunteerToken;
    const accessToken: string = await VolunteerApi.getAppAccessToken();
    const tokenResult = await HttpRequest.get<AppTokenResponse>(
      `${VolunteerApi.APP_BASE}/auth/volunteer-app-token`,
      { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' }
    );
    if (tokenResult.data.code === 401 && retryAppAuth) {
      const storage = AppStorage.getInstance();
      await storage.setAppAuthAccessToken('');
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      return VolunteerApi.login(true, false);
    }
    const appToken: string = tokenResult.data.data || '';
    if (tokenResult.data.code !== 200 || appToken.length === 0) {
      throw new Error(tokenResult.data.message || '无法获取志愿者登录凭证');
    }
    const loginResult = await HttpRequest.request<VolunteerLoginResponse>(
      `${VolunteerApi.VOLUNTEER_BASE}/login/mobile`, 'POST',
      { headers: { token: appToken, Accept: 'application/json' } }
    );
    const volunteerToken: string = loginResult.data.data || '';
    if (volunteerToken.length === 0) {
      throw new Error(loginResult.data.msg || loginResult.data.message || '志愿者系统登录失败');
    }
    VolunteerApi.volunteerToken = volunteerToken;
    return volunteerToken;
  }

  private static async lookup(code: string, retry: boolean): Promise<VolunteerEnvelope<RawHourCodeInfo>> {
    const token: string = await VolunteerApi.login(!retry);
    const result = await HttpRequest.get<VolunteerEnvelope<RawHourCodeInfo>>(
      `${VolunteerApi.VOLUNTEER_BASE}/volunteer/public/timetableInfo/?randomString=${encodeURIComponent(code)}`,
      { token, Accept: 'application/json' }
    );
    if ((result.data.code === 2004 || result.response.responseCode === 401) && retry) {
      VolunteerApi.volunteerToken = '';
      return VolunteerApi.lookup(code, false);
    }
    return result.data;
  }

  static async getHourCodeInfo(code: string): Promise<VolunteerHourCodeInfo> {
    const response = await VolunteerApi.lookup(code, true);
    if (response.code !== undefined && response.code !== 0 && response.code !== 10000) {
      throw new Error(response.msg || response.message || '工时码无效或已过期');
    }
    const data: RawHourCodeInfo | undefined = response.data;
    if (!data) throw new Error('工时码无效或已过期');
    const rawTimes: number[] | string[] = data.volunteerTimes || [];
    const times: number[] = rawTimes.map((value: number | string): number => Number(value))
      .filter((value: number): boolean => Number.isFinite(value));
    if (times.length === 0) throw new Error('该活动没有可认证的工时');
    return {
      activityId: `${data.activityId || ''}`,
      volunteerCheckId: `${data.volunteerCheckId || ''}`,
      participateDate: data.participateDate || '',
      activityName: data.activityName || '志愿活动',
      volunteerTimes: times.sort((a: number, b: number): number => a - b),
      crater: data.crater || ''
    };
  }

  private static async submit(code: string, hours: number, retry: boolean): Promise<VolunteerEnvelope<string>> {
    const token: string = await VolunteerApi.login(!retry);
    const result = await HttpRequest.postForm<VolunteerEnvelope<string>>(
      `${VolunteerApi.VOLUNTEER_BASE}/volunteer/public/time`,
      { volunteerTime: `${hours}`, randomString: code },
      { token, Accept: 'application/json' }
    );
    if ((result.data.code === 2004 || result.response.responseCode === 401) && retry) {
      VolunteerApi.volunteerToken = '';
      return VolunteerApi.submit(code, hours, false);
    }
    return result.data;
  }

  static async certifyHours(code: string, hours: number): Promise<void> {
    const response = await VolunteerApi.submit(code, hours, true);
    if (response.code !== undefined && response.code !== 0 && response.code !== 10000) {
      throw new Error(response.msg || response.message || '工时认证失败');
    }
  }
}
