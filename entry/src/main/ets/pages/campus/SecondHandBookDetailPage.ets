import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';
import { call } from '@kit.TelephonyKit';
import { AppStorage } from '../../store/AppStorage';
import { SecondHandBookApi, SecondhandBook, SecondhandDetail, SecondhandListing, SecondhandReply } from '../../net/SecondHandBookApi';
import { CampusWallApi, CampusWallPost } from '../../net/CampusWallApi';

interface DetailParams { listing?: string; postId?: string; source?: string; }

@Entry
@Component
struct SecondHandBookDetailPage {
  @State private listing: SecondhandListing = {};
  @State private book: SecondhandBook = {};
  @State private replies: SecondhandReply[] = [];
  @State private loading: boolean = true;
  @State private replyOpen: boolean = false;
  @State private replyText: string = '';
  @State private sending: boolean = false;
  @State private contactOpen: boolean = false;
  @State private myAvatar: string = '';
  @State private myStudentId: string = '';
  @State private myName: string = '';
  @State private myCollege: string = '';
  @State private actionOpen: boolean = false;
  @State private deleteDialogOpen: boolean = false;
  @State private deleting: boolean = false;
  private communityPostId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams;
    if (params.listing) {
      try { this.listing = JSON.parse(params.listing) as SecondhandListing; } catch { this.listing = {}; }
    }
    const communityPostId = Number(params.postId || this.listing.communityPostId || 0);
    this.communityPostId = Number.isSafeInteger(communityPostId) && communityPostId > 0 ? communityPostId : 0;
    this.loadProfile();
    this.load();
  }

  private async loadProfile(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.myAvatar = await storage.getAvatarUrl();
    this.myStudentId = await storage.getStudentId();
    this.myName = await storage.getRealName();
    this.myCollege = await storage.getCollege();
  }

  private async load(notifyFailure: boolean = true, requireReplies: boolean = false): Promise<boolean> {
    this.loading = true;
    try {
      if (this.communityPostId > 0 || this.listing.source === 'community') {
        if (this.communityPostId <= 0) throw new Error('帖子信息不完整');
        const post: CampusWallPost = await CampusWallApi.detail(this.communityPostId);
        if (!post.id || post.id !== this.communityPostId) throw new Error('帖子详情加载失败');
        this.listing = SecondHandBookApi.fromCommunityPost(post);
        this.communityPostId = post.id || this.communityPostId;
        this.book = { title: this.listing.bookTitle, author: this.listing.bookAuthor,
          publisher: this.listing.bookPublisher, edition: this.listing.bookEdition,
          isbn: this.listing.bookIsbn, category: this.listing.major, coverUrl: this.listing.bookCover };
        this.replies = this.listing.replies || [];
        this.loading = false;
        return true;
      }
      const detail: SecondhandDetail = await SecondHandBookApi.detail(this.listing, requireReplies);
      this.book = detail.book || {};
      this.listing = detail.listing || this.listing;
      this.replies = detail.replies || [];
    } catch {
      if (notifyFailure) promptAction.showToast({ message: '详情加载失败', duration: 1400 });
      this.loading = false;
      return false;
    }
    this.loading = false;
    return true;
  }

  private metadata(label: string): string {
    const prefix = `${label}：`;
    const line = (this.listing.note || '').split('\n').find((value: string) => value.startsWith(prefix));
    return line ? line.substring(prefix.length).trim() : '';
  }

  private plainNote(): string {
    return (this.listing.note || '').split('\n').filter((line: string) =>
      !line.startsWith('适用专业：') && !line.startsWith('面交校区：') && !line.startsWith('面交地点：') &&
      !line.startsWith('作者：') && !line.startsWith('出版社：') && !line.startsWith('版次：') &&
      !line.startsWith('ISBN：')).join('\n').trim();
  }

  private title(): string { return this.book.title || this.listing.bookTitle || '未命名书籍'; }
  private author(): string { return this.book.author || this.listing.bookAuthor || this.metadata('作者'); }
  private publisher(): string { return this.book.publisher || this.listing.bookPublisher || this.metadata('出版社'); }
  private edition(): string { return this.book.edition || this.listing.bookEdition || this.metadata('版次'); }
  private isbn(): string { return this.book.isbn || this.listing.bookIsbn || this.metadata('ISBN'); }
  private major(): string { return this.book.category || this.listing.major || this.metadata('适用专业'); }
  private majorItems(): string[] {
    return this.major().split(/[、,，]/).map((value: string) => value.trim()).filter((value: string) => value.length > 0);
  }
  private campus(): string { return this.listing.campusName || this.listing.campus || this.metadata('面交校区'); }
  private sellerName(): string { return this.listing.displayName || this.listing.sellerName || this.listing.realName || this.listing.sellerId || '同学'; }
  private sellerAvatar(): string { return this.listing.avatarUrl || this.listing.sellerAvatar || ''; }
  private isOwnPost(): boolean { return !!this.myStudentId && this.listing.sellerId === this.myStudentId; }

  private async confirmDelete(): Promise<void> {
    if (this.deleting || !this.isOwnPost()) return;
    this.deleting = true;
    try {
      if (this.communityPostId > 0) await CampusWallApi.deletePost(this.communityPostId);
      else await SecondHandBookApi.removeListing(this.listing.id || 0);
      this.deleteDialogOpen = false;
      promptAction.showToast({ message: '帖子已删除', duration: 1200 });
      router.back();
    } catch { promptAction.showToast({ message: '删除失败，请稍后重试', duration: 1500 }); }
    this.deleting = false;
  }

  private dateLabel(value?: number | string): string {
    if (!value) return '';
    const stamp = typeof value === 'number' ? (value < 100000000000 ? value * 1000 : value) : Date.parse(value);
    if (isNaN(stamp)) return String(value);
    const date = new Date(stamp);
    const pad = (number: number): string => number < 10 ? `0${number}` : `${number}`;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private contactParts(): string[] {
    const value = (this.listing.contact || '').trim();
    const separator = value.indexOf('：') >= 0 ? '：' : ':';
    const parts = value.split(separator);
    return parts.length > 1 ? [parts[0].trim(), parts.slice(1).join(separator).trim()] : ['联系方式', value];
  }

  private async copyContact(): Promise<void> {
    const value = this.contactParts()[1];
    if (!value) return;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '联系方式已复制', duration: 1200 });
      this.contactOpen = false;
    } catch { promptAction.showToast({ message: '复制失败，请长按复制', duration: 1400 }); }
  }

  private contactActionLabel(): string {
    const type = this.contactParts()[0].toLowerCase();
    if (type.indexOf('qq') >= 0) return '复制并打开 QQ';
    if (type.indexOf('微信') >= 0 || type.indexOf('wechat') >= 0) return '复制并打开微信';
    if (type.indexOf('手机') >= 0 || type.indexOf('电话') >= 0 || type.indexOf('phone') >= 0) return '复制并打开拨号';
    return '复制并打开对应应用';
  }

  private async copyAndOpenContact(): Promise<void> {
    const parts = this.contactParts();
    const type = parts[0].toLowerCase();
    const value = parts[1];
    if (!value) return;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      await pasteboard.getSystemPasteboard().setData(data);
    } catch {
      promptAction.showToast({ message: '复制失败，请长按号码复制', duration: 1400 });
      return;
    }
    if (type.indexOf('手机') >= 0 || type.indexOf('电话') >= 0 || type.indexOf('phone') >= 0) {
      try {
        await call.makeCall(value);
        this.contactOpen = false;
      } catch { promptAction.showToast({ message: '号码已复制，未能打开拨号界面', duration: 1800 }); }
      return;
    }
    let want: Want;
    if (type.indexOf('微信') >= 0 || type.indexOf('wechat') >= 0) want = { action: 'ohos.want.action.viewData', uri: 'weixin://' };
    else if (type.indexOf('qq') >= 0) want = { action: 'ohos.want.action.viewData', uri: 'mqq://' };
    else {
      promptAction.showToast({ message: '联系方式已复制，请打开对应应用搜索', duration: 1800 });
      this.contactOpen = false;
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await context.startAbility(want);
      this.contactOpen = false;
    } catch {
      promptAction.showToast({ message: '号码已复制，未能打开对应应用', duration: 1800 });
    }
  }

  private async sendReply(): Promise<void> {
    const content = this.replyText.trim();
    if (!content || this.sending) return;
    const isCommunity = this.communityPostId > 0 || this.listing.source === 'community';
    const targetId = isCommunity ? this.communityPostId : Number(this.listing.id || 0);
    if (!Number.isSafeInteger(targetId) || targetId <= 0) {
      promptAction.showToast({ message: '帖子信息不完整，请重新打开后重试', duration: 1600 });
      return;
    }
    this.sending = true;
    try {
      if (isCommunity) await CampusWallApi.reply(targetId, content);
      else await SecondHandBookApi.reply(targetId, content);
      if (this.replyText.trim() === content) {
        this.replyText = '';
        this.replyOpen = false;
      }
      const refreshed = await this.load(false, true);
      promptAction.showToast({ message: refreshed ? '留言成功' : '留言已发送，刷新失败，请稍后重试', duration: 1600 });
    } catch (error) {
      const message = error instanceof Error && error.message ? error.message : '留言发送失败，请稍后重试';
      promptAction.showToast({ message, duration: 1800 });
    } finally {
      this.sending = false;
    }
  }

  @Builder
  private infoRow(label: string, value: string) {
    if (value.trim()) {
      Row() {
        Text(label).width(86).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#999999');
        Text(value).layoutWeight(1).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#555555');
      }.width('100%').margin({ top: 13 })
    }
  }

  @Builder
  private replyItem(reply: SecondhandReply) {
    Row({ space: 14 }) {
      Image(reply.avatarUrl || $r('app.media.ic_default_avatar')).width(50).height(50).borderRadius(25).objectFit(ImageFit.Cover).alignSelf(ItemAlign.Start)
      Column() {
        Row() {
          Text(reply.displayName || reply.realName || reply.studentId || '同学').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#655C86')
          if ((reply.redFlowers || 0) > 0) {
            Image($r('app.media.flower')).width(18).height(18).objectFit(ImageFit.Contain).margin({ left: 7 })
            Text(`${reply.redFlowers}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#B83D5B').margin({ left: 4 })
          }
        }.width('100%')
        if (reply.college || reply.major) { Text(reply.college || reply.major || '').fontSize(14).fontColor('#999999').margin({ top: 2 }) }
        Text(reply.content || '').fontSize(18).fontColor('#333333').lineHeight(28).margin({ top: 12 })
        Text(this.dateLabel(reply.createdAt)).fontSize(14).fontColor('#AAAAAA').margin({ top: 12 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 30, right: 30, top: 20, bottom: 20 }).backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: '#EEEEEE' })
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('‹').fontSize(42).width(48).onClick(() => router.back())
          Text('二手书详情').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 10 })
        }.width('100%').height(82).padding({ left: 14 }).backgroundColor('#F5F6F8')

        Scroll() {
          Column() {
            Column() {
            Row({ space: 14 }) {
              Image(this.sellerAvatar() || $r('app.media.ic_default_avatar')).width(58).height(58).borderRadius(29).objectFit(ImageFit.Cover)
              Column() {
                Row() {
                  Text(this.sellerName()).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#655C86')
                  if ((this.listing.redFlowers || 0) > 0) {
                    Image($r('app.media.flower')).width(18).height(18).objectFit(ImageFit.Contain).margin({ left: 7 })
                    Text(`${this.listing.redFlowers}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#B83D5B').margin({ left: 4 })
                  }
                }
                if (this.listing.college || this.listing.major) { Text(this.listing.college || this.listing.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 }) }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Column() {
                Text(this.dateLabel(this.listing.createdAt)).fontSize(15).fontColor('#999999')
                if (this.isOwnPost()) {
                  Image($r('app.media.more_horiz')).width(28).height(28).margin({ top: 10 })
                    .onClick(() => { this.actionOpen = true; })
                }
              }.alignItems(HorizontalAlign.End).alignSelf(ItemAlign.Start)
            }.width('100%')

            Text(this.title()).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%').margin({ top: 28 })
            Row() {
              Column() { Text('价格').fontSize(16).fontColor('#AAAAAA'); Text(`¥${this.listing.price || 0}`).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#D75C3E').margin({ top: 9 }); }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if ((this.listing.condition || '').trim()) { Column() { Text('品相').fontSize(16).fontColor('#AAAAAA'); Text(SecondHandBookApi.conditionLabel(this.listing.condition)).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 9 }); }.layoutWeight(1).alignItems(HorizontalAlign.Start) }
              if (this.campus()) { Column() { Text('面交校区').fontSize(16).fontColor('#AAAAAA'); Text(this.campus()).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 9 }); }.layoutWeight(1).alignItems(HorizontalAlign.Start) }
            }.width('100%').padding({ top: 24, bottom: 26 }).border({ width: { bottom: 1 }, color: '#EEEEEE' })

            if (this.major()) {
              Text('适用专业').fontSize(22).fontWeight(FontWeight.Bold).width('100%').margin({ top: 26, bottom: 14 })
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.majorItems(), (major: string) => {
                  Text(major).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#555555')
                    .padding({ left: 16, right: 16, top: 10, bottom: 10 }).backgroundColor('#F6F6F9')
                    .borderRadius(8).margin({ right: 8, bottom: 8 })
                }, (major: string) => major)
              }.width('100%')
            }
            if (this.author() || this.publisher() || this.edition() || this.isbn()) {
              Text('书籍资料').fontSize(22).fontWeight(FontWeight.Bold).width('100%').margin({ top: 28 })
              this.infoRow('作者', this.author())
              this.infoRow('出版社', this.publisher())
              this.infoRow('版次', this.edition())
              this.infoRow('ISBN', this.isbn())
            }
            if (this.metadata('面交地点')) {
              Text('面交地点').fontSize(22).fontWeight(FontWeight.Bold).width('100%').margin({ top: 30 })
              Text(this.metadata('面交地点')).fontSize(18).fontColor('#555555').width('100%').margin({ top: 14 })
            }
            if (this.plainNote()) {
              Text('补充说明').fontSize(22).fontWeight(FontWeight.Bold).width('100%').margin({ top: 30 })
              Text(this.plainNote()).fontSize(18).fontColor('#555555').lineHeight(28).width('100%').margin({ top: 14 })
            }
            ForEach(this.listing.images || [], (url: string) => {
              Image(url).width('100%').objectFit(ImageFit.Contain).borderRadius(12).margin({ top: 18 })
            }, (url: string) => url)
            }.width('100%').padding({ left: 28, right: 28, top: 24, bottom: 28 }).backgroundColor(Color.White)

            if (this.replies.length > 0) {
              Text('回复').fontSize(22).fontWeight(FontWeight.Bold).width('100%').padding({ left: 30, top: 20, bottom: 14 }).backgroundColor('#F5F6F8')
              ForEach(this.replies, (reply: SecondhandReply) => { this.replyItem(reply) }, (reply: SecondhandReply) => `${reply.id || reply.createdAt || reply.content}`)
            }
          }.width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)

        Row() {
          Image(this.myAvatar || $r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).objectFit(ImageFit.Cover).margin({ right: 12 })
          Text('留言咨询...').fontSize(18).fontColor('#999999').layoutWeight(1).onClick(() => { this.replyOpen = true; })
          if ((this.listing.contact || '').trim()) {
            Text('联系卖家').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#20C894').onClick(() => { this.contactOpen = true; })
          }
        }.width('92%').height(72).padding({ left: 16, right: 22 }).backgroundColor(Color.White).borderRadius(36).shadow({ radius: 10, color: '#33000000', offsetY: 3 }).margin({ bottom: 16 })
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

      if (this.replyOpen) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => { this.replyOpen = false; })
          Column() {
            TextArea({ placeholder: '请输入留言', text: this.replyText }).width('100%').height(230).fontSize(20).backgroundColor(Color.White).onChange((value: string) => { this.replyText = value; })
            Row() {
              Text('收起').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#777777').layoutWeight(1).textAlign(TextAlign.Center).onClick(() => { this.replyOpen = false; })
              Button(this.sending ? '发送中…' : '发送').width(160).height(52).fontSize(20).fontWeight(FontWeight.Bold).backgroundColor('#20C894').enabled(!this.sending).onClick(() => this.sendReply())
            }.width('100%').margin({ top: 10 })
          }.width('92%').padding(22).backgroundColor(Color.White).borderRadius(22)
        }.width('100%').height('100%')
      }

      if (this.contactOpen) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => { this.contactOpen = false; })
          Column() {
            Text(this.contactParts()[0]).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#444444')
            Text(this.contactParts()[1]).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#666666').margin({ top: 26, bottom: 26 }).copyOption(CopyOptions.LocalDevice)
            Row({ space: 28 }) {
              Button('关闭').width(132).height(52).fontSize(19).fontWeight(FontWeight.Bold).backgroundColor('#E86B55').onClick(() => { this.contactOpen = false; })
              Button('复制').width(132).height(52).fontSize(19).fontWeight(FontWeight.Bold).backgroundColor('#55D600').onClick(() => this.copyContact())
            }
            Button(this.contactActionLabel()).width('100%').height(52).fontSize(18).fontWeight(FontWeight.Bold)
              .backgroundColor('#20C894').margin({ top: 16 }).onClick(() => this.copyAndOpenContact())
          }.width('78%').padding({ left: 26, right: 26, top: 30, bottom: 30 }).backgroundColor(Color.White).borderRadius(24).alignItems(HorizontalAlign.Center)
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%')
  }
}
