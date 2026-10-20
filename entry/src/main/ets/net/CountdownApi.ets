import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface CountdownItem { uuid: string; name: string; comment: string; time: string; createTime?: string; }
interface CountdownResponse { code?: number; message?: string; data?: CountdownItem[] | string; }
interface CountdownHeaders extends Record<string, string> { Authorization: string; Accept: string; Platform: string; }
interface ExamRecord { courseName?: string; name?: string; examTime?: string; time?: string; examLocation?: string; location?: string; examType?: string; }
interface ExamResponse { code?: number; message?: string; data?: ExamRecord[]; }

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
    const result = await HttpRequest.get<ExamResponse>(`https://lyzyy.love/UnderGraduate/Support/GetExamList?term=${encodeURIComponent(term)}`, await CountdownApi.headers());
    if (result.data.code !== undefined && result.data.code !== 200 && result.data.code !== 0 && result.data.code !== 10000) throw new Error(result.data.message || '考试获取失败');
    const records: ExamRecord[] = result.data.data ?? [];
    return records.map((item: ExamRecord, index: number): CountdownItem => ({ uuid: `exam-${index}`, name: item.courseName || item.name || '考试', time: item.examTime || item.time || '', comment: item.examLocation || item.location || '' }));
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
