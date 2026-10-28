import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusCatApi, CampusCatPost } from '../../net/CampusCatApi';
import { campusWallRelativeTime } from '../../net/CampusWallApi';
import { CampusRichText } from '../../components/CampusRichText';
import { CommunityPostImage } from '../../components/CommunityPostImage';

interface CampusCatDetailParams extends Record<string, string> { id: string; }

@Entry
@Component
struct CampusCatDetailPage {
  @State private post: CampusCatPost = {};
  @State private loading: boolean = true;

  aboutToAppear(): void {
    const params = router.getParams() as CampusCatDetailParams;
    this.load(Number(params?.id || 0));
  }

  private async load(id: number): Promise<void> {
    if (id <= 0) {
      this.loading = false;
      return;
    }
    try {
      this.post = await CampusCatApi.detail(id);
    } catch {
      promptAction.showToast({ message: '校园猫详情加载失败', duration: 1500 });
    }
    this.loading = false;
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('详情').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 })
      }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8')
      if (this.loading) {
        Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 40 })
      } else if (!this.post.id) {
        Text('帖子不存在或已被删除').fontSize(18).fontColor('#999999').margin({ top: 40 })
      } else {
        Scroll() {
          Column() {
            Row() {
              Image(this.post.authorAvatar || $r('app.media.ic_default_avatar'))
                .width(54).height(54).borderRadius(27).objectFit(ImageFit.Cover).margin({ right: 12 })
              Column() {
                Text(this.post.authorName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86')
                Text(campusWallRelativeTime(this.post.createdAt)).fontSize(15).fontColor('#999999').margin({ top: 4 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if ((this.post.tags || []).length > 0) {
                Text((this.post.tags || []).join(' · ')).fontSize(15).fontColor('#148D6D')
                  .backgroundColor('#E8F8F3').borderRadius(18).padding({ left: 12, right: 12, top: 7, bottom: 7 })
              }
            }.width('100%')
            if (this.post.title) {
              CampusRichText({ content: this.post.title, fontSize: 24, textColor: '#222222', baseBold: true, lineHeight: 34 })
                .margin({ top: 22 })
            }
            CampusRichText({ content: this.post.content || '', fontSize: 19, textColor: '#333333', lineHeight: 30 })
              .margin({ top: 12 })
            ForEach(this.post.images || [], (url: string) => {
              CommunityPostImage({ src: url }).margin({ top: 16 })
            }, (url: string, index: number) => `${index}-${url}`)
          }.width('100%').padding({ left: 28, right: 28, top: 22, bottom: 36 }).alignItems(HorizontalAlign.Start)
        }.width('100%').layoutWeight(1).backgroundColor(Color.White)
      }
    }.width('100%').height('100%').backgroundColor(Color.White)
  }
}
