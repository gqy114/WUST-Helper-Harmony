import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, CampusWallReply, campusWallExtra, decodeHtmlEntities } from '../../net/CampusWallApi';
import { AppStorage } from '../../store/AppStorage';
import { CampusRichText } from '../../components/CampusRichText';
import { CommunityPostImage } from '../../components/CommunityPostImage';
import { CommunityNavigationStore } from '../../store/CommunityNavigationStore';

interface DetailParams extends Record<string, string> { id: string; }
interface FormattedRun {
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  strike: boolean;
}
interface ReactionOption { type: string; emoji: string; }
const DETAIL_REACTIONS: ReactionOption[] = [
  { type: 'thumbs_up', emoji: '👍' }, { type: 'thumbs_down', emoji: '👎' },
  { type: 'heart', emoji: '❤️' }, { type: 'eyes', emoji: '👀' }, { type: 'rocket', emoji: '🚀' }
];

@Entry
@Component
struct CampusPostDetailPage {
  @State private postId: number = 0;
  @State private post: CampusWallPost = {};
  @State private replyText: string = '';
  @State private loading: boolean = true;
  @State private sending: boolean = false;
  @State private myAvatar: string = '';
  @State private actionOpen: boolean = false;
  @State private actionTarget: string = 'post';
  @State private actionReplyId: number = 0;
  @State private actionReplyName: string = '';
  @State private reactionsOpen: boolean = false;
  @State private favorited: boolean = false;
  @State private reportDialogOpen: boolean = false;
  @State private reportReason: string = '';
  @State private reporting: boolean = false;
  @State private myStudentId: string = '';
  @State private deleteDialogOpen: boolean = false;
  @State private deleting: boolean = false;
  @State private accepting: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams;
    this.postId = Number(params?.id || 0);
    this.load();
    this.loadMyAvatar();
    this.loadIdentity();
    this.loadFavorite();
  }

  private async loadIdentity(): Promise<void> {
    this.myStudentId = await AppStorage.getInstance().getStudentId();
  }

  private isOwnTarget(): boolean {
    if (!this.myStudentId) return false;
    if (this.actionTarget === 'post') return this.post.studentId === this.myStudentId;
    const reply = (this.post.replies || []).find((item: CampusWallReply) => (item.id || 0) === this.actionReplyId);
    return reply?.studentId === this.myStudentId;
  }

  private openDeleteDialog(): void {
    this.actionOpen = false;
    this.deleteDialogOpen = true;
  }

  private async confirmDelete(): Promise<void> {
    if (this.deleting) return;
    this.deleting = true;
    try {
      if (this.actionTarget === 'post') {
        await CampusWallApi.deletePost(this.postId);
        CommunityNavigationStore.getInstance().markCampusPostDeleted(this.postId);
        this.deleteDialogOpen = false;
        promptAction.showToast({ message: '帖子已删除', duration: 1200 });
        router.back();
      } else {
        await CampusWallApi.deleteReply(this.postId, this.actionReplyId);
        this.deleteDialogOpen = false;
        promptAction.showToast({ message: '回复已删除', duration: 1200 });
        await this.load();
      }
    } catch { promptAction.showToast({ message: '删除失败，请稍后重试', duration: 1500 }); }
    this.deleting = false;
  }

  private async loadFavorite(): Promise<void> {
    const raw = await AppStorage.getInstance().getSettingString('campusFavoritePostIds', '[]');
    try { this.favorited = (JSON.parse(raw) as number[]).indexOf(this.postId) >= 0; } catch { this.favorited = false; }
  }

  private openPostActions(): void {
    this.actionTarget = 'post';
    this.actionReplyId = 0;
    this.actionReplyName = '';
    this.actionOpen = true;
  }

  private openReplyActions(reply: CampusWallReply): void {
    this.actionTarget = 'reply';
    this.actionReplyId = reply.id || 0;
    this.actionReplyName = reply.displayName || reply.realName || '同学';
    this.actionOpen = true;
  }

  private async toggleFavorite(): Promise<void> {
    const storage = AppStorage.getInstance();
    const raw = await storage.getSettingString('campusFavoritePostIds', '[]');
    let ids: number[] = [];
    try { ids = JSON.parse(raw) as number[]; } catch {}
    if (ids.indexOf(this.postId) >= 0) ids = ids.filter((id: number) => id !== this.postId);
    else ids.push(this.postId);
    await storage.setSettingString('campusFavoritePostIds', JSON.stringify(ids));
    this.favorited = ids.indexOf(this.postId) >= 0;
    this.actionOpen = false;
    promptAction.showToast({ message: this.favorited ? '已收藏' : '已取消收藏', duration: 1200 });
  }

  private replyToSelected(): void {
    this.replyText = `@${this.actionReplyName} `;
    this.actionOpen = false;
  }

  private isHelpPost(): boolean {
    const value = `${this.post.tag || ''} ${this.post.type || ''} ${this.post.category || ''}`.toLowerCase();
    return value.indexOf('help') >= 0 || value.indexOf('ask') >= 0 || value.indexOf('求助') >= 0;
  }

  private acceptedReplyId(): number {
    const extraId = campusWallExtra(this.post).acceptedReplyId;
    return Number(extraId || this.post.acceptedReplyId || this.post.accepted_reply_id || 0);
  }

  private isResolvedHelpPost(): boolean {
    const status = (this.post.status || '').toLowerCase();
    return this.acceptedReplyId() > 0 || this.post.resolved === true || this.post.isResolved === true ||
      status === 'resolved' || status === 'solved' || status === 'accepted' || status === '已解决';
  }

  private isAcceptedReply(reply: CampusWallReply): boolean {
    const acceptedReplyId = this.acceptedReplyId();
    return (acceptedReplyId > 0 && acceptedReplyId === Number(reply.id || 0)) || reply.accepted === true ||
      reply.isAccepted === true || reply.is_accepted === true;
  }

  private canAcceptSelectedReply(): boolean {
    return this.actionTarget === 'reply' && this.isHelpPost() && !this.isResolvedHelpPost() &&
      this.actionReplyId > 0 && this.myStudentId.length > 0 && this.post.studentId === this.myStudentId;
  }

  private async acceptSelectedReply(): Promise<void> {
    if (!this.canAcceptSelectedReply() || this.accepting) return;
    this.accepting = true;
    this.actionOpen = false;
    try {
      await CampusWallApi.acceptReply(this.postId, this.actionReplyId);
      await this.load();
      promptAction.showToast({ message: '回答已采纳', duration: 1200 });
    } catch {
      promptAction.showToast({ message: '采纳失败，请稍后重试', duration: 1500 });
    }
    this.accepting = false;
  }

  private openReportDialog(): void {
    this.actionOpen = false;
    this.reportReason = '';
    this.reportDialogOpen = true;
  }

  private async submitReport(): Promise<void> {
    if (this.reporting) return;
    this.reporting = true;
    try {
      await CampusWallApi.report(this.actionTarget, this.actionTarget === 'post' ? this.postId : this.actionReplyId,
        this.reportReason.trim() || '不当内容');
      this.reportDialogOpen = false;
      promptAction.showToast({ message: '举报已提交', duration: 1200 });
    } catch { promptAction.showToast({ message: '举报失败，请稍后重试', duration: 1500 }); }
    this.reporting = false;
  }

  private async react(type: string): Promise<void> {
    try {
      await CampusWallApi.toggleReaction(this.postId, type);
      await this.load();
    } catch { promptAction.showToast({ message: '当前帖子暂不支持表态', duration: 1200 }); }
  }

  private reactionCount(type: string): number { return this.post.reactions?.[type] || 0; }
  private reactedByMe(type: string): boolean { return (this.post.myReactions || []).indexOf(type) >= 0; }

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

  private formattedContent(value: string | undefined): FormattedRun[] {
    const source = decodeHtmlEntities(value || '');
    const runs: FormattedRun[] = [];
    const tagPattern = /<[^>]+>/g;
    let boldDepth = 0;
    let italicDepth = 0;
    let underlineDepth = 0;
    let strikeDepth = 0;
    let cursor = 0;
    let match: RegExpExecArray | null = tagPattern.exec(source);
    const append = (text: string): void => {
      if (!text) return;
      const last = runs.length > 0 ? runs[runs.length - 1] : undefined;
      const bold = boldDepth > 0;
      const italic = italicDepth > 0;
      const underline = underlineDepth > 0;
      const strike = strikeDepth > 0;
      if (last && last.bold === bold && last.italic === italic && last.underline === underline && last.strike === strike) {
        last.text += text;
      } else {
        runs.push({ text, bold, italic, underline, strike });
      }
    };
    while (match) {
      append(source.substring(cursor, match.index));
      const tag = match[0].toLowerCase();
      const closing = tag.startsWith('</');
      if (/^<\/?(?:b|strong)\b/.test(tag)) boldDepth = Math.max(0, boldDepth + (closing ? -1 : 1));
      else if (/^<\/?(?:i|em)\b/.test(tag)) italicDepth = Math.max(0, italicDepth + (closing ? -1 : 1));
      else if (/^<\/?u\b/.test(tag)) underlineDepth = Math.max(0, underlineDepth + (closing ? -1 : 1));
      else if (/^<\/?(?:s|strike)\b/.test(tag)) strikeDepth = Math.max(0, strikeDepth + (closing ? -1 : 1));
      else if (/^<br\b/.test(tag) || /^<\/?(?:p|div)\b/.test(tag)) append('\n');
      cursor = match.index + match[0].length;
      match = tagPattern.exec(source);
    }
    append(source.substring(cursor));
    if (runs.length === 0) runs.push({ text: source, bold: false, italic: false, underline: false, strike: false });
    runs[0].text = runs[0].text.replace(/^\s+/, '');
    runs[runs.length - 1].text = runs[runs.length - 1].text.replace(/\s+$/, '');
    return runs.filter((run: FormattedRun) => run.text.length > 0);
  }

  @Builder
  private formattedBody() {
    CampusRichText({ content: this.post.content || '', fontSize: 20, textColor: '#444444', lineHeight: 32 })
      .margin({ top: 18 })
  }

  private lostNoticeLabel(): string {
    const value = (campusWallExtra(this.post).type || this.post.noticeType || this.post.type || this.post.category || '').toLowerCase();
    return value === 'found' || value.indexOf('招领') >= 0 || value.indexOf('拾') >= 0 ? '失物招领' : '寻物启事';
  }

  private lostAddress(): string {
    return (campusWallExtra(this.post).address || this.post.address || '').trim();
  }

  private isLostFoundPost(): boolean {
    const tag = (this.post.tag || '').toLowerCase();
    const value = `${tag} ${this.post.type || ''} ${this.post.category || ''} ${this.post.noticeType || ''}`.toLowerCase();
    return value.indexOf('lost') >= 0 || value.indexOf('found') >= 0 || value.indexOf('寻物') >= 0 || value.indexOf('招领') >= 0 || this.lostAddress().length > 0;
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
        Image($r('app.media.more_horiz')).width(27).height(27).margin({ top: 12 }).onClick(() => this.openPostActions())
      }.alignItems(HorizontalAlign.End)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private postImage(url: string) {
    CommunityPostImage({ src: url }).margin({ top: 14 })
  }

  @Builder
  private replyItem(reply: CampusWallReply) {
    Row() {
      Image(reply.avatarUrl || $r('app.media.ic_default_avatar'))
        .width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 14 })
      Column() {
        Row() {
          Row() {
            Text(reply.displayName || reply.realName || '同学')
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#655C86').maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if ((reply.redFlowers || 0) > 0) {
              Row() {
                Image($r('app.media.flower')).width(18).height(18).objectFit(ImageFit.Contain)
                Text(`${reply.redFlowers}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#B83D5B').margin({ left: 4 })
              }.height(28).padding({ left: 7, right: 8 }).backgroundColor('#FFF0F2').borderRadius(14).margin({ left: 8 })
            }
          }.layoutWeight(1)
          if (this.isAcceptedReply(reply)) {
            Text('已采纳').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#16B889')
              .backgroundColor('#E9FAF5').borderRadius(16)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).margin({ right: 10 })
          }
          Image($r('app.media.more_horiz')).width(24).height(24).onClick(() => this.openReplyActions(reply))
        }.width('100%')
        Text(reply.college || reply.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 })
        CampusRichText({ content: reply.content || '', fontSize: 19, textColor: '#333333', lineHeight: 29 }).margin({ top: 16 })
        ForEach(reply.images || [], (url: string) => {
          this.postImage(url)
        }, (url: string) => url)
        Text(this.dateLabel(reply.createdAt)).fontSize(15).fontColor('#AAAAAA').margin({ top: 14 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
      .padding({ left: 28, right: 28, top: 22, bottom: 24 }).backgroundColor(Color.White)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
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
              this.formattedBody()
              if (this.isLostFoundPost()) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  if (this.lostAddress()) {
                    Text(this.lostAddress()).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#18B98C')
                      .backgroundColor('#E9FAF5').borderRadius(20)
                      .padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ right: 10, bottom: 8 });
                  }
                  Text(this.lostNoticeLabel()).fontSize(17).fontWeight(FontWeight.Bold)
                    .fontColor(this.lostNoticeLabel() === '失物招领' ? '#27865D' : '#B44F70')
                    .backgroundColor(this.lostNoticeLabel() === '失物招领' ? '#E7F8E9' : '#FFF0F2')
                    .borderRadius(20).padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ bottom: 8 });
                }.width('100%').margin({ top: 16 })
              }
              if (this.isHelpPost()) {
                Text(this.isResolvedHelpPost() ? '已采纳答案' : '等待答案')
                  .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#18B98C')
                  .backgroundColor('#E9FAF5').borderRadius(20)
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 16 })
              }
              ForEach(this.post.images || [], (url: string) => {
                this.postImage(url)
              }, (url: string) => url)
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
                Blank().layoutWeight(1)
                ForEach(DETAIL_REACTIONS, (option: ReactionOption) => {
                  if (this.reactionsOpen || this.reactionCount(option.type) > 0) {
                    Text(`${option.emoji}${this.reactionCount(option.type) > 0 ? ` ${this.reactionCount(option.type)}` : ''}`)
                      .fontSize(22).fontColor('#655C86').padding({ left: 12, right: 12, top: 7, bottom: 7 })
                      .backgroundColor(this.reactedByMe(option.type) ? '#CDEFE4' : '#ECF8F4').borderRadius(20)
                      .margin({ left: 7, bottom: 6 }).onClick(() => this.react(option.type))
                  }
                }, (option: ReactionOption) => option.type)
                if (!this.reactionsOpen) {
                  Image($r('app.media.more_horiz')).width(48).height(30).padding({ left: 10, right: 10 })
                    .backgroundColor('#ECF8F4').borderRadius(20).onClick(() => { this.reactionsOpen = true; })
                }
              }.width('100%').margin({ top: 18 })
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
    if (this.actionOpen) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => { this.actionOpen = false; })
      Column() {
        Row() {
          Text('操作').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#222222').layoutWeight(1)
          Text('×').fontSize(32).fontWeight(FontWeight.Bold).fontColor('#555555').width(52).height(52)
            .textAlign(TextAlign.Center).backgroundColor('#F5F5F5').borderRadius(26).onClick(() => { this.actionOpen = false; })
        }.width('100%')
        Row() {
          if (this.actionTarget === 'post') {
            Column() {
              Image(this.favorited ? $r('app.media.star_shine') : $r('app.media.star'))
                .width(82).height(82).padding(20).objectFit(ImageFit.Contain)
                .backgroundColor('#F7F7F7').borderRadius(18)
              Text(this.favorited ? '取消收藏' : '收藏').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
            }.margin({ right: 22 }).onClick(() => this.toggleFavorite())
          } else if (this.canAcceptSelectedReply()) {
            Column() {
              Image($r('app.media.checked_circle')).width(82).height(82).padding(20).objectFit(ImageFit.Contain)
                .backgroundColor('#F7F7F7').borderRadius(18)
              Text(this.accepting ? '采纳中' : '采纳').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
            }.margin({ right: 22 }).onClick(() => this.acceptSelectedReply())
          } else {
            Column() {
              Image($r('app.media.reply')).width(82).height(82).padding(20).objectFit(ImageFit.Contain)
                .backgroundColor('#F7F7F7').borderRadius(18)
              Text('回复').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
            }.margin({ right: 22 }).onClick(() => this.replyToSelected())
          }
          if (this.isOwnTarget()) {
            Column() {
              Image($r('app.media.delete')).width(82).height(82).padding(20).objectFit(ImageFit.Contain)
                .backgroundColor('#F7F7F7').borderRadius(18)
              Text('删除').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#D9534F').margin({ top: 10 })
            }.margin({ right: 22 }).onClick(() => this.openDeleteDialog())
          }
          Column() {
            Image($r('app.media.flag')).width(82).height(82).padding(20).objectFit(ImageFit.Contain)
              .backgroundColor('#F7F7F7').borderRadius(18)
            Text('举报').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
          }.onClick(() => this.openReportDialog())
        }.width('100%').margin({ top: 24 })
      }.width('100%').height(310).padding({ left: 28, right: 28, top: 28 }).backgroundColor(Color.White)
        .borderRadius({ topLeft: 28, topRight: 28 })
    }
    if (this.deleteDialogOpen) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height('100%').backgroundColor('#66000000')
        Column() {
          Text(this.actionTarget === 'post' ? '删除这条帖子？' : '删除这条回复？')
            .fontSize(25).fontWeight(FontWeight.Bold).fontColor('#333333')
          Text('删除后无法恢复').fontSize(17).fontColor('#999999').margin({ top: 14, bottom: 28 })
          Row() {
            Button('取消').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
              .width('42%').height(54).backgroundColor('#F0F0F0').borderRadius(9)
              .onClick(() => { this.deleteDialogOpen = false; })
            Button(this.deleting ? '删除中' : '删除').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .width('42%').height(54).backgroundColor('#E35D5B').borderRadius(9).margin({ left: 18 })
              .onClick(() => this.confirmDelete())
          }.justifyContent(FlexAlign.Center)
        }.width('82%').padding({ left: 24, right: 24, top: 30, bottom: 28 })
          .backgroundColor(Color.White).borderRadius(24).alignItems(HorizontalAlign.Center)
      }.width('100%').height('100%')
    }
    if (this.reportDialogOpen) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height('100%').backgroundColor('#66000000')
        Column() {
          Text('举报这条内容？').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#444444')
            .width('100%').textAlign(TextAlign.Center).margin({ bottom: 24 })
          TextArea({ placeholder: '请输入举报原因（可选）', text: this.reportReason })
            .width('82%').height(110).fontSize(18).fontColor('#444444').placeholderColor('#AAAAAA')
            .backgroundColor('#F5F5F5').borderRadius(14).padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .onChange((value: string) => { this.reportReason = value; })
          Row() {
            Button('取消').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .width('42%').height(54).backgroundColor('#E66D57').borderRadius(9)
              .onClick(() => { this.reportDialogOpen = false; })
            Button(this.reporting ? '提交中' : '举报').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .width('42%').height(54).backgroundColor('#58D900').borderRadius(9).margin({ left: 28 })
              .enabled(!this.reporting).onClick(() => this.submitReport())
          }.width('82%').margin({ top: 26 })
        }.width('82%').padding({ top: 28, bottom: 30 }).backgroundColor(Color.White).borderRadius(24)
      }.width('100%').height('100%')
    }
    }
  }
}
