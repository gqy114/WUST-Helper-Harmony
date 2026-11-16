import router from '@ohos.router';
import webview from '@ohos.web.webview';
import { promptAction } from '@kit.ArkUI';
import { CampusNewsApi, NewsDetail } from '../../net/CampusNewsApi';

const TAG = 'CampusNewsDetailPage';

@Entry
@Component
struct CampusNewsDetailPage {
  @State private loading: boolean = true;
  @State private failed: boolean = false;
  @State private errorText: string = '';
  @State private title: string = '';
  @State private dateText: string = '';
  @State private contentHtml: string = '';
  private articleId: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private attached: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.articleId = (params?.id || '').trim();
    this.title = params?.title || '资讯详情';
    this.load();
  }

  aboutToDisappear(): void {
    this.attached = false;
  }

  private async load(): Promise<void> {
    if (!this.articleId) {
      this.loading = false;
      this.failed = true;
      this.errorText = '缺少资讯编号';
      return;
    }
    this.loading = true;
    this.failed = false;
    try {
      const detail: NewsDetail = await CampusNewsApi.detail(this.articleId);
      this.title = detail.title || this.title;
      this.dateText = (detail.published_at || '').substring(0, 10);
      this.contentHtml = detail.content_html || this.textToHtml(detail.content_text || '');
      this.loading = false;
      this.renderContent();
    } catch (error) {
      this.loading = false;
      this.failed = true;
      this.errorText = error instanceof Error ? error.message : '资讯详情加载失败';
      promptAction.showToast({ message: this.errorText, duration: 1800 });
    }
  }

  private textToHtml(text: string): string {
    const escaped = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return escaped.split(/\n+/).map((line: string) => `<p>${line}</p>`).join('');
  }

  private renderContent(): void {
    if (!this.attached || !this.contentHtml) return;
    const document = `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
<style>
  body { margin:0; padding:14px; font-size:16px; line-height:1.75; color:#333; background:#fff; }
  img { max-width:100%; height:auto; }
  table { width:100%; border-collapse:collapse; }
  td, th { border:1px solid #ddd; padding:6px; font-size:14px; }
  p { margin: 0 0 12px; }
</style></head><body>${this.contentHtml}</body></html>`;
    // ArkWeb loadData 会把第一个 # 当片段分隔符，整段必须先编码。
    this.controller.loadData(encodeURIComponent(document), 'text/html', 'UTF-8');
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(26).fontColor('#333333').onClick(() => router.back())
        Text('资讯详情').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 14 })
        Blank()
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 10 }).backgroundColor(Color.White)

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#20C997')
          Text('加载中…').fontSize(13).fontColor('#999999').margin({ top: 10 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.failed) {
        Column() {
          Image($r('app.media.empty')).width(80).height(80).objectFit(ImageFit.Contain)
          Text(this.errorText).fontSize(14).fontColor('#999999').textAlign(TextAlign.Center).margin({ top: 12 })
          Button('重试').fontSize(14).height(36).margin({ top: 16 }).backgroundColor('#20C997')
            .onClick(() => this.load())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%')
          if (this.dateText) {
            Text(this.dateText).fontSize(12).fontColor('#999999').width('100%').margin({ top: 6 })
          }
        }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 8 }).backgroundColor(Color.White)

        Web({ src: 'about:blank', controller: this.controller })
          .width('100%').layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onControllerAttached(() => {
            this.attached = true;
            this.renderContent();
          })
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F6F7')
  }
}
