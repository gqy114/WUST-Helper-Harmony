/**
 * GradeStatCard — 成绩统计卡片
 *
 * 显示：总学分 / 平均绩点 / 课程数 / 未通过数
 *
 * 文件路径：entry/src/main/ets/components/GradeStatCard.ets
 */
@Component
export struct GradeStatCard {
  @Prop totalCredits: string = '0';
  @Prop averageGpa: string = '0';
  @Prop courseCount: number = 0;
  @Prop failedCount: number = 0;

  build() {
    Row() {
      this.statItem('平均绩点', this.averageGpa, '#1ec98d')
      Text('').width(1).height(32).backgroundColor('#EEEEEE')
      this.statItem('总学分', this.totalCredits, '#2196f3')
      Text('').width(1).height(32).backgroundColor('#EEEEEE')
      this.statItem('课程', `${this.courseCount}`, '#ff9800')
      if (this.failedCount > 0) {
        Text('').width(1).height(32).backgroundColor('#EEEEEE')
        this.statItem('未通过', `${this.failedCount}`, '#f44336')
      }
    }
    .width('100%').height(80)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Color.White).borderRadius(8)
  }

  @Builder
  private statItem(label: string, value: string, color: string) {
    Column() {
      Text(value).fontSize(20).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor('#999999').margin({ top: 2 })
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}
