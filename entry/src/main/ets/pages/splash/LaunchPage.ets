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
  private navigationScheduled: boolean = false;

  aboutToAppear(): void {
    // 竖屏锁定 → 在 module.json5 abilities[].orientation = "portrait"
    // 页面过渡动画 → 使用 pageTransition 声明式 API（见底部）
    console.info(TAG, 'aboutToAppear');
  }

  onPageShow(): void {
    // 对应 onResume()
    console.info(TAG, 'onPageShow');
    if (!this.navigationScheduled) {
      this.navigationScheduled = true;
      // 给开屏图保留完整展示时间，再进入登录页或主页。
      setTimeout(() => this.handleNavigation(), 1500);
    }
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
      let isLogin = await storage.getIsLogin();

      // After a reboot or an app update the persisted teaching-system token
      // may be empty/expired, while the saved credentials are still present.
      // Re-establish the session before deciding to show the login page.
      if (!isLogin || !(await storage.getToken())) {
        const sid = await storage.getStudentId();
        const pwd = await storage.getPassword();
        if (sid && pwd) {
          const graduate = await storage.getIsGraduate();
          const refreshed = graduate
            ? await ApiService.refreshGraduateToken(storage, sid, pwd)
            : await ApiService.refreshUndergradToken(storage, sid, pwd);
          isLogin = refreshed;
          if (refreshed) await storage.setIsLogin(true);
        }
      }

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
      Image($r('app.media.open'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
