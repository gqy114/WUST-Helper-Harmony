import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, decodeHtmlEntities } from '../../net/CampusWallApi';

@Entry @Component
struct CampusHelpPage {
  @State private posts: CampusWallPost[] = [];
  @State private avatarUrl: string = '';
  @State private loading: boolean = true;
  @State private searching: boolean = false;
  @State private query: string = "";
  @State private filterOpen: boolean = false;
  @State private pendingCollegeFilter: string = "全部";
  @State private pendingStatusFilter: string = "全部";
  @State private activeCollegeFilter: string = "全部";
  @State private activeStatusFilter: string = "全部";
  @State private selfCollege: string = "";
  private async loadAvatar(): Promise<void> { this.avatarUrl = await AppStorage.getInstance().getAvatarUrl(); }
  aboutToAppear(): void { this.load(); this.loadAvatar(); }
  private async load(): Promise<void> { this.loading = true; try { this.selfCollege = await AppStorage.getInstance().getCollege(); } catch {} try { this.posts = await CampusWallApi.list(1, 'help'); } catch { promptAction.showToast({ message: '求助信息加载失败', duration: 1500 }); } this.loading = false; }
  private matchScore(post: CampusWallPost): number { const q = this.query.trim().toLowerCase(); if (!q) return 1; const text = `${post.title || ""}${post.content || ""}${post.displayName || ""}${post.realName || ""}${post.college || ""}`.toLowerCase(); let score = 0; for (let i = 0; i < q.length; i++) { if (text.includes(q.charAt(i))) score++; } return score; }
  private timeLabel(value: string): string { if (value.length === 0) return ''; const stamp = Date.parse(value); if (isNaN(stamp)) return value; const hours = Math.max(0, Math.floor((Date.now() - stamp) / 3600000)); return hours < 1 ? '刚刚' : `${hours}小时前`; }
  private filterMatch(post: CampusWallPost): boolean {
    const same: boolean = this.selfCollege.length > 0 && (post.college || '').includes(this.selfCollege);
    const collegeOk: boolean = this.activeCollegeFilter === '全部' || (this.activeCollegeFilter === '同学院' ? same : !same);
    const resolved: boolean = this.isResolved(post);
    const statusOk: boolean = this.activeStatusFilter === '全部' || (this.activeStatusFilter === '已解决' ? resolved : !resolved);
    return collegeOk && statusOk;
  }
  private isResolved(post: CampusWallPost): boolean { const status = (post.status || '').toLowerCase(); return post.resolved === true || post.isResolved === true || status === 'resolved' || status === 'solved' || status === '已解决'; }
  private sortedPosts(): CampusWallPost[] {
    return this.posts.filter((post: CampusWallPost) => this.filterMatch(post) && this.matchScore(post) > 0).sort((a: CampusWallPost, b: CampusWallPost) => {
      const statusOrder: number = (this.isResolved(a) ? 1 : 0) - (this.isResolved(b) ? 1 : 0);
      if (statusOrder !== 0) return statusOrder;
      const aTime: number = Date.parse(a.createdAt || '') || 0;
      const bTime: number = Date.parse(b.createdAt || '') || 0;
      return bTime - aTime;
    });
  }
  @Builder private highlighted(value: string, size: number, color: string, bold: boolean) {
    Text() { ForEach(value.split(''), (ch: string) => { Span(ch).fontColor(this.query.trim().length > 0 && this.query.toLowerCase().includes(ch.toLowerCase()) ? '#18B889' : color); }) }
      .fontSize(size).fontWeight(bold ? FontWeight.Bold : FontWeight.Normal).width('100%');
  }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('求助').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 }); Blank().layoutWeight(1); Image($r('app.media.filter')).width(24).height(24).margin({ right: 14 }).onClick(() => { this.pendingCollegeFilter = this.activeCollegeFilter; this.pendingStatusFilter = this.activeStatusFilter; this.filterOpen = true; }); Text('⌕').fontSize(34).fontColor('#333333').margin({ right: 18 }).onClick(() => { this.searching = true; }); Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover); }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      if (this.filterOpen) {
        Column() {
          Row() { Text('学院').fontSize(16).fontColor('#777777').width(52); ForEach(['同学院', '不同学院', '全部'], (item: string) => { Text(item).fontSize(16).fontColor(this.pendingCollegeFilter === item ? '#20C894' : '#777777').backgroundColor(this.pendingCollegeFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(18).padding({ left: 10, right: 10, top: 8, bottom: 8 }).margin({ right: 8 }).onClick(() => { this.pendingCollegeFilter = item; }); }) }.width('100%');
          Row() { Text('状态').fontSize(16).fontColor('#777777').width(52); ForEach(['待解决', '已解决', '全部'], (item: string) => { Text(item).fontSize(16).fontColor(this.pendingStatusFilter === item ? '#20C894' : '#777777').backgroundColor(this.pendingStatusFilter === item ? '#E7F8F2' : '#F5F5F5').borderRadius(18).padding({ left: 10, right: 10, top: 8, bottom: 8 }).margin({ right: 8 }).onClick(() => { this.pendingStatusFilter = item; }); }) }.width('100%').margin({ top: 8 });
          Row() { Text('取消').fontSize(17).fontColor('#999999').layoutWeight(1).onClick(() => { this.filterOpen = false; }); Text('确定').fontSize(17).fontColor('#20C894').textAlign(TextAlign.End).onClick(() => { this.activeCollegeFilter = this.pendingCollegeFilter; this.activeStatusFilter = this.pendingStatusFilter; this.filterOpen = false; }); }.width('100%').margin({ top: 12 });
        }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 12 }).animation({ duration: 260, curve: Curve.EaseInOut });
      }
      if (this.searching) {
        Row() { Text('⌕').fontSize(30).fontColor('#555555'); TextInput({ placeholder: '搜索当前板块', text: this.query }).layoutWeight(1).fontSize(20).onChange((value: string) => { this.query = value; }); Text('×').fontSize(32).fontColor('#777777').onClick(() => { this.query = ''; this.searching = false; }); }.width('92%').height(58).padding({ left: 16, right: 14 }).backgroundColor(Color.White).borderRadius(30).margin({ bottom: 12 });
      }
      Scroll() { Column() {
        if (this.loading) { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        else if (this.posts.length === 0) { Text('暂无求助信息').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        else { ForEach(this.sortedPosts(), (post: CampusWallPost) => Column() {
          Row() { if (post.avatarUrl) { Image(post.avatarUrl).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } Column() { Text(post.displayName || post.realName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86'); Text(post.college || post.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { Text(this.isResolved(post) ? '已解决' : '待解决').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.isResolved(post) ? '#3C8B62' : '#B66D16').backgroundColor(this.isResolved(post) ? '#E8F7ED' : '#FFF4DE').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }); Text(this.isResolved(post) ? '问题已解决' : ((post.replyCount || 0) > 0 ? `${post.replyCount} 个回答` : '等待回答')).fontSize(15).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 6 }); }.alignItems(HorizontalAlign.End); }.width('100%');
          if (post.title) { this.highlighted(decodeHtmlEntities(post.title), 22, '#222222', true); }
          this.highlighted(decodeHtmlEntities(post.content || ''), 18, '#333333', false); Text(this.timeLabel(post.createdAt || '')).fontSize(16).fontColor('#AAAAAA');
        }.width('100%').padding({ left: 34, right: 34, top: 20, bottom: 22 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' }), (post: CampusWallPost) => `${post.id || post.createdAt || post.content}`); }
      }.width('100%').backgroundColor('#F5F6F8'); }.layoutWeight(1);
      Row() { Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('发布求助问题...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'help', label: '发布求助问题' } })).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 });
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}



