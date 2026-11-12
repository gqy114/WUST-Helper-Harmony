/**
 * 桌面小组件的数据与偏好设置。
 *
 * 卡片本身不能访问网络或 Preferences，数据由 EntryFormAbility 组装后通过
 * formBindingData 注入。设置页修改偏好后也调用这里重新生成数据并刷新卡片。
 */
import { AppStorage } from '../store/AppStorage';
import { CourseData, isCourseInWeek } from '../model/CourseModel';

export const WIDGET_MODE_COUNTDOWN: string = 'countdown';
export const WIDGET_MODE_DAILY: string = 'daily';
export const WIDGET_MODE_WEEKLY: string = 'weekly';

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
}

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
}

const WEEKDAY_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function themeColors(dark: boolean): string[] {
  // [卡片底色, 主文字, 次文字]
  return dark ? ['#1C1C1E', '#FFFFFF', '#B9BDC6'] : ['#FFFFFF', '#111111', '#666666'];
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

  /** 考试倒计时按学号分开存：切账号时不会读到上一个账号的考试。 */
  private static examStorageKey(sid: string): string {
    return sid ? `${EXAM_KEY}_${sid}` : EXAM_KEY;
  }

  static async getExamCountdowns(storage: AppStorage, sid: string = ''): Promise<WidgetCountdownItem[]> {
    const current = (sid || (await storage.getStudentId())).trim();
    return WidgetPrefs.readItems(storage, WidgetPrefs.examStorageKey(current));
  }

  static async setExamCountdowns(storage: AppStorage, items: WidgetCountdownItem[], sid: string): Promise<void> {
    const current = (sid || '').trim();
    await storage.setSettingString(WidgetPrefs.examStorageKey(current), JSON.stringify(items));
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
            detail: typeof item.detail === 'string' ? item.detail : ''
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

  private static formatDate(date: Date): string {
    return `${date.getFullYear()}-${WidgetData.two(date.getMonth() + 1)}-${WidgetData.two(date.getDate())}`;
  }

  /** 解析 YYYY-MM-DD 或带时间的字符串，失败返回 null。 */
  private static parseDate(value: string): Date | null {
    if (!value) return null;
    const dayPart = value.trim().slice(0, 10);
    const parts = dayPart.split('-');
    if (parts.length !== 3) return null;
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    const day = parseInt(parts[2], 10);
    if (isNaN(year) || isNaN(month) || isNaN(day)) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return new Date(year, month - 1, day);
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

  /** 按小时轮换：多个考试倒计时时，每小时切换显示下一个。 */
  private static rotationIndex(total: number): number {
    if (total <= 1) return 0;
    return Math.floor(Date.now() / (60 * 60 * 1000)) % total;
  }

  private static countdownSnapshot(items: WidgetCountdownItem[], accent: string): WidgetSnapshot {
    const today = new Date();
    const todayDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    let title = '考试倒计时';
    let subtitle = '还没有考试安排';
    let detail = '';
    let days = '';
    let line0 = '';

    const sorted: WidgetCountdownItem[] = [];
    for (let i = 0; i < items.length; i++) sorted.push(items[i]);
    sorted.sort((left: WidgetCountdownItem, right: WidgetCountdownItem): number => {
      return left.date.localeCompare(right.date);
    });
    const upcoming: WidgetCountdownItem[] = [];
    for (let i = 0; i < sorted.length; i++) {
      const date = WidgetData.parseDate(sorted[i].date);
      if (date === null) continue;
      if (date.getTime() >= todayDay.getTime()) upcoming.push(sorted[i]);
    }
    const pool = upcoming.length > 0 ? upcoming : sorted;
    if (pool.length > 0) {
      const target = pool[WidgetData.rotationIndex(pool.length)];
      title = target.title;
      detail = target.detail || '';
      const date = WidgetData.parseDate(target.date);
      if (date !== null) {
        const remain = Math.round((date.getTime() - todayDay.getTime()) / (24 * 60 * 60 * 1000));
        days = `${remain}`;
        subtitle = remain >= 0 ? `还有 ${remain} 天` : `已过去 ${-remain} 天`;
        line0 = `${target.date} ${WEEKDAY_NAMES[date.getDay()]}`;
      }
    }
    return {
      mode: WIDGET_MODE_COUNTDOWN,
      title: title,
      subtitle: subtitle,
      line0: line0,
      line1: '',
      line2: '',
      line3: '',
      line4: '',
      line5: '',
      days: days,
      detail: detail,
      accent: accent,
      bg: '',
      bgOpacity: DEFAULT_BACKGROUND_OPACITY,
      cardBg: '',
      textColor: '',
      subColor: '',
      updatedAt: WidgetData.formatDate(today)
    };
  }

  private static courseSnapshot(courses: CourseData[], week: number, mode: string, accent: string): WidgetSnapshot {
    const today = new Date();
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
    return {
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
  }

  /**
   * 生成卡片数据。
   * @param systemDark 系统是否深色（“跟随系统”主题时使用）。
   */
  static async build(storage: AppStorage, systemDark: boolean = false): Promise<WidgetSnapshot> {
    const mode = await WidgetPrefs.getMode(storage);
    const accent = await WidgetPrefs.getAccent(storage);
    const theme = await WidgetPrefs.getTheme(storage);
    const dark = theme === WIDGET_THEME_DARK || (theme === WIDGET_THEME_SYSTEM && systemDark);
    const colors = themeColors(dark);
    const bg = await WidgetPrefs.getBackground(storage);
    const bgOpacity = await WidgetPrefs.getBackgroundOpacity(storage);

    let snapshot: WidgetSnapshot;
    if (mode === WIDGET_MODE_COUNTDOWN) {
      // 优先展示考试倒计时；没有考试数据时退回手动倒计时。
      const sid = (await storage.getStudentId()).trim();
      let items = await WidgetPrefs.getExamCountdowns(storage, sid);
      if (items.length === 0) items = await WidgetPrefs.getCountdowns(storage);
      snapshot = WidgetData.countdownSnapshot(items, accent);
    } else {
      let courses: CourseData[] = [];
      try {
        courses = await storage.getCurrentCourses();
      } catch {
        courses = [];
      }
      const week = await WidgetData.currentWeek(storage);
      snapshot = WidgetData.courseSnapshot(courses, week, mode, accent);
    }
    snapshot.bg = bg;
    snapshot.bgOpacity = bgOpacity;
    snapshot.cardBg = colors[0];
    snapshot.textColor = colors[1];
    snapshot.subColor = colors[2];
    return snapshot;
  }
}
