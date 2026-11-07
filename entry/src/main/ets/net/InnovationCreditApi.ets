import { HttpRequest } from './HttpRequest';

/** Go 后端 InnovationCredit/Support 接口。登录凭据仅在请求体中发送，不落盘。 */
export interface InnovationCreditTicket {
  tgt?: string;
  ticket?: string;
}

/** primaryAuthTicket 的顶层响应。Go 后端把提示放在 message，旧接口放在 msg。 */
export interface InnovationCreditEnvelope {
  code: number;
  msg?: string;
  message?: string;
  data?: InnovationCreditTicket;
}

export class InnovationCreditApi {
  private static readonly URL = 'https://lyzyy.love/InnovationCredit/Support/primaryAuthTicket';

  static async getAuthTicket(studentId: string, password: string): Promise<InnovationCreditTicket> {
    // 学号密码属于敏感请求：只允许 HTTPS，节点故障时不降级。
    const result = await HttpRequest.postJson<InnovationCreditEnvelope>(
      InnovationCreditApi.URL,
      { username: studentId, password: password },
      undefined, undefined, true,
    );
    const envelope = result.data;
    const message = ((envelope.msg || envelope.message || '') as string).trim();
    if (envelope.code !== 200 || !envelope.data) {
      // 例如 TWOVERIFY / invalid password 都在这条错误信息里。
      throw new Error(message || '双创学分认证失败');
    }
    return envelope.data;
  }
}
