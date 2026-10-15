import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpRequest } from '../../net/HttpRequest';
import { AppStorage } from '../../store/AppStorage';
interface Notice { title?: string; content?: string; createdAt?: string; }
@Entry @Component
struct CommunityNotificationsPage {
  @State private items: Notice[] = [];
  @State private loading: boolean = true;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> { this.loading = true; try { const token = await AppStorage.getInstance().getAppAuthAccessToken(); const result = await HttpRequest.get<Record<string, Object>>('https://lyzyy.love:8081/api/v1/campus-wall/notifications', { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' }); const raw = result.data['data']; this.items = Array.isArray(raw) ? raw as Notice[] : []; } catch { promptAction.showToast({ message: '消息加载失败', duration: 1200 }); } this.loading = false; }
  build() { Column() { Row() { Text('‹').fontSize(42).width(48).onClick(() => router.back()); Text('社区消息').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 }); }.width('100%').height(96).padding({ left: 14 }).backgroundColor('#F5F6F8'); Scroll() { Column() { if (this.loading) { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); } else if (this.items.length === 0) { Text('暂无社区消息').fontSize(18).fontColor('#999999').margin({ top: 36 }); } else { ForEach(this.items, (item: Notice) => Column() { Text(item.title || '社区消息').fontSize(22).fontWeight(FontWeight.Bold).width('100%'); Text(item.content || '').fontSize(18).fontColor('#666666').width('100%').margin({ top: 10 }); Text(item.createdAt || '').fontSize(16).fontColor('#999999').margin({ top: 14 }); }.width('100%').padding({ left: 40, right: 30, top: 28, bottom: 28 }).backgroundColor(Color.White).border({ width: { bottom: 1 }, color: '#EEEEEE' }), (item: Notice) => `${item.title || ''}${item.createdAt || ''}`); } }.width('100%').backgroundColor('#F5F6F8'); }.layoutWeight(1); }.width('100%').height('100%').backgroundColor('#F5F6F8'); }
}
