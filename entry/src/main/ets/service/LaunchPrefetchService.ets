/**
 * LaunchPrefetchService.ets
 *
 * 启动页展示的 1.5 秒里，把进入 App 后第一屏要用的数据先拉下来：
 * - 「首页设为课表」时：课表 + 本学期起始日（写进本地存档，课表页直接可用）
 * - 否则：主页的轮播与公告（写进 HomeContentApi 的内存缓存）
 *
 * 目标：启动页消失后第一屏不再空等网络。所有失败都静默忽略，
 * 不影响启动流程。
 *
 * 文件路径：entry/src/main/ets/service/LaunchPrefetchService.ets
 */
import { AppStorage } from '../store/AppStorage';
import { TeachingSessionService } from './TeachingSessionService';
import { CourseApi } from '../net/CourseApi';
import { HomeContentApi } from '../net/HomeContentApi';
import { CourseData } from '../model/CourseModel';

const TAG = 'LaunchPrefetch';
/** 预取完成后这段时间内，课表页直接使用预取结果，不再重复请求。 */
const COURSE_FRESH_MS = 15_000;

export class LaunchPrefetchService {
  private static started: boolean = false;
  private static coursePrefetchedAt: number = 0;
  private static task: Promise<void> | null = null;
  private static prefetchedSid: string = '';
  private static prefetchedGraduate: boolean = false;
  private static prefetchedSemester: string = '';

  /** 启动页调用一次即可；重复调用无副作用。 */
  static start(): void {
    if (LaunchPrefetchService.started) return;
    LaunchPrefetchService.started = true;
    LaunchPrefetchService.task = LaunchPrefetchService.run().catch((err: Error) => {
      console.warn(TAG, `prefetch failed: ${err.message}`);
    });
  }

  /**
   * 等待预取结束（最多 timeoutMs）。课表页用它把「读缓存」和「预取写缓存」
   * 排好顺序，避免正好卡在中间时显示旧数据。
   */
  static async awaitPrefetch(timeoutMs: number = 2500): Promise<void> {
    const task = LaunchPrefetchService.task;
    if (task === null) return;
    let timer: number = -1;
    const timeout = new Promise<void>((resolve: () => void) => {
      timer = setTimeout(() => resolve(), timeoutMs);
    });
    await Promise.race([task, timeout]);
    if (timer !== -1) clearTimeout(timer);
  }

  /** 课表是否刚由启动页预取过，并且账号、身份、学期都还是同一份。 */
  static coursePrefetchedRecently(sid: string, graduate: boolean, semester: string): boolean {
    if (LaunchPrefetchService.coursePrefetchedAt <= 0) return false;
    if (Date.now() - LaunchPrefetchService.coursePrefetchedAt >= COURSE_FRESH_MS) return false;
    return LaunchPrefetchService.prefetchedSid === sid &&
      LaunchPrefetchService.prefetchedGraduate === graduate &&
      LaunchPrefetchService.prefetchedSemester === semester;
  }

  private static async run(): Promise<void> {
    const storage = AppStorage.getInstance();
    const sid = await storage.getStudentId();
    // 没登录过（或登录信息被清空）时没有可预取的数据。
    if (!sid) return;
    const courseAsHome = await storage.getCourseAsHome();
    if (courseAsHome) {
      await LaunchPrefetchService.prefetchCourse(storage);
    } else {
      await HomeContentApi.preload();
    }
  }

  /** 预算课表：写进本地存档，课表页 mount 后立刻有数据。 */
  private static async prefetchCourse(storage: AppStorage): Promise<void> {
    // 先同步记下版本号，再读账号/学期：期间任何切号或切学期都会让它对不上。
    const epoch = storage.getSessionEpoch();
    const expectedSid = await storage.getStudentId();
    if (!expectedSid) return;
    const expectedGraduate = await storage.getIsGraduate();
    const semester = (await storage.getSemester()) || LaunchPrefetchService.semesterFallback();

    let token = (await storage.getToken()).trim();
    if (!token) {
      // 开机/升级后 Token 可能为空，先恢复会话，成功再继续。
      await TeachingSessionService.ensureSession(true);
      token = (await storage.getToken()).trim();
    }
    if (!token) return;

    let list: CourseData[] = [];
    try {
      if (expectedGraduate) {
        const pwd = await storage.getPassword();
        if (!pwd) return;
        const result = await CourseApi.getGraduateCourseTable(expectedSid, pwd);
        if (!LaunchPrefetchService.isOk(result.code)) return;
        list = result.data ?? [];
      } else {
        const result = await CourseApi.getCourseTable(semester, token);
        if (!LaunchPrefetchService.isOk(result.code)) return;
        list = result.data ?? [];
      }
    } catch {
      return;
    }
    if (list.length === 0) return;

    // 写入前用内存版本号做一次同步校验：账号或学期在这期间被切换过就丢弃结果。
    if (storage.getSessionEpoch() !== epoch) {
      console.info(TAG, 'account/semester changed during prefetch, discard result');
      return;
    }
    const writeMarker = `prefetch_${epoch}_${Date.now()}`;
    await storage.setCurrentCourses(list, writeMarker);
    LaunchPrefetchService.prefetchedSid = expectedSid;
    LaunchPrefetchService.prefetchedGraduate = expectedGraduate;
    LaunchPrefetchService.prefetchedSemester = semester;
    LaunchPrefetchService.coursePrefetchedAt = Date.now();
    console.info(TAG, `prefetched ${list.length} courses`);

    // 写入过程本身也可能是异步的：写完再核对一次，若期间切号/切学期就把刚写的数据撤掉。
    // 判断「是否仍是我的写入」必须和清空一起放进写入队列，否则旧任务的清空会排在
    // 新课表写入之后执行，把新学期的课表清空。
    if (storage.getSessionEpoch() !== epoch) {
      const rolledBack = await storage.resetCourseCacheIfMarker(writeMarker);
      console.info(TAG, rolledBack ? 'switched during write, rollback prefetched courses'
        : 'newer course write detected, skip rollback');
      LaunchPrefetchService.coursePrefetchedAt = 0;
      LaunchPrefetchService.prefetchedSid = '';
      LaunchPrefetchService.prefetchedSemester = '';
      return;
    }

    // 学期起始日决定当前周次，缓存里没有时顺手补上。
    try {
      const cached = await storage.getTermStartDate();
      if (!cached) {
        const term = await CourseApi.getTermStartDate(token);
        if (LaunchPrefetchService.isOk(term.code) && term.data && term.data.year > 0) {
          const month = term.data.month < 10 ? `0${term.data.month}` : `${term.data.month}`;
          const day = term.data.day < 10 ? `0${term.data.day}` : `${term.data.day}`;
          await storage.setTermStartDate(`${term.data.year}-${month}-${day}`);
        }
      }
    } catch {
      // 学期起始日失败不影响课表展示。
    }
  }

  private static isOk(code: number): boolean {
    return code === 200 || code === 0 || code === 10000;
  }

  /** 与登录页一致的学期兜底：8 月前算第二学期。 */
  private static semesterFallback(): string {
    const now = new Date();
    const year = now.getFullYear();
    return now.getMonth() + 1 >= 8 ? `${year}-${year + 1}-1` : `${year - 1}-${year}-2`;
  }
}
