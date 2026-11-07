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

const MODE_KEY: string = 'widgetMode';
const COUNTDOWN_KEY: string = 'widgetCountdowns';
const ACCENT_KEY: string = 'widgetAccent';

export interface WidgetCountdownItem {
  title: string;
  date: string;
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
  accent: string;
  updatedAt: string;
}

const WEEKDAY_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

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
    const accent = await storage.getSettingString(ACCENT_KEY, '#1EC98D');
    return accent.length > 0 ? accent : '#1EC98D';
  }

  static async setAccent(storage: AppStorage, accent: string): Promise<void> {
    await storage.setSettingString(ACCENT_KEY, accent);
  }

  static async getCountdowns(storage: AppStorage): Promise<WidgetCountdownItem[]> {
    const raw = await storage.getSettingString(COUNTDOWN_KEY, '');
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as WidgetCountdownItem[];
      if (!Array.isArray(parsed)) return [];
      const items: WidgetCountdownItem[] = [];
      for (let i = 0; i < parsed.length; i++) {
        const item = parsed[i];
        if (item && typeof item.title === 'string' && typeof item.date === 'string') {
          items.push({ title: item.title, date: item.date });
        }
      }
      return items;
    } catch {
      return [];
    }
  }

  static async setCountdowns(storage: AppStorage, items: WidgetCountdownItem[]): Promise<void> {
    await storage.setSettingString(COUNTDOWN_KEY, JSON.stringify(items));
  }
}

export class WidgetData {
  private static two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static formatDate(date: Date): string {
    return `${date.getFullYear()}-${WidgetData.two(date.getMonth() + 1)}-${WidgetData.two(date.getDate())}`;
  }

  /** 解析 YYYY-MM-DD，失败返回 null。 */
  private static parseDate(value: string): Date | null {
    if (!value) return null;
    const parts = value.split('-');
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

  private static countdownSnapshot(items: WidgetCountdownItem[], accent: string): WidgetSnapshot {
    const today = new Date();
    const todayDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    let title = '倒计时';
    let subtitle = '还没有添加倒计时';
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
    const target = upcoming.length > 0 ? upcoming[0] : (sorted.length > 0 ? sorted[0] : null);
    if (target !== null) {
      title = target.title;
      const date = WidgetData.parseDate(target.date);
      if (date !== null) {
        const days = Math.round((date.getTime() - todayDay.getTime()) / (24 * 60 * 60 * 1000));
        subtitle = days >= 0 ? `还有 ${days} 天` : `已过去 ${-days} 天`;
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
      accent: accent,
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
    for (let i = 0; i < picked.length && lines.length < 4; i++) {
      const course = picked[i];
      const where = course.location && course.location.length > 0 ? ` @${course.location}` : '';
      const day = weekly ? `${WEEKDAY_NAMES[course.dayOfWeek % 7]} ` : '';
      lines.push(`${day}${course.startPeriod}-${course.endPeriod}节 ${course.courseName}${where}`);
    }
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
      accent: accent,
      updatedAt: WidgetData.formatDate(today)
    };
  }

  static async build(storage: AppStorage): Promise<WidgetSnapshot> {
    const mode = await WidgetPrefs.getMode(storage);
    const accent = await WidgetPrefs.getAccent(storage);
    if (mode === WIDGET_MODE_COUNTDOWN) {
      const items = await WidgetPrefs.getCountdowns(storage);
      return WidgetData.countdownSnapshot(items, accent);
    }
    let courses: CourseData[] = [];
    try {
      courses = await storage.getCurrentCourses();
    } catch {
      courses = [];
    }
    const week = await WidgetData.currentWeek(storage);
    return WidgetData.courseSnapshot(courses, week, mode, accent);
  }
}
