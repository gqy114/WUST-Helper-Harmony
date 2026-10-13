
/**
 * GradeApi — 成绩网络接口
 *
 * 对应安卓 GradeModel.getGradeFromNet() → NewApiHelper.getGrade()
 * 接口地址：WustApi.GRADE_API
 *
 * 文件路径：entry/src/main/ets/net/GradeApi.ets
 */
import { HttpRequest } from './HttpRequest';
import { BaseResponse } from '../model/BaseResponse';
import { GradeBean } from '../model/GradeModel';

/** 本科生成绩查询 —— 对应 WustApi.GRADE_API */
const GRADE_API_URL = 'https://www.lyzyy.love/UnderGraduate/Support/GetScorePage';

/** 研究生成绩查询 —— 对应 WustApi.GRADUATE_GRADE_API */
const GRADUATE_GRADE_URL = 'https://wusthelper.wustlinghang.cn/mobileapi/v2/yjs/get-grade';

interface GradeApiEnvelope {
  code?: number;
  message?: string;
  msg?: string;
  data?: RawGrade[];
  list?: RawGrade[];
  grades?: RawGrade[];
  records?: RawGrade[];
}

export class GradeApi {
  /**
   * 获取本科生成绩
   * 安卓原型：NewApiHelper.getGrade(listener) → RequestCenter.getWithBearer(GRADE_API)
   */
  static async getGrade(token: string): Promise<BaseResponse<GradeBean[]>> {
    try {
      const result = await HttpRequest.request<GradeApiEnvelope>(
        GRADE_API_URL, 'GET',
        { headers: { Cookie: token, Accept: 'application/json' } },
      );
      const data = result.data;
      if (data && (data.code === 200 || data.code === 0 || data.code === 10000 || data.code === 11000)) {
        const rows = data.data ?? data.list ?? data.grades ?? data.records ?? [];
        return { code: data.code, msg: data.msg ?? data.message ?? 'ok', data: rows.map(normalizeGrade) };
      }
      return { code: data?.code ?? -1, msg: data?.msg ?? '请求失败', data: [] };
    } catch {
      console.warn('GradeApi', 'getGrade error');
      return { code: -1, msg: '网络请求失败', data: [] };
    }
  }

  /**
   * 获取研究生成绩
   * 安卓原型：NewApiHelper.getGraduateGrade(listener)
   */
  static async getGraduateGrade(token: string): Promise<BaseResponse<GradeBean[]>> {
    try {
      const result = await HttpRequest.request<BaseResponse<GradeBean[]>>(
        GRADUATE_GRADE_URL, 'GET',
        { headers: { Authorization: `Bearer ${token}`, Platform: 'android' } },
      );
      const data = result.data;
      if (data && (data.code === 200 || data.code === 0 || data.code === 10000 || data.code === 11000)) {
        return { code: data.code, msg: data.msg ?? 'ok', data: data.data ?? [] };
      }
      return { code: data?.code ?? -1, msg: data?.msg ?? '请求失败', data: [] };
    } catch {
      console.warn('GradeApi', 'getGraduateGrade error');
      return { code: -1, msg: '网络请求失败', data: [] };
    }
  }
}

interface RawGrade {
  id?: string | number;
  term?: string;
  schoolTerm?: string;
  courseNumber?: string;
  courseNum?: string;
  courseName?: string;
  score?: string | number;
  grade?: string | number;
  credit?: string | number;
  courseCredit?: string | number;
  courseHours?: string | number;
  gradePoint?: string | number;
  evaluateMethod?: string;
  evaluationMode?: string;
  kind?: string;
  courseKind?: string;
  courseNature?: string;
  examNature?: string;
  missExamTag?: number;
  reExamTag?: number;
  rebuildTag?: number;
}

function text(value: string | number | undefined, fallback: string = ''): string {
  return value === undefined || value === null ? fallback : String(value);
}

function normalizeGrade(raw: RawGrade): GradeBean {
  const term = raw.term ?? raw.schoolTerm ?? '';
  return {
    courseNum: raw.courseNumber ?? raw.courseNum ?? '',
    courseName: raw.courseName ?? '',
    grade: text(raw.score ?? raw.grade, '0'),
    courseCredit: text(raw.credit ?? raw.courseCredit, '0'),
    courseHours: text(raw.courseHours, '0'),
    gradePoint: text(raw.gradePoint, '0'),
    evaluationMode: raw.evaluateMethod ?? raw.evaluationMode ?? '',
    examNature: raw.examNature ?? '',
    courseNature: raw.courseKind ?? raw.courseNature ?? raw.kind ?? '',
    schoolTerm: term,
    missExamTag: raw.missExamTag ?? 0,
    reExamTag: raw.reExamTag ?? 0,
    rebuildTag: raw.rebuildTag ?? 0,
  };
}



