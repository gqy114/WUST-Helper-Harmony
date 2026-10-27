import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusRichText } from '../../components/CampusRichText';
import { CampusWallApi, CampusWallNotification } from '../../net/CampusWallApi';

@Entry
@Component
struct CommunityNotificationsPage {
  @State private items: CampusWallNotification[] = [];
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private hasMore: boolean = true;
  private readonly pageSize: number = 30;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.hasMore = true;
    try {
      const page = await CampusWallApi.notifications(0, this.pageSize);
      this.items = page.items || [];
      this.hasMore = this.items.length >= this.pageSize;
      if (page.latestId > 0 && page.unreadCount > 0) CampusWallApi.markNotificationsRead(page.latestId).catch(() => {});
    } catch { promptAction.showToast({ message: '消息加载失败', duration: 1200 }); }
    this.loading = false;
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore || this.items.length === 0) return;
    const lastId = this.items[this.items.length - 1].id || 0;
    if (lastId <= 0) return;
    this.loadingMore = true;
    try {
      const page = await CampusWallApi.notifications(lastId, this.pageSize);
      const existing: Set<number> = new Set<number>();
      this.items.forEach((item: CampusWallNotification) => existing.add(item.id || 0));
      const fresh = (page.items || []).filter((item: CampusWallNotification) => !existing.has(item.id || 0));
      this.items = this.items.concat(fresh);
      this.hasMore = page.items.length >= this.pageSize;
    } catch { promptAction.showToast({ message: '加载更多失败', duration: 1200 }); }
    this.loadingMore = false;
  }

  private actorName(item: CampusWallNotification): string {
    return item.actor?.displayName || item.actor?.realName || item.actor?.studentId || '同学';
  }

  private actionText(item: CampusWallNotification): string {
    return item.eventType === 'mention' ? '提到了你' : '回复了你的帖子';
  }

  private dateText(value?: string): string {
    if (!value) return '';
    const stamp = Date.parse(value);
    if (isNaN(stamp)) return value;
    const date = new Date(stamp);
    const pad = (number: number): string => number < 10 ? `0${number}` : `${number}`;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private openNotification(item: CampusWallNotification): void {
    if (item.targetType === 'cat_reply') {
      router.pushUrl({ url: 'pages/campus/CampusCatPage' });
    } else if ((item.postId || 0) > 0) {
      router.pushUrl({ url: 'pages/campus/CampusPostDetailPage', params: { id: String(item.postId) } });
    }
  }

  @Builder
  private notificationItem(item: CampusWallNotification) {
    Column() {
      Row() {
        if (item.actor?.avatarUrl) {
          Image(item.actor.avatarUrl).width(46).height(46).borderRadius(23).objectFit(ImageFit.Cover).margin({ right: 12 });
        } else {
          Image($r('app.media.ic_default_avatar')).width(46).height(46).borderRadius(23).margin({ right: 12 });
        }
        Text(`${this.actorName(item)}${this.actionText(item)}`).fontSize(21).fontWeight(FontWeight.Bold)
          .fontColor('#2F2F2F').layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis });
      }.width('100%').alignItems(VerticalAlign.Center);
      if (item.postTitle) {
        CampusRichText({ content: item.postTitle, fontSize: 18, textColor: '#555555', baseBold: true, lineHeight: 26 });
      }
      if (item.content) {
        CampusRichText({ content: item.content, fontSize: 18, textColor: '#666666', lineHeight: 26 });
      }
      Text(this.dateText(item.createdAt)).fontSize(16).fontColor('#999999').margin({ top: 12 });
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: 32, right: 28, top: 24, bottom: 24 })
      .backgroundColor(item.readAt ? Color.White : '#FAFFFD')
      .border({ width: { bottom: 1 }, color: '#EEEEEE' })
      .onClick(() => this.openNotification(item));
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).width(48).textAlign(TextAlign.Center).onClick(() => router.back());
        Text('社区消息').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 });
      }.width('100%').height(96).padding({ left: 14 }).alignItems(VerticalAlign.Center).backgroundColor('#F5F6F8');
      List() {
        if (this.loading) {
          ListItem() { Text('加载中…').fontSize(18).fontColor('#999999').height(100).textAlign(TextAlign.Center); }
        } else if (this.items.length === 0) {
          ListItem() { Text('暂无社区消息').fontSize(18).fontColor('#999999').height(120).textAlign(TextAlign.Center); }
        } else {
          ForEach(this.items, (item: CampusWallNotification) => {
            ListItem() { this.notificationItem(item); }
          }, (item: CampusWallNotification) => `${item.id || 0}`);
          if (this.loadingMore) {
            ListItem() { Text('加载更多…').fontSize(16).fontColor('#999999').height(52).textAlign(TextAlign.Center); }
          } else if (!this.hasMore) {
            ListItem() { Text('已经到底了').fontSize(15).fontColor('#BBBBBB').height(46).textAlign(TextAlign.Center); }
          }
        }
      }.width('100%').layoutWeight(1).backgroundColor('#F5F6F8').onReachEnd(() => this.loadMore());
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
