import { promptAction } from '@kit.ArkUI';
import { HotFeatureTopBar } from '../../components/HotFeatureTopBar';
import { AIApi } from '../../net/AIApi';

@Entry @Component
struct AIAssistantPage {
  @State private question: string = '';
  @State private answer: string = '';
  @State private loading: boolean = false;

  build() {
    Column() {
      HotFeatureTopBar({ title: 'AI问答' })
      Scroll() {
        Column() {
          if (this.answer) {
            Column() {
              // AI 生成标识放在每条回答最前面，避免用户误当成人工回复。
              Row() {
                Text('【AI生成】')
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#0E9F6E')
                  .backgroundColor('#E7F8F2').borderRadius(8)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                Blank()
                Text('仅供参考').fontSize(12).fontColor('#AAAAAA')
              }.width('100%').margin({ bottom: 12 })

              Text(this.answer).fontSize(17).fontColor('#444444').width('100%').lineHeight(26)
            }
            .width('100%').padding(18).backgroundColor(Color.White).borderRadius(16)
            .alignItems(HorizontalAlign.Start).margin({ bottom: 12 })

            Text('以下内容由AI生成，可能存在错误，仅供参考。')
              .fontSize(12).fontColor('#999999').width('100%').textAlign(TextAlign.Center)
              .margin({ top: 2, bottom: 12 })
          } else if (this.loading) {
            Column() {
              LoadingProgress().width(36).height(36).color('#1EC98D')
              Text('AI 正在生成…').fontSize(14).fontColor('#999999').margin({ top: 10 })
            }.width('100%').padding({ top: 50, bottom: 30 })
          } else {
            Text('有什么校园问题想问？').fontSize(18).fontColor('#999999').margin({ top: 60, bottom: 30 });
            Text('以下内容由AI生成，可能存在错误，仅供参考。')
              .fontSize(12).fontColor('#AAAAAA').textAlign(TextAlign.Center).width('100%');
          }
        }.width('100%').padding(16);
      }.layoutWeight(1);
      Row() {
        TextInput({ placeholder: '输入你的问题', text: this.question }).layoutWeight(1).height(48)
          .backgroundColor('#F2F3F5').borderRadius(12)
          .onChange((value: string) => { this.question = value; });
        Button(this.loading ? '回答中' : '发送')
          .enabled(!this.loading && this.question.trim().length > 0)
          .height(44).margin({ left: 10 }).backgroundColor('#1EC98D')
          .onClick(() => this.ask());
      }.width('100%').padding(12).backgroundColor(Color.White);
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }

  private async ask(): Promise<void> {
    const q = this.question.trim();
    if (!q) return;
    this.loading = true;
    try {
      this.answer = await AIApi.chat(q);
    } catch {
      promptAction.showToast({ message: 'AI 服务暂不可用', duration: 1500 });
    }
    this.loading = false;
  }
}
