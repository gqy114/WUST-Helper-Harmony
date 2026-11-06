/**
 * 双创学分页面。
 *
 * 学校双创学分系统在 aTrust 网关后面，需要使用统一身份认证的 CAS 票据。
 * 流程：App 后端用保存的学号密码换取 ticket → 把 ticket 拼到 aTrust 的 CAS 服务地址上，
 * 由 Web 组件打开，网关校验票据后会自动跳转到双创学分系统。
 *
 * 之前首页入口直接指向 pages/common/WebPage 且 url 为空，必然显示“页面加载失败”。
 */
import { promptAction, router } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { common, Want } from '@kit.AbilityKit';
import { AppStorage } from '../../store/AppStorage';
import { InnovationCreditApi, InnovationCreditTicket } from '../../net/InnovationCreditApi';

const TAG = 'InnovationCreditPage';
/** aTrust 网关的 CAS 服务地址，与后端 innovation_credit.go 中的 service 保持一致。 */
const ATRUST_CAS_URL = 'https://atrust.wust.edu.cn:443/passport/v1/auth/cas?sfDomain=cas12226';
/** 网关前置页面，票据失效时用于人工登录。 */
const ATRUST_PORTAL_URL = 'https://atrust.wust.edu.cn';
const SYSTEM_URL = 'http://cxcy.wust.edu.cn';

@Entry
@Component
struct InnovationCreditPage {
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;
  @State private errorText: string = '';
  @State private webUrl: string = '';
  @State private statusText: string = '正在获取双创学分系统登录票据…';
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.start();
  }

  private async start(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    this.errorText = '';
    this.webUrl = '';
    const storage = AppStorage.getInstance();
    const sid = (await storage.getStudentId()).trim();
    const password = await storage.getPassword();
    if (sid.length === 0 || password.length === 0) {
      this.loading = false;
      this.loadFailed = true;
      this.errorText = '还没有保存学号密码，请先在登录页登录后再使用双创学分';
      return;
    }
    try {
      this.statusText = '正在登录学校统一身份认证…';
      const ticket: InnovationCreditTicket = await InnovationCreditApi.getAuthTicket(sid, password);
      const value = (ticket.ticket ?? '').trim();
      if (value.length === 0) {
        throw new Error('统一身份认证未返回票据，请稍后重试');
      }
      this.webUrl = `${ATRUST_CAS_URL}&ticket=${encodeURIComponent(value)}`;
      this.statusText = '';
      this.loading = false;
      console.info(TAG, 'atrust ticket acquired, loading gateway');
    } catch (error) {
      this.loading = false;
      this.loadFailed = true;
      const message = error instanceof Error ? error.message : '双创学分登录失败';
      if (message.indexOf('TWOVERIFY') >= 0) {
        this.errorText = '该账号登录需要短信二次验证，请重新登录 App 完成验证后再试';
      } else if (message.indexOf('invalid password') >= 0 || message.indexOf('PASSERROR') >= 0) {
        this.errorText = '统一身份认证密码不正确，请重新登录 App';
      } else {
        this.errorText = message;
      }
    }
  }

  private openExternal(url: string): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      };
      context.startAbility(want);
    } catch (error) {
      console.warn(TAG, `open external failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '未能打开浏览器', duration: 1800 });
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_left'))
          .width(24).height(24)
          .onClick(() => router.back())
        Text('双创学分')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#333333')
          .margin({ left: 8 })
        Blank()
        Text('刷新')
          .fontSize(15).fontColor('#1ec98d')
          .onClick(() => this.start())
      }
      .width('100%').height(48)
      .padding({ left: 12, right: 14 })
      .backgroundColor(Color.White)

      Divider().height(0.5).color('#EEEEEE').width('100%')

      if (this.loading) {
        Column() {
          LoadingProgress().width(44).height(44).color('#1ec98d')
          Text(this.statusText || '正在加载…')
            .fontSize(14).fontColor('#888888').margin({ top: 14 })
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadFailed) {
        Column() {
          Text('双创学分暂时无法打开')
            .fontSize(17).fontColor('#555555')
          Text(this.errorText)
            .fontSize(13).fontColor('#999999').margin({ top: 10 })
            .textAlign(TextAlign.Center).width('84%')
          Row() {
            Button('重试')
              .fontSize(14).fontColor(Color.White).backgroundColor('#1ec98d').borderRadius(6)
              .onClick(() => this.start())
            Button('在浏览器打开')
              .fontSize(14).fontColor('#1ec98d').backgroundColor(Color.White).borderRadius(6)
              .border({ width: 1, color: '#1ec98d' }).margin({ left: 12 })
              .onClick(() => this.openExternal(SYSTEM_URL))
          }.margin({ top: 20 })
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Web({ src: this.webUrl, controller: this.webController })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onPageEnd(() => {
            this.loading = false;
          })
          .onErrorReceive((event) => {
            const mainFrame = event?.request?.isMainFrame();
            if (mainFrame === false) return;
            this.loadFailed = true;
            this.errorText = `网关返回错误（${event?.error?.getErrorCode() ?? '未知'}），请稍后重试`;
          })
        Text('若页面停留在 aTrust 门户，请点击门户中的“创新创业”入口进入学分系统。')
          .fontSize(12).fontColor('#999999').padding(10)
          .width('100%').textAlign(TextAlign.Center)
          .backgroundColor('#F5F5F5')
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#F5F5F5')
  }
}
