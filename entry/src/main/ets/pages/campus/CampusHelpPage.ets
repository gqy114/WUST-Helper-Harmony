import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, decodeHtmlEntities } from '../../net/CampusWallApi';

@Entry @Component
struct CampusHelpPage {
  @State private posts: CampusWallPost[] = [];
  @State private loading: boolean = true;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> { this.loading = true; try { this.posts = await CampusWallApi.list(1, 'help'); } catch { promptAction.showToast({ message: '求助信息加载失败', duration: 1500 }); } this.loading = false; }
  private timeLabel(value: string): string { if (value.length === 0) return ''; const stamp = Date.parse(value); if (isNaN(stamp)) return value; const hours = Math.max(0, Math.floor((Date.now() - stamp) / 3600000)); return hours < 1 ? '刚刚' : `${hours}小时前`; }
  private isResolved(post: CampusWallPost): boolean { const status = (post.status || '').toLowerCase(); return post.resolved === true || post.isResolved === true || status === 'resolved' || status === 'solved' || status === '已解决'; }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('求助').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 }); Blank().layoutWeight(1); Text('⌕').fontSize(34).fontColor('#333333').margin({ right: 18 }); Image($r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover); }.width('100%').height(96).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      Scroll() { Column() {
        if (this.loading) { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        else if (this.posts.length === 0) { Text('暂无求助信息').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
        else { ForEach(this.posts, (post: CampusWallPost) => Column() {
          Row() { if (post.avatarUrl) { Image(post.avatarUrl).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } Column() { Text(post.displayName || post.realName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86'); Text(post.college || post.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 }); }.alignItems(HorizontalAlign.Start).layoutWeight(1); Column() { Text(this.isResolved(post) ? '已解决' : '待解决').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.isResolved(post) ? '#3C8B62' : '#B66D16').backgroundColor(this.isResolved(post) ? '#E8F7ED' : '#FFF4DE').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }); Text(this.isResolved(post) ? '问题已解决' : ((post.replyCount || 0) > 0 ? `${post.replyCount} 个回答` : '等待回答')).fontSize(15).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 6 }); }.alignItems(HorizontalAlign.End); }.width('100%');
          if (post.title) { Text(decodeHtmlEntities(post.title)).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%').margin({ top: 16 }); }
          Text(decodeHtmlEntities(post.content || '')).fontSize(18).fontColor('#333333').width('100%').maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 12 }); Text(this.timeLabel(post.createdAt || '')).fontSize(16).fontColor('#AAAAAA').margin({ top: 16 });
        }.width('100%').padding({ left: 34, right: 34, top: 20, bottom: 22 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' }), (post: CampusWallPost) => `${post.id || post.createdAt || post.content}`); }
      }.width('100%').backgroundColor('#F5F6F8'); }.layoutWeight(1);
      Row() { Image($r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('发布求助问题...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'help', label: '发布求助问题' } })).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 });
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}


