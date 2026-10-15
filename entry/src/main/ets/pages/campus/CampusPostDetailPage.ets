import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi } from '../../net/CampusWallApi';

@Entry @Component
struct CampusPostDetailPage {
  @State private postId: number = 0;
  @State private title: string = '';
  @State private content: string = '';
  @State private replyText: string = '';
  aboutToAppear(): void { const params = router.getParams() as Record<string, string>; if (params) { this.postId = Number(params['id'] || 0); this.title = params['title'] || '帖子详情'; this.content = params['content'] || ''; } }
  private async submitReply(): Promise<void> { if (this.postId <= 0 || this.replyText.trim().length === 0) { promptAction.showToast({ message: '请输入回复内容', duration: 1200 }); return; } try { await CampusWallApi.reply(this.postId, this.replyText.trim()); promptAction.showToast({ message: '回复成功', duration: 1200 }); router.back(); } catch { promptAction.showToast({ message: '回复失败，请稍后重试', duration: 1500 }); } }
  build() { Column() { Row() { Text('‹').fontSize(42).width(48).onClick(() => router.back()); Text('帖子详情').fontSize(27).fontWeight(FontWeight.Bold).margin({ left: 12 }); }.width('100%').height(76).padding({ left: 14 }).backgroundColor(Color.White); Scroll() { Column() { Text(this.title).fontSize(24).fontWeight(FontWeight.Bold).width('100%'); Text(this.content).fontSize(19).fontColor('#444444').width('100%').margin({ top: 18 }); Divider().margin({ top: 28, bottom: 18 }); Text('回复').fontSize(21).fontWeight(FontWeight.Bold).width('100%'); TextInput({ placeholder: '写下你的回复...', text: this.replyText }).onChange((value: string) => { this.replyText = value; }).fontSize(18).height(150).width('100%').margin({ top: 14 }); Button('提交回复').width('100%').height(52).fontSize(18).fontColor(Color.White).backgroundColor('#20C894').borderRadius(26).margin({ top: 20 }).onClick(() => this.submitReply()); }.width('100%').padding(24); }.layoutWeight(1).backgroundColor('#F5F6F8'); }.width('100%').height('100%').backgroundColor('#F5F6F8'); }
}
