import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, CampusWallReply, decodeHtmlEntities } from '../../net/CampusWallApi';
import { AppStorage } from '../../store/AppStorage';

interface DetailParams extends Record<string, string> { id: string; }

@Entry
@Component
struct CampusPostDetailPage {
  @State private postId: number = 0;
  @State private post: CampusWallPost = {};
  @State private replyText: string = '';
  @State private loading: boolean = true;
  @State private sending: boolean = false;
  @State private myAvatar: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams;
    this.postId = Number(params?.id || 0);
    this.load();
    this.loadMyAvatar();
  }

  private async loadMyAvatar(): Promise<void> {
    this.myAvatar = await AppStorage.getInstance().getAvatarUrl();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      this.post = await CampusWallApi.detail(this.postId);
    } catch {
      promptAction.showToast({ message: '详情加载失败', duration: 1500 });
    }
    this.loading = false;
  }

  private async submitReply(): Promise<void> {
    if (this.postId <= 0 || this.replyText.trim().length === 0) {
      promptAction.showToast({ message: '请输入回复内容', duration: 1200 });
      return;
    }
    if (this.sending) return;
    this.sending = true;
    try {
      await CampusWallApi.reply(this.postId, this.replyText.trim());
      this.replyText = '';
      await this.load();
    } catch {
      promptAction.showToast({ message: '回复失败，请稍后重试', duration: 1500 });
    }
    this.sending = false;
  }

  private dateLabel(value: string | undefined): string {
    if (!value) return '';
    const stamp = Date.parse(value);
    if (isNaN(stamp)) return value;
    const date = new Date(stamp);
    const pad = (number: number): string => number < 10 ? `0${number}` : `${number}`;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private contentHtml(value: string | undefined): string {
    let content = decodeHtmlEntities(value || '');
    if (!/<\/?(?:b|strong|i|em|u|s|strike|p|div|br)\b/i.test(content)) {
      content = content.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '<br>');
    }
    return `<div style="font-size:19px;color:#444444;line-height:1.65;word-break:break-word;">${content}</div>`;
  }

  @Builder
  private authorHeader() {
    Row() {
      Image(this.post.avatarUrl || $r('app.media.ic_default_avatar'))
        .width(58).height(58).borderRadius(29).objectFit(ImageFit.Cover).margin({ right: 14 })
      Column() {
        Text(this.post.displayName || this.post.realName || '同学')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86')
        Text(this.post.college || this.post.major || '')
          .fontSize(15).fontColor('#888888').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Column() {
        Text(this.dateLabel(this.post.createdAt)).fontSize(14).fontColor('#999999')
        Image($r('app.media.more_horiz')).width(27).height(27).margin({ top: 12 })
      }.alignItems(HorizontalAlign.End)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private postImage(url: string) {
    Image(url).width('100%').height(280).objectFit(ImageFit.Contain).margin({ top: 18 })
  }

  @Builder
  private replyItem(reply: CampusWallReply) {
    Row() {
      Image(reply.avatarUrl || $r('app.media.ic_default_avatar'))
        .width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 14 })
      Column() {
        Row() {
          Text(reply.displayName || reply.realName || '同学')
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#655C86').layoutWeight(1)
          Image($r('app.media.more_horiz')).width(24).height(24)
        }.width('100%')
        Text(reply.college || reply.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 })
        Text(decodeHtmlEntities(reply.content || '')).fontSize(19).fontColor('#333333').lineHeight(29).margin({ top: 16 })
        ForEach(reply.images || [], (url: string) => {
          this.postImage(url)
        }, (url: string) => url)
        Text(this.dateLabel(reply.createdAt)).fontSize(15).fontColor('#AAAAAA').margin({ top: 14 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
      .padding({ left: 28, right: 28, top: 22, bottom: 24 }).backgroundColor(Color.White)
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back())
        Text('详情').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 })
        Blank().layoutWeight(1)
      }.width('100%').height(96).alignItems(VerticalAlign.Center)
        .padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8')

      Scroll() {
        Column() {
          if (this.loading) {
            Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 40 })
          } else {
            Column() {
              this.authorHeader()
              Text(decodeHtmlEntities(this.post.title || ''))
                .fontSize(25).fontWeight(FontWeight.Bold).fontColor('#222222').lineHeight(36).margin({ top: 26 })
              RichText(this.contentHtml(this.post.content)).width('100%').margin({ top: 20 })
              ForEach(this.post.images || [], (url: string) => {
                this.postImage(url)
              }, (url: string) => url)
            }.width('100%').alignItems(HorizontalAlign.Start)
              .padding({ left: 28, right: 28, top: 24, bottom: 28 }).backgroundColor(Color.White)

            Text('回复').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
              .width('100%').padding({ left: 28, top: 20, bottom: 16 }).backgroundColor('#F1F2F4')

            ForEach(this.post.replies || [], (reply: CampusWallReply) => {
              this.replyItem(reply)
            }, (reply: CampusWallReply) => `${reply.id || reply.createdAt || reply.content}`)
          }
        }.width('100%').alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8')

      Row() {
        Image(this.myAvatar || $r('app.media.ic_default_avatar'))
          .width(42).height(42).borderRadius(21).objectFit(ImageFit.Cover).margin({ right: 10 })
        TextInput({ placeholder: '说点什么吧...', text: this.replyText })
          .layoutWeight(1).fontSize(17).backgroundColor('#F5F5F5').borderRadius(22)
          .onChange((value: string) => { this.replyText = value; })
        Button(this.sending ? '发送中' : '发送').fontSize(17).fontColor(Color.White)
          .backgroundColor('#20C894').borderRadius(22).margin({ left: 8 }).onClick(() => this.submitReply())
      }.width('92%').height(68).padding({ left: 10, right: 8, top: 8, bottom: 8 })
        .backgroundColor(Color.White).borderRadius(34).margin({ top: 8, bottom: 16 })
        .shadow({ radius: 8, color: '#22000000', offsetY: 2 })
    }.width('100%').height('100%').backgroundColor('#F5F6F8')
  }
}
