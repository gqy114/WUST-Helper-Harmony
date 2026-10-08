/**
 * MineHeader — 个人中心头部
 *
 * 对应安卓 MineFragment 顶部用户信息区
 * 展示：默认头像 + 学号 + 姓名
 *
 * 文件路径：entry/src/main/ets/components/mine/MineHeader.ets
 */
import { UserInfo } from '../model/UserInfoModel';

@Component
export struct MineHeader {
  private userInfo: UserInfo = { studentId: '', userName: '' };
  private isLoggedIn: boolean = false;

  build() {
    Column() {
      if (this.isLoggedIn) {
        // ── 已登录：头像 + 姓名 + 学号 ──
        Image($r('app.media.ic_default_avatar'))
          .width(64).height(64).borderRadius(32)
          .objectFit(ImageFit.Cover).margin({ top: 20 })

        Text(this.userInfo.userName || '未设置昵称')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333')
          .margin({ top: 10 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`学号: ${this.userInfo.studentId || '未知'}`)
          .fontSize(13).fontColor('#999999').margin({ top: 4 })
      } else {
        // ── 未登录 ──
        Image($r('app.media.ic_default_avatar'))
          .width(64).height(64).borderRadius(32)
          .objectFit(ImageFit.Cover).margin({ top: 20 }).opacity(0.5)

        Text('未登录')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#BBBBBB')
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.White)
    .padding({ bottom: 20 })
  }
}