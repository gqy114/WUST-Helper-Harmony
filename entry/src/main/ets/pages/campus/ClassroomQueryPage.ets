/** 教室查询入口页 */
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct ClassroomQueryPage {
  @Builder
  private QueryCard(title: string, subtitle: string, icon: Resource, onClick: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#3A3A3A')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Clip })
        Text(subtitle).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#777777').margin({ top: 12 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image(icon).width(92).height(92).objectFit(ImageFit.Contain).margin({ right: 18 })
    }
    .width('100%').height(178).padding({ left: 28, right: 8 })
    .backgroundColor(Color.White).borderRadius(20)
    .shadow({ radius: 8, color: '#22000000', offsetX: 0, offsetY: 2 }).onClick(onClick)
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_left')).width(24).height(24).objectFit(ImageFit.Contain)
          .fillColor(Color.White).onClick(() => router.back())
        Text('教室查询').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 12 })
      }.width('100%').height(56).padding({ left: 16 }).alignItems(VerticalAlign.Center).backgroundColor('#23C087')

      Scroll() {
        Column() {
          this.QueryCard('空教室查询', '找个教室去办活动咯～', $r('app.media.new_location'), () => {
            promptAction.showToast({ message: '空教室查询即将开放', duration: 1500 })
          })
          Column() {
            this.QueryCard('课程查询', '去蹭喜欢老师の课吧～', $r('app.media.new_note'), () => {
              promptAction.showToast({ message: '课程查询即将开放', duration: 1500 })
            })
          }.margin({ top: 44 })
          Blank().layoutWeight(1)
          Text('领航工作室出品').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#888888').margin({ bottom: 22 })
        }.width('100%').height('100%').padding({ left: 45, right: 45, top: 110 })
      }.layoutWeight(1).width('100%').backgroundColor('#FAFAFA').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#FAFAFA')
  }
}
