/**
 * 业务 API 层，对应原 Android 端 NewApiHelper 中的部分方法
 * 仅包含 LaunchActivity 涉及的接口
 */
import { HttpRequest } from './HttpRequest';
import {
  BaseResponse,
  TokenDataContent,
  GraduateLoginDataContent,
  AppAuthDataContent,
} from '../model/BaseResponse';
import { AppStorage } from '../store/AppStorage';

// 从 WustApi.java 抽取的常量子集
// 登录接口以 iOS 接口文档为准：本科生换取教务 Cookie，研究生直接返回个人信息。
export const UG_LOGIN_V2 = 'https://www.lyzyy.love/UnderGraduate/Support/loginGetCookie';
const UG_LOGIN_V2_BACKUP = 'https://lyzyy.love/UnderGraduate/Support/loginGetCookie';
export const GRADUATE_LOGIN_V2 = 'https://www.lyzyy.love:8009/personal-info';
const GRADUATE_LOGIN_V2_BACKUP = 'https://lyzyy.love:8009/personal-info';
export const APP_AUTH_LOGIN = 'https://lyzyy.love:8081/api/v1/auth/login';
const APP_AUTH_LOGIN_BACKUP = 'https://www.lyzyy.love:8081/api/v1/auth/login';
const UG_TWO_VERIFY_SEND = 'https://www.lyzyy.love/UnderGraduate/Support/twoVerify/sendCode';
const UG_TWO_VERIFY_CHECK = 'https://www.lyzyy.love/UnderGraduate/Support/twoVerify/verify';

interface UndergradLoginResponse {
  code: number;
  msg?: string;
  message?: string;
  data?: TokenDataContent | string;
  dataObject?: TokenDataContent;
}

export class ApiService {
  static async sendUndergradVerifyCode(state: string): Promise<BaseResponse<{ cooldown_seconds?: number }>> {
    const result = await HttpRequest.postJson<BaseResponse<{ cooldown_seconds?: number }>>(UG_TWO_VERIFY_SEND, { state });
    return result.data;
  }

  static async verifyUndergradCode(state: string, code: string): Promise<BaseResponse<TokenDataContent>> {
    const result = await HttpRequest.postJson<BaseResponse<TokenDataContent>>(UG_TWO_VERIFY_CHECK, { state, code });
    return result.data;
  }
  /** Mock helper: wrap success response */
  private static mockSuccess<T>(data: T): BaseResponse<T> {
    return { code: 200, msg: 'ok', data };
  }

  /** 本科生登录（同步风格，返回 Response 用于解析 TokenData） */
  static async loginUndergrad(
    studentId: string,
    password: string,
  ): Promise<BaseResponse<TokenDataContent>> {
        if (await AppStorage.getInstance().getUseMock()) {
      return ApiService.mockSuccess<TokenDataContent>({
        token: 'mock_token_' + studentId,
        student_id: studentId,
        student_type: 'undergrad',
      });
    }
    let data: UndergradLoginResponse;
    try {
      const result = await HttpRequest.postJson<UndergradLoginResponse>(UG_LOGIN_V2, { username: studentId, password });
      data = result.data;
      // 旧版教务接口使用 form-urlencoded；JSON 返回非成功码时兼容重试。
      if (data.code !== 200) {
        const formResult = await HttpRequest.postForm<UndergradLoginResponse>(UG_LOGIN_V2, { username: studentId, password });
        if (formResult.data.code === 200) data = formResult.data;
      }
    } catch {
      try {
        const result = await HttpRequest.postJson<UndergradLoginResponse>(UG_LOGIN_V2_BACKUP, { username: studentId, password });
        data = result.data;
      } catch {
        const formResult = await HttpRequest.postForm<UndergradLoginResponse>(UG_LOGIN_V2_BACKUP, { username: studentId, password });
        data = formResult.data;
      }
    }
    console.info('ApiService', `undergrad login response code=${data.code}, hasData=${data.data !== undefined}, hasDataObject=${data.dataObject !== undefined}`);
    if (typeof data.data === 'string') {
      return {
        code: data.code,
        msg: data.msg ?? data.message ?? '',
        data: { token: data.data, student_id: studentId, student_type: 'undergrad' },
      };
    }
    return {
      code: data.code,
      msg: data.msg ?? data.message ?? '',
      data: data.data ?? data.dataObject,
    };
  }

  /** 研究生登录 */
  static async loginGraduate(
    studentId: string,
    password: string,
  ): Promise<BaseResponse<GraduateLoginDataContent>> {
        if (await AppStorage.getInstance().getUseMock()) {
      return ApiService.mockSuccess<GraduateLoginDataContent>({
        studentNumber: studentId,
        name: 'Zhang San',
        college: 'CS College',
        major: 'CS',
        clazz: 'CS2101',
        birthday: '2003-01-01',
        sex: 'M',
        nationality: 'Han',
        hometown: 'Wuhan',
        idNumber: '420106200301010000',
      });
    }
    try {
      const result = await HttpRequest.postJson<BaseResponse<GraduateLoginDataContent>>(
        GRADUATE_LOGIN_V2,
        { student_id: studentId, password },
      );
      return result.data;
    } catch {
      const result = await HttpRequest.postJson<BaseResponse<GraduateLoginDataContent>>(
        GRADUATE_LOGIN_V2_BACKUP,
        { student_id: studentId, password },
      );
      return result.data;
    }
  }

  /** App Auth 登录 */
  static async loginAppAuth(
    studentId: string,
    password: string,
    isGraduate: boolean,
  ): Promise<BaseResponse<AppAuthDataContent>> {
        if (await AppStorage.getInstance().getUseMock()) {
      return ApiService.mockSuccess<AppAuthDataContent>({
        accessToken: 'mock_access_' + studentId,
        refreshToken: 'mock_refresh_' + studentId,
        expiresAt: Date.now() + 7 * 24 * 3600 * 1000,
        refreshExpiresAt: Date.now() + 30 * 24 * 3600 * 1000,
        user: { displayName: 'Zhang San', avatarUrl: '' },
      });
    }
    const body = {
      student_id: studentId,
      password,
      studentType: isGraduate ? 'graduate' : 'undergrad',
      platform: 'android',
    };
    const headers = { 'X-Wust-Skip-Auth-Interceptor': 'true' };
    try {
      const result = await HttpRequest.postJson<BaseResponse<AppAuthDataContent>>(APP_AUTH_LOGIN, body, headers);
      return result.data;
    } catch {
      const result = await HttpRequest.postJson<BaseResponse<AppAuthDataContent>>(APP_AUTH_LOGIN_BACKUP, body, headers);
      return result.data;
    }
  }

  /** 用保存的凭据恢复 App Auth */
  static async loginAppAuthFromSavedCredentials(
    storage: AppStorage,
  ): Promise<void> {
    const studentId = await storage.getStudentId();
    const password = await storage.getPassword();
    if (!studentId || !password) {
      console.warn('ApiService', 'missing saved credentials for app auth');
      return;
    }
    const isGraduate = await storage.getIsGraduate();
    const data = await ApiService.loginAppAuth(studentId, password, isGraduate);
    if (data && data.code === 200 && data.data) {
      const d = data.data;
      await storage.setAppAuthAccessToken(d.accessToken ?? '');
      await storage.setAppAuthRefreshToken(d.refreshToken ?? '');
      await storage.setAppAuthExpiresAt(d.expiresAt ?? 0);
      await storage.setAppAuthRefreshExpiresAt(d.refreshExpiresAt ?? 0);
      if (d.user) {
        if (d.user.displayName?.trim()) {
          // 可根据业务需要存到 UserInfo
        }
        if (d.user.avatarUrl?.trim()) {
          await storage.setAvatarUrl(d.user.avatarUrl.trim());
        }
      }
      console.info('ApiService', 'app auth restored');
    } else {
      console.warn('ApiService', `app auth restore failed: ${data?.msg}`);
    }
  }

  /** 本科生 Token 刷新（含持久化） */
  static async refreshUndergradToken(
    storage: AppStorage,
    studentId: string,
    password: string,
  ): Promise<boolean> {
    try {
      const resp = await ApiService.loginUndergrad(studentId, password);
      if (resp && resp.data?.token) {
        const token = resp.data.token;
        await storage.setToken(token);
        await storage.setTokenUpdateTime(Date.now());
        await storage.setTokenLastUseTime(Date.now());
        await storage.setMessage(resp.msg ?? '');
        return true;
      }
      return false;
    } catch {
      console.warn('ApiService', 'refreshUndergradToken error');
      return false;
    }
  }

  /** 研究生 Token 刷新 */
  static async refreshGraduateToken(
    storage: AppStorage,
    studentId: string,
    password: string,
  ): Promise<boolean> {
    try {
      const resp = await ApiService.loginGraduate(studentId, password);
      if (resp && resp.code === 200) {
        const token = 'grad_' + studentId;
        const msg = resp.msg ?? '';
        await storage.setToken(token);
        await storage.setTokenUpdateTime(Date.now());
        await storage.setTokenLastUseTime(Date.now());
        await storage.setMessage(msg);
        return true;
      }
      return false;
    } catch {
      console.warn('ApiService', 'refreshGraduateToken error');
      return false;
    }
  }
}



// net/CookieManager.ts

/**
 * Cookie 管理器
 * 对应原 Android 端校园门户登录的会话 Cookie 持久化
 * 在鸿蒙网络请求中需要手动管理 Set-Cookie / Cookie 头
 */

const TAG = 'CookieManager';

export class CookieManager {
  private static cookies: Map<string, string> = new Map();

  static setCookie(domain: string, cookie: string): void {
    CookieManager.cookies.set(domain, cookie);
    console.info(TAG, `set cookie for ${domain}: ${cookie.substring(0, 40)}...`);
  }

  static getCookie(domain: string): string {
    return CookieManager.cookies.get(domain) ?? '';
  }

  static clear(): void {
    CookieManager.cookies.clear();
  }

  /**
   * 从响应头中提取 Set-Cookie 并保存
   */
  static extractAndSave(headers: Record<string, string | number>, domain: string): void {
    const setCookie = headers['Set-Cookie'] ?? headers['set-cookie'];
    if (setCookie && typeof setCookie === 'string') {
      // 取第一个完整 cookie 条目（截止到第一个 ; 之后可只保留 key=value 部分）
      const cookieValue = setCookie.split(';')[0];
      if (cookieValue) {
        CookieManager.setCookie(domain, cookieValue);
      }
    }
  }
}
// ── 课表 API ──

/** 本科生课表查询 —— 对应 WustApi.UG_COURSE_TABLE_V2 */
export const UG_COURSE_TABLE_V2 = 'https://lyzyy.love:8081/UnderGraduate/Support/getCoursesPage';

export interface CourseApiItem {
  id?: number;
  courseName: string;
  teacher: string;
  location: string;
  dayOfWeek: number;
  startPeriod: number;
  endPeriod: number;
  weekRanges: string;
  term: string;
}

/** 课表 API 统一返回结构 */
export interface CourseApiResponse {
  list: CourseApiItem[];
  semester: string;
  currentWeek: number;
  totalWeeks: number;
}





