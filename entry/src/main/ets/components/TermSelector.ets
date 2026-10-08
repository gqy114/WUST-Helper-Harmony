/**
 * TermSelector — 学期选择器
 *
 * 对应安卓 GradeActivity 中 tvSpinner 点击弹出 AlertDialog 选择学期
 * 显示格式："全部成绩" + 学年学期列表
 *
 * 文件路径：entry/src/main/ets/components/TermSelector.ets
 */
@Component
export struct TermSelector {
  private termOptions: string[] = [];
  private selectedTerm: string = '全部成绩';
  private onTermChange?: (term: string) => void;

  build() {
    Row() {
      Text(this.selectedTerm)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Image($r('app.media.ic_arrow_down'))
        .width(16).height(16)
        .objectFit(ImageFit.Contain)
        .margin({ left: 4 })
    }
    .width('100%')
    .height(40)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .onClick(() => {
      this.showTermPicker();
    })
  }

  private showTermPicker(): void {
    // 简化实现：左右箭头切换（与 WeekSelector 风格一致）
    // 实际可根据需要替换为 PickerDialog
  }
}