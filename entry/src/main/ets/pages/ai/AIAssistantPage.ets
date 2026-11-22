import { promptAction } from '@kit.ArkUI';
import { HotFeatureTopBar } from '../../components/HotFeatureTopBar';
import { AIApi } from '../../net/AIApi';

interface AiChatMessage {
  role: string;
  text: string;
}

interface AiSuggestion {
  icon: string;
  text: string;
}

const AI_SUGGESTIONS: AiSuggestion[] = [
  { icon: '📅', text: '这周课表' },
  { icon: '🎓', text: '什么时间考试' },
  { icon: '📍', text: '今天有哪些空教室' },
  { icon: '📢', text: '最近有什么公告' },
  { icon: '📖', text: '借阅证什么时候到期' },
  { icon: '🗓️', text: '校历在哪看' }
];

@Entry @Component
struct AIAssistantPage {
  @State private question: string = '';
  @State private messages: AiChatMessage[] = [];
  @State private loading: boolean = false;
  private listScroller: Scroller = new Scroller();

  private scrollToBottom(): void {
    setTimeout(() => {
      try { this.listScroller.scrollToIndex(this.messages.length - 1, false); } catch { /* 列表尚未渲染 */ }
    }, 50);
  }

  @Builder
  private userBubble(text: string) {
    Row() {
      Blank()
      Text(text).fontSize(16).fontColor(Color.White).lineHeight(24)
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#1EC98D').borderRadius(14)
        .constraintSize({ maxWidth: '78%' })
    }.width('100%').margin({ bottom: 14 })
  }

  @Builder
  private aiBubble(text: string) {
    Column() {
      // AI 生成标识放在每条回答最前面，避免用户误当成人工回复。
      Row() {
        Text('【AI生成】')
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#0E9F6E')
          .backgroundColor('#E7F8F2').borderRadius(8)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        Blank()
        Text('仅供参考').fontSize(12).fontColor('#AAAAAA')
      }.width('100%').margin({ bottom: 10 })

      Text(text).fontSize(16).fontColor('#444444').width('100%').lineHeight(25)
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(16)
    .alignItems(HorizontalAlign.Start).margin({ bottom: 6 })
  }

  build() {
    Column() {
      HotFeatureTopBar({ title: 'AI问答' })

      List({ scroller: this.listScroller }) {
        if (this.messages.length === 0) {
          ListItem() {
            Column() {
              Image($r('app.media.ai_mascot'))
                .width('78%').objectFit(ImageFit.Contain).margin({ top: 0 })
              Text('有什么校园问题想问？')
                .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#222222').margin({ top: 10 })
              Text('以下内容由AI生成，可能存在错误，仅供参考。')
                .fontSize(13).fontColor('#888888').margin({ top: 10 }).textAlign(TextAlign.Center)

              Row() {
                Text('✦').fontSize(22).fontColor('#1EC98D').margin({ right: 10, top: 1 })
                Text('我可以帮你回答课表、考试、空教室、图书馆、校历、校园公告等问题。')
                  .fontSize(15).fontColor('#3D5A50').lineHeight(22).layoutWeight(1)
              }.width('100%').padding(14).backgroundColor('#EAF8F2').borderRadius(16).margin({ top: 16 })
              .alignItems(VerticalAlign.Top)

              Row() {
                Column().width(4).height(18).backgroundColor('#1EC98D').borderRadius(2).margin({ right: 8 })
                Text('试试这些问题：').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#333333')
              }.width('100%').margin({ top: 16, bottom: 10 })

              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(AI_SUGGESTIONS, (item: AiSuggestion) => {
                  Row() {
                    Text(item.icon).fontSize(16).margin({ right: 6 })
                    Text(item.text).fontSize(14).fontColor('#333333').maxLines(2).lineHeight(19)
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                  }
                  .width('48%').height(52).padding({ left: 10, right: 8 })
                  .backgroundColor('#F1FAF5').borderRadius(12).margin({ bottom: 10 })
                  .onClick(() => { this.question = item.text; this.ask(); })
                }, (item: AiSuggestion) => item.text)
              }.width('100%')
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 24 })
            .alignItems(HorizontalAlign.Center)
          }
        }
        ForEach(this.messages, (message: AiChatMessage) => {
          ListItem() {
            if (message.role === 'user') {
              this.userBubble(message.text)
            } else {
              this.aiBubble(message.text)
            }
          }
        }, (message: AiChatMessage, index: number) => `${index}-${message.role}-${message.text}`)

        if (this.loading) {
          ListItem() {
            Row() {
              LoadingProgress().width(26).height(26).color('#1EC98D')
              Text('AI 正在生成…').fontSize(14).fontColor('#999999').margin({ left: 8 })
            }.width('100%').padding({ left: 10, top: 6, bottom: 10 })
          }
        }
      }
      .width('100%').layoutWeight(1).padding(16).scrollBar(BarState.Off)
      .backgroundColor('#F5F6F8')

      Row() {
        TextInput({ placeholder: '输入你的问题', text: this.question }).layoutWeight(1).height(48)
          .backgroundColor('#F2F3F5').borderRadius(12)
          .onChange((value: string) => { this.question = value; })
          .onSubmit(() => this.ask());
        Button(this.loading ? '回答中' : '发送')
          .enabled(!this.loading && this.question.trim().length > 0)
          .height(44).margin({ left: 10 }).backgroundColor('#1EC98D')
          .onClick(() => this.ask());
      }.width('100%').padding(12).backgroundColor(Color.White);
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }

  private async ask(): Promise<void> {
    const q = this.question.trim();
    if (!q || this.loading) return;
    this.messages = this.messages.concat([{ role: 'user', text: q }]);
    this.question = '';
    this.loading = true;
    this.scrollToBottom();
    try {
      const answer = await AIApi.chat(q);
      this.messages = this.messages.concat([{ role: 'ai', text: answer }]);
    } catch {
      promptAction.showToast({ message: 'AI 服务暂不可用', duration: 1500 });
    }
    this.loading = false;
    this.scrollToBottom();
  }
}
