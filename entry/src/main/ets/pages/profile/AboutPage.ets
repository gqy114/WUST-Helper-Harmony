import { promptAction, router } from '@kit.ArkUI';

@Entry
@Component
struct AboutPage {
  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(32)
          .fontColor('#333333')
          .width(40)
          .height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back());

        Text('关于APP')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ left: 8 });
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor('#FFFFFF');

      Scroll() {
        Column() {
          Column() {
            Image($r('app.media.logo'))
              .width(80)
              .height(80)
              .borderRadius(12)
              .margin({ top: 48, bottom: 20 });

            Text('武科大助手')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333');

            Text('v5.3.0.172')
              .fontSize(18)
              .fontColor('#666666')
              .margin({ top: 8 });
          }
          .width('100%')
          .backgroundColor('#F5F7FA')
          .padding({ bottom: 40 })
          .alignItems(HorizontalAlign.Center);

          Text('作者')
            .fontSize(14)
            .fontColor('#999999')
            .width('100%')
            .padding({ left: 16, top: 20, bottom: 8 })
            .backgroundColor('#F5F7FA');

          this.aboutItem($r('app.media.person_edit'), '作者介绍', () => {
            promptAction.showDialog({
              title: '作者介绍',
              message: '武科大助手由武汉科技大学领航工作室开发与维护。\n\n我们致力于为武科大学生提供便捷、实用的校园服务。',
              buttons: [{ text: '知道了', color: '#1EC98D' }]
            });
          });

          Text('其它')
            .fontSize(14)
            .fontColor('#999999')
            .width('100%')
            .padding({ left: 16, top: 20, bottom: 8 })
            .backgroundColor('#F5F7FA');

          this.aboutItem($r('app.media.computer'), '领航官网', () => {
            router.pushUrl({
              url: 'pages/common/WebPage',
              params: { title: '领航官网', url: 'https://wustlinghang.cn' }
            });
          });

          this.aboutItem($r('app.media.description'), '用户协议与隐私政策', () => {
            router.pushUrl({
              url: 'pages/common/WebPage',
              params: { title: '用户协议与隐私政策', url: 'https://wusthelper.wustlinghang.cn/page/android_privacy.html' }
            });
          });
        }
        .width('100%');
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#F5F7FA');
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }

  @Builder
  aboutItem(icon: Resource, title: string, action: () => void) {
    Row() {
      Column() {
        Image(icon)
          .width(20)
          .height(20)
          .fillColor('#FFFFFF');
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor('#999999')
      .justifyContent(FlexAlign.Center)
      .margin({ right: 16 });

      Text(title)
        .fontSize(18)
        .fontColor('#333333')
        .layoutWeight(1);

      Text('›')
        .fontSize(24)
        .fontColor('#CCCCCC');
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
    .onClick(action);
  }
}

export { AboutPage };
