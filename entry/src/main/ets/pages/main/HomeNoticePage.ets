import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HomeContentApi, HomeNotice } from '../../net/HomeContentApi';

@Entry
@Component
struct HomeNoticePage {
  @State private notices: HomeNotice[] = [];
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;

  aboutToAppear(): void {
    this.loadNotices();
  }

  private async loadNotices(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    try {
      this.notices = await HomeContentApi.notices();
    } catch (error) {
      this.loadFailed = true;
      console.warn('HomeNoticePage', `load notices failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '公告加载失败，请稍后重试', duration: 1500 });
    } finally {
      this.loading = false;
    }
  }

  private plainText(value: string): string {
    return value.replace(/<br\s*\/?>/gi, ' ').replace(/<\/p>|<\/div>/gi, ' ')
      .replace(/<[^>]+>/g, '').replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<').replace(/&gt;/gi, '>').replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'").replace(/\s+/g, ' ').trim();
  }

  private dateText(value: string): string {
    if (!value) return '';
    let text = value.replace('T', ' ');
    const dot = text.indexOf('.');
    if (dot >= 0) text = text.substring(0, dot);
    return text.length > 19 ? text.substring(0, 19) : text;
  }

  private openNotice(item: HomeNotice): void {
    router.pushUrl({
      url: 'pages/main/HomeNoticeDetailPage',
      params: {
        id: `${item.id}`,
        title: item.title,
        content: item.content,
        updateTime: item.updateTime
      }
    });
  }

  @Builder
  private noticeItem(item: HomeNotice) {
    Column() {
      Text(item.title || '助手公告')
        .width('100%')
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F2F2F')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.content) {
        Text(this.plainText(item.content))
          .width('100%')
          .fontSize(17)
          .fontColor('#666666')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 10 })
      }
      Text(this.dateText(item.updateTime))
        .width('100%')
        .fontSize(15)
        .fontColor('#999999')
        .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 24, right: 24, top: 22, bottom: 22 })
    .backgroundColor(Color.White)
    .border({ width: { bottom: 1 }, color: '#EEEEEE' })
    .onClick(() => this.openNotice(item))
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_left'))
          .width(26).height(26).objectFit(ImageFit.Contain)
          .onClick(() => router.back())
        Text('助手公告')
          .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#303030')
          .margin({ left: 20 })
      }
      .width('100%').height(92)
      .padding({ left: 22, right: 22 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#F5F6F8')

      if (this.loading) {
        Column() {
          LoadingProgress().width(34).height(34).color('#20C894')
          Text('正在加载公告…').fontSize(16).fontColor('#999999').margin({ top: 14 })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.notices.length === 0) {
        Column() {
          Text(this.loadFailed ? '公告加载失败' : '暂无公告')
            .fontSize(18).fontColor('#999999')
          if (this.loadFailed) {
            Button('重新加载').fontSize(16).fontColor(Color.White).backgroundColor('#20C894')
              .borderRadius(20).margin({ top: 18 }).onClick(() => this.loadNotices())
          }
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.notices, (item: HomeNotice) => {
            ListItem() { this.noticeItem(item) }
          }, (item: HomeNotice, index: number) => `${item.id || index}-${item.updateTime}`)
        }.width('100%').layoutWeight(1).backgroundColor(Color.White)
      }
    }.width('100%').height('100%').backgroundColor('#F5F6F8')
  }
}
