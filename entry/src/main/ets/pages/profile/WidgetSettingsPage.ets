import { router, promptAction } from '@kit.ArkUI';

const WIDGET_TABS: string[] = ['倒计时', '每日课表', '每周课表'];
const WEEK_DAYS: string[] = ['日', '一', '二', '三', '四', '五', '六'];
const PREVIEW_ROWS: number[] = [1, 2, 3, 4];

@Entry
@Component
struct WidgetSettingsPage {
  @State private selectedTab: number = 0;
  @State private opacityValue: number = 72;

  @Builder
  private toolbarIcon(label: string) {
    Text(label)
      .fontSize(27)
      .fontColor('#666666')
      .width(42)
      .height(42)
      .textAlign(TextAlign.Center)
  }

  @Builder
  private previewHeader() {
    Row() {
      if (this.selectedTab === 0) {
        Text('倒计时').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111111').layoutWeight(1)
      } else if (this.selectedTab === 1) {
        Text('10月27日  第6周 Tue.').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111111').layoutWeight(1)
      } else {
        Text('Tue.  第6周').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111111').layoutWeight(1)
      }
      this.toolbarIcon('⚙')
      Image($r('app.media.refresh')).width(27).height(27).fillColor('#666666').margin({ left: 7, right: 9 })
      if (this.selectedTab === 0) {
        this.toolbarIcon('+')
      } else if (this.selectedTab === 2) {
        Image($r('app.media.keyboard_arrow_down')).width(27).height(27).fillColor('#777777')
      }
    }
    .width('100%')
    .height(72)
    .padding({ left: 20, right: 14 })
  }

  @Builder
  private weeklyCourse(title: string, background: string, top: number = 0) {
    Text(title)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .textAlign(TextAlign.Center)
      .maxLines(4)
      .width(43)
      .height(62)
      .padding(4)
      .borderRadius(8)
      .backgroundColor(background)
      .margin({ top: top })
  }

  @Builder
  private weeklyPreview() {
    Column() {
      Row() {
        Blank().width(42)
        ForEach(WEEK_DAYS, (day: string) => {
          Text(day).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#111111').layoutWeight(1).textAlign(TextAlign.Center)
        })
      }.width('100%').height(28)
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          ForEach(PREVIEW_ROWS, () => {
            Row() {
              Text('08:00\n\n10:00').fontSize(10).fontWeight(FontWeight.Medium).fontColor('#222222').width(42).height(72)
              Blank().layoutWeight(1)
            }.width('100%').height(72)
          })
        }.width('100%')
        Row() {
          Blank().width(47)
          this.weeklyCourse('高等数学\n@教三楼', '#FFA3AD')
          Blank().width(58)
          this.weeklyCourse('大学英语\n@教四楼', '#59ADEC', 55)
          Blank().width(58)
          this.weeklyCourse('专业课程\n@实验楼', '#FF8568', 110)
        }.width('100%')
      }.width('100%').height(288)
    }.width('100%')
  }

  @Builder
  private previewContent() {
    Column() {
      this.previewHeader()
      if (this.selectedTab === 0) {
        Text('计划使生活更精彩，快添加你的计划吧')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#111111')
          .textAlign(TextAlign.Center).width('88%').margin({ top: 34 })
      } else if (this.selectedTab === 1) {
        Divider().color('#EEEEEE')
        Text('今天没有课程了')
          .fontSize(25).fontWeight(FontWeight.Bold).fontColor('#111111')
          .width('100%').textAlign(TextAlign.Center).margin({ top: 54 })
      } else {
        this.weeklyPreview()
      }
    }
    .width('100%')
    .height(this.selectedTab === 2 ? 410 : 220)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .border({ width: 1, color: '#E4E4E4' })
  }

  @Builder
  private appearanceRow(title: string, trailing: string = '') {
    Row() {
      Text(title).fontSize(19).fontWeight(FontWeight.Medium).fontColor('#222222').layoutWeight(1)
      if (trailing.length > 0) {
        Text(trailing).fontSize(24).fontColor('#000000').margin({ right: 18 })
      }
      Image($r('app.media.ic_arrow_right')).width(22).height(22).fillColor('#777777')
    }
    .width('100%').height(62).padding({ left: 20, right: 18 }).backgroundColor('#FFFFFF')
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_left')).width(27).height(27).fillColor('#222222').onClick(() => router.back())
        Text('小组件设置').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#222222').margin({ left: 17 })
        Blank()
        Image($r('app.media.help')).width(29).height(29).fillColor('#777777')
          .onClick(() => promptAction.showToast({ message: '小组件帮助功能开发中', duration: 1500 }))
      }.width('100%').height(70).padding({ left: 18, right: 20 }).backgroundColor('#FFFFFF')

      Row() {
        ForEach(WIDGET_TABS, (tab: string, index: number) => {
          Column() {
            Text(tab).fontSize(19).fontWeight(FontWeight.Bold)
              .fontColor(this.selectedTab === index ? '#20C997' : '#111111')
              .height(57).textAlign(TextAlign.Center)
            Divider().strokeWidth(3).color(this.selectedTab === index ? '#20C997' : '#FFFFFF')
          }.layoutWeight(1).onClick(() => { this.selectedTab = index; })
        })
      }.width('100%').height(60).backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          Text('效果预览').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#A7ABB3')
            .width('100%').margin({ bottom: 10 })
          this.previewContent()
          Text('外观').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#A7ABB3')
            .width('100%').margin({ top: 18, bottom: 10 })
          Column() {
            this.appearanceRow('自定义背景')
            Divider().color('#EEEEEE').margin({ left: 20 })
            this.appearanceRow('默认主题')
            Divider().color('#EEEEEE').margin({ left: 20 })
            this.appearanceRow('标题颜色', '●')
            Divider().color('#EEEEEE').margin({ left: 20 })
            Row() {
              Text('不透明度').fontSize(19).fontWeight(FontWeight.Medium).fontColor('#222222').width(108)
              Slider({ value: this.opacityValue, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
                .selectedColor('#20C997').trackColor('#999999').blockColor('#20C997').layoutWeight(1)
                .onChange((value: number) => { this.opacityValue = Math.round(value); })
              Text(`${this.opacityValue}%`).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20C997')
                .width(58).textAlign(TextAlign.End)
            }.width('100%').height(66).padding({ left: 20, right: 18 }).backgroundColor('#FFFFFF')
          }.width('100%').borderRadius(13).clip(true)
        }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 30 })
      }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8')
    }.width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}
