import { router, promptAction } from '@kit.ArkUI';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import { calendarManager } from '@kit.CalendarKit';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';
import { CourseData, TIME_SLOTS, isCourseInWeek } from '../../model/CourseModel';
import { CourseStore } from '../../store/CourseStore';

@Entry
@Component
struct ScheduleSetting {
  @State private courseAsHome: boolean = true;
  @State private sundayFirst: boolean = false;
  @State private allWeeksImported: boolean = false;
  @State private importing: boolean = false;
  private importedEventIds: number[] = [];
  private courseList: CourseData[] = [];
  private currentWeek: number = 1;
  private semesterStart: Date = new Date(2025, 8, 1);
  private semester: string = '';

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const storage = PreferencesStorage.getInstance();
    this.courseAsHome = await storage.getCourseAsHome();
    await storage.setCourseAsHome(this.courseAsHome);
    this.sundayFirst = await storage.getSundayFirst();
    this.allWeeksImported = await storage.getAllWeeksImported();
    this.importedEventIds = await storage.getImportedEventIds();
    this.semester = await storage.getSemester();
    if (!this.semester) {
      this.semester = CourseStore.getInstance().semester;
    }
    this.semesterStart = this.resolveSemesterStart(this.semester);
    const store = CourseStore.getInstance();
    this.courseList = Array.isArray(store.courses) ? [...store.courses] : [];
    this.currentWeek = store.currentWeek > 0 ? store.currentWeek : 1;
  }

  private async setCourseAsHome(value: boolean): Promise<void> {
    this.courseAsHome = value;
    await PreferencesStorage.getInstance().setCourseAsHome(value);
    AppStorage.setOrCreate<boolean>('courseAsHome', value);
    promptAction.showToast({
      message: value ? '已设置课表为主页' : '已取消课表为主页',
      duration: 1500
    });
  }

  private async setSundayFirst(value: boolean): Promise<void> {
    this.sundayFirst = value;
    await PreferencesStorage.getInstance().setSundayFirst(value);
    AppStorage.setOrCreate<boolean>('sundayFirst', value);
    promptAction.showToast({
      message: value ? '已设置周日为第一天' : '已恢复周一为第一天',
      duration: 1500
    });
  }

  private async requestCalendarPermission(): Promise<boolean> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, [
        'ohos.permission.READ_CALENDAR',
        'ohos.permission.WRITE_CALENDAR'
      ]);

      console.info('ScheduleSetting', `permission result: ${JSON.stringify(result)}`);
      const authResults = result.authResults;
      if (authResults && authResults.length >= 2) {
        const granted = authResults[0] === 0 && authResults[1] === 0;
        if (!granted) {
          promptAction.showToast({ message: '日历权限被拒绝，无法导入', duration: 2000 });
        }
        return granted;
      }
      promptAction.showToast({ message: '权限申请失败', duration: 1500 });
      return false;
    } catch (err) {
      console.error('ScheduleSetting', `permission error: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '权限申请失败', duration: 1500 });
      return false;
    }
  }

  private async getCalendar(): Promise<calendarManager.Calendar> {
    const manager = calendarManager.getCalendarManager(getContext(this) as common.Context);
    // 写入系统默认日历，确保系统日历应用可以直接显示事件。
    return await manager.getCalendar();
  }

  private resolveSemesterStart(semester: string): Date {
    const parts = semester.split('-');
    const firstYear = parts.length > 0 ? Number(parts[0]) : 0;
    const term = parts.length > 2 ? parts[2] : '1';
    if (!isNaN(firstYear) && firstYear > 2000) {
      // 第1学期从9月开始，第2学期从次年2月开始。
      return term === '2' ? new Date(firstYear + 1, 1, 17) : new Date(firstYear, 8, 1);
    }
    return new Date(2025, 8, 1);
  }

  private getMondayOfWeek(week: number): Date {
    const monday = new Date(this.semesterStart);
    monday.setDate(monday.getDate() + (week - 1) * 7);
    return monday;
  }

  private createEvent(course: CourseData, week: number): calendarManager.Event {
    const monday = this.getMondayOfWeek(week);
    const courseDate = new Date(monday);
    courseDate.setDate(monday.getDate() + course.dayOfWeek - 1);
    const slot = TIME_SLOTS[Math.floor((course.startPeriod - 1) / 2)] || TIME_SLOTS[0];
    const startParts = slot.start.split(':');
    const endParts = slot.end.split(':');
    const startTime = new Date(courseDate);
    startTime.setHours(Number(startParts[0]), Number(startParts[1]), 0, 0);
    const endTime = new Date(courseDate);
    endTime.setHours(Number(endParts[0]), Number(endParts[1]), 0, 0);
    return {
      type: calendarManager.EventType.NORMAL,
      title: course.courseName,
      location: { location: course.location || '', longitude: 0, latitude: 0 },
      startTime: startTime.getTime(),
      endTime: endTime.getTime(),
      description: `教师：${course.teacher || ''}`
    };
  }

  private async importCurrentWeekToCalendar(): Promise<void> {
    if (this.importing) {
      return;
    }
    const hasPermission = await this.requestCalendarPermission();
    if (!hasPermission) {
      return;
    }
    this.importing = true;
    try {
      const calendar = await this.getCalendar();
      let count = 0;
      for (let i = 0; i < this.courseList.length; i++) {
        const course = this.courseList[i];
        if (!isCourseInWeek(course, this.currentWeek)) {
          continue;
        }
        await calendar.addEvent(this.createEvent(course, this.currentWeek));
        count++;
      }
      promptAction.showToast({
        message: count > 0 ? '已导入当前周课程到日程' : '当前周没有可导入课程',
        duration: 1500
      });
    } catch (err) {
      console.error('ScheduleSetting', `import current week error: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '导入失败，请检查日历权限', duration: 2000 });
    } finally {
      this.importing = false;
    }
  }

  private async importAllWeeksToCalendar(): Promise<void> {
    if (this.importing) {
      return;
    }
    const hasPermission = await this.requestCalendarPermission();
    if (!hasPermission) {
      return;
    }
    this.importing = true;
    try {
      console.info('ScheduleSetting', '=== 开始导入所有周课程 ===');
      console.info('ScheduleSetting', `课程数量: ${this.courseList.length}`);

      if (this.courseList.length === 0) {
        this.allWeeksImported = false;
        await PreferencesStorage.getInstance().setAllWeeksImported(false);
        promptAction.showToast({ message: '没有可导入的课程', duration: 2000 });
        return;
      }

      const calendar = await this.getCalendar();
      console.info('ScheduleSetting', '已获取 WustHelper 课程日历');
      const ids: number[] = [];
      const totalWeeks = CourseStore.getInstance().totalWeeks > 0 ? CourseStore.getInstance().totalWeeks : 25;
      console.info('ScheduleSetting', `准备导入周数: ${totalWeeks}`);

      for (let week = 1; week <= totalWeeks; week++) {
        for (let i = 0; i < this.courseList.length; i++) {
          const course = this.courseList[i];
          if (!isCourseInWeek(course, week)) {
            continue;
          }

          const event = this.createEvent(course, week);
          console.info('ScheduleSetting',
            `创建事件: 第${week}周 ${course.courseName} ${event.startTime}-${event.endTime} @${course.location || ''}`);
          try {
            const eventId = await calendar.addEvent(event);
            console.info('ScheduleSetting', `事件创建成功: id=${eventId}`);
            ids.push(eventId);
          } catch (eventErr) {
            console.error('ScheduleSetting',
              `事件创建失败: ${course.courseName}, week=${week}, error=${JSON.stringify(eventErr)}`);
          }
        }
      }

      console.info('ScheduleSetting', `=== 导入完成，成功创建 ${ids.length} 个事件 ===`);
      if (ids.length === 0) {
        this.allWeeksImported = false;
        await PreferencesStorage.getInstance().setAllWeeksImported(false);
        await PreferencesStorage.getInstance().setImportedEventIds([]);
        promptAction.showToast({ message: '课程事件创建失败，未完成导入', duration: 2000 });
        return;
      }

      this.importedEventIds = ids;
      this.allWeeksImported = true;
      const storage = PreferencesStorage.getInstance();
      await storage.setAllWeeksImported(true);
      await storage.setImportedEventIds(ids);
      promptAction.showToast({ message: `成功导入 ${ids.length} 个课程到日程`, duration: 2000 });
    } catch (err) {
      console.error('ScheduleSetting', `import all weeks error: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: `导入失败: ${JSON.stringify(err)}`, duration: 2000 });
    } finally {
      this.importing = false;
    }
  }

  private async deleteImportedEvents(): Promise<void> {
    if (this.importing) {
      return;
    }
    this.importing = true;
    try {
      const calendar = await this.getCalendar();
      const ids = this.importedEventIds.length > 0
        ? this.importedEventIds
        : await PreferencesStorage.getInstance().getImportedEventIds();
      for (let i = 0; i < ids.length; i++) {
        const id = ids[i];
        await calendar.deleteEvent(id);
      }
      this.importedEventIds = [];
      this.allWeeksImported = false;
      const storage = PreferencesStorage.getInstance();
      await storage.setAllWeeksImported(false);
      await storage.setImportedEventIds([]);
      promptAction.showToast({ message: '已删除导入的日程', duration: 1500 });
    } catch (err) {
      console.error('ScheduleSetting', `delete events error: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '删除失败', duration: 1500 });
    } finally {
      this.importing = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor('#333333')
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())

        Text('课表~~日程')
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })

        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 16 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          Row() {
            Text('设置课表为主页').fontSize(16).fontColor('#333333')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.courseAsHome })
              .selectedColor('#82B1FF')
              .onChange((isOn: boolean) => this.setCourseAsHome(isOn))
          }
          .width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')

          Row() {
            Text('设置周日为每周第一天').fontSize(16).fontColor('#333333')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.sundayFirst })
              .selectedColor('#82B1FF')
              .onChange((isOn: boolean) => this.setSundayFirst(isOn))
          }
          .width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')

          Text('注：教务处周一为每周第一天')
            .fontSize(13).fontColor('#BBBBBB').width('100%')
            .textAlign(TextAlign.Center).padding({ top: 12, bottom: 12 })
            .backgroundColor('#FFFFFF')

          Blank().height(8)

          Row() {
            Text('将当前周课程导入日程').fontSize(16).fontColor('#333333')
            Blank()
            Text('导入')
              .fontSize(15).fontColor('#333333').backgroundColor('#B3D4FC')
              .borderRadius(8).padding({ left: 24, right: 24, top: 8, bottom: 8 })
              .onClick(() => this.importCurrentWeekToCalendar())
          }
          .width('100%').height(64).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')

          Row() {
            Text('将所有周课程导入日程').fontSize(16).fontColor('#333333')
            if (this.allWeeksImported) {
              Text('✓').fontSize(14).fontColor('#FFFFFF').width(20).height(20)
                .textAlign(TextAlign.Center).backgroundColor('#009688').borderRadius(4)
                .margin({ left: 8 })
            }
            Blank()
            if (this.allWeeksImported) {
              Text('删除').fontSize(15).fontColor('#333333').backgroundColor('#E0E0E0')
                .borderRadius(8).padding({ left: 24, right: 24, top: 8, bottom: 8 })
                .onClick(() => this.deleteImportedEvents())
            } else {
              Text('导入').fontSize(15).fontColor('#333333').backgroundColor('#B3D4FC')
                .borderRadius(8).padding({ left: 24, right: 24, top: 8, bottom: 8 })
                .onClick(() => this.importAllWeeksToCalendar())
            }
          }
          .width('100%').height(64).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}
