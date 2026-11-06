import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, campusWallExtra, campusWallRelativeTime } from '../../net/CampusWallApi';
import { CampusRichText } from '../../components/CampusRichText';
import { CommunityPostImagePreview } from '../../components/CommunityPostImagePreview';

@Entry @Component
struct CampusHelpPage {
  @State private posts: CampusWallPost[] = [];
  @State private avatarUrl: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private currentPage: number = 1;
  @State private hasMore: boolean = true;
  private readonly pageSize: number = 20;
  // 每次刷新递增；旧的分页/首屏响应只有在代次未变时才允许写回列表和页码。
  private requestGeneration: number = 0;
  @State private searching: boolean = false;
  @State private query: string = "";
  @State private filterOpen: boolean = false;
  @State private pendingCollegeFilter: string = "全部";
  @State private pendingStatusFilter: string = "全部";
  @State private activeCollegeFilter: string = "全部";
  @State private activeStatusFilter: string = "全部";
  @State private selfCollege: string = "";
  private async loadAvatar(): Promise<void> { this.avatarUrl = await AppStorage.getInstance().getAvatarUrl(); }
  aboutToAppear(): void { this.loadAvatar(); }
  onPageShow(): void { this.load(); }
  private async load(): Promise<void> {
    const generation = ++this.requestGeneration;
    this.loading = true;
    this.loadingMore = false;
    this.posts = [];
    this.currentPage = 1;
    this.hasMore = true;
    try { this.selfCollege = await AppStorage.getInstance().getCollege(); } catch {}
    if (generation !== this.requestGeneration) return;
    try {
      const firstPage = await CampusWallApi.list(1, 'help');
      if (generation !== this.requestGeneration) return;
      this.posts = firstPage;
      this.hasMore = firstPage.length >= this.pageSize;
    } catch {
      if (generation !== this.requestGeneration) return;
      promptAction.showToast({ message: '求助信息加载失败', duration: 1500 });
    }
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
    const generation = this.requestGeneration;
    this.loadingMore = true;
    const nextPage = this.currentPage + 1;
    try {
      const nextPosts = await CampusWallApi.list(nextPage, 'help');
      if (generation !== this.requestGeneration) return;
      this.posts = this.appendUniquePosts(this.posts, nextPosts);
      this.currentPage = nextPage;
      this.hasMore = nextPosts.length >= this.pageSize;
    } catch {
      if (generation !== this.requestGeneration) return;
      promptAction.showToast({ message: '加载更多失败', duration: 1200 });
    }
    this.loadingMore = false;
  }
  private matchScore(post: CampusWallPost): number { const q = this.query.trim().toLowerCase(); if (!q) return 1; const text = `${post.title || ""}${post.content || ""}${post.displayName || ""}${post.realName || ""}${post.college || ""}`.toLowerCase(); let score = 0; for (let i = 0; i < q.length; i++) { if (text.includes(q.charAt(i))) score++; } return score; }
  private filterMatch(post: CampusWallPost): boolean {
    const same: boolean = this.selfCollege.length > 0 && (post.college || '').includes(this.selfCollege);
    const collegeOk: boolean = this.activeCollegeFilter === '全部' || (this.activeCollegeFilter === '同学院' ? same : !same);
    const resolved: boolean = this.isResolved(post);
    const statusOk: boolean = this.activeStatusFilter === '全部' || (this.activeStatusFilter === '已解决' ? resolved : !resolved);
    return collegeOk && statusOk;
  }
  private isResolved(post: CampusWallPost): boolean {
    const status = (post.status || '').toLowerCase();
    const acceptedReplyId = Number(campusWallExtra(post).acceptedReplyId || 0);
    return acceptedReplyId > 0 || post.resolved === true || post.isResolved === true || status === 'resolved' || status === 'solved' || status === '已解决';
  }
  private sortedPosts(): CampusWallPost[] {
    return this.posts.filter((post: CampusWallPost) => this.filterMatch(post) && this.matchScore(post) > 0).sort((a: CampusWallPost, b: CampusWallPost) => {
      const statusOrder: number = (this.isResolved(a) ? 1 : 0) - (this.isResolved(b) ? 1 : 0);
      if (statusOrder !== 0) return statusOrder;
      const aTime: number = Date.parse(a.createdAt || '') || 0;
      const bTime: number = Date.parse(b.createdAt || '') || 0;
      return bTime - aTime;
    });
  }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('求助').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 }); Blank().layoutWeight(1); Row() { Image($r('app.media.filter')).width(24).height(24).margin({ right: 14 }).onClick(() => { this.pendingCollegeFilter = this.activeCollegeFilter; this.pendingStatusFilter = this.activeStatusFilter; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = true; }); }); Image($r('app.media.search')).width(24).height(24).margin({ right: 18 }).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = true; }); }); }.height(48).alignItems(VerticalAlign.Center); Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover).alignSelf(ItemAlign.Center); }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      if (this.filterOpen) {
        Column() {
          Row() { Text('学院').fontSize(16).fontColor('#777777').width(52); ForEach(['同学院', '不同学院', '全部'], (item: string) => { Text(item).fontSize(16).fontColor(this.pendingCollegeFilter === item ? '#20C894' : '#777777').backgroundColor(this.pendingCollegeFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(18).padding({ left: 10, right: 10, top: 8, bottom: 8 }).margin({ right: 8 }).onClick(() => { this.pendingCollegeFilter = item; }); }) }.width('100%');
          Row() { Text('状态').fontSize(16).fontColor('#777777').width(52); ForEach(['待解决', '已解决', '全部'], (item: string) => { Text(item).fontSize(16).fontColor(this.pendingStatusFilter === item ? '#20C894' : '#777777').backgroundColor(this.pendingStatusFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(18).padding({ left: 10, right: 10, top: 8, bottom: 8 }).margin({ right: 8 }).onClick(() => { this.pendingStatusFilter = item; }); }) }.width('100%').margin({ top: 8 });
          Row() { Text('取消').fontSize(17).fontColor('#999999').layoutWeight(1).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); Text('确定').fontSize(17).fontColor('#20C894').textAlign(TextAlign.End).onClick(() => { this.activeCollegeFilter = this.pendingCollegeFilter; this.activeStatusFilter = this.pendingStatusFilter; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); }.width('100%').margin({ top: 12 });
        }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 12 }).transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 0, y: -120 }))).animation({ duration: 260, curve: Curve.EaseInOut });
      }
      if (this.searching) {
        Row() { Text('⌕').fontSize(30).fontColor('#555555'); TextInput({ placeholder: '搜索当前板块', text: this.query }).layoutWeight(1).fontSize(20).onChange((value: string) => { this.query = value; }); Text('×').fontSize(32).fontColor('#777777').onClick(() => { this.query = ''; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = false; }); }); }.width('92%').height(58).padding({ left: 16, right: 14 }).backgroundColor(Color.White).borderRadius(30).margin({ bottom: 12 });
      }
      List() {
        if (this.loading) { ListItem() { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); } }
        else if (this.sortedPosts().length === 0) { ListItem() { Text('暂无求助信息').fontSize(18).fontColor('#999999').margin({ top: 36 }); } }
        else { ForEach(this.sortedPosts(), (post: CampusWallPost) => ListItem() { Column() {
          Row() { if (post.avatarUrl) { Image(post.avatarUrl).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } Column() { Text(post.displayName || post.realName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86'); Text(post.college || post.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { Text(this.isResolved(post) ? '已解决' : '待解决').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.isResolved(post) ? '#3C8B62' : '#B66D16').backgroundColor(this.isResolved(post) ? '#E8F7ED' : '#FFF4DE').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }); Text(this.isResolved(post) ? '问题已解决' : ((post.replyCount || 0) > 0 ? `${post.replyCount} 个回答` : '等待回答')).fontSize(15).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 6 }); }.alignItems(HorizontalAlign.End); }.width('100%');
          if (post.title) { CampusRichText({ content: post.title, fontSize: 22, textColor: '#222222', baseBold: true, lineHeight: 30 }); }
          CampusRichText({ content: post.content || '', fontSize: 18, textColor: '#333333', lineHeight: 28 });
          if (post.images && post.images.length > 0) { CommunityPostImagePreview({ images: post.images }).margin({ top: 12 }); }
          Text(campusWallRelativeTime(post.createdAt)).fontSize(16).fontColor('#AAAAAA');
        }.width('100%').padding({ left: 34, right: 34, top: 20, bottom: 22 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' }).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPostDetailPage', params: { id: String(post.id || 0) } })); }, (post: CampusWallPost) => `${post.id || post.createdAt || post.content}`); }
        if (!this.loading && this.posts.length > 0) { ListItem() { Row() { if (this.loadingMore) { LoadingProgress().width(22).height(22).color('#20C894'); Text('正在加载更多…').fontSize(15).fontColor('#888888').margin({ left: 8 }); } else if (!this.hasMore) { Text('已经到底了').fontSize(15).fontColor('#AAAAAA'); } }.width('100%').height(54).justifyContent(FlexAlign.Center); } }
      }.width('100%').layoutWeight(1).backgroundColor('#F5F6F8').onReachEnd(() => this.loadMore());
      Row() { Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('发布求助问题...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'help', label: '发布求助问题' } })).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 });
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}



