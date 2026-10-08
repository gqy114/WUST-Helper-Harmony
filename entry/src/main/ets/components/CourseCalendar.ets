/**
 * CourseCalendar — 课表网格画布
 *
 * 使用 Stack + 绝对定位 实现课程色块叠加效果：
 *   底层：背景网格（12 行 × 7 列）+ 节次号
 *   上层：CourseItem 色块（根据 dayOfWeek/startPeriod/endPeriod 定位）
 *
 * 每个课程色块的位置计算：
 *   x = LABEL_WIDTH + (dayOfWeek - 1) × columnWidth
 *   y = (startPeriod - 1) × PERIOD_HEIGHT
 *   width  = columnWidth
 *   height = (endPeriod - startPeriod + 1) × PERIOD_HEIGHT - 2
 *   columnWidth = (gridWidth - LABEL_WIDTH) / 7
 */
/**
 * CourseCalendar — 课表网格画布
 *
 * 文件路径：entry/src/main/ets/components/CourseCalendar.ets
 */
import { CourseData, LABEL_WIDTH, PERIOD_HEIGHT, DAY_LABELS, TIME_SLOTS, CourseTimeSlot, isCourseInWeek } from '../model/CourseModel';
import { CourseItem } from './CourseItem';
import { CourseStore } from '../store/CourseStore';

const PERIOD_ARRAY: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const DAYS_7: number[] = [1, 2, 3, 4, 5, 6, 7];
const WEEKDAY_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const PERIOD_SLOT_HEIGHT: number = PERIOD_HEIGHT * 2 + 5;

@Component
export struct CourseCalendar {
  /** 当前周的课程（已过滤） */
  @Prop courseList: CourseData[] = [];
  /** 当前周次 */
  @Prop currentWeek: number = 1;
  /** 周次变化时的强制刷新标记。 */
  @Prop refreshKey: number = 0;
  /** 当前周 7 天日期，由 CoursePage 计算后传入。 */
  @Prop weekDates: string[] = [];
  /** 左侧月份，由 CoursePage 根据当前周计算。 */
  @Prop monthLabel: string = '9月';
  /** 课程点击回调 */
  onCourseClick?: (course: CourseData) => void;

  @State private gridWidth: number = 360;
  @State private columnWidth: number = 50;

  aboutToAppear(): void {
    console.info("CourseCalendar", "aboutToAppear start");
    console.info("CourseCalendar", `aboutToAppear currentWeek=${this.currentWeek}`);
    const testCourse: CourseData = {
      courseName: '测试',
      teacher: '测试',
      location: '测试',
      dayOfWeek: 2,
      startPeriod: 5,
      endPeriod: 6,
      weekRanges: '2,4,6,8,10,12,14,16',
      color: '#FF0000'
    };
    const r2 = isCourseInWeek(testCourse, 2);
    const r1 = isCourseInWeek(testCourse, 1);
    console.info('CourseCalendar', `硬编码测试 week2=${r2} week1=${r1}`);
    const storeCourses = CourseStore.getInstance().courses;
    console.info("CourseCalendar", `aboutToAppear courseListLen=${this.courseList ? this.courseList.length : 0}, storeLen=${storeCourses ? storeCourses.length : 0}`);
    this.calcColumnWidth();
    console.info("CourseCalendar", `init: gridWidth=${this.gridWidth}, columnWidth=${this.columnWidth}, LABEL_WIDTH=${LABEL_WIDTH}, PERIOD_HEIGHT=${PERIOD_HEIGHT}`);
  }

  aboutToUpdate(): void {
    const storeCourses = CourseStore.getInstance().courses;
    console.info("CourseCalendar", `aboutToUpdate courseListLen=${this.courseList ? this.courseList.length : 0}, storeLen=${storeCourses ? storeCourses.length : 0}`);
  }

  private calcColumnWidth(): void {
    const gw = typeof this.gridWidth === 'number' && !isNaN(this.gridWidth) ? this.gridWidth : 360;
    const lw = typeof LABEL_WIDTH === 'number' && !isNaN(LABEL_WIDTH) ? LABEL_WIDTH : 36;
    const w = (gw - lw) / 7;
    this.columnWidth = (!isNaN(w) && w > 0) ? w : 50;
    console.info("CourseCalendar", `calcColumnWidth: gridWidth=${this.gridWidth}, columnWidth=${this.columnWidth}`);
  }

  private todayWeekday(): number {
    const day = new Date().getDay();
    return day === 0 ? 7 : day;
  }

  build() {
    Column() {
      // ── 日头 ──
      Row() {
        Text(this.monthLabel).width(LABEL_WIDTH).fontSize(12).fontColor('#666666')
          .fontWeight(FontWeight.Medium).textAlign(TextAlign.Center)
        ForEach(DAYS_7, (day: number) => {
          Column() {
            Text(WEEKDAY_NAMES[day - 1]).fontSize(13).fontWeight(FontWeight.Medium)
              .fontColor(day === this.todayWeekday() ? '#2196F3' : '#666666')
            Text(this.weekDates[day - 1] ? this.weekDates[day - 1] : '').fontSize(10)
              .fontColor(day === this.todayWeekday() ? '#2196F3' : '#999999')
              .margin({ top: 3 })
          }
          .width(this.columnWidth)
          .alignItems(HorizontalAlign.Center)
        })
      }.width('100%').height(52).backgroundColor(Color.White).border({
        width: { bottom: 0.5 },
        color: '#E0E0E0',
      })

      // ── 课表网格 ──
      Scroll() {
        Stack() {
          // 背景网格
          Column() {
            ForEach(TIME_SLOTS, (slot: CourseTimeSlot) => {
              Column() {
                Row() {
                  Column() {
                    Text(slot.start).fontSize(10).fontColor('#999999')
                    Text('|').fontSize(10).fontColor('#CCCCCC').margin({ top: 2, bottom: 2 })
                    Text(slot.end).fontSize(10).fontColor('#999999')
                  }
                  .width(LABEL_WIDTH)
                  .height(PERIOD_SLOT_HEIGHT)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  ForEach(DAYS_7, () => {
                    Text('').width(this.columnWidth - 1).height(PERIOD_SLOT_HEIGHT)
                  })
                }.width('100%').height(PERIOD_SLOT_HEIGHT)
                Divider().height(0.5).color('#EEEEEE').width('100%')
              }
            })
          }
          .width('100%')

          // 课程色块（绝对定位）
          ForEach(this.courseList, (course: CourseData) => {
            Stack() {
              CourseItem({
                courseName: course.courseName,
                teacher: course.teacher,
                location: course.location,
                color: course.color ? course.color : '#66cc99',
                isDimmed: !isCourseInWeek(course, this.currentWeek),   // 直接内联计算
                onItemTap: () => {
                  if (this.onCourseClick !== undefined && this.onCourseClick !== null) {
                    this.onCourseClick(course);
                  }
                },
              })
            }
            .position({
              x: (typeof LABEL_WIDTH === 'number' ? LABEL_WIDTH : 36) + (course.dayOfWeek - 1) * this.columnWidth + 1,
              y: (course.startPeriod - 1) * ((typeof PERIOD_HEIGHT === 'number' ? PERIOD_HEIGHT : 60) + 5) + 1,
            })
            .width(this.columnWidth - 3)
            .height((course.endPeriod - course.startPeriod + 1) * ((typeof PERIOD_HEIGHT === 'number' ? PERIOD_HEIGHT : 60) + 5) - 3)
          }, (course: CourseData) => `${this.refreshKey}-${course.dayOfWeek}-${course.startPeriod}-${course.courseName}`)
        }
        .width('100%')
        .height(TIME_SLOTS.length * PERIOD_SLOT_HEIGHT + 10)
        .onAreaChange((_old: Area, newArea: Area) => {
          const raw = newArea.width;
          const w = typeof raw === 'number' && !isNaN(raw) && raw > 0 ? raw : 360;
          if (Math.abs(w - this.gridWidth) > 0.5) {
            this.gridWidth = w;
            this.calcColumnWidth();
          }
        })
      }
      .width('100%')
    }
    .width('100%')
  }
}
