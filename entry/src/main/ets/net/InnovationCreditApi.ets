import { HttpRequest } from './HttpRequest';

/** Go 后端 InnovationCredit/Support 接口。登录凭据仅在请求体中发送，不落盘。 */
export interface InnovationCreditTicket {
  tgt?: string;
  ticket?: string;
}

export class InnovationCreditApi {
  private static readonly URL = 'https://lyzyy.love/InnovationCredit/Support/primaryAuthTicket';

  static async getAuthTicket(studentId: string, password: string): Promise<InnovationCreditTicket> {
    const result = await HttpRequest.postJson<{ code: number; msg?: string; data?: InnovationCreditTicket }>(
      InnovationCreditApi.URL,
      { username: studentId, password },
    );
    if (result.data.code !== 200 || !result.data.data) {
      throw new Error(result.data.msg ?? '双创学分认证失败');
    }
    return result.data.data;
  }
}
