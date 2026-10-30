import router from '@ohos.router';
import { HomeContentApi, HomeNotice } from '../../net/HomeContentApi';
import { CampusRichText } from '../../components/CampusRichText';

interface HomeNoticeDetailParams extends Record<string, string> {
  id: string;
  title: string;
  content: string;
  updateTime: string;
}

@Entry
@Component
struct HomeNoticeDetailPage {
  @State private noticeId: number = 0;
  @State private title: string = '';
  @State private content: string = '';
  @State private updateTime: string = '';
  @State private loading: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as HomeNoticeDetailParams;
    this.noticeId = Number(params?.id || 0);
    this.title = params?.title || '';
    this.content = params?.content || '';
    this.updateTime = params?.updateTime || '';
    if (!this.title && !this.content && this.noticeId > 0) this.loadNotice();
  }

  private async loadNotice(): Promise<void> {
    this.loading = true;
    try {
      const notices = await HomeContentApi.notices();
      for (let i = 0; i < notices.length; i++) {
        if (notices[i].id === this.noticeId) {
          const item: HomeNotice = notices[i];
          this.title = item.title;
          this.content = item.content;
          this.updateTime = item.updateTime;
          break;
        }
      }
    } catch (error) {
      console.warn('HomeNoticeDetailPage', `load notice failed: ${JSON.stringify(error)}`);
    } finally {
      this.loading = false;
    }
  }

  private dateText(value: string): string {
    if (!value) return '';
    let text = value.replace('T', ' ');
    const dot = text.indexOf('.');
    if (dot >= 0) text = text.substring(0, dot);
    return text.length > 19 ? text.substring(0, 19) : text;
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_left'))
          .width(26).height(26).objectFit(ImageFit.Contain)
          .onClick(() => router.back())
        Text(this.title || '公告详情')
          .fontSize(27).fontWeight(FontWeight.Bold).fontColor('#303030')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 20 }).layoutWeight(1)
      }
      .width('100%').constraintSize({ minHeight: 92 })
      .padding({ left: 22, right: 24, top: 18, bottom: 18 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#F5F6F8')

      if (this.loading) {
        Column() {
          LoadingProgress().width(34).height(34).color('#20C894')
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.content) {
              CampusRichText({
                content: this.content,
                fontSize: 21,
                textColor: '#333333',
                lineHeight: 34
              })
            } else {
              Text('暂无公告正文').width('100%').fontSize(18).fontColor('#999999')
            }
            if (this.updateTime) {
              Text(this.dateText(this.updateTime))
                .width('100%').fontSize(15).fontColor('#999999').margin({ top: 28 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 28, right: 28, top: 30, bottom: 48 })
        }.width('100%').layoutWeight(1).backgroundColor(Color.White)
      }
    }.width('100%').height('100%').backgroundColor(Color.White)
  }
}
