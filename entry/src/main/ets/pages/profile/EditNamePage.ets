import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { AppStorage as PreferenceStorage } from '../../store/AppStorage';
import { UserStore } from '../../store/UserStore';
import { UserApi } from '../../net/UserApi';
import { ApiService } from '../../net/ApiService';

interface EditNameParams {
  name?: string;
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
    let synced = false;
    try {
      // 先用应用令牌把昵称写到服务端，社区/其他设备读的是服务端资料。
      let token = (await storage.getAppAuthAccessToken()).trim();
      if (!token) {
        await ApiService.loginAppAuthFromSavedCredentials(storage);
        token = (await storage.getAppAuthAccessToken()).trim();
      }
      if (token) {
        try {
          synced = await UserApi.updateAppDisplayName(value);
        } catch (error) {
          console.warn('EditNamePage', `sync nickname failed: ${JSON.stringify(error)}`);
          synced = false;
        }
      }
      await storage.setUserName(value);
      await UserStore.getInstance().restoreFromLocal();
      this.profileVersion = Date.now();
      promptAction.showToast({
        message: synced ? '昵称已修改，社区同步生效' : '已保存到本机，服务器同步失败',
        duration: synced ? 1200 : 2000
      });
      router.back();
    } catch (error) {
      console.error('EditNamePage', `save nickname failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '保存失败，请重试', duration: 1500 });
    } finally {
      this.saving = false;
    }
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
