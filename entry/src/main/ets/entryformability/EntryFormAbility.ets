/**
 * 桌面小组件（卡片）的 FormExtensionAbility。
 *
 * 负责：
 *  - onAddForm：返回初始卡片数据
 *  - onUpdateForm：系统触发或设置页刷新时重新生成数据
 *  - onFormEvent：卡片上按钮（message = 'refresh'）触发时刷新
 */
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Configuration, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { AppStorage } from '../store/AppStorage';
import { WidgetData, WidgetSnapshot } from '../widget/WidgetData';

const TAG = 'EntryFormAbility';
const FORM_ID_KEY = 'ohos.extra.param.key.form_identity';
const FORM_NAME_KEY = 'ohos.extra.param.key.form_name';
const FORM_MODE_PREFIX = 'widgetFormMode_';

interface WidgetCardMessage {
  action?: string;
  archiveId?: string;
}

export default class EntryFormAbility extends FormExtensionAbility {
  private storageReady: boolean = false;
  private updateQueue: Promise<void> = Promise.resolve();

  private async ensureStorage(): Promise<void> {
    if (this.storageReady) return;
    await AppStorage.getInstance().init(this.context);
    this.storageReady = true;
  }

  private async buildBindingData(formId: string = ''): Promise<formBindingData.FormBindingData> {
    try {
      await this.ensureStorage();
      const dark = this.systemDark();
      const storage = AppStorage.getInstance();
      let modeOverride = '';
      if (formId.length > 0) {
        modeOverride = (await storage.getSettingString(`${FORM_MODE_PREFIX}${formId}`, '')).trim();
      }
      const snapshot: WidgetSnapshot = await WidgetData.build(storage, dark, modeOverride, formId);
      return formBindingData.createFormBindingData(snapshot);
    } catch (error) {
      console.warn(TAG, `build binding data failed: ${JSON.stringify(error)}`);
      return formBindingData.createFormBindingData({
        mode: 'countdown',
        title: '梧桐助手',
        subtitle: '打开 App 后即可同步数据',
        line0: '',
        line1: '',
        line2: '',
        line3: '',
        line4: '',
        line5: '',
        days: '',
        detail: '',
        accent: '#EC5A3C',
        bg: '',
        bgOpacity: 0.7,
        cardBg: '#FFFFFF',
        textColor: '#111111',
        subColor: '#666666',
        updatedAt: ''
      });
    }
  }

  /** 当前系统是否深色；用于“跟随系统”主题。 */
  private systemDark(): boolean {
    try {
      return this.context.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (error) {
      console.warn(TAG, `read color mode failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    console.info(TAG, 'config updated, refreshing forms');
    this.refreshAllForms();
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want?.parameters?.[FORM_ID_KEY] as string;
    const formName = (want?.parameters?.[FORM_NAME_KEY] as string) || '';
    // 四套独立小组件：倒计时 / 周课表 / 日课表 / 快捷功能，按 form 名称决定内容。
    let initialMode = 'countdown';
    if (formName.indexOf('weekly') >= 0) {
      initialMode = 'weekly';
    } else if (formName.indexOf('daily') >= 0) {
      initialMode = 'daily';
    } else if (formName.indexOf('quick') >= 0) {
      initialMode = 'quick';
    }
    this.rememberFormMode(formId, initialMode).then(() => {
      setTimeout(() => this.refreshForm(formId), 300);
    });
    return formBindingData.createFormBindingData({
      mode: initialMode,
      countdownCompact: want?.parameters?.['ohos.extra.param.key.form_dimension'] === formInfo.FormDimension.Dimension_2_2,
      title: '梧桐助手',
      subtitle: '正在加载数据…',
      line0: '',
      line1: '',
      line2: '',
      line3: '',
      line4: '',
      line5: '',
      days: '',
      detail: '',
      accent: '#EC5A3C',
      bg: '',
      bgOpacity: 0.7,
      cardBg: '#FFFFFF',
      textColor: '#111111',
      subColor: '#666666',
      updatedAt: ''
    });
  }

  onUpdateForm(formId: string): void {
    this.applyData(formId);
  }

  onFormEvent(formId: string, message: string): void {
    let event: WidgetCardMessage | undefined;
    try {
      event = JSON.parse(message) as WidgetCardMessage;
    } catch {
      event = undefined;
    }
    this.applyData(formId, event?.action === 'selectArchive' ? event.archiveId : undefined);
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    // 可见性变化时刷新一次，保证上课时间等数据不过期。
    this.refreshAllForms();
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private rememberFormMode(formId: string | undefined, mode: string): Promise<void> {
    const id = (formId || '').trim();
    if (!id) return Promise.resolve();
    return this.enqueue(async () => {
      await this.ensureStorage();
      const storage = AppStorage.getInstance();
      await storage.setSettingString(`${FORM_MODE_PREFIX}${id}`, mode);
      if (mode === 'daily' || mode === 'weekly') await storage.getWidgetSchedule(id);
    });
  }

  private enqueue(task: () => Promise<void>): Promise<void> {
    this.updateQueue = this.updateQueue.then(task).catch((error: Error) => {
      console.warn(TAG, `form update failed: ${JSON.stringify(error)}`);
    });
    return this.updateQueue;
  }

  private refreshForm(formId: string | undefined): void {
    if (!formId || formId.length === 0) return;
    this.applyData(formId);
  }

  private refreshAllForms(): void {
    formProvider.getPublishedRunningFormInfos().then((infos: formInfo.RunningFormInfo[]) => {
      for (let i = 0; i < infos.length; i++) {
        this.applyData(infos[i].formId);
      }
    }).catch((error: Error) => {
      console.warn(TAG, `get published forms failed: ${JSON.stringify(error)}`);
    });
  }

  private applyData(formId: string, archiveId?: string): void {
    this.enqueue(async () => {
      if (typeof archiveId === 'string' && archiveId) {
        await this.ensureStorage();
        const storage = AppStorage.getInstance();
        const mode = await storage.getSettingString(FORM_MODE_PREFIX + formId, '');
        if (mode === 'daily' || mode === 'weekly') await storage.setWidgetScheduleArchive(formId, archiveId);
      }
      const data = await this.buildBindingData(formId);
      await formProvider.updateForm(formId, data);
    });
  }
}
