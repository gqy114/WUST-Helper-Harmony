import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { CultivationPlanApi } from '../../net/CultivationPlanApi';

@Entry
@Component
struct TrainingPlanPage {
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;
  @State private errorText: string = '';
  @State private html: string = '';
  private webController: webview.WebviewController = new webview.WebviewController();
  private controllerAttached: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    this.errorText = '';
    this.html = '';
    try {
      this.html = await CultivationPlanApi.fetchHtml();
    } catch (error) {
      this.loadFailed = true;
      this.errorText = error instanceof Error ? error.message : '培养方案加载失败';
      promptAction.showToast({ message: this.errorText, duration: 1800 });
    }
    this.loading = false;
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

  private renderHtml(): void {
    if (!this.controllerAttached || this.html.trim().length === 0) return;
    try {
      this.webController.loadData(
        this.documentHtml(this.html),
        'text/html',
        'UTF-8',
        'https://www.lyzyy.love/',
        'https://www.lyzyy.love/UnderGraduate/Support/getTrainingPlanPage'
      );
    } catch (error) {
      console.error('TrainingPlanPage', `render html failed: ${JSON.stringify(error)}`);
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
          .javaScriptAccess(false)
          .domStorageAccess(false)
          .onControllerAttached(() => {
            this.controllerAttached = true;
            this.renderHtml();
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F7')
  }
}
