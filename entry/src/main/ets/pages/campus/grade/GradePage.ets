/**
 * GradePage — 成绩查询页面
 * 对应安卓 GradeActivity，逻辑对齐：
 *   1. 页面进入 → 校验登录 → getGrade()
 *   2. 成功 → 展示全部成绩 + 提取学期列表
 *   3. 失败 → 提示网络异常
 *   4. 学期切换 → 按 schoolTerm 筛选
 *   5. 401/403 → 跳转 LoginPage
 *
 * 文件路径：entry/src/main/ets/pages/campus/grade/GradePage.ets
 */
import { RouterUtil } from '../../../utils/RouterUtil';
import { AppStorage } from '../../../store/AppStorage';
import { GradeApi } from '../../../net/GradeApi';
import { GradeStore } from '../../../store/GradeStore';
import { GradeBean, calcGradeSummary, GradeStatSummary } from '../../../model/GradeModel';
import { TermSelector } from '../../../components/TermSelector';
import { GradeStatCard } from '../../../components/GradeStatCard';
import { GradeItem } from '../../../components/GradeItem';

const TAG = 'GradePage';

interface MockGradeItem extends GradeBean {
  credit: number;
  score: number;
  isPassed: boolean;
  semester: string;
  courseType: string;
}

const mockSemesterList: string[] = ['2024-2025-1', '2024-2025-2', '2025-2026-1'];

const mockGradeList: MockGradeItem[] = [
  { courseNum: 'MATH101', courseName: '高等数学', grade: '92', courseCredit: '4', courseHours: '64', gradePoint: '4.0', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2024-2025-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 4, score: 92, isPassed: true, semester: '2024-2025-1', courseType: '必修' },
  { courseNum: 'ENGL102', courseName: '大学英语', grade: '78', courseCredit: '3', courseHours: '48', gradePoint: '2.8', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2024-2025-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 3, score: 78, isPassed: true, semester: '2024-2025-1', courseType: '必修' },
  { courseNum: 'CS101', courseName: '程序设计基础', grade: '55', courseCredit: '3', courseHours: '48', gradePoint: '0.0', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2024-2025-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 3, score: 55, isPassed: false, semester: '2024-2025-1', courseType: '必修' },
  { courseNum: 'ART201', courseName: '艺术鉴赏', grade: '86', courseCredit: '2', courseHours: '32', gradePoint: '3.3', evaluationMode: '考查', examNature: '正常', courseNature: '选修', schoolTerm: '2024-2025-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 2, score: 86, isPassed: true, semester: '2024-2025-1', courseType: '选修' },
  { courseNum: 'PHY201', courseName: '大学物理', grade: '96', courseCredit: '4', courseHours: '64', gradePoint: '4.0', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2024-2025-2', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 4, score: 96, isPassed: true, semester: '2024-2025-2', courseType: '必修' },
  { courseNum: 'PE202', courseName: '体育', grade: '82', courseCredit: '1', courseHours: '32', gradePoint: '3.0', evaluationMode: '考查', examNature: '正常', courseNature: '选修', schoolTerm: '2024-2025-2', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 1, score: 82, isPassed: true, semester: '2024-2025-2', courseType: '选修' },
  { courseNum: 'ENG203', courseName: '英语听说', grade: '58', courseCredit: '2', courseHours: '32', gradePoint: '0.0', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2024-2025-2', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 2, score: 58, isPassed: false, semester: '2024-2025-2', courseType: '必修' },
  { courseNum: 'HIS204', courseName: '中国近现代史', grade: '76', courseCredit: '2', courseHours: '32', gradePoint: '2.5', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2024-2025-2', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 2, score: 76, isPassed: true, semester: '2024-2025-2', courseType: '必修' },
  { courseNum: 'CS301', courseName: '数据结构', grade: '91', courseCredit: '4', courseHours: '64', gradePoint: '4.0', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2025-2026-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 4, score: 91, isPassed: true, semester: '2025-2026-1', courseType: '必修' },
  { courseNum: 'AI302', courseName: '人工智能导论', grade: '88', courseCredit: '2', courseHours: '32', gradePoint: '3.5', evaluationMode: '考查', examNature: '正常', courseNature: '选修', schoolTerm: '2025-2026-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 2, score: 88, isPassed: true, semester: '2025-2026-1', courseType: '选修' },
  { courseNum: 'SE303', courseName: '软件工程', grade: '63', courseCredit: '3', courseHours: '48', gradePoint: '1.0', evaluationMode: '考试', examNature: '正常', courseNature: '必修', schoolTerm: '2025-2026-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 3, score: 63, isPassed: true, semester: '2025-2026-1', courseType: '必修' },
  { courseNum: 'PE304', courseName: '篮球', grade: '72', courseCredit: '1', courseHours: '32', gradePoint: '2.0', evaluationMode: '考查', examNature: '正常', courseNature: '选修', schoolTerm: '2025-2026-1', missExamTag: 0, reExamTag: 0, rebuildTag: 0, credit: 1, score: 72, isPassed: true, semester: '2025-2026-1', courseType: '选修' },
]

interface MockSummary {
  totalCredit: string;
  avgGpa: string;
  avgScore: string;
  rank: string;
  totalStudent: number;
}

const mockSummary: MockSummary = {
  totalCredit: '42.0',
  avgGpa: '3.20',
  avgScore: '82.5',
  rank: '12',
  totalStudent: 60,
};

/** 成绩详情弹窗 */
@CustomDialog
struct GradeDetailDialog {
  controller?: CustomDialogController;
  grade?: GradeBean;
  onClose?: () => void;

  build() {
    Column() {
      Text(this.grade?.courseName ?? '').fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor('#333333').margin({ top: 16 })
      Divider().margin({ top: 12, bottom: 12 })
      this.detailRow('课程编号', this.grade?.courseNum ?? '')
      this.detailRow('课程性质', this.grade?.courseNature ?? '')
      this.detailRow('考核方式', this.grade?.evaluationMode ?? '')
      this.detailRow('学分', this.grade?.courseCredit ?? '0')
      this.detailRow('成绩', this.grade?.grade ?? '0')
      this.detailRow('绩点', this.grade?.gradePoint ?? '0')
      this.detailRow('学期', this.grade?.schoolTerm ?? '')
      Text('关闭').fontSize(16).fontColor('#1ec98d').margin({ top: 12, bottom: 12 })
        .onClick(() => this.onClose?.())
    }
    .width('80%').backgroundColor(Color.White).borderRadius(12).padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private detailRow(label: string, value: string) {
    Row() {
      Text(label).width(80).fontSize(14).fontColor('#999999')
      Text(value).fontSize(14).fontColor('#333333').layoutWeight(1)
    }
    .width('100%').height(30).padding({ left: 16, right: 16 })
  }
}

@Entry
@Component
struct GradePage {
  @State private gradeList: GradeBean[] = [];
  @State private summary: GradeStatSummary = {
    totalCredits: '0', averageGpa: '0', courseCount: 0, failedCount: 0,
  };
  @State private termOptions: string[] = ['全部成绩'];
  @State private selectedTerm: string = '全部成绩';
  @State private loading: boolean = true;
  @State private errorMsg: string = '';
  @State private showGradeDialog: boolean = false;
  @State private tappedGrade: GradeBean | null = null;

  private isUseMockData: boolean = true;
  private store: GradeStore = GradeStore.getInstance();

  aboutToAppear(): void {
    this.verifyAndLoad();
  }

  private async verifyAndLoad(): Promise<void> {
    console.info(TAG, `isUseMockData=${this.isUseMockData}`);

    if (this.isUseMockData) {
      this.store.allGradeList = mockGradeList;
      this.store.gradeList = mockGradeList;
      this.store.extractTerms(mockGradeList);
      this.termOptions = this.store.termOptions;
      this.selectedTerm = '全部成绩';
      this.gradeList = mockGradeList;
      this.summary = calcGradeSummary(mockGradeList);
      this.loading = false;
      this.errorMsg = '';
      console.info(TAG, `mock loaded ${mockGradeList.length} grades`);
      console.info(TAG, `mockSemesterList=${mockSemesterList.join(',')}`);
      console.info(TAG, `mockSummary=${JSON.stringify(mockSummary)}`);
      return;
    }

    try {
      const appStorage = AppStorage.getInstance();
      const token = await appStorage.getToken();
      const isLogin = await appStorage.getIsLogin();
      if (!token || !isLogin) {
        RouterUtil.toLogin();
        return;
      }
      await this.fetchGrades();
    } catch {
      console.error(TAG, 'verify error');
      this.loading = false;
      this.errorMsg = '登录状态校验失败';
    }
  }

  private async fetchGrades(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    try {
      const appStorage = AppStorage.getInstance();
      const token = await appStorage.getToken();
      if (!token) {
        this.errorMsg = '登录已失效';
        return;
      }
      const resp = await GradeApi.getGrade(token);
      if (resp.code === 200 || resp.code === 0 || resp.code === 10000 || resp.code === 11000) {
        const list: GradeBean[] = resp.data ?? [];
        this.store.allGradeList = list;
        this.store.gradeList = list;
        this.store.extractTerms(list);
        this.termOptions = this.store.termOptions;
        this.selectedTerm = '全部成绩';
        this.gradeList = list;
        this.summary = calcGradeSummary(list);
        this.errorMsg = '';
        console.info(TAG, `loaded ${list.length} grades`);
      } else if (resp.code === 401 || resp.code === 403) {
        this.errorMsg = '登录已过期，正在跳转...';
        setTimeout(() => RouterUtil.toLogin(), 1500);
      } else {
        this.errorMsg = resp.msg || '成绩获取失败';
      }
    } catch {
      console.warn(TAG, 'fetchGrades error');
      this.errorMsg = '网络请求失败，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  private onTermChange(term: string): void {
    this.selectedTerm = term;
    if (term === '' || term === '全部成绩') {
      this.gradeList = this.store.allGradeList;
    } else {
      const filtered: GradeBean[] = [];
      for (const g of this.store.allGradeList) {
        if (g.schoolTerm === term) {
          filtered.push(g);
        }
      }
      this.gradeList = filtered;
    }
    this.summary = calcGradeSummary(this.gradeList);
    console.info(TAG, `term changed to ${term}, filtered ${this.gradeList.length} grades`);
  }

  private onGradeTap(grade: GradeBean): void {
    this.tappedGrade = grade;
    this.showGradeDialog = true;
  }

  private retry(): void {
    this.fetchGrades();
  }

  build() {
    Column() {
      // 学期选择器
      TermSelector({
        termOptions: this.termOptions,
        selectedTerm: this.selectedTerm,
        onTermChange: (term: string) => this.onTermChange(term),
      })

      // 统计卡片
      GradeStatCard({ summary: this.summary })
        .margin({ top: 8, left: 16, right: 16 })

      // 主内容
      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#1ec98d')
          Text('正在拼命加载中...').fontSize(14).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.errorMsg !== '' && this.gradeList.length === 0) {
        Column() {
          Text(this.errorMsg).fontSize(14).fontColor('#f44336')
          Button('重试').fontSize(14).fontColor(Color.White)
            .backgroundColor('#1ec98d').borderRadius(6).margin({ top: 16 })
            .onClick(() => this.retry())
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.gradeList.length === 0) {
        Column() {
          Text('暂无成绩记录').fontSize(16).fontColor('#999999')
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.gradeList, (grade: GradeBean) => {
              GradeItem({
                grade: grade,
                onItemTap: () => this.onGradeTap(grade),
              })
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
      }
      if (this.showGradeDialog && this.tappedGrade) {
        GradeDetailDialog({
          grade: this.tappedGrade,
          onClose: () => { this.showGradeDialog = false; }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
