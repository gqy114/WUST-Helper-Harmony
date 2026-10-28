import { ApiService } from '../net/ApiService';
import { AppStorage } from '../store/AppStorage';

/**
 * 教务会话只负责实时教务数据，不再代表整个 App 的登录状态。
 * 刷新失败时保留旧 Token、缓存和 AppAuth，供离线功能继续使用。
 */
export class TeachingSessionService {
  private static refreshing: boolean = false;
  private static lastAttemptAt: number = 0;

  static async hasSavedIdentity(): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const sid = await storage.getStudentId();
    const password = await storage.getPassword();
    return sid.trim().length > 0 && password.length > 0;
  }

  static async ensureSession(force: boolean = false): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const token = await storage.getToken();
    if (!force && token.trim().length > 0) return true;

    const now = Date.now();
    if (TeachingSessionService.refreshing) return false;
    if (!force && now - TeachingSessionService.lastAttemptAt < 30_000) return false;

    const sid = await storage.getStudentId();
    const password = await storage.getPassword();
    if (!sid || !password) return false;

    TeachingSessionService.refreshing = true;
    TeachingSessionService.lastAttemptAt = now;
    try {
      const graduate = await storage.getIsGraduate();
      const refreshed = graduate
        ? await ApiService.refreshGraduateToken(storage, sid, password)
        : await ApiService.refreshUndergradToken(storage, sid, password);
      if (refreshed) await storage.setIsLogin(true);
      return refreshed;
    } catch {
      return false;
    } finally {
      TeachingSessionService.refreshing = false;
    }
  }
}
