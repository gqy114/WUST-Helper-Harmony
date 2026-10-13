import { promptAction, router } from '@kit.ArkUI';
import { GradeStore } from '../../../store/GradeStore';

interface CalcCourse { name: string; credit: number; gpa: number; selected: boolean; weight: number; }

@Entry
@Component
struct ScholarshipCalculatorPage {
  @State private mode: string = 'select';
  @State private courses: CalcCourse[] = [
    { name: '高等数学A(一)', credit: 5, gpa: 2, selected: true, weight: 1 },
    { name: '计算机科学导论', credit: 1, gpa: 3.7, selected: true, weight: 1 },
    { name: 'C语言程序设计实验', credit: 1, gpa: 3.7, selected: true, weight: 1 },
    { name: 'C语言程序设计', credit: 3, gpa: 2, selected: true, weight: 1 },
    { name: '大学英语(一)', credit: 2, gpa: 1.5, selected: true, weight: 1 },
    { name: '体育(一)', credit: 1, gpa: 3, selected: true, weight: 1 },
    { name: '大学生心理健康教育', credit: 2, gpa: 4, selected: true, weight: 1 },
    { name: '军事训练', credit: 2, gpa: 4, selected: true, weight: 1 },
  ];
  @State private weightedGpa: number = 0;
  @State private showSortMenu: boolean = false;
  @State private sortMenuOpacity: number = 0;
  @State private sortMenuScale: number = 0.8;
  @State private sortMode: string = '学分';
  @State private showYearPicker: boolean = false;
  @State private academicYear: string = '大一';
  private readonly academicYears: string[] = ['大一', '大二', '大三', '大四'];

  aboutToAppear(): void {
    const grades = GradeStore.getInstance().allGradeList;
    if (grades.length === 0) {
      return;
    }
    const loaded: CalcCourse[] = [];
    for (let i = 0; i < grades.length; i++) {
      const grade = grades[i];
      loaded.push({
        name: grade.courseName,
        credit: parseFloat(grade.courseCredit) || 0,
        gpa: parseFloat(grade.gradePoint) || 0,
        selected: true,
        weight: 1
      });
    }
    this.courses = loaded;
  }

  build() { Column() { if (this.mode === 'select') { this.selectMode(); } else { this.resultMode(); } }.width('100%').height('100%').backgroundColor('#F5F5F5'); }

  @Builder
  private selectMode() {
    Stack({ alignContent: Alignment.Center }) {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .margin({ left: 16 })
          .onClick(() => router.back())
        Text('请勾选计算科目')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .margin({ left: 16 })
        Image($r('app.media.checklist'))
          .width(24)
          .height(24)
          .fillColor('#FFFFFF')
          .margin({ right: 16 })
          .onClick(() => this.toggleAll())
      }
      .width('100%')
      .height(56)
      .backgroundColor('#23C087')
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          ForEach(this.courses, (course: CalcCourse, index: number) => {
            Row() {
              Text(course.selected ? '✓' : '')
                .fontSize(15)
                .fontColor('#FFFFFF')
                .width(26)
                .height(26)
                .borderRadius(13)
                .backgroundColor(course.selected ? '#23C087' : '#CCCCCC')
                .textAlign(TextAlign.Center)
                .margin({ right: 16 })
                .onClick(() => this.toggleCourse(index))
              Text(course.name).fontSize(16).fontColor('#333333').layoutWeight(1)
              Text(`绩点: ${course.gpa}`).fontSize(14).fontColor('#666666')
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            
          }, (course: CalcCourse) => course.name + '_' + (course.selected ? 'selected' : 'unselected') + '_' + course.weight.toString())
        }
        .width('100%')
      }
      .layoutWeight(1)

      Row() {
        Column() {
          Image($r('app.media.sort')).width(24).height(24).fillColor('#999999')
          Text('排序').fontSize(12).fontColor('#999999').margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => this.openSortMenu())

        Column() {
          Image($r('app.media.more_horiz')).width(24).height(24).fillColor('#999999')
          Text('选择学期').fontSize(12).fontColor('#999999').margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => this.openYearPicker())

        Button('确定')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor('#23C087')
          .layoutWeight(2)
          .height(48)
          .borderRadius(24)
          .margin({ right: 16 })
          .onClick(() => this.calculate())
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')

      }

      if (this.showSortMenu) {
        Column().width('100%').height('100%').backgroundColor('#000000').opacity(0.35).onClick(() => this.closeSortMenu())
        Column() {
          Text('排序方式').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ top: 20, bottom: 8 })
          Text('按学分排序').fontSize(17).fontColor(this.sortMode === '学分' ? '#23C087' : '#555555').width('100%').padding({ left: 24, top: 14, bottom: 14 }).onClick(() => this.chooseSort('学分'))
          Text('按绩点排序').fontSize(17).fontColor(this.sortMode === '绩点' ? '#23C087' : '#555555').width('100%').padding({ left: 24, top: 14, bottom: 14 }).onClick(() => this.chooseSort('绩点'))
        }.width(280).backgroundColor('#FFFFFF').borderRadius(14).scale({ x: this.sortMenuScale, y: this.sortMenuScale }).opacity(this.sortMenuOpacity)
      }

      if (this.showYearPicker) {
        Column().width('100%').height('100%').backgroundColor('#000000').opacity(0.35).onClick(() => { this.showYearPicker = false; })
        Column() {
          Text('选择学年').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ top: 20, bottom: 12 })
          TextPicker({ range: this.academicYears, selected: this.academicYears.indexOf(this.academicYear) })
            .width(260).height(150)
            .onChange((value: string | string[], index: number | number[]) => {
              if (typeof index === 'number') { this.academicYear = this.academicYears[index]; }
            })
          Button('确定').fontColor('#FFFFFF').backgroundColor('#23C087').width(180).height(42).margin({ top: 12, bottom: 20 }).onClick(() => { this.showYearPicker = false; })
        }.width(300).backgroundColor('#FFFFFF').borderRadius(14)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private resultMode() {
    Column() {
      Column() { Row() { Text('←').fontSize(24).fontColor('#FFFFFF').margin({ left: 16 }).onClick(() => { this.mode = 'select'; }); Blank(); Text('重选科目').fontSize(16).fontColor('#FFFFFF').margin({ right: 16 }).onClick(() => { this.mode = 'select'; }); }.width('100%').margin({ top: 16 }); Text(this.academicYear + '学年').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 16 }); Text(`${this.weightedGpa.toFixed(5)}`).fontSize(48).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 8, bottom: 24 }); }.width('100%').backgroundColor('#7B68EE').borderRadius({ bottomLeft: 24, bottomRight: 24 });
      Scroll() { Column() { ForEach(this.selectedCourses(), (course: CalcCourse) => { Row() { Text(course.name.charAt(0)).fontSize(20).fontColor('#FFFFFF').width(48).height(48).borderRadius(24).backgroundColor('#9370DB').textAlign(TextAlign.Center).margin({ right: 12 }); Column() { Text(course.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333333'); Text(`学分: ${course.credit}  绩点: ${course.gpa}`).fontSize(14).fontColor('#999999').margin({ top: 4 }); }.layoutWeight(1); Column() { Text(`${course.weight.toFixed(1)}`).fontSize(28).fontColor('#666666'); Row() { Text('+').width(26).height(28).backgroundColor('#E0E0E0').textAlign(TextAlign.Center).onClick(() => this.changeWeight(course.name, 0.1)); Text('-').width(26).height(28).backgroundColor('#E0E0E0').textAlign(TextAlign.Center).margin({ left: 4 }).onClick(() => this.changeWeight(course.name, -0.1)); }.margin({ top: 4 }); }.alignItems(HorizontalAlign.Center); }.width('100%').padding(16).backgroundColor('#FFFFFF').margin({ bottom: 1 }); }, (course: CalcCourse) => course.name + '_' + course.weight.toString()) }.width('100%'); }.layoutWeight(1);
    }.width('100%').height('100%').backgroundColor('#F5F5F5');
  }

  private openSortMenu(): void {
    this.showSortMenu = true;
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.sortMenuOpacity = 1;
      this.sortMenuScale = 1;
    });
  }

  private closeSortMenu(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.sortMenuOpacity = 0;
      this.sortMenuScale = 0.8;
    });
    setTimeout(() => { this.showSortMenu = false; }, 200);
  }

  private chooseSort(mode: string): void {
    this.sortMode = mode;
    const sorted: CalcCourse[] = this.courses.slice();
    if (mode === '学分') {
      sorted.sort((a: CalcCourse, b: CalcCourse) => b.credit - a.credit);
    } else {
      sorted.sort((a: CalcCourse, b: CalcCourse) => b.gpa - a.gpa);
    }
    this.courses = sorted;
    this.closeSortMenu();
  }

  private openYearPicker(): void {
    this.showYearPicker = true;
  }

  private selectedCourses(): CalcCourse[] { const result: CalcCourse[] = []; for (let i = 0; i < this.courses.length; i++) { if (this.courses[i].selected) result.push(this.courses[i]); } return result; }
  private toggleAll(): void {
    const allSelected = this.courses.every((course: CalcCourse) => course.selected);
    const newList: CalcCourse[] = [];
    for (let i = 0; i < this.courses.length; i++) {
      const course = this.courses[i];
      newList.push({
        name: course.name,
        credit: course.credit,
        gpa: course.gpa,
        selected: !allSelected,
        weight: course.weight
      });
    }
    this.courses = newList;
  }

  private toggleCourse(index: number): void {
    const newList: CalcCourse[] = [];
    for (let i = 0; i < this.courses.length; i++) {
      const course = this.courses[i];
      newList.push({
        name: course.name,
        credit: course.credit,
        gpa: course.gpa,
        selected: i === index ? !course.selected : course.selected,
        weight: course.weight
      });
    }
    this.courses = newList;
  }
  private calculate(): void { if (this.selectedCourses().length === 0) { promptAction.showToast({ message: '请至少选择一门课程', duration: 1500 }); return; } this.recalculate(); this.mode = 'result'; }
  private changeWeight(name: string, delta: number): void {
    const newList: CalcCourse[] = [];
    for (let i = 0; i < this.courses.length; i++) {
      const course = this.courses[i];
      newList.push({
        name: course.name,
        credit: course.credit,
        gpa: course.gpa,
        selected: course.selected,
        weight: course.name === name ? Math.max(0.1, course.weight + delta) : course.weight
      });
    }
    this.courses = newList;
    this.recalculate(true);
  }
  /** 与安卓 ScholarshipPresenter 一致：绩点按学分和手动权重共同加权。 */
  private recalculate(animated: boolean = false): void {
    const selected = this.selectedCourses();
    let weighted = 0;
    let totalCredits = 0;
    for (let i = 0; i < selected.length; i++) {
      const effectiveCredit = selected[i].credit * selected[i].weight;
      weighted += selected[i].gpa * effectiveCredit;
      totalCredits += effectiveCredit;
    }
    const target = totalCredits > 0 ? weighted / totalCredits : 0;
    if (animated) {
      animateTo({ duration: 350, curve: Curve.EaseOut }, () => { this.weightedGpa = target; });
    } else {
      this.weightedGpa = target;
    }
  }
}











