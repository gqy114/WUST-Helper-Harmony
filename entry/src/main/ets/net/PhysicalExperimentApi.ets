import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface PhysicalExperimentCourse {
  name?: string;
  courseName?: string;
  classroom?: string;
  weekDay?: number;
  startSection?: number;
  endSection?: number;
  startWeek?: number;
  endWeek?: number;
}

interface PhysicalExperimentResponse {
  code: number;
  msg?: string;
  data?: PhysicalExperimentCourse[];
}

/**
 * 物理实验由 Go 后端 getCoursesPage 统一抓取并合并实验课表。
 * Android 后端对应 bkjx.wust.edu.cn/jsxsd/syjx/toXskb.do。
 */
export class PhysicalExperimentApi {
  private static readonly URL = 'https://lyzyy.love/UnderGraduate/Support/getCoursesPage';

  static async getCourses(term: string): Promise<PhysicalExperimentCourse[]> {
    const storage = AppStorage.getInstance();
    const token = await storage.getToken();
    const result = await HttpRequest.get<PhysicalExperimentResponse>(
      `${PhysicalExperimentApi.URL}?term=${encodeURIComponent(term)}`,
      { Authorization: token.trim().startsWith('Bearer ') ? token.trim() : `Bearer ${token.trim()}`, Accept: 'application/json', Platform: 'android' },
    );
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200 && result.data.code !== 10000) {
      throw new Error(result.data.msg ?? '物理实验课表获取失败');
    }
    const courses: PhysicalExperimentCourse[] = result.data.data ?? [];
    return courses.filter((item) => {
      const text = `${item.name ?? ''}${item.courseName ?? ''}`.toLowerCase();
      return text.includes('实验') || text.includes('physics');
    });
  }
}
