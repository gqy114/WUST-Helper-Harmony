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
  data?: string | VolunteerTokenData;
}

interface VolunteerTokenData {
  token?: string;
  platformToken?: string;
  accessToken?: string;
  jwt?: string;
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

interface RawVolunteerSummary {
  timePassed?: string | number;
  sumTime?: string | number;
  totalTime?: string | number;
  timeToBePassed?: string | number;
  pendingTime?: string | number;
  activityJoined?: string | number;
  activityCount?: string | number;
}

interface RawVolunteerLog {
  activityName?: string;
  actName?: string;
  title?: string;
  name?: string;
  organizationName?: string;
  orgName?: string;
  participateDate?: string;
  activityDate?: string;
  createTime?: string;
  activityStartTime?: string;
  createDate?: string;
  date?: string;
  volunteerTime?: string | number;
  sumTime?: string | number;
  hours?: string | number;
  time?: string | number;
  volunteerStatus?: string | number;
  volunteerStatusName?: string | number;
  auditStatusName?: string | number;
  auditStatus?: string | number;
  statusName?: string | number;
  status?: string | number;
  crater?: string;
  creator?: string;
}

interface RawVolunteerActivity {
  id?: string | number;
  activityId?: string | number;
  recruitId?: string | number;
  title?: string;
  name?: string;
  activityName?: string;
  activityTime?: string;
  time?: string;
  holdTime?: string;
  recruitTime?: string;
  date?: string;
  activityPlace?: string;
  location?: string;
  place?: string;
  address?: string;
  site?: string;
  recruitNum?: string | number;
  count?: string | number;
  people?: string | number;
  num?: string | number;
}

interface VolunteerPagePayload<T> {
  list?: T[];
  records?: T[];
  currPage?: number;
  totalPage?: number;
  pageSize?: number;
  totalCount?: number;
}

export interface VolunteerSummary {
  certifiedHours: number;
  uncertifiedHours: number;
  participatedCount: number;
}

export interface VolunteerLog {
  activityName: string;
  organizationName: string;
  participateDate: string;
  hours: number;
  certified: boolean;
  creator: string;
}

export interface VolunteerActivity {
  id: string;
  title: string;
  time: string;
  location: string;
  recruitNum: string;
}

export interface VolunteerPageData {
  summary: VolunteerSummary;
  logs: VolunteerLog[];
  activities: VolunteerActivity[];
}

export class VolunteerApi {
  private static readonly APP_BASE: string = 'https://lyzyy.love:8081/api/v1';
  private static readonly VOLUNTEER_BASE: string = 'https://volunteer-api.wustlinghang.cn/volunteer';
  private static volunteerToken: string = '';

  private static isSuccess(code: number | undefined): boolean {
    return code === undefined || code === 0 || code === 200 || code === 10000 || code === 11000;
  }

  private static isExpired(code: number | undefined, responseCode: number): boolean {
    return code === 2004 || code === 401 || responseCode === 401;
  }

  private static extractToken(data: string | VolunteerTokenData | undefined): string {
    if (typeof data === 'string') return data.replace(/^Bearer\s+/i, '').trim();
    if (!data) return '';
    return (data.token || data.platformToken || data.accessToken || data.jwt || '').replace(/^Bearer\s+/i, '').trim();
  }

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
    const directLogin = await HttpRequest.request<VolunteerLoginResponse>(
      `${VolunteerApi.VOLUNTEER_BASE}/login/mobile`, 'POST',
      { headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' } }
    );
    if (VolunteerApi.isExpired(directLogin.data.code, directLogin.response.responseCode) && retryAppAuth) {
      const storage = AppStorage.getInstance();
      await storage.setAppAuthAccessToken('');
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      return VolunteerApi.login(true, false);
    }
    let volunteerToken: string = VolunteerApi.extractToken(directLogin.data.data);
    if (VolunteerApi.isSuccess(directLogin.data.code) && volunteerToken.length > 0) {
      VolunteerApi.volunteerToken = volunteerToken;
      return volunteerToken;
    }

    // 兼容仍要求中转 appToken 的旧志愿后端。
    const tokenResult = await HttpRequest.get<AppTokenResponse>(
      `${VolunteerApi.APP_BASE}/auth/volunteer-app-token`,
      { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' }
    );
    const appToken: string = tokenResult.data.data || '';
    if (tokenResult.data.code !== 200 || appToken.length === 0) {
      throw new Error(directLogin.data.msg || directLogin.data.message || tokenResult.data.message || '无法获取志愿者登录凭证');
    }
    const legacyLogin = await HttpRequest.request<VolunteerLoginResponse>(
      `${VolunteerApi.VOLUNTEER_BASE}/login/mobile`, 'POST',
      { headers: { token: appToken, Accept: 'application/json' } }
    );
    volunteerToken = VolunteerApi.extractToken(legacyLogin.data.data);
    if (volunteerToken.length === 0) {
      throw new Error(legacyLogin.data.msg || legacyLogin.data.message || '志愿者系统登录失败');
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

  private static numberValue(value: string | number | undefined): number {
    if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
    const raw: string = `${value ?? ''}`.trim().replace(/,/g, '');
    if (raw.length === 0) return 0;
    const direct: number = Number(raw);
    if (Number.isFinite(direct)) return direct;
    // 兼容后端返回的“8小时”“10.5h”等展示字符串。
    const match: RegExpMatchArray | null = raw.match(/-?\d+(?:\.\d+)?/);
    const parsed: number = match && match[0] ? Number(match[0]) : 0;
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private static async getSummaryInternal(retry: boolean): Promise<VolunteerSummary> {
    const token: string = await VolunteerApi.login(!retry);
    const result = await HttpRequest.get<VolunteerEnvelope<RawVolunteerSummary>>(
      `${VolunteerApi.VOLUNTEER_BASE}/volunteer/public/sumTime`,
      { token, Accept: 'application/json' }
    );
    if (VolunteerApi.isExpired(result.data.code, result.response.responseCode) && retry) {
      VolunteerApi.volunteerToken = '';
      return VolunteerApi.getSummaryInternal(false);
    }
    if (!VolunteerApi.isSuccess(result.data.code)) {
      throw new Error(result.data.msg || result.data.message || '工时统计拉取失败');
    }
    const data: RawVolunteerSummary = result.data.data || {};
    return {
      certifiedHours: VolunteerApi.numberValue(data.timePassed ?? data.sumTime ?? data.totalTime),
      uncertifiedHours: VolunteerApi.numberValue(data.timeToBePassed ?? data.pendingTime),
      participatedCount: VolunteerApi.numberValue(data.activityJoined ?? data.activityCount)
    };
  }

  private static logItems(data: VolunteerPagePayload<RawVolunteerLog> | RawVolunteerLog[] | undefined): RawVolunteerLog[] {
    if (!data) return [];
    if (Array.isArray(data)) return data;
    return data.list || data.records || [];
  }

  private static activityItems(data: VolunteerPagePayload<RawVolunteerActivity> | RawVolunteerActivity[] | undefined): RawVolunteerActivity[] {
    if (!data) return [];
    if (Array.isArray(data)) return data;
    return data.records || data.list || [];
  }

  private static totalPages<T>(data: VolunteerPagePayload<T> | T[] | undefined): number {
    if (!data || Array.isArray(data)) return 1;
    if (data.totalPage && data.totalPage > 0) return data.totalPage;
    if (data.totalCount && data.pageSize && data.pageSize > 0) return Math.ceil(data.totalCount / data.pageSize);
    return 1;
  }

  private static mapLog(raw: RawVolunteerLog): VolunteerLog {
    const statusValue: string | number | undefined = raw.volunteerStatusName ?? raw.auditStatusName ??
      raw.auditStatus ?? raw.statusName ?? raw.volunteerStatus ?? raw.status;
    const status: string = `${statusValue ?? ''}`.trim().toLowerCase();
    const hours: number = VolunteerApi.numberValue(raw.volunteerTime ?? raw.sumTime ?? raw.hours ?? raw.time);
    let certified: boolean = status === '5';
    if (!certified && status.length > 0) {
      const positive: boolean = status.includes('已认证') || status.includes('审核通过') ||
        status.includes('认证通过') || status.includes('已通过') || status === '通过' ||
        status.includes('passed') || status.includes('approved') || status.includes('certified');
      const negative: boolean = status.includes('未认证') || status.includes('待认证') ||
        status.includes('待审核') || status.includes('未通过') || status.includes('驳回') ||
        status.includes('pending') || status.includes('unapproved') || status.includes('rejected');
      certified = positive && !negative;
    }
    // 老接口的工时明细只有已审核记录且不返回状态字段；有有效工时即视作已认证。
    if (status.length === 0 && hours > 0) certified = true;
    return {
      activityName: raw.activityName || raw.name || raw.title || raw.actName || '志愿活动',
      organizationName: raw.organizationName || raw.orgName || '',
      participateDate: `${raw.participateDate || raw.createTime || raw.activityStartTime ||
        raw.activityDate || raw.time || raw.date || raw.createDate || ''}`,
      hours,
      certified,
      creator: raw.crater || raw.creator || ''
    };
  }

  private static mapActivity(raw: RawVolunteerActivity): VolunteerActivity {
    const people: string | number | undefined = raw.recruitNum ?? raw.count ?? raw.people ?? raw.num;
    return {
      id: `${raw.id ?? raw.activityId ?? raw.recruitId ?? ''}`,
      title: raw.title || raw.name || raw.activityName || '招募活动',
      time: raw.activityTime || raw.time || raw.holdTime || raw.recruitTime || raw.date || '',
      location: raw.activityPlace || raw.location || raw.place || raw.address || raw.site || '学校',
      recruitNum: people === undefined ? '不限' : `${people}`.replace(/\.0$/, '')
    };
  }

  private static async getLogsInternal(retry: boolean): Promise<VolunteerLog[]> {
    const token: string = await VolunteerApi.login(!retry);
    const logs: VolunteerLog[] = [];
    let lastFingerprint: string = '';
    for (let page: number = 1; page <= 100; page++) {
      const result = await HttpRequest.get<VolunteerEnvelope<VolunteerPagePayload<RawVolunteerLog> | RawVolunteerLog[]>>(
        `${VolunteerApi.VOLUNTEER_BASE}/volunteer/public/volunteerTime?currPage=${page}`,
        { token, Accept: 'application/json' }
      );
      if (VolunteerApi.isExpired(result.data.code, result.response.responseCode) && retry) {
        VolunteerApi.volunteerToken = '';
        return VolunteerApi.getLogsInternal(false);
      }
      if (!VolunteerApi.isSuccess(result.data.code)) {
        throw new Error(result.data.msg || result.data.message || '工时明细拉取失败');
      }
      const rawItems: RawVolunteerLog[] = VolunteerApi.logItems(result.data.data);
      if (rawItems.length === 0) break;
      const fingerprint: string = rawItems.map((item: RawVolunteerLog): string =>
        `${item.activityName || item.name || item.title || item.actName || ''}|` +
        `${item.participateDate || item.createTime || item.date || ''}|${item.volunteerTime ?? item.sumTime ?? ''}`
      ).join(';');
      if (page > 1 && fingerprint === lastFingerprint) break;
      lastFingerprint = fingerprint;
      logs.push(...rawItems.map((item: RawVolunteerLog): VolunteerLog => VolunteerApi.mapLog(item)));
      if (page >= VolunteerApi.totalPages(result.data.data)) break;
    }
    return logs;
  }

  private static async getActivitiesInternal(retry: boolean): Promise<VolunteerActivity[]> {
    const token: string = await VolunteerApi.login(!retry);
    const activities: VolunteerActivity[] = [];
    let lastFingerprint: string = '';
    for (let page: number = 1; page <= 100; page++) {
      const result = await HttpRequest.get<VolunteerEnvelope<VolunteerPagePayload<RawVolunteerActivity> | RawVolunteerActivity[]>>(
        `${VolunteerApi.VOLUNTEER_BASE}/recruit/list?currPage=${page}`,
        { token, Accept: 'application/json' }
      );
      if (VolunteerApi.isExpired(result.data.code, result.response.responseCode) && retry) {
        VolunteerApi.volunteerToken = '';
        return VolunteerApi.getActivitiesInternal(false);
      }
      if (!VolunteerApi.isSuccess(result.data.code)) {
        throw new Error(result.data.msg || result.data.message || '志愿招募拉取失败');
      }
      const rawItems: RawVolunteerActivity[] = VolunteerApi.activityItems(result.data.data);
      if (rawItems.length === 0) break;
      const fingerprint: string = rawItems.map((item: RawVolunteerActivity): string =>
        `${item.id ?? item.activityId ?? ''}|${item.title || item.activityName || ''}|${item.time || item.activityTime || ''}`
      ).join(';');
      if (page > 1 && fingerprint === lastFingerprint) break;
      lastFingerprint = fingerprint;
      activities.push(...rawItems.map((item: RawVolunteerActivity): VolunteerActivity => VolunteerApi.mapActivity(item)));
      if (page >= VolunteerApi.totalPages(result.data.data)) break;
    }
    return activities;
  }

  static async getPageData(): Promise<VolunteerPageData> {
    // 先完成登录和统计；列表接口即使单独异常，也不覆盖已拿到的真实统计。
    await VolunteerApi.login();
    const summary: VolunteerSummary = await VolunteerApi.getSummaryInternal(true);
    let logs: VolunteerLog[] = [];
    let activities: VolunteerActivity[] = [];
    try {
      logs = await VolunteerApi.getLogsInternal(true);
    } catch (error) {
      console.error('VolunteerApi', `工时明细拉取失败: ${error}`);
    }
    try {
      activities = await VolunteerApi.getActivitiesInternal(true);
    } catch (error) {
      console.error('VolunteerApi', `志愿招募拉取失败: ${error}`);
    }

    // 部分志愿后端账号的 sumTime 会错误返回全 0，以完整工时明细作为可靠兜底。
    // 明细已按全部分页拉取，因此可以准确还原活动数及认证/未认证工时。
    if (logs.length > 0) {
      let certifiedFromLogs: number = 0;
      let uncertifiedFromLogs: number = 0;
      logs.forEach((log: VolunteerLog): void => {
        if (log.certified) {
          certifiedFromLogs += log.hours;
        } else {
          uncertifiedFromLogs += log.hours;
        }
      });
      const summaryIsEmpty: boolean = summary.participatedCount === 0 &&
        summary.certifiedHours === 0 && summary.uncertifiedHours === 0;
      if (summaryIsEmpty) {
        summary.participatedCount = logs.length;
        summary.certifiedHours = certifiedFromLogs;
        summary.uncertifiedHours = uncertifiedFromLogs;
      } else {
        // 单个统计字段异常为 0 时也按可见明细纠正，正常的后端统计仍优先保留。
        if (summary.participatedCount === 0) summary.participatedCount = logs.length;
        if (summary.certifiedHours === 0 && certifiedFromLogs > 0) summary.certifiedHours = certifiedFromLogs;
        if (summary.uncertifiedHours === 0 && uncertifiedFromLogs > 0) summary.uncertifiedHours = uncertifiedFromLogs;
      }
    }
    return { summary, logs, activities };
  }

  private static async registerInternal(activityId: string, retry: boolean): Promise<void> {
    const token: string = await VolunteerApi.login(!retry);
    const result = await HttpRequest.get<VolunteerEnvelope<string>>(
      `${VolunteerApi.VOLUNTEER_BASE}/recruit/add?activityId=${encodeURIComponent(activityId)}`,
      { token, Accept: 'application/json' }
    );
    if (VolunteerApi.isExpired(result.data.code, result.response.responseCode) && retry) {
      VolunteerApi.volunteerToken = '';
      return VolunteerApi.registerInternal(activityId, false);
    }
    if (!VolunteerApi.isSuccess(result.data.code)) {
      throw new Error(result.data.msg || result.data.message || '志愿活动报名失败');
    }
  }

  static async registerActivity(activityId: string): Promise<void> {
    if (activityId.length === 0) throw new Error('该招募活动缺少报名编号');
    await VolunteerApi.registerInternal(activityId, true);
  }
}
