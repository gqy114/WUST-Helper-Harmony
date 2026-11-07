import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface SecondClassroomModule {
  id: string;
  name: string;
  required_credit: number;
  earned_credit: number;
  required_compulsory_credit: number;
  earned_compulsory_credit: number;
  required_elective_credit: number;
  earned_elective_credit: number;
  compulsory_complete: boolean;
  elective_complete: boolean;
}

/** 第二课堂活动记录保留后端原字段，便于兼容学校接口的字段命名。 */
export interface SecondClassroomActivity {
  ID?: string;
  SHZT?: string;
  XN?: string;
  XQ?: string;
  MKNR?: string;
  XMNR?: string;
  HDRQ?: string;
  HDJF?: number | string;
}

export interface SecondClassroomActivities {
  totalSize: number;
  pageNumber: number;
  pageSize: number;
  rows: SecondClassroomActivity[];
}

export interface SecondClassroomSummary {
  total_credit: number;
  evaluation: string;
  modules: SecondClassroomModule[];
  approved_projects?: Object[];
  rules?: Object;
  activities: SecondClassroomActivities;
}

interface SecondClassroomResponse {
  code?: number;
  message?: string;
  msg?: string;
  data?: SecondClassroomSummary;
}

export class SecondClassroomApi {
  private static readonly URL = 'https://lyzyy.love:8081/SecondClassroom/Support/summary';

  static async summary(page: number = 1, pageSize: number = 100): Promise<SecondClassroomSummary> {
    const storage = AppStorage.getInstance();
    const username = await storage.getStudentId();
    const password = await storage.getPassword();
    if (!username || !password) throw new Error('未保存统一认证账号或密码');

    const result = await HttpRequest.postJson<SecondClassroomResponse>(SecondClassroomApi.URL, {
      username,
      password,
      page: `${page}`,
      page_size: `${pageSize}`
    }, undefined, undefined, true);
    const response = result.data;
    const code = response.code;
    if ((code !== undefined && code !== 0 && code !== 200) || !response.data) {
      throw new Error(response.message || response.msg || '第二课堂数据获取失败');
    }
    return response.data;
  }
}
