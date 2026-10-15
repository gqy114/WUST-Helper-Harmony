import { router, promptAction } from '@kit.ArkUI';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';

@Entry
@Component
struct SettingsPage {
  @State private showCampusCat: boolean = true;
  @State private atNotify: boolean = true;
  @State private replyNotify: boolean = true;
  @State private useCampusProxy: boolean = false;
  @State private cacheSize: string = '55.3 MB';

  aboutToAppear(): void { this.loadSettings(); }

  private async loadSettings(): Promise<void> {
    const storage = PreferencesStorage.getInstance();
    this.showCampusCat = await storage.getSettingBool('showCampusCat', true);
    this.atNotify = await storage.getSettingBool('atNotify', true);
    this.replyNotify = await storage.getSettingBool('replyNotify', true);
    this.useCampusProxy = await storage.getSettingBool('useCampusProxy', false);
  }

  private async saveBool(key: string, value: boolean): Promise<void> {
    await PreferencesStorage.getInstance().setSettingBool(key, value);
  }

  @Builder
  private groupTitle(title: string) {
    Text(title).fontSize(14).fontColor('#999999').width('100%')
      .padding({ left: 16, top: 16, bottom: 8 }).backgroundColor('#F5F5F5')
  }

  @Builder
  private navItem(title: string, action: () => void) {
    Row() {
      Text(title).fontSize(18).fontColor('#333333').layoutWeight(1)
      Text('>').fontSize(18).fontColor('#CCCCCC')
    }
    .width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF').onClick(() => action())
  }

  @Builder
  private switchItem(title: string, value: boolean, action: (value: boolean) => void) {
    Row() {
      Text(title).fontSize(18).fontColor('#333333').layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value }).selectedColor('#82B1FF')
        .onChange((isOn: boolean) => action(isOn))
    }
    .width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')
  }

  private clearCache(): void {
    this.cacheSize = '0 MB';
    promptAction.showToast({ message: '缓存已清理', duration: 1500 });
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(24).fontColor('#333333').onClick(() => router.back())
        Text('设置').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 16 })
      }.width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          this.groupTitle('界面')
          this.navItem('底部导航自定义', () => promptAction.showToast({ message: '开发中', duration: 1500 }))
          this.switchItem('显示校园猫入口', this.showCampusCat, (value: boolean) => { this.showCampusCat = value; this.saveBool('showCampusCat', value); })
          this.navItem('重置小组件', () => promptAction.showToast({ message: '开发中', duration: 1500 }))
          this.groupTitle('校园社区')
          this.switchItem('@我的通知', this.atNotify, (value: boolean) => { this.atNotify = value; this.saveBool('atNotify', value); })
          this.switchItem('回复我的通知', this.replyNotify, (value: boolean) => { this.replyNotify = value; this.saveBool('replyNotify', value); })
          this.groupTitle('课表')
          this.navItem('课表二维码', () => router.pushUrl({ url: 'pages/course/CourseSharePage' }))
          this.navItem('课表档案管理', () => router.pushUrl({ url: 'pages/course/CourseArchivePage' }))
          this.groupTitle('其他')
          Row() {
            Text('清理图片缓存').fontSize(18).fontColor('#333333').layoutWeight(1)
            Text(this.cacheSize).fontSize(16).fontColor('#999999').margin({ right: 8 })
            Text('>').fontSize(18).fontColor('#CCCCCC')
          }.width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF').onClick(() => this.clearCache())
          this.switchItem('使用校园网代理', this.useCampusProxy, (value: boolean) => { this.useCampusProxy = value; this.saveBool('useCampusProxy', value); })
          Text('当设备没有连接到校园网时，自动使用校园网代理访问来解决一些功能的使用问题。')
            .fontSize(14).fontColor('#AAAAAA').width('100%').padding({ left: 16, right: 16, top: 12, bottom: 24 }).backgroundColor('#F5F5F5')
        }.width('100%')
      }.layoutWeight(1).backgroundColor('#F5F5F5')
    }.width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}
