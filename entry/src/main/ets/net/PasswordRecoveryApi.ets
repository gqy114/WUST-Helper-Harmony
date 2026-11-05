import { HttpRequest, RequestResult } from './HttpRequest';

interface RecoveryResponse<T> { code?: number; message?: string; data?: T; }
export interface RecoveryCaptcha { recovery_id?: string; image_base64?: string; }
export interface RecoveryIdentity { account?: string; masked_phone?: string; }
interface RecoveryCooldown { cooldown_seconds?: number; }
interface RecoveryVerified { verified?: boolean; }
interface RecoveryReset { success?: boolean; }

/** The recovery ID is stored in server memory, so every step must use the same HTTPS node. */
export class PasswordRecoveryApi {
  private static readonly BASE: string = 'https://lyzyy.love:8081/UnderGraduate/Support/passwordRecovery';

  private static result<T>(response: RequestResult<RecoveryResponse<T>>, fallback: string): T {
    const data = response.data;
    if (response.response.responseCode < 200 || response.response.responseCode >= 300 ||
      !data || typeof data !== 'object' || data.code !== 200 || !data.data) {
      throw new Error((data && typeof data === 'object' && data.message) || fallback);
    }
    return data.data;
  }

  static async captcha(): Promise<RecoveryCaptcha> {
    const response = await HttpRequest.request<RecoveryResponse<RecoveryCaptcha>>(
      `${PasswordRecoveryApi.BASE}/captcha`, 'GET', { pinBackend: true });
    const data = PasswordRecoveryApi.result<RecoveryCaptcha>(response, '获取图形验证码失败');
    if (!data.recovery_id || !data.image_base64 || data.image_base64.length > 1048576) {
      throw new Error('图形验证码加载失败，请重试');
    }
    return data;
  }

  static async identity(recoveryId: string, studentId: string, name: string, idCard: string,
    captchaCode: string): Promise<RecoveryIdentity> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryIdentity>>(
      `${PasswordRecoveryApi.BASE}/identityAuth`, {
        recovery_id: recoveryId, user_id: studentId, user_name: name, id_card: idCard, captcha_code: captchaCode
      });
    return PasswordRecoveryApi.result<RecoveryIdentity>(response, '身份验证失败');
  }

  static async sendCode(recoveryId: string): Promise<number> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryCooldown>>(
      `${PasswordRecoveryApi.BASE}/sendCode`, { recovery_id: recoveryId });
    const data = PasswordRecoveryApi.result<RecoveryCooldown>(response, '短信发送失败');
    return data.cooldown_seconds || 60;
  }

  static async verify(recoveryId: string, code: string): Promise<void> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryVerified>>(
      `${PasswordRecoveryApi.BASE}/verify`, { recovery_id: recoveryId, code });
    if (!PasswordRecoveryApi.result<RecoveryVerified>(response, '短信验证码验证失败').verified) {
      throw new Error('短信验证码验证失败');
    }
  }

  static async reset(recoveryId: string, newPassword: string): Promise<void> {
    const response = await HttpRequest.postJsonPinned<RecoveryResponse<RecoveryReset>>(
      `${PasswordRecoveryApi.BASE}/reset`, { recovery_id: recoveryId, new_password: newPassword });
    if (!PasswordRecoveryApi.result<RecoveryReset>(response, '密码修改结果无法确认').success) {
      throw new Error('密码修改结果无法确认');
    }
  }
}
