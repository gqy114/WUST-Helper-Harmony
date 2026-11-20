import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import router from '@ohos.router';
import { StorageUtil } from '../utils/StorageUtil';
import { AppStorage } from '../store/AppStorage';

const DOMAIN = 0x0000;
const IMAGE_DATA_CACHE_BYTES: number = 16 * 1024 * 1024;

export default class EntryAbility extends UIAbility {
  // 快捷功能卡片点击后要直达的页面；为空时仍走开屏页。
  private widgetRoute: string = '';
  // 每次新的快捷入口请求都会递增；旧请求的延迟重试据此作废，避免把页面跳回旧页面。
  private routeRequestId: number = 0;

  private requestPortraitOrientation(mainWindow: window.Window): void {
    // 平板使用 AUTO_ROTATION_PORTRAIT 才会跟随传感器在两个竖向方向间旋转；
    // 固定 PORTRAIT 在部分大屏设备上会退化为横屏中的竖向兼容窗口。
    mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT).then(() => {
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Preferred orientation set to auto portrait.');
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, 'testTag', 'Failed to set auto portrait orientation. Cause: %{public}s', JSON.stringify(err));
    });
  }

  /**
   * 桌面卡片 postCardAction 的参数会被鸿蒙包一层：真正内容在 want.parameters.params 里。
   * 兼容直接参数、嵌套对象和 JSON 字符串三种形态。
   */
  private widgetRouteFromWant(want: Want): string {
    const parameters = want?.parameters;
    if (!parameters) return '';
    const direct = parameters['widgetRoute'];
    if (typeof direct === 'string' && direct.startsWith('pages/')) return direct;
    const nested = parameters['params'];
    if (nested && typeof nested === 'object') {
      const route = (nested as Record<string, Object>)['widgetRoute'];
      if (typeof route === 'string' && route.startsWith('pages/')) return route;
    }
    if (typeof nested === 'string') {
      try {
        const parsed = JSON.parse(nested) as Record<string, string>;
        const route = parsed['widgetRoute'];
        if (typeof route === 'string' && route.startsWith('pages/')) return route;
      } catch (error) {
        hilog.warn(DOMAIN, 'testTag', 'Invalid widget params: %{public}s', JSON.stringify(error));
      }
    }
    return '';
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    this.widgetRoute = this.widgetRouteFromWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // App 已在后台运行时，桌面卡片的 router action 只会走 onNewWant。
    const route = this.widgetRouteFromWant(want);
    if (route.length > 0) {
      // 新请求让之前没执行完的重试全部作废。
      this.routeRequestId++;
      const startPage = this.currentPageName();
      this.pushWidgetRoute(route, 0, this.routeRequestId, startPage);
    }
  }

  private currentPageName(): string {
    try {
      const state = router.getState();
      return state && state.name ? state.name : '';
    } catch (error) {
      return '';
    }
  }

  /**
   * 跳转失败时重试。只要用户没有自己跳到别的页面就继续尝试；
   * 若期间页面已变化（例如用户打开了图书馆），旧重试作废，避免把页面抢回。
   */
  private pushWidgetRoute(route: string, attempt: number, requestId: number, startPage: string): void {
    if (requestId !== this.routeRequestId) {
      return;
    }
    if (attempt > 0 && startPage.length > 0) {
      const current = this.currentPageName();
      if (current.length > 0 && current !== startPage) {
        hilog.info(DOMAIN, 'testTag', 'Skip widget route %{public}s, page changed to %{public}s',
          route, current);
        return;
      }
    }
    router.pushUrl({ url: route }).catch((error: Error) => {
      if (requestId !== this.routeRequestId) {
        return;
      }
      if (attempt < 3) {
        hilog.warn(DOMAIN, 'testTag', 'Route %{public}s failed, retry %{public}d. Cause: %{public}s',
          route, attempt + 1, JSON.stringify(error));
        setTimeout(() => this.pushWidgetRoute(route, attempt + 1, requestId, startPage), 400);
      } else {
        hilog.warn(DOMAIN, 'testTag', 'Route %{public}s failed after retries. Cause: %{public}s',
          route, JSON.stringify(error));
      }
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    const loadPage = (url: string): void => {
      windowStage.loadContent(url, (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
        // 内容加载完成后窗口已进入前台全屏态，此时请求旋转才能在平板上真正生效。
        try {
          const mainWindow = windowStage.getMainWindowSync();
          this.requestPortraitOrientation(mainWindow);
          // 缩略图组件重建时，优先复用已下载的图片数据。
          mainWindow.getUIContext().setImageRawDataCacheSize(IMAGE_DATA_CACHE_BYTES);
        } catch (windowError) {
          hilog.warn(DOMAIN, 'testTag', 'Failed to configure main window. Cause: %{public}s',
            JSON.stringify(windowError));
        }
      });
    };

    Promise.all([
      StorageUtil.init(this.context),
      AppStorage.getInstance().init(this.context),
    ]).then(async () => {
      // 在课表刷新之前迁移旧版实验课，避免刷新把只存在课表里的实验课覆盖掉。
      try {
        await AppStorage.getInstance().migrateLegacyExperimentsIfNeeded();
      } catch (migrationError) {
        hilog.warn(DOMAIN, 'testTag', 'Failed to migrate legacy experiments: %{public}s',
          JSON.stringify(migrationError));
      }
      // 快捷功能卡片直达对应页面，否则进入开屏页。
      loadPage(this.widgetRoute.length > 0 ? this.widgetRoute : 'pages/splash/LaunchPage');
    }).catch(() => {
      loadPage(this.widgetRoute.length > 0 ? this.widgetRoute : 'pages/splash/LaunchPage');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    // 某些平板会忽略窗口尚未进入前台时的旋转请求，进入前台后再补一次。
    window.getLastWindow(this.context).then((mainWindow: window.Window) => {
      this.requestPortraitOrientation(mainWindow);
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, 'testTag', 'Failed to get foreground window. Cause: %{public}s', JSON.stringify(err));
    });
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
