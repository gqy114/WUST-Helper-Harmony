import { CourseArchive, CourseData } from '../model/CourseModel';
import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface DynamicInvite { token: string; expiresAt: number; expiresIn: number; }
interface DynamicInviteResponse { code?: number; msg?: string; message?: string; data?: DynamicInvite; }

interface DynamicInviteRequest {
  semester: string;
  allowExtra: boolean;
}

interface SharedScheduleCourse {
  className: string;
  classroom: string;
  teacher: string;
  weekDay: number;
  startWeek: number;
  endWeek: number;
  section: number;
  endSection: number;
}

interface SharedSchedule {
  grantId: string;
  name: string;
  semester: string;
  courses: SharedScheduleCourse[];
}

interface SharedScheduleResponse { code?: number; data?: SharedSchedule; }
interface SharedScheduleHeaders extends Record<string, string> { Authorization: string; Accept: string; }

export function readScheduleQrToken(content: string): string {
  const value = content.trim();
  const legacy = /^wusthelper:\/\/schedule\/([0-9a-f]{64})\/?$/i.exec(value);
  if (legacy) return legacy[1].toLowerCase();
  const current = /^wusthelper:\/\/dynamic-schedule\?token=([0-9a-f]{64})$/i.exec(value);
  return current ? current[1].toLowerCase() : '';
}

export class DynamicScheduleApi {
  private static readonly BASE_URL = 'https://lyzyy.love:8081/api/v1/schedules';
  static async redeemInvite(inviteToken: string): Promise<CourseArchive> {
    const headers = await DynamicScheduleApi.sharedScheduleHeaders();
    const result = await HttpRequest.postRawJson<SharedScheduleResponse>(
      DynamicScheduleApi.BASE_URL + '/redeem', JSON.stringify({ token: inviteToken }), headers);
    return DynamicScheduleApi.toArchive(result.response.responseCode, result.data);
  }

  static async getSharedSchedule(archiveId: string): Promise<CourseArchive> {
    const grantId = /^shared_([0-9a-f]{64})$/.exec(archiveId);
    if (!grantId) throw new Error('共享课表档案无效');
    const headers = await DynamicScheduleApi.sharedScheduleHeaders();
    const result = await HttpRequest.get<SharedScheduleResponse>(
      DynamicScheduleApi.BASE_URL + '/shared/' + grantId[1], headers);
    const archive = DynamicScheduleApi.toArchive(result.response.responseCode, result.data);
    if (archive.id !== archiveId) throw new Error('共享课表响应无效');
    return archive;
  }

  private static async sharedScheduleHeaders(): Promise<SharedScheduleHeaders> {
    const token = (await AppStorage.getInstance().getAppAuthAccessToken()).trim();
    if (!token) throw new Error('请先登录后再查看共享课表');
    const headers: SharedScheduleHeaders = { Authorization: token.startsWith('Bearer ') ? token : 'Bearer ' + token, Accept: 'application/json' };
    return headers;
  }

  private static toArchive(status: number, response: SharedScheduleResponse | undefined): CourseArchive {
    const code = response?.code ?? status;
    if (status === 401 || code === 401) throw new Error('登录已失效，请重新登录后重试');
    if (status === 410 || code === 410) throw new Error('课表二维码已过期或失效，请让分享人重新生成');
    if (code === 404) throw new Error('对方的共享课表已取消或暂不可用');
    if (status !== 200 || code !== 200) throw new Error('获取共享课表失败，请稍后重试');
    const schedule = response?.data;
    if (!schedule || typeof schedule.grantId !== 'string' || !/^[0-9a-f]{64}$/.test(schedule.grantId) ||
      typeof schedule.semester !== 'string' || !schedule.semester.trim() || !Array.isArray(schedule.courses)) {
      throw new Error('共享课表响应无效');
    }

    const courses: CourseData[] = [];
    for (const course of schedule.courses) {
      if (!course || typeof course.className !== 'string' || !course.className.trim() ||
        !Number.isInteger(course.weekDay) || course.weekDay < 1 || course.weekDay > 7 ||
        !Number.isInteger(course.section) || course.section < 1 || course.section > 6 ||
        !Number.isInteger(course.endSection) || course.endSection < 0 || course.endSection > 6 ||
        !Number.isInteger(course.startWeek) || !Number.isInteger(course.endWeek) ||
        course.startWeek < 1 || course.endWeek < course.startWeek) {
        throw new Error('共享课表中存在无效课程');
      }
      // 共享接口用 1–6 表示每两个小节组成的大节。
      const mapped: CourseData = {
        courseName: course.className,
        teacher: course.teacher || '',
        location: course.classroom || '',
        dayOfWeek: course.weekDay,
        startPeriod: course.section * 2 - 1,
        endPeriod: Math.max(course.section, course.endSection) * 2,
        weekRanges: course.startWeek === course.endWeek ? String(course.startWeek) :
          course.startWeek + '-' + course.endWeek
      };
      courses.push(mapped);
    }
    return {
      id: 'shared_' + schedule.grantId,
      name: typeof schedule.name === 'string' && schedule.name.trim() ? schedule.name.trim() : '共享课表',
      semester: schedule.semester,
      courses,
      isMine: false
    };
  }

  static async createInvite(semester: string, allowExtra: boolean): Promise<DynamicInvite> {
    const term: string = semester.trim();
    if (term.length === 0 || term.length > 32) throw new Error('请先在课表页面选择有效学期');
    const token: string = (await AppStorage.getInstance().getAppAuthAccessToken()).trim();
    if (token.length === 0) throw new Error('请先登录后再生成动态二维码');
    const body: DynamicInviteRequest = { semester: term, allowExtra };
    const result = await HttpRequest.postRawJson<DynamicInviteResponse>(
      DynamicScheduleApi.BASE_URL + '/invites',
      JSON.stringify(body),
      { Authorization: token.startsWith('Bearer ') ? token : `Bearer ${token}`, Accept: 'application/json' }
    );
    const code: number = result.data.code ?? 0;
    if (result.response.responseCode !== 200 || (code !== 0 && code !== 200) || !result.data.data?.token) {
      throw new Error(result.data.msg ?? result.data.message ?? `动态课表二维码生成失败（code=${code}）`);
    }
    const invite: DynamicInvite = result.data.data;
    if (!/^[a-f0-9]{64}$/.test(invite.token) || !Number.isFinite(invite.expiresAt) ||
      !Number.isFinite(invite.expiresIn) || invite.expiresIn <= 0) {
      throw new Error('动态课表凭证无效，请重试');
    }
    return invite;
  }
}
