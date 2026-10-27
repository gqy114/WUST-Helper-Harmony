import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';
import { promptAction } from '@kit.ArkUI';
import { CampusCatApi, CampusCatPost } from '../../net/CampusCatApi';
import { campusWallRelativeTime, decodeHtmlEntities } from '../../net/CampusWallApi';

@Entry @Component
struct CampusCatPage {
  @State private posts: CampusCatPost[] = [];
  @State private avatarUrl: string = '';
  @State private loading: boolean = true;
  @State private searching: boolean = false;
  @State private query: string = "";
  @State private filterOpen: boolean = false;
  @State private pendingTags: string[] = [];
  @State private activeTags: string[] = [];
  @State private currentPage: number = 1;
  @State private loadingMore: boolean = false;
  @State private hasMore: boolean = true;
  private readonly pageSize: number = 20;
  private async loadAvatar(): Promise<void> { this.avatarUrl = await AppStorage.getInstance().getAvatarUrl(); }
  aboutToAppear(): void { this.load(); this.loadAvatar(); }
  private async load(): Promise<void> {
    this.loading = true;
    this.currentPage = 1;
    this.hasMore = true;
    try {
      const firstPage = await CampusCatApi.list(1, this.pageSize);
      this.posts = firstPage;
      this.hasMore = firstPage.length >= this.pageSize;
    } catch {
      promptAction.showToast({ message: '校园猫加载失败', duration: 1500 });
    }
    this.loading = false;
  }
  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore) return;
    this.loadingMore = true;
    const nextPage = this.currentPage + 1;
    try {
      const nextPosts = await CampusCatApi.list(nextPage, this.pageSize);
      this.posts = this.posts.concat(nextPosts);
      this.currentPage = nextPage;
      this.hasMore = nextPosts.length >= this.pageSize;
    } catch {
      promptAction.showToast({ message: '加载更多失败', duration: 1200 });
    }
    this.loadingMore = false;
  }
  private matchScore(post: CampusCatPost): number { const q = this.query.trim().toLowerCase(); if (!q) return 1; const text = `${post.title || ""}${post.content || ""}${post.authorName || ""}`.toLowerCase(); let score = 0; for (let i = 0; i < q.length; i++) { if (text.includes(q.charAt(i))) score++; } return score; }
  private togglePendingTag(tag: string): void {
    this.pendingTags = this.pendingTags.indexOf(tag) >= 0 ?
      this.pendingTags.filter((item: string) => item !== tag) : this.pendingTags.concat([tag]);
  }
  private filterMatch(post: CampusCatPost): boolean {
    if (this.activeTags.length === 0) return true;
    const postTags: string[] = post.tags || [];
    return this.activeTags.some((tag: string) => postTags.indexOf(tag) >= 0);
  }
  private visiblePosts(): CampusCatPost[] {
    return this.posts.filter((post: CampusCatPost) => this.filterMatch(post) && this.matchScore(post) > 0)
      .sort((a: CampusCatPost, b: CampusCatPost) => this.matchScore(b) - this.matchScore(a));
  }
  @Builder private highlighted(value: string, size: number, color: string, bold: boolean) {
    Text(value).fontSize(size).fontWeight(bold ? FontWeight.Bold : FontWeight.Normal).fontColor(color).width('100%');
  }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('校园猫').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 }); Blank().layoutWeight(1); Row() { Image($r('app.media.filter')).width(24).height(24).margin({ right: 14 }).alignSelf(ItemAlign.Center).onClick(() => { this.pendingTags = this.activeTags.slice(); animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = true; }); }); Image($r('app.media.search')).width(24).height(24).margin({ right: 18 }).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = true; }); }); }.height(48).alignItems(VerticalAlign.Center); Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover).alignSelf(ItemAlign.Center); }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      if (this.filterOpen) {
        Column() {
          Text('选择标签（可多选）').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555').width('100%').margin({ bottom: 10 });
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('全部').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.pendingTags.length === 0 ? Color.White : '#707070').textAlign(TextAlign.Center).width(88).height(44).backgroundColor(this.pendingTags.length === 0 ? '#20C894' : '#ECF8F4').borderRadius(16).margin({ right: 8, bottom: 8 }).onClick(() => { this.pendingTags = []; });
            ForEach(['流浪', '领养', '日常', '求助', '晒猫'], (tag: string) => {
              Text(tag).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.pendingTags.indexOf(tag) >= 0 ? Color.White : '#707070').textAlign(TextAlign.Center).width(88).height(44).backgroundColor(this.pendingTags.indexOf(tag) >= 0 ? '#20C894' : '#ECF8F4').borderRadius(16).margin({ right: 8, bottom: 8 }).onClick(() => this.togglePendingTag(tag));
            });
          }.width('100%');
          Row() { Text('取消').fontSize(17).fontColor('#999999').layoutWeight(1).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); Text('确定').fontSize(17).fontColor('#20C894').onClick(() => { this.activeTags = this.pendingTags.slice(); animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); }.width('100%').margin({ top: 4 });
        }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 12 }).transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 0, y: -120 }))).animation({ duration: 260, curve: Curve.EaseInOut });
      }
      if (this.searching) {
        Row() { Text('⌕').fontSize(30).fontColor('#555555'); TextInput({ placeholder: '搜索当前板块', text: this.query }).layoutWeight(1).fontSize(20).onChange((value: string) => { this.query = value; }); Text('×').fontSize(32).fontColor('#777777').onClick(() => { this.query = ''; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = false; }); }); }.width('92%').height(58).padding({ left: 16, right: 14 }).backgroundColor(Color.White).borderRadius(30).margin({ bottom: 12 });
      }
      List() {
        if (this.loading) {
          ListItem() { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        } else if (this.posts.length === 0) {
          ListItem() { Text('暂无校园猫信息').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        } else if (this.visiblePosts().length === 0) {
          ListItem() { Text('暂无符合条件的校园猫帖子').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        } else {
          ForEach(this.visiblePosts(), (post: CampusCatPost) => {
            ListItem() {
              Column() {
                Row() { if (post.authorAvatar) { Image(post.authorAvatar).width(52).height(52).sourceSize({ width: 104, height: 104 }).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } Column() { Text(post.authorName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86'); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { Text((post.tags && post.tags.length > 0) ? post.tags.join(' · ') : '日常').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#148D6D').backgroundColor('#E8F8F3').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }); Text((post.commentCount || 0) > 0 ? `${post.commentCount} 个回答` : '校园猫动态').fontSize(15).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 6 }); }.alignItems(HorizontalAlign.End); }.width('100%');
                if (post.title) { this.highlighted(decodeHtmlEntities(post.title), 22, '#222222', true); }
                this.highlighted(decodeHtmlEntities(post.content || ''), 18, '#333333', false);
                if (post.images && post.images.length > 0) {
                  ForEach(post.images, (image: string) => {
                    Image(image).width('100%').height(190).sourceSize({ width: 720, height: 380 }).objectFit(ImageFit.Cover).borderRadius(10).margin({ top: 12 });
                  }, (image: string, imageIndex: number) => `${imageIndex}-${image}`)
                }
                Text(campusWallRelativeTime(post.createdAt)).fontSize(16).fontColor('#AAAAAA');
              }.width('100%').padding({ left: 34, right: 34, top: 20, bottom: 22 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' });
            }
          }, (post: CampusCatPost, index: number) => `${post.id || post.createdAt || 'post'}-${index}`)
          if (this.loadingMore) {
            ListItem() { Text('加载更多…').fontSize(16).fontColor('#999999').height(52).textAlign(TextAlign.Center); }
          } else if (!this.hasMore) {
            ListItem() { Text('已经到底了').fontSize(15).fontColor('#BBBBBB').height(46).textAlign(TextAlign.Center); }
          }
        }
      }.width('100%').layoutWeight(1).backgroundColor('#F5F6F8').onReachEnd(() => this.loadMore());
      Row() { Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('发布校园猫...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'cat', label: '发布校园猫帖子' } })).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 });
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}



