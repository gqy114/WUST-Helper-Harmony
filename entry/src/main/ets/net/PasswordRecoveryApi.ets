import { HttpRequest, RequestResult } from './HttpRequest';

interface RecoveryResponse<T> { code?: number; message?: string; data?: T; }
export interface RecoveryCaptcha { recovery_id?: string; image_base64?: string; }
export interface RecoveryIdentity { account?: string; masked_phone?: string; }
interface RecoveryCooldown { cooldown_seconds?: number; }
interface RecoveryVerified { verified?: boolean; }
interface RecoveryReset { success?: boolean; }

/** 业务错误：保留后端 JSON code，页面据此处理 410/429 等。 */
export class PasswordRecoveryError extends Error {
  code: number;
  cooldown: number;
  constructor(message: string, code: number, cooldown: number = 0) {
    super(message);
    this.code = code;
    this.cooldown = cooldown;
  }
}

export class PasswordRecoveryApi {
  private static readonly BASE: string = 'https://port.happylandmc.cc:52145/UnderGraduate/Support/passwordRecovery';

  private static result<T>(response: RequestResult<RecoveryResponse<T>>, fallback: string): T {
    const data = response.data;
    const code = data && typeof data === 'object' && typeof data.code === 'number' ? data.code : -1;
    if (response.response.responseCode < 200 || response.response.responseCode >= 300 ||
      !data || typeof data !== 'object' || code !== 200 || !data.data) {
      const message = (data && typeof data === 'object' && data.message) || fallback;
      let cooldown = 0;
      if (code === 429 && data && typeof data === 'object') {
        const extra = data.data as Record<string, number> | undefined;
        cooldown = extra?.cooldown_seconds ?? 0;
      }
      throw new PasswordRecoveryError(message, code, cooldown);
    }
    return data.data;
  }

  static async captcha(): Promise<RecoveryCaptcha> {
    const response = await HttpRequest.request<RecoveryResponse<RecoveryCaptcha>>(
      `${PasswordRecoveryApi.BASE}/captcha`, 'GET');
    const data = PasswordRecoveryApi.result<RecoveryCaptcha>(response, '获取图形验证码失败');
    if (!data.recovery_id || !data.image_base64 || data.image_base64.length > 1048576) {
      throw new PasswordRecoveryError('图形验证码加载失败，请重试', -1);
    }
    return data;
  }

  static async identity(recoveryId: string, studentId: string, captchaCode: string): Promise<RecoveryIdentity> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryIdentity>>(
      `${PasswordRecoveryApi.BASE}/identityAuth`, {
        recovery_id: recoveryId, user_id: studentId, captcha_code: captchaCode
      });
    return PasswordRecoveryApi.result<RecoveryIdentity>(response, '账号核对失败');
  }

  static async smsCaptcha(recoveryId: string): Promise<RecoveryCaptcha> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryCaptcha>>(
      `${PasswordRecoveryApi.BASE}/smsCaptcha`, { recovery_id: recoveryId });
    const data = PasswordRecoveryApi.result<RecoveryCaptcha>(response, '获取短信图形验证码失败');
    if (!data.image_base64) throw new PasswordRecoveryError('短信图形验证码加载失败，请重试', -1);
    return data;
  }

  static async sendCode(recoveryId: string, phone: string, captchaCode: string): Promise<number> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryCooldown>>(
      `${PasswordRecoveryApi.BASE}/sendCode`, { recovery_id: recoveryId, phone, captcha_code: captchaCode });
    const data = PasswordRecoveryApi.result<RecoveryCooldown>(response, '短信发送失败');
    return data.cooldown_seconds || 60;
  }

  static async verify(recoveryId: string, code: string): Promise<void> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryVerified>>(
      `${PasswordRecoveryApi.BASE}/verify`, { recovery_id: recoveryId, code });
    if (!PasswordRecoveryApi.result<RecoveryVerified>(response, '短信验证码验证失败').verified) {
      throw new PasswordRecoveryError('短信验证码验证失败', -1);
    }
  }

  static async reset(recoveryId: string, newPassword: string): Promise<void> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryReset>>(
      `${PasswordRecoveryApi.BASE}/reset`, { recovery_id: recoveryId, new_password: newPassword });
    if (!PasswordRecoveryApi.result<RecoveryReset>(response, '密码修改结果无法确认').success) {
      throw new PasswordRecoveryError('密码修改结果无法确认', -1);
    }
  }
}
