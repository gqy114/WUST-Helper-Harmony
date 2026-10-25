import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CourseApi } from '../../net/CourseApi';
import { CourseData } from '../../model/CourseModel';
import { AppStorage } from '../../store/AppStorage';

interface CourseResultGroup {
  key: string;
  name: string;
  teacher: string;
  schedules: CourseData[];
}

@Entry
@Component
struct CourseSearchResultPage {
  @State private groups: CourseResultGroup[] = [];
  @State private scheduleCount: number = 0;
  @State private loading: boolean = true;
  @State private error: string = '';
  @State private expandedKeys: string[] = [];
  private params: Record<string, string> = {};

  aboutToAppear(): void {
    this.params = router.getParams() as Record<string, string>;
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const storage = AppStorage.getInstance();
      const semester = await storage.getSemester();
      const token = await storage.getToken();
      await CourseApi.getCourseTable(semester, token);
      const weekday = this.params.weekday || '';
      const weekDayNumber = weekday.length > 0 ? ['周一', '周二', '周三', '周四', '周五', '周六', '周日'].indexOf(weekday) + 1 : 0;
      const courses = await CourseApi.searchCourses(semester, token, this.params.courseName || '', this.params.teacher || '',
        this.params.classroom || '', weekDayNumber, Number(this.params.startPeriod || 0), Number(this.params.endPeriod || 0));
      this.scheduleCount = courses.length;
      this.groups = this.groupCourses(courses);
    } catch (error) {
      this.error = error instanceof Error ? error.message : '课程查询失败，请稍后重试';
      promptAction.showToast({ message: this.error, duration: 1800 });
    } finally { this.loading = false; }
  }

  private groupCourses(courses: CourseData[]): CourseResultGroup[] {
    const groups: CourseResultGroup[] = [];
    for (let i = 0; i < courses.length; i++) {
      const course = courses[i];
      const key = `${course.courseName}|${course.teacher}`;
      const index = groups.findIndex((group: CourseResultGroup) => group.key === key);
      if (index >= 0) groups[index].schedules.push(course);
      else groups.push({ key, name: course.courseName, teacher: course.teacher, schedules: [course] });
    }
    return groups;
  }

  private isExpanded(key: string): boolean { return this.expandedKeys.includes(key); }

  private toggleExpanded(key: string): void {
    if (this.isExpanded(key)) this.expandedKeys = this.expandedKeys.filter((item: string) => item !== key);
    else this.expandedKeys = this.expandedKeys.concat([key]);
  }

  private shownSchedules(group: CourseResultGroup): CourseData[] {
    return this.isExpanded(group.key) ? group.schedules : group.schedules.slice(0, 2);
  }

  private weekday(day: number): string {
    return day >= 1 && day <= 7 ? `周${['一', '二', '三', '四', '五', '六', '日'][day - 1]}` : '星期不限';
  }

  private filterSummary(): string {
    let text = `课程：${this.params.courseName || ''}`;
    if (this.params.teacher) text += ` · 教师：${this.params.teacher}`;
    if (this.params.classroom) text += ` · 教室：${this.params.classroom}`;
    if (this.params.weekday) text += ` · ${this.params.weekday}`;
    if (this.params.startPeriod) text += ` · 第${this.params.startPeriod}-${this.params.endPeriod}节`;
    return text;
  }

  @Builder
  private scheduleRow(item: CourseData) {
    Column() {
      Text(`${this.weekday(item.dayOfWeek)} · 第 ${item.startPeriod}-${item.endPeriod} 节`)
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#128E6B').width('100%');
      Text(`第 ${item.weekRanges || '不限'} 周`).fontSize(16).fontColor('#6F7E79').width('100%').margin({ top: 8 });
      Text(`教室 · ${item.location || '待定'}`).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#263B36')
        .width('100%').margin({ top: 8 });
    }.width('100%').padding({ top: 16, bottom: 16 }).border({ width: { bottom: 1 }, color: '#E7EAE9' })
  }

  @Builder
  private courseCard(group: CourseResultGroup) {
    Column() {
      Text(group.name).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#203C35').width('100%');
      Row() {
        Text(`授课教师 · ${group.teacher || '待定'}`).fontSize(16).fontColor('#6F7E79').layoutWeight(1);
        Text(`${group.schedules.length} 条上课安排`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#128E6B')
          .padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor('#EAF8F3').borderRadius(18);
      }.width('100%').margin({ top: 12, bottom: 2 });
      ForEach(this.shownSchedules(group), (item: CourseData) => { this.scheduleRow(item); },
        (item: CourseData) => `${item.dayOfWeek}-${item.startPeriod}-${item.endPeriod}-${item.weekRanges}-${item.location}`);
      if (group.schedules.length > 2) {
        Text(this.isExpanded(group.key) ? '收起安排 ↑' : `展开全部 ${group.schedules.length} 条安排 ↓`)
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#128E6B').textAlign(TextAlign.Center)
          .width('100%').height(54).backgroundColor('#EAF8F3').borderRadius(14).margin({ top: 14 })
          .onClick(() => this.toggleExpanded(group.key));
      }
    }.width('92%').padding({ left: 20, right: 20, top: 22, bottom: 20 }).backgroundColor(Color.White)
      .borderRadius(20).margin({ bottom: 16 }).border({ width: 1, color: '#E1E6E4' });
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(32).fontColor(Color.White).width(48).onClick(() => router.back());
        Text('课程搜索结果').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 12 });
        Blank().layoutWeight(1);
        Text('调整筛选').fontSize(16).fontColor(Color.White).onClick(() => router.back());
      }.width('100%').height(56).padding({ left: 16, right: 20 }).alignItems(VerticalAlign.Center).backgroundColor('#20C894');
      if (this.loading) {
        Column() { Text('正在查询课程…').fontSize(18).fontColor('#999999'); }.layoutWeight(1).justifyContent(FlexAlign.Center);
      } else if (this.error.length > 0) {
        Column() { Text(this.error).fontSize(18).fontColor('#999999'); Button('重试').margin({ top: 16 }).onClick(() => this.load()); }
          .layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        Scroll() {
          Column() {
            Column() {
              Text(`${this.groups.length} 个课程结果`).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#203C35').width('100%');
              Text(`${this.scheduleCount} 条上课安排`).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#71817C').width('100%').margin({ top: 8 });
              Text(this.filterSummary()).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#128E6B').width('100%')
                .padding(16).backgroundColor('#EAF8F3').borderRadius(14).margin({ top: 18 });
            }.width('100%').padding({ left: 26, right: 26, top: 28, bottom: 24 }).backgroundColor(Color.White);
            if (this.groups.length === 0) {
              Text('没有找到符合条件的课程').fontSize(18).fontColor('#999999').margin({ top: 80 });
            } else {
              Column() {
                ForEach(this.groups, (group: CourseResultGroup) => { this.courseCard(group); }, (group: CourseResultGroup) => group.key);
              }.width('100%').padding({ top: 20, bottom: 24 });
            }
          }.width('100%').alignItems(HorizontalAlign.Center);
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off);
      }
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
