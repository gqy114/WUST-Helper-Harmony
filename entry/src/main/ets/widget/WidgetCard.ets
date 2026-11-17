/**
 * 桌面小组件卡片 UI。
 *
 * 数据由 EntryFormAbility 通过 formBindingData 注入，
 * 卡片内部只做展示，不访问网络，也不读写 Preferences。
 */
const LINE_COUNT = 4;

let widgetStorage: LocalStorage = new LocalStorage();

@Entry(widgetStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('mode') mode: string = 'countdown';
  @LocalStorageProp('title') title: string = '武科大助手';
  @LocalStorageProp('subtitle') subtitle: string = '正在加载数据…';
  @LocalStorageProp('line0') line0: string = '';
  @LocalStorageProp('line1') line1: string = '';
  @LocalStorageProp('line2') line2: string = '';
  @LocalStorageProp('line3') line3: string = '';
  @LocalStorageProp('days') days: string = '';
  @LocalStorageProp('detail') detail: string = '';
  @LocalStorageProp('accent') accent: string = '#EC5A3C';
  @LocalStorageProp('bg') bg: string = '';
  @LocalStorageProp('bgOpacity') bgOpacity: number = 0.7;
  @LocalStorageProp('cardBg') cardBg: string = '#FFFFFF';
  @LocalStorageProp('textColor') textColor: string = '#111111';
  @LocalStorageProp('subColor') subColor: string = '#666666';

  private lineAt(index: number): string {
    if (index === 0) return this.line0;
    if (index === 1) return this.line1;
    if (index === 2) return this.line2;
    return this.line3;
  }

  private lineIndexes(): number[] {
    const result: number[] = [];
    for (let i = 0; i < LINE_COUNT; i++) result.push(i);
    return result;
  }

  @Builder
  private countdownContent() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.line0.length > 0) {
          Text(this.line0)
            .fontSize(13)
            .fontColor(this.subColor)
            .maxLines(1)
            .margin({ top: 6 })
            .width('100%')
        }
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(12)
            .fontColor(this.subColor)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .height('100%')

      Column() {
        if (this.days.length > 0) {
          Text(this.days)
            .fontSize(52)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accent)
            .maxLines(1)
          Text('天')
            .fontSize(13)
            .fontColor(this.subColor)
        } else {
          Text('—')
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.subColor)
        }
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width(96)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private courseContent() {
    Column() {
      Row() {
        Column() {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.subtitle)
            .fontSize(12)
            .fontColor(this.accent)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Divider().color('#33000000').margin({ top: 8, bottom: 6 }).strokeWidth(0.5)

      Column() {
        ForEach(this.lineIndexes(), (index: number) => {
          if (this.lineAt(index).length > 0) {
            Text(this.lineAt(index))
              .fontSize(12)
              .fontColor(this.subColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ bottom: 4 })
          }
        }, (index: number) => `${index}-${this.lineAt(index)}`)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      // 底色 + 背景图；不透明度只作用于背景图，不影响文字。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.cardBg)
      if (this.bg.length > 0) {
        Image(this.bg)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.bgOpacity)
      }

      Column() {
        if (this.mode === 'countdown') {
          this.countdownContent()
        } else {
          this.courseContent()
        }
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {
          message: 'open'
        }
      });
    })
  }
}
