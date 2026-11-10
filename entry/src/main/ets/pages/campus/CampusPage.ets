import { router } from '@kit.ArkUI';
import webview from '@ohos.web.webview';

const TAG = 'CampusPage';
const CAMPUS_NEWS_URL = 'https://news.wustlinghang.cn';
const LOAD_TIMEOUT_MS = 12_000;
const CONTENT_CHECK_DELAY_MS = 1_000;
const MIN_CONTENT_SCORE = 20;

interface CampusShortcut {
  title: string;
  description: string;
  icon: Resource;
  route: string;
}

const CAMPUS_SHORTCUTS: CampusShortcut[] = [
  {
    title: '学校校历',
    description: '了解校历与假期安排',
    icon: $r('app.media.ic_schoolcalendar'),
    route: 'pages/campus/SchoolCalendarPage'
  },
  {
    title: '校车时刻',
    description: '查询各校区发车时间',
    icon: $r('app.media.ic_school_bus'),
    route: 'pages/campus/SchoolBusPage'
  },
  {
    title: '校园黄页',
    description: '查询校园常用号码',
    icon: $r('app.media.ic_yellow_page'),
    route: 'pages/campus/YellowPagesPage'
  },
  {
    title: '物理实验',
    description: '查询并导入实验课表',
    icon: $r('app.media.ic_physical'),
    route: 'pages/course/PhysicalExperimentPage'
  }
];

@Component
export struct CampusPage {
  @State private loading: boolean = true;
  @State private loadError: boolean = false;
  @State private errorText: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private loadTimer: number = -1;
  private contentCheckTimer: number = -1;

  aboutToAppear(): void {
    // Some WebView failures do not deliver an error callback on every device.
    // Start a component-level timeout as a final guard against a permanent blank page.
    this.startLoadTimer();
  }

  aboutToDisappear(): void {
    this.clearLoadTimer();
    this.clearContentCheckTimer();
  }

  private clearLoadTimer(): void {
    if (this.loadTimer !== -1) {
      clearTimeout(this.loadTimer);
      this.loadTimer = -1;
    }
  }

  private startLoadTimer(): void {
    this.clearLoadTimer();
    this.loadTimer = setTimeout(() => {
      this.loadTimer = -1;
      if (this.loading) {
        console.warn(TAG, 'campus news load timed out');
        this.loading = false;
        this.errorText = '校园资讯服务响应超时';
        this.loadError = true;
      }
    }, LOAD_TIMEOUT_MS);
  }

  private clearContentCheckTimer(): void {
    if (this.contentCheckTimer !== -1) {
      clearTimeout(this.contentCheckTimer);
      this.contentCheckTimer = -1;
    }
  }

  /**
   * onPageEnd 只表示导航结束，证书错误页、HTTP 空响应和 about:blank 也可能触发。
   * 延迟检查实际 DOM 内容，避免把空页面误判为加载成功。
   */
  private scheduleContentCheck(): void {
    this.clearContentCheckTimer();
    this.contentCheckTimer = setTimeout(() => {
      this.contentCheckTimer = -1;
      this.verifyCampusContent();
    }, CONTENT_CHECK_DELAY_MS);
  }

  private verifyCampusContent(): void {
    try {
      const script = `document.body ?
        (document.body.innerText.trim().length +
        document.body.getElementsByTagName('img').length * 20 +
        document.body.getElementsByTagName('a').length * 10) : 0`;
      this.controller.runJavaScript(script)
        .then((result: string) => {
          const contentScore = parseInt(result, 10);
          if (isNaN(contentScore) || contentScore < MIN_CONTENT_SCORE) {
            console.warn(TAG, `campus news page is empty, score=${result}`);
            this.showLoadError('校园资讯服务返回了空白页面');
            return;
          }
          this.clearLoadTimer();
          this.loading = false;
          this.loadError = false;
          this.errorText = '';
        })
        .catch((error: Error) => {
          console.warn(TAG, `verify campus content failed: ${error.message}`);
          this.showLoadError('校园资讯页面校验失败');
        });
    } catch (error) {
      console.warn(TAG, `run campus content check failed: ${JSON.stringify(error)}`);
      this.showLoadError('校园资讯页面校验失败');
    }
  }

  private retry(): void {
    this.clearContentCheckTimer();
    this.loading = true;
    this.loadError = false;
    this.errorText = '';
    this.startLoadTimer();
    try {
      this.controller.loadUrl(CAMPUS_NEWS_URL);
    } catch (error) {
      console.warn(TAG, `retry loadUrl failed: ${JSON.stringify(error)}`);
      this.showLoadError('校园资讯暂时无法连接');
    }
  }

  private showLoadError(message: string): void {
    this.clearLoadTimer();
    this.clearContentCheckTimer();
    this.loading = false;
    this.errorText = message;
    this.loadError = true;
  }

  private openShortcut(target: string): void {
    router.pushUrl({ url: target }).catch((error: Error) => {
      console.warn(TAG, `open shortcut failed: ${target}, ${error.message}`);
    });
  }

  @Builder
  private shortcutCard(item: CampusShortcut) {
    Row() {
      Image(item.icon)
        .width(44)
        .height(44)
        .objectFit(ImageFit.Contain)

      Column() {
        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Text(item.description)
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: 14 })
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(28)
        .fontColor('#BBBBBB')
    }
    .width('100%')
    .height(76)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .borderRadius(14)
    .onClick(() => this.openShortcut(item.route))
  }

  @Builder
  private fallbackContent() {
    Scroll() {
      Column() {
        Column() {
          Image($r('app.media.empty'))
            .width(72)
            .height(72)
            .objectFit(ImageFit.Contain)
          Text('校园资讯暂时无法加载')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#444444')
            .margin({ top: 10 })
          Text(this.errorText || '资讯服务连接异常，其他校园功能仍可正常使用')
            .fontSize(13)
            .fontColor('#999999')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
          Button('重新加载')
            .fontSize(14)
            .fontColor(Color.White)
            .height(38)
            .padding({ left: 24, right: 24 })
            .backgroundColor('#20C997')
            .borderRadius(20)
            .margin({ top: 16 })
            .onClick(() => this.retry())
        }
        .width('100%')
        .padding({ top: 24, bottom: 24, left: 18, right: 18 })
        .backgroundColor(Color.White)
        .borderRadius(16)

        Text('校园服务')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#444444')
          .width('100%')
          .margin({ top: 24, bottom: 12 })

        ForEach(CAMPUS_SHORTCUTS, (item: CampusShortcut) => {
          this.shortcutCard(item)
          Blank().height(12)
        }, (item: CampusShortcut) => item.route)
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  build() {
    Column() {
      Row() {
        Text('校园')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#555555')
        Text('SCHOOL')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#777777')
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 28, top: 32, bottom: 26 })

      Stack() {
        Web({ src: CAMPUS_NEWS_URL, controller: this.controller })
          .width('100%')
          .height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .cacheMode(CacheMode.Default)
          .onPageBegin(() => {
            this.clearContentCheckTimer();
            this.loading = true;
            this.loadError = false;
            this.errorText = '';
            this.startLoadTimer();
          })
          .onPageEnd(() => {
            this.scheduleContentCheck();
          })
          .onErrorReceive((event) => {
            const mainFrame = event?.request?.isMainFrame();
            if (mainFrame === false) {
              return;
            }
            const code = event?.error?.getErrorCode() ?? '未知';
            console.warn(TAG, `campus news web error: ${code} ${event?.error?.getErrorInfo() ?? ''}`);
            this.showLoadError(`校园资讯加载失败（错误码 ${code}）`);
          })
          .onHttpErrorReceive((event) => {
            const mainFrame = event?.request?.isMainFrame();
            if (mainFrame === false) {
              return;
            }
            const code = event?.response?.getResponseCode() ?? 0;
            if (code >= 400) {
              console.warn(TAG, `campus news http error: ${code}`);
              this.showLoadError(`校园资讯服务器返回 ${code}`);
            }
          })

        if (this.loadError) {
          this.fallbackContent()
        } else if (this.loading) {
          Column() {
            LoadingProgress()
              .width(38)
              .height(38)
              .color('#20C997')
            Text('校园资讯加载中…')
              .fontSize(13)
              .fontColor('#999999')
              .margin({ top: 10 })
          }
          .width('100%')
          .height('100%')
          .backgroundColor(Color.White)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F7')
  }
}
