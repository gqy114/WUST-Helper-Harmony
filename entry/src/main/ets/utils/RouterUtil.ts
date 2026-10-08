/**
 * 页面路由封装，对应原 Android 端 Intent + startActivity
 */
import { router } from '@kit.ArkUI';

const TAG = 'RouterUtil';

export type ReplaceType = 'replaceUrl' | 'pushUrl';

export class RouterUtil {
  /**
   * 替换当前页面（对应原 startActivity + finish）
   */
  static replace(url: string, params?: Record<string, string>): void {
    try {
      router.replaceUrl({
        url,
        params: params ?? {},
      });
      console.info(TAG, `replace to ${url}`);
    } catch {
      console.error(TAG, 'replace failed');
    }
  }

  /**
   * 压栈新页面（对应原 startActivity 不 finish）
   */
  static push(url: string, params?: Record<string, string>): void {
    try {
      router.pushUrl({
        url,
        params: params ?? {},
      });
      console.info(TAG, `push to ${url}`);
    } catch {
      console.error(TAG, 'push failed');
    }
  }

  // ── 业务专用快捷方法 ──

  static toMain(): void {
    RouterUtil.replace('pages/main/MainPage');
  }

  static toLogin(): void {
    RouterUtil.replace('pages/login/LoginPage');
  }
}



