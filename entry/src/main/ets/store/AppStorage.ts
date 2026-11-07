/**
 * 对应原 Android 端 SharePreferenceLab + SPTool
 * 统一封装 preferences，单 store 存储
 *
 * 文件路径：entry/src/main/ets/store/AppStorage.ts
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ScheduleSettings, DEFAULT_SETTINGS, CourseArchive, CourseData } from '../model/CourseModel';

const STORE_NAME = 'wusthelper_prefs';

export class AppStorage {
  private static instance: AppStorage;
  private kvStore: preferences.Preferences | null = null;

  /** 最近一次课表缓存的写入标记：异步写入者用它判断自己是否仍是最后一次写入。 */
  private courseCacheMarker: string = '';

  getCourseCacheMarker(): string { return this.courseCacheMarker; }

  private constructor() {}

  static getInstance(): AppStorage {
    if (!AppStorage.instance) {
      AppStorage.instance = new AppStorage();
    }
    return AppStorage.instance;
  }

  async init(context: common.Context): Promise<void> {
    this.kvStore = await preferences.getPreferences(context, STORE_NAME);
    // 升级后第一次启动就确定旧档案归属，而不是等用户点开档案页。
    await this.claimLegacyArchives();
  }

  /**
   * 旧版本只有全局课表档案。认领必须发生在「首个账号启动/登录」时点，
   * 否则 A 升级后没打开档案页就切到 B，B 会误认领 A 的档案。
   * 旧数据只复制不删除。
   */
  private async claimLegacyArchives(): Promise<void> {
    const migrated = await this.getBool('courseArchivesMigrated', false);
    if (migrated) {
      return;
    }
    const sid = await this.getStudentId();
    if (!sid) {
      return;
    }
    const legacy = await this.getStr('courseArchives', '');
    if (legacy) {
      const scopedKey = await this.archiveKey('courseArchives');
      if (!(await this.getStr(scopedKey, ''))) {
        await this.putStr(scopedKey, legacy);
      }
    }
    const legacyId = await this.getStr('currentArchiveId', '');
    if (legacyId) {
      const scopedIdKey = await this.archiveKey('currentArchiveId');
      if (!(await this.getStr(scopedIdKey, ''))) {
        await this.putStr(scopedIdKey, legacyId);
      }
    }
    await this.putBool('courseArchivesMigrated', true);
  }

  // ── 低层读写 ──

  private async getStr(key: string, def: string = ''): Promise<string> {
    const raw = await this.kvStore?.get(key, JSON.stringify(def));
    if (raw === undefined) {
      return def;
    }
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        return typeof parsed === 'string' ? parsed : def;
      } catch {
        return def;
      }
    }
    return typeof raw === 'string' ? raw : def;
  }

  private async putStr(key: string, value: string): Promise<void> {
    await this.kvStore?.put(key, JSON.stringify(value));
    await this.kvStore?.flush();
  }

  private async getBool(key: string, def: boolean = false): Promise<boolean> {
    const raw = await this.kvStore?.get(key, JSON.stringify(def));
    if (raw === undefined) {
      return def;
    }
    if (typeof raw === 'boolean') {
      return raw;
    }
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        return typeof parsed === 'boolean' ? parsed : def;
      } catch {
        return def;
      }
    }
    return def;
  }

  private async putBool(key: string, value: boolean): Promise<void> {
    await this.kvStore?.put(key, JSON.stringify(value));
    await this.kvStore?.flush();
  }

  private async getNum(key: string, def: number = 0): Promise<number> {
    const raw = await this.kvStore?.get(key, JSON.stringify(def));
    return raw !== undefined ? JSON.parse(raw as string) : def;
  }

  private async putNum(key: string, value: number): Promise<void> {
    await this.kvStore?.put(key, JSON.stringify(value));
    await this.kvStore?.flush();
  }

  // ── Mock 模拟开关 ──

  async getUseMock(): Promise<boolean> { return this.getBool('useMock', false); }
  async setUseMock(v: boolean): Promise<void> { return this.putBool('useMock', v); }

  // ── 学期 ──

  async getSemester(): Promise<string> { return this.getStr('semester'); }
  async setSemester(v: string): Promise<void> { return this.putStr('semester', v); }
  async getSelectSemester(): Promise<string> { return this.getStr('selectSemester'); }
  async setSelectSemester(v: string): Promise<void> { return this.putStr('selectSemester', v); }

  // ── 日期与周次 ──

  async getDate(): Promise<string> { return this.getStr('date'); }
  async setDate(v: string): Promise<void> { return this.putStr('date', v); }
  async getWeek(): Promise<number> { return this.getNum('week'); }
  async setWeek(v: number): Promise<void> { return this.putNum('week', v); }
  async getWeekday(): Promise<number> { return this.getNum('weekday'); }
  async setWeekday(v: number): Promise<void> { return this.putNum('weekday', v); }
  async getTermStartDate(): Promise<string> { return this.getStr('termStartDate'); }
  async setTermStartDate(v: string): Promise<void> { return this.putStr('termStartDate', v); }

  // ── 登录与 Token ──

  async getIsLogin(): Promise<boolean> { return this.getBool('isLogin'); }
  async setIsLogin(v: boolean): Promise<void> { return this.putBool('isLogin', v); }
  async getToken(): Promise<string> { return this.getStr('token'); }
  async setToken(v: string): Promise<void> { return this.putStr('token', v); }
  async getStudentId(): Promise<string> { return this.getStr('studentId'); }
  async setStudentId(v: string): Promise<void> {
    await this.putStr('studentId', v);
    // 升级后还没重启过就登录：在这里补一次旧档案认领，保证在切号前完成。
    await this.claimLegacyArchives();
  }
  async getPassword(): Promise<string> { return this.getStr('password'); }
  async setPassword(v: string): Promise<void> { return this.putStr('password', v); }
  async getPhysicalExperimentPassword(): Promise<string> { return this.getStr('physicalExperimentPassword'); }
  async setPhysicalExperimentPassword(v: string): Promise<void> { return this.putStr('physicalExperimentPassword', v); }
  async getMessage(): Promise<string> { return this.getStr('login_msg'); }
  async setMessage(v: string): Promise<void> { return this.putStr('login_msg', v); }
  async getIsGraduate(): Promise<boolean> { return this.getBool('isGraduate'); }
  async setIsGraduate(v: boolean): Promise<void> { return this.putBool('isGraduate', v); }
  async getTokenUpdateTime(): Promise<number> { return this.getNum('token_update_time'); }
  async setTokenUpdateTime(v: number): Promise<void> { return this.putNum('token_update_time', v); }
  async getTokenLastUseTime(): Promise<number> { return this.getNum('token_last_use_time'); }
  async setTokenLastUseTime(v: number): Promise<void> { return this.putNum('token_last_use_time', v); }

  // ── 用户信息 ──

  async getRealName(): Promise<string> { return this.getStr('realName'); }
  async setRealName(v: string): Promise<void> { return this.putStr('realName', v); }
  async getUserName(): Promise<string> { return this.getStr('userName'); }
  async setUserName(v: string): Promise<void> { return this.putStr('userName', v); }
  async getCollege(): Promise<string> { return this.getStr('college'); }
  async setCollege(v: string): Promise<void> { return this.putStr('college', v); }
  async getMajor(): Promise<string> { return this.getStr('major'); }
  async setMajor(v: string): Promise<void> { return this.putStr('major', v); }
  async getAvatarUrl(): Promise<string> { return this.getStr('avatarUrl'); }
  async setAvatarUrl(v: string): Promise<void> { return this.putStr('avatarUrl', v); }
  async getClasses(): Promise<string> { return this.getStr('classes'); }
  async setClasses(v: string): Promise<void> { return this.putStr('classes', v); }

  // ── App Auth ──

  async getAppAuthAccessToken(): Promise<string> { return this.getStr('appAuthAccessToken'); }
  async setAppAuthAccessToken(v: string): Promise<void> { return this.putStr('appAuthAccessToken', v); }
  async getAppAuthRefreshToken(): Promise<string> { return this.getStr('appAuthRefreshToken'); }
  async setAppAuthRefreshToken(v: string): Promise<void> { return this.putStr('appAuthRefreshToken', v); }
  async getAppAuthExpiresAt(): Promise<number> { return this.getNum('appAuthExpiresAt'); }
  async setAppAuthExpiresAt(v: number): Promise<void> { return this.putNum('appAuthExpiresAt', v); }
  async getAppAuthRefreshExpiresAt(): Promise<number> { return this.getNum('appAuthRefreshExpiresAt'); }
  async setAppAuthRefreshExpiresAt(v: number): Promise<void> { return this.putNum('appAuthRefreshExpiresAt',
    v); }

  async hasUsableAppAuthToken(): Promise<boolean> {
    const token = await this.getAppAuthAccessToken();
    const expiresAt = await this.getAppAuthExpiresAt();
    if (!token || token.trim().length === 0) return false;
    return expiresAt > Date.now() + 60_000;
  }

  async getScheduleSettings(): Promise<ScheduleSettings> {
    const raw = await this.getStr('scheduleSettings', '');
    if (raw) {
      return JSON.parse(raw) as ScheduleSettings;
    }
    return DEFAULT_SETTINGS;
  }

  async setScheduleSettings(settings: ScheduleSettings): Promise<void> {
    await this.putStr('scheduleSettings', JSON.stringify(settings));
  }

  // ── 课表与日程设置 ──

  async getCourseAsHome(): Promise<boolean> { return this.getBool('courseAsHome', true); }
  async setCourseAsHome(value: boolean): Promise<void> { return this.putBool('courseAsHome', value); }
  async getSundayFirst(): Promise<boolean> { return this.getBool('sundayFirst'); }
  async setSundayFirst(value: boolean): Promise<void> { return this.putBool('sundayFirst', value); }
  async getAllWeeksImported(): Promise<boolean> { return this.getBool('allWeeksImported'); }
  async setAllWeeksImported(value: boolean): Promise<void> { return this.putBool('allWeeksImported', value); }
  async getImportedEventIds(): Promise<number[]> {
    const raw = await this.getStr('importedEventIds', '');
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as number[];
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  async setImportedEventIds(value: number[]): Promise<void> {
    return this.putStr('importedEventIds', JSON.stringify(value));
  }

  /** 课表档案按账号隔离：同一台设备上不同学号互不可见。 */
  private async archiveKey(base: string): Promise<string> {
    const sid = await this.getStudentId();
    return sid ? `${base}_${sid}` : base;
  }

  private parseArchives(raw: string): CourseArchive[] {
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw) as CourseArchive[];
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  async getCourseArchives(): Promise<CourseArchive[]> {
    const sid = await this.getStudentId();
    if (!sid) {
      // 还没登录：不认领旧档案，避免升级后第一个点开档案页的账号被动接收。
      return this.parseArchives(await this.getStr('courseArchives', ''));
    }
    const key = await this.archiveKey('courseArchives');
    let raw = await this.getStr(key, '');
    if (!raw) {
      // 旧版本只有全局档案：只允许升级后首次启动的那个账号认领一次，
      // 之后其它账号不再继承，避免 A 的档案出现在 B 的列表里。
      const migrated = await this.getBool('courseArchivesMigrated', false);
      if (!migrated) {
        const legacy = await this.getStr('courseArchives', '');
        if (legacy) {
          await this.putStr(key, legacy);
          raw = legacy;
        }
        const legacyId = await this.getStr('currentArchiveId', '');
        if (legacyId) {
          await this.putStr(await this.archiveKey('currentArchiveId'), legacyId);
        }
        await this.putBool('courseArchivesMigrated', true);
      }
    }
    return this.parseArchives(raw);
  }

  async setCourseArchives(value: CourseArchive[]): Promise<void> {
    return this.putStr(await this.archiveKey('courseArchives'), JSON.stringify(value));
  }

  async getCurrentArchiveId(): Promise<string> {
    return this.getStr(await this.archiveKey('currentArchiveId'), 'mine');
  }

  async setCurrentArchiveId(value: string): Promise<void> {
    return this.putStr(await this.archiveKey('currentArchiveId'), value);
  }

  private async getStoredCourses(key: string): Promise<CourseData[]> {
    const raw = await this.getStr(key, '');
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as CourseData[];
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  private isPhysicalExperimentCourse(course: CourseData): boolean {
    return course.isPhysicalExperiment === true || course.courseName.indexOf('物理实验') >= 0 ||
      /^实验\d+-\d+/.test(course.courseName);
  }

  private normalizePhysicalExperiment(course: CourseData): CourseData {
    return {
      courseName: course.courseName,
      teacher: course.teacher,
      location: course.location,
      dayOfWeek: course.dayOfWeek,
      startPeriod: course.startPeriod,
      endPeriod: course.endPeriod,
      weekRanges: course.weekRanges,
      color: course.color,
      isPhysicalExperiment: true,
      physicalDate: course.physicalDate
    };
  }

  private isSamePhysicalExperiment(left: CourseData, right: CourseData): boolean {
    if (left.courseName !== right.courseName) return false;
    if (left.physicalDate && right.physicalDate) return left.physicalDate === right.physicalDate;
    return left.dayOfWeek === right.dayOfWeek && left.startPeriod === right.startPeriod &&
      left.endPeriod === right.endPeriod && left.weekRanges === right.weekRanges && left.location === right.location;
  }

  private mergePhysicalExperiments(courses: CourseData[], experiments: CourseData[]): CourseData[] {
    const merged: CourseData[] = [];
    for (let i = 0; i < courses.length; i++) {
      merged.push(this.isPhysicalExperimentCourse(courses[i]) ?
        this.normalizePhysicalExperiment(courses[i]) : courses[i]);
    }
    for (let i = 0; i < experiments.length; i++) {
      const experiment = this.normalizePhysicalExperiment(experiments[i]);
      let duplicate = false;
      for (let j = 0; j < merged.length; j++) {
        if (this.isPhysicalExperimentCourse(merged[j]) && this.isSamePhysicalExperiment(merged[j], experiment)) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) merged.push(experiment);
    }
    return merged;
  }

  /**
   * 物理实验使用独立缓存，避免普通课表刷新或切换存档时将它们覆盖。
   * 首次读取时会自动迁移旧版本中混存在 currentCourses 里的实验课。
   */
  async getPhysicalExperimentCourses(): Promise<CourseData[]> {
    const saved = await this.getStoredCourses('physicalExperimentCourses');
    const current = await this.getStoredCourses('currentCourses');
    const legacy: CourseData[] = [];
    for (let i = 0; i < current.length; i++) {
      if (this.isPhysicalExperimentCourse(current[i])) legacy.push(current[i]);
    }
    const merged = this.mergePhysicalExperiments(saved, legacy);
    if (merged.length !== saved.length) {
      await this.putStr('physicalExperimentCourses', JSON.stringify(merged));
    }
    return merged;
  }

  async setPhysicalExperimentCourses(value: CourseData[]): Promise<void> {
    const experiments: CourseData[] = [];
    for (let i = 0; i < value.length; i++) {
      if (this.isPhysicalExperimentCourse(value[i])) experiments.push(this.normalizePhysicalExperiment(value[i]));
    }
    await this.putStr('physicalExperimentCourses', JSON.stringify(experiments));
  }

  /**
   * 切换账号时使用：直接清空普通课表与实验课缓存。
   * 不能走 setCurrentCourses([])：它会先把旧 currentCourses 里的实验课迁移到
   * 实验课缓存再合并回来，导致上一个账号的实验课残留。
   */
  async resetCourseCache(): Promise<void> {
    this.courseCacheMarker = `reset_${Date.now()}`;
    await this.putStr('currentCourses', '[]');
    await this.putStr('physicalExperimentCourses', '[]');
  }

  async getCurrentCourses(): Promise<CourseData[]> {
    const current = await this.getStoredCourses('currentCourses');
    const experiments = await this.getPhysicalExperimentCourses();
    const merged = this.mergePhysicalExperiments(current, experiments);
    if (merged.length !== current.length) {
      await this.putStr('currentCourses', JSON.stringify(merged));
    }
    return merged;
  }

  async setCurrentCourses(value: CourseData[], marker?: string): Promise<void> {
    // 记录这次写入的标记，异步任务可以用它判断自己是不是「最后一次写入」。
    this.courseCacheMarker = marker !== undefined ? marker : `courses_${Date.now()}`;
    const savedExperiments = await this.getPhysicalExperimentCourses();
    const incomingExperiments: CourseData[] = [];
    for (let i = 0; i < value.length; i++) {
      if (this.isPhysicalExperimentCourse(value[i])) incomingExperiments.push(value[i]);
    }
    const experiments = this.mergePhysicalExperiments(savedExperiments, incomingExperiments);
    await this.setPhysicalExperimentCourses(experiments);
    const merged = this.mergePhysicalExperiments(value, experiments);
    await this.putStr('currentCourses', JSON.stringify(merged));
  }

  async getCachedGrades(): Promise<string> { return this.getStr('cachedGrades', ''); }
  async setCachedGrades(value: string): Promise<void> { return this.putStr('cachedGrades', value); }

  async getSettingBool(key: string, defaultValue: boolean): Promise<boolean> {
    return this.getBool(key, defaultValue);
  }

  async setSettingBool(key: string, value: boolean): Promise<void> {
    return this.putBool(key, value);
  }

  async getSettingNumber(key: string, defaultValue: number = 0): Promise<number> {
    return this.getNum(key, defaultValue);
  }

  async setSettingNumber(key: string, value: number): Promise<void> {
    return this.putNum(key, value);
  }

  async getSettingString(key: string, defaultValue: string = ''): Promise<string> {
    return this.getStr(key, defaultValue);
  }

  async setSettingString(key: string, value: string): Promise<void> {
    return this.putStr(key, value);
  }
}
