import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { WaterDispenserApi } from '../../net/WaterDispenserApi';

@Entry @Component
struct WaterDispenserPage {
  @State private deviceId: string = '';
  @State private account: string = '';
  @State private balance: string = '¥0.00';
  @State private running: boolean = false;
  @State private loading: boolean = false;
  @State private loggedIn: boolean = false;
  @State private phone: string = '';
  @State private captcha: string = '';
  @State private smsCode: string = '';
  @State private captchaSeed: string = '0.5';
  private async loadWallet(): Promise<void> { try { await WaterDispenserApi.wallet(); this.balance = '¥0.00'; } catch {} }
  private async selectDevice(): Promise<void> { if (!this.deviceId.trim()) { promptAction.showToast({ message: '请先输入二维码ID', duration: 1500 }); return; } this.loading = true; try { await WaterDispenserApi.useQr(this.deviceId.trim()); await WaterDispenserApi.home(this.deviceId.trim()); promptAction.showToast({ message: '饮水机选择成功', duration: 1200 }); } catch { promptAction.showToast({ message: '设备信息获取失败', duration: 1500 }); } this.loading = false; }
  private async start(): Promise<void> { if (!this.deviceId) return; try { await WaterDispenserApi.start(this.deviceId); this.running = true; promptAction.showToast({ message: '已开始出水', duration: 1200 }); } catch { promptAction.showToast({ message: '启动失败', duration: 1500 }); } }
  private async stop(): Promise<void> { if (!this.deviceId) return; try { await WaterDispenserApi.end(this.deviceId); this.running = false; promptAction.showToast({ message: '已结束使用并结算', duration: 1200 }); } catch { promptAction.showToast({ message: '结束失败', duration: 1500 }); } }
  aboutToAppear(): void { this.loadWallet(); }
  private async sendCode(): Promise<void> { try { await WaterDispenserApi.sendCode(this.phone, this.captcha, this.captchaSeed); promptAction.showToast({ message: '验证码已发送', duration: 1200 }); } catch { promptAction.showToast({ message: '验证码发送失败', duration: 1500 }); } }
  private async login(): Promise<void> { try { const response: string = await WaterDispenserApi.login(this.phone, this.smsCode); const match: RegExpMatchArray | null = response.match(/\"token\"\s*:\s*\"([^\"]+)/); if (match && match[1]) { await (await import('../../store/AppStorage')).AppStorage.getInstance().setAppAuthAccessToken(match[1]); } this.loggedIn = true; this.loadWallet(); promptAction.showToast({ message: '登录成功', duration: 1200 }); } catch { promptAction.showToast({ message: '登录失败，请检查验证码', duration: 1500 }); } }
  build() {
    Column() {
      Row() { Text('‹').fontSize(44).fontColor(Color.White).onClick(() => router.back()); Text('饮水机').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 18 }); }.width('100%').height(96).padding({ left: 24 }).backgroundColor('#20C894');
      if (!this.loggedIn) { Scroll() { Column() { Text('登录饮水账户').fontSize(28).fontWeight(FontWeight.Bold).width('100%'); Text('饮水账户由慧生活798提供，与武科大助手账号相互独立。').fontSize(17).fontColor('#888888').width('100%').margin({ top: 14, bottom: 26 }); TextInput({ placeholder: '手机号', text: this.phone }).width('100%').height(58).onChange((v: string) => { this.phone = v; }); Row() { TextInput({ placeholder: '图形验证码', text: this.captcha }).layoutWeight(1).height(58).onChange((v: string) => { this.captcha = v; }); Image(`https://i.ilife798.com/api/v1/captcha/?s=${this.captchaSeed}&r=0`).width(120).height(48).margin({ left: 12 }); }.width('100%').margin({ top: 14 }); Row() { TextInput({ placeholder: '短信验证码', text: this.smsCode }).layoutWeight(1).height(58).onChange((v: string) => { this.smsCode = v; }); Button('获取验证码').height(52).fontColor('#20C894').backgroundColor(Color.White).border({ width: 1, color: '#20C894' }).margin({ left: 12 }).onClick(() => this.sendCode()); }.width('100%').margin({ top: 14 }); Button('登录').width('100%').height(60).fontSize(22).fontColor(Color.White).backgroundColor('#20C894').margin({ top: 22 }).onClick(() => this.login()); }.width('92%').padding(28).backgroundColor(Color.White).borderRadius(20).margin({ top: 30 }); }.layoutWeight(1); } else {      Scroll() { Column() {
        Column() { Row() { Image($r('app.media.ic_default_avatar')).width(72).height(72).borderRadius(36); Column() { Text(this.account || '慧生活账户').fontSize(24).fontWeight(FontWeight.Bold); Text('账号信息').fontSize(16).fontColor('#888888').margin({ top: 8 }); }.margin({ left: 18 }); }.width('100%'); Divider().margin({ top: 22, bottom: 18 }); Text('账户余额').fontSize(20).fontWeight(FontWeight.Bold).width('100%'); Text(this.balance).fontSize(40).fontWeight(FontWeight.Bold).fontColor('#20C894').width('100%').margin({ top: 12 }); }.width('92%').padding(24).backgroundColor(Color.White).borderRadius(20).margin({ top: 24 });
        Column() { Row() { Image($r('app.media.water_dispenser')).width(58).height(58); Column() { Text(this.deviceId ? '已选择饮水机' : '尚未选择饮水机').fontSize(24).fontWeight(FontWeight.Bold); Text(this.deviceId ? `设备 ${this.deviceId}` : '请输入或扫描机器二维码').fontSize(17).fontColor('#888888').margin({ top: 8 }); }.margin({ left: 18 }); }.width('100%'); TextInput({ placeholder: '输入二维码ID', text: this.deviceId }).width('100%').margin({ top: 18 }).onChange((v: string) => { this.deviceId = v; }); Button('扫码选择饮水机').width('100%').height(58).fontSize(20).fontColor(Color.White).backgroundColor('#20C894').margin({ top: 16 }).onClick(() => this.selectDevice()); }.width('92%').padding(24).backgroundColor(Color.White).borderRadius(20).margin({ top: 18 });
        Column() { Text('设备控制').fontSize(24).fontWeight(FontWeight.Bold).width('100%'); Text('将使用慧生活账户内余额进行扣费').fontSize(17).fontColor('#888888').width('100%').margin({ top: 10, bottom: 20 }); Button('使用账户余额启动').width('100%').height(58).fontSize(20).fontColor(Color.White).backgroundColor(this.deviceId && !this.running ? '#20C894' : '#D5D5D5').enabled(!!this.deviceId && !this.running).onClick(() => this.start()); Button('结束使用并结算').width('100%').height(58).fontSize(20).fontColor('#20C894').backgroundColor(Color.White).border({ width: 1, color: '#20C894' }).margin({ top: 14 }).enabled(!!this.deviceId && this.running).onClick(() => this.stop()); }.width('92%').padding(24).backgroundColor(Color.White).borderRadius(20).margin({ top: 18, bottom: 30 });
      }.width('100%'); }.layoutWeight(1); }
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
