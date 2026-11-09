import { router, promptAction } from '@kit.ArkUI';
import { PhysicalExperimentApi, PhysicalExperimentCourse } from '../../net/PhysicalExperimentApi';
import { CourseStore } from '../../store/CourseStore';
import { CourseData, CourseTimeSlot, TIME_SLOTS_HUANGJIAHU } from '../../model/CourseModel';
import { AppStorage as PreferenceStorage } from '../../store/AppStorage';
import { CourseApi } from '../../net/CourseApi';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import { calendarManager } from '@kit.CalendarKit';

interface DateParts { year: number; month: number; day: number; }

@Entry
@Component
export struct PhysicalExperimentPage {
  @State private courses: PhysicalExperimentCourse[] = [];
  @State private loading: boolean = false;
  @State private error: string = '';
  @State private showLogin: boolean = false;
  @State private studentId: string = '';
  @State private physicalPassword: string = '';
  @State private importingCalendar: boolean = false;
  // 课表里是否还有从物理实验导入的课程：决定「移除实验课表」按钮是否显示。
  @State private hasTimetableExperiments: boolean = false;
  @State private confirmRemove: boolean = false;
  @State private removing: boolean = false;
  // 是否还有本应用导入过、可以删除的实验日程。
  @State private hasCalendarEvents: boolean = false;
  @State private confirmRemoveCalendar: boolean = false;
  @State private removingCalendar: boolean = false;
  private store: CourseStore = CourseStore.getInstance();

  aboutToAppear(): void { this.prepare(); }

  private async prepare(): Promise<void> {
    const storage = PreferenceStorage.getInstance();
    this.studentId = await storage.getStudentId();
    this.physicalPassword = await storage.getPhysicalExperimentPassword();
    await this.restoreCachedCourses(storage);
    await this.refreshTimetableState(storage);
    await this.refreshCalendarState(storage);
    if (!this.physicalPassword) {
      this.showLogin = true;
      return;
    }
    await this.loadCourses();
  }

  private async refreshCalendarState(storage: PreferenceStorage): Promise<void> {
    const raw = await storage.getSettingString('physicalExperimentCalendarEventIds', '');
    this.hasCalendarEvents = raw.length > 0;
  }

  private async refreshTimetableState(storage: PreferenceStorage): Promise<void> {
    const current = await storage.getCurrentCourses();
    this.hasTimetableExperiments = current.some((course: CourseData) => course.isPhysicalExperiment === true);
  }

  private async confirmLogin(): Promise<void> {
    const password = this.physicalPassword.trim();
    if (!password) {
      promptAction.showToast({ message: '物理实验密码不能为空', duration: 1500 });
      return;
    }
    this.showLogin = false;
    this.physicalPassword = password;
    await PreferenceStorage.getInstance().setPhysicalExperimentPassword(password);
    await this.loadCourses(true);
  }

  private async restoreCachedCourses(storage: PreferenceStorage): Promise<void> {
    try {
      const raw = await storage.getSettingString('physicalExperimentCourseCache', '');
      if (raw) {
        const cached = JSON.parse(raw) as PhysicalExperimentCourse[];
        if (Array.isArray(cached) && cached.length > 0) this.courses = cached;
      }
    } catch {}
  }

  private async loadCourses(savePassword: boolean = false): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const storage = PreferenceStorage.getInstance();
      this.courses = await PhysicalExperimentApi.getCourses(await storage.getSemester(), this.physicalPassword);
      await storage.setPhysicalExperimentPassword(this.physicalPassword);
      await storage.setSettingString('physicalExperimentCourseCache', JSON.stringify(this.courses));
    } catch (e) {
      const message = e instanceof Error ? e.message : '物理实验课表获取失败';
      if (this.courses.length > 0) {
        this.error = '';
        promptAction.showToast({ message: '网络异常，已显示上次获取的实验课程', duration: 1800 });
      } else {
        this.error = message;
        if (savePassword) this.showLogin = true;
      }
    } finally {
      this.loading = false;
    }
  }

  private async logoutPhysical(): Promise<void> {
    await PreferenceStorage.getInstance().setPhysicalExperimentPassword('');
    this.physicalPassword = '';
    this.courses = [];
    this.error = '';
    this.showLogin = true;
  }

  private parseDate(value: string): DateParts | undefined {
    const parts = value.split('-');
    if (parts.length !== 3) return undefined;
    const result: DateParts = { year: Number(parts[0]), month: Number(parts[1]), day: Number(parts[2]) };
    return result.year > 0 && result.month > 0 && result.day > 0 ? result : undefined;
  }

  private clockMinutes(value: string): number {
    const parts = value.split(':');
    if (parts.length < 2) return -1;
    return Number(parts[0]) * 60 + Number(parts[1]);
  }

  private nearestPeriods(startClock: string): CourseTimeSlot {
    const target = this.clockMinutes(startClock);
    let best = TIME_SLOTS_HUANGJIAHU[0];
    let bestDistance = Number.MAX_SAFE_INTEGER;
    for (let i = 0; i < TIME_SLOTS_HUANGJIAHU.length; i++) {
      const slot = TIME_SLOTS_HUANGJIAHU[i];
      const distance = Math.abs(this.clockMinutes(slot.start) - target);
      if (target >= 0 && distance < bestDistance) {
        best = slot;
        bestDistance = distance;
      }
    }
    return best;
  }

  private formatDate(date: Date): string {
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return `${date.getFullYear()}-${month < 10 ? `0${month}` : month}-${day < 10 ? `0${day}` : day}`;
  }

  private async localTermStart(storage: PreferenceStorage): Promise<string> {
    const savedDate = this.parseDate(await storage.getDate());
    const savedWeek = await storage.getWeek();
    const savedWeekday = await storage.getWeekday();
    if (savedDate && savedWeek > 0) {
      const date = new Date(savedDate.year, savedDate.month - 1, savedDate.day);
      const weekday = savedWeekday >= 1 && savedWeekday <= 7 ? savedWeekday : (date.getDay() === 0 ? 7 : date.getDay());
      date.setDate(date.getDate() - (savedWeek - 1) * 7 - (weekday - 1));
      return this.formatDate(date);
    }
    for (let i = 0; i < this.courses.length; i++) {
      const item = this.courses[i];
      const parts = this.parseDate(item.date || '');
      if (!parts) continue;
      const date = new Date(parts.year, parts.month - 1, parts.day);
      const weekday = date.getDay() === 0 ? 7 : date.getDay();
      const week = item.startWeek && item.startWeek > 0 ? item.startWeek : 1;
      date.setDate(date.getDate() - (week - 1) * 7 - (weekday - 1));
      return this.formatDate(date);
    }
    return '';
  }

  private async ensureTermStart(storage: PreferenceStorage): Promise<string> {
    const cached = await storage.getTermStartDate();
    if (cached) return cached;
    try {
      const response = await CourseApi.getTermStartDate(await storage.getToken());
      if (response.data) {
        const month = response.data.month < 10 ? `0${response.data.month}` : `${response.data.month}`;
        const day = response.data.day < 10 ? `0${response.data.day}` : `${response.data.day}`;
        const value = `${response.data.year}-${month}-${day}`;
        await storage.setTermStartDate(value);
        return value;
      }
    } catch {}
    const local = await this.localTermStart(storage);
    if (local) await storage.setTermStartDate(local);
    return local;
  }

  private toCourse(item: PhysicalExperimentCourse, termStart: string): CourseData {
    const slot = this.nearestPeriods(item.startClock || '');
    let dayOfWeek = item.weekDay || 1;
    let week = item.startWeek || 1;
    const date = this.parseDate(item.date || '');
    const start = this.parseDate(termStart);
    if (date) {
      const utc = Date.UTC(date.year, date.month - 1, date.day);
      const weekday = new Date(utc).getUTCDay();
      dayOfWeek = weekday === 0 ? 7 : weekday;
      if (start) {
        const startUtc = Date.UTC(start.year, start.month - 1, start.day);
        week = Math.max(1, Math.floor((utc - startUtc) / 604800000) + 1);
      }
    }
    return {
      courseName: item.courseName || item.className || item.name || item.course || '物理实验',
      teacher: item.teacher || '', location: item.classroom || '', dayOfWeek,
      startPeriod: item.startClock ? slot.startPeriod : (item.startSection || item.section || 1),
      endPeriod: item.startClock ? slot.endPeriod : (item.endSection || item.startSection || item.section || 1),
      weekRanges: `${week}`, isPhysicalExperiment: true, physicalDate: item.date || ''
    };
  }

  private async importCourses(): Promise<void> {
    try {
      const storage = PreferenceStorage.getInstance();
      const termStart = await this.ensureTermStart(storage);
      const imported: CourseData[] = this.courses.map((item: PhysicalExperimentCourse): CourseData => this.toCourse(item, termStart));
      if (imported.length === 0) {
        promptAction.showToast({ message: '暂无可导入的实验课程' });
        return;
      }
      const existing = await storage.getCurrentCourses();
      const base = existing.length > 0 ? existing : this.store.courses;
      const merged: CourseData[] = [...base];
      let added = 0;
      for (let i = 0; i < imported.length; i++) {
        const item = imported[i];
        let duplicate = false;
        for (let j = 0; j < merged.length; j++) {
          if (merged[j].isPhysicalExperiment && merged[j].courseName === item.courseName &&
            merged[j].physicalDate === item.physicalDate) duplicate = true;
        }
        if (!duplicate) { merged.push(item); added++; }
      }
      await storage.setPhysicalExperimentCourses(imported);
      await storage.setCurrentCourses(merged);
      const saved = await storage.getCurrentCourses();
      this.store.setCourses(saved);
      this.hasTimetableExperiments = saved.some((course: CourseData) => course.isPhysicalExperiment === true);
      AppStorage.setOrCreate<number>('courseDataVersion', Date.now());
      promptAction.showToast({ message: added > 0 ? `已导入${added}门实验课程` : '实验课程已在课表中' });
    } catch (error) {
      console.error('PhysicalExperimentPage', `course import error: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '导入课表失败，请稍后重试', duration: 1800 });
    }
  }

  /** 一键移除课表里的实验课程：只删除 isPhysicalExperiment 的条目，其他课程原样保留。 */
  private async removeFromTimetable(): Promise<void> {
    if (this.removing) return;
    this.removing = true;
    try {
      const storage = PreferenceStorage.getInstance();
      // 原子操作：清空实验缓存 + 重写普通课表在同一次写入里完成，
      // 否则 setCurrentCourses() 会把实验课从旧课表里迁移回来。
      const removed = await storage.removePhysicalExperimentCourses();
      if (removed === 0) {
        this.hasTimetableExperiments = false;
        promptAction.showToast({ message: '课表中没有实验课程' });
        return;
      }
      const saved = await storage.getCurrentCourses();
      this.store.setCourses(saved);
      this.hasTimetableExperiments = saved.some((course: CourseData) => course.isPhysicalExperiment === true);
      AppStorage.setOrCreate<number>('courseDataVersion', Date.now());
      promptAction.showToast({ message: `已移除${removed}门实验课程` });
    } catch (error) {
      console.error('PhysicalExperimentPage', `course removal error: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '移除实验课程失败，请稍后重试', duration: 1800 });
    } finally {
      this.removing = false;
    }
  }

  private async requestCalendarPermission(): Promise<boolean> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, [
        'ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'
      ]);
      const authResults = result.authResults;
      const granted = authResults !== undefined && authResults.length >= 2 &&
        authResults[0] === 0 && authResults[1] === 0;
      if (!granted) promptAction.showToast({ message: '日历权限被拒绝，无法导入', duration: 2000 });
      return granted;
    } catch (error) {
      console.error('PhysicalExperimentPage', `calendar permission error: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '日历权限申请失败', duration: 1800 });
      return false;
    }
  }

  private createCalendarEvent(item: PhysicalExperimentCourse): calendarManager.Event | undefined {
    const date = this.parseDate(item.date || '');
    const startMinutes = this.clockMinutes(item.startClock || '');
    const endMinutes = this.clockMinutes(item.endClock || '');
    if (!date || startMinutes < 0 || endMinutes <= startMinutes) return undefined;
    const startTime = new Date(date.year, date.month - 1, date.day,
      Math.floor(startMinutes / 60), startMinutes % 60, 0, 0);
    const endTime = new Date(date.year, date.month - 1, date.day,
      Math.floor(endMinutes / 60), endMinutes % 60, 0, 0);
    return {
      type: calendarManager.EventType.NORMAL,
      title: item.courseName || item.className || item.name || item.course || '物理实验',
      location: { location: item.classroom || '', longitude: 0, latitude: 0 },
      startTime: startTime.getTime(), endTime: endTime.getTime(),
      description: `物理实验 ${item.startClock || ''}-${item.endClock || ''}`
    };
  }

  private eventKey(item: PhysicalExperimentCourse): string {
    return `${item.date || ''}|${item.startClock || ''}|${item.endClock || ''}|` +
      `${item.courseName || item.className || item.name || item.course || ''}|${item.classroom || ''}`;
  }

  private async importToCalendar(): Promise<void> {
    if (this.importingCalendar || this.courses.length === 0) return;
    if (!await this.requestCalendarPermission()) return;
    this.importingCalendar = true;
    try {
      const storage = PreferenceStorage.getInstance();
      const raw = await storage.getSettingString('physicalExperimentCalendarKeys', '');
      const savedKeys: string[] = raw ? JSON.parse(raw) as string[] : [];
      const rawIds = await storage.getSettingString('physicalExperimentCalendarEventIds', '');
      const savedIds: number[] = rawIds ? JSON.parse(rawIds) as number[] : [];
      const manager = calendarManager.getCalendarManager(getContext(this) as common.Context);
      const calendar = await manager.getCalendar();
      let imported = 0;
      let skipped = 0;
      for (let i = 0; i < this.courses.length; i++) {
        const item = this.courses[i];
        const key = this.eventKey(item);
        if (savedKeys.indexOf(key) >= 0) {
          skipped++;
          continue;
        }
        const event = this.createCalendarEvent(item);
        if (!event) {
          skipped++;
          continue;
        }
        // 记住日历返回的事件 id：之后「删除实验日程」要靠它精确删除。
        const eventId = await calendar.addEvent(event);
        savedIds.push(eventId);
        await storage.setSettingString('physicalExperimentCalendarEventIds', JSON.stringify(savedIds));
        savedKeys.push(key);
        await storage.setSettingString('physicalExperimentCalendarKeys', JSON.stringify(savedKeys));
        imported++;
      }
      if (imported > 0) {
        this.hasCalendarEvents = savedIds.length > 0;
        promptAction.showToast({ message: `已按准确时间导入${imported}门实验到日程`, duration: 2000 });
      } else if (skipped > 0) {
        this.hasCalendarEvents = savedIds.length > 0;
        promptAction.showToast({ message: '实验日程已导入，无需重复添加', duration: 1800 });
      } else {
        promptAction.showToast({ message: '没有可导入的实验日程', duration: 1800 });
      }
    } catch (error) {
      console.error('PhysicalExperimentPage', `calendar import error: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '导入日程失败，请检查日历权限', duration: 2000 });
    } finally {
      this.importingCalendar = false;
    }
  }

  /**
   * 删除本应用导入的实验日程：按保存的事件 id 逐条删除。
   *
   * 只有删除成功的条目才清除记录；删除失败的保留 id 与 key，
   * 避免日程还留在系统日历里、App 却再也找不到它（重新导入时还会重复）。
   */
  private async removeFromCalendar(): Promise<void> {
    if (this.removingCalendar) return;
    if (!await this.requestCalendarPermission()) return;
    this.removingCalendar = true;
    try {
      const storage = PreferenceStorage.getInstance();
      const rawIds = await storage.getSettingString('physicalExperimentCalendarEventIds', '');
      const ids: number[] = rawIds ? JSON.parse(rawIds) as number[] : [];
      const rawKeys = await storage.getSettingString('physicalExperimentCalendarKeys', '');
      const keys: string[] = rawKeys ? JSON.parse(rawKeys) as string[] : [];
      if (ids.length === 0) {
        this.hasCalendarEvents = false;
        promptAction.showToast({ message: '没有需要删除的实验日程' });
        return;
      }
      const manager = calendarManager.getCalendarManager(getContext(this) as common.Context);
      const calendar = await manager.getCalendar();
      const keptIds: number[] = [];
      // 旧版本只保存去重 key、没有保存事件 id。升级后新导入的数据会继续
      // 追加到两个数组尾部，所以能和 id 对应的是 keys 的最后 ids.length 项，
      // 前面的 key 都是旧版记录，删除时必须保留，避免以后重复导入。
      const pairedKeyStart = Math.max(0, keys.length - ids.length);
      const legacyKeys = keys.slice(0, pairedKeyStart);
      const pairedKeys = keys.slice(pairedKeyStart);
      const keptKeys: string[] = legacyKeys.slice();
      let deleted = 0;
      for (let i = 0; i < ids.length; i++) {
        const key = i < pairedKeys.length ? pairedKeys[i] : '';
        try {
          await calendar.deleteEvent(ids[i]);
          deleted++;
        } catch (error) {
          console.warn('PhysicalExperimentPage', `calendar delete failed for ${ids[i]}: ${JSON.stringify(error)}`);
          keptIds.push(ids[i]);
          if (key) keptKeys.push(key);
        }
      }
      await storage.setSettingString('physicalExperimentCalendarEventIds',
        keptIds.length > 0 ? JSON.stringify(keptIds) : '');
      await storage.setSettingString('physicalExperimentCalendarKeys',
        keptKeys.length > 0 ? JSON.stringify(keptKeys) : '');
      this.hasCalendarEvents = keptIds.length > 0;
      if (keptIds.length === 0) {
        promptAction.showToast({ message: `已删除${deleted}条实验日程` });
      } else {
        promptAction.showToast({
          message: `已删除${deleted}条，${keptIds.length}条删除失败已保留记录，可重试`,
          duration: 2500
        });
      }
    } catch (error) {
      console.error('PhysicalExperimentPage', `calendar removal error: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '删除实验日程失败，请检查日历权限', duration: 2000 });
    } finally {
      this.removingCalendar = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Text('‹').fontSize(36).fontColor('#333333').onClick(() => router.back())
          Text('物理实验').fontSize(22).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1)
          Text('退出').width(52).height(40).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#888888')
            .textAlign(TextAlign.Center).margin({ right: 4 }).onClick(() => this.logoutPhysical())
          Text('刷新').width(52).height(40).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1ec98d')
            .textAlign(TextAlign.Center).onClick(() => this.loadCourses())
        }.width('100%').height(56).padding({ left: 18, right: 10 }).alignItems(VerticalAlign.Center).backgroundColor(Color.White)

        if (this.loading) {
          LoadingProgress().width(42).height(42).layoutWeight(1)
        } else if (this.error.length > 0) {
          Column() {
            Text('物理实验课表加载失败').fontSize(18).fontColor('#333333')
            Text(this.error).fontSize(14).fontColor('#999999').margin({ top: 10 }).textAlign(TextAlign.Center)
            Button('重新登录').backgroundColor('#1ec98d').fontColor(Color.White).margin({ top: 18 })
              .onClick(() => { this.physicalPassword = ''; this.showLogin = true; })
          }.layoutWeight(1).padding(24).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column() {
              Text(`共${this.courses.length}门实验课程`).fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 12 })
              ForEach(this.courses, (item: PhysicalExperimentCourse) => {
                Row() {
                  Column() {
                    Text(item.courseName || item.className || item.name || item.course || '物理实验').fontSize(16).fontColor('#333333')
                    if (item.date || item.startClock || item.endClock) {
                      Text(`${item.date || ''} ${item.startClock || ''}-${item.endClock || ''}`.trim())
                        .fontSize(13).fontColor('#999999').margin({ top: 5 })
                    }
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Text(item.classroom || '待定').fontSize(14).fontColor('#888888')
                }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(10).margin({ bottom: 10 })
              })
              Button('导入到课表').width('90%').height(48).backgroundColor('#1ec98d').fontColor(Color.White)
                .margin({ top: 12, bottom: 10 }).onClick(() => this.importCourses())
              if (this.hasTimetableExperiments) {
                Button('移除实验课表').width('90%').height(48).backgroundColor(Color.White).fontColor('#E6584A')
                  .border({ width: 1, color: '#E6584A' }).margin({ bottom: 10 })
                  .enabled(!this.removing)
                  .onClick(() => { this.confirmRemove = true; })
              }
              Button(this.importingCalendar ? '正在导入日程...' : '导入到日程').width('90%').height(48)
                .backgroundColor(Color.White).fontColor('#1ec98d').border({ width: 1, color: '#1ec98d' })
                .margin({ bottom: this.hasCalendarEvents ? 10 : 24 }).enabled(!this.importingCalendar).onClick(() => this.importToCalendar())
              if (this.hasCalendarEvents) {
                Button('删除实验日程').width('90%').height(48).backgroundColor(Color.White).fontColor('#E6584A')
                  .border({ width: 1, color: '#E6584A' }).margin({ bottom: 24 })
                  .enabled(!this.removingCalendar)
                  .onClick(() => { this.confirmRemoveCalendar = true; })
              }
            }.width('100%').padding(16)
          }.width('100%').layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor('#F5F6F7')

      if (this.showLogin) {
        Column() {
          Column() {
            Text('物理实验登录').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%')
            TextInput({ text: this.studentId, placeholder: '学号' }).fontSize(17).fontColor('#999999').enabled(false)
              .width('100%').height(58).margin({ top: 18 }).backgroundColor(Color.Transparent)
            Divider().color('#E5E5E5')
            TextInput({ text: this.physicalPassword, placeholder: '物理实验密码' }).type(InputType.Password)
              .fontSize(17).width('100%').height(58).backgroundColor(Color.Transparent)
              .onChange((value: string) => { this.physicalPassword = value; })
            Divider().color('#E5E5E5')
            Text('密码是物理实验预约系统的密码').fontSize(14).fontColor('#9CA3AF').width('100%')
              .textAlign(TextAlign.End).margin({ top: 14, bottom: 16 })
            Divider().color('#EFEFEF')
            Text('确认').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#2785EF').width('100%').height(52)
              .textAlign(TextAlign.Center).onClick(() => this.confirmLogin())
          }.width('84%').padding({ left: 24, right: 24, top: 24 }).backgroundColor(Color.White).borderRadius(16)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#99000000')
      }
      if (this.confirmRemove) {
        Column() {
          Column() {
            Text('移除实验课表？').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%')
            Text('只会移除从物理实验导入的课程，其他课程不受影响。')
              .fontSize(15).fontColor('#888888').width('100%').margin({ top: 14, bottom: 24 })
            Row() {
              Button('取消').layoutWeight(1).height(48).backgroundColor('#F2F3F5').fontColor('#555555')
                .onClick(() => { this.confirmRemove = false; })
              Button(this.removing ? '移除中...' : '移除').layoutWeight(1).height(48).margin({ left: 12 })
                .backgroundColor('#E6584A').fontColor(Color.White).enabled(!this.removing)
                .onClick(() => {
                  this.confirmRemove = false;
                  this.removeFromTimetable();
                })
            }.width('100%')
          }.width('84%').padding({ left: 24, right: 24, top: 24, bottom: 24 }).backgroundColor(Color.White).borderRadius(16)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#99000000')
      }
      if (this.confirmRemoveCalendar) {
        Column() {
          Column() {
            Text('删除实验日程？').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%')
            Text('只会删除通过本应用导入到系统日历的实验日程，其他日程不受影响。')
              .fontSize(15).fontColor('#888888').width('100%').margin({ top: 14, bottom: 24 })
            Row() {
              Button('取消').layoutWeight(1).height(48).backgroundColor('#F2F3F5').fontColor('#555555')
                .onClick(() => { this.confirmRemoveCalendar = false; })
              Button(this.removingCalendar ? '删除中...' : '删除').layoutWeight(1).height(48).margin({ left: 12 })
                .backgroundColor('#E6584A').fontColor(Color.White).enabled(!this.removingCalendar)
                .onClick(() => {
                  this.confirmRemoveCalendar = false;
                  this.removeFromCalendar();
                })
            }.width('100%')
          }.width('84%').padding({ left: 24, right: 24, top: 24, bottom: 24 }).backgroundColor(Color.White).borderRadius(16)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#99000000')
      }
    }.width('100%').height('100%')
  }
}
