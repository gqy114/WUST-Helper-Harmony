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
    await this.claimLegacyProfileForAccount(await this.getStudentId());
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

  // ── 账号资料的分账号存储 + 串行提交 ──
  //
  // 头像/昵称按学号分 key 保存：切号期间旧账号的写入只会落到旧账号自己的数据上，
  // 不会覆盖新账号；当前账号读取时只读自己的 key，旧全局数据只迁移给升级后首个账号。
  // 写入同时串成一条链（commitProfileWrite），执行前校验 sessionEpoch，
  // 切号后尚未执行的旧写入直接丢弃。

  /** 在启动/切号时为旧全局资料确定唯一归属；只复制，不覆盖已有的分账号资料。 */
  private async claimLegacyProfileForAccount(owner: string): Promise<void> {
    const sid = (owner || '').trim();
    if (!sid) return;
    // 和资料写入共享队列，避免迁移在读取空值后覆盖同时保存的新头像或昵称。
    const run = this.profileWriteChain.then(async (): Promise<void> => {
      const keys: string[] = ['avatarUrl', 'userName'];
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const migratedKey = `profileScopedMigrated_${key}`;
        if (await this.getBool(migratedKey)) continue;
        const scopedKey = `${key}_${sid}`;
        const existing = await this.getStr(scopedKey, '');
        if (!existing) {
          const legacy = await this.getStr(key, '');
          if (legacy) await this.putStr(scopedKey, legacy);
        }
        // 即使当前账号已有新资料，也要完成认领标记，防止其他账号再继承旧数据。
        await this.putBool(migratedKey, true);
      }
    });
    this.profileWriteChain = run.then((): void => {}, (): void => {});
    await run;
  }

  private async getProfileValue(key: string): Promise<string> {
    const epoch = this.sessionEpoch;
    const sid = (await this.getStudentId()).trim();
    if (this.sessionEpoch !== epoch) return '';
    if (!sid) {
      const legacy = await this.getStr(key, '');
      return this.sessionEpoch === epoch ? legacy : '';
    }
    await this.claimLegacyProfileForAccount(sid);
    if (this.sessionEpoch !== epoch) return '';
    const value = await this.getStr(`${key}_${sid}`, '');
    return this.sessionEpoch === epoch ? value : '';
  }

  private async setProfileValue(key: string, value: string): Promise<void> {
    const epoch = this.sessionEpoch;
    const sid = (await this.getStudentId()).trim();
    const scopedKey = sid ? `${key}_${sid}` : key;
    // 固定读取到的账号，排队后再核对会话，不能在切号后重新计算成新账号。
    await this.commitProfileWrite(epoch, () => this.putStr(scopedKey, value));
  }

  private commitProfileWrite(epoch: number, writer: () => Promise<void>): Promise<boolean> {
    const run = this.profileWriteChain.then(async (): Promise<boolean> => {
      if (this.sessionEpoch !== epoch) return false;
      await writer();
      return true;
    });
    this.profileWriteChain = run.then((): void => {}, (): void => {});
    return run;
  }

  /** 仅当会话代次未变时才写入指定账号的头像；返回是否真的写入。 */
  async setAvatarUrlForAccount(epoch: number, sid: string, value: string): Promise<boolean> {
    const account = (sid || '').trim();
    if (!account) return false;
    return this.commitProfileWrite(epoch, () => this.putStr(`avatarUrl_${account}`, value));
  }

  /** 仅当会话代次未变时才写入指定账号的昵称；返回是否真的写入。 */
  async setUserNameForAccount(epoch: number, sid: string, value: string): Promise<boolean> {
    const account = (sid || '').trim();
    if (!account) return false;
    return this.commitProfileWrite(epoch, () => this.putStr(`userName_${account}`, value));
  }

  /**
   * 仅当会话（代次 + 学号）未变时才写入整套应用认证令牌；返回是否写入。
   *
   * 认证恢复请求可能持续数秒，期间用户切号：旧请求返回后不能把旧账号的令牌
   * 写给新账号。写入走同一条串行链，且 setStudentId 会先等待链上的写入完成，
   * 因此“校验通过后开始写”的旧写入一定在新学号落盘之前结束。
   */
  async setAppAuthTokensIfSession(epoch: number, sid: string,
    accessToken: string, refreshToken: string,
    expiresAt: number, refreshExpiresAt: number): Promise<boolean> {
    const account = (sid || '').trim();
    if (!account) return false;
    return this.commitSessionWrite(epoch, account, async (): Promise<void> => {
      await this.putStr('appAuthAccessToken', accessToken);
      await this.putStr('appAuthRefreshToken', refreshToken);
      await this.putNum('appAuthExpiresAt', expiresAt);
      await this.putNum('appAuthRefreshExpiresAt', refreshExpiresAt);
    });
  }

  private commitSessionWrite(epoch: number, sid: string, writer: () => Promise<void>): Promise<boolean> {
    const account = (sid || '').trim();
    if (!account) return Promise.resolve(false);
    const run = this.profileWriteChain.then(async (): Promise<boolean> => {
      if (this.accountChangesPending > 0 || this.sessionEpoch !== epoch) return false;
      if ((await this.getStudentId()).trim() !== account) return false;
      if (this.accountChangesPending > 0 || this.sessionEpoch !== epoch) return false;
      await writer();
      return true;
    });
    this.profileWriteChain = run.then((): void => {}, (): void => {});
    return run;
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

  /**
   * 账号/学期版本号：切换账号或学期时自增。
   * 异步任务（如启动页预取）用它判断自己的结果是否已经过期，
   * 避免把旧账号/旧学期的数据写进当前缓存。
   */
  private sessionEpoch: number = 0;
  // 账号资料写入的串行链：见 commitProfileWrite。
  private profileWriteChain: Promise<void> = Promise.resolve();
  private accountWriteChain: Promise<void> = Promise.resolve();
  // 从发起切号到学号落盘期间，不允许认证恢复把旧账号令牌重新写入。
  private accountChangesPending: number = 0;
  private authIdentityVersion: number = 0;
  private authIdentityAppliedVersion: number = 0;

  /** 最近一次课表缓存的写入标记：异步写入者用它判断自己是否仍是最后一次写入。 */
  private courseCacheMarker: string = '';

  getSessionEpoch(): number { return this.sessionEpoch; }

  getCourseCacheMarker(): string { return this.courseCacheMarker; }

  private bumpSessionEpoch(): void { this.sessionEpoch = this.sessionEpoch + 1; }

  // ── 学期 ──

  async getSemester(): Promise<string> { return this.getStr('semester'); }
  async setSemester(v: string): Promise<void> {
    this.bumpSessionEpoch();
    return this.putStr('semester', v);
  }
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
    this.accountChangesPending++;
    this.bumpSessionEpoch();
    const changeAccount = async (): Promise<void> => {
      // 等正在提交的资料/令牌写入完成：它们属于旧账号，必须在新学号落盘前写完，
      // 否则旧请求的结果可能被写到新账号下。
      await this.profileWriteChain;
      const previousSid = (await this.getStudentId()).trim();
      const identityVersion = this.authIdentityVersion;
      // 资料刷新会重复保存相同学号；只有身份确实改变时才清除令牌。
      if (previousSid !== (v || '').trim() || identityVersion !== this.authIdentityAppliedVersion) {
        await this.putStr('appAuthAccessToken', '');
        await this.putStr('appAuthRefreshToken', '');
      }
      // 先由旧账号认领旧全局资料；不能等切号后才由新账号第一次读取触发迁移。
      await this.claimLegacyProfileForAccount(await this.getStudentId());
      await this.putStr('studentId', v);
      // 登录后立即认领旧档案。
      await this.claimLegacyArchives();
      await this.claimLegacyProfileForAccount(v);
      this.authIdentityAppliedVersion = identityVersion;
    };
    const run = this.accountWriteChain.then(changeAccount, changeAccount);
    this.accountWriteChain = run.then((): void => {}, (): void => {});
    try {
      await run;
    } finally {
      this.accountChangesPending--;
    }
  }
  async getPassword(): Promise<string> { return this.getStr('password'); }
  async setPassword(v: string): Promise<void> { return this.putStr('password', v); }
  async getPhysicalExperimentPassword(): Promise<string> { return this.getStr('physicalExperimentPassword'); }
  async setPhysicalExperimentPassword(v: string): Promise<void> { return this.putStr('physicalExperimentPassword', v); }
  async getMessage(): Promise<string> { return this.getStr('login_msg'); }
  async setMessage(v: string): Promise<void> { return this.putStr('login_msg', v); }
  async getIsGraduate(): Promise<boolean> { return this.getBool('isGraduate'); }
  async setIsGraduate(v: boolean): Promise<void> {
    // 身份变化也属于“账号状态切换”：先让正在提交的令牌/资料写入完成，
    // 再清掉旧身份令牌，避免切换期间旧令牌仍可被使用。
    // 注意不要排到 accountWriteChain 上，否则会与正在等待的切号互相等待。
    this.accountChangesPending++;
    this.bumpSessionEpoch();
    try {
      await this.profileWriteChain;
      const previous = await this.getIsGraduate();
      if (previous !== v) {
        this.authIdentityVersion++;
        await this.putStr('appAuthAccessToken', '');
        await this.putStr('appAuthRefreshToken', '');
      }
      await this.putBool('isGraduate', v);
      this.authIdentityAppliedVersion = this.authIdentityVersion;
    } finally {
      this.accountChangesPending--;
    }
  }
  async getTokenUpdateTime(): Promise<number> { return this.getNum('token_update_time'); }
  async setTokenUpdateTime(v: number): Promise<void> { return this.putNum('token_update_time', v); }
  async getTokenLastUseTime(): Promise<number> { return this.getNum('token_last_use_time'); }
  async setTokenLastUseTime(v: number): Promise<void> { return this.putNum('token_last_use_time', v); }

  // ── 用户信息 ──

  async getRealName(): Promise<string> { return this.getStr('realName'); }
  async setRealName(v: string): Promise<void> { return this.putStr('realName', v); }
  async getUserName(): Promise<string> { return this.getProfileValue('userName'); }
  async setUserName(v: string): Promise<void> { await this.setProfileValue('userName', v); }
  async getCollege(): Promise<string> { return this.getStr('college'); }
  async setCollege(v: string): Promise<void> { return this.putStr('college', v); }
  async getMajor(): Promise<string> { return this.getStr('major'); }
  async setMajor(v: string): Promise<void> { return this.putStr('major', v); }
  async getAvatarUrl(): Promise<string> { return this.getProfileValue('avatarUrl'); }
  async setAvatarUrl(v: string): Promise<void> { await this.setProfileValue('avatarUrl', v); }
  async getClasses(): Promise<string> { return this.getStr('classes'); }
  async setClasses(v: string): Promise<void> { return this.putStr('classes', v); }

  // ── App Auth ──

  async getAppAuthAccessToken(): Promise<string> { return this.getStr('appAuthAccessToken'); }

  /**
   * 读取应用认证令牌，同时确认会话（代次 + 学号）未变。
   * 读取期间切号会返回空串，调用方不能拿新账号的令牌发送旧账号的数据。
   */
  async getAppAuthAccessTokenForSession(epoch: number, sid: string): Promise<string> {
    const account = (sid || '').trim();
    if (!account) return '';
    if (this.sessionEpoch !== epoch || this.accountChangesPending > 0) return '';
    if ((await this.getStudentId()).trim() !== account) return '';
    const token = await this.getStr('appAuthAccessToken');
    if (this.sessionEpoch !== epoch || this.accountChangesPending > 0) return '';
    return token;
  }
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
   *
   * 读取可能触发迁移写入，因此必须和移除操作共用同一个写入队列：
   * 否则「移除实验课」清空缓存后，并发读取会把旧课表里的实验课迁移回来。
   */
  async getPhysicalExperimentCourses(): Promise<CourseData[]> {
    return this.enqueueCourseWrite(() => this.readPhysicalExperimentCoursesUnlocked());
  }

  /**
   * 已持有写入队列时使用的读取实现。
   * 队列内部不能再调用会再次入队的公开方法，否则会等待自身造成死锁。
   */
  private async readPhysicalExperimentCoursesUnlocked(): Promise<CourseData[]> {
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
    return this.enqueueCourseWrite(() => this.writePhysicalExperimentCoursesUnlocked(value));
  }

  private async writePhysicalExperimentCoursesUnlocked(value: CourseData[]): Promise<void> {
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
    return this.enqueueCourseWrite(async () => {
      this.courseCacheMarker = `reset_${Date.now()}`;
      await this.putStr('currentCourses', '[]');
      await this.putStr('physicalExperimentCourses', '[]');
    });
  }

  /**
   * 条件清空：只有缓存仍然是 marker 那次写入时才清空。
   * 判断和清空必须在同一个写入队列任务里完成，否则旧任务的清空会排在
   * 新课表写入之后执行，把新学期的课表清掉。
   */
  async resetCourseCacheIfMarker(marker: string): Promise<boolean> {
    return this.enqueueCourseWrite(async () => {
      if (this.courseCacheMarker !== marker) {
        return false;
      }
      this.courseCacheMarker = `reset_${Date.now()}`;
      await this.putStr('currentCourses', '[]');
      await this.putStr('physicalExperimentCourses', '[]');
      return true;
    });
  }

  /**
   * 读取课表。迁移/回写实验课的步骤同样在写入队列里执行，
   * 避免和「移除实验课」交错把已移除的课程又写回来。
   */
  async getCurrentCourses(): Promise<CourseData[]> {
    return this.enqueueCourseWrite(() => this.readCurrentCoursesUnlocked());
  }

  private async readCurrentCoursesUnlocked(): Promise<CourseData[]> {
    const current = await this.getStoredCourses('currentCourses');
    const experiments = await this.readPhysicalExperimentCoursesUnlocked();
    const merged = this.mergePhysicalExperiments(current, experiments);
    if (merged.length !== current.length) {
      await this.putStr('currentCourses', JSON.stringify(merged));
    }
    return merged;
  }

  /**
   * 课表缓存写入串行化：两次异步写入不能交错，
   * 否则 A 的写入可能在 B 保存完成后才落盘，把 B 的数据覆盖掉。
   */
  private courseWriteChain: Promise<void> = Promise.resolve();

  private enqueueCourseWrite<T>(task: () => Promise<T>): Promise<T> {
    const run = this.courseWriteChain.then(task, task);
    this.courseWriteChain = run.then(() => {}, () => {});
    return run;
  }

  async setCurrentCourses(value: CourseData[], marker?: string): Promise<void> {
    // 写入是异步的：期间若切换账号/学期，就放弃这次写入，
    // 避免旧请求的结果覆盖新账号刚保存的课表。
    const epochAtStart = this.sessionEpoch;
    return this.enqueueCourseWrite(async () => {
      if (this.sessionEpoch !== epochAtStart) return;
      const savedExperiments = await this.readPhysicalExperimentCoursesUnlocked();
      const incomingExperiments: CourseData[] = [];
      for (let i = 0; i < value.length; i++) {
        if (this.isPhysicalExperimentCourse(value[i])) incomingExperiments.push(value[i]);
      }
      const experiments = this.mergePhysicalExperiments(savedExperiments, incomingExperiments);
      if (this.sessionEpoch !== epochAtStart) return;
      await this.writePhysicalExperimentCoursesUnlocked(experiments);
      if (this.sessionEpoch !== epochAtStart) return;
      const merged = this.mergePhysicalExperiments(value, experiments);
      // 记录这次写入的标记，异步任务可以用它判断自己是不是「最后一次写入」。
      this.courseCacheMarker = marker !== undefined ? marker : `courses_${Date.now()}`;
      await this.putStr('currentCourses', JSON.stringify(merged));
    });
  }

  /**
   * 一键移除课表里的实验课程。
   *
   * 必须在一个写任务里同时清空实验缓存并重写普通课表：之前分两步做，
   * 第二步 setCurrentCourses() 会调用 getPhysicalExperimentCourses()，
   * 把刚清掉的实验课又从 currentCourses 里迁移回实验缓存并合并回课表。
   */
  async removePhysicalExperimentCourses(): Promise<number> {
    return this.enqueueCourseWrite(async () => {
      const current = await this.getStoredCourses('currentCourses');
      const remaining: CourseData[] = [];
      let removed = 0;
      for (let i = 0; i < current.length; i++) {
        if (this.isPhysicalExperimentCourse(current[i])) {
          removed++;
          continue;
        }
        remaining.push(current[i]);
      }
      if (removed === 0) return 0;
      this.courseCacheMarker = `remove_experiments_${Date.now()}`;
      await this.putStr('physicalExperimentCourses', '[]');
      await this.putStr('currentCourses', JSON.stringify(remaining));
      return removed;
    });
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
