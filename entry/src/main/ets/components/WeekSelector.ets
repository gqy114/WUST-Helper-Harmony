/**
 * WeekSelector - 教学周选择器。
 *
 * 每个教学周为一个横向排列的单元，单元内使用 6 行 x 7 列圆点：
 * - 6 行依次对应第 1-2 节、第 3-4 节 ... 第 11-12 节
 * - 7 列对应周一到周日
 * - 绿色圆点表示该时间段有课，灰色圆点表示没有课
 */
import { CourseData, isCourseInWeek } from '../model/CourseModel';

const WEEK_NUMBERS: number[] = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
  11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  21, 22, 23, 24, 25
];
const DOT_ROWS: number[] = [0, 1, 2, 3, 4, 5];
const DAY_COLUMNS: number[] = [0, 1, 2, 3, 4, 5, 6];

// 取自 Android 解包 colors.xml：colorTab / white_with_alpha_80 / colorBlock / colorTabViewDefault / colorTabText。
const COLOR_PANEL = '#EBFDF0';
const COLOR_ITEM_SELECTED = '#FFFFFF';
const COLOR_DOT_ACTIVE = '#74FF90';
const COLOR_DOT_EMPTY = '#CECCCC';
const COLOR_TEXT = '#768486';

@Component
export struct WeekSelector {
  /** 当前选中教学周，1 起。 */
  @Prop currentWeek: number = 1;
  /** 真实本周，用于“（本周）”标记，不跟随选中周移动。 */
  @Prop actualCurrentWeek: number = 1;
  /** 总教学周数。 */
  private totalWeeks: number = 25;
  /** 全部课程，不过滤周次，用于计算每周是否有课。 */
  private courseList: CourseData[] = [];
  /** 选择教学周回调。 */
  private onWeekSelect?: (week: number) => void;

  private hasCourseInSlot(week: number, row: number, col: number): boolean {
    const startPeriod = row * 2 + 1;
    const endPeriod = row * 2 + 2;
    for (const course of this.courseList) {
      if (isCourseInWeek(course, week)
        && course.dayOfWeek === col + 1
        && course.startPeriod <= endPeriod
        && course.endPeriod >= startPeriod) {
        return true;
      }
    }
    return false;
  }

  @Builder
  private weekItem(week: number) {
    Column() {
      Text(`第${week}周`)
        .fontSize(11)
        .fontColor(COLOR_TEXT)
        .margin({ top: 5 })

      Column() {
        ForEach(DOT_ROWS, (row: number) => {
          Row() {
            ForEach(DAY_COLUMNS, (col: number) => {
              Text('')
                .width(4)
                .height(4)
                .borderRadius(2)
                .backgroundColor(this.hasCourseInSlot(week, row, col) ? COLOR_DOT_ACTIVE : COLOR_DOT_EMPTY)
                .margin({ left: 1, right: 1, top: 1, bottom: 1 })
            }, (col: number) => `dot-${week}-${row}-${col}`)
          }
        }, (row: number) => `row-${week}-${row}`)
      }
      .margin({ top: 4, bottom: 5 })

      if (week === this.actualCurrentWeek) {
        Text('（本周）')
          .fontSize(11)
          .fontColor('#666666')
          .margin({ top: 6 })
      }
    }
    .width(56)
    .height(92)
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(6)
    .backgroundColor(week === this.currentWeek ? COLOR_ITEM_SELECTED : Color.Transparent)
    .margin({ top: 6, bottom: 6 })
    .onClick(() => {
      if (this.onWeekSelect !== undefined && this.onWeekSelect !== null) {
        this.onWeekSelect(week);
      }
    })
  }

  build() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(WEEK_NUMBERS.filter((week: number) => week <= this.totalWeeks), (week: number) => {
          this.weekItem(week)
        }, (week: number) => `week-${week}`)
      }
      .padding({ left: 8, right: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .friction(0.8)
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PANEL)
  }
}
