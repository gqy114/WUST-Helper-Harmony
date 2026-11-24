/**
 * 桌面小组件的数据与偏好设置。
 *
 * 卡片本身不能访问网络或 Preferences，数据由 EntryFormAbility 组装后通过
 * formBindingData 注入。设置页修改偏好后也调用这里重新生成数据并刷新卡片。
 */
import { AppStorage } from '../store/AppStorage';
import { CourseData, getCourseColor, isCourseInWeek, PERIOD_COUNT, TOTAL_WEEKS, getTimeSlotsByCampus } from '../model/CourseModel';

export const WIDGET_MODE_COUNTDOWN: string = 'countdown';
export const WIDGET_MODE_DAILY: string = 'daily';
export const WIDGET_MODE_WEEKLY: string = 'weekly';
export const WIDGET_MODE_QUICK: string = 'quick';

export const WIDGET_THEME_SYSTEM: string = 'system';
export const WIDGET_THEME_LIGHT: string = 'light';
export const WIDGET_THEME_DARK: string = 'dark';

const MODE_KEY: string = 'widgetMode';
const COUNTDOWN_KEY: string = 'widgetCountdowns';
const EXAM_KEY: string = 'widgetExamCountdowns';
const ACCENT_KEY: string = 'widgetAccent';
const BACKGROUND_KEY: string = 'widgetBackgroundPath';
const OPACITY_KEY: string = 'widgetBackgroundOpacity';
const THEME_KEY: string = 'widgetTheme';

export const DEFAULT_BACKGROUND_OPACITY: number = 0.7;

export interface WidgetCountdownItem {
  title: string;
  date: string;
  detail?: string;
  startedOn?: string;
}

export interface WidgetCountdownSlide {
  title: string;
  date: string;
  elapsed: string;
  remaining: string;
}

interface QuickRoomPref { id?: string; name?: string; remaining?: string; unit?: string; }

export interface WidgetSnapshot {
  mode: string;
  title: string;
  subtitle: string;
  line0: string;
  line1: string;
  line2: string;
  line3: string;
  line4: string;
  line5: string;
  /** 倒计时天数，考试倒计时用 */
  days: string;
  /** 倒计时补充信息，例如考场 */
  detail: string;
  accent: string;
  /** 自定义背景图（应用沙箱路径），空串表示纯色 */
  bg: string;
  /** 只作用于背景图的不透明度 */
  bgOpacity: number;
  cardBg: string;
  textColor: string;
  subColor: string;
  updatedAt: string;
  weeklyCourses?: string;
  weeklyPages?: string;
  weeklyCurrentWeek?: number;
  campus?: string;
  dailyCourses?: string;
  dailyWeekday?: string;
  countdownSlides?: string;
}

export interface WeeklyWidgetPages {
  grids: string[];
  weekGridIndexes: number[];
}

export interface DailyWidgetCourse {
  name: string;
  details: string;
  start: string;
  end: string;
}

export interface WeeklyWidgetCourse {
  name: string;
  location: string;
  color: string;
  day: number;
  start: number;
  end: number;
  lane: number;
  lanes: number;
}

const WEEKDAY_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function themeColors(dark: boolean): string[] {
  // [卡片底色, 主文字, 次文字]
  // 简洁白：白色蒙版（半透明）盖在背景图上，而不是整块不透明白。
  return dark ? ['#1C1C1E', '#FFFFFF', '#B9BDC6'] : ['#F2FFFFFF', '#111111', '#666666'];
}

function normalizeOpacity(value: number): number {
  if (isNaN(value)) return DEFAULT_BACKGROUND_OPACITY;
  const bounded = Math.min(1, Math.max(0.2, value));
  return bounded;
}

export class WidgetPrefs {
  static async getMode(storage: AppStorage): Promise<string> {
    const mode = await storage.getSettingString(MODE_KEY, WIDGET_MODE_COUNTDOWN);
    if (mode === WIDGET_MODE_DAILY || mode === WIDGET_MODE_WEEKLY || mode === WIDGET_MODE_COUNTDOWN) {
      return mode;
    }
    return WIDGET_MODE_COUNTDOWN;
  }

  static async setMode(storage: AppStorage, mode: string): Promise<void> {
    await storage.setSettingString(MODE_KEY, mode);
  }

  static async getAccent(storage: AppStorage): Promise<string> {
    const accent = await storage.getSettingString(ACCENT_KEY, '#EC5A3C');
    return accent.length > 0 ? accent : '#EC5A3C';
  }

  static async setAccent(storage: AppStorage, accent: string): Promise<void> {
    await storage.setSettingString(ACCENT_KEY, accent);
  }

  static async getCountdowns(storage: AppStorage): Promise<WidgetCountdownItem[]> {
    return WidgetPrefs.readItems(storage, COUNTDOWN_KEY);
  }

  static async setCountdowns(storage: AppStorage, items: WidgetCountdownItem[]): Promise<void> {
    await storage.setSettingString(COUNTDOWN_KEY, JSON.stringify(items));
  }

  /** 考试倒计时按学号 + 学期分开存：切账号/切学期都不会读到旧数据。 */
  private static examStorageKey(sid: string, term: string): string {
    const account = sid || 'guest';
    const semester = term || 'unknown';
    return `${EXAM_KEY}_${account}_${semester}`;
  }

  static async getExamCountdowns(storage: AppStorage, sid: string = '', term: string = ''): Promise<WidgetCountdownItem[]> {
    const current = (sid || (await storage.getStudentId())).trim();
    let currentTerm = (term || '').trim();
    if (!currentTerm) {
      currentTerm = (await storage.getSemester()).trim();
      if (!currentTerm) currentTerm = (await storage.getSelectSemester()).trim();
    }
    return WidgetPrefs.readItems(storage, WidgetPrefs.examStorageKey(current, currentTerm));
  }

  static async setExamCountdowns(storage: AppStorage, items: WidgetCountdownItem[], sid: string,
    term: string): Promise<void> {
    const key = WidgetPrefs.examStorageKey(sid.trim(), term.trim());
    const previous = await WidgetPrefs.readItems(storage, key);
    const today = WidgetData.formatDate(new Date());
    const next: WidgetCountdownItem[] = items.map((item: WidgetCountdownItem): WidgetCountdownItem => {
      const cached = previous.find(old => old.title === item.title && old.date === item.date);
      return { title: item.title, date: item.date, detail: item.detail, startedOn: cached?.startedOn || today };
    });
    await storage.setSettingString(key, JSON.stringify(next));
  }

  static async getBackground(storage: AppStorage): Promise<string> {
    return storage.getSettingString(BACKGROUND_KEY, '');
  }

  static async setBackground(storage: AppStorage, path: string): Promise<void> {
    await storage.setSettingString(BACKGROUND_KEY, path);
  }

  static async getBackgroundOpacity(storage: AppStorage): Promise<number> {
    const raw = await storage.getSettingString(OPACITY_KEY, `${DEFAULT_BACKGROUND_OPACITY}`);
    return normalizeOpacity(parseFloat(raw));
  }

  static async setBackgroundOpacity(storage: AppStorage, value: number): Promise<void> {
    await storage.setSettingString(OPACITY_KEY, `${normalizeOpacity(value)}`);
  }

  static async getTheme(storage: AppStorage): Promise<string> {
    const theme = await storage.getSettingString(THEME_KEY, WIDGET_THEME_SYSTEM);
    if (theme === WIDGET_THEME_LIGHT || theme === WIDGET_THEME_DARK) return theme;
    return WIDGET_THEME_SYSTEM;
  }

  static async setTheme(storage: AppStorage, theme: string): Promise<void> {
    await storage.setSettingString(THEME_KEY, theme);
  }

  private static async readItems(storage: AppStorage, key: string): Promise<WidgetCountdownItem[]> {
    const raw = await storage.getSettingString(key, '');
    if (raw.length === 0) return [];
    try {
      const parsed = JSON.parse(raw) as WidgetCountdownItem[];
      if (!Array.isArray(parsed)) return [];
      const items: WidgetCountdownItem[] = [];
      for (let i = 0; i < parsed.length; i++) {
        const item = parsed[i];
        if (item && typeof item.title === 'string' && typeof item.date === 'string') {
          items.push({
            title: item.title,
            date: item.date,
            detail: typeof item.detail === 'string' ? item.detail : '',
            startedOn: typeof item.startedOn === 'string' ? item.startedOn : ''
          });
        }
      }
      return items;
    } catch {
      return [];
    }
  }
}

export class WidgetData {
  private static two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  static formatDate(date: Date): string {
    return `${date.getFullYear()}-${WidgetData.two(date.getMonth() + 1)}-${WidgetData.two(date.getDate())}`;
  }

  /** 解析 YYYY-MM-DD 或带时间的字符串，失败返回 null。 */
  private static parseDate(value: string): Date | null {
    if (!value) return null;
    const dayPart = value.trim().slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dayPart)) return null;
    const parts = dayPart.split('-');
    if (parts.length !== 3) return null;
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);
    if (isNaN(year) || isNaN(month) || isNaN(day)) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    const date = new Date(year, month - 1, day);
    return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day ? date : null;
  }

  private static async currentWeek(storage: AppStorage): Promise<number> {
    const startText = await storage.getTermStartDate();
    const start = WidgetData.parseDate(startText);
    if (start === null) {
      const saved = await storage.getWeek();
      return saved > 0 ? saved : 1;
    }
    const today = new Date();
    const startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate());
    const todayDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const diffDays = Math.floor((todayDay.getTime() - startDay.getTime()) / (24 * 60 * 60 * 1000));
    let week = Math.floor(diffDays / 7) + 1;
    if (week < 1) week = 1;
    if (week > 25) week = 25;
    return week;
  }

  private static calendarDay(date: Date): number {
    return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86400000;
  }

  private static countdownSnapshot(items: WidgetCountdownItem[], accent: string,
    today: Date = new Date()): WidgetSnapshot {
    const currentDay = WidgetData.calendarDay(today);
    const slides: WidgetCountdownSlide[] = [];
    const sorted = [...items].sort((left, right) => left.date.localeCompare(right.date));
    for (const item of sorted) {
      const date = WidgetData.parseDate(item.date);
      if (date === null) continue;
      const remaining = WidgetData.calendarDay(date) - currentDay;
      if (remaining < 0) continue;
      const started = WidgetData.parseDate(item.startedOn || '');
      const slide: WidgetCountdownSlide = {
        title: item.title,
        date: item.date.trim(),
        elapsed: started ? String(Math.max(0, currentDay - WidgetData.calendarDay(started))) : '—',
        remaining: String(remaining)
      };
      slides.push(slide);
    }
    const first = slides[0];
    return {
      mode: WIDGET_MODE_COUNTDOWN,
      title: first?.title ?? '倒计时',
      subtitle: first ? '' : '暂无待显示的倒计时',
      line0: first?.date ?? '',
      line1: '',
      line2: '',
      line3: '',
      line4: '',
      line5: '',
      days: first?.remaining ?? '',
      detail: '',
      countdownSlides: JSON.stringify(slides),
      accent: accent,
      bg: '',
      bgOpacity: DEFAULT_BACKGROUND_OPACITY,
      cardBg: '',
      textColor: '',
      subColor: '',
      updatedAt: WidgetData.formatDate(today)
    };
  }

  private static courseSnapshot(courses: CourseData[], week: number, mode: string, accent: string,
    today: Date = new Date(), campus: string = '黄家湖校区'): WidgetSnapshot {
    const dayOfWeek = today.getDay() === 0 ? 7 : today.getDay();
    const weekly = mode === WIDGET_MODE_WEEKLY;
    const picked: CourseData[] = [];
    for (let i = 0; i < courses.length; i++) {
      const course = courses[i];
      if (!isCourseInWeek(course, week)) continue;
      // 每周课表要展示整周；只有每日课表才按今天过滤。
      if (!weekly && course.dayOfWeek !== dayOfWeek) continue;
      picked.push(course);
    }
    picked.sort((left: CourseData, right: CourseData): number => {
      if (left.dayOfWeek !== right.dayOfWeek) return left.dayOfWeek - right.dayOfWeek;
      return left.startPeriod - right.startPeriod;
    });

    const lines: string[] = [];
    // 卡片最多四行：正好四门时全部显示；超过四门时显示三门 + 一行剩余数量。
    const overflow = picked.length > 4;
    const maxCourses = overflow ? 3 : picked.length;
    for (let i = 0; i < maxCourses; i++) {
      const course = picked[i];
      const where = course.location && course.location.length > 0 ? ` @${course.location}` : '';
      const day = weekly ? `${WEEKDAY_NAMES[course.dayOfWeek % 7]} ` : '';
      lines.push(`${day}${course.startPeriod}-${course.endPeriod}节 ${course.courseName}${where}`);
    }
    if (overflow) lines.push(`还有 ${picked.length - maxCourses} 门课程`);
    while (lines.length < 4) lines.push('');

    const title = weekly ? `第${week}周` : `${today.getMonth() + 1}月${today.getDate()}日`;
    const subtitle = picked.length > 0
      ? (weekly ? `本周 ${picked.length} 节课` : `今天 ${picked.length} 节课`)
      : (weekly ? '本周没有课程了' : '今天没有课程了');
    const snapshot: WidgetSnapshot = {
      mode: mode,
      title: title,
      subtitle: subtitle,
      line0: lines[0],
      line1: lines[1],
      line2: lines[2],
      line3: lines[3],
      line4: '',
      line5: '',
      days: '',
      detail: '',
      accent: accent,
      bg: '',
      bgOpacity: DEFAULT_BACKGROUND_OPACITY,
      cardBg: '',
      textColor: '',
      subColor: '',
      updatedAt: WidgetData.formatDate(today)
    };
    if (weekly) {
      const pages = WidgetData.weeklyPages(courses);
      snapshot.weeklyCourses = pages.grids[pages.weekGridIndexes[week - 1]] ?? '';
      snapshot.weeklyPages = JSON.stringify(pages);
      snapshot.weeklyCurrentWeek = week;
    } else {
      snapshot.dailyCourses = JSON.stringify(WidgetData.dailyCarousel(picked, today, campus));
      snapshot.dailyWeekday = `第${week}周 ${WEEKDAY_NAMES[today.getDay()]}`;
    }
    return snapshot;
  }

  private static clockMinutes(time: string): number {
    const parts = time.split(':');
    return Number(parts[0]) * 60 + Number(parts[1]);
  }

  private static dailyCarousel(courses: CourseData[], today: Date, campus: string): DailyWidgetCourse[] {
    const items: DailyWidgetCourse[] = [];
    const slots = getTimeSlotsByCampus(campus);
    const now = today.getHours() * 60 + today.getMinutes();
    let first = 0;
    let closest = Number.POSITIVE_INFINITY;
    let closestIsPast = true;
    for (const course of courses) {
      const firstSlot = slots.find((slot) =>
        course.startPeriod >= slot.startPeriod && course.startPeriod <= slot.endPeriod);
      const lastSlot = slots.find((slot) =>
        course.endPeriod >= slot.startPeriod && course.endPeriod <= slot.endPeriod);
      if (!firstSlot || !lastSlot || course.endPeriod < course.startPeriod) continue;

      const start = WidgetData.clockMinutes(firstSlot.start);
      const end = WidgetData.clockMinutes(lastSlot.end);
      const isPast = now > end;
      const distance = Math.max(start - now, now - end, 0);
      if (distance < closest || (distance === closest && closestIsPast && !isPast)) {
        closest = distance;
        closestIsPast = isPast;
        first = items.length;
      }
      items.push({
        name: course.courseName,
        details: [course.location, course.teacher].filter((value: string) => value && value.trim().length > 0).join(' · '),
        start: firstSlot.start,
        end: lastSlot.end
      });
    }
    return items.slice(first).concat(items.slice(0, first));
  }

  private static weeklyPages(courses: CourseData[]): WeeklyWidgetPages {
    const sorted = [...courses].sort((left, right) =>
      left.dayOfWeek - right.dayOfWeek || left.startPeriod - right.startPeriod);
    const grids: string[] = [];
    const weekGridIndexes: number[] = [];
    // 相同的周课表共用一份网格数据。
    for (let week = 1; week <= TOTAL_WEEKS; week++) {
      const grid = JSON.stringify(WidgetData.weeklyGrid(sorted.filter(course => isCourseInWeek(course, week))));
      let gridIndex = grids.indexOf(grid);
      if (gridIndex < 0) {
        gridIndex = grids.length;
        grids.push(grid);
      }
      weekGridIndexes.push(gridIndex);
    }
    return { grids, weekGridIndexes };
  }

  private static weeklyGrid(courses: CourseData[]): WeeklyWidgetCourse[] {
    const grid: WeeklyWidgetCourse[] = [];
    let groupStart = 0;
    let groupEnd = 0;
    let day = 0;
    const laneEnds: number[] = [];
    for (const course of courses) {
      if (course.dayOfWeek < 1 || course.dayOfWeek > 7 || course.startPeriod < 1 ||
        course.endPeriod < course.startPeriod || course.startPeriod > PERIOD_COUNT) continue;
      if (course.dayOfWeek !== day || course.startPeriod > groupEnd) {
        day = course.dayOfWeek;
        groupStart = grid.length;
        groupEnd = 0;
        laneEnds.length = 0;
      }
      let lane = laneEnds.findIndex((end: number) => end < course.startPeriod);
      if (lane < 0) lane = laneEnds.length;
      const end = Math.min(course.endPeriod, PERIOD_COUNT);
      laneEnds[lane] = end;
      groupEnd = Math.max(groupEnd, end);
      grid.push({
        name: course.courseName, location: course.location || '',
        color: course.color || getCourseColor(grid.length),
        day: day, start: course.startPeriod, end: end, lane: lane, lanes: laneEnds.length
      });
      for (let i = groupStart; i < grid.length; i++) {
        grid[i].lanes = laneEnds.length;
      }
    }
    return grid;
  }

  /**
   * 生成卡片数据。
   * @param systemDark 系统是否深色（“跟随系统”主题时使用）。
   */
  /** 快捷功能卡片：电量数据来自本机缓存，其余入口是固定路由。 */
  private static async quickSnapshot(storage: AppStorage, accent: string): Promise<WidgetSnapshot> {
    let roomLabel = '快捷功能';
    let valueText = '校园生活 一手掌握';
    try {
      const raw = await storage.getSettingString('electricityRooms', '');
      const rooms = JSON.parse(raw) as QuickRoomPref[];
      if (Array.isArray(rooms) && rooms.length > 0) {
        const room = rooms[0];
        roomLabel = (room.name || room.id || '我的寝室').trim();
        valueText = `${(room.remaining || '--')}${(room.unit || '度')}`;
      }
    } catch (error) {
      console.warn('WidgetData', `read electricity failed: ${JSON.stringify(error)}`);
    }
    return {
      mode: WIDGET_MODE_QUICK,
      title: roomLabel,
      subtitle: valueText,
      line0: '成绩查询',
      line1: '校园墙',
      line2: '教室查询',
      line3: '图书馆',
      line4: '培养方案',
      line5: '',
      days: '',
      detail: '',
      accent: accent,
      bg: '',
      bgOpacity: 0.7,
      cardBg: '',
      textColor: '',
      subColor: '',
      updatedAt: WidgetData.formatDate(new Date())
    };
  }

  static async build(storage: AppStorage, systemDark: boolean = false,
    modeOverride: string = ''): Promise<WidgetSnapshot> {
    const mode = modeOverride.length > 0 ? modeOverride : await WidgetPrefs.getMode(storage);
    const accent = await WidgetPrefs.getAccent(storage);
    const theme = await WidgetPrefs.getTheme(storage);
    const dark = theme === WIDGET_THEME_DARK || (theme === WIDGET_THEME_SYSTEM && systemDark);
    const colors = themeColors(dark);
    const bg = await WidgetPrefs.getBackground(storage);
    const bgOpacity = await WidgetPrefs.getBackgroundOpacity(storage);

    let snapshot: WidgetSnapshot;
    if (mode === WIDGET_MODE_QUICK) {
      snapshot = await WidgetData.quickSnapshot(storage, accent);
    } else if (mode === WIDGET_MODE_COUNTDOWN) {
      // 考试与自定义倒计时使用同一个轮换队列。
      const sid = (await storage.getStudentId()).trim();
      let term = (await storage.getSemester()).trim();
      if (!term) term = (await storage.getSelectSemester()).trim();
      const today = new Date();
      const exams = await WidgetPrefs.getExamCountdowns(storage, sid, term);
      const custom = await WidgetPrefs.getCountdowns(storage);
      snapshot = WidgetData.countdownSnapshot([...exams, ...custom], accent, today);
    } else {
      let courses: CourseData[] = [];
      try {
        courses = await storage.getCurrentCourses();
      } catch {
        courses = [];
      }
      const week = await WidgetData.currentWeek(storage);
      const campus = await storage.getSettingString('courseCampus', '黄家湖校区');
      snapshot = WidgetData.courseSnapshot(courses, week, mode, accent, new Date(), campus);
      snapshot.campus = campus;
    }
    snapshot.bg = bg;
    snapshot.bgOpacity = bgOpacity;
    snapshot.cardBg = colors[0];
    snapshot.textColor = colors[1];
    snapshot.subColor = colors[2];
    return snapshot;
  }
}
