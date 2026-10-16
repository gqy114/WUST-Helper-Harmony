import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface DynamicInvite { token: string; expiresAt: number; expiresIn: number; }
interface DynamicInviteResponse { code?: number; msg?: string; message?: string; data?: DynamicInvite; }

export class DynamicScheduleApi {
  private static readonly URL = 'https://lyzyy.love:8081/api/v1/schedules/invites';

  static async createInvite(semester: string, allowExtra: boolean): Promise<DynamicInvite> {
    const token: string = (await AppStorage.getInstance().getAppAuthAccessToken()).trim();
    if (token.length === 0) throw new Error('请先登录后再生成动态二维码');
    const result = await HttpRequest.postJson<DynamicInviteResponse>(
      DynamicScheduleApi.URL,
      { semester, allowExtra: String(allowExtra) },
      { Authorization: `Bearer ${token}`, Accept: 'application/json' },
    );
    const code: number = result.data.code ?? 0;
    if (code !== 0 && code !== 200 || !result.data.data?.token) {
      throw new Error(result.data.msg ?? result.data.message ?? `动态课表二维码生成失败（code=${code}）`);
    }
    return result.data.data;
  }
}
