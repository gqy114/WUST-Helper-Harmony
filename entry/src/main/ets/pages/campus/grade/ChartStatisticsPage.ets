import { router } from '@kit.ArkUI';
import { GradeStore } from '../../../store/GradeStore';
import { GradeBean } from '../../../model/GradeModel';

interface GpaSlice {
  gpa: number;
  count: number;
  color: string;
}

interface GpaBar {
  name: string;
  value: number;
  color: string;
}

@Entry
@Component
struct ChartStatisticsPage {
  @State private avgGpa: number = 0;
  @State private avgScore: number = 0;
  @State private courseCount: number = 0;
  @State private distribution: GpaSlice[] = [];
  @State private semesterBars: GpaBar[] = [];
  @State private yearBars: GpaBar[] = [];
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private readonly chartColors: string[] = ['#B9F67C', '#C9A7F5', '#F5A7B8', '#7CD9F5', '#F5C97C', '#F5E77C', '#A8D97C', '#8CB8F5'];

  aboutToAppear(): void {
    this.calculateAll(GradeStore.getInstance().allGradeList);
  }

  private calculateAll(grades: GradeBean[]): void {
    this.courseCount = grades.length;
    this.avgGpa = 0;
    this.avgScore = 0;
    this.distribution = [];
    this.semesterBars = [];
    this.yearBars = [];
    if (grades.length === 0) {
      return;
    }

    let creditTotal = 0;
    let weightedTotal = 0;
    let scoreWeightedTotal = 0;
    const points: number[] = [];
    const counts: number[] = [];
    const termNames: string[] = [];
    const termWeighted: number[] = [];
    const termCredits: number[] = [];
    const yearNames: string[] = [];
    const yearWeighted: number[] = [];
    const yearCredits: number[] = [];

    // 与安卓端一致：同名课程只保留成绩较高的一条，再按学分加权计算平均成绩。
    const effectiveGrades: GradeBean[] = [];
    for (const grade of grades) {
      let duplicateIndex = -1;
      for (let j = 0; j < effectiveGrades.length; j++) {
        if (effectiveGrades[j].courseName === grade.courseName) {
          duplicateIndex = j;
          break;
        }
      }
      if (duplicateIndex < 0) {
        effectiveGrades.push(grade);
      } else if (this.scoreValue(grade.grade) > this.scoreValue(effectiveGrades[duplicateIndex].grade)) {
        effectiveGrades[duplicateIndex] = grade;
      }
    }

    for (let i = 0; i < grades.length; i++) {
      const credit = parseFloat(grades[i].courseCredit) || 0;
      const point = parseFloat(grades[i].gradePoint) || 0;
      creditTotal += credit;
      weightedTotal += credit * point;

      const pointIndex = points.indexOf(point);
      if (pointIndex < 0) {
        points.push(point);
        counts.push(1);
      } else {
        counts[pointIndex]++;
      }

      const term = grades[i].schoolTerm || '未知学期';
      const termIndex = termNames.indexOf(term);
      if (termIndex < 0) {
        termNames.push(term);
        termWeighted.push(credit * point);
        termCredits.push(credit);
      } else {
        termWeighted[termIndex] += credit * point;
        termCredits[termIndex] += credit;
      }

      const year = term.length >= 9 ? term.substring(0, 9) : term;
      const yearIndex = yearNames.indexOf(year);
      if (yearIndex < 0) {
        yearNames.push(year);
        yearWeighted.push(credit * point);
        yearCredits.push(credit);
      } else {
        yearWeighted[yearIndex] += credit * point;
        yearCredits[yearIndex] += credit;
      }
    }

    for (const grade of effectiveGrades) {
      const credit = parseFloat(grade.courseCredit) || 0;
      scoreWeightedTotal += this.scoreValue(grade.grade) * credit;
    }

    this.avgGpa = creditTotal > 0 ? weightedTotal / creditTotal : 0;
    const effectiveCredits = effectiveGrades.reduce((sum: number, grade: GradeBean) => {
      return sum + (parseFloat(grade.courseCredit) || 0);
    }, 0);
    this.avgScore = effectiveCredits > 0 ? scoreWeightedTotal / effectiveCredits : 0;

    const slices: GpaSlice[] = [];
    for (let i = 0; i < points.length; i++) {
      slices.push({ gpa: points[i], count: counts[i], color: this.chartColors[i % this.chartColors.length] });
    }
    slices.sort((a: GpaSlice, b: GpaSlice) => b.gpa - a.gpa);
    this.distribution = slices;

    const terms: GpaBar[] = [];
    for (let i = 0; i < termNames.length; i++) {
      const value = termCredits[i] > 0 ? termWeighted[i] / termCredits[i] : 0;
      terms.push({
        name: termNames[i],
        value: value,
        color: i % 2 === 0 ? '#B9F67C' : '#E07F8D'
      });
    }
    terms.sort((a: GpaBar, b: GpaBar) => a.name.localeCompare(b.name));
    this.semesterBars = terms;

    const years: GpaBar[] = [];
    for (let i = 0; i < yearNames.length; i++) {
      const value = yearCredits[i] > 0 ? yearWeighted[i] / yearCredits[i] : 0;
      years.push({ name: yearNames[i], value: value, color: '#A8D97C' });
    }
    years.sort((a: GpaBar, b: GpaBar) => a.name.localeCompare(b.name));
    this.yearBars = years;
  }

  /** 安卓 GradeChartPresenter.addGrade 的等级换算规则。 */
  private scoreValue(value: string): number {
    const grade = value.trim();
    const fixed: Record<string, number> = {
      'A': 95, 'A-': 87, 'B+': 83, 'B': 79.5, 'B-': 76,
      'C+': 73, 'C': 69.5, 'C-': 65.5, 'D': 61.5, 'F': 30,
    };
    if (fixed[grade] !== undefined) {
      return fixed[grade];
    }
    const score = parseFloat(grade);
    return isNaN(score) ? 0 : score;
  }

  private drawDistribution(): void {
    const ctx = this.canvasContext;
    ctx.clearRect(0, 0, 300, 260);
    if (this.courseCount === 0) {
      return;
    }
    const cx = 150;
    const cy = 130;
    const radius = 80;
    const thickness = 40;
    let angle = -Math.PI / 2;
    for (let i = 0; i < this.distribution.length; i++) {
      const part = this.distribution[i].count / this.courseCount * Math.PI * 2;
      ctx.beginPath();
      ctx.lineWidth = thickness;
      ctx.strokeStyle = this.distribution[i].color;
      ctx.arc(cx, cy, radius, angle + 0.012, angle + part - 0.012);
      ctx.stroke();
      angle += part;
    }
    ctx.fillStyle = '#555555';
    ctx.font = 'bold 20px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(this.courseCount.toString() + ' 门', cx, cy + 7);
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(25)
          .fontColor('#FFFFFF')
          .width(56)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())
        Text('图表统计')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(64)
      .backgroundColor('#23C087')
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          Column() {
            this.averageLine('平均学分绩点', this.avgGpa.toFixed(3))
            this.ticketDivider()
            this.sectionLabel('绩点分布')
            if (this.courseCount > 0) {
              Canvas(this.canvasContext)
                .width(300)
                .height(260)
                .onReady(() => this.drawDistribution())
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                ForEach(this.distribution, (item: GpaSlice) => {
                  Row() {
                    Column().width(10).height(10).borderRadius(5).backgroundColor(item.color)
                    Text(item.gpa.toFixed(1) + ' · ' + (item.count / this.courseCount * 100).toFixed(1) + '%')
                      .fontSize(12)
                      .fontColor('#555555')
                      .margin({ left: 5 })
                  }
                  .margin({ right: 12, bottom: 8 })
                }, (item: GpaSlice) => item.gpa.toString())
              }
              .width('100%')
              .padding({ left: 20, right: 20, bottom: 24 })
            } else {
              this.emptyMessage()
            }

            this.ticketDivider()
            this.sectionLabel('学期绩点')
            this.barChart(this.semesterBars)
            this.ticketDivider()
            this.sectionLabel('学年绩点')
            this.barChart(this.yearBars)
            this.ticketDivider()
            this.averageLine('平均成绩', this.avgScore.toFixed(3))
          }
          .width('90%')
          .backgroundColor('#FFFFFF')
          .margin({ top: 24, bottom: 28 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ECEDEF')
  }

  @Builder
  private averageLine(label: string, value: string) {
    Row() {
      Text(label).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#666666').layoutWeight(1)
      Text(value).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#333333')
    }
    .width('100%')
    .height(76)
    .padding({ left: 20, right: 20 })
  }

  @Builder
  private ticketDivider() {
    Row() {
      Text('· · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·')
        .fontSize(17)
        .fontColor('#CCCCCC')
        .width('100%')
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .width('100%')
    .height(18)
  }

  @Builder
  private sectionLabel(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#666666')
      .textAlign(TextAlign.Center)
      .width(146)
      .height(36)
      .border({ width: 1, color: '#23C087' })
      .borderRadius(18)
      .margin({ top: 24, bottom: 20 })
  }

  @Builder
  private barChart(data: GpaBar[]) {
    if (data.length === 0) {
      this.emptyMessage()
    } else {
      Scroll() {
        Row() {
          ForEach(data, (item: GpaBar) => {
            Column() {
              Text(item.value.toFixed(3))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#222222')
                .margin({ bottom: 4 })
              Column()
                .width(62)
                .height(Math.max(3, item.value / 4 * 190))
                .backgroundColor(item.color)
              Text(item.name)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .width(86)
                .textAlign(TextAlign.Center)
                .maxLines(2)
                .margin({ top: 8 })
            }
            .width(96)
            .height(250)
            .justifyContent(FlexAlign.End)
            .margin({ left: 6, right: 6 })
          }, (item: GpaBar) => item.name)
        }
        .padding({ left: 12, right: 12 })
        .border({ width: { bottom: 1 }, color: '#CCCCCC' })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(254)
      .margin({ bottom: 20 })
    }
  }

  @Builder
  private emptyMessage() {
    Text('暂无成绩数据')
      .fontSize(14)
      .fontColor('#999999')
      .width('100%')
      .height(120)
      .textAlign(TextAlign.Center)
  }
}

