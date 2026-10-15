import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi } from '../../net/CampusWallApi';

@Entry @Component
struct CampusPublishPage {
  @State private title: string = '';
  @State private content: string = '';
  @State private tag: string = 'wall';
  @State private label: string = '发布新鲜事';
  aboutToAppear(): void { const params = router.getParams() as Record<string, string>; if (params) { this.tag = params['tag'] || 'wall'; this.label = params['label'] || '发布新鲜事'; } }
  private async submit(): Promise<void> { if (this.title.trim().length === 0 || this.content.trim().length === 0) { promptAction.showToast({ message: '请填写标题和内容', duration: 1200 }); return; } try { await CampusWallApi.publish(this.title.trim(), this.content.trim(), this.tag); promptAction.showToast({ message: '发布成功', duration: 1200 }); router.back(); } catch { promptAction.showToast({ message: '发布失败，请稍后重试', duration: 1500 }); } }
  build() { Column() { Row() { Text('‹').fontSize(42).width(48).onClick(() => router.back()); Text(this.label).fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }); Blank().layoutWeight(1); Text('发布').fontSize(18).fontColor('#20C894').onClick(() => this.submit()); }.width('100%').height(76).padding({ left: 14, right: 20 }).backgroundColor(Color.White); Column() { TextInput({ placeholder: '请输入标题', text: this.title }).onChange((value: string) => { this.title = value; }).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 24 }); TextInput({ placeholder: '请输入内容', text: this.content }).onChange((value: string) => { this.content = value; }).fontSize(18).height(220).margin({ top: 16 }); }.width('100%').padding(24).layoutWeight(1).backgroundColor('#F5F6F8'); }.width('100%').height('100%').backgroundColor('#F5F6F8'); }
}
