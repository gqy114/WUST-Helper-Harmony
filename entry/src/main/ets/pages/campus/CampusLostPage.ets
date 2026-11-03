import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, campusWallExtra, campusWallRelativeTime } from '../../net/CampusWallApi';
import { CampusRichText } from '../../components/CampusRichText';
import { CommunityPostImagePreview } from '../../components/CommunityPostImagePreview';

@Entry @Component
struct CampusLostPage {
  @State private posts: CampusWallPost[] = [];
  @State private avatarUrl: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private currentPage: number = 1;
  @State private hasMore: boolean = true;
  private readonly pageSize: number = 20;
  @State private searching: boolean = false;
  @State private query: string = "";
  @State private filterOpen: boolean = false;
  @State private pendingFilter: string = "全部";
  @State private activeFilter: string = "全部";

  private async loadAvatar(): Promise<void> { this.avatarUrl = await AppStorage.getInstance().getAvatarUrl(); }
  aboutToAppear(): void { this.load(); this.loadAvatar(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.currentPage = 1;
    this.hasMore = true;
    try {
      const firstPage = await CampusWallApi.list(1, 'lost');
      this.posts = firstPage;
      this.hasMore = firstPage.length >= this.pageSize;
    }
    catch { promptAction.showToast({ message: '失物信息加载失败', duration: 1500 }); }
    this.loading = false;
  }
  private appendUniquePosts(current: CampusWallPost[], incoming: CampusWallPost[]): CampusWallPost[] {
    const result = current.slice();
    const ids: number[] = result.map((post: CampusWallPost) => post.id || 0);
    incoming.forEach((post: CampusWallPost) => {
      const id = post.id || 0;
      if (id === 0 || ids.indexOf(id) < 0) {
        result.push(post);
        if (id > 0) ids.push(id);
      }
    });
    return result;
  }
  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore) return;
    this.loadingMore = true;
    const nextPage = this.currentPage + 1;
    try {
      const nextPosts = await CampusWallApi.list(nextPage, 'lost');
      this.posts = this.appendUniquePosts(this.posts, nextPosts);
      this.currentPage = nextPage;
      this.hasMore = nextPosts.length >= this.pageSize;
    } catch { promptAction.showToast({ message: '加载更多失败', duration: 1200 }); }
    this.loadingMore = false;
  }
  private matchScore(post: CampusWallPost): number { const q = this.query.trim().toLowerCase(); if (!q) return 1; const text = `${post.title || ""}${post.content || ""}${post.displayName || ""}${post.realName || ""}${post.college || ""}`.toLowerCase(); let score = 0; for (let i = 0; i < q.length; i++) { if (text.includes(q.charAt(i))) score++; } return score; }
  private async toggleLike(post: CampusWallPost): Promise<void> {
    if (!post.id) return;
    try {
      const added = await CampusWallApi.toggleReaction(post.id);
      post.likeCount = Math.max(0, (post.likeCount || 0) + (added ? 1 : -1));
      this.posts = this.posts.slice();
    } catch { promptAction.showToast({ message: '操作失败，请稍后重试', duration: 1200 }); }
  }
  private filterMatch(post: CampusWallPost): boolean { return this.activeFilter === '全部' || this.noticeLabel(post) === this.activeFilter; }
  private noticeLabel(post: CampusWallPost): string {
    const value = (campusWallExtra(post).type || post.noticeType || post.type || post.category || '').toLowerCase();
    return value === 'found' || value.indexOf('招领') >= 0 || value.indexOf('拾') >= 0 ? '失物招领' : '寻物启事';
  }
  private addressLabel(post: CampusWallPost): string {
    return (campusWallExtra(post).address || post.address || '').trim();
  }
  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back());
        Text('失物招领').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 });
        Blank().layoutWeight(1); Row() { Image($r('app.media.filter')).width(24).height(24).margin({ right: 14 }).onClick(() => { this.pendingFilter = this.activeFilter; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = true; }); }); Image($r('app.media.search')).width(24).height(24).margin({ right: 18 }).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = true; }); }); }.height(48).alignItems(VerticalAlign.Center); Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover);
      }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      if (this.filterOpen) {
        Column() {
          Text('选择类型').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555').margin({ bottom: 8 });
          Row() { ForEach(['失物招领', '寻物启事', '全部'], (item: string) => { Text(item).fontSize(18).fontColor(this.pendingFilter === item ? '#20C894' : '#777777').backgroundColor(this.pendingFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(20).padding({ left: 18, right: 18, top: 9, bottom: 9 }).margin({ right: 10 }).onClick(() => { this.pendingFilter = item; }); }) }.width('100%');
          Row() { Text('取消').fontSize(17).fontColor('#999999').layoutWeight(1).textAlign(TextAlign.Start).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); Text('确定').fontSize(17).fontColor('#20C894').textAlign(TextAlign.End).onClick(() => { this.activeFilter = this.pendingFilter; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); }.width('100%').margin({ top: 12 });
        }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 12 }).transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 0, y: -120 }))).animation({ duration: 260, curve: Curve.EaseInOut });
      }
      if (this.searching) {
        Row() { Text('⌕').fontSize(30).fontColor('#555555'); TextInput({ placeholder: '搜索当前板块', text: this.query }).layoutWeight(1).fontSize(20).onChange((value: string) => { this.query = value; }); Text('×').fontSize(32).fontColor('#777777').onClick(() => { this.query = ''; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = false; }); }); }.width('92%').height(58).padding({ left: 16, right: 14 }).backgroundColor(Color.White).borderRadius(30).margin({ bottom: 12 });
      }
      List() {
        if (this.loading) { ListItem() { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); } }
        else if (this.posts.filter((post: CampusWallPost) => this.filterMatch(post) && this.matchScore(post) > 0).length === 0) { ListItem() { Text('暂无失物信息').fontSize(18).fontColor('#999999').margin({ top: 36 }); } }
        else { ForEach(this.posts.filter((post: CampusWallPost) => this.filterMatch(post) && this.matchScore(post) > 0).sort((a: CampusWallPost, b: CampusWallPost) => this.matchScore(b) - this.matchScore(a)), (post: CampusWallPost) => { ListItem() {
          Column() {
            Row() {
              if (post.avatarUrl) { Image(post.avatarUrl).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); }
              Column() { Text(post.displayName || post.realName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86'); Text(post.college || post.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1);
              Column() {
                Text(this.noticeLabel(post)).fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor(this.noticeLabel(post) === '失物招领' ? '#27865D' : '#B44F70')
                  .backgroundColor(this.noticeLabel(post) === '失物招领' ? '#E7F8E9' : '#FFF0F2')
                  .borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 });
                if (this.addressLabel(post)) {
                  Text(this.addressLabel(post)).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#666666')
                    .textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: 180 })
                    .backgroundColor('#F4F4F5').borderRadius(18)
                    .padding({ left: 14, right: 14, top: 7, bottom: 7 }).margin({ top: 7 });
                }
              }.alignItems(HorizontalAlign.End);
            }.width('100%');
            if (post.title) { CampusRichText({ content: post.title, fontSize: 22, textColor: '#222222', baseBold: true, lineHeight: 30 }); }
            CampusRichText({ content: post.content || '', fontSize: 18, textColor: '#333333', lineHeight: 28 });
            if (post.images && post.images.length > 0) { CommunityPostImagePreview({ images: post.images }).margin({ top: 12 }); }
            Row() { Text(campusWallRelativeTime(post.createdAt)).fontSize(16).fontColor('#AAAAAA').layoutWeight(1); Text(`评论 ${post.replyCount || 0}`).fontSize(16).fontColor('#999999').margin({ left: 20 }); }.margin({ top: 18 });
          }.width('100%').padding({ left: 34, right: 34, top: 22, bottom: 24 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' }).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPostDetailPage', params: { id: String(post.id || 0) } })); }
        }, (post: CampusWallPost) => `${post.id || post.createdAt || post.content}`); }
        if (!this.loading && this.posts.length > 0) { ListItem() { Row() { if (this.loadingMore) { LoadingProgress().width(22).height(22).color('#20C894'); Text('正在加载更多…').fontSize(15).fontColor('#888888').margin({ left: 8 }); } else if (!this.hasMore) { Text('已经到底了').fontSize(15).fontColor('#AAAAAA'); } }.width('100%').height(54).justifyContent(FlexAlign.Center); } }
      }.width('100%').layoutWeight(1).backgroundColor('#F5F6F7').onReachEnd(() => this.loadMore());
      Row() { Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('发布失物招领...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'lost', label: '发布失物招领' } })).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 });
    }.width('100%').height('100%').backgroundColor('#F5F6F7');
  }
}




