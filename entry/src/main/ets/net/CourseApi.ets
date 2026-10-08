import { HttpRequest } from './HttpRequest';
import { BaseResponse } from '../model/BaseResponse';
import { CourseData } from '../model/CourseModel';

/** 本科生课表查询 —— 对应 WustApi.UG_COURSE_TABLE_V2 */
const UG_COURSE_TABLE_URL = 'https://lyzyy.love:8081/UnderGraduate/Support/getCoursesPage';

/** 课表 API 原始返回结构（后端字段名可能为驼峰或下划线） */
export interface CourseApiRawItem {
  courseName?: string;
  teacher?: string;
  location?: string;
  dayOfWeek?: number;
  startPeriod?: number;
  endPeriod?: number;
  weekRanges?: string;
  /** 兼容字段别名 */
  course_name?: string;
  start_period?: number;
  end_period?: number;
  week_ranges?: string;
  day_of_week?: number;
}

export interface CourseApiRawData {
  list?: CourseApiRawItem[];
  semester?: string;
  currentWeek?: number;
  totalWeeks?: number;
  current_week?: number;
  total_weeks?: number;
}

function normalizeItem(raw: CourseApiRawItem): CourseData {
  return {
    courseName: raw.courseName ?? raw.course_name ?? '',
    teacher: raw.teacher ?? '',
    location: raw.location ?? '',
    dayOfWeek: raw.dayOfWeek ?? raw.day_of_week ?? 1,
    startPeriod: raw.startPeriod ?? raw.start_period ?? 1,
    endPeriod: raw.endPeriod ?? raw.end_period ?? 1,
    weekRanges: raw.weekRanges ?? raw.week_ranges ?? '1-16',
  };
}

export class CourseApi {
  /**
   * 按学期获取当前课表
   * @param semester 学期字符串，如 "2025-2026-1"
   * @param token    登录 Token
   */
  static async getCourseTable(semester: string, token: string): Promise<BaseResponse<CourseData[]>> {
    const url = `${UG_COURSE_TABLE_URL}?term=${encodeURIComponent(semester)}`;
    const result = await HttpRequest.get<BaseResponse<CourseApiRawData>>(url, {
      Authorization: `Bearer ${token}`,
      Platform: 'android',
    });
    const respData = result.data;

    if (respData && (respData.code === 200 || respData.code === 0) && respData.data?.list) {
      const rawList: CourseApiRawItem[] = respData.data.list;
      const list: CourseData[] = [];
      for (const raw of rawList) {
        list.push(normalizeItem(raw));
      }
      return { code: respData.code, msg: respData.msg ?? 'ok', data: list };
    }
    return { code: respData?.code ?? -1, msg: respData?.msg ?? '请求失败', data: [] };
  }
}

