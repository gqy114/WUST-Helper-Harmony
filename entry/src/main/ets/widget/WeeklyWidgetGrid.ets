import { CourseTimeSlot, DAY_LABELS, PERIOD_COUNT, TIME_SLOTS } from '../model/CourseModel';
import { WeeklyWidgetCourse } from './WidgetData';

const TIME_COLUMN = 12;
const DAY_WIDTH = (100 - TIME_COLUMN) / DAY_LABELS.length;

/** Shared by the desktop form and the settings preview. */
@Component
export struct WeeklyWidgetGrid {
  @Prop courses: string = '';
  @Prop subtitle: string = '';
  @Prop textColor: string = '#111111';
  @Prop subColor: string = '#666666';

  private courseBlocks(): WeeklyWidgetCourse[] {
    if (this.courses.length === 0) return [];
    try {
      return JSON.parse(this.courses) as WeeklyWidgetCourse[];
    } catch {
      return [];
    }
  }

  build() {
    Column() {
      Row() {
        Blank().width(`${TIME_COLUMN}%`)
        ForEach(DAY_LABELS, (day: string) => {
          Text(day).width(`${DAY_WIDTH}%`).fontSize(11).fontColor(this.textColor).textAlign(TextAlign.Center)
        }, (day: string) => day)
      }.width('100%').height(19)

      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          ForEach(TIME_SLOTS, (slot: CourseTimeSlot) => {
            Row() {
              Column() {
                Text(slot.start).fontSize(8).fontColor(this.subColor).maxLines(1).minFontSize(6)
                Text(slot.end).fontSize(8).fontColor(this.subColor).maxLines(1).minFontSize(6)
              }.width(`${TIME_COLUMN}%`).alignItems(HorizontalAlign.Start)
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
          }, (slot: CourseTimeSlot) => slot.start)
        }.width('100%').height('100%')

        ForEach(this.courseBlocks(), (course: WeeklyWidgetCourse) => {
          Column() {
            Text(course.location ? `${course.name}\n@${course.location}` : course.name)
              .fontSize(9).fontColor(Color.White).textAlign(TextAlign.Center)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').height('100%')
              .align(Alignment.Top).padding(2)
          }
          .width(`${(DAY_WIDTH - 0.7) / course.lanes}%`)
          .height(`${(course.end - course.start + 1) * 100 / PERIOD_COUNT - 0.6}%`)
          .position({
            x: `${TIME_COLUMN + (course.day - 1) * DAY_WIDTH + course.lane * DAY_WIDTH / course.lanes}%`,
            y: `${(course.start - 1) * 100 / PERIOD_COUNT}%`
          })
          .backgroundColor(course.color).borderRadius(4).clip(true)
        }, (course: WeeklyWidgetCourse) => `${course.day}-${course.start}-${course.end}-${course.lane}-${course.name}`)

        if (this.courseBlocks().length === 0) {
          Text(this.subtitle).fontSize(12).fontColor(this.subColor).textAlign(TextAlign.Center)
            .width('88%').height('100%').position({ x: '12%', y: 0 })
        }
      }.width('100%').layoutWeight(1).clip(true)
    }.width('100%').height('100%')
  }
}
