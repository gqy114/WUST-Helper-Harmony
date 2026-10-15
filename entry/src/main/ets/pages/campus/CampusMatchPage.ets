import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi, CampusWallPost, decodeHtmlEntities } from '../../net/CampusWallApi';

@Entry @Component
struct CampusMatchPage {
  @State private posts: CampusWallPost[] = [];
  @State private loading: boolean = true;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.posts = await CampusWallApi.list(1, 'team'); }
    catch { promptAction.showToast({ message: '组队信息加载失败', duration: 1500 }); }
    this.loading = false;
  }

  private async toggleLike(post: CampusWallPost): Promise<void> {
    if (!post.id) return;
    try {
      const added = await CampusWallApi.toggleReaction(post.id);
      post.likeCount = Math.max(0, (post.likeCount || 0) + (added ? 1 : -1));
      this.posts = this.posts.slice();
    } catch { promptAction.showToast({ message: '操作失败，请稍后重试', duration: 1200 }); }
  }
  private teamLabel(post: CampusWallPost): string { const value = (post.noticeType || post.type || post.category || '').toLowerCase(); return value.indexOf('队伍') >= 0 || value.indexOf('team') >= 0 || value.indexOf('join') >= 0 ? '找队伍' : '找队友'; }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center)
          .onClick(() => router.back());
        Text('竞赛组队').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 });
        Blank().layoutWeight(1); Text('⌕').fontSize(34).fontColor('#333333').margin({ right: 18 }); Image($r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover);
      }.width('100%').height(96).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      Scroll() {
        Column() {
          if (this.loading) {
            Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 });
          } else if (this.posts.length === 0) {
            Text('暂无组队信息').fontSize(18).fontColor('#999999').margin({ top: 36 });
          } else {
            ForEach(this.posts, (post: CampusWallPost) => {
              Column() {
                Row() {
                  if (post.avatarUrl) { Image(post.avatarUrl).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); } else { Image($r('app.media.ic_default_avatar')).width(52).height(52).borderRadius(26).objectFit(ImageFit.Cover).margin({ right: 12 }); }
                  Column() {
                    Text(post.displayName || post.realName || '同学').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#655C86');
                    Text(post.college || post.major || '').fontSize(15).fontColor('#888888').margin({ top: 3 });
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1);
                  Column() { Text(this.teamLabel(post)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2D6E9F').backgroundColor('#E7F4FF').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }); Text((post.replyCount || 0) > 0 ? `${post.replyCount} 条回复` : '等待回应').fontSize(15).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(22).padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 6 }); }.alignItems(HorizontalAlign.End);
                }.width('100%');
                if (post.title) { Text(decodeHtmlEntities(post.title)).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%').margin({ top: 16 }); }
                Text(decodeHtmlEntities(post.content || '')).fontSize(18).fontColor('#333333').width('100%').maxLines(6).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 12 });
                Text('刚刚').fontSize(16).fontColor('#AAAAAA').margin({ top: 18 });
              }.width('100%').padding({ left: 34, right: 34, top: 22, bottom: 24 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' });
            }, (post: CampusWallPost) => `${post.id || post.createdAt || post.content}`);
          }
        }.width('100%').backgroundColor('#F5F6F7');
      }.layoutWeight(1);
      Row() { Image($r('app.media.ic_default_avatar')).width(42).height(42).borderRadius(21).margin({ right: 12 }); Text('发布组队信息...').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#999999').layoutWeight(1); Text('+').fontSize(32).onClick(() => router.pushUrl({ url: 'pages/campus/CampusPublishPage', params: { tag: 'team', label: '发布组队信息' } })).fontColor(Color.White).width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#20C894').borderRadius(29); }.width('88%').height(76).padding({ left: 18, right: 14 }).backgroundColor(Color.White).borderRadius(38).shadow({ radius: 12, color: '#33000000', offsetY: 3 }).margin({ bottom: 18 });
    }.width('100%').height('100%').backgroundColor('#F5F6F7');
  }
}




