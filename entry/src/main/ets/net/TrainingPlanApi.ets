import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
import { TeachingSessionService } from '../service/TeachingSessionService';

type AuditNumber = number | string;

export interface TrainingPlanSummary {
  credits: number;
  courseCount: number;
  failedCount: number;
  failedCredits: number;
  missingRequired: number;
  missingRequiredCredits: number;
  missingCredits: number;
  unselectedCourseCount: number;
  termCount: number;
  averageCreditPerTerm: number;
  categories: number;
  planCourseCount: number;
}

export interface TrainingPlanCourse {
  term: string;
  courseCode: string;
  courseName: string;
  credit: number;
  courseNature: string;
  courseAttribute: string;
  status: string;
}

export interface TrainingPlanCreditCategory {
  name: string;
  attribute: string;
  requiredCredit: number;
  earnedCredit: number;
}

export interface TrainingPlanGeneralCategory {
  name: string;
  requiredCredit: number;
  earnedCredit: number;
}

export interface TrainingPlanData {
  reminder: string;
  summary: TrainingPlanSummary;
  courses: TrainingPlanCourse[];
  creditCategories: TrainingPlanCreditCategory[];
  generalCategories: TrainingPlanGeneralCategory[];
}

interface AuditSummary {
  termCount?: AuditNumber;
  completedCourseCount?: AuditNumber;
  completedCredit?: AuditNumber;
  averageCreditPerTerm?: AuditNumber;
  failedCourseCount?: AuditNumber;
  failedCredit?: AuditNumber;
  unselectedCourseCount?: AuditNumber;
  unselectedCredit?: AuditNumber;
  requiredUncompletedCourseCount?: AuditNumber;
  requiredUncompletedCredit?: AuditNumber;
}

interface AuditCourse {
  term?: string;
  courseCode?: string;
  courseName?: string;
  credit?: AuditNumber;
  courseNature?: string;
  courseAttribute?: string;
  status?: string;
}

interface AuditCreditCategory {
  courseNature?: string;
  courseAttribute?: string;
  requiredCredit?: AuditNumber;
  earnedCredit?: AuditNumber;
}

interface AuditGeneralCategory {
  category?: string;
  requiredCredit?: AuditNumber;
  earnedCredit?: AuditNumber;
}

interface GraduationAudit {
  reminder?: string;
  courseDetails?: AuditCourse[];
  creditCategories?: AuditCreditCategory[];
  generalEducationCategories?: AuditGeneralCategory[];
  summary?: AuditSummary;
}

interface AuditResponse {
  code?: number;
  message?: string;
  msg?: string;
  data?: GraduationAudit;
  dataObject?: GraduationAudit;
}

interface TrainingPlanHeaders extends Record<string, string> {
  Accept: string;
  Cookie: string;
  Authorization: string;
  Token: string;
}

export class TrainingPlanApi {
  private static readonly URLS: string[] = [
    'https://lyzyy.love:8081/UnderGraduate/Support/GetGraduationAudit',
    'http://port.happylandmc.cc:52144/UnderGraduate/Support/GetGraduationAudit'
  ];

  private static number(value: AuditNumber | undefined): number {
    const parsed = Number(value ?? 0);
    return isNaN(parsed) ? 0 : parsed;
  }

  private static emptySummary(): TrainingPlanSummary {
    return {
      credits: 0,
      courseCount: 0,
      failedCount: 0,
      failedCredits: 0,
      missingRequired: 0,
      missingRequiredCredits: 0,
      missingCredits: 0,
      unselectedCourseCount: 0,
      termCount: 0,
      averageCreditPerTerm: 0,
      categories: 0,
      planCourseCount: 0
    };
  }

  private static success(code: number | undefined): boolean {
    return code === undefined || code === 0 || code === 200 || code === 10000 || code === 11000;
  }

  /**
   * 毕业审核属于本科教务取数接口，鉴权凭据是 loginGetCookie 返回的
   * 教务 Cookie（AppStorage.token），不是校园社区使用的 AppAuth Bearer Token。
   */
  private static async teachingCookie(forceRefresh: boolean = false): Promise<string> {
    const storage = AppStorage.getInstance();
    let cookie = (await storage.getToken()).trim();
    if (forceRefresh || cookie.length === 0) {
      const refreshed = await TeachingSessionService.ensureSession(true);
      if (refreshed) cookie = (await storage.getToken()).trim();
    }
    if (cookie.length === 0) throw new Error('教务登录状态已失效，暂时无法获取新的主修进度');
    return cookie;
  }

  private static async requestAudit(retry: boolean = true): Promise<GraduationAudit> {
    const cookie = await TrainingPlanApi.teachingCookie(false);
    const headers: TrainingPlanHeaders = {
      Accept: 'application/json',
      // NetworkKit/部分网关链路可能不会保留 Cookie 请求头。后端的 getCookie
      // 同时兼容 Cookie、Bearer 和 Token，因此三种方式一并发送同一教务 Cookie。
      Cookie: cookie,
      Authorization: `Bearer ${cookie}`,
      Token: cookie
    };

    let lastMessage: string = '';
    let unauthorized: boolean = false;
    for (const url of TrainingPlanApi.URLS) {
      try {
        // 这里必须固定节点逐个请求。否则公共首选节点切到旧备用节点后，
        // HTTP 200 + 业务失败不会继续尝试另一个节点。
        const result = await HttpRequest.request<AuditResponse>(url, 'GET', {
          headers,
          pinBackend: true
        });
        const response = result.data;
        const message = response?.message || response?.msg || '';
        const currentUnauthorized = result.response.responseCode === 401 ||
          result.response.responseCode === 403 || response?.code === 401 || response?.code === 403 ||
          /unauthorized|missing cookie/i.test(message);
        unauthorized = unauthorized || currentUnauthorized;
        const audit = response?.data || response?.dataObject;
        if (response && TrainingPlanApi.success(response.code) && audit) return audit;
        if (message.trim().length > 0) lastMessage = message;
      } catch (error) {
        if (error instanceof Error && error.message.trim().length > 0) lastMessage = error.message;
      }
    }

    if (unauthorized && retry) {
      await TrainingPlanApi.teachingCookie(true);
      return TrainingPlanApi.requestAudit(false);
    }
    if (unauthorized) throw new Error('教务登录状态已失效，请稍后重试');
    throw new Error(lastMessage || '培养方案加载失败');
  }

  private static normalize(audit: GraduationAudit): TrainingPlanData {
    const rawSummary: AuditSummary = audit.summary || {};
    const rawCourses: AuditCourse[] = audit.courseDetails || [];
    const rawCreditCategories: AuditCreditCategory[] = audit.creditCategories || [];
    const rawGeneralCategories: AuditGeneralCategory[] = audit.generalEducationCategories || [];
    const courses: TrainingPlanCourse[] = rawCourses.map((item: AuditCourse): TrainingPlanCourse => {
      return {
        term: item.term || '未分学期',
        courseCode: item.courseCode || '',
        courseName: item.courseName || '未命名课程',
        credit: TrainingPlanApi.number(item.credit),
        courseNature: item.courseNature || '',
        courseAttribute: item.courseAttribute || '',
        status: item.status || '未知'
      };
    });
    const creditCategories: TrainingPlanCreditCategory[] = rawCreditCategories.map(
      (item: AuditCreditCategory): TrainingPlanCreditCategory => {
        return {
          name: item.courseNature || '未分类',
          attribute: item.courseAttribute || '',
          requiredCredit: TrainingPlanApi.number(item.requiredCredit),
          earnedCredit: TrainingPlanApi.number(item.earnedCredit)
        };
      }
    );
    const generalCategories: TrainingPlanGeneralCategory[] = rawGeneralCategories.map(
      (item: AuditGeneralCategory): TrainingPlanGeneralCategory => {
        return {
          name: item.category || '未分类',
          requiredCredit: TrainingPlanApi.number(item.requiredCredit),
          earnedCredit: TrainingPlanApi.number(item.earnedCredit)
        };
      }
    );
    const summary: TrainingPlanSummary = {
      credits: TrainingPlanApi.number(rawSummary.completedCredit),
      courseCount: TrainingPlanApi.number(rawSummary.completedCourseCount),
      failedCount: TrainingPlanApi.number(rawSummary.failedCourseCount),
      failedCredits: TrainingPlanApi.number(rawSummary.failedCredit),
      missingRequired: TrainingPlanApi.number(rawSummary.requiredUncompletedCourseCount),
      missingRequiredCredits: TrainingPlanApi.number(rawSummary.requiredUncompletedCredit),
      missingCredits: TrainingPlanApi.number(rawSummary.unselectedCredit),
      unselectedCourseCount: TrainingPlanApi.number(rawSummary.unselectedCourseCount),
      termCount: TrainingPlanApi.number(rawSummary.termCount),
      averageCreditPerTerm: TrainingPlanApi.number(rawSummary.averageCreditPerTerm),
      categories: creditCategories.length + generalCategories.length,
      planCourseCount: courses.length
    };
    return {
      reminder: audit.reminder || '',
      summary,
      courses,
      creditCategories,
      generalCategories
    };
  }

  static async fetchData(): Promise<TrainingPlanData> {
    const storage = AppStorage.getInstance();
    if (await storage.getIsGraduate()) return TrainingPlanApi.fetchGraduateData(storage);
    const audit = await TrainingPlanApi.requestAudit();
    const data = TrainingPlanApi.normalize(audit);
    if (!audit.summary && data.courses.length === 0 && data.creditCategories.length === 0 &&
      data.generalCategories.length === 0) {
      throw new Error('培养方案数据为空');
    }
    return data;
  }

  static async fetchSummary(): Promise<TrainingPlanSummary> {
    return (await TrainingPlanApi.fetchData()).summary;
  }

  private static async fetchGraduateData(storage: AppStorage): Promise<TrainingPlanData> {
    const result = await HttpRequest.postJson<string>('https://www.lyzyy.love:8007/cultivation-plan', {
      student_id: await storage.getStudentId(),
      password: await storage.getPassword()
    }, undefined, undefined, true);
    const html = typeof result.data === 'string' ? result.data : JSON.stringify(result.data);
    const text = html.replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ');
    if (text.trim().length === 0) throw new Error('培养方案数据为空');
    const creditMatch = text.match(/(?:已修学分|获得学分|总学分)[^0-9]{0,30}(\d+(?:\.\d+)?)/);
    const summary = TrainingPlanApi.emptySummary();
    summary.credits = creditMatch ? Number(creditMatch[1]) || 0 : 0;
    return {
      reminder: '研究生培养方案暂仅提供已修学分汇总。',
      summary,
      courses: [],
      creditCategories: [],
      generalCategories: []
    };
  }
}
