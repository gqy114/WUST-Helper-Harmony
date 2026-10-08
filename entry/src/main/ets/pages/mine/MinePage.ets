/**
 * MinePage — 个人中心主页面
 *
 * 对应安卓 MineFragment
 * 逻辑对齐：
 *   1. aboutToAppear 校验登录 → 未登录跳转 LoginPage
 *   2. 加载用户信息（优先本地 AppStorage，成功则拉取 API 更新）
 *   3. 菜单：清除缓存 / 默认学期设置 / 关于本App / 退出登录
 *   4. 退出登录：二次确认 → clearLoginState → RouterUtil.toLogin()
 *
 * 文件路径：entry/src/main/ets/pages/mine/MinePage.ets
 */
import { promptAction } from '@kit.ArkUI';
import { RouterUtil } from '../../utils/RouterUtil';
import { AppStorage } from '../../store/AppStorage';
import { StorageUtil } from '../../utils/StorageUtil';
import { UserApi } from '../../net/UserApi';
import { UserStore } from '../../store/UserStore';
import { UserInfo } from '../../model/UserInfoModel';

const TAG = 'MinePage';

interface MineFeatureItem {
  title: string;
  desc: string;
  bgColor: string;
  icon: Resource;
}

const mockNickName: string = '滚木';
const mockStudentId: string = '114514191981';

const mineFeatureList: MineFeatureItem[] = [
  { title: '提交反馈', desc: '快来吐槽吧', bgColor: '#FFFFFF', icon: $r('app.media.ic_feedback') },
  { title: 'QQ用户群', desc: '加入助手内测', bgColor: '#FFFFFF', icon: $r('app.media.ic_qq') },
  { title: '关于APP', desc: '武科大助手', bgColor: '#FFFFFF', icon: $r('app.media.ic_about_us') },
  { title: '检查更新', desc: '来体验船新版本', bgColor: '#FFFFFF', icon: $r('app.media.ic_update') }
]

/** 退出登录确认弹窗 */
@CustomDialog
struct LogoutConfirmDialog {
  controller?: CustomDialogController;
  onConfirm?: () => void;
  onCancel?: () => void;

  build() {
    Column() {
      Text('提示').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ top: 16 })
      Text('是否确定退出登录？').fontSize(15).fontColor('#666666').margin({ top: 16, bottom: 8 })

      Row() {
        Text('取消').fontSize(16).fontColor('#666666').height(40).layoutWeight(1)
          .textAlign(TextAlign.Center).onClick(() => this.onCancel?.())

        Text('确定').fontSize(16).fontColor('#f44336').height(40).layoutWeight(1)
          .textAlign(TextAlign.Center).onClick(() => {
          this.onCancel?.();
          this.onConfirm?.();
        })
      }.width('100%').margin({ top: 8 })
    }
    .width('75%').backgroundColor(Color.White).borderRadius(12).alignItems(HorizontalAlign.Center)
  }
}

/** 关于弹窗 */
@CustomDialog
struct AboutDialog {
  controller: CustomDialogController;

  build() {
    Column() {
      Image($r('app.media.logo')).width(56).height(56).borderRadius(12).margin({ top: 20 })
      Text('武科大助手').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ top: 10 })
      Text('v5.2.8').fontSize(13).fontColor('#999999').margin({ top: 4 })
      Text('武汉科技大学领航工作室出品').fontSize(12).fontColor('#BBBBBB').margin({ top: 12 })

      Text('关闭').fontSize(16).fontColor('#1ec98d').margin({ top: 16, bottom: 12 })
        .onClick(() => this.controller.close())
    }
    .width('75%').backgroundColor(Color.White).borderRadius(12).alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct MinePage {
  @State private userInfo: UserInfo = { studentId: '', userName: '' };
  @State private isLoggedIn: boolean = false;
  @State private loading: boolean = true;
  @State private errorMsg: string = '';
  @State private showLogoutDialog: boolean = false;

  private store: UserStore = UserStore.getInstance();

  aboutToAppear(): void {
    this.verifyAndLoad();
  }

  private async verifyAndLoad(): Promise<void> {
    try {
      const s = AppStorage.getInstance();
      const token = await s.getToken();
      const loginFlag = await s.getIsLogin();
      if (!token || !loginFlag) {
        this.isLoggedIn = false;
        this.loading = false;
        return;
      }
      this.isLoggedIn = true;
      await this.store.restoreFromLocal();
      this.userInfo = this.store.userInfo;
      this.loading = false;
      // 后台拉取 API 更新用户信息
      this.fetchUserInfo(token);
    } catch {
      console.error(TAG, 'verify error');
      this.loading = false;
    }
  }

  private async fetchUserInfo(token: string): Promise<void> {
    try {
      const resp = await UserApi.getUserInfo(token);
      if (resp.code === 200 || resp.code === 0 || resp.code === 10000) {
        const data = resp.data;
        if (data) {
          const s = AppStorage.getInstance();
          if (data.stuName) {
            await s.setRealName(data.stuName);
            const nick = await s.getUserName();
            if (!nick || nick === '木有设置') {
              await s.setUserName(data.stuName);
            }
          }
          if (data.college) { await s.setCollege(data.college); }
          if (data.major) { await s.setMajor(data.major); }
          // 刷新界面
          await this.store.restoreFromLocal();
          this.userInfo = this.store.userInfo;
        }
      } else if (resp.code === 401 || resp.code === 403) {
        this.errorMsg = '登录已过期';
        setTimeout(() => RouterUtil.toLogin(), 1500);
      }
      console.info(TAG, 'userInfo loaded from API');
    } catch {
      console.warn(TAG, 'fetchUserInfo error');
    }
  }

  /** 清除缓存 */
  private clearCache(): void {
    promptAction.showToast({ message: '缓存已清除', duration: 2000 });
  }

  /** 退出登录 */
  private doLogout(): void {
    this.clearLoginState().then(() => RouterUtil.toLogin());
  }

  private async clearLoginState(): Promise<void> {
    const s = AppStorage.getInstance();
    await s.setToken('');
    await s.setTokenUpdateTime(0);
    await s.setTokenLastUseTime(0);
    await s.setIsLogin(false);
    await s.setMessage('');
    await StorageUtil.clearLoginInfo();
  }

  build() {
    Column() {
      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#1ec98d')
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            Row() {
              Stack({ alignContent: Alignment.BottomEnd }) {
                Image($r('app.media.ic_default_avatar'))
                  .width(64)
                  .height(64)
                  .borderRadius(32)
                  .objectFit(ImageFit.Cover)

                Image($r('app.media.ic_medal'))
                  .width(20)
                  .height(20)
                  .borderRadius(10)
                  .backgroundColor(Color.White)
              }

              Column() {
                Text(mockNickName)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333333')
                Text(mockStudentId)
                  .fontSize(13)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })

              Text('注销')
                .fontSize(13)
                .fontColor(Color.White)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#D9534F')
                .borderRadius(16)
                .onClick(() => {
                  this.showLogoutDialog = true;
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 18, bottom: 18 })
            .backgroundColor(Color.White)
            .borderRadius(16)
            .alignItems(VerticalAlign.Center)

            if (this.errorMsg !== '') {
              Text(this.errorMsg)
                .fontSize(13)
                .fontColor('#f44336')
                .margin({ top: 8 })
                .onClick(() => this.retry())
            }

            Grid() {
              ForEach(mineFeatureList, (item: MineFeatureItem) => {
                GridItem() {
                  Row() {
                    Image(item.icon)
                      .width(26)
                      .height(26)
                      .objectFit(ImageFit.Contain)

                    Column() {
                      Text(item.title)
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#333333')
                      Text(item.desc)
                        .fontSize(12)
                        .fontColor('#999999')
                        .margin({ top: 4 })
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: 10 })
                  }
                  .width('100%')
                  .padding(14)
                  .backgroundColor(item.bgColor)
                  .borderRadius(12)
                  .alignItems(VerticalAlign.Center)
                  .onClick(() => {
                    promptAction.showToast({ message: `${item.title} 功能待实现`, duration: 2000 });
                  })
                }
              }, (item: MineFeatureItem) => item.title)
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(12)
            .rowsGap(12)
            .width('100%')
            .margin({ top: 16 })

            Row() {
              Text('设置')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .layoutWeight(1)

              Image($r('app.media.ic_setting_mine'))
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ top: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              promptAction.showToast({ message: '设置页面待实现', duration: 2000 });
            })

            Text('领航工作室出品')
              .fontSize(13)
              .fontColor('#BBBBBB')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 24, bottom: 40 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 100 })
        }
        .width('100%')
      }
      if (this.showLogoutDialog) {
        LogoutConfirmDialog({
          onConfirm: () => {
            this.showLogoutDialog = false;
            this.doLogout();
          },
          onCancel: () => {
            this.showLogoutDialog = false;
          }
        })
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  private retry(): void {
    this.loading = true;
    this.errorMsg = '';
    this.verifyAndLoad();
  }
}

export { MinePage };
