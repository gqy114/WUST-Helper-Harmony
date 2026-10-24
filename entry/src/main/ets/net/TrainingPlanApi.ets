import { HttpRequest } from './HttpRequest';
import { CookieManager } from './ApiService';
import { AppStorage } from '../store/AppStorage';

export interface TrainingPlanSummary { credits: number; courseCount: number; failedCount: number; missingRequired: number; missingCredits: number; categories: number; planCourseCount: number; }
interface AuditSummary { completedCourseCount?: string; completedCredit?: string; failedCourseCount?: string; unselectedCredit?: string; requiredUncompletedCourseCount?: string; }
interface AuditCourse { status?: string; }
interface AuditCategory { earnedCredit?: string; requiredCredit?: string; }
interface GraduationAudit { reminder?: string; courseDetails?: AuditCourse[]; creditCategories?: AuditCategory[]; generalEducationCategories?: AuditCategory[]; summary?: AuditSummary; }
interface AuditResponse { code?: number; message?: string; data?: GraduationAudit; }

export class TrainingPlanApi {
  private static number(value: string | undefined): number { const parsed = Number(value || '0'); return isNaN(parsed) ? 0 : parsed; }

  static async fetchSummary(): Promise<TrainingPlanSummary> {
    const storage = AppStorage.getInstance();
    if (await storage.getIsGraduate()) return TrainingPlanApi.fetchGraduateSummary(storage);
    const token = await storage.getAppAuthAccessToken();
    const cookie = CookieManager.getCookie('www.lyzyy.love');
    const headers: Record<string, string> = { Accept: 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (cookie) headers['Cookie'] = cookie;
    const response = await HttpRequest.get<AuditResponse>('https://lyzyy.love/UnderGraduate/Support/GetGraduationAudit', headers);
    if (response.data.code !== 200 && response.data.code !== 0) throw new Error(response.data.message || '培养方案加载失败');
    const audit = response.data.data;
    if (!audit || (!audit.summary && (audit.courseDetails || []).length === 0)) throw new Error('培养方案数据为空');
    const summary = audit.summary || {};
    const courses = audit.courseDetails || [];
    const categories = (audit.creditCategories || []).length + (audit.generalEducationCategories || []).length;
    return {
      credits: TrainingPlanApi.number(summary.completedCredit),
      courseCount: TrainingPlanApi.number(summary.completedCourseCount),
      failedCount: TrainingPlanApi.number(summary.failedCourseCount),
      missingRequired: TrainingPlanApi.number(summary.requiredUncompletedCourseCount),
      missingCredits: TrainingPlanApi.number(summary.unselectedCredit),
      categories,
      planCourseCount: courses.length
    };
  }

  private static async fetchGraduateSummary(storage: AppStorage): Promise<TrainingPlanSummary> {
    const result = await HttpRequest.postJson<string>('https://www.lyzyy.love:8007/cultivation-plan', { student_id: await storage.getStudentId(), password: await storage.getPassword() });
    const html = typeof result.data === 'string' ? result.data : JSON.stringify(result.data);
    const text = html.replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ');
    const creditMatch = text.match(/(?:已修学分|获得学分|总学分)[^0-9]{0,30}(\d+(?:\.\d+)?)/);
    const credits = creditMatch ? Number(creditMatch[1]) || 0 : 0;
    if (text.trim().length === 0) throw new Error('培养方案数据为空');
    return { credits, courseCount: 0, failedCount: 0, missingRequired: 0, missingCredits: 0, categories: 0, planCourseCount: 0 };
  }
}
