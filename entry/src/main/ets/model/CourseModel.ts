/**
 * 课程数据模型
 *
 * 对应原 Android CourseBean.java
 * dayOfWeek: 1=周一 ... 7=周日
 * startPeriod/endPeriod: 第几节 (1-12)
 * weekRanges: 周次范围字符串, 如 "1-16" 或 "1,3,5,7-16"
 */
export interface CourseData {
  courseName: string;
  teacher: string;
  location: string;
  dayOfWeek: number;
  startPeriod: number;
  endPeriod: number;
  weekRanges: string;
  color?: string;
}

/**
 * 课表网络接口返回格式
 * 对应 Android CourseData
 */
export interface CourseListResponse {
  /** 课程列表 */
  list: CourseData[];
  /** 当前学期 */
  semester: string;
  /** 当前周 */
  currentWeek: number;
  /** 总周数 */
  totalWeeks: number;
}

/**
 * 判断某周是否在当前课程的周次范围内
 * 解析 "1-16" / "1,3,5,7-16" 格式
 */
export function isCourseInWeek(course: CourseData, week: number): boolean {
  if (!course.weekRanges || course.weekRanges.length === 0) {
    return true;
  }

  let rangesStr = course.weekRanges;
  rangesStr = rangesStr.split(' ').join('');
  rangesStr = rangesStr.split('周').join('');
  rangesStr = rangesStr.split('第').join('');

  const ranges = rangesStr.split(',');
  for (let i = 0; i < ranges.length; i++) {
    const range = ranges[i];
    if (range.length === 0) {
      continue;
    }

    const dashIndex = range.indexOf('-');
    if (dashIndex > 0) {
      const startStr = range.substring(0, dashIndex);
      const endStr = range.substring(dashIndex + 1);
      const start = parseInt(startStr);
      const end = parseInt(endStr);
      if (!isNaN(start) && !isNaN(end)) {
        if (week >= start && week <= end) {
          if (range.indexOf('单') >= 0 && week % 2 === 0) {
            continue;
          }
          if (range.indexOf('双') >= 0 && week % 2 === 1) {
            continue;
          }
          return true;
        }
      }
    } else {
      const w = parseInt(range);
      if (!isNaN(w) && w === week) {
        return true;
      }
    }
  }
  return false;
}

export interface CourseArchive {
  id: string;
  name: string;
  semester: string;
  courses: CourseData[];
  isMine: boolean;
}

export function getDefaultArchive(): CourseArchive {
  return {
    id: 'mine',
    name: '我的课表',
    semester: '2026-2027-1',
    courses: [
      { courseName: '高等数学', teacher: '张老师', location: '教1-203', dayOfWeek: 1, startPeriod: 1, endPeriod: 2, weekRanges: '1-16', color: '#FD999A' },
      { courseName: '大学物理', teacher: '李老师', location: '教2-405', dayOfWeek: 2, startPeriod: 3, endPeriod: 4, weekRanges: '1-16', color: '#66CC99' },
      { courseName: '程序设计', teacher: '王老师', location: '计科-301', dayOfWeek: 3, startPeriod: 5, endPeriod: 6, weekRanges: '1-16', color: '#66BDB0' },
      { courseName: '数据结构', teacher: '赵老师', location: '计科-205', dayOfWeek: 1, startPeriod: 3, endPeriod: 4, weekRanges: '1,3,5,7,9,11,13,15', color: '#2196F3' },
      { courseName: '线性代数', teacher: '孙老师', location: '教3-102', dayOfWeek: 2, startPeriod: 5, endPeriod: 6, weekRanges: '2,4,6,8,10,12,14,16', color: '#BF83DA' },
      { courseName: '大学英语', teacher: '周老师', location: '外语楼-201', dayOfWeek: 4, startPeriod: 1, endPeriod: 2, weekRanges: '1-16', color: '#68C4CF' },
      { courseName: '体育', teacher: '吴老师', location: '体育馆', dayOfWeek: 5, startPeriod: 3, endPeriod: 4, weekRanges: '1-16', color: '#FF5722' },
      { courseName: '形势与政策', teacher: '郑老师', location: '教4-101', dayOfWeek: 3, startPeriod: 9, endPeriod: 11, weekRanges: '5,6,7,8', color: '#00D4BB' }
    ],
    isMine: true
  };
}

/** 课程色块颜色池 —— 对应 Android colorClass1~colorClass8 */
export const COURSE_COLORS: string[] = [
  '#fd999a', '#66cc99', '#66bdb0', '#2196f3',
  '#bf83da', '#68c4cf', '#ff5722', '#00d4bb',
  '#968cdc', '#4cb050',
];

export function getCourseColor(index: number): string {
  return COURSE_COLORS[index % COURSE_COLORS.length];
}

/** 教学周常量 */
export const TOTAL_WEEKS = 25;
export const PERIOD_HEIGHT = 60; // 每节课高度 vp
export const LABEL_WIDTH = 36;   // 节次标签列宽度 vp
export const DAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];
export const PERIOD_COUNT = 12;

export const DEFAULT_BG_OPACITY: number = 0;
export const DEFAULT_FONT_SIZE: number = 11;
export const DEFAULT_BG_FULLSCREEN: boolean = false;
export const DEFAULT_ITALIC: boolean = false;

export interface ScheduleSettings {
  bgImage: string;
  bgOpacity: number;
  bgFullscreen: boolean;
  fontSize: number;
  italic: boolean;
}

export const DEFAULT_SETTINGS: ScheduleSettings = {
  bgImage: '',
  bgOpacity: 0,
  bgFullscreen: false,
  fontSize: 11,
  italic: false,
};

export interface CourseTimeSlot {
  start: string;
  end: string;
  startPeriod: number;
  endPeriod: number;
}

/** 黄家湖校区作息时间。 */
export const TIME_SLOTS_HUANGJIAHU: CourseTimeSlot[] = [
  { start: '08:20', end: '10:00', startPeriod: 1, endPeriod: 2 },
  { start: '10:20', end: '12:00', startPeriod: 3, endPeriod: 4 },
  { start: '14:00', end: '15:40', startPeriod: 5, endPeriod: 6 },
  { start: '16:00', end: '17:40', startPeriod: 7, endPeriod: 8 },
  { start: '18:40', end: '20:20', startPeriod: 9, endPeriod: 10 },
  { start: '20:30', end: '22:10', startPeriod: 11, endPeriod: 12 },
];

/** 青山校区作息时间：上午早20分钟，下午和晚上不变。 */
export const TIME_SLOTS_QINGSHAN: CourseTimeSlot[] = [
  { start: '08:00', end: '09:40', startPeriod: 1, endPeriod: 2 },
  { start: '10:10', end: '11:50', startPeriod: 3, endPeriod: 4 },
  { start: '14:00', end: '15:40', startPeriod: 5, endPeriod: 6 },
  { start: '16:00', end: '17:40', startPeriod: 7, endPeriod: 8 },
  { start: '18:40', end: '20:20', startPeriod: 9, endPeriod: 10 },
  { start: '20:30', end: '22:10', startPeriod: 11, endPeriod: 12 },
];

export function getTimeSlotsByCampus(campus: string): CourseTimeSlot[] {
  if (campus === '青山校区') {
    return TIME_SLOTS_QINGSHAN;
  }
  return TIME_SLOTS_HUANGJIAHU;
}

/** 保留默认值，避免旧代码引用报错。 */
export const TIME_SLOTS: CourseTimeSlot[] = TIME_SLOTS_HUANGJIAHU;
