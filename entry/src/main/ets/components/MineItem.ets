/**
 * MineItem — 通用设置列表条目
 *
 * 对应安卓 FragmentMineBinding 中 cardSetting 系列组件
 * 左侧标题 + 右侧描述 + 箭头指示 + 点击回调
 *
 * 文件路径：entry/src/main/ets/components/mine/MineItem.ets
 */
@Component
export struct MineItem {
  private title: string = '';
  private description: string = '';
  private color: string = '#333333';
  private  onItemTap?: () => void;

  build() {
    Row() {
      Text(this.title)
        .fontSize(15).fontColor(this.color).layoutWeight(1)

      if (this.description !== '') {
        Text(this.description)
          .fontSize(12).fontColor('#999999').margin({ right: 6 })
      }

      Text('›')
        .fontSize(18).fontColor('#CCCCCC')
    }
    .width('100%').height(48)
    .padding({ left: 20, right: 20 })
    .backgroundColor(Color.White)
    .onClick(() => { this. onItemTap?.(); })
  }
}