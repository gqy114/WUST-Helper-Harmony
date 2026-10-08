/**
 * CourseStore — 课表全局状态
 *
 * 文件路径：entry/src/main/ets/store/CourseStore.ets
 */
import { CourseData, getCourseColor } from '../model/CourseModel';
import { AppStorage } from './AppStorage';

export class CourseStore {
  private static instance: CourseStore;
  private _courses: CourseData[] = [];
  private _currentWeek: number = 1;
  private _totalWeeks: number = 25;
  private _semester: string = '';

  static getInstance(): CourseStore {
    if (!CourseStore.instance) {
      CourseStore.instance = new CourseStore();
    }
    return CourseStore.instance;
  }

  get courses(): CourseData[] {
    return this._courses;
  }

  get currentWeek(): number {
    return this._currentWeek;
  }

  get totalWeeks(): number {
    return this._totalWeeks;
  }

  get semester(): string {
    return this._semester;
  }

  /** 从后端数据更新课程列表，自动分配颜色 */
  setCourses(list: CourseData[]): void {
    const result: CourseData[] = [];
    for (let i = 0; i < list.length; i++) {
      const raw = list[i];
      const colored: CourseData = {
        courseName: raw.courseName,
        teacher: raw.teacher,
        location: raw.location,
        dayOfWeek: raw.dayOfWeek,
        startPeriod: raw.startPeriod,
        endPeriod: raw.endPeriod,
        weekRanges: raw.weekRanges,
        color: raw.color ?? getCourseColor(i),
      };
      result.push(colored);
    }
    this._courses = result;
  }

  setCurrentWeek(w: number): void {
    this._currentWeek = w;
  }

  setTotalWeeks(w: number): void {
    this._totalWeeks = w;
  }

  setSemester(s: string): void {
    this._semester = s;
  }

  /** 从 AppStorage 恢复持久化的周次和学期 */
  async restoreFromStorage(): Promise<void> {
    const appStorage = AppStorage.getInstance();
    const savedWeek = await appStorage.getWeek();
    if (savedWeek > 0) {
      this._currentWeek = savedWeek;
    }
    const savedSemester = await appStorage.getSemester();
    if (savedSemester) {
      this._semester = savedSemester;
    }
  }
}
