import { HttpRequest } from './HttpRequest';
import { CookieManager } from './ApiService';
import { AppStorage } from '../store/AppStorage';
export interface TrainingPlanSummary { credits: number; courseCount: number; failedCount: number; missingRequired: number; missingCredits: number; categories: number; planCourseCount: number; }
export class TrainingPlanApi {
  static async fetchSummary(): Promise<TrainingPlanSummary> {
    const s = AppStorage.getInstance(); let html = '';
    if (await s.getIsGraduate()) { const r = await HttpRequest.postJson<string>('https://www.lyzyy.love:8007/cultivation-plan', { student_id: await s.getStudentId(), password: await s.getPassword() }); html = typeof r.data === 'string' ? r.data : JSON.stringify(r.data); }
    else { const r = await HttpRequest.get<string>('https://www.lyzyy.love/UnderGraduate/Support/getTrainingPlanPage', { Cookie: CookieManager.getCookie('www.lyzyy.love'), Accept: 'text/html' }); html = typeof r.data === 'string' ? r.data : JSON.stringify(r.data); }
    return TrainingPlanApi.parse(html);
  }
  private static parse(html: string): TrainingPlanSummary { const t = html.replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' '); const n = (p: RegExp): number => { const m = t.match(p); return m ? Number(m[1]) || 0 : 0; }; return { credits: n(/(?:已修学分|获得学分|总学分)[^0-9]{0,30}(\d+(?:\.\d+)?)/), courseCount: n(/(?:已修课程|已修课程数|课程)[^0-9]{0,30}(\d+)/), failedCount: n(/(?:不及格|挂科)[^0-9]{0,20}(\d+)/), missingRequired: n(/(?:必修未获|未获必修)[^0-9]{0,20}(\d+)/), missingCredits: n(/(?:未选学分|缺少学分)[^0-9]{0,20}(\d+(?:\.\d+)?)/), categories: (t.match(/课程类别|通识|专业必修|公共必修/g) || []).length, planCourseCount: (t.match(/课程名称|courseName|课程代码/g) || []).length }; }
}
