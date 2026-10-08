/**
 * LaunchPage.ets
 *
 * 迁移来源：LaunchActivity.java
 * 布局来源：activity_launch.xml + StartTheme
 *
 * 文件路径：entry/src/main/ets/pages/splash/LaunchPage.ets
 */
import { AppStorage } from '../../store/AppStorage';
import { ApiService } from '../../net/ApiService';
import { RouterUtil } from '../../utils/RouterUtil';

const TAG = 'LaunchPage';

/** 全局 token 持有者（对应 NewApiHelper 静态字段） */
class TokenHolder {
  private static token: string = '';
  private static message: string = '';

  static getToken(): string { return TokenHolder.token; }
  static setToken(t: string) { TokenHolder.token = t; }
  static getMessage(): string { return TokenHolder.message; }
  static setMessage(m: string) { TokenHolder.message = m; }
}

@Entry
@Component
struct LaunchPage {
  aboutToAppear(): void {
    // 竖屏锁定 → 在 module.json5 abilities[].orientation = "portrait"
    // 页面过渡动画 → 使用 pageTransition 声明式 API（见底部）
    console.info(TAG, 'aboutToAppear');
  }

  onPageShow(): void {
    // 对应 onResume()
    console.info(TAG, 'onPageShow');
    this.handleNavigation();
  }

  onBackPress(): boolean {
    // 对应 onBackPressed() 空实现：阻止系统返回
    console.info(TAG, 'back blocked');
    return true;
  }

  // ═══════════════════════ 导航逻辑 ═══════════════════════

  private async handleNavigation(): Promise<void> {
    try {
      const storage = AppStorage.getInstance();
      const isLogin = await storage.getIsLogin();

      if (isLogin) {
        // ① 恢复内存 Token
        await this.restoreToken();
        // ② 跳主页（先跳，不阻塞）
        RouterUtil.toMain();
        // ③ 后台恢复 AppAuth 并刷新 Token
        this.ensureAppAuthAsync();
        this.refreshTokenAsync();
      } else {
        RouterUtil.toLogin();
      }
    } catch (err) {
      console.error(TAG, `handleNavigation error: ${err}`);
      RouterUtil.toLogin();
    }
  }

  private async restoreToken(): Promise<void> {
    const storage = AppStorage.getInstance();
    let token = await storage.getToken();
    if (!token || token.trim().length === 0) {
      token = await storage.getToken();
    }
    const msg = await storage.getMessage();
    TokenHolder.setToken(token);
    TokenHolder.setMessage(msg);
    console.info(TAG, `token restored, len=${token.length}`);
  }

  // ═══════════════════════ 后台任务 ═══════════════════════

  /** App Auth 恢复（不阻塞跳转） */
  private async ensureAppAuthAsync(): Promise<void> {
    const storage = AppStorage.getInstance();
    const hasUsable = await storage.hasUsableAppAuthToken();
    if (hasUsable) {
      console.info(TAG, 'app auth already usable');
      return;
    }
    try {
      await ApiService.loginAppAuthFromSavedCredentials(storage);
    } catch {
      console.warn(TAG, 'ensureAppAuth failed');
    }
  }

  /** Token 后台刷新（不阻塞跳转） */
  private async refreshTokenAsync(): Promise<void> {
    const storage = AppStorage.getInstance();
    const sid = await storage.getStudentId();
    const pwd = await storage.getPassword();
    if (!sid || !pwd) {
      console.info(TAG, 'skip refresh: no creds');
      return;
    }
    try {
      const isGraduate = await storage.getIsGraduate();
      let ok: boolean;
      if (isGraduate) {
        ok = await ApiService.refreshGraduateToken(storage, sid, pwd);
      } else {
        ok = await ApiService.refreshUndergradToken(storage, sid, pwd);
      }
      console.info(TAG, `token refresh ${ok ? 'ok' : 'failed'}`);
    } catch {
      console.warn(TAG, 'refreshToken failed');
    }
  }

  // ═══════════════════════ UI ═══════════════════════

  build() {
    Stack() {
      // 纯黑背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      // 中部：Logo + 标语
      Column() {
        Image($r('app.media.logo_foreground'))
          .width(120)
          .height(120)
          .objectFit(ImageFit.Contain)

        Text('随时随地  开启校园之旅')
          .fontSize(17)
          .fontColor('#787878')
          .margin({ top: 16 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .position({ x: 0, y: '25%' })

      // 底部版权信息
      Column() {
        Text('武科大教务处唯一授权')
          .fontSize(17)
          .fontColor(Color.White)
          .margin({ bottom: 15 })

        Text('武汉科技大学青年志愿者服务队合作伙伴')
          .fontSize(17)
          .fontColor(Color.White)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .position({ x: 0, y: '85%' })
    }
    .width('100%')
    .height('100%')
  }

  // ═══════════════════════ 页面过渡动画 ═══════════════════════
  // 对应 overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
  //
  // pageTransition() {
  //   PageTransitionEnter({ duration: 300, curve: Curve.FadeIn })
  //     .onEnter((type, progress) => {})
  //   PageTransitionExit({ duration: 300, curve: Curve.FadeOut })
  //     .onExit((type, progress) => {})
  // }
  //
  // 注意事项：
  //   - pageTransition 是 @Entry Page 组件专有声明式 API
  //   - 若目标 SDK 不支持，可在 module.json5 的 abilities 中配置
  //     "startWindowAnimation": {"enter": "fade", "exit": "fade"}
}
