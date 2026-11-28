import { formBindingData, formProvider } from '@kit.FormKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import { AppStorage } from '../store/AppStorage';
import { WidgetData, WIDGET_MODE_DAILY, WIDGET_MODE_WEEKLY } from './WidgetData';

export class ScheduleWidgetRefresh {
  private static queue: Promise<void> = Promise.resolve();

  static run(context: common.UIAbilityContext, epoch: number): void {
    const dark = context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    ScheduleWidgetRefresh.queue = ScheduleWidgetRefresh.queue.then(async () => {
      const storage = AppStorage.getInstance();
      if (epoch !== storage.getSessionEpoch()) return;
      const forms = await formProvider.getPublishedRunningFormInfos();
      for (const info of forms) {
        const fallback = info.formName === 'wust_daily' ? WIDGET_MODE_DAILY
          : info.formName === 'wust_weekly' ? WIDGET_MODE_WEEKLY : '';
        const mode = await storage.getSettingString('widgetFormMode_' + info.formId, fallback);
        if (mode !== WIDGET_MODE_DAILY && mode !== WIDGET_MODE_WEEKLY) continue;
        try {
          const snapshot = await WidgetData.build(storage, dark, mode, info.formId);
          if (epoch !== storage.getSessionEpoch()) return;
          await formProvider.updateForm(info.formId, formBindingData.createFormBindingData(snapshot));
        } catch (error) {
          console.warn('ScheduleWidgetRefresh', '卡片刷新失败: ' + JSON.stringify(error));
        }
      }
    }).catch((error: Error) => {
      console.warn('ScheduleWidgetRefresh', '读取卡片列表失败: ' + error.message);
    });
  }
}
