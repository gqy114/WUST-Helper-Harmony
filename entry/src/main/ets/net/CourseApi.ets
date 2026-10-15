import { HttpRequest } from './HttpRequest';
import { BaseResponse } from '../model/BaseResponse';
import { CourseData } from '../model/CourseModel';

/** 本科生课表查询 —— 一步式生效接口 */
const UG_COURSE_TABLE_URL = 'https://lyzyy.love:8081/UnderGraduate/Support/getCoursesPage';
const UG_COURSE_TABLE_BACKUP_URL = 'https://www.lyzyy.love:8081/UnderGraduate/Support/getCoursesPage';

/** 学期起始日接口（用于计算真实当前周）。 */
const UG_TERM_STARTDATE_URL = 'https://lyzyy.love:8081/UnderGraduate/Support/getData';
const UG_TERM_STARTDATE_BACKUP_URL = 'https://www.lyzyy.love:8081/UnderGraduate/Support/getData';

/** 一步式课表接口原始返回项。字段名与教务处接口保持一致。 */
export interface CourseApiRawItem {
  className?: string;
  name?: string;
  courseName?: string;
  teacher?: string;
  classroom?: string;
  Classroom?: string;
  classNo?: string;
  startWeek?: string | number;
  endWeek?: string | number;
  section?: string | number;
  startSection?: string | number;
  endSection?: string | number;
  start_section?: string | number;
  end_section?: string | number;
  weekDay?: string | number;
  weekday?: string | number;
  dayOfWeek?: string | number;
}

/** 一步式课表接口顶层响应。成功时 data 是课程数组。 */
export interface CourseApiEnvelope {
  code?: number;
  msg?: string;
  data?: CourseApiRawItem[];
}

/** 学期起始日 data 内容。month 为 1-12。 */
export interface TermStartDateContent {
  year?: number;
  month?: number;
  day?: number;
}

/** 学期起始日接口顶层响应。 */
export interface TermStartDateEnvelope {
  code?: number;
  msg?: string;
  data?: TermStartDateContent;
}

/** 归一化后的学期起始日。 */
export interface TermStartDateResult {
  year: number;
  month: number;
  day: number;
}
interface CourseHttpResult<T> { data: T; }
interface CourseHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }

function asInt(value: string | number | undefined, fallback: number): number {
  if (value === undefined || value === '') {
    return fallback;
  }
  const n = typeof value === 'number' ? value : parseInt(value, 10);
  return isNaN(n) ? fallback : n;
}

function firstValue(value: string | undefined): string {
  return value === undefined ? '' : value;
}

function normalizeItem(raw: CourseApiRawItem): CourseData {
  // 安卓端 CourseBean 的 section/endSection 是实际节次（1-12）。
  const rawStart = raw.section ?? raw.startSection ?? raw.start_section;
  const rawEnd = raw.endSection ?? raw.end_section;
  // 防止后端异常值把课程块绘制成整列；课表最多 12 节。
  const parsedStart = asInt(rawStart, 1);
  const startPeriod = Math.max(1, Math.min(12, parsedStart));
  const parsedEnd = asInt(rawEnd, startPeriod);
  const endPeriod = Math.max(startPeriod, Math.min(12, parsedEnd));
  const startWeek = asInt(raw.startWeek, 1);
  const endWeek = asInt(raw.endWeek, startWeek);
  const weekdayRaw = asInt(raw.weekDay, 1);
  const dayOfWeek = weekdayRaw >= 1 && weekdayRaw <= 7 ? weekdayRaw : 1;
  const weekRanges = startWeek === endWeek ? `${startWeek}` : `${startWeek}-${endWeek}`;

  return {
    courseName: firstValue(raw.className) || firstValue(raw.name) || firstValue(raw.courseName),
    teacher: firstValue(raw.teacher),
    location: firstValue(raw.classroom) || firstValue(raw.Classroom),
    dayOfWeek: dayOfWeek,
    startPeriod: startPeriod,
    endPeriod: endPeriod,
    weekRanges: weekRanges,
  };
}

export class CourseApi {
  /**
   * 按学期获取当前课表
   * @param semester 学期字符串，如 "2025-2026-1"
   * @param token    登录后拿到的 legacy token（作为 Bearer token 使用）
   */
  static async getCourseTable(semester: string, token: string): Promise<BaseResponse<CourseData[]>> {
    try {
      const headers: CourseHeaders = {
        Authorization: token.trim().startsWith('Bearer ') ? token.trim() : `Bearer ${token.trim()}`,
        Platform: 'android',
        Accept: 'application/json',
      };
      let result: CourseHttpResult<CourseApiEnvelope>;
      try {
        result = await HttpRequest.get<CourseApiEnvelope>(`${UG_COURSE_TABLE_URL}?term=${encodeURIComponent(semester)}`, headers);
      } catch {
        result = await HttpRequest.get<CourseApiEnvelope>(`${UG_COURSE_TABLE_BACKUP_URL}?term=${encodeURIComponent(semester)}`, headers);
      }
      const resp = result.data;

      if (resp && (resp.code === 10000 || resp.code === 200 || resp.code === 0) && resp.data) {
        const list: CourseData[] = [];
        for (let i = 0; i < resp.data.length; i++) {
          list.push(normalizeItem(resp.data[i]));
        }
        return {
          code: resp.code !== undefined ? resp.code : 10000,
          msg: firstValue(resp.msg),
          data: list,
        };
      }

      return {
        code: resp && resp.code !== undefined ? resp.code : -1,
        msg: resp && resp.msg !== undefined ? resp.msg : '请求失败',
        data: [],
      };
    } catch {
      console.warn('CourseApi', 'getCourseTable error');
      return { code: -1, msg: '网络请求失败', data: [] };
    }
  }

  /**
   * 获取学期起始日。
   * Android 端走 getWithBearer，即 Authorization: Bearer <token>。
   */
  static async getTermStartDate(token: string): Promise<BaseResponse<TermStartDateResult>> {
    try {
      let result: CourseHttpResult<TermStartDateEnvelope>;
      try {
        result = await HttpRequest.get<TermStartDateEnvelope>(UG_TERM_STARTDATE_URL, { Authorization: `Bearer ${token}` });
      } catch {
        result = await HttpRequest.get<TermStartDateEnvelope>(UG_TERM_STARTDATE_BACKUP_URL, { Authorization: `Bearer ${token}` });
      }
      const resp = result.data;

      if (resp && (resp.code === 10000 || resp.code === 200 || resp.code === 0) && resp.data) {
        const year = resp.data.year !== undefined ? resp.data.year : 0;
        const month = resp.data.month !== undefined ? resp.data.month : 0;
        const day = resp.data.day !== undefined ? resp.data.day : 0;
        if (year > 0 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return {
            code: resp.code !== undefined ? resp.code : 10000,
            msg: firstValue(resp.msg),
            data: { year: year, month: month, day: day },
          };
        }
        return { code: -1, msg: '学期起始日数据不完整' };
      }

      return {
        code: resp && resp.code !== undefined ? resp.code : -1,
        msg: resp && resp.msg !== undefined ? resp.msg : '请求失败',
      };
    } catch {
      console.warn('CourseApi', 'getTermStartDate error');
      return { code: -1, msg: '网络请求失败' };
    }
  }
}

