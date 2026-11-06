import { ApiService } from '../net/ApiService';
import { AppStorage } from '../store/AppStorage';

/**
 * 教务会话只负责实时教务数据，不再代表整个 App 的登录状态。
 * 刷新失败时保留旧 Token、缓存和 AppAuth，供离线功能继续使用。
 */
export class TeachingSessionService {
  /** 正在进行的刷新任务。并发调用共享同一个 Promise，避免 return false 让调用方误判。 */
  private static inFlight: Promise<boolean> | null = null;
  private static lastAttemptAt: number = 0;
  private static lastSuccessAt: number = 0;

  static async hasSavedIdentity(): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const sid = await storage.getStudentId();
    const password = await storage.getPassword();
    return sid.trim().length > 0 && password.length > 0;
  }

  static async ensureSession(force: boolean = false): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const token = (await storage.getToken()).trim();
    if (!force && token.length > 0) return true;

    // 已有刷新在进行时直接等待它，不要返回 false：调用方会据此认为会话不可用。
    if (TeachingSessionService.inFlight) return TeachingSessionService.inFlight;

    const now = Date.now();
    if (!force && now - TeachingSessionService.lastAttemptAt < 30_000) return false;

    const sid = await storage.getStudentId();
    const password = await storage.getPassword();
    if (!sid || !password) return false;

    TeachingSessionService.lastAttemptAt = now;
    const task: Promise<boolean> = (async (): Promise<boolean> => {
      try {
        const graduate = await storage.getIsGraduate();
        const refreshed = graduate
          ? await ApiService.refreshGraduateToken(storage, sid, password)
          : await ApiService.refreshUndergradToken(storage, sid, password);
        if (refreshed) {
          await storage.setIsLogin(true);
          TeachingSessionService.lastSuccessAt = Date.now();
        }
        return refreshed;
      } catch {
        return false;
      }
    })();
    TeachingSessionService.inFlight = task;
    try {
      return await task;
    } finally {
      TeachingSessionService.inFlight = null;
    }
  }

  /**
   * Token 足够新就直接复用，超过 maxAgeMs 才重新登录教务。
   * 后台定时任务应使用本方法，避免每分钟强制重新登录学校系统。
   */
  static async ensureFreshSession(maxAgeMs: number = 6 * 60 * 60 * 1000): Promise<boolean> {
    const storage = AppStorage.getInstance();
    const token = (await storage.getToken()).trim();
    if (token.length === 0) return TeachingSessionService.ensureSession(true);
    const updatedAt = await storage.getTokenUpdateTime();
    if (updatedAt > 0 && Date.now() - updatedAt < maxAgeMs) return true;
    return TeachingSessionService.ensureSession(true);
  }

  static lastSuccessfulRefreshAt(): number {
    return TeachingSessionService.lastSuccessAt;
  }
}
