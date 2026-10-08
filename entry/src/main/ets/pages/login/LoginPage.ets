/**
 * LoginPage.ets — 登录页
 *
 * 迁移来源：LoginMvpActivity.java + activity_login.xml
 * + LoginPresenter.java + LoginModel.java
 * + PolicyDialog.java + PermissionDialog.java + ErrorLoginDialog.java
 *
 * 文件路径：entry/src/main/ets/pages/login/LoginPage.ets
 */
import promptAction from '@ohos.promptAction';
import netConnection from '@ohos.net.connection';

import { AppStorage } from '../../store/AppStorage';
import { ApiService } from '../../net/ApiService';
import { RouterUtil } from '../../utils/RouterUtil';
import { StorageUtil } from '../../utils/StorageUtil';
import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI';

import { TokenDataContent, GraduateLoginDataContent } from '../../model/BaseResponse';
// ═══════════════════════════════════════════════ 常量 ═══════════════════════════════════════════════

const TAG = 'LoginPage';
const C_THEME = '#1ec98d';
const C_GRAY = '#d0d0d0';
const C_LINK = '#a2a1a1';
const C_BLUE = '#1295ff';
const C_CONFIRM = '#2785ef';
const TIMEOUT_LOGIN = 20_000;
const TIMEOUT_COURSE = 28_000;
const URL_PRIVACY = 'https://wusthelper.wustlinghang.cn/page/android_privacy.html';
const URL_HELP = 'https://support.qq.com/product/275699/faqs-more';
const URL_VOLUNTEER = 'https://volunteer.wustlinghang.cn';

// ═══════════════════════════════════════════════ PolicyDialog═══════════════════════════════════════════════

@CustomDialog

struct PolicyDialog {
  controller?: CustomDialogController;
  onPolicyYes?: () => void;
  onFinish?: () => void;
  onClose?: () => void;

  @State private stage: number = 1;
  @State private content: string = `欢迎使用武科大助手。
1.为向您提供教务系统课表、成绩查询、学分统计、图书馆借阅等服务，我们会根据您使用服务的具体功能需要，收集必要的用户信息。
2.为了实现图片缓存与取用，降低流量消耗，需要相关媒体访问能力。您有权拒绝或者取消授权。
3.未经您的允许，我们不会与第三方共享或对外提供您的信息。`
  @State private btnNo: string = '不同意';
  @State private btnYes: string = '同意并且授权';
  @State private showLink: boolean = true;
  @State private semesterStr: string = "";

  build() {
    Column() {
      Text('温馨提示').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 10 })
      if (this.showLink) {
        Row() {
          Text('请您阅读完整版的').fontSize(14).fontColor('#333')
          Text('《用户协议与隐私政策》').fontSize(14).fontColor(C_BLUE)
            .onClick(() => {
              RouterUtil.push('pages/common/WebPage', { title: '用户协议与隐私政策', url: URL_PRIVACY });
            })
        }.padding({ left: 16 }).width('100%').margin({ top: 8 })
      }
      Scroll() {
        Text(this.content).fontSize(14).fontColor('#666').lineHeight(20).padding(16).width('100%')
      }.height(200).width('100%')
      Row() {

        Text(this.btnNo).fontSize(16).fontColor('#666').height(32).layoutWeight(1).textAlign(TextAlign.Center
        )
          .onClick(() => this.onNotPermit())

        Text(this.btnYes).fontSize(16).fontColor(C_THEME).height(32).layoutWeight(1).textAlign(TextAlign.Center)
        .onClick(() => this.onPermit())
      }.width('100%').padding(10)
    }.width('85%').backgroundColor(Color.White).borderRadius(12)
  }

  private onPermit(): void {
    if (this.stage === 1) { this.onClose?.(); this.onPolicyYes?.(); return; }
    this.stage = 1; this.showLink = true;
    this.content = '欢迎使用武科大助手。\n1.为向您提供教务系统课表……';
    this.btnYes = '同意并且授权'; this.btnNo = '不同意';
  }

  private onNotPermit(): void {
    if (this.stage === 1) {
      this.stage = 2; this.showLink = false;
      this.content = `1.您需要同意本用户协议和隐私政策才能继续使用武科大助手\n2.若您不同意，很遗憾我们无法为
      您提供服务`;
      this.btnYes = '查看协议'; this.btnNo = '仍不同意';
    } else if (this.stage === 2) {
      this.stage = 3; this.content = '要不再想想？';
      this.btnYes = '查看协议'; this.btnNo = '退出应用';
    } else {
      this.onClose?.(); this.onFinish?.();
    }
  }
}

// ═══════════════════════════════════════════════ PermissionDialog═══════════════════════════════════════════════

@CustomDialog
struct PermissionDialog {
  controller?: CustomDialogController;
  onGrant?: () => void;
  onClose?: () => void;

  build() {
    Column() {
      Text('存储权限').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 10 })
      Text('为了实现图片缓存与取用，降低流量消耗，需要您授权读取存储权限。')
        .fontSize(14).fontColor('#666').lineHeight(20).padding(16)
      Text('同意并且授权').fontSize(16).fontColor(Color.White).backgroundColor(C_THEME).borderRadius(6)
        .padding({ left: 32, right: 32, top: 8, bottom: 8 }).margin({ bottom: 10 })
        .onClick(() => { this.onClose?.(); this.onGrant?.(); })
    }.width('80%').backgroundColor(Color.White).borderRadius(12).alignItems(HorizontalAlign.Center)
  }
}

// ═══════════════════════════════════════════════ ErrorLoginDialog═══════════════════════════════════════════════

@CustomDialog
struct ErrorLoginDialog {
  controller?: CustomDialogController;
  title: string = '错误登录提醒';
  content: string = '';
  onClose?: () => void;

  build() {
    Column() {
      Text(this.title)
        .fontSize(this.title.includes('锁定') ? 22 : 19)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.title.includes('锁定') ? '#C9C14239' : '#333')
        .margin({ top: 10 })
      Scroll() {
        Text(this.content).fontSize(15).fontColor('#666').lineHeight(20).padding(16).width('100%')
      }.height(180).width('100%')
      Row() {
        Text('暂不需要').fontSize(16).fontColor('#666').height(32).layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => this.onClose?.())
        Text('').width(1).height(20).backgroundColor('#e0e0e0')
        Text('寻求帮助').fontSize(16).fontColor(C_CONFIRM).height(32).layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => { RouterUtil.push('pages/common/WebPage', { title: '帮助', url: URL_HELP });
            this.onClose?.(); })
      }.width('100%').padding(10)
    }.width('85%').backgroundColor(Color.White).borderRadius(12)
  }
}

// ═══════════════════════════════════════════════ LoadingDialog═══════════════════════════════════════════════

@CustomDialog
struct LoadingDialog {
  controller?: CustomDialogController;
  @State message: string = '登录中...';
  onClose?: () => void;

  build() {
    Column() {
      LoadingProgress().width(40).height(40).color(C_THEME)
      Text(this.message).fontSize(15).fontColor('#333').margin({ top: 12 })
    }.padding(30).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 8, color: '#20000000', offsetY: 4 })
    .width(180).height(130).alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
  }
}

// ═══════════════════════════════════════════════ UpdateDialog═══════════════════════════════════════════════

@CustomDialog
struct UpdateDialog {
  controller?: CustomDialogController;
  onClose?: () => void;

  build() {
    Column() {
      Text('发现新版本').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 16 })
      Text('请前往应用商店更新到最新版本').fontSize(14).fontColor('#666').padding(16)
      Text('知道了').fontSize(16).fontColor(C_THEME).onClick(() => this.onClose?.()).margin({ bottom:
      16 })
    }.width('80%').backgroundColor(Color.White).borderRadius(12).alignItems(HorizontalAlign.Center)
  }
}

// ═══════════════════════════════════════════════ LoginPage 主页面═══════════════════════════════════════════════

@Entry
@Component
struct LoginPage {
  // ── @State 变量 ──
  @State private studentId: string = '';
  @State private password: string = '';
  @State private isPasswordVisible: boolean = false;
  @State private isGraduate: boolean = false;
  @State private showVolunteer: boolean = true;
  @State private loadingMessage: string = '登录中...';
  @State private isShowLoadingDialog: boolean = false;
  @State private isShowPolicyDialog: boolean = false;
  @State private isShowPermissionDialog: boolean = false;
  @State private isShowErrorDialog: boolean = false;
  @State private errorTitle: string = '';
  @State private errorContent: string = '';
  // ── 内部状态 ──
  private errorCount: Record<string, number> = {};
  private isLoggingIn: boolean = false;
  private courseFinished: boolean = false;
  private loginTimer?: number;
  private courseTimer?: number;
  private semester: number = 1;
  private isPageAlive: boolean = false;
  private semesterStr: string = "";

  // ══════════ 生命周期 ══════════

  aboutToAppear(): void {
    console.info(TAG, 'aboutToAppear');
    this.isPageAlive = true;
    try {
      AppStorage.getInstance().init(getContext(this) as common.UIAbilityContext);
      StorageUtil.init(getContext(this) as common.Context);
    } catch {
      console.warn(TAG, 'AppStorage init failed');
    }
  }

  onPageShow(): void {
    console.info(TAG, 'onPageShow');
    this.initDialogs();
    this.restoreCredentials();
    this.checkPolicy();
  }

  onBackPress(): boolean {
    if (this.isLoggingIn) {
      console.info(TAG, 'back blocked - logging in');
      return true;
    }
    return false;
  }

  onPageHide(): void {
    this.clearTimers();
  }

  aboutToDisappear(): void {
    this.clearTimers();
    this.isPageAlive = false;
  }
  // ══════════ 恢复凭据 & 检查协议 ══════════

  private async restoreCredentials(): Promise<void> {
    try {
      const s = AppStorage.getInstance();
      const sid = await s.getStudentId();
      const pwd = await s.getPassword();
      if (sid?.trim()) this.studentId = sid;
      if (pwd?.trim()) this.password = pwd;
    } catch {
      console.warn(TAG, 'restore error');
    }
  }

  private async checkPolicy(): Promise<void> {
    try {
      const storage = AppStorage.getInstance();
      const agreed: boolean = await storage.getIsConfirmPolicy();
      if (!agreed) {
        setTimeout(() => {
          if (this.isPageAlive) { this.isShowPolicyDialog = true; }
        }, 300);
      }
    } catch {
      console.warn(TAG, 'checkPolicy error');
    }
  }

  // ══════════ 切换 研究生/本科 ══════════

  private async onSwitchChanged(): Promise<void> {
    const s = AppStorage.getInstance();
    await s.setIsGraduate(this.isGraduate);
    this.showVolunteer = !this.isGraduate;
  }

  // ══════════ 登录按钮点击 ══════════

  private onLoginClick(): void {
    console.info(TAG, 'onLoginClick entered');
    const sid = this.studentId.trim();
    const pwd = this.password.trim();
    console.info(TAG, 'onLoginClick sid=' + sid + ' pwdLen=' + pwd.length);
    if (sid.length !== 12) {
      console.info(TAG, 'onLoginClick validation failed, sidLen=' + sid.length);
      promptAction.showToast({ message: '请输入正确的学号(12位)', duration: 2000 });
      return;
    }
    if (pwd.length <= 0) {
      console.info(TAG, 'onLoginClick validation failed, password empty');
      promptAction.showToast({ message: '请输入密码', duration: 2000 });
      return;
    }
    console.info(TAG, 'onLoginClick validation passed, calling doLogin');
    this.doLogin(sid, pwd);

  }

  // ══════════ 检查网络 ══════════

  private async checkNetwork(): Promise<boolean> {
    try {
      const netHandle = await netConnection.getDefaultNet();
      const caps = await netConnection.getNetCapabilities(netHandle);
      // 有非空 NetCapabilities 对象 → 网络可用
      if (!caps) {
        return false;
      }
      return caps !== null && caps !== undefined;
    } catch {
      console.error(TAG, 'checkNetwork: network check failed');
      // 网络不可达或未连接 → 返回 false
      return false;
    }
  }

  // ══════════ 执行登录 ══════════

  private async doLogin(sid: string, pwd: string): Promise<void> {
    if (this.isLoggingIn) return;
    this.isLoggingIn = true;
    this.semesterStr = this.calcSemester();
    await AppStorage.getInstance().setSemester(this.semesterStr);
    this.showLoading('\u767b\u5f55\u4e2d...');
    this.startLoginTimer();

    try {
      const resp = this.isGraduate
        ? await ApiService.loginGraduate(sid, pwd)
        : await ApiService.loginUndergrad(sid, pwd);
      this.clearLoginTimer();

      if (resp && (resp.code === 200 || resp.code === 0)) {
        const s = AppStorage.getInstance();
        if (resp.data) {
          if (this.isGraduate) {
            const gdata = resp.data as GraduateLoginDataContent;
            if (gdata.name) {
              await s.setUserName(gdata.name);
            }
            await StorageUtil.saveLoginInfo('grad_' + sid, sid, sid);
            console.info(TAG, 'graduate login, sid saved');
          } else {
            const tdata = resp.data as TokenDataContent;
            if (tdata.token) {
              await s.setToken(tdata.token);
              await s.setIsLogin(true);
              await s.setTokenUpdateTime(Date.now());
              await s.setTokenLastUseTime(Date.now());
              await s.setStudentId(sid);
              await s.setPassword(pwd);
              await StorageUtil.saveLoginInfo(tdata.token, sid, sid);
              console.info(TAG, 'login token saved: ' + tdata.token);
            }
          }
        }
        this.hideLoading();
        this.isLoggingIn = false;
        promptAction.showToast({ message: '登录成功，准备跳转', duration: 1500 });
        this.clearTimers();
        console.info(TAG, 'navigating to MainPage');
        setTimeout(() => {
          router.pushUrl({ url: 'pages/main/MainPage' }).catch((err: Error) => {
            console.error(TAG, 'pushUrl failed: ' + JSON.stringify(err));
          });
        }, 300);

      } else {
        this.hideLoading();
        this.isLoggingIn = false;
        this.handleLoginFail(sid, resp?.msg ?? '\u767b\u5f55\u5931\u8d25');
      }
    } catch {
      this.clearLoginTimer();
      this.hideLoading();
      this.isLoggingIn = false;
      promptAction.showToast({ message: '\u767b\u5f55\u8bf7\u6c42\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc', duration: 3000 });
      console.error(TAG, 'login error');
    }
  }
  private async loginUndergrad(sid: string, pwd: string): Promise<void> {
    try {
      const resp = await ApiService.loginUndergrad(sid, pwd);
      this.clearLoginTimer();
      if (resp && (resp.code === 200 || resp.code === 0) && resp.data?.token) {
        await this.saveLoginData(resp.data.token, resp.msg ?? '', sid, pwd);
        this.silentAppAuth(sid, pwd, false);
        this.syncOnLogin();
        this.fetchUserInfo(sid);
        this.fetchTermStart();
        await this.fetchCourse();
      } else {
        this.handleLoginFail(sid, resp?.msg ?? '登录失败');
      }
    } catch {
      this.clearLoginTimer();
      this.handleLoginFail(sid, '网络异常，请稍后重试');
    }
  }
  private async loginGraduate(sid: string, pwd: string): Promise<void> {
    try {
      const resp = await ApiService.loginGraduate(sid, pwd);
      this.clearLoginTimer();
      if (resp && (resp.code === 200 || resp.code === 0)) {
        const token = 'grad_' + sid;
        await this.saveLoginData(token, resp.msg ?? '', sid, pwd);
        if (resp.data) {
          const s = AppStorage.getInstance();
          if (resp.data.college) await s.setCollege(resp.data.college);
          if (resp.data.major) await s.setMajor(resp.data.major);
          if (resp.data.name) {
            await s.setRealName(resp.data.name);
            const nick = await s.getUserName();
            if (!nick?.trim() || nick === '木有设置') await s.setUserName(resp.data.name);
          }
        }
        this.silentAppAuth(sid, pwd, true);
        this.syncOnLogin();
        this.fetchTermStart();
        await this.fetchCourse();
      } else {
        this.handleLoginFail(sid, resp?.msg ?? '账号或密码错误');
      }
    } catch {
      this.clearLoginTimer();
      this.handleLoginFail(sid, '网络异常，请稍后重试');
    }
  }
  private handleLoginFail(sid: string, msg: string): void {
    this.hideLoading();
    promptAction.showToast({ message: msg || '登录失败', duration: 2000 });
    if (!this.errorCount[sid]) this.errorCount[sid] = 0;
    this.errorCount[sid]++;
    const c = this.errorCount[sid];
    if (c === 3) {
      this.showErrorDialog('错误登录提醒',
        `\t\t\t\t\t该账号已三次登录"武科大助手"密码错误，您可以去帮助中心寻求帮助，也可联系相关管理员为您解
      决。`);
    } else if (c > 4) {
      this.showErrorDialog('！账号锁定提醒',
        `\t\t\t\t\t该账号已五次或以上登录"武科大助手"密码错误，您可以去新版教务处官网查验此账号是否被锁
      定。`);
    }
  }

  // ══════════ 保存登录数据 ══════════

  private async saveLoginData(token: string, msg: string, sid: string, pwd: string): Promise<void> {
    try {
    const s = AppStorage.getInstance();
    const now = Date.now();
    await s.setToken(token);
    await s.setTokenUpdateTime(now);
    await s.setTokenLastUseTime(now);
    await s.setMessage(msg);
    await s.setIsLogin(true);
    await s.setStudentId(sid);
    await s.setPassword(pwd);
    await s.setSelectSemester(this.semesterStr);
    await s.setSemester(this.semesterStr);
    await StorageUtil.saveLoginInfo(token, sid, sid);
    const w = (await s.getWeek()) > 0 ? await s.getWeek() : 1;
    await s.setDate(this.formatToday());
    await s.setWeek(w);
    await s.setWeekday(this.weekday());
    } catch {
      console.error(TAG, 'saveLoginData failed');
    }
  }
  // ══════════ 后台任务 ══════════

private async fetchUserInfo(_sid: string): Promise<void> {
    console.info(TAG, 'fetchUserInfo stub');
  }

  private async fetchTermStart(): Promise<void> {
    console.info(TAG, 'fetchTermStart stub');
  }

  private async fetchCourse(): Promise<void> {
    this.courseFinished = false;
    this.updateLoading('登录成功，正在请求课表...');
    this.startCourseTimer();
    try {
      this.finishCourse(null);
    } catch {
      this.finishCourse('登录成功，但是课表获取失败，可能是教务处不稳定或者请求超时');
    }
  }

  private finishCourse(toast: string | null): void {
    if (this.courseFinished) return;
    this.courseFinished = true;
    this.clearCourseTimer();
    this.hideLoading();
    if (toast) promptAction.showToast({ message: toast, duration: 3000 });
    RouterUtil.toMain();
  }

  private async silentAppAuth(_sid: string, _pwd: string, _isGrad: boolean): Promise<void> {
    try {
      await ApiService.loginAppAuthFromSavedCredentials(AppStorage.getInstance());
    } catch {
      console.warn(TAG, 'appAuth err');
    }
  }

  private async syncOnLogin(): Promise<void> {
    console.info(TAG, 'syncOnLogin stub');
  }

  // ══════════ 弹窗管理 ══════════

  private showLoading(msg: string): void {
    this.loadingMessage = msg;
    this.isShowLoadingDialog = true;
  }

  private updateLoading(msg: string): void {
    this.loadingMessage = msg;
    console.info(TAG, 'updateLoading: ' + msg);
  }

  private hideLoading(): void {
    this.isShowLoadingDialog = false;
  }

  private openPermissionDialog(): void {
    this.isShowPermissionDialog = true;
  }

  private initDialogs(): void {
    console.info(TAG, 'initDialogs migrated to @State');
  }

  private showErrorDialog(title: string, content: string): void {
    this.errorTitle = title;
    this.errorContent = content;
    this.isShowErrorDialog = true;
  }

  private requestStoragePermission(): void {
    console.info(TAG, 'requestStoragePermission: stub — use abilityAccessCtrl');
  }

  // ══════════ 定时器管理 ══════════

  private startLoginTimer(): void {
    this.clearLoginTimer();
    this.loginTimer = setTimeout(() => {
      if (!this.isPageAlive) return;
      this.hideLoading();
      promptAction.showToast({ message: '登录超时，请检查网络或稍后再试', duration: 3000 });
      this.isLoggingIn = false;
    }, TIMEOUT_LOGIN);
  }

  private clearLoginTimer(): void {
    if (this.loginTimer !== undefined && this.loginTimer !== null) {
      clearTimeout(this.loginTimer);
      this.loginTimer = undefined;
    }
  }

  private startCourseTimer(): void {
    this.clearCourseTimer();
    this.courseTimer = setTimeout(() => {
      if (!this.isPageAlive) return;
      this.finishCourse('登录成功，但是课表获取超时，可能是教务处不稳定');
    }, TIMEOUT_COURSE);
  }

  private clearCourseTimer(): void {
    if (this.courseTimer !== undefined && this.courseTimer !== null) {
      clearTimeout(this.courseTimer);
      this.courseTimer = undefined;
    }
  }

  private clearTimers(): void {
    this.clearLoginTimer();
    this.clearCourseTimer();
  }

  // ══════════ 工具方法 ══════════

  private calcSemester(): string {
    const now = new Date();
    const m = now.getMonth() + 1;
    const d = now.getDate();
    const first = m > 8 || (m === 8 && d >= 15);
    return first ? `${now.getFullYear()}-${now.getFullYear() + 1}-1` : `${now.getFullYear() -
      1}-${now.getFullYear()}-2`;
  }

  private formatToday(): string {
    const n = new Date();
    return `${n.getFullYear()}-${String(n.getMonth() + 1).padStart(2, '0')}-${String(n.getDate()).padStart(2,
      '0')}`;
  }

  private weekday(): number {
    const d = new Date().getDay();
    return d === 0 ? 7 : d;
  }

  private finishApp(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      if (ctx?.terminateSelf) {
        ctx.terminateSelf();
      }
    } catch {
      console.warn(TAG, 'finishApp: exit failed');
    }
  }

  // ══════════ UI 布局 ══════════

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor(Color.White)

      Scroll() {
        Column() {
          // ── Logo + 标题 ──
          Row() {
            Image($r('app.media.logo')).width(60).height(60).borderRadius(8).objectFit(ImageFit.Contain)
            Column() {
              Text('武科大助手').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#484747')
              Text('随时随地  开启校园之旅').fontSize(14).fontColor('#979797').margin({ top: 5 })
            }.alignItems(HorizontalAlign.Start).margin({ left: 10 })
          }.justifyContent(FlexAlign.Center).width('100%').margin({ top: '12%' })

          // ── 本科生/研究生 切换 ──
          Row() {
            Text('本科生').fontSize(14)
              .fontColor(this.isGraduate ? '#f0f0f0' : Color.White)
              .width(140).height(40).textAlign(TextAlign.Center)
              .backgroundColor(this.isGraduate ? Color.Transparent : C_THEME)
              .borderRadius({ topLeft: 20, bottomLeft: 20 })
            Text('研究生').fontSize(14)
              .fontColor(this.isGraduate ? Color.White : '#f0f0f0')
              .width(140).height(40).textAlign(TextAlign.Center)
              .backgroundColor(this.isGraduate ? C_THEME : Color.Transparent)
              .borderRadius({ topRight: 20, bottomRight: 20 })
          }.width(280).height(40).backgroundColor(C_GRAY).borderRadius(20).margin({ top: 40 })
          .onClick(() => { this.isGraduate = !this.isGraduate; this.onSwitchChanged(); })

          // ── 输入区 ──
          Column() {
            TextInput({ placeholder: '学号' })
              .fontSize(16).height(48).backgroundColor('#f5f5f5').borderRadius(8)
              .onChange((v: string) => { this.studentId = v; })

            Row() {
              TextInput({ placeholder: '教务处密码' })
                .fontSize(16).height(48)
                .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
                .backgroundColor('#f5f5f5').borderRadius(8).padding({ left: 16 }).placeholderColor('#bbb')
                .layoutWeight(1).onChange((v: string) => { this.password = v; })
            }.margin({ top: 16 }).height(48).backgroundColor('#f5f5f5').borderRadius(8)
          }.width('100%').padding({ left: 25, right: 25 }).margin({ top: 30 })

          // ── 登录按钮 ──
          Button('登录').fontSize(17).fontColor(Color.White).backgroundColor(C_THEME)
            .width('90%').height(48).borderRadius(10).margin({ top: 30 })
            .onClick(() => this.onLoginClick())

          // ── 底部链接 ──
          Row() {
            if (this.showVolunteer) {
              Text('工时系统').fontSize(14).fontWeight(FontWeight.Bold).fontColor(C_THEME).margin({ left: 30 })
                .onClick(() => { RouterUtil.push('pages/common/WebPage', { title: '工时系统', url: URL_VOLUNTEER }); })
            }
            if (this.showVolunteer) { Blank() } else { Blank().layoutWeight(1) }
            Text('忘记密码？登录遇到问题？').fontSize(14).fontColor(C_LINK).margin({ right: 30 })
              .onClick(() => { RouterUtil.push('pages/common/WebPage', { title: '帮助', url: URL_HELP }); })
          }.width('100%').margin({ top: 13 }).padding({ bottom: 60 })
        }.width('100%')
      }.width('100%').height('100%')

      // ── 底部版权 ──
      Column() {
        Text('Copyright ©2015-2022').fontSize(13).fontColor(C_LINK)
        Text('LingHang Studio.武科大领航工作室').fontSize(13).fontColor(C_LINK).margin({ top: 2 })
      }.width('100%').alignItems(HorizontalAlign.Center).position({ x: 0, y: '92%' })

      if (this.isShowLoadingDialog) {
        LoadingDialog({
          message: this.loadingMessage,
          onClose: () => { this.isShowLoadingDialog = false; }
        })
      }

      if (this.isShowPolicyDialog) {
        PolicyDialog({
          onPolicyYes: () => {
            this.isShowPolicyDialog = false;
            this.openPermissionDialog();
          },
          onFinish: () => {
            this.isShowPolicyDialog = false;
            this.finishApp();
          },
          onClose: () => { this.isShowPolicyDialog = false; }
        })
      }

      if (this.isShowPermissionDialog) {
        PermissionDialog({
          onGrant: () => {
            this.isShowPermissionDialog = false;
            this.requestStoragePermission();
          },
          onClose: () => { this.isShowPermissionDialog = false; }
        })
      }

      if (this.isShowErrorDialog) {
        ErrorLoginDialog({
          title: this.errorTitle,
          content: this.errorContent,
          onClose: () => { this.isShowErrorDialog = false; }
        })
      }
    }.width('100%').height('100%')
  }
}
