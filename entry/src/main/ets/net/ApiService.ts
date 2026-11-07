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
// 当前 Go 后端与其余本科教务接口统一部署在 8081 端口；443 反向代理保留为故障回退。
export const UG_LOGIN_V2 = 'https://lyzyy.love:8081/UnderGraduate/Support/loginGetCookie';
const UG_LOGIN_V2_BACKUP = 'https://www.lyzyy.love/UnderGraduate/Support/loginGetCookie';
const GO_BACKUP_BASE = 'http://port.happylandmc.cc:52144';
const UG_LOGIN_BACKEND_BACKUP = `${GO_BACKUP_BASE}/UnderGraduate/Support/loginGetCookie`;
// 研究生登录：首选 Go 后端（与课表/培养方案同一套凭据校验），旧 8009 服务仅作回退。
export const GRADUATE_LOGIN_GO = 'https://lyzyy.love:8081/Graduate/Support/loginPage';
export const GRADUATE_LOGIN_V2 = 'https://www.lyzyy.love:8009/personal-info';
const GRADUATE_LOGIN_V2_BACKUP = 'https://lyzyy.love:8009/personal-info';
export const APP_AUTH_LOGIN = 'https://lyzyy.love:8081/api/v1/auth/login';
const APP_AUTH_LOGIN_BACKUP = 'https://www.lyzyy.love:8081/api/v1/auth/login';
const UG_TWO_VERIFY_SEND_PATH = '/UnderGraduate/Support/twoVerify/sendCode';
const UG_TWO_VERIFY_CHECK_PATH = '/UnderGraduate/Support/twoVerify/verify';

interface UndergradLoginResponse {
  code: number;
  msg?: string;
  message?: string;
  data?: TokenDataContent | string;
  dataObject?: TokenDataContent;
}

/**
 * 研究生登录响应的原始形状：
 * - Go 后端（Graduate/Support/loginPage）：data 直接是学生资料字段；
 * - 旧 8009 服务：data 是 { status, message, login_error, data } 包装层，失败时外层 code 仍是 200。
 */
interface GraduateLoginPayload {
  studentNumber?: string;
  name?: string;
  college?: string;
  major?: string;
  clazz?: string;
  birthday?: string;
  sex?: string;
  nationality?: string;
  hometown?: string;
  idNumber?: string;
  status?: string;
  message?: string;
  login_error?: string;
  data?: GraduateLoginPayload;
}

/** Go 后端把提示放在 message 而不是 msg，两种都要读。 */
interface GraduateLoginResponse<T> {
  code: number;
  msg?: string;
  message?: string;
  data?: T;
}

export class ApiService {
  private static undergradSessionBackend: string = 'https://lyzyy.love:8081';

  static async sendUndergradVerifyCode(state: string): Promise<BaseResponse<{ cooldown_seconds?: number }>> {
    const result = await HttpRequest.postJsonPinned<BaseResponse<{ cooldown_seconds?: number }>>(
      `${ApiService.undergradSessionBackend}${UG_TWO_VERIFY_SEND_PATH}`, { state }, undefined, true);
    return result.data;
  }

  static async verifyUndergradCode(state: string, code: string): Promise<BaseResponse<TokenDataContent>> {
    const result = await HttpRequest.postJsonPinned<BaseResponse<TokenDataContent>>(
      `${ApiService.undergradSessionBackend}${UG_TWO_VERIFY_CHECK_PATH}`, { state, code }, undefined, true);
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
    const endpoints: string[] = [UG_LOGIN_V2, UG_LOGIN_BACKEND_BACKUP, UG_LOGIN_V2_BACKUP];
    let data: UndergradLoginResponse | undefined = undefined;
    for (const endpoint of endpoints) {
      try {
        const result = await HttpRequest.postJson<UndergradLoginResponse>(endpoint, { username: studentId, password },
          undefined, undefined, true);
        const candidate = result.data;
        // 只有结构化业务响应才停止回退；网关 HTML、空响应等继续尝试备用入口。
        if (candidate && typeof candidate === 'object' && candidate.code !== undefined) {
          data = candidate;
          ApiService.undergradSessionBackend = HttpRequest.getPreferredBackendBase();
          break;
        }
        console.warn('ApiService', `undergrad login returned invalid response from ${endpoint}`);
      } catch (error) {
        console.warn('ApiService', `undergrad login endpoint unavailable: ${endpoint}, ${JSON.stringify(error)}`);
      }
    }
    if (!data) {
      // 作为业务失败返回，让登录页展示真实原因，而不是把服务端不可达误报为用户网络故障。
      return { code: 503, msg: '登录服务暂时无法连接，请稍后重试（不是账号密码错误）' };
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
    const body: Record<string, string> = { student_id: studentId, password };
    const headers: Record<string, string> = { Platform: 'android' };
    let primary: BaseResponse<GraduateLoginDataContent> = { code: -1, msg: '登录请求失败' };
    try {
      // 研究生课表需要 Go 后端用同一份学号密码换取研究生系统 Cookie，
      // 从同一入口登录可以保证「能登录」与「能取课表」的凭据口径一致。
      const result = await HttpRequest.postJson<GraduateLoginResponse<GraduateLoginPayload>>(
        GRADUATE_LOGIN_GO, body, headers, 45000, true);
      primary = ApiService.normalizeGraduateLogin(result.data);
      if (primary.code === 200 || String(primary.code) === '200') return primary;
      console.warn('ApiService', `go graduate login failed: ${primary.msg}`);
    } catch {
      console.warn('ApiService', 'go graduate login request error');
    }

    // 主服务明确拒绝凭据（密码错误/账号被锁）时不再尝试旧服务：
    // 换一个服务重放同样的密码只会加速触发上游锁定。
    if (ApiService.isCredentialRejection(primary)) return primary;

    // 兼容旧 8009 个人信息服务：它只做研究生系统登录，失败时外层仍返回 200。
    const legacyUrls: string[] = [GRADUATE_LOGIN_V2, GRADUATE_LOGIN_V2_BACKUP];
    for (let i = 0; i < legacyUrls.length; i++) {
      try {
        const legacy = await HttpRequest.postJson<GraduateLoginResponse<GraduateLoginPayload>>(legacyUrls[i], body,
          undefined, undefined, true);
        const normalized = ApiService.normalizeGraduateLogin(legacy.data);
        if (normalized.code === 200 || String(normalized.code) === '200') return normalized;
        // 旧节点明确拒绝凭据时同样立刻停止，避免继续打下一个入口、加速账号锁定。
        if (ApiService.isCredentialRejection(normalized)) return normalized;
      } catch {
        console.warn('ApiService', 'legacy graduate login request failed');
      }
    }
    return primary;
  }

  /** 把两种后端的研究生登录响应归一成 BaseResponse<GraduateLoginDataContent>。 */
  private static normalizeGraduateLogin(
    resp: GraduateLoginResponse<GraduateLoginPayload> | undefined,
  ): BaseResponse<GraduateLoginDataContent> {
    if (!resp) return { code: -1, msg: '登录失败' };
    const payload = resp.data;
    const successCode = resp.code === 200 || resp.code === 0 || resp.code === 10000;
    const respMsg = (resp.msg || resp.message || '').trim();
    if (payload) {
      const nested = payload.data;
      let profile: GraduateLoginPayload | undefined = undefined;
      if (nested && (nested.studentNumber || nested.name)) {
        profile = nested;
      } else if (payload.studentNumber || payload.name) {
        profile = payload;
      }
      if (successCode && profile) {
        return { code: 200, msg: respMsg || '登录成功', data: ApiService.toGraduateContent(profile) };
      }
      const failureMsg = (payload.login_error || payload.message || '').trim();
      if (!successCode || payload.status === 'failure' || failureMsg) {
        return { code: successCode ? 500 : resp.code, msg: failureMsg || respMsg || '登录失败' };
      }
    }
    if (successCode) {
      // code=200 但没有任何用户信息：按失败处理，避免登录页误判成功。
      return { code: 500, msg: respMsg || '登录响应缺少用户信息' };
    }
    return { code: resp.code, msg: respMsg || '登录失败' };
  }

  /** 是否为「凭据被明确拒绝」：这类失败换服务重试只会加速账号锁定。 */
  private static isCredentialRejection(resp: BaseResponse<GraduateLoginDataContent>): boolean {
    if (resp.code === 401 || resp.code === 403) return true;
    const msg = (resp.msg || '').toLowerCase();
    return msg.includes('invalid password') || msg.includes('密码') || msg.includes('口令') ||
      msg.includes('账号') || msg.includes('帐号') || msg.includes('锁定');
  }

  private static toGraduateContent(profile: GraduateLoginPayload): GraduateLoginDataContent {
    return {
      studentNumber: profile.studentNumber ?? '',
      name: profile.name ?? '',
      college: profile.college ?? '',
      major: profile.major ?? '',
      clazz: profile.clazz ?? '',
      birthday: profile.birthday ?? '',
      sex: profile.sex ?? '',
      nationality: profile.nationality ?? '',
      hometown: profile.hometown ?? '',
      idNumber: profile.idNumber ?? '',
    };
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
      const result = await HttpRequest.postJson<BaseResponse<AppAuthDataContent>>(APP_AUTH_LOGIN, body, headers,
        undefined, true);
      return result.data;
    } catch {
      const result = await HttpRequest.postJson<BaseResponse<AppAuthDataContent>>(APP_AUTH_LOGIN_BACKUP, body, headers,
        undefined, true);
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





