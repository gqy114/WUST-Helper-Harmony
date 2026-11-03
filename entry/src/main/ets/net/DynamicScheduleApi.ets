import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface DynamicInvite { token: string; expiresAt: number; expiresIn: number; }
interface DynamicInviteResponse { code?: number; msg?: string; message?: string; data?: DynamicInvite; }

interface DynamicInviteRequest {
  semester: string;
  allowExtra: boolean;
}

export class DynamicScheduleApi {
  private static readonly URL = 'https://lyzyy.love:8081/api/v1/schedules/invites';

  static async createInvite(semester: string, allowExtra: boolean): Promise<DynamicInvite> {
    const term: string = semester.trim();
    if (term.length === 0 || term.length > 32) throw new Error('请先在课表页面选择有效学期');
    const token: string = (await AppStorage.getInstance().getAppAuthAccessToken()).trim();
    if (token.length === 0) throw new Error('请先登录后再生成动态二维码');
    const body: DynamicInviteRequest = { semester: term, allowExtra };
    const result = await HttpRequest.postRawJson<DynamicInviteResponse>(
      DynamicScheduleApi.URL,
      JSON.stringify(body),
      { Authorization: token.startsWith('Bearer ') ? token : `Bearer ${token}`, Accept: 'application/json' }
    );
    const code: number = result.data.code ?? 0;
    if (result.response.responseCode !== 200 || (code !== 0 && code !== 200) || !result.data.data?.token) {
      throw new Error(result.data.msg ?? result.data.message ?? `动态课表二维码生成失败（code=${code}）`);
    }
    const invite: DynamicInvite = result.data.data;
    if (!/^[a-f0-9]{64}$/.test(invite.token) || !Number.isFinite(invite.expiresAt) ||
      !Number.isFinite(invite.expiresIn) || invite.expiresIn <= 0) {
      throw new Error('动态课表凭证无效，请重试');
    }
    return invite;
  }
}
