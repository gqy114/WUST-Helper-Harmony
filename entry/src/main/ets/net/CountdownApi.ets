import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface CountdownItem { uuid: string; name: string; comment: string; time: string; createTime?: string; source?: string; examType?: string; location?: string; seatNumber?: string; }
interface CountdownResponse { code?: number; message?: string; data?: CountdownItem[] | string; }
interface CountdownHeaders extends Record<string, string> { Authorization: string; Accept: string; Platform: string; }
interface ExamRecord { id?: string; term?: string; courseName?: string; name?: string; examTime?: string; time?: string; examLocation?: string; location?: string; examType?: string; seatNumber?: string; }
interface ExamListData { exams?: ExamRecord[]; list?: ExamRecord[]; items?: ExamRecord[]; }
interface ExamResponse { code?: number; message?: string; msg?: string; data?: ExamRecord[] | ExamListData; }

export class CountdownApi {
  private static readonly BASE: string = 'https://lyzyy.love/v2/lh';
  private static async headers(): Promise<CountdownHeaders> {
    const token: string = await AppStorage.getInstance().getAppAuthAccessToken();
    return { Authorization: `Bearer ${token}`, Accept: 'application/json', Platform: 'android' };
  }
  static async list(): Promise<CountdownItem[]> {
    const result = await HttpRequest.get<CountdownResponse>(`${CountdownApi.BASE}/list-countdown`, await CountdownApi.headers());
    if (result.data.code !== undefined && result.data.code !== 200 && result.data.code !== 0) throw new Error(result.data.message || '倒计时获取失败');
    return Array.isArray(result.data.data) ? result.data.data : [];
  }
  static async listExams(term: string): Promise<CountdownItem[]> {
    const token = await AppStorage.getInstance().getToken();
    let response: ExamResponse;
    try {
      response = await CountdownApi.requestExams('https://lyzyy.love', term, token, 'Bearer');
    } catch {
      response = await CountdownApi.requestExams('https://www.lyzyy.love', term, token, 'Bearer');
    }
    if (response.code === 401 || response.code === 403) response = await CountdownApi.requestExams('https://lyzyy.love', term, token, 'Wuster');
    if (response.code === 401 || response.code === 403) response = await CountdownApi.requestExams('https://www.lyzyy.love', term, token, 'Wuster');
    let raw: ExamRecord[] | ExamListData | undefined = response.data;
    let records: ExamRecord[] = Array.isArray(raw) ? raw : (raw?.exams || raw?.list || raw?.items || []);
    if (records.length === 0 && term.trim().length > 0) {
      try {
        response = await CountdownApi.requestExams('https://lyzyy.love', '', token, 'Bearer');
      } catch {
        response = await CountdownApi.requestExams('https://www.lyzyy.love', '', token, 'Bearer');
      }
      raw = response.data;
      records = Array.isArray(raw) ? raw : (raw?.exams || raw?.list || raw?.items || []);
    }
    if (response.code !== undefined && response.code !== 200 && response.code !== 0 && response.code !== 10000) throw new Error(response.message || response.msg || '考试获取失败');
    return records.map((item: ExamRecord, index: number): CountdownItem => ({
      uuid: `exam-${item.id || index}`, name: item.courseName || item.name || '考试', time: item.examTime || item.time || '',
      comment: item.examLocation || item.location || '', source: 'exam', examType: item.examType || '',
      location: item.examLocation || item.location || '', seatNumber: item.seatNumber || ''
    }));
  }
  private static async requestExams(host: string, term: string, token: string, scheme: string): Promise<ExamResponse> {
    const auth = token.trim().startsWith(`${scheme} `) ? token.trim() : `${scheme} ${token.trim()}`;
    const url = `${host}/UnderGraduate/Support/GetExamList${term.trim().length > 0 ? `?term=${encodeURIComponent(term)}` : ''}`;
    const result = await HttpRequest.get<ExamResponse>(url, { Authorization: auth, Accept: 'application/json', Platform: 'android' });
    return result.data;
  }
  static async add(name: string, comment: string, time: string): Promise<void> {
    const result = await HttpRequest.postJson<CountdownResponse>(`${CountdownApi.BASE}/add-countdown`, { name, comment, time }, await CountdownApi.headers());
    if (result.data.code !== undefined && result.data.code !== 200 && result.data.code !== 0) throw new Error(result.data.message || '倒计时添加失败');
  }
  static async remove(uuid: string): Promise<void> {
    const result = await HttpRequest.get<CountdownResponse>(`${CountdownApi.BASE}/del-countdown?uuid=${encodeURIComponent(uuid)}`, await CountdownApi.headers());
    if (result.data.code !== undefined && result.data.code !== 200 && result.data.code !== 0) throw new Error(result.data.message || '倒计时删除失败');
  }
}
