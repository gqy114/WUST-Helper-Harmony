import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, decodeHtmlEntities } from '../../net/CampusWallApi';

@Entry @Component
struct CampusMatchPage {
  @State private posts: CampusWallPost[] = [];
  @State private avatarUrl: string = '';
  @State private loading: boolean = true;
  @State private searching: boolean = false;
  @State private query: string = "";
  @State private filterOpen: boolean = false;
  @State private pendingCollegeFilter: string = "全部";
  @State private pendingTeamFilter: string = "全部";
  @State private activeCollegeFilter: string = "全部";
  @State private activeTeamFilter: string = "全部";
  @State private selfCollege: string = "";

  private async loadAvatar(): Promise<void> { this.avatarUrl = await AppStorage.getInstance().getAvatarUrl(); }
  aboutToAppear(): void { this.load(); this.loadAvatar(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.selfCollege = await AppStorage.getInstance().getCollege(); } catch {}
    try { this.posts = await CampusWallApi.list(1, 'team'); }
    catch { promptAction.showToast({ message: '组队信息加载失败', duration: 1500 }); }
    this.loading = false;
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
  private filterMatch(post: CampusWallPost): boolean {
    const teamOk: boolean = this.activeTeamFilter === '全部' || this.teamLabel(post) === this.activeTeamFilter;
    const same: boolean = this.selfCollege.length > 0 && (post.college || '').includes(this.selfCollege);
    const collegeOk: boolean = this.activeCollegeFilter === '全部' || (this.activeCollegeFilter === '同学院' ? same : !same);
    return teamOk && collegeOk;
  }
  private teamLabel(post: CampusWallPost): string { const value = (post.noticeType || post.type || post.category || '').toLowerCase(); return value.indexOf('队伍') >= 0 || value.indexOf('team') >= 0 || value.indexOf('join') >= 0 ? '找队伍' : '找队友'; }

  @Builder private highlighted(value: string, size: number, color: string, bold: boolean) {
    Text() { ForEach(value.split(''), (ch: string) => { Span(ch).fontColor(this.query.trim().length > 0 && this.query.toLowerCase().includes(ch.toLowerCase()) ? '#18B889' : color); }) }
      .fontSize(size).fontWeight(bold ? FontWeight.Bold : FontWeight.Normal).width('100%');
  }
  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center)
          .onClick(() => router.back());
        Text('竞赛组队').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 });
        Blank().layoutWeight(1); Row() { Image($r('app.media.filter')).width(24).height(24).margin({ right: 14 }).onClick(() => { this.pendingCollegeFilter = this.activeCollegeFilter; this.pendingTeamFilter = this.activeTeamFilter; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = true; }); }); Image($r('app.media.search')).width(24).height(24).margin({ right: 18 }).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = true; }); }); }.height(48).alignItems(VerticalAlign.Center); Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover);
      }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      if (this.filterOpen) {
        Column() {
          Row() { Text('学院').fontSize(16).fontColor('#777777').width(52); ForEach(['同学院', '不同学院', '全部'], (item: string) => { Text(item).fontSize(16).fontColor(this.pendingCollegeFilter === item ? '#20C894' : '#777777').backgroundColor(this.pendingCollegeFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(18).padding({ left: 10, right: 10, top: 8, bottom: 8 }).margin({ right: 8 }).onClick(() => { this.pendingCollegeFilter = item; }); }) }.width('100%');
          Row() { Text('类型').fontSize(16).fontColor('#777777').width(52); ForEach(['找队友', '找队伍', '全部'], (item: string) => { Text(item).fontSize(16).fontColor(this.pendingTeamFilter === item ? '#20C894' : '#777777').backgroundColor(this.pendingTeamFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(18).padding({ left: 10, right: 10, top: 8, bottom: 8 }).margin({ right: 8 }).onClick(() => { this.pendingTeamFilter = item; }); }) }.width('100%').margin({ top: 8 });
          Row() { Text('取消').fontSize(17).fontColor('#999999').layoutWeight(1).onClick(() => { animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); Text('确定').fontSize(17).fontColor('#20C894').textAlign(TextAlign.End).onClick(() => { this.activeCollegeFilter = this.pendingCollegeFilter; this.activeTeamFilter = this.pendingTeamFilter; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }); }.width('100%').margin({ top: 12 });
        }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 12 }).transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 0, y: -120 }))).animation({ duration: 260, curve: Curve.EaseInOut });
      }
      if (this.searching) {
        Row() { Text('⌕').fontSize(30).fontColor('#555555'); TextInput({ placeholder: '搜索当前板块', text: this.query }).layoutWeight(1).fontSize(20).onChange((value: string) => { this.query = value; }); Text('×').fontSize(32).fontColor('#777777').onClick(() => { this.query = ''; animateTo({ duration: 260, curve: Curve.EaseInOut }, () => { this.searching = false; }); }); }.width('92%').height(58).padding({ left: 16, right: 14 }).backgroundColor(Color.White).borderRadius(30).margin({ bottom: 12 });
      }
      Scroll() {
        Column() {
          if (this.loading) {
            Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 });
          } else if (this.posts.length === 0) {
            Text('暂无组队信息').fontSize(18).fontColor('#999999').margin({ top: 36 });
          } else {
            ForEach(this.posts.filter((post: CampusWallPost) => this.filterMatch(post) && this.matchScore(post) > 0).sort((a: CampusWallPost, b: CampusWallPost) => this.matchScore(b) - this.matchScore(a)), (post: CampusWallPost) => {
              Column() {
                Row() {
                  if (post.avatarUrl) { Image(post.avatarUrl).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); }
                  Column() {
                    Text(post.displayName || post.realName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86');
                    Text(post.college || post.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 });
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1);
                  Column() { Text(this.teamLabel(post)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2D6E9F').backgroundColor('#E7F4FF').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }); Text((post.replyCount || 0) > 0 ? `${post.replyCount} 条回复` : '等待回应').fontSize(15).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 6 }); }.alignItems(HorizontalAlign.End);
                }.width('100%');
                if (post.title) { this.highlighted(decodeHtmlEntities(post.title), 22, '#222222', true); }
                this.highlighted(decodeHtmlEntities(post.content || ''), 18, '#333333', false);
                Text('刚刚').fontSize(16).fontColor('#AAAAAA').margin({ top: 18 });
              }.width('100%').padding({ left: 34, right: 34, top: 22, bottom: 24 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' });
            }, (post: CampusWallPost) => `${post.id || post.createdAt || post.content}`);
          }
        }.width('100%').backgroundColor('#F5F6F7');
      }.layoutWeight(1);
      Row() { Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('发布组队信息...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'team', label: '发布组队信息' } })).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 });
    }.width('100%').height('100%').backgroundColor('#F5F6F7');
  }
}





