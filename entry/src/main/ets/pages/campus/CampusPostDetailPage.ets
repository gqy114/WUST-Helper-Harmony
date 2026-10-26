import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, CampusWallReply, decodeHtmlEntities } from '../../net/CampusWallApi';
import { AppStorage } from '../../store/AppStorage';

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

  aboutToAppear(): void {
    const params = router.getParams() as DetailParams;
    this.postId = Number(params?.id || 0);
    this.load();
    this.loadMyAvatar();
    this.loadFavorite();
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

  private async confirmReport(): Promise<void> {
    const result = await promptAction.showDialog({
      title: '举报内容', message: '确认举报这条内容吗？',
      buttons: [{ text: '取消', color: '#777777' }, { text: '举报', color: '#D9534F' }]
    });
    if (result.index !== 1) return;
    try {
      await CampusWallApi.report(this.actionTarget, this.actionTarget === 'post' ? this.postId : this.actionReplyId, '不当内容');
      this.actionOpen = false;
      promptAction.showToast({ message: '举报已提交', duration: 1200 });
    } catch { promptAction.showToast({ message: '举报失败，请稍后重试', duration: 1500 }); }
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
    Text() {
      ForEach(this.formattedContent(this.post.content), (run: FormattedRun) => {
        Span(run.text).fontWeight(run.bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
          .decoration({ type: run.underline ? TextDecorationType.Underline :
            (run.strike ? TextDecorationType.LineThrough : TextDecorationType.None) })
      }, (run: FormattedRun, index: number) => `${index}-${run.text}`)
    }.width('100%').fontSize(20).fontColor('#444444').lineHeight(32).margin({ top: 18 })
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
    Image(url).width('100%').height(280).objectFit(ImageFit.Contain).margin({ top: 14 })
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
          Image($r('app.media.more_horiz')).width(24).height(24).onClick(() => this.openReplyActions(reply))
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
              Text(this.favorited ? '★' : '☆').fontSize(42).width(82).height(82).textAlign(TextAlign.Center).backgroundColor('#F7F7F7').borderRadius(18)
              Text(this.favorited ? '取消收藏' : '收藏').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
            }.margin({ right: 22 }).onClick(() => this.toggleFavorite())
          } else {
            Column() {
              Text('↩').fontSize(42).width(82).height(82).textAlign(TextAlign.Center).backgroundColor('#F7F7F7').borderRadius(18)
              Text('回复').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
            }.margin({ right: 22 }).onClick(() => this.replyToSelected())
          }
          Column() {
            Text('⚑').fontSize(42).width(82).height(82).textAlign(TextAlign.Center).backgroundColor('#F7F7F7').borderRadius(18)
            Text('举报').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
          }.onClick(() => this.confirmReport())
        }.width('100%').margin({ top: 24 })
      }.width('100%').height(310).padding({ left: 28, right: 28, top: 28 }).backgroundColor(Color.White)
        .borderRadius({ topLeft: 28, topRight: 28 })
    }
    }
  }
}
