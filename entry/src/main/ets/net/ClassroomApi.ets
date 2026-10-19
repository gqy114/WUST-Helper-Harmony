import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

interface ClassroomResponse { code?: number; msg?: string; data?: string[]; }
interface ClassroomQueryPayload extends Record<string, string> {
  semester: string;
  startWeek: string;
  endWeek: string;
  weekDay: string;
  startSection: string;
  endSection: string;
  building: string;
  roomNo: string;
  limit: string;
}
interface ClassroomReportCourse { classroom: string; weekDay: number; startWeek: number; endWeek: number; startSection: number; endSection: number; courseName: string; teacher: string; }
interface ClassroomReportRequest extends Record<string, string> { studentId: string; semester: string; report: string; updatedAt: string; }

export class ClassroomApi {
  static async reportCourses(semester: string, courses: ClassroomReportCourse[]): Promise<void> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const body: ClassroomReportRequest = { studentId: await AppStorage.getInstance().getStudentId(), semester, report: JSON.stringify({ semester, courses }), updatedAt: String(Date.now()) };
    await HttpRequest.postJson<Record<string, string>>('https://lyzyy.love/Classroom/Support/report-course-occupancies', body, { Authorization: `Bearer ${token}`, Accept: 'application/json', Platform: 'android' });
  }
  static async query(params: Record<string, string>): Promise<string[]> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const body: ClassroomQueryPayload = {
      semester: await AppStorage.getInstance().getSemester(),
      startWeek: params.startWeek || '1', endWeek: params.endWeek || params.startWeek || '1',
      weekDay: String(ClassroomApi.weekday(params.weekday || '周一')),
      startSection: params.startPeriod || '1', endSection: params.endPeriod || params.startPeriod || '1',
      building: params.building || '', roomNo: params.room || '', limit: '100'
    };
    const result = await HttpRequest.postJson<ClassroomResponse>('https://lyzyy.love/Classroom/Support/query-empty-rooms', body, {
      Authorization: `Bearer ${token}`, Accept: 'application/json', Platform: 'android'
    });
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200 && result.data.code !== 10000) throw new Error(result.data.msg || '空教室查询失败');
    return result.data.data ?? [];
  }

  private static weekday(value: string): number {
    const index = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'].indexOf(value);
    return index >= 0 ? index + 1 : 0;
  }
}

