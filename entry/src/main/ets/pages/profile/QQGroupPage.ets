/**
 * QQ 用户群页面。
 *
 * 之前直接用 Web 打开 https://qm.qq.com/ ，该地址在没有加群参数时只会渲染空白页，
 * 既看不到群号也无法加群。这里改成原生页面：展示群号、一键复制，并提供加群引导。
 */
import { promptAction, router } from '@kit.ArkUI';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';

/** 官方用户群号，与后端 wusthelper_android.json 的 qqGroup 保持一致。 */
const QQ_GROUP_NUMBER = '648599822';

@Entry
@Component
struct QQGroupPage {
  private copyGroupNumber(): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, QQ_GROUP_NUMBER);
      pasteboard.getSystemPasteboard().setData(data)
        .then(() => {
          promptAction.showToast({ message: `已复制群号 ${QQ_GROUP_NUMBER}`, duration: 1800 });
        })
        .catch((error: BusinessError) => {
          console.warn('QQGroupPage', `copy failed: ${JSON.stringify(error)}`);
          promptAction.showToast({ message: '复制失败，请手动记录群号', duration: 1800 });
        });
    } catch (error) {
      console.warn('QQGroupPage', `pasteboard unavailable: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '复制失败，请手动记录群号', duration: 1800 });
    }
  }

  private openQqApp(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: 'mqq://'
      };
      context.startAbility(want).catch((error: BusinessError) => {
        console.warn('QQGroupPage', `open qq failed: ${JSON.stringify(error)}`);
        promptAction.showToast({ message: '未找到 QQ，请复制群号后手动打开', duration: 2200 });
      });
    } catch (error) {
      console.warn('QQGroupPage', `startAbility failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '未找到 QQ，请复制群号后手动打开', duration: 2200 });
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_left'))
          .width(24).height(24)
          .onClick(() => router.back())
        Text('QQ用户群')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#333333')
          .margin({ left: 8 })
      }
      .width('100%').height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Color.White)

      Column() {
        Image($r('app.media.ic_qq'))
          .width(72).height(72)
          .margin({ top: 40 })
        Text('武科大助手用户群')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
          .margin({ top: 18 })
        Text(QQ_GROUP_NUMBER)
          .fontSize(34).fontWeight(FontWeight.Bold).fontColor('#1ec98d')
          .margin({ top: 14 })
        Text('打开 QQ，通过“加好友/群 → 找群”搜索上面的群号即可加入。')
          .fontSize(14).fontColor('#888888')
          .textAlign(TextAlign.Center)
          .width('82%')
          .margin({ top: 12 })

        Row() {
          Button('复制群号')
            .fontSize(15).fontColor(Color.White)
            .backgroundColor('#1ec98d').borderRadius(8)
            .width(140).height(44)
            .onClick(() => this.copyGroupNumber())
          Button('打开 QQ')
            .fontSize(15).fontColor('#1ec98d')
            .backgroundColor(Color.White).borderRadius(8)
            .border({ width: 1, color: '#1ec98d' })
            .width(140).height(44)
            .margin({ left: 14 })
            .onClick(() => this.openQqApp())
        }
        .margin({ top: 28 })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%')
    .backgroundColor('#F5F5F5')
  }
}
