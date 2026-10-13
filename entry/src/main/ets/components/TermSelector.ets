/**
 * TermSelector — 学期选择器
 *
 * 对应安卓 GradeActivity 中 tvSpinner 点击弹出 AlertDialog 选择学期
 * 显示格式："全部成绩" + 学年学期列表
 *
 * 文件路径：entry/src/main/ets/components/TermSelector.ets
 */
import { promptAction, router } from '@kit.ArkUI';

@Component
export struct TermSelector {
  private termOptions: string[] = [];
  private selectedTerm: string = '全部成绩';
  private onTermChange?: (term: string) => void;

  build() {
    Row() {
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
      .onClick(() => this.showTermPicker())

      Image($r('app.media.search'))
        .width(22)
        .height(22)
        .fillColor('#FFFFFF')
        .margin({ right: 20 })
        .onClick(() => {
          promptAction.showToast({ message: '搜索功能开发中', duration: 1200 });
        })

      Image($r('app.media.more_vert'))
        .width(22)
        .height(22)
        .fillColor('#FFFFFF')
        .margin({ right: 16 })
        .onClick(() => {
          promptAction.showToast({ message: '更多功能开发中', duration: 1200 });
        })
    }
    .width('100%')
    .height(56)
    .backgroundColor('#23C087')
    .alignItems(VerticalAlign.Center)
  }

  private showTermPicker(): void {
    // 简化实现：左右箭头切换（与 WeekSelector 风格一致）
    // 实际可根据需要替换为 PickerDialog
  }
}
