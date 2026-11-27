import { DailyWidgetCourse } from './WidgetData';

const ROTATION_INTERVAL_MS: number = 20000;

@Component
export struct DailyWidgetCarousel {
  @Prop dateText: string = '';
  @Prop weekText: string = '';
  @Prop courses: string = '';
  @Prop emptyText: string = '';
  @Prop accent: string = '#EC5A3C';
  @Prop textColor: string = '#111111';
  @Prop subColor: string = '#666666';
  @State private locked: boolean = false;
  onSettings: () => void = () => {};
  onRefresh: () => void = () => {};

  private entries(): DailyWidgetCourse[] {
    try {
      return JSON.parse(this.courses || '[]') as DailyWidgetCourse[];
    } catch {
      return [];
    }
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        Column({ space: 1 }) {
          Text(this.dateText).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.textColor).maxLines(1)
          Text(this.weekText).fontSize(11).fontColor(this.subColor).maxLines(1)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.ic_widget_lock')).width(22).height(28).objectFit(ImageFit.Contain)
          .fillColor(this.locked ? '#61A5FA' : this.subColor)
          .accessibilityText(this.locked ? '取消锁定日课表' : '锁定日课表')
          .onClick(() => { this.locked = !this.locked; })
        Image($r('app.media.setting')).width(22).height(28).objectFit(ImageFit.Contain).fillColor(this.subColor)
          .accessibilityText('小组件设置').onClick(() => this.onSettings())
        Image($r('app.media.refresh')).width(22).height(28).objectFit(ImageFit.Contain).fillColor(this.subColor)
          .accessibilityText('刷新日课表').onClick(() => this.onRefresh())
      }.width('100%')

      Divider().color('#33808080').margin({ top: 6, bottom: 4 })
      if (this.entries().length > 0) {
        Swiper() {
          ForEach(this.entries(), (course: DailyWidgetCourse, index: number) => {
            Row({ space: 8 }) {
              Column({ space: 3 }) {
                Text(course.start).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.textColor)
                Text(course.end).fontSize(12).fontColor(this.subColor)
              }.alignItems(HorizontalAlign.Start)
              Column().width(3).height(30).borderRadius(2).backgroundColor(this.accent)
              Column({ space: 3 }) {
                Text(course.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                if (course.details.length > 0) {
                  Text(course.details).fontSize(12).fontColor(this.subColor)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%').height('100%').alignItems(VerticalAlign.Center)
          }, (course: DailyWidgetCourse, index: number) => `${index}-${JSON.stringify(course)}`)
        }
        .autoPlay(!this.locked && this.entries().length > 1)
        .loop(this.entries().length > 1)
        .interval(ROTATION_INTERVAL_MS)
        .vertical(true)
        .indicator(false)
        .width('100%')
        .layoutWeight(1)
      } else {
        Text(this.emptyText).fontSize(13).fontColor(this.subColor)
          .width('100%').textAlign(TextAlign.Center).layoutWeight(1)
      }
    }.width('100%').height('100%')
  }
}
