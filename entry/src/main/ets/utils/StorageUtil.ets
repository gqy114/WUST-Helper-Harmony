/**
 * StorageUtil - 登录状态持久化。
 *
 * 使用 UserPreferences 保存 token、用户名和用户 ID，
 * 供启动时判断是否已登录，以及退出登录时清除。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'wust_helper_user_info';
const KEY_TOKEN = 'token';
const KEY_USERNAME = 'username';
const KEY_USER_ID = 'user_id';

export class StorageUtil {
  private static preferences: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (StorageUtil.preferences === null) {
      StorageUtil.preferences = await preferences.getPreferences(context, STORE_NAME);
    }
  }

  static async saveLoginInfo(token: string, username: string, userId: string): Promise<void> {
    if (StorageUtil.preferences === null) {
      return;
    }
    await StorageUtil.preferences.put(KEY_TOKEN, token);
    await StorageUtil.preferences.put(KEY_USERNAME, username);
    await StorageUtil.preferences.put(KEY_USER_ID, userId);
    await StorageUtil.preferences.flush();
    console.info('StorageUtil', 'saveLoginInfo success');
  }

  static getToken(): string {
    if (StorageUtil.preferences === null) {
      return '';
    }
    return StorageUtil.preferences.getSync(KEY_TOKEN, '') as string;
  }

  static getUsername(): string {
    if (StorageUtil.preferences === null) {
      return '';
    }
    return StorageUtil.preferences.getSync(KEY_USERNAME, '') as string;
  }

  static async clearLoginInfo(): Promise<void> {
    if (StorageUtil.preferences === null) {
      return;
    }
    await StorageUtil.preferences.delete(KEY_TOKEN);
    await StorageUtil.preferences.delete(KEY_USERNAME);
    await StorageUtil.preferences.delete(KEY_USER_ID);
    await StorageUtil.preferences.flush();
    console.info('StorageUtil', 'clearLoginInfo success');
  }

  static isLoggedIn(): boolean {
    const token = StorageUtil.getToken();
    return token !== null && token !== undefined && token !== '';
  }
}
