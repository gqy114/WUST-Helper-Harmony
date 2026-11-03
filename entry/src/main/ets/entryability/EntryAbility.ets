import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { StorageUtil } from '../utils/StorageUtil';
import { AppStorage } from '../store/AppStorage';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private requestPortraitOrientation(mainWindow: window.Window): void {
    // 平板使用 AUTO_ROTATION_PORTRAIT 才会跟随传感器在两个竖向方向间旋转；
    // 固定 PORTRAIT 在部分大屏设备上会退化为横屏中的竖向兼容窗口。
    mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT).then(() => {
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Preferred orientation set to auto portrait.');
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, 'testTag', 'Failed to set auto portrait orientation. Cause: %{public}s', JSON.stringify(err));
    });
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
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
          this.requestPortraitOrientation(windowStage.getMainWindowSync());
        } catch (orientationError) {
          hilog.warn(DOMAIN, 'testTag', 'Main window is not ready after load. Cause: %{public}s',
            JSON.stringify(orientationError));
        }
      });
    };

    Promise.all([
      StorageUtil.init(this.context),
      AppStorage.getInstance().init(this.context),
    ]).then(() => {
      // 统一先进入开屏页，由 LaunchPage 决定登录页或主页，并展示自定义 open.png。
      loadPage('pages/splash/LaunchPage');
    }).catch(() => {
      loadPage('pages/splash/LaunchPage');
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
