
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
const GRADE_API_URL = 'https://wusthelper.wustlinghang.cn/mobileapi/v2/jwc/get-grade';

/** 研究生成绩查询 —— 对应 WustApi.GRADUATE_GRADE_API */
const GRADUATE_GRADE_URL = 'https://wusthelper.wustlinghang.cn/mobileapi/v2/yjs/get-grade';

export class GradeApi {
  /**
   * 获取本科生成绩
   * 安卓原型：NewApiHelper.getGrade(listener) → RequestCenter.getWithBearer(GRADE_API)
   */
  static async getGrade(token: string): Promise<BaseResponse<GradeBean[]>> {
    try {
      const result = await HttpRequest.request<BaseResponse<GradeBean[]>>(
        GRADE_API_URL, 'GET',
        { headers: { Authorization: `Bearer ${token}`, Platform: 'android' } },
      );
      const data = result.data;
      if (data && (data.code === 200 || data.code === 0 || data.code === 10000 || data.code === 11000)) {
        return { code: data.code, msg: data.msg ?? 'ok', data: data.data ?? [] };
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



