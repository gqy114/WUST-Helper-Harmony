/**
 * 培养方案页面。
 *
 * 关键点：ArkWeb 的 loadData 会把内容里的第一个 `#` 当成文档片段分隔符，
 * 之后的正文全部被丢弃。培养方案的 HTML 里大量出现 `#`（CSS 颜色、锚点），
 * 直接传入会让 Web 显示成白屏。官方要求先 encodeURIComponent（把 # 转成 %23），
 * 或者在调用前做 base64 编码。这里统一在调用处编码。
 */
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { CultivationPlanApi } from '../../net/CultivationPlanApi';

const TAG = 'TrainingPlanPage';
const BASE_URL = 'https://www.lyzyy.love/';
const HISTORY_URL = 'https://www.lyzyy.love/UnderGraduate/Support/getTrainingPlanPage';
const MAX_RENDER_ATTEMPTS = 2;

@Entry
@Component
struct TrainingPlanPage {
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;
  @State private errorText: string = '';
  @State private html: string = '';
  private webController: webview.WebviewController = new webview.WebviewController();
  private controllerAttached: boolean = false;
  private renderAttempts: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    this.errorText = '';
    this.html = '';
    this.renderAttempts = 0;
    // loading 会把 Web 组件从树下移除，controller 随之解绑；
    // 这里同步复位，等新组件 onControllerAttached 后再 loadData，
    // 避免在旧 controller 已经解绑的情况下渲染。
    this.controllerAttached = false;
    try {
      this.html = await CultivationPlanApi.fetchHtml();
    } catch (error) {
      this.loadFailed = true;
      this.errorText = error instanceof Error ? error.message : '培养方案加载失败';
      promptAction.showToast({ message: this.errorText, duration: 1800 });
    }
    this.loading = false;
    if (!this.loadFailed) this.renderHtml();
  }

  private documentHtml(source: string): string {
    const additions = `<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
<style>
  html, body { max-width: 100%; min-height: 100%; box-sizing: border-box; }
  body { margin: 0; padding: 14px; overflow-x: auto; font-size: 16px; line-height: 1.65; color: #333; background: #fff; }
  img { max-width: 100%; height: auto; }
  table { max-width: 100%; border-collapse: collapse; }
  pre { white-space: pre-wrap; overflow-wrap: anywhere; }
</style>`;
    if (/<head(?:\s[^>]*)?>/i.test(source)) {
      return source.replace(/<head(?:\s[^>]*)?>/i, (head: string) => `${head}${additions}`);
    }
    if (/<html(?:\s[^>]*)?>/i.test(source)) {
      return source.replace(/<html(?:\s[^>]*)?>/i, (htmlTag: string) => `${htmlTag}<head>${additions}</head>`);
    }
    return `<!DOCTYPE html><html><head>${additions}</head><body>${source}</body></html>`;
  }

  /**
   * 渲染正文。Web 组件可能比正文晚就绪，所以由 load() 与 onControllerAttached 共同触发，
   * 并用 renderAttempts 限制重复渲染。
   */
  private renderHtml(): void {
    if (!this.controllerAttached || this.html.trim().length === 0) return;
    if (this.renderAttempts >= MAX_RENDER_ATTEMPTS) return;
    this.renderAttempts++;
    try {
      // encodeURIComponent 会把 # 编码为 %23，避免 loadData 截断后面的正文。
      const encoded = encodeURIComponent(this.documentHtml(this.html));
      this.webController.loadData(encoded, 'text/html', 'UTF-8', BASE_URL, HISTORY_URL);
      console.info(TAG, `loadData attempt=${this.renderAttempts} size=${encoded.length}`);
    } catch (error) {
      console.error(TAG, `render html failed: ${JSON.stringify(error)}`);
      this.loadFailed = true;
      this.errorText = '培养方案渲染失败，请重试';
    }
  }

  /** 页面渲染完成后检查是否仍然是空白页（旧内核上 about:blank 会覆盖 loadData 的结果）。 */
  private verifyRendered(): void {
    if (this.renderAttempts === 0 || this.html.trim().length === 0) return;
    try {
      this.webController.runJavaScript('document.body ? document.body.innerText.length : 0')
        .then((result: string) => {
          const length = parseInt(result, 10);
          if (!isNaN(length) && length === 0 && this.renderAttempts < MAX_RENDER_ATTEMPTS) {
            console.warn(TAG, 'rendered page is empty, retry loadData');
            this.renderHtml();
          }
        })
        .catch(() => {
          // runJavaScript 失败不影响页面本身，忽略。
        });
    } catch (error) {
      console.warn(TAG, `verify rendered failed: ${JSON.stringify(error)}`);
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(42)
          .width(48)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Text('培养方案')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank().layoutWeight(1)
        Text('刷新')
          .fontSize(17)
          .fontColor('#20B984')
          .onClick(() => this.load())
      }
      .width('100%')
      .height(76)
      .padding({ left: 14, right: 20 })
      .backgroundColor(Color.White)

      if (this.loading) {
        Column() {
          LoadingProgress().width(48).height(48).color('#20B984')
          Text('正在获取培养方案…').fontSize(18).fontColor('#777777').margin({ top: 18 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadFailed) {
        Column() {
          Text('培养方案获取失败').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#444444')
          Text(this.errorText || '请检查网络或登录状态')
            .fontSize(17)
            .fontColor('#888888')
            .textAlign(TextAlign.Center)
            .margin({ top: 14 })
          Button('重新加载')
            .width(150)
            .height(50)
            .fontSize(18)
            .fontColor(Color.White)
            .backgroundColor('#20B984')
            .margin({ top: 26 })
            .onClick(() => this.load())
        }
        .width('88%')
        .padding(28)
        .backgroundColor(Color.White)
        .borderRadius(22)
        .margin({ top: 26 })
      } else {
        Web({ src: 'about:blank', controller: this.webController })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(false)
          .onControllerAttached(() => {
            this.controllerAttached = true;
            this.renderHtml();
          })
          .onPageEnd(() => {
            this.verifyRendered();
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F7')
  }
}
