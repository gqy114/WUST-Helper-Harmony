/**
 * WebPage — 通用网页页面
 *
 * 对应安卓 OtherWebActivity
 * 接收 Router 参数：
 *   title: string  页面标题
 *   url:   string  加载的网页地址
 *
 * 功能：返回按钮 / 标题栏 / Web 组件加载 / 网络错误提示 / 系统浏览器兜底
 *
 * 说明：
 *  1. onErrorReceive 对子资源（图片、脚本、统计请求）失败也会回调，
 *     之前只要任意子资源失败就把整页替换成“页面加载失败”，
 *     导致页面本身已经打开却仍显示失败的误报。这里只把主文档错误当作失败。
 *  2. 错误提示以浮层形式覆盖在 Web 之上，不销毁 Web 组件，
 *     这样“重试”时 controller 仍然有效。
 *
 * 文件路径：entry/src/main/ets/pages/common/WebPage.ets
 */
import { router } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { common, Want } from '@kit.AbilityKit';

const TAG = 'WebPage';

interface WebPageParams {
  title: string;
  url: string;
}

@Entry
@Component
struct WebPage {
  @State private pageTitle: string = '';
  @State private pageUrl: string = '';
  @State private loadError: boolean = false;
  @State private loading: boolean = true;
  @State private progress: number = 0;
  @State private errorText: string = '';
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.pageTitle = params?.title ?? '';
    const rawUrl = params?.url ?? '';
    if (rawUrl && rawUrl.trim().length > 0) {
      this.pageUrl = rawUrl.trim();
    }
    console.info(TAG, `load url: ${rawUrl}`);
  }

  private retry(): void {
    if (!this.pageUrl) return;
    this.loadError = false;
    this.errorText = '';
    this.loading = true;
    this.progress = 0;
    try {
      this.webController.loadUrl(this.pageUrl);
    } catch (error) {
      console.warn(TAG, `retry loadUrl failed: ${JSON.stringify(error)}`);
      this.loading = false;
      this.loadError = true;
      this.errorText = '页面暂时无法打开';
    }
  }

  private openInBrowser(): void {
    if (!this.pageUrl) return;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: this.pageUrl
      };
      context.startAbility(want);
    } catch (error) {
      console.warn(TAG, `open in browser failed: ${JSON.stringify(error)}`);
    }
  }

  @Builder
  private errorOverlay() {
    Column() {
      Text('页面加载失败')
        .fontSize(17).fontColor('#555555')
      Text(this.errorText || '请检查网络连接后重试')
        .fontSize(13).fontColor('#999999').margin({ top: 10 })
        .textAlign(TextAlign.Center).width('84%')
      Row() {
        Button('重试').fontSize(14).fontColor(Color.White)
          .backgroundColor('#1ec98d').borderRadius(6)
          .onClick(() => this.retry())
        Button('在浏览器打开').fontSize(14).fontColor('#1ec98d')
          .backgroundColor(Color.White).borderRadius(6)
          .border({ width: 1, color: '#1ec98d' })
          .margin({ left: 12 })
          .onClick(() => this.openInBrowser())
      }.margin({ top: 18 })
      Button('返回').fontSize(13).fontColor('#999999')
        .backgroundColor(Color.Transparent)
        .margin({ top: 6 })
        .onClick(() => { router.back(); })
    }
    .width('100%').height('100%')
    .backgroundColor('#F5F5F5')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      // ── 顶部导航栏 ──
      Row() {
        Image($r('app.media.ic_arrow_left'))
          .width(24).height(24)
          .objectFit(ImageFit.Contain)
          .onClick(() => {
            router.back();
          })

        Text(this.pageTitle)
          .fontSize(17).fontWeight(FontWeight.Medium).fontColor('#333333')
          .margin({ left: 8 }).layoutWeight(1).textAlign(TextAlign.Start)
      }
      .width('100%').height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Color.White)

      Divider().height(0.5).color('#EEEEEE').width('100%')

      // ── Web 内容或错误提示 ──
      if (!this.pageUrl) {
        Column() {
          Text('页面加载失败')
            .fontSize(16).fontColor('#666666').margin({ top: 24 })
          Text('未指定网页地址').fontSize(13).fontColor('#999999').margin({ top: 8 })
          Button('返回').fontSize(14).fontColor(Color.White)
            .backgroundColor('#1ec98d').borderRadius(6).margin({ top: 16 })
            .onClick(() => { router.back(); })
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Stack() {
          Web({ src: this.pageUrl, controller: this.webController })
            .width('100%').height('100%')
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .cacheMode(CacheMode.Default)
            .onPageBegin(() => {
              this.loading = true;
            })
            .onProgressChange((event) => {
              if (event) this.progress = event.newProgress;
            })
            .onPageEnd(() => {
              this.loading = false;
              // 主文档已经加载完成，之前的子资源错误不应继续占据整页。
              this.loadError = false;
            })
            .onErrorReceive((event) => {
              const mainFrame = event?.request?.isMainFrame();
              if (mainFrame === false) {
                console.warn(TAG, `sub resource error ignored: ${event?.error?.getErrorInfo() ?? ''}`);
                return;
              }
              console.warn(TAG, `web error: ${event?.error?.getErrorCode() ?? 'unknown'} ${event?.error?.getErrorInfo() ?? ''}`);
              this.loading = false;
              this.errorText = `错误码 ${event?.error?.getErrorCode() ?? '未知'}`;
              this.loadError = true;
            })
            .onHttpErrorReceive((event) => {
              const mainFrame = event?.request?.isMainFrame();
              if (mainFrame === false) return;
              const code = event?.response?.getResponseCode() ?? 0;
              if (code >= 400) {
                console.warn(TAG, `http error ${code} for ${this.pageUrl}`);
                this.loading = false;
                this.errorText = `服务器返回 ${code}`;
                this.loadError = true;
              }
            })

          if (this.loadError) {
            this.errorOverlay()
          } else if (this.loading) {
            Column() {
              LoadingProgress().width(38).height(38).color('#1ec98d')
              Text(`页面加载中… ${this.progress > 0 ? this.progress + '%' : ''}`)
                .fontSize(13).fontColor('#999999').margin({ top: 10 })
            }
            .width('100%').height('100%')
            .backgroundColor(Color.White)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%').layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#F5F5F5')
  }
}
