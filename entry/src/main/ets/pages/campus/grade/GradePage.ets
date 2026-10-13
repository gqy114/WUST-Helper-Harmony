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
import { GradeStatCard } from '../../../components/GradeStatCard';
import { GradeItem } from '../../../components/GradeItem';
import { promptAction, router } from '@kit.ArkUI';

const TAG = 'GradePage';

interface GpaTableRow {
  score: string;
  grade: string;
  gpa: string;
}

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
  @State private filteredGradeList: GradeBean[] = [];
  @State private isSearching: boolean = false;
  @State private searchText: string = '';
  @State private showSemesterPicker: boolean = false;
  @State private loading: boolean = true;
  @State private errorMsg: string = '';
  @State private showGradeDialog: boolean = false;
  @State private tappedGrade: GradeBean | null = null;
  @State private detailScale: number = 0.8;
  @State private detailOpacity: number = 0;
  @State private detailMaskOpacity: number = 0;
  @State private showMoreMenu: boolean = false;
  @State private menuScale: number = 0.8;
  @State private menuOpacity: number = 0;
  @State private menuMaskOpacity: number = 0;
  @State private showGpaTable: boolean = false;
  @State private showGradeDesc: boolean = false;

  private gpaTableData: GpaTableRow[] = [
    { score: '90-100', grade: 'A', gpa: '4.0' },
    { score: '85-89', grade: 'A-', gpa: '3.7' },
    { score: '82-84', grade: 'B+', gpa: '3.3' },
    { score: '78-81', grade: 'B', gpa: '3.0' },
    { score: '75-77', grade: 'B-', gpa: '2.7' },
    { score: '72-74', grade: 'C+', gpa: '2.3' },
    { score: '68-71', grade: 'C', gpa: '2.0' },
    { score: '64-67', grade: 'C-', gpa: '1.5' },
    { score: '60-63', grade: 'D', gpa: '1.0' },
    { score: '60以下', grade: 'F', gpa: '0' },
  ];

  private isUseMockData: boolean = false;
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
      this.filteredGradeList = mockGradeList;
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
        const list: GradeBean[] = this.sortGradesByTerm(resp.data ?? []);
        this.store.allGradeList = list;
        this.store.gradeList = list;
        this.store.extractTerms(list);
        this.termOptions = this.store.termOptions;
        this.selectedTerm = '全部成绩';
        this.gradeList = list;
        this.filteredGradeList = list;
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

  /** 学期倒序：最新学年/学期排在最前面，同学期保持接口原顺序。 */
  private sortGradesByTerm(grades: GradeBean[]): GradeBean[] {
    return grades.slice().sort((a: GradeBean, b: GradeBean) => {
      const termA = a.schoolTerm || '';
      const termB = b.schoolTerm || '';
      return termB.localeCompare(termA);
    });
  }

  private onTermChange(term: string): void {
    this.selectedTerm = term;
    this.showSemesterPicker = false;
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
    this.filteredGradeList = [...this.gradeList];
    this.summary = calcGradeSummary(this.gradeList);
    console.info(TAG, `term changed to ${term}, filtered ${this.gradeList.length} grades`);
  }

  private enterSearch(): void {
    this.isSearching = true;
    this.searchText = '';
    setTimeout(() => {
      console.info(TAG, 'enterSearch, requesting focus');
      focusControl.requestFocus('gradeSearchInput');
    }, 500);
  }

  private exitSearch(): void {
    this.isSearching = false;
    this.searchText = '';
    this.filteredGradeList = [...this.gradeList];
  }

  private filterBySearch(keyword: string): void {
    if (keyword.length === 0) {
      this.filteredGradeList = [...this.gradeList];
      return;
    }
    const result: GradeBean[] = [];
    for (let i = 0; i < this.gradeList.length; i++) {
      if (this.gradeList[i].courseName.indexOf(keyword) >= 0) {
        result.push(this.gradeList[i]);
      }
    }
    this.filteredGradeList = result;
  }

  private onGradeTap(grade: GradeBean): void {
    this.tappedGrade = grade;
    this.showGradeDialog = true;
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.detailMaskOpacity = 0.5;
      this.detailScale = 1;
      this.detailOpacity = 1;
    });
  }

  private closeDetail(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.detailMaskOpacity = 0;
      this.detailScale = 0.8;
      this.detailOpacity = 0;
    });
    setTimeout(() => {
      this.showGradeDialog = false;
      this.tappedGrade = null;
    }, 200);
  }

  private openMoreMenu(): void {
    this.showMoreMenu = true;
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.menuMaskOpacity = 0.5;
      this.menuScale = 1;
      this.menuOpacity = 1;
    });
  }

  private closeMoreMenu(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.menuMaskOpacity = 0;
      this.menuScale = 0.8;
      this.menuOpacity = 0;
    });
    setTimeout(() => {
      this.showMoreMenu = false;
    }, 200);
  }

  private retry(): void {
    this.fetchGrades();
  }

  @Builder
  private detailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor('#333333')
        .layoutWeight(1)
      Text(value)
        .fontSize(15)
        .fontColor('#999999')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 7, bottom: 7 })
  }

  @Builder
  private menuItem(title: string, action: () => void) {
    Text(title)
      .fontSize(16)
      .fontColor('#333333')
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .onClick(action)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          if (this.isSearching) {
            Text('←')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .margin({ left: 16 })
              .onClick(() => this.exitSearch())

            TextInput({ text: this.searchText, placeholder: '搜索课程名' })
              .id('gradeSearchInput')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#FFFFFF')
              .borderRadius(20)
              .fontSize(16)
              .fontColor('#333333')
              .placeholderColor('#999999')
              .margin({ left: 12, right: 12 })
              .type(InputType.Normal)
              .onChange((value: string) => {
                this.searchText = value;
                this.filterBySearch(value);
              })

            Text('✕')
              .fontSize(20)
              .fontColor('#FFFFFF')
              .padding(8)
              .margin({ right: 16 })
              .onClick(() => {
                this.searchText = '';
                this.filterBySearch('');
              })
          } else {
            Text('←')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .margin({ left: 16 })
              .onClick(() => router.back())

            Row() {
              Text(this.selectedTerm)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Image($r('app.media.keyboard_arrow_down'))
                .width(20)
                .height(20)
                .fillColor('#FFFFFF')
                .margin({ left: 4 })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.showSemesterPicker = true;
            })

            Image($r('app.media.search'))
              .width(22)
              .height(22)
              .fillColor('#FFFFFF')
              .margin({ right: 20 })
              .onClick(() => this.enterSearch())

            Image($r('app.media.more_vert'))
              .width(22)
              .height(22)
              .fillColor('#FFFFFF')
              .margin({ right: 16 })
              .onClick(() => this.openMoreMenu())
          }
        }
        .width('100%')
        .height(56)
        .backgroundColor('#23C087')
        .alignItems(VerticalAlign.Center)

        // 统计直接基于当前展示列表，并与成绩列表处于同一页面渲染上下文。
        Row() {
          Column() {
            Text(calcGradeSummary(this.filteredGradeList).averageGpa).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1ec98d')
            Text('平均绩点').fontSize(11).fontColor('#999999').margin({ top: 2 })
          }.layoutWeight(1)
          Text('').width(1).height(32).backgroundColor('#EEEEEE')
          Column() {
            Text(calcGradeSummary(this.filteredGradeList).totalCredits).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2196f3')
            Text('总学分').fontSize(11).fontColor('#999999').margin({ top: 2 })
          }.layoutWeight(1)
          Text('').width(1).height(32).backgroundColor('#EEEEEE')
          Column() {
            Text(`${this.filteredGradeList.length}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#ff9800')
            Text('课程').fontSize(11).fontColor('#999999').margin({ top: 2 })
          }.layoutWeight(1)
        }
        .width('100%').height(80).padding({ left: 8, right: 8 })
        .backgroundColor(Color.White).borderRadius(8)
        .margin({ top: 8, left: 16, right: 16 })

        if (this.loading) {
          Column() {
            LoadingProgress().width(40).height(40).color('#1ec98d')
            Text('正在拼命加载中...').fontSize(14).fontColor('#999999').margin({ top: 12 })
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.errorMsg !== '' && this.filteredGradeList.length === 0) {
          Column() {
            Text(this.errorMsg).fontSize(14).fontColor('#f44336')
            Button('重试').fontSize(14).fontColor(Color.White)
              .backgroundColor('#1ec98d').borderRadius(6).margin({ top: 16 })
              .onClick(() => this.retry())
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.filteredGradeList.length === 0) {
          Column() {
            Text('暂无成绩记录').fontSize(16).fontColor('#999999')
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.filteredGradeList, (grade: GradeBean) => {
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
      }
      .width('100%')
      .height('100%')

      if (this.showMoreMenu) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(this.menuMaskOpacity)
          .onClick(() => this.closeMoreMenu())

        Column() {
          this.menuItem('图表统计', () => {
            this.closeMoreMenu();
            setTimeout(() => {
              router.pushUrl({ url: 'pages/campus/grade/ChartStatisticsPage' });
            }, 200);
          })
          this.menuItem('奖学金计算', () => {
            this.closeMoreMenu();
            setTimeout(() => {
              router.pushUrl({ url: 'pages/campus/grade/ScholarshipCalculatorPage' });
            }, 200);
          })
          this.menuItem('成绩说明', () => {
            this.closeMoreMenu();
            setTimeout(() => {
              this.showGradeDesc = true;
            }, 200);
          })
          this.menuItem('绩点分段', () => {
            this.closeMoreMenu();
            setTimeout(() => {
              this.showGpaTable = true;
            }, 200);
          })
        }
        .width(180)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .position({ x: '100%', y: 56 })
        .translate({ x: -188 })
        .scale({ x: this.menuScale, y: this.menuScale })
        .opacity(this.menuOpacity)
      }

      if (this.showGpaTable) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(0.5)
          .onClick(() => {
            this.showGpaTable = false;
          })

        Column() {
          Text('绩点分段表')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width('100%')
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor('#23C087')

          Column() {
            Row() {
              Text('考核成绩')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
              Text('等级制')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
              Text('绩点')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 1 }, color: '#CCCCCC' })

            ForEach(this.gpaTableData, (item: GpaTableRow) => {
              Row() {
                Text(item.score)
                  .fontSize(16)
                  .fontColor('#666666')
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                Text(item.grade)
                  .fontSize(16)
                  .fontColor('#666666')
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                Text(item.gpa)
                  .fontSize(16)
                  .fontColor('#666666')
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .height(44)
              .border({ width: { bottom: 1 }, color: '#EEEEEE' })
            }, (item: GpaTableRow) => item.score)
          }
          .width('90%')
          .margin({ top: 16 })
          .border({ width: 1, color: '#CCCCCC' })

          Row() {
            Blank()
            Text('我知道了')
              .fontSize(16)
              .fontColor('#23C087')
              .padding({ top: 16, bottom: 16, right: 24 })
              .onClick(() => {
                this.showGpaTable = false;
              })
          }
          .width('100%')
        }
        .width(340)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
      }

      if (this.showGradeDesc) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(0.5)
          .onClick(() => {
            this.showGradeDesc = false;
          })

        Column() {
          Text('成绩说明')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width('100%')
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor('#23C087')

          Scroll() {
            Column() {
              Text('本软件的成绩数据仅供参考，具体请以教务处官网为准')
                .fontSize(16)
                .fontColor('#333333')
                .width('100%')
                .margin({ bottom: 16 })

              Text('1.计算平均学分绩点（GPA）')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .width('100%')
                .margin({ bottom: 8 })

              Text('平均学分绩点=Σ学分*绩点 ÷ Σ学分')
                .fontSize(16)
                .fontColor('#333333')
                .width('100%')
                .margin({ bottom: 16 })

              Text('2.关于成绩标识符')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .width('100%')
                .margin({ bottom: 8 })

              Text('有缓考的标识符，不纳入计算，同样课程名只取最高一次的成绩计算')
                .fontSize(16)
                .fontColor('#333333')
                .width('100%')
                .margin({ bottom: 16 })

              Text('3.标识符说明：')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .width('100%')
                .margin({ bottom: 8 })

              Text('缓=缓考，补=补考，重=重修，缺=缺考')
                .fontSize(16)
                .fontColor('#333333')
                .width('100%')
                .margin({ bottom: 16 })

              Text('4.如果出现数据有-1的情况，可能是教务处相关数据显示为空')
                .fontSize(16)
                .fontColor('#333333')
                .width('100%')
            }
            .width('100%')
            .padding(20)
          }
          .layoutWeight(1)

          Row() {
            Blank()
            Text('我知道了')
              .fontSize(16)
              .fontColor('#23C087')
              .padding({ top: 16, bottom: 16, right: 24 })
              .onClick(() => {
                this.showGradeDesc = false;
              })
          }
          .width('100%')
        }
        .width(340)
        .height(480)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
      }

      if (this.showSemesterPicker) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(0.5)
          .onClick(() => {
            this.showSemesterPicker = false;
          })

        Column() {
          Text('选择学期')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .width('100%')
            .padding({ left: 24, top: 20, bottom: 16 })

          Scroll() {
            Column() {
              ForEach(this.termOptions, (term: string) => {
                Text(term)
                  .fontSize(18)
                  .fontColor(this.selectedTerm === term ? '#23C087' : '#333333')
                  .fontWeight(this.selectedTerm === term ? FontWeight.Bold : FontWeight.Normal)
                  .width('100%')
                  .padding({ left: 24, top: 16, bottom: 16 })
                  .onClick(() => this.onTermChange(term))
              }, (term: string) => term)
            }
            .width('100%')
          }
          .width('100%')
          .height('60%')
        }
        .width(320)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
      }

      if (this.showGradeDialog) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(this.detailMaskOpacity)
          .onClick(() => this.closeDetail())
      }

      if (this.showGradeDialog && this.tappedGrade) {
        Column() {
          Text(this.tappedGrade?.courseName ?? '')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 24, bottom: 16 })

          Text(this.tappedGrade?.grade ?? '0')
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFA726')

          Text(`绩点 ${this.tappedGrade?.gradePoint ?? '0'}`)
            .fontSize(18)
            .fontColor('#999999')
            .margin({ top: 8, bottom: 24 })

          this.detailRow('学分', this.tappedGrade?.courseCredit ?? '0')
          this.detailRow('学时', this.tappedGrade?.courseHours ?? '-')
          this.detailRow('课程类别', this.tappedGrade?.courseNature || '考试')

          Divider().color('#EEEEEE').margin({ top: 12, bottom: 12 })

          this.detailRow('开课学期', this.tappedGrade?.schoolTerm ?? '-')
          this.detailRow('考试性质', this.tappedGrade?.examNature ?? '-')
          this.detailRow('课程性质', this.tappedGrade?.courseNature ?? '-')
          Blank().height(24)
        }
        .width(320)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .scale({ x: this.detailScale, y: this.detailScale })
        .opacity(this.detailOpacity)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}

