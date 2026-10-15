import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { AIApi } from '../../net/AIApi';
@Entry @Component
struct AIAssistantPage {
  @State private question: string = '';
  @State private answer: string = '';
  @State private loading: boolean = false;
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('AI问答').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }); }.width('100%').height(76).padding({ left: 14 }).backgroundColor(Color.White);
      Scroll() { Column() { if (this.answer) { Text(this.answer).fontSize(17).fontColor('#444444').width('100%').padding(18).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 18 }); } else { Text('有什么校园问题想问？').fontSize(18).fontColor('#999999').margin({ top: 60, bottom: 30 }); } }.width('100%').padding(16); }.layoutWeight(1);
      Row() { TextInput({ placeholder: '输入你的问题', text: this.question }).layoutWeight(1).height(48).backgroundColor('#F2F3F5').borderRadius(12).onChange((value: string) => { this.question = value; }); Button(this.loading ? '回答中' : '发送').enabled(!this.loading && this.question.trim().length > 0).height(44).margin({ left: 10 }).backgroundColor('#1EC98D').onClick(() => this.ask()); }.width('100%').padding(12).backgroundColor(Color.White);
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
  private async ask(): Promise<void> { const q = this.question.trim(); if (!q) return; this.loading = true; try { this.answer = await AIApi.chat(q); } catch { promptAction.showToast({ message: 'AI 服务暂不可用', duration: 1500 }); } this.loading = false; }
}
