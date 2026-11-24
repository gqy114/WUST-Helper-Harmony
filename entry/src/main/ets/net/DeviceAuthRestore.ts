import { AppStorage } from '../store/AppStorage';
import { ApiService } from './ApiService';
import { UndergradDeviceLogin } from './UndergradDeviceLogin';

/**
 * 本科 App 会话恢复：
 * 1. 先用保存的教务 Cookie 调 deviceLogin/complete 换新会话；
 * 2. complete 返回 401（Cookie 失效）才回退到保存的学号密码设备登录；
 * 3. 其它错误或网络失败直接返回失败，不主动用密码重登。
 */
export class DeviceAuthRestore {
  static async restore(storage: AppStorage): Promise<void> {
    const sessionEpoch = storage.getSessionEpoch();
    const studentId = await storage.getStudentId();
    if (!studentId) return;
    if (storage.getSessionEpoch() !== sessionEpoch) return;
    const isGraduate = await storage.getIsGraduate();
    if (!isGraduate) {
      const cookie = (await storage.getToken()).trim();
      if (cookie.length > 0) {
        try {
          const outcome = await UndergradDeviceLogin.complete(studentId, cookie);
          if (outcome.code === 200 && outcome.data?.appAuth) {
            const appAuth = outcome.data.appAuth;
            if (storage.getSessionEpoch() !== sessionEpoch) return;
            const saved = await storage.setAppAuthTokensIfSession(sessionEpoch, studentId,
              appAuth.accessToken ?? '', appAuth.refreshToken ?? '',
              appAuth.expiresAt ?? 0, appAuth.refreshExpiresAt ?? 0);
            if (saved && appAuth.user?.avatarUrl) {
              await storage.setAvatarUrlForAccount(sessionEpoch, studentId, appAuth.user.avatarUrl);
            }
            return;
          }
          if (outcome.code !== 401) return;
        } catch (error) {
          console.warn('DeviceAuthRestore', `complete failed: ${JSON.stringify(error)}`);
          return;
        }
      }
    }
    // 没有 Cookie 或 Cookie 已失效：沿用保存的学号密码恢复。
    await ApiService.loginAppAuthFromSavedCredentials(storage);
  }
}
