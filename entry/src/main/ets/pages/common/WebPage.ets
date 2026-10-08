/**
 * WebPage — 通用网页页面
 *
 * 对应安卓 OtherWebActivity
 * 接收 Router 参数：
 *   title: string  页面标题
 *   url:   string  加载的网页地址
 *
 * 功能：返回按钮 / 标题栏 / Web 组件加载 / 网络错误提示
 *
 * 文件路径：entry/src/main/ets/pages/common/WebPage.ets
 */
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkUI';

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

  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.pageTitle = params?.title ?? '';
    const rawUrl = params?.url ?? '';
    if (rawUrl && rawUrl !== '') {
      this.pageUrl = rawUrl;
    }
    console.info(TAG, `load url: ${rawUrl}`);
  }

  onPageShow(): void {
    if (this.pageUrl && this.pageUrl !== '' && !this.loadError) {
      try {
        this.webController.loadUrl(this.pageUrl);
      } catch {
        console.warn(TAG, `loadUrl error: ${e}`);
        this.loadError = true;
      }
    }
  }

  build() {
    Column() {
      // ── 顶部导航栏 ──
      Row() {
        // 返回按钮
        Image($r('app.media.ic_arrow_left'))
          .width(24).height(24)
          .objectFit(ImageFit.Contain)
          .onClick(() => {
            router.back();
          })

        // 标题
        Text(this.pageTitle)
          .fontSize(17).fontWeight(FontWeight.Medium).fontColor('#333333')
          .margin({ left: 8 }).layoutWeight(1).textAlign(TextAlign.Start)
      }
      .width('100%').height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Color.White)

      Divider().height(0.5).color('#EEEEEE').width('100%')

      // ── Web 内容或错误提示 ──
      if (this.loadError || !this.pageUrl) {
        Column() {
          Text('页面加载失败')
            .fontSize(16).fontColor('#666666').margin({ top: 24 })
          if (!this.pageUrl) {
            Text('未指定网页地址').fontSize(13).fontColor('#999999').margin({ top: 8 })
          } else {
            Text('请检查网络连接后重试').fontSize(13).fontColor('#999999').margin({ top: 8 })
          }
          Button('返回').fontSize(14).fontColor(Color.White)
            .backgroundColor('#1ec98d').borderRadius(6).margin({ top: 16 })
            .onClick(() => { router.back(); })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        // Web 组件
        Web({ src: this.pageUrl, controller: this.webController })
          .width('100%').height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onErrorReceive((event) => {
            console.warn(TAG, `web error: ${event?.error?.info ?? 'unknown'}`);
            this.loadError = true;
          })
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#F5F5F5')
  }
}

