/**
 * GradeItem — 单行成绩条目
 *
 * 对应安卓 GradeAdapter → RecyclerView item
 * 左侧：课程名 + 课程性质 | 右侧：分数 + 绩点
 * 点击弹出详情弹窗
 *
 * 文件路径：entry/src/main/ets/components/GradeItem.ets
 */
import { GradeBean } from '../model/GradeModel';

@Component
export struct GradeItem {
  private grade: GradeBean = {
    courseName: '', grade: '0', courseCredit: '0',
    courseHours: '0', gradePoint: '0', evaluationMode: '',
    examNature: '', courseNature: '', schoolTerm: '',
    courseNum: '', missExamTag: 0, reExamTag: 0, rebuildTag: 0,
  };
  private onItemTap?: () => void;

  build() {
    Row() {
      Column() {
        Text(this.grade.courseName)
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#333333')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(this.grade.courseNature).fontSize(11).fontColor('#999999')
          Text(`${this.grade.courseCredit} 学分`).fontSize(11).fontColor('#999999').margin({ left: 12 })
        }.margin({ top: 4 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)

      Column() {
        Text(this.grade.grade)
          .fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(this.getScoreColor())
        Text(`绩点 ${this.grade.gradePoint}`)
          .fontSize(11).fontColor('#999999').margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%').height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White).borderRadius(8).margin({ bottom: 8 })
    .onClick(() => { this.onItemTap?.(); })
  }

  private getScoreColor(): string {
    const num = parseFloat(this.grade.grade);
    if (isNaN(num)) return '#333333';
    if (num < 60) return '#f44336';
    if (num >= 85) return '#1ec98d';
    return '#333333';
  }
}