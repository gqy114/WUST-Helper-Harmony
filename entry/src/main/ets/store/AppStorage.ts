/**
 * 对应原 Android 端 SharePreferenceLab + SPTool
 * 统一封装 preferences，单 store 存储
 *
 * 文件路径：entry/src/main/ets/store/AppStorage.ts
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

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

  async init(context: common.UIAbilityContext): Promise<void> {
    this.kvStore = await preferences.getPreferences(context, STORE_NAME);
  }

  // ── 低层读写 ──

  private async getStr(key: string, def: string = ''): Promise<string> {
    const raw = await this.kvStore?.get(key, JSON.stringify(def));
    return raw !== undefined ? JSON.parse(raw as string) : def;
  }

  private async putStr(key: string, value: string): Promise<void> {
    await this.kvStore?.put(key, JSON.stringify(value));
    await this.kvStore?.flush();
  }

  private async getBool(key: string, def: boolean = false): Promise<boolean> {
    const raw = await this.kvStore?.get(key, JSON.stringify(def));
    return raw !== undefined ? JSON.parse(raw as string) : def;
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

  // ── 隐私协议确认 ──

  async getIsConfirmPolicy(): Promise<boolean> { return this.getBool('isConfirmPolicy'); }
  async setIsConfirmPolicy(v: boolean): Promise<void> { return this.putBool('isConfirmPolicy', v); }

  // ── Mock 模拟开关 ──

  async getUseMock(): Promise<boolean> { return this.getBool('useMock', true); }
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

  // ── 登录与 Token ──

  async getIsLogin(): Promise<boolean> { return this.getBool('isLogin'); }
  async setIsLogin(v: boolean): Promise<void> { return this.putBool('isLogin', v); }
  async getToken(): Promise<string> { return this.getStr('token'); }
  async setToken(v: string): Promise<void> { return this.putStr('token', v); }
  async getStudentId(): Promise<string> { return this.getStr('studentId'); }
  async setStudentId(v: string): Promise<void> { return this.putStr('studentId', v); }
  async getPassword(): Promise<string> { return this.getStr('password'); }
  async setPassword(v: string): Promise<void> { return this.putStr('password', v); }
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
}
