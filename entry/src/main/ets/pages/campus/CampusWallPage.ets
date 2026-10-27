import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, campusWallRelativeTime } from '../../net/CampusWallApi';
import { CampusRichText } from '../../components/CampusRichText';

interface WallReactionOption { type: string; emoji: string; }
const WALL_REACTIONS: WallReactionOption[] = [
  { type: 'thumbs_up', emoji: '👍' }, { type: 'thumbs_down', emoji: '👎' },
  { type: 'heart', emoji: '❤️' }, { type: 'eyes', emoji: '👀' }, { type: 'rocket', emoji: '🚀' }
];

@Entry @Component
struct CampusWallPage {
  @State private posts: CampusWallPost[] = [];
  @State private avatarUrl: string = '';
  @State private searching: boolean = false;
  @State private query: string = '';
  @State private loading: boolean = true;
  @State private filterOpen: boolean = false;
  @State private pendingCollegeFilter: string = '全部';
  @State private activeCollegeFilter: string = '全部';
  @State private selfCollege: string = '';
  private async loadProfile(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.avatarUrl = await storage.getAvatarUrl();
    this.selfCollege = (await storage.getCollege()).trim();
  }
  aboutToAppear(): void { this.load(); this.loadProfile(); }
  private async load(): Promise<void> { this.loading = true; try { this.posts = await CampusWallApi.list(); } catch { promptAction.showToast({ message: '校园墙信息加载失败', duration: 1500 }); } this.loading = false; }
  private reactionCount(post: CampusWallPost, type: string): number { return post.reactions?.[type] || 0; }
  private matchScore(post: CampusWallPost): number { const q = this.query.trim().toLowerCase(); if (!q) return 1; const text = `${post.title || ""}${post.content || ""}${post.displayName || ""}${post.realName || ""}${post.college || ""}`.toLowerCase(); let score = 0; for (let i = 0; i < q.length; i++) { if (text.includes(q.charAt(i))) score++; } return score; }
  private collegeMatch(post: CampusWallPost): boolean {
    if (this.activeCollegeFilter === '全部') return true;
    const mine = this.selfCollege.replace(/\s/g, '');
    const college = (post.college || '').trim().replace(/\s/g, '');
    if (!mine || !college) return false;
    const same = college === mine || college.indexOf(mine) >= 0 || mine.indexOf(college) >= 0;
    return this.activeCollegeFilter === '同学院' ? same : !same;
  }
  private visiblePosts(): CampusWallPost[] {
    return this.posts.filter((post: CampusWallPost) => this.collegeMatch(post) && this.matchScore(post) > 0)
      .sort((a: CampusWallPost, b: CampusWallPost) => this.matchScore(b) - this.matchScore(a));
  }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('校园墙').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 }); Blank().layoutWeight(1); Row() { Image($r('app.media.filter')).width(24).height(24).margin({ right: 14 }).alignSelf(ItemAlign.Center).onClick(() => { this.pendingCollegeFilter = this.activeCollegeFilter; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = true; }); }); Image($r('app.media.search')).width(24).height(24).margin({ right: 18 }).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = true; }); }); }.height(48).alignItems(VerticalAlign.Center); Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover).alignSelf(ItemAlign.Center); }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      if (this.filterOpen) {
        Column() {
          Text('选择学院范围').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555').width('100%').margin({ bottom: 8 });
          Row() {
            ForEach(['同学院', '不同学院', '全部'], (item: string) => {
              Text(item).fontSize(18).fontColor(this.pendingCollegeFilter === item ? '#20C894' : '#777777')
                .backgroundColor(this.pendingCollegeFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(20)
                .padding({ left: 18, right: 18, top: 9, bottom: 9 }).margin({ right: 10 })
                .onClick(() => { this.pendingCollegeFilter = item; });
            })
          }.width('100%');
          Row() {
            Text('取消').fontSize(17).fontColor('#999999').layoutWeight(1).textAlign(TextAlign.Start)
              .onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); });
            Text('确定').fontSize(17).fontColor('#20C894').textAlign(TextAlign.End).onClick(() => {
              this.activeCollegeFilter = this.pendingCollegeFilter;
              animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; });
            });
          }.width('100%').margin({ top: 12 });
        }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 12 })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 0, y: -120 })))
          .animation({ duration: 260, curve: Curve.EaseInOut });
      }
      if (this.searching) { Row() { Text('⌕').fontSize(30).fontColor('#555555'); TextInput({ placeholder: '搜索当前板块', text: this.query }).layoutWeight(1).fontSize(20).onChange((value: string) => { this.query = value; }); Text('×').fontSize(32).fontColor('#777777').onClick(() => { this.query = ''; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = false; }); }); }.width('92%').height(58).padding({ left: 16, right: 14 }).backgroundColor(Color.White).borderRadius(30).margin({ bottom: 12 }); }
      Scroll() { Column() {
        if (this.loading) { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        else if (this.visiblePosts().length === 0) { Text('暂无符合条件的校园墙信息').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        else { ForEach(this.visiblePosts(), (post: CampusWallPost) => Column() {
          Row() { if (post.avatarUrl) { Image(post.avatarUrl).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } Column() { Text(post.displayName || post.realName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86'); Text(post.college || post.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text((post.replyCount || 0) > 0 ? `${post.replyCount} 个回复` : '暂无回复').fontSize(15).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }); }.width('100%');
          if (post.title) { CampusRichText({ content: post.title, fontSize: 22, textColor: '#222222', baseBold: true, lineHeight: 30 }); }
          CampusRichText({ content: post.content || '', fontSize: 18, textColor: '#333333', lineHeight: 28 }); if (post.images && post.images.length > 0) { ForEach(post.images, (image: string) => { Image(image).width('100%').height(190).objectFit(ImageFit.Cover).borderRadius(10).margin({ top: 12 }); }); }
          Text(campusWallRelativeTime(post.createdAt)).fontSize(16).fontColor('#AAAAAA').margin({ top: 10 });
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(WALL_REACTIONS, (option: WallReactionOption) => {
              if (this.reactionCount(post, option.type) > 0) {
                Text(`${option.emoji} ${this.reactionCount(post, option.type)}`).fontSize(18).fontColor('#655C86')
                  .padding({ left: 11, right: 11, top: 6, bottom: 6 }).backgroundColor('#ECF8F4')
                  .borderRadius(18).margin({ right: 7, top: 8 })
              }
            }, (option: WallReactionOption) => option.type)
          }.width('100%')
        }.width('100%').padding({ left: 34, right: 34, top: 20, bottom: 22 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' }).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPostDetailPage', params: { id: String(post.id || 0) } })), (post: CampusWallPost) => `${post.id || post.createdAt || post.content}`); }
      }.width('100%').backgroundColor('#F5F6F8'); }.layoutWeight(1);
      Row() { Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('分享新鲜事...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 }).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'wall', label: '发布新鲜事' } }));
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}




