/**
 * CoursePage — 课表页面（不含 @Entry，供 MainPage Tabs 嵌入）
 *
 * 文件路径：entry/src/main/ets/pages/course/CoursePage.ets
 */
import { RouterUtil } from '../../utils/RouterUtil';
import { AppStorage as PreferenceStorage } from '../../store/AppStorage';
import { CourseApi } from '../../net/CourseApi';
import { CourseStore } from '../../store/CourseStore';
import { WeekSelector } from '../../components/WeekSelector';
import { CourseCalendar } from '../../components/CourseCalendar';
import { CourseMoreMenu } from '../../components/CourseMoreMenu';
import { CampusPicker } from '../../components/CampusPicker';
import { SemesterPicker } from '../../components/SemesterPicker';
import { WeekAdjustPicker } from '../../components/WeekAdjustPicker';
import { CourseData, isCourseInWeek, getTimeSlotsByCampus, ScheduleSettings, DEFAULT_SETTINGS } from '../../model/CourseModel';
import { router, promptAction } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';

const TAG = 'CoursePage';

const mockCourseList: CourseData[] = [
  { courseName: '高等数学', teacher: '张老师', location: '教1-203', dayOfWeek: 1, startPeriod: 1, endPeriod: 2, weekRanges: '1-16', color: '#FD999A' },
  { courseName: '大学物理', teacher: '李老师', location: '教2-405', dayOfWeek: 2, startPeriod: 3, endPeriod: 4, weekRanges: '1-16', color: '#66CC99' },
  { courseName: '程序设计', teacher: '王老师', location: '计科-301', dayOfWeek: 3, startPeriod: 5, endPeriod: 6, weekRanges: '1-16', color: '#66BDB0' },
  { courseName: '数据结构', teacher: '赵老师', location: '计科-205', dayOfWeek: 1, startPeriod: 3, endPeriod: 4, weekRanges: '1,3,5,7,9,11,13,15', color: '#2196F3' },
  { courseName: '线性代数', teacher: '孙老师', location: '教3-102', dayOfWeek: 2, startPeriod: 5, endPeriod: 6, weekRanges: '2,4,6,8,10,12,14,16', color: '#BF83DA' },
  { courseName: '大学英语', teacher: '周老师', location: '外语楼-201', dayOfWeek: 4, startPeriod: 1, endPeriod: 2, weekRanges: '1-16', color: '#68C4CF' },
  { courseName: '体育', teacher: '吴老师', location: '体育馆', dayOfWeek: 5, startPeriod: 3, endPeriod: 4, weekRanges: '1-16', color: '#FF5722' },
  { courseName: '形势与政策', teacher: '郑老师', location: '教4-101', dayOfWeek: 3, startPeriod: 9, endPeriod: 11, weekRanges: '5,6,7,8', color: '#00D4BB' }
]

/** 课程详情弹窗 */
@CustomDialog
struct CourseDetailDialog {
  controller?: CustomDialogController;
  private course?: CourseData;
  onClose?: () => void;

  build() {
    Column() {
      Text(this.course && this.course.courseName ? this.course.courseName : '').fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor('#333333').margin({ top: 16 })

      Divider().margin({ top: 12, bottom: 12 })

      Row() { Text('授课教师').width(80).fontSize(14).fontColor('#999999')
        Text(this.course && this.course.teacher ? this.course.teacher : '').fontSize(14).fontColor('#333333').layoutWeight(1) }
      .width('100%').height(32).padding({ left: 16, right: 16 })

      Row() { Text('上课地点').width(80).fontSize(14).fontColor('#999999')
        Text(this.course && this.course.location ? this.course.location : '').fontSize(14).fontColor('#333333').layoutWeight(1) }
      .width('100%').height(32).padding({ left: 16, right: 16 })

      Row() { Text('星期').width(80).fontSize(14).fontColor('#999999')
        Text( this.course && this.course.dayOfWeek ? `星期${this.course.dayOfWeek}` : ''
        ).fontSize(14).fontColor('#333333').layoutWeight(1) }
      .width('100%').height(32).padding({ left: 16, right: 16 })

      Row() { Text('节次').width(80).fontSize(14).fontColor('#999999')
        Text(this.course ? `第 ${this.course.startPeriod}-${this.course.endPeriod} 节` :
          '').fontSize(14).fontColor('#333333').layoutWeight(1) }
      .width('100%').height(32).padding({ left: 16, right: 16 })

      Row() { Text('教学周').width(80).fontSize(14).fontColor('#999999')
        Text(this.course && this.course.weekRanges ? this.course.weekRanges : '').fontSize(14).fontColor('#333333').layoutWeight(1) }
      .width('100%').height(32).padding({ left: 16, right: 16 })

      Text('关闭').fontSize(16).fontColor('#1ec98d').margin({ top: 12, bottom: 12 })
        .onClick(() => {
          if (this.onClose !== undefined && this.onClose !== null) {
            this.onClose();
          }
        })
    }
    .width('80%').backgroundColor(Color.White).borderRadius(12).padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}

@Entry
@Component
export struct CoursePage {
  @State private loading: boolean = true;
  @State private errorMsg: string = '';
  @State private empty: boolean = false;

  private isUseMockData: boolean = false;
  private store: CourseStore = CourseStore.getInstance();
  @State private courseList: CourseData[] = [];
  @State private allCourseList: CourseData[] = [];

  /** 当前周的可见课程（由 CourseCalendar 过滤） */
  @State private visibleList: CourseData[] = [];
  @State private calendarCourseList: CourseData[] = [];
  @State private showCourseDialog: boolean = false;
  @State private tappedCourse: CourseData | null = null;
  @State private currentWeek: number = 1;
  @State private actualCurrentWeek: number = 1;
  @State private weekDates: string[] = [];
  @State private monthLabel: string = '9月';
  @State private refreshKey: number = 0;
  @State private selectorHeight: number = 0;
  @State private isRefreshing: boolean = false;
  @State private refreshRotate: number = 0;
  private refreshTimer: number = -1;
  @State private showMoreMenu: boolean = false;
  @State private menuAnim: boolean = false;
  @State private onlyThisWeek: boolean = false;
  @State private showCampusPicker: boolean = false;
  @State private currentCampus: string = '黄家湖校区';
  @State private showSemesterPicker: boolean = false;
  @State private showWeekAdjust: boolean = false;
  @State private currentSemester: string = '2026-2027-1';
  @StorageLink('scheduleSettings') scheduleSettings: ScheduleSettings = DEFAULT_SETTINGS;
  @StorageLink('sundayFirst') sundayFirst: boolean = false;
  private semesterStart: Date = new Date(2025, 8, 1);

  aboutToAppear(): void {
    this.initializeWeek();
  }

  private async initializeWeek(): Promise<void> {
    await this.resolveSemesterStart();
    const autoWeek = this.calcCurrentWeek();
    const adjustedWeek = await this.getAdjustedWeek();
    const initialWeek = adjustedWeek >= 1 && adjustedWeek <= 25 ? adjustedWeek : autoWeek;
    this.actualCurrentWeek = initialWeek;
    this.currentWeek = initialWeek;
    this.store.setCurrentWeek(initialWeek);
    this.calendarCourseList = Array.isArray(this.store.courses) ? [...this.store.courses] : [];
    this.updateWeekDates();
    this.loadCalendarOrderSetting();
    this.loadScheduleSettings();
    this.verifyAndLoad();
  }

  /** 从缓存或 getData 接口解析学期起始日，覆盖 2025-09-01 的默认值。 */
  private async resolveSemesterStart(): Promise<void> {
    const s = PreferenceStorage.getInstance();
    try {
      const cached = await s.getTermStartDate();
      if (this.applyTermStartDateFromString(cached)) {
        console.info(TAG, `resolveSemesterStart from cache: ${cached}`);
        return;
      }
    } catch {
      // 忽略缓存读取异常。
    }

    try {
      const token = await s.getToken();
      if (!token) {
        return;
      }
      const resp = await CourseApi.getTermStartDate(token);
      if (resp.code === 10000 || resp.code === 200 || resp.code === 0) {
        if (resp.data) {
          const year = resp.data.year;
          const month = resp.data.month;
          const day = resp.data.day;
          if (year > 0 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            this.semesterStart = new Date(year, month - 1, day);
            const mm = month < 10 ? `0${month}` : `${month}`;
            const dd = day < 10 ? `0${day}` : `${day}`;
            await s.setTermStartDate(`${year}-${mm}-${dd}`);
            console.info(TAG, `resolveSemesterStart from api: ${year}-${mm}-${dd}`);
          }
        }
      }
    } catch {
      console.warn(TAG, 'resolveSemesterStart error');
    }
  }

  private applyTermStartDateFromString(value: string): boolean {
    if (!value || value.length === 0) {
      return false;
    }
    const parts = value.split('-');
    if (parts.length !== 3) {
      return false;
    }
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);
    if (isNaN(year) || isNaN(month) || isNaN(day)) {
      return false;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    this.semesterStart = new Date(year, month - 1, day);
    return true;
  }

  private async getAdjustedWeek(): Promise<number> {
    const memoryWeek = AppStorage.get<number>('adjustedCurrentWeek');
    if (memoryWeek !== undefined && memoryWeek >= 1 && memoryWeek <= 25) {
      return memoryWeek;
    }
    const savedWeek = await PreferenceStorage.getInstance().getSettingNumber('adjustedCurrentWeek', 0);
    if (savedWeek >= 1 && savedWeek <= 25) {
      AppStorage.setOrCreate('adjustedCurrentWeek', savedWeek);
      return savedWeek;
    }
    return 0;
  }

  private async loadScheduleSettings(): Promise<void> {
    try {
      const settings = await PreferenceStorage.getInstance().getScheduleSettings();
      // 整体替换对象，确保 StorageLink 和 CourseCalendar 都收到更新。
      this.scheduleSettings = {
        bgImage: settings.bgImage,
        bgOpacity: settings.bgOpacity,
        bgFullscreen: settings.bgFullscreen,
        fontSize: settings.fontSize,
        italic: settings.italic,
      };
      console.info('CoursePage', `schedule settings: fontSize=${settings.fontSize}, italic=${settings.italic}`);
    } catch {
      this.scheduleSettings = {
        bgImage: DEFAULT_SETTINGS.bgImage,
        bgOpacity: DEFAULT_SETTINGS.bgOpacity,
        bgFullscreen: DEFAULT_SETTINGS.bgFullscreen,
        fontSize: DEFAULT_SETTINGS.fontSize,
        italic: DEFAULT_SETTINGS.italic,
      };
    }
  }

  private async loadCalendarOrderSetting(): Promise<void> {
    this.sundayFirst = await PreferenceStorage.getInstance().getSundayFirst();
    this.updateWeekDates();
  }

  onPageShow(): void {
    const store = CourseStore.getInstance();
    const adjustedWeek = AppStorage.get<number>('adjustedCurrentWeek');
    if (adjustedWeek !== undefined && adjustedWeek >= 1 && adjustedWeek <= 25) {
      this.actualCurrentWeek = adjustedWeek;
      this.currentWeek = adjustedWeek;
      store.setCurrentWeek(adjustedWeek);
      this.updateWeekDates();
      this.applyOnlyThisWeekFilter();
    }
    this.loadCurrentArchiveCourses();
    // 从背景与字体设置页返回时立即重新读取最新值。
    this.loadScheduleSettings();
    this.loadCalendarOrderSetting();
    this.calendarCourseList = Array.isArray(store.courses) ? [...store.courses] : [];
    console.info("CoursePage onPageShow len=", this.calendarCourseList.length);
    this.calendarCourseList = [];
    setTimeout(() => {
      const latest = CourseStore.getInstance().courses;
      this.calendarCourseList = Array.isArray(latest) ? [...latest] : [];
      console.info("CoursePage onPageShow refresh len=", this.calendarCourseList.length);
    }, 50);
  }

  aboutToDisappear(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  /** 校验登录态，失效跳转 */
  private async verifyAndLoad(): Promise<void> {
    console.info(TAG, `isUseMockData=${this.isUseMockData}`);

    if (this.isUseMockData) {
      console.info(TAG, `store.currentWeek=${this.store.currentWeek}`);
      for (let i = 0; i < mockCourseList.length; i++) {
        console.info('CoursePage', `mock: ${mockCourseList[i].courseName} weekRanges=[${mockCourseList[i].weekRanges}]`);
      }
      let testCourse: CourseData | null = null;
      for (let i = 0; i < mockCourseList.length; i++) {
        if (mockCourseList[i].courseName === '线性代数') {
          testCourse = mockCourseList[i];
          break;
        }
      }
      if (testCourse !== null) {
        for (let w = 1; w <= 5; w++) {
          const result = isCourseInWeek(testCourse, w);
          console.info('CoursePage', `test isCourseInWeek: 线性代数 week=${w} result=${result} weekRanges=[${testCourse.weekRanges}]`);
        }
      }
      this.store.setCourses(mockCourseList);
      this.allCourseList = [...mockCourseList];
      this.loadCurrentArchiveCourses();
      this.applyOnlyThisWeekFilter();
      this.empty = this.allCourseList.length === 0;
      this.errorMsg = '';
      this.loading = false;
      this.filterVisibleCourses();
      this.updateWeekDates();
      console.info(TAG, `mock loaded ${this.courseList.length} courses`);
      return;
    }

    try {
      const s = PreferenceStorage.getInstance();
      const token = await s.getToken();
      const isLogin = await s.getIsLogin();
      if (!token || !isLogin) {
        RouterUtil.toLogin();
        return;
      }
      await this.store.restoreFromStorage();
      this.currentSemester = this.store.semester || this.calcSemesterFallback();
      const adjustedWeek = AppStorage.get<number>('adjustedCurrentWeek');
      if (adjustedWeek !== undefined && adjustedWeek >= 1 && adjustedWeek <= 25) {
        this.actualCurrentWeek = adjustedWeek;
        this.currentWeek = adjustedWeek;
        this.store.setCurrentWeek(adjustedWeek);
      } else {
        this.currentWeek = this.store.currentWeek;
      }
      this.updateWeekDates();
      this.loading = true;
      await this.fetchCourses();
      this.loading = false;
    } catch {
      console.error(TAG, 'verifyAndLoad error');
      this.loading = false;
      this.errorMsg = '登录状态校验失败';
    }
  }

  /** 调用真实 API 获取课表 */
  private async fetchCourses(): Promise<void> {
    try {
      const s = PreferenceStorage.getInstance();
      const token = await s.getToken();
      if (!token) {
        this.errorMsg = '登录已失效，请重新登录';
        return;
      }

      // 若学期为空则从 AppStorage 读取
      let semester = this.store.semester;
      if (!semester) {
        semester = await s.getSemester();
        if (!semester) {
          semester = this.calcSemesterFallback();
          await s.setSemester(semester);
        }
        this.store.setSemester(semester);
      }

      const resp = await CourseApi.getCourseTable(semester, token);

      if (resp.code === 10000 || resp.code === 200 || resp.code === 0) {
        const list: CourseData[] = resp.data ? resp.data : [];
        this.store.setCourses(list);
        const colored = this.store.courses;
        this.allCourseList = Array.isArray(colored) ? [...colored] : [...list];
        this.applyOnlyThisWeekFilter();
        this.empty = list.length === 0;
        this.errorMsg = '';

        // 更新周次信息
        if (this.store.currentWeek > 0) {
          this.store.setCurrentWeek(this.store.currentWeek);
        }
        // 过滤当前周可见课程
        this.filterVisibleCourses();

        console.info(TAG, `loaded ${list.length} courses`);
      } else if (resp.code === 401 || resp.code === 403 || resp.code === 10001 || resp.code === 30001) {
        // Token 失效 → 跳转登录
        this.errorMsg = '登录已过期，正在跳转...';
        setTimeout(() => RouterUtil.toLogin(), 1500);
      } else {
        this.errorMsg = resp.msg || '课表获取失败';
        // 有缓存数据时仍展示
        const cached = this.store.courses;
        if (cached.length > 0) {
          this.allCourseList = [...cached];
          this.applyOnlyThisWeekFilter();
          this.filterVisibleCourses();
          this.errorMsg = '';
        }
      }
    } catch {
      console.warn(TAG, 'fetchCourses error');
      // 网络失败：有缓存则展示缓存，无缓存提示错误
      const cached = this.store.courses;
      if (cached.length > 0) {
        this.allCourseList = [...cached];
        this.applyOnlyThisWeekFilter();
        this.filterVisibleCourses();
        this.errorMsg = '';
      } else {
        this.errorMsg = '网络请求失败，请检查网络后重试';
      }
    }
  }

  /** 按当前周次过滤可见课程 */

  private applyOnlyThisWeekFilter(): void {
    if (this.onlyThisWeek) {
      const filtered: CourseData[] = [];
      for (let i = 0; i < this.allCourseList.length; i++) {
        if (isCourseInWeek(this.allCourseList[i], this.currentWeek)) {
          filtered.push(this.allCourseList[i]);
        }
      }
      this.courseList = filtered;
    } else {
      this.courseList = [...this.allCourseList];
    }
    this.visibleList = [...this.courseList];
    this.calendarCourseList = [...this.courseList];
    console.info('CoursePage', `applyOnlyThisWeekFilter only=${this.onlyThisWeek} all=${this.allCourseList.length} current=${this.currentWeek} result=${this.courseList.length}`);
  }

  private async loadCurrentArchiveCourses(): Promise<boolean> {
    const currentCourses = await PreferenceStorage.getInstance().getCurrentCourses();
    if (!currentCourses || currentCourses.length === 0) {
      return false;
    }
    this.store.setCourses(currentCourses);
    this.allCourseList = [...currentCourses];
    this.applyOnlyThisWeekFilter();
    this.empty = this.allCourseList.length === 0;
    this.filterVisibleCourses();
    console.info(TAG, `loaded current archive courses: ${currentCourses.length}`);
    return true;
  }

  private filterVisibleCourses(): void {
    this.visibleList = [...this.courseList];
    this.calendarCourseList = Array.isArray(this.visibleList) ? [...this.visibleList] : [];
    console.info(TAG, `filterVisibleCourses: all courses visible=${this.visibleList.length}`);
  }

  private calcCurrentWeek(): number {
    const now = new Date();
    const diffTime = now.getTime() - this.semesterStart.getTime();
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    let week = Math.floor(diffDays / 7) + 1;
    if (week < 1) {
      week = 1;
    }
    if (week > this.store.totalWeeks) {
      week = this.store.totalWeeks;
    }
    console.info('CoursePage', `calcCurrentWeek: now=${now.toLocaleDateString()}, diffDays=${diffDays}, week=${week}`);
    return week;
  }

  /** 根据当前教学周生成表头日期和左侧月份。 */
  private updateWeekDates(): void {
    const semesterStart = new Date(this.semesterStart);
    const weekMonday = new Date(semesterStart);
    weekMonday.setDate(semesterStart.getDate() + (this.currentWeek - 1) * 7);

    const dates: string[] = [];
    const firstDay = this.sundayFirst
      ? new Date(weekMonday.getTime() - 24 * 60 * 60 * 1000)
      : weekMonday;
    for (let i = 0; i < 7; i++) {
      const day = new Date(firstDay);
      day.setDate(firstDay.getDate() + i);
      dates.push(`${day.getMonth() + 1}/${day.getDate()}`);
    }
    this.weekDates = dates;
    this.monthLabel = `${weekMonday.getMonth() + 1}月`;
    console.info(TAG, `updateWeekDates: week=${this.currentWeek}, dates=${JSON.stringify(this.weekDates)}, month=${this.monthLabel}`);
  }

  private async startScan(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const permissionResult = await atManager.requestPermissionsFromUser(context, [
        'ohos.permission.CAMERA'
      ]);
      if (!permissionResult.authResults || permissionResult.authResults[0] !== 0) {
        promptAction.showToast({ message: '需要相机权限才能扫码', duration: 1500 });
        return;
      }
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: false,
        enableAlbum: true
      };
      const result = await scanBarcode.startScanForResult(context, options);
      console.info('CoursePage', `扫码结果: ${JSON.stringify(result)}`);
      if (result.originalValue) {
        promptAction.showToast({ message: `扫码结果: ${result.originalValue}`, duration: 2000 });
      }
    } catch (err) {
      console.error('CoursePage', `扫码失败: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '扫码已取消', duration: 1500 });
    }
  }

  /** 周切换回调 */
  private onWeekChange(week: number): void {
    this.store.setCurrentWeek(week);
    this.currentWeek = week;
    this.updateWeekDates();
    console.info(TAG, `week changed to ${week}`);
  }

  /** 右上角刷新课表 */
  private onRefresh(): void {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    console.info('CoursePage', 'onRefresh start');

    this.refreshTimer = setInterval(() => {
      this.refreshRotate = (this.refreshRotate + 9) % 360;
    }, 20);

    setTimeout(async () => {
      if (this.isUseMockData) {
        this.store.setCourses(mockCourseList);
        this.allCourseList = [...mockCourseList];
        this.applyOnlyThisWeekFilter();
        this.empty = this.allCourseList.length === 0;
        this.updateWeekDates();
        this.refreshKey = this.refreshKey + 1;
        console.info('CoursePage', 'mock data refreshed');
      } else {
        await this.fetchCourses();
        this.refreshKey = this.refreshKey + 1;
        console.info('CoursePage', 'api data refreshed');
      }

      if (this.refreshTimer !== -1) {
        clearInterval(this.refreshTimer);
        this.refreshTimer = -1;
      }
      this.refreshRotate = 0;
      this.isRefreshing = false;

      promptAction.showToast({ message: '刷新成功', duration: 1500 });
      console.info('CoursePage', 'refresh success');
    }, 800);
  }

  /** 课程点击弹详情 */
  private onCourseTap(course: CourseData): void {
    this.tappedCourse = course;
    this.showCourseDialog = true;
  }

  private onMoreMenuItemClick(index: number): void {
    if (index === 0) {
      this.onlyThisWeek = !this.onlyThisWeek;
      this.applyOnlyThisWeekFilter();
      this.refreshKey = this.refreshKey + 1;
      promptAction.showToast({
        message: this.onlyThisWeek ? '已只显示本周课程' : '已显示全部课程',
        duration: 1500
      });
      console.info('CoursePage', `onlyThisWeek=${this.onlyThisWeek}`);
      return;
    }
    if (index === 1) {
      this.showSemesterPicker = true;
      return;
    }
    if (index === 2) {
      this.showCampusPicker = true;
      return;
    }
    if (index === 3) {
      this.showWeekAdjust = true;
      this.showMoreMenu = false;
      return;
    }
    if (index === 4) {
      router.pushUrl({ url: 'pages/course/CourseArchivePage' });
      return;
    }
    if (index === 5) {
      router.pushUrl({ url: 'pages/course/ScheduleSetting' });
      return;
    }
    if (index === 6) {
      router.pushUrl({ url: 'pages/course/BackgroundSetting' });
      return;
    }
    console.info('CoursePage', `more menu clicked index=${index}`);
  }

  private closeMoreMenu(): void {
    this.menuAnim = false;
    setTimeout(() => {
      this.showMoreMenu = false;
    }, 250);
  }

  /** 重试加载 */
  private retry(): void {
    this.loading = true;
    this.errorMsg = '';
    this.fetchCourses().finally(() => { this.loading = false; });
  }

  /** 保存所选学期并重新请求该学期课表。 */
  private async switchSemester(semester: string): Promise<void> {
    if (!semester || semester === this.store.semester) {
      this.currentSemester = semester || this.currentSemester;
      return;
    }

    const s = PreferenceStorage.getInstance();
    this.currentSemester = semester;
    this.store.setSemester(semester);
    await s.setSemester(semester);
    await s.setSelectSemester(semester);

    this.loading = true;
    this.errorMsg = '';
    try {
      await this.fetchCourses();
      this.refreshKey = this.refreshKey + 1;
      if (!this.errorMsg) {
        promptAction.showToast({ message: `已切换到${semester}`, duration: 1500 });
      }
    } finally {
      this.loading = false;
    }
  }

  /** fallback 学期计算 */
  private calcSemesterFallback(): string {
    const now = new Date();
    const m = now.getMonth() + 1;
    const d = now.getDate();
    const first = m > 8 || (m === 8 && d >= 15);
    return first
      ? `${now.getFullYear()}-${now.getFullYear() + 1}-1`
      : `${now.getFullYear() - 1}-${now.getFullYear()}-2`;
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.scheduleSettings.bgImage) {
        Image(this.scheduleSettings.bgImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.scheduleSettings.bgOpacity)
      }

      Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Row() {
        Row() {
          Text('‹')
            .fontSize(24)
            .fontColor('#999999')
            .onClick(() => {
              if (this.currentWeek > 1) {
                this.onWeekChange(this.currentWeek - 1);
              }
            })

          Text(`第${this.currentWeek}周`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ left: 10 })

          Image($r('app.media.keyboard_arrow_down'))
            .width(20)
            .height(20)
            .fillColor('#333333')
            .rotate({ angle: this.selectorHeight > 0 ? 180 : 0 })
            .animation({ duration: 200 })
            .margin({ left: 2 })

          if (this.currentWeek !== this.actualCurrentWeek) {
            Text('（非本周）')
              .fontSize(13)
              .fontColor('#B0B0B0')
              .fontWeight(FontWeight.Normal)
              .margin({ left: 6 })
              .lineHeight(18)
          }
        }
        .onClick(() => {
          const isExpanded = this.selectorHeight > 0;
          animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
            this.selectorHeight = isExpanded ? 0 : 104;
          });
        })

        Row() {
          Image($r('app.media.qrcode_scanner'))
            .width(22)
            .height(22)
            .fillColor('#333333')
            .margin({ right: 8 })
            .onClick(() => {
              this.startScan();
            })

          Image($r('app.media.refresh'))
            .width(22)
            .height(22)
            .fillColor('#333333')
            .margin({ right: 8 })
            .rotate({ angle: this.refreshRotate })
            .onClick(() => {
              this.onRefresh();
            })

          Image($r('app.media.more_vert'))
            .width(22)
            .height(22)
            .fillColor('#333333')
            .onClick(() => {
              if (this.showMoreMenu) {
                this.closeMoreMenu();
              } else {
                this.showMoreMenu = true;
                setTimeout(() => {
                  this.menuAnim = true;
                }, 10);
              }
            })
        }
        .alignItems(VerticalAlign.Center)
        .height(32)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(Color.White)

      }
      .width('100%')
      .height(48)

      Column() {
        WeekSelector({
          currentWeek: this.currentWeek,
          actualCurrentWeek: this.actualCurrentWeek,
          totalWeeks: this.store.totalWeeks,
          courseList: this.allCourseList,
          onWeekSelect: (week: number) => {
            console.info('CoursePage', `onWeekSelect: ${week}`);
            this.currentWeek = week;
            this.store.setCurrentWeek(week);
            this.updateWeekDates();
            this.refreshKey = this.refreshKey + 1;
            this.applyOnlyThisWeekFilter();
            let la: CourseData | null = null;
            for (let i = 0; i < this.courseList.length; i++) {
              if (this.courseList[i].courseName === '线性代数') {
                la = this.courseList[i];
                break;
              }
            }
            if (la !== null) {
              const r = isCourseInWeek(la, week);
              console.info('CoursePage', `onWeekSelect week=${week} 线性代数 inWeek=${r} weekRanges=${la.weekRanges}`);
            }
          }
        })
      }
      .width('100%')
      .height(this.selectorHeight)
      .clip(true)
      .animation({ duration: 300, curve: Curve.EaseInOut })

      // 主内容区
      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#1ec98d')
          Text('课表加载中...').fontSize(14).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.errorMsg && this.courseList.length === 0) {
        // 错误状态（无缓存数据）
        Column() {
          Text('课表加载失败').fontSize(16).fontColor('#666666')
          Text(this.errorMsg).fontSize(13).fontColor('#999999').margin({ top: 8 })
          Button('重试').fontSize(14).fontColor(Color.White)
            .backgroundColor('#1ec98d').borderRadius(6)
            .margin({ top: 16 }).onClick(() => this.retry())
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.empty && this.visibleList.length === 0) {
        // 空课表
        Column() {
          Text('本周暂无课程安排').fontSize(16).fontColor('#999999')
          Text('点击上方箭头切换教学周查看').fontSize(13).fontColor('#BBBBBB').margin({ top: 8 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        // 正常课表网格
        CourseCalendar({
          currentWeek: this.currentWeek,
          refreshKey: this.refreshKey,
          onCourseClick: (course: CourseData) => this.onCourseTap(course),
          courseList: this.courseList,
          weekDates: this.weekDates,
          monthLabel: this.monthLabel,
          timeSlots: getTimeSlotsByCampus(this.currentCampus),
          sundayFirst: this.sundayFirst,
          courseFontSize: this.scheduleSettings.fontSize,
          courseItalic: this.scheduleSettings.italic,
        })
          .layoutWeight(1)
      }
      if (this.showCourseDialog && this.tappedCourse) {
        CourseDetailDialog({
          course: this.tappedCourse,
          onClose: () => { this.showCourseDialog = false; }
        })
      }
      }
      .width('100%').height('100%')
      .backgroundColor(this.scheduleSettings.bgImage ? '#00F5F5F5' : '#F5F5F5')

      if (this.showMoreMenu) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#40000000')
            .opacity(this.menuAnim ? 1 : 0)
            .animation({ duration: 250, curve: Curve.EaseOut })
            .onClick(() => {
              this.closeMoreMenu();
            })

          CourseMoreMenu({
            onlyThisWeek: this.onlyThisWeek,
            onMenuItemClick: (index: number) => {
              this.onMoreMenuItemClick(index);
            },
            onClose: () => {
              this.closeMoreMenu();
            }
          })
          .scale({ x: this.menuAnim ? 1 : 0.85, y: this.menuAnim ? 1 : 0.85 })
          .opacity(this.menuAnim ? 1 : 0)
          .translate({ x: this.menuAnim ? 0 : 20, y: this.menuAnim ? 0 : -15 })
          .animation({ duration: 250, curve: Curve.EaseOut })
          .margin({ top: 56, right: 12 })
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
      }

      CampusPicker({
        visible: this.showCampusPicker,
        selectedCampus: this.currentCampus,
        onCancel: () => {
          this.showCampusPicker = false;
        },
        onConfirm: (campus: string) => {
          this.currentCampus = campus;
          this.showCampusPicker = false;
          promptAction.showToast({ message: `已切换到${campus}`, duration: 1500 });
        }
      })

      SemesterPicker({
        visible: this.showSemesterPicker,
        selectedSemester: this.currentSemester,
        onCancel: () => {
          this.showSemesterPicker = false;
        },
        onConfirm: (semester: string) => {
          this.showSemesterPicker = false;
          this.switchSemester(semester);
        }
      })

      WeekAdjustPicker({
        visible: this.showWeekAdjust,
        currentWeek: this.currentWeek,
        onConfirm: (week: number) => {
          this.actualCurrentWeek = week;
          this.currentWeek = week;
          AppStorage.setOrCreate('adjustedCurrentWeek', week);
          PreferenceStorage.getInstance().setSettingNumber('adjustedCurrentWeek', week);
          this.store.setCurrentWeek(week);
          this.updateWeekDates();
          this.refreshKey = this.refreshKey + 1;
          if (this.onlyThisWeek) {
            this.applyOnlyThisWeekFilter();
          }
          this.showWeekAdjust = false;
          promptAction.showToast({ message: `已校准为第${week}周`, duration: 1500 });
        },
        onCancel: () => {
          this.showWeekAdjust = false;
        }
      })

      // 回到本周定位按钮（仅非本周时显示）
      if (this.currentWeek !== this.actualCurrentWeek) {
        Column() {
          Image($r('app.media.location_on'))
            .width(24)
            .height(24)
            .fillColor('#666666')
        }
        .width(44)
        .height(44)
        .borderRadius(12)
        .backgroundColor('#F0F0F0')
        .justifyContent(FlexAlign.Center)
        .shadow({
          radius: 6,
          color: '#30000000',
          offsetX: 0,
          offsetY: 2
        })
        .position({ x: '86%', y: '72%' })
        .onClick(() => {
          this.currentWeek = this.actualCurrentWeek;
          this.store.setCurrentWeek(this.actualCurrentWeek);
          this.updateWeekDates();
          this.refreshKey = this.refreshKey + 1;
          if (this.onlyThisWeek) {
            this.applyOnlyThisWeekFilter();
          }
          promptAction.showToast({ message: '已经回到当前周', duration: 1500 });
        })
      }
    }
    .width('100%').height('100%')
  }
}
