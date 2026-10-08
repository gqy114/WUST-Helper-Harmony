/**
 * GradeStore — 成绩全局状态
 *
 * 文件路径：entry/src/main/ets/store/GradeStore.ets
 */
import { GradeBean } from '../model/GradeModel';

@Observed
export class GradeStore {
  private static instance: GradeStore;

  /** 当前展示的成绩列表 */
  gradeList: GradeBean[] = [];
  /** 全部成绩（未筛选学期） */
  allGradeList: GradeBean[] = [];
  /** 当前选中学期 */
  currentTerm: string = '';
  /** 所有学期列表（去重） */
  termOptions: string[] = [];
  /** 学期显示名映射 {"全部成绩": ""} */
  termDisplayMap: Record<string, string> = {};
  /** 加载中 */
  loading: boolean = false;
  /** 错误信息 */
  errorMsg: string = '';

  static getInstance(): GradeStore {
    if (!GradeStore.instance) {
      GradeStore.instance = new GradeStore();
    }
    return GradeStore.instance;
  }

  /** 从成绩列表中提取不重复的学期 */
  extractTerms(grades: GradeBean[]): void {
    const seen: string[] = [];
    for (const g of grades) {
      if (g.schoolTerm && !seen.includes(g.schoolTerm)) {
        seen.push(g.schoolTerm);
      }
    }
    // 降序排列（最近学期在前）
    seen.sort().reverse();
    this.termOptions = ['全部成绩', ...seen];
    this.termDisplayMap = { '全部成绩': '' };
    for (const t of seen) {
      this.termDisplayMap[t] = t;
    }
  }
}