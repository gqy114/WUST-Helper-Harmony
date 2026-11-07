import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusCatApi, CampusCatPost, CampusCatReply } from '../../net/CampusCatApi';
import { campusWallRelativeTime } from '../../net/CampusWallApi';
import { CampusRichText } from '../../components/CampusRichText';
import { CommunityPostImage } from '../../components/CommunityPostImage';
import { AppStorage } from '../../store/AppStorage';

interface CampusCatDetailParams extends Record<string, string> { id: string; }

@Entry
@Component
struct CampusCatDetailPage {
  @State private post: CampusCatPost = {};
  @State private comments: CampusCatReply[] = [];
  @State private loading: boolean = true;
  @State private replyText: string = '';
  @State private sending: boolean = false;
  @State private myAvatar: string = '';
  @State private isMine: boolean = false;
  @State private actionOpen: boolean = false;
  @State private deleteDialogOpen: boolean = false;
  @State private deleting: boolean = false;
  private postId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as CampusCatDetailParams;
    this.postId = Number(params?.id || 0);
    this.load(this.postId);
    this.loadAvatar();
    this.loadOwnership();
  }

  private async loadAvatar(): Promise<void> {
    this.myAvatar = await AppStorage.getInstance().getAvatarUrl();
  }

  private async loadOwnership(): Promise<void> {
    try {
      const mine = await CampusCatApi.mine();
      this.isMine = mine.some((post: CampusCatPost) => (post.id || 0) === this.postId);
    } catch { this.isMine = false; }
  }

  private async confirmDelete(): Promise<void> {
    if (this.deleting || !this.isMine || this.postId <= 0) return;
    this.deleting = true;
    try {
      await CampusCatApi.deletePost(this.postId);
      this.deleteDialogOpen = false;
      promptAction.showToast({ message: '帖子已删除', duration: 1200 });
      router.back();
    } catch { promptAction.showToast({ message: '删除失败，请稍后重试', duration: 1500 }); }
    this.deleting = false;
  }

  private async load(id: number): Promise<void> {
    if (id <= 0) {
      this.loading = false;
      return;
    }
    try {
      this.post = await CampusCatApi.detail(id);
      this.comments = await CampusCatApi.comments(id);
    } catch {
      promptAction.showToast({ message: '校园猫详情加载失败', duration: 1500 });
    }
    this.loading = false;
  }

  private async submitReply(): Promise<void> {
    const content = this.replyText.trim();
    if (!content) {
      promptAction.showToast({ message: '请输入评论内容', duration: 1200 });
      return;
    }
    if (this.sending || this.postId <= 0) return;
    this.sending = true;
    try {
      await CampusCatApi.reply(this.postId, content);
      this.replyText = '';
      this.comments = await CampusCatApi.comments(this.postId);
      this.post.commentCount = this.comments.length;
      promptAction.showToast({ message: '评论成功', duration: 1000 });
    } catch {
      promptAction.showToast({ message: '评论失败，请稍后重试', duration: 1500 });
    }
    this.sending = false;
  }

  @Builder
  private commentItem(comment: CampusCatReply) {
    Row() {
      Image(comment.authorAvatar || $r('app.media.ic_default_avatar'))
        .width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 14 })
      Column() {
        Text(comment.authorName || '同学').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#655C86')
        CampusRichText({ content: comment.content || '', fontSize: 19, textColor: '#333333', lineHeight: 29 })
          .margin({ top: 14 })
        Text(campusWallRelativeTime(comment.createdAt)).fontSize(15).fontColor('#AAAAAA').margin({ top: 12 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
      .padding({ left: 28, right: 28, top: 22, bottom: 24 }).backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: '#EEEEEE' })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
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
                if (this.isMine) {
                  Image($r('app.media.more_horiz')).width(28).height(28).margin({ left: 10 })
                    .onClick(() => { this.actionOpen = true; })
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
            Text(`评论${this.comments.length > 0 ? ` ${this.comments.length}` : ''}`)
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
              .width('100%').padding({ left: 28, top: 20, bottom: 16 }).backgroundColor('#F1F2F4')
            if (this.comments.length === 0) {
              Text('还没有评论，来聊聊吧').fontSize(17).fontColor('#AAAAAA')
                .width('100%').height(100).textAlign(TextAlign.Center).backgroundColor(Color.White)
            } else {
              ForEach(this.comments, (comment: CampusCatReply) => {
                this.commentItem(comment)
              }, (comment: CampusCatReply) => `${comment.id || comment.createdAt || comment.content}`)
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
            .constraintSize({ minHeight: '100%' })
        }.width('100%').layoutWeight(1).backgroundColor('#F5F6F8').align(Alignment.Top)
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
      }
    }.width('100%').height('100%').backgroundColor('#F5F6F8')
    if (this.actionOpen) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
      Column() {
        Row() {
          Text('操作').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#222222').layoutWeight(1)
          Text('×').fontSize(32).fontWeight(FontWeight.Bold).fontColor('#555555').width(52).height(52)
            .textAlign(TextAlign.Center).backgroundColor('#F5F5F5').borderRadius(26)
            .onClick(() => { this.actionOpen = false; })
        }.width('100%')
        Column() {
          Image($r('app.media.delete')).width(82).height(82).padding(20).objectFit(ImageFit.Contain)
            .backgroundColor('#F7F7F7').borderRadius(18)
          Text('删除').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#D9534F').margin({ top: 10 })
        }.margin({ top: 24 }).onClick(() => {
          this.actionOpen = false;
          this.deleteDialogOpen = true;
        })
      }.width('100%').height(290).padding({ left: 28, right: 28, top: 28 }).backgroundColor(Color.White)
        .borderRadius({ topLeft: 28, topRight: 28 })
    }
    if (this.deleteDialogOpen) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height('100%').backgroundColor('#66000000')
        Column() {
          Text('删除这条帖子？').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#333333')
          Text('删除后无法恢复').fontSize(17).fontColor('#999999').margin({ top: 14, bottom: 28 })
          Row() {
            Button('取消').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
              .width('42%').height(54).backgroundColor('#F0F0F0').borderRadius(9)
              .onClick(() => { this.deleteDialogOpen = false; })
            Button(this.deleting ? '删除中' : '删除').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .width('42%').height(54).backgroundColor('#E35D5B').borderRadius(9).margin({ left: 18 })
              .enabled(!this.deleting).onClick(() => this.confirmDelete())
          }.justifyContent(FlexAlign.Center)
        }.width('82%').padding({ left: 24, right: 24, top: 30, bottom: 28 })
          .backgroundColor(Color.White).borderRadius(24).alignItems(HorizontalAlign.Center)
      }.width('100%').height('100%')
    }
    }
  }
}
