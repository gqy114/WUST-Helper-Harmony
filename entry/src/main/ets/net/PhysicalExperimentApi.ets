import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
import { CookieManager } from './ApiService';

export interface PhysicalExperimentCourse {
  name?: string;
  courseName?: string;
  classroom?: string;
  weekDay?: number;
  startSection?: number;
  endSection?: number;
  startWeek?: number;
  endWeek?: number;
  [key: string]: Object | undefined;
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
    const cookie = CookieManager.getCookie('www.lyzyy.love') || token;
    const result = await HttpRequest.get<{ code: number; msg?: string; data?: PhysicalExperimentCourse[] }>(
      `${PhysicalExperimentApi.URL}?term=${encodeURIComponent(term)}`,
      { Cookie: cookie, Accept: 'application/json', Platform: 'android' },
    );
    if (result.data.code !== 200 || !Array.isArray(result.data.data)) {
      throw new Error(result.data.msg ?? '物理实验课表获取失败');
    }
    return result.data.data.filter((item) => {
      const text = `${item.name ?? ''}${item.courseName ?? ''}`.toLowerCase();
      return text.includes('实验') || text.includes('physics');
    });
  }
}
