import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface PhysicalExperimentCourse {
  name?: string;
  courseName?: string;
  className?: string;
  course?: string;
  classroom?: string;
  teacher?: string;
  weekDay?: number;
  section?: number;
  startSection?: number;
  endSection?: number;
  startWeek?: number;
  endWeek?: number;
  date?: string;
  startClock?: string;
  endClock?: string;
}

interface PhysicalExperimentResponse {
  code?: number;
  msg?: string;
  message?: string;
  data?: PhysicalExperimentCourse[];
  list?: PhysicalExperimentCourse[];
}

interface PhysicalExperimentRequest extends Record<string, string> {
  username: string;
  password: string;
  gateway_username: string;
  gateway_password: string;
  semester: string;
}

/**
 * 物理实验预约系统拥有独立密码，接口协议与 Android 端保持一致。
 */
export class PhysicalExperimentApi {
  private static readonly URL = 'https://lyzyy.love:8081/Physics/Support/getCourses';

  static async getCourses(term: string, physicalPassword: string): Promise<PhysicalExperimentCourse[]> {
    const storage = AppStorage.getInstance();
    const studentId = await storage.getStudentId();
    const gatewayPassword = await storage.getPassword();
    if (!studentId || !gatewayPassword) {
      throw new Error('未保存主账号密码，请先使用账号密码登录武科大助手');
    }
    const request: PhysicalExperimentRequest = {
      username: studentId, password: physicalPassword,
      gateway_username: studentId, gateway_password: gatewayPassword, semester: term
    };
    const result = await HttpRequest.postJson<PhysicalExperimentResponse>(
      PhysicalExperimentApi.URL, request, { Accept: 'application/json', Platform: 'android' },
    );
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200 && result.data.code !== 10000) {
      throw new Error(result.data.message ?? result.data.msg ?? '物理实验课表获取失败');
    }
    return result.data.data ?? result.data.list ?? [];
  }
}
