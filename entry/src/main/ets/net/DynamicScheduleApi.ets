import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface DynamicInvite { token: string; expiresAt: number; expiresIn: number; }
interface DynamicInviteResponse { code: number; msg?: string; data?: DynamicInvite; }

export class DynamicScheduleApi {
  private static readonly URL = 'https://lyzyy.love:8081/api/v1/schedules/invites';

  static async createInvite(semester: string, allowExtra: boolean): Promise<DynamicInvite> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const result = await HttpRequest.postJson<DynamicInviteResponse>(
      DynamicScheduleApi.URL,
      { semester, allowExtra: String(allowExtra) },
      { Authorization: `Bearer ${token}`, Accept: 'application/json' },
    );
    if (result.data.code !== 200 || !result.data.data?.token) {
      throw new Error(result.data.msg ?? '动态课表二维码生成失败');
    }
    return result.data.data;
  }
}
