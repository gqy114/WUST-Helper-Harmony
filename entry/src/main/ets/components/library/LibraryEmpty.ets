/**
 * LibraryEmpty — 图书馆空状态 / 错误状态
 *
 * 区分三种状态：
 *   1. 无借阅记录（展示空白文案）
 *   2. 网络请求失败（展示错误文案 + 重试按钮）
 *   3. 图书馆登录过期（提示重新登录）
 *
 * 文件路径：entry/src/main/ets/components/library/LibraryEmpty.ets
 */
@Component
export struct LibraryEmpty {
  private isError: boolean = false;
  private errorMsg: string = '';
  private isSessionExpired: boolean = false;
  private onRetry?: () => void;

  build() {
    Column() {
      if (this.isSessionExpired) {
        Text('图书馆登录已过期')
          .fontSize(16).fontColor('#f44336').margin({ top: 24 })
        Text('请重新登录后再查看借阅信息')
          .fontSize(13).fontColor('#999999').margin({ top: 8 })
      } else if (this.isError && this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(16).fontColor('#666666').margin({ top: 24 })

        Button('重试')
          .fontSize(14).fontColor(Color.White)
          .backgroundColor('#1ec98d').borderRadius(6)
          .margin({ top: 16 })
          .onClick(() => { this.onRetry?.(); })
      } else {
        Text('暂无借阅记录')
          .fontSize(16).fontColor('#999999').margin({ top: 24 })
        Text('您当前没有在借图书')
          .fontSize(13).fontColor('#BBBBBB').margin({ top: 8 })
      }
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}