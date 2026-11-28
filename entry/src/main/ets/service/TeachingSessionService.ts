import { ApiService } from '../net/ApiService';
import { AppStorage } from '../store/AppStorage';

/**
 * 教务会话只负责实时教务数据，不再代表整个 App 的登录状态。
 * 刷新失败时保留旧 Token、缓存和 AppAuth，供离线功能继续使用。
 */
export class TeachingSessionService {
  private static inFlight: Promise<boolean> | null = null;
  private static refreshEpoch: number = -1;
  private static lastAttemptAt: number = 0;
  private static lastSuccessAt: number = 0;

  static async hasSavedIdentity(): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const epoch = storage.getSessionEpoch();
    const sid = await storage.getStudentId();
    const password = await storage.getPassword();
    return storage.isSessionCurrent(epoch) && sid.trim().length > 0 && password.length > 0;
  }

  static async ensureSession(force: boolean = false): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const epoch = storage.getSessionEpoch();
    const token = (await storage.getToken()).trim();
    if (!storage.isSessionCurrent(epoch)) return false;
    if (!force && token.length > 0) return true;

    const now = Date.now();
    if (TeachingSessionService.refreshEpoch === epoch) {
      if (TeachingSessionService.inFlight) return TeachingSessionService.inFlight;
      if (!force && now - TeachingSessionService.lastAttemptAt < 30_000) return false;
    }

    TeachingSessionService.refreshEpoch = epoch;
    TeachingSessionService.lastAttemptAt = now;
    const task: Promise<boolean> = (async (): Promise<boolean> => {
      try {
        const sid = (await storage.getStudentId()).trim();
        const password = await storage.getPassword();
        const graduate = await storage.getIsGraduate();
        if (!sid || !password || !storage.isSessionCurrent(epoch)) return false;
        const refreshed = graduate
          ? await ApiService.refreshGraduateToken(storage, sid, password, epoch)
          : await ApiService.refreshUndergradToken(storage, sid, password, epoch);
        if (!refreshed || !storage.isSessionCurrent(epoch)) return false;
        TeachingSessionService.lastSuccessAt = Date.now();
        return true;
      } catch {
        return false;
      }
    })();
    TeachingSessionService.inFlight = task;
    try {
      return await task;
    } finally {
      if (TeachingSessionService.inFlight === task) TeachingSessionService.inFlight = null;
    }
  }

  /**
   * Token 足够新就直接复用，超过 maxAgeMs 才重新登录教务。
   * 后台定时任务应使用本方法，避免每分钟强制重新登录学校系统。
   */
  static async ensureFreshSession(maxAgeMs: number = 6 * 60 * 60 * 1000): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const epoch = storage.getSessionEpoch();
    const token = (await storage.getToken()).trim();
    if (!storage.isSessionCurrent(epoch)) return false;
    if (token.length === 0) return TeachingSessionService.ensureSession(true);
    const updatedAt = await storage.getTokenUpdateTime();
    if (!storage.isSessionCurrent(epoch)) return false;
    if (updatedAt > 0 && Date.now() - updatedAt < maxAgeMs) return true;
    return TeachingSessionService.ensureSession(true);
  }

  static lastSuccessfulRefreshAt(): number {
    return TeachingSessionService.lastSuccessAt;
  }
}
