/**
 * UserStore — 用户信息全局状态
 *
 * 文件路径：entry/src/main/ets/store/UserStore.ets
 */
import { UserInfo } from '../model/UserInfoModel';
import { AppStorage } from './AppStorage';

export class UserStore {
  private static instance: UserStore;

  userInfo: UserInfo = { studentId: '', userName: '' };
  loading: boolean = false;
  errorMsg: string = '';

  static getInstance(): UserStore {
    if (!UserStore.instance) {
      UserStore.instance = new UserStore();
    }
    return UserStore.instance;
  }

  /** 从 AppStorage 恢复本地已保存的用户信息 */
  async restoreFromLocal(): Promise<void> {
    const s = AppStorage.getInstance();
    const studentId = await s.getStudentId();
    const userName = await s.getUserName();
    const realName = await s.getRealName();
    this.userInfo = {
      studentId: studentId ?? '',
      userName: userName && userName !== '木有设置' ? userName : (realName ?? ''),
      realName: realName ?? '',
    };
  }
}