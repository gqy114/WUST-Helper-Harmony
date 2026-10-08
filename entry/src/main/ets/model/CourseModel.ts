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

export interface CourseTimeSlot {
  start: string;
  end: string;
  startPeriod: number;
  endPeriod: number;
}

/** 左侧时间轴，每两项代表一组两节课的起止时间。 */
export const TIME_SLOTS: CourseTimeSlot[] = [
  { start: '08:20', end: '10:00', startPeriod: 1, endPeriod: 2 },
  { start: '10:20', end: '12:00', startPeriod: 3, endPeriod: 4 },
  { start: '14:00', end: '15:40', startPeriod: 5, endPeriod: 6 },
  { start: '16:00', end: '17:40', startPeriod: 7, endPeriod: 8 },
  { start: '18:40', end: '20:20', startPeriod: 9, endPeriod: 10 },
  { start: '20:30', end: '22:10', startPeriod: 11, endPeriod: 12 },
];
