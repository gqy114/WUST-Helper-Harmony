import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { AppStorage } from '../../store/AppStorage';
import { DynamicScheduleApi } from '../../net/DynamicScheduleApi';

@Entry
@Component
struct CourseSharePage {
  @State private nickname: string = '我的';
  @State private avatarUrl: string = '';
  @State private allowExtra: boolean = false;
  @State private isDynamic: boolean = true;
  @State private inviteToken: string = '';
  @State private expiresIn: number = 0;
  @State private qrUrl: string = '';
  private timer?: number;

  aboutToAppear(): void {
    this.loadProfile();
  }

  aboutToDisappear(): void { if (this.timer !== undefined) clearInterval(this.timer); }

  private async createInvite(): Promise<void> {
    try {
      const result = await DynamicScheduleApi.createInvite('2026-2027-1', this.allowExtra);
      this.inviteToken = result.token;
      this.expiresIn = result.expiresIn || 300;
      this.updateDynamicQr();
      if (this.timer !== undefined) clearInterval(this.timer);
      this.timer = setInterval(() => { if (this.expiresIn > 0) this.expiresIn -= 1; }, 1000);
    } catch (err) {
      promptAction.showToast({ message: `${err}`, duration: 1800 });
    }
  }

  private async loadProfile(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.nickname = (await storage.getRealName()) || (await storage.getUserName()) || '我的';
    this.avatarUrl = await storage.getAvatarUrl();
    this.updateStaticQr();
  }

  private updateStaticQr(): void {
    const payload = `wusthelper://schedule?student=${encodeURIComponent(this.nickname)}&semester=2026-2027-1`;
    this.qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=540x540&data=${encodeURIComponent(payload)}`;
  }

  private updateDynamicQr(): void {
    this.qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=540x540&data=${encodeURIComponent(`wusthelper://dynamic-schedule?token=${this.inviteToken}`)}`;
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(44).fontColor('#222222').width(48).textAlign(TextAlign.Center)
          .onClick(() => router.back());
        Text('课表分享').fontSize(27).fontWeight(FontWeight.Bold).fontColor('#222222').margin({ left: 18 });
        Blank().layoutWeight(1);
        Text('授权管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2A8F70');
      }.width('100%').height(88).padding({ left: 14, right: 18 }).backgroundColor(Color.White);

      Scroll() {
        Column() {
          Column() {
            Row() {
              Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(58).height(58)
                .borderRadius(29).objectFit(ImageFit.Cover);
              Column() {
                Text(`${this.nickname}的课表`).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#222222');
                Text('2025-2026 学年 · 第 1 学期').fontSize(18).fontColor('#888888').margin({ top: 8 });
              }.alignItems(HorizontalAlign.Start).margin({ left: 18 });
            }.width('100%').padding({ left: 24, top: 24, bottom: 24 });
            Column() {
              Image(this.qrUrl).width(270).height(270).objectFit(ImageFit.Contain);
              Text('使用武科大助手扫一扫').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#444444').margin({ top: 16 });
              Row() {
                Text(this.isDynamic ? `${Math.floor(this.expiresIn / 60).toString().padStart(2, '0')}:${(this.expiresIn % 60).toString().padStart(2, '0')} 内可扫码` : '使用武科大助手扫码').fontSize(16).fontColor('#999999');
                if (this.isDynamic) { Text('↻ 刷新').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#2A8F70').margin({ left: 20 }).onClick(() => this.createInvite()); }
              }.margin({ top: 12 });
            }.width('100%').padding({ top: 20, bottom: 20 });
            Divider().strokeWidth(1).color('#E5EAE8').margin({ left: 24, right: 24 });
            Row() {
              Column() {
                Text('允许查看额外安排').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333');
                Text('包括你手动添加的课程').fontSize(16).fontColor('#999999').margin({ top: 8 });
              }.alignItems(HorizontalAlign.Start).layoutWeight(1);
              Toggle({ type: ToggleType.Switch, isOn: this.allowExtra }).selectedColor('#2A8F70')
                .onChange((value: boolean) => { this.allowExtra = value; });
            }.width('100%').padding({ left: 24, right: 24, top: 24, bottom: 28 });
          }.width('calc(100% - 32vp)').backgroundColor(Color.White).borderRadius(28);

          Row() {
            Text('⇄').fontSize(28).fontColor('#2A8F70');
            Text(this.isDynamic ? '切换到普通课表' : '切换到动态课表').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2A8F70').margin({ left: 12 });
          }.margin({ top: 26 }).onClick(() => { this.isDynamic = !this.isDynamic; if (this.isDynamic) this.createInvite(); else { this.updateStaticQr(); this.expiresIn = 0; } });
          Text(this.isDynamic ? '动态课表允许他人实时查看你的课表变化。\n需使用安卓版本武科大助手 5.3.0.158 及以上版本。' : '普通课表二维码仅包含当前课表档案，可供武科大助手扫码导入。')
            .fontSize(16).fontColor('#999999').textAlign(TextAlign.Center).lineHeight(28).margin({ top: 28, bottom: 30 });
        }.width('100%').padding({ top: 44, bottom: 24 }).alignItems(HorizontalAlign.Center);
      }.layoutWeight(1).backgroundColor('#F7F8F7');

      Row() {
        Button('保存图片').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2A8F70')
          .backgroundColor('#EEF8F4').layoutWeight(1).height(60).borderRadius(20);
        Button('分享二维码').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor('#20C894').layoutWeight(1.35).height(60).borderRadius(20).margin({ left: 16 });
      }.width('100%').padding({ left: 24, right: 24, top: 16, bottom: 18 }).backgroundColor(Color.White);
    }.width('100%').height('100%').backgroundColor('#F7F8F7');
  }
}
