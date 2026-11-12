import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { AppStorage as PreferenceStorage } from '../../store/AppStorage';
import { UserStore } from '../../store/UserStore';
import { UserApi } from '../../net/UserApi';
import { ApiService } from '../../net/ApiService';

interface EditNameParams {
  name?: string;
}

/** 发起改名时的会话快照：切号后旧操作必须作废。 */
interface NicknameSession {
  sid: string;
  epoch: number;
  token: string;
}

AppStorage.setOrCreate<number>('profileVersion', 0);

@Entry
@Component
struct EditNamePage {
  @StorageLink('profileVersion') private profileVersion: number = 0;
  @State private nickname: string = '';
  @State private saving: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as EditNameParams;
    this.loadName(params?.name || '');
  }

  private async loadName(paramName: string): Promise<void> {
    const storage = PreferenceStorage.getInstance();
    this.nickname = paramName || (await storage.getUserName()) || (await storage.getRealName()) || '';
  }

  private async saveName(): Promise<void> {
    const value = this.nickname.trim();
    if (!value) {
      promptAction.showToast({ message: '昵称不能为空', duration: 1500 });
      return;
    }
    if (value.length > 20) {
      promptAction.showToast({ message: '昵称不能超过20个字符', duration: 1500 });
      return;
    }
    if (this.saving) return;
    this.saving = true;
    const storage = PreferenceStorage.getInstance();
    // 先同步取代次，再异步读学号和令牌；读取期间切号就放弃，避免把旧账号输入发给新账号。
    const sessionEpoch = storage.getSessionEpoch();
    const sessionSid = (await storage.getStudentId()).trim();
    const sessionToken = (await storage.getAppAuthAccessToken()).trim();
    if (storage.getSessionEpoch() !== sessionEpoch ||
      (await storage.getStudentId()).trim() !== sessionSid) {
      console.warn('EditNamePage', 'account changed while reading session, nickname save cancelled');
      promptAction.showToast({ message: '账号已切换，本次改名已取消', duration: 2000 });
      this.saving = false;
      return;
    }
    const session: NicknameSession = {
      sid: sessionSid,
      epoch: sessionEpoch,
      token: sessionToken,
    };
    // 同步只是“尽力而为”：令牌恢复或网络失败都不能阻止本地改名。
    const synced = await this.syncDisplayName(storage, value, session);
    if (await this.isAccountChanged(storage, session)) {
      // 切号后不把旧账号输入的昵称写进新账号。
      console.warn('EditNamePage', 'account changed during nickname save, result discarded');
      promptAction.showToast({ message: '账号已切换，本次改名已取消', duration: 2000 });
      this.saving = false;
      return;
    }
    try {
      // 最终写入也走会话队列：切号期间的旧写入会被丢弃，不会覆盖新账号昵称。
      if (!(await storage.setUserNameForAccount(session.epoch, session.sid, value))) {
        promptAction.showToast({ message: '账号已切换，本次改名已取消', duration: 2000 });
        this.saving = false;
        return;
      }
      if (await this.isAccountChanged(storage, session)) {
        // 写入期间切号：写入已按队列落盘到旧账号，不再向新账号提示成功。
        promptAction.showToast({ message: '账号已切换，本次改名已取消', duration: 2000 });
        this.saving = false;
        return;
      }
      await UserStore.getInstance().restoreFromLocal();
      this.profileVersion = Date.now();
      promptAction.showToast({
        message: synced ? '昵称已修改，社区同步生效' : '已保存到本机，服务器同步失败',
        duration: synced ? 1200 : 2000
      });
      router.back();
    } catch (error) {
      console.error('EditNamePage', `save nickname failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '本地保存失败，请重试', duration: 1500 });
    } finally {
      this.saving = false;
    }
  }

  /** 账号或会话代次是否已变化（切号后旧操作必须作废）。 */
  private async isAccountChanged(storage: PreferenceStorage, session: NicknameSession): Promise<boolean> {
    if (storage.getSessionEpoch() !== session.epoch) return true;
    return (await storage.getStudentId()).trim() !== session.sid;
  }

  /**
   * 尝试把昵称同步到服务端，返回是否确认成功。
   * 令牌恢复或网络失败都不能阻止本地改名。
   * 会话快照固定账号；中途切号直接放弃，不拿新账号令牌发旧昵称。
   */
  private async syncDisplayName(storage: PreferenceStorage, value: string,
    session: NicknameSession): Promise<boolean> {
    let token = session.token;
    if (!token) {
      try {
        if (await this.isAccountChanged(storage, session)) return false;
        await ApiService.loginAppAuthFromSavedCredentials(storage);
        if (await this.isAccountChanged(storage, session)) return false;
        // 读取令牌期间切号会拿到新账号的令牌，必须放弃本次发送。
        token = await storage.getAppAuthAccessTokenForSession(session.epoch, session.sid);
        if (await this.isAccountChanged(storage, session)) return false;
      } catch (error) {
        console.warn('EditNamePage', `restore app auth failed: ${JSON.stringify(error)}`);
      }
    }
    if (!token) return false;
    try {
      if (await UserApi.updateAppDisplayName(value, token)) {
        return !(await this.isAccountChanged(storage, session));
      }
    } catch (error) {
      console.warn('EditNamePage', `sync nickname failed: ${JSON.stringify(error)}`);
    }
    if (await this.isAccountChanged(storage, session)) return false;
    // 令牌可能已失效：恢复一次后重试，仍失败就明确提示未同步。
    try {
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      if (await this.isAccountChanged(storage, session)) return false;
      token = await storage.getAppAuthAccessTokenForSession(session.epoch, session.sid);
      if (await this.isAccountChanged(storage, session)) return false;
      if (token) {
        const synced = await UserApi.updateAppDisplayName(value, token);
        return synced && !(await this.isAccountChanged(storage, session));
      }
    } catch (error) {
      console.warn('EditNamePage', `retry sync nickname failed: ${JSON.stringify(error)}`);
    }
    return false;
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(44).fontColor('#333333').width(48).textAlign(TextAlign.Center)
          .onClick(() => router.back());
        Text('修改名字').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#222222')
          .margin({ left: 22 });
      }
      .width('100%').height(88).padding({ left: 16, right: 20 });

      Column() {
        TextInput({ text: this.nickname, placeholder: '请输入昵称' })
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222')
          .placeholderColor('#BBBBBB').backgroundColor(Color.Transparent)
          .height(58).padding({ left: 0, right: 0 }).maxLength(20)
          .onChange((value: string) => { this.nickname = value; });
        Divider().strokeWidth(1).color('#777777');
        Text('修改你的名字，便于分享时让别人知道你是谁')
          .fontSize(15).fontColor('#AAAAAA').width('100%').margin({ top: 18 });

        Button(this.saving ? '保存中…' : '确认修改')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#222222')
          .backgroundColor('#F7F7F7').borderRadius(10).height(58).width(140)
          .margin({ top: 72 }).enabled(!this.saving)
          .onClick(() => this.saveName());
      }
      .width('100%').padding({ left: 32, right: 32 }).alignItems(HorizontalAlign.Center);

      Blank().layoutWeight(1);
    }
    .width('100%').height('100%').backgroundColor(Color.White);
  }
}
