/**
 * 小组件设置页。
 *
 * 与 EntryFormAbility 共用 WidgetPrefs / WidgetData：
 *  - 设置：切换卡片内容类型、编辑倒计时、同步考试倒计时
 *  - 刷新：重新生成数据并刷新所有已添加的卡片
 *  - 添加：打开系统小组件管理页
 *  - 外观：自定义背景（选图 + 2:1 裁剪）、主题（滚轮选择）、背景不透明度
 */
import { promptAction, router } from '@kit.ArkUI';
import { formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppStorage } from '../../store/AppStorage';
import { CountdownApi, CountdownItem } from '../../net/CountdownApi';
import {
  WidgetCountdownItem,
  WidgetData,
  WidgetPrefs,
  WidgetSnapshot,
  WIDGET_MODE_COUNTDOWN,
  WIDGET_MODE_DAILY,
  WIDGET_MODE_WEEKLY,
  WIDGET_THEME_DARK,
  WIDGET_THEME_LIGHT,
  WIDGET_THEME_SYSTEM,
  DEFAULT_BACKGROUND_OPACITY
} from '../../widget/WidgetData';

const TAG = 'WidgetSettingsPage';
const WIDGET_TABS: string[] = ['倒计时', '每日课表', '每周课表'];
const TAB_MODES: string[] = [WIDGET_MODE_COUNTDOWN, WIDGET_MODE_DAILY, WIDGET_MODE_WEEKLY];
const THEME_LABELS: string[] = ['跟随系统', '简洁白', '主题黑'];
const THEME_VALUES: string[] = [WIDGET_THEME_SYSTEM, WIDGET_THEME_LIGHT, WIDGET_THEME_DARK];
const BUNDLE_NAME = 'wust.linghang.wusthelper';
// 卡片默认 4:2，裁剪框按 2:1 显示。
const CROP_WIDTH = 300;
const CROP_HEIGHT = 150;

@Entry
@Component
struct WidgetSettingsPage {
  @State private selectedTab: number = 0;
  @State private helpOpen: boolean = false;
  @State private addOpen: boolean = false;
  @State private countdownTitle: string = '';
  @State private countdownDate: string = '';
  @State private countdowns: WidgetCountdownItem[] = [];
  @State private examCountdowns: WidgetCountdownItem[] = [];
  @State private snapshot: WidgetSnapshot | null = null;
  @State private accent: string = '#EC5A3C';
  @State private publishedCount: number = 0;
  @State private busy: boolean = false;

  // 外观：背景 / 不透明度 / 主题
  @State private backgroundPath: string = '';
  @State private backgroundOpacity: number = DEFAULT_BACKGROUND_OPACITY;
  @State private theme: string = WIDGET_THEME_SYSTEM;

  // 裁剪器
  @State private showingCropper: boolean = false;
  @State private cropImageUri: string = '';
  @State private cropImageWidth: number = 0;
  @State private cropImageHeight: number = 0;
  @State private cropScale: number = 1;
  @State private cropOffsetX: number = 0;
  @State private cropOffsetY: number = 0;
  @State private cropperBusy: boolean = false;
  private cropStartOffsetX: number = 0;
  private cropStartOffsetY: number = 0;

  aboutToAppear(): void {
    this.loadSettings();
    this.refreshPublishedCount();
  }

  private async loadSettings(): Promise<void> {
    const storage = AppStorage.getInstance();
    const mode = await WidgetPrefs.getMode(storage);
    this.selectedTab = mode === WIDGET_MODE_DAILY ? 1 : (mode === WIDGET_MODE_WEEKLY ? 2 : 0);
    this.accent = await WidgetPrefs.getAccent(storage);
    this.countdowns = await WidgetPrefs.getCountdowns(storage);
    this.examCountdowns = await WidgetPrefs.getExamCountdowns(storage);
    this.backgroundPath = await WidgetPrefs.getBackground(storage);
    this.backgroundOpacity = await WidgetPrefs.getBackgroundOpacity(storage);
    this.theme = await WidgetPrefs.getTheme(storage);
    this.snapshot = await WidgetData.build(storage, this.systemDark());
    // 后台同步一次考试倒计时，失败不影响页面。
    this.syncExamCountdowns(false);
  }

  private systemDark(): boolean {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return context.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch {
      return false;
    }
  }

  /** 从教务同步考试安排，写进卡片数据源。 */
  private async syncExamCountdowns(toast: boolean): Promise<void> {
    const storage = AppStorage.getInstance();
    try {
      let term = await storage.getSemester();
      if (!term) term = await storage.getSelectSemester();
      const exams: CountdownItem[] = await CountdownApi.listExams(term);
      const items: WidgetCountdownItem[] = [];
      for (let i = 0; i < exams.length; i++) {
        const exam = exams[i];
        if (!exam.name || !exam.time) continue;
        const detailParts: string[] = [];
        if (exam.examType) detailParts.push(exam.examType);
        if (exam.location) detailParts.push(exam.location);
        if (exam.seatNumber) detailParts.push(`座位 ${exam.seatNumber}`);
        items.push({ title: exam.name, date: exam.time, detail: detailParts.join(' · ') });
      }
      await WidgetPrefs.setExamCountdowns(storage, items);
      this.examCountdowns = items;
      if (toast) {
        promptAction.showToast({ message: items.length > 0 ? `已同步 ${items.length} 场考试` : '暂未查到考试安排', duration: 1800 });
      }
    } catch (error) {
      console.warn(TAG, `sync exams failed: ${JSON.stringify(error)}`);
      if (toast) {
        promptAction.showToast({ message: '考试安排同步失败，请稍后重试', duration: 1800 });
      }
    }
  }

  private async refreshPublishedCount(): Promise<void> {
    try {
      const infos: formInfo.RunningFormInfo[] = await formProvider.getPublishedRunningFormInfos();
      this.publishedCount = infos.length;
    } catch (error) {
      console.warn(TAG, `get published forms failed: ${JSON.stringify(error)}`);
      this.publishedCount = 0;
    }
  }

  /** 重新生成卡片数据并刷新所有已添加的卡片。 */
  private async refreshWidgets(showToast: boolean = true): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    const storage = AppStorage.getInstance();
    try {
      this.snapshot = await WidgetData.build(storage, this.systemDark());
      const infos: formInfo.RunningFormInfo[] = await formProvider.getPublishedRunningFormInfos();
      this.publishedCount = infos.length;
      if (infos.length === 0) {
        if (showToast) {
          promptAction.showToast({ message: '还没有添加小组件，请先点“添加小组件”', duration: 2200 });
        }
        return;
      }
      const data = formBindingData.createFormBindingData(this.snapshot);
      let updated = 0;
      for (let i = 0; i < infos.length; i++) {
        try {
          await formProvider.updateForm(infos[i].formId, data);
          updated++;
        } catch (error) {
          console.warn(TAG, `update form ${infos[i].formId} failed: ${JSON.stringify(error)}`);
        }
      }
      if (showToast) {
        promptAction.showToast({ message: `已刷新 ${updated} 个小组件`, duration: 1800 });
      }
    } catch (error) {
      console.warn(TAG, `refresh widgets failed: ${JSON.stringify(error)}`);
      if (showToast) {
        promptAction.showToast({ message: '刷新小组件失败，请稍后重试', duration: 1800 });
      }
    } finally {
      this.busy = false;
    }
  }

  private async selectTab(index: number): Promise<void> {
    this.selectedTab = index;
    await WidgetPrefs.setMode(AppStorage.getInstance(), TAB_MODES[index]);
    await this.refreshWidgets(false);
  }

  private async selectAccent(color: string): Promise<void> {
    this.accent = color;
    await WidgetPrefs.setAccent(AppStorage.getInstance(), color);
    await this.refreshWidgets(false);
  }

  private openAddWidget(): void {
    try {
      formProvider.openFormManager({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: 'EntryFormAbility'
      });
      // 管理页关闭后用户可能已经添加了卡片，延迟同步一次数量。
      setTimeout(() => this.refreshPublishedCount(), 1500);
    } catch (error) {
      console.warn(TAG, `open form manager failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '当前系统不支持小组件管理页，请长按桌面空白处添加', duration: 2600 });
    }
  }

  // ── 外观：主题 / 背景 / 不透明度 ──

  private themeIndexValue(): number {
    const index = THEME_VALUES.indexOf(this.theme);
    return index >= 0 ? index : 0;
  }

  private themeLabel(): string {
    return THEME_LABELS[this.themeIndexValue()];
  }

  private pickTheme(): void {
    TextPickerDialog.show({
      range: THEME_LABELS,
      selected: this.themeIndexValue(),
      onAccept: (result: TextPickerResult) => {
        const index = result.index as number;
        const value = THEME_VALUES[index];
        if (!value) return;
        this.theme = value;
        WidgetPrefs.setTheme(AppStorage.getInstance(), value).then(() => this.refreshWidgets(false));
      }
    });
  }

  private themeColors(): string[] {
    const dark = this.theme === WIDGET_THEME_DARK || (this.theme === WIDGET_THEME_SYSTEM && this.systemDark());
    return dark ? ['#1C1C1E', '#FFFFFF', '#B9BDC6'] : ['#FFFFFF', '#111111', '#666666'];
  }

  private async chooseBackground(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      if (!result.photoUris || result.photoUris.length === 0) return;
      this.cropImageUri = result.photoUris[0];
      await this.loadCropImageSize(this.cropImageUri);
      this.resetCrop();
      this.showingCropper = true;
    } catch (error) {
      console.warn(TAG, `choose background failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '选择图片失败', duration: 1500 });
    }
  }

  private async loadCropImageSize(uri: string): Promise<void> {
    try {
      const source = image.createImageSource(uri);
      const info = await source.getImageInfo();
      this.cropImageWidth = info.size.width;
      this.cropImageHeight = info.size.height;
      source.release();
    } catch (error) {
      console.warn(TAG, `read background size failed: ${JSON.stringify(error)}`);
      this.cropImageWidth = 0;
      this.cropImageHeight = 0;
    }
  }

  private resetCrop(): void {
    this.cropScale = 1;
    this.cropOffsetX = 0;
    this.cropOffsetY = 0;
  }

  private cancelCrop(): void {
    this.showingCropper = false;
    this.cropImageUri = '';
    this.resetCrop();
  }

  /** Cover 填充后图片的基础宽高，按 2:1 裁剪框计算。 */
  private cropBaseWidth(): number {
    if (this.cropImageWidth <= 0 || this.cropImageHeight <= 0) return CROP_WIDTH;
    return CROP_WIDTH * Math.max(1, this.cropImageWidth / this.cropImageHeight);
  }

  private cropBaseHeight(): number {
    if (this.cropImageWidth <= 0 || this.cropImageHeight <= 0) return CROP_HEIGHT;
    return CROP_HEIGHT * Math.max(1, this.cropImageHeight / this.cropImageWidth);
  }

  private cropPanLimitX(): number {
    return Math.max(0, (this.cropBaseWidth() * this.cropScale - CROP_WIDTH) / 2);
  }

  private cropPanLimitY(): number {
    return Math.max(0, (this.cropBaseHeight() * this.cropScale - CROP_HEIGHT) / 2);
  }

  private applyCropPan(offsetX: number, offsetY: number): void {
    const limitX = this.cropPanLimitX();
    const limitY = this.cropPanLimitY();
    this.cropOffsetX = Math.min(limitX, Math.max(-limitX, this.cropStartOffsetX + offsetX));
    this.cropOffsetY = Math.min(limitY, Math.max(-limitY, this.cropStartOffsetY + offsetY));
  }

  private applyCropScale(scale: number): void {
    this.cropScale = Math.min(4, Math.max(1, scale));
    const limitX = this.cropPanLimitX();
    const limitY = this.cropPanLimitY();
    this.cropOffsetX = Math.min(limitX, Math.max(-limitX, this.cropOffsetX));
    this.cropOffsetY = Math.min(limitY, Math.max(-limitY, this.cropOffsetY));
  }

  private async confirmCrop(): Promise<void> {
    if (!this.cropImageUri || this.cropperBusy) return;
    this.cropperBusy = true;
    try {
      const snapshot = await this.getUIContext().getComponentSnapshot().get('widgetCropBox');
      this.showingCropper = false;
      const packer = image.createImagePacker();
      const options: image.PackingOption = { format: 'image/jpeg', quality: 92 };
      const buffer = await packer.packing(snapshot, options);
      const context = getContext(this) as common.UIAbilityContext;
      const path = `${context.filesDir}/widget_bg.jpg`;
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, buffer);
      } finally {
        fileIo.closeSync(file);
      }
      const stored = `file://${path}`;
      this.backgroundPath = stored;
      await WidgetPrefs.setBackground(AppStorage.getInstance(), stored);
      await this.refreshWidgets(false);
      promptAction.showToast({ message: '背景已更新', duration: 1500 });
    } catch (error) {
      console.warn(TAG, `set background failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '设置背景失败，请重试', duration: 1500 });
    } finally {
      this.cropperBusy = false;
      this.cropImageUri = '';
      this.resetCrop();
    }
  }

  private async clearBackground(): Promise<void> {
    this.backgroundPath = '';
    await WidgetPrefs.setBackground(AppStorage.getInstance(), '');
    await this.refreshWidgets(false);
  }

  private async changeOpacity(value: number): Promise<void> {
    this.backgroundOpacity = value;
    await WidgetPrefs.setBackgroundOpacity(AppStorage.getInstance(), value);
    await this.refreshWidgets(false);
  }

  private pickDate(): void {
    const today = new Date();
    const oneYearLater = new Date(today.getFullYear() + 2, today.getMonth(), today.getDate());
    DatePickerDialog.show({
      start: today,
      end: oneYearLater,
      selected: today,
      onDateAccept: (value: Date) => {
        const month = value.getMonth() + 1;
        const day = value.getDate();
        this.countdownDate = `${value.getFullYear()}-${month < 10 ? '0' + month : month}-${day < 10 ? '0' + day : day}`;
      }
    });
  }

  private async addCountdown(): Promise<void> {
    const title = this.countdownTitle.trim();
    if (title.length === 0) {
      promptAction.showToast({ message: '请填写倒计时名称', duration: 1600 });
      return;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(this.countdownDate)) {
      promptAction.showToast({ message: '请选择目标日期', duration: 1600 });
      return;
    }
    const items: WidgetCountdownItem[] = [];
    for (let i = 0; i < this.countdowns.length; i++) items.push(this.countdowns[i]);
    items.push({ title: title, date: this.countdownDate });
    await WidgetPrefs.setCountdowns(AppStorage.getInstance(), items);
    this.countdowns = items;
    this.countdownTitle = '';
    this.countdownDate = '';
    this.addOpen = false;
    await this.refreshWidgets(false);
    promptAction.showToast({ message: '已添加倒计时', duration: 1600 });
  }

  private async removeCountdown(index: number): Promise<void> {
    const items: WidgetCountdownItem[] = [];
    for (let i = 0; i < this.countdowns.length; i++) {
      if (i !== index) items.push(this.countdowns[i]);
    }
    await WidgetPrefs.setCountdowns(AppStorage.getInstance(), items);
    this.countdowns = items;
    await this.refreshWidgets(false);
  }

  private backgroundSource(): string {
    return this.backgroundPath;
  }

  @Builder
  private appearanceRow(title: string, value: string, showArrow: boolean, action: () => void) {
    Row() {
      Text(title).fontSize(16).fontColor('#222222').layoutWeight(1)
      if (value.length > 0) {
        Text(value).fontSize(14).fontColor('#999999').margin({ right: 6 })
      }
      if (showArrow) {
        Image($r('app.media.ic_arrow_right')).width(18).height(18).fillColor('#BBBBBB')
      }
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
    .onClick(action)
  }

  @Builder
  private previewCard() {
    Stack() {
      Row().width('100%').height('100%').backgroundColor(this.themeColors()[0])
      if (this.backgroundPath.length > 0) {
        Image(this.backgroundSource())
          .width('100%').height('100%').objectFit(ImageFit.Cover)
          .opacity(this.backgroundOpacity)
      }
      Column() {
        Row() {
          Blank()
          Image($r('app.media.setting')).width(24).height(24).fillColor(this.themeColors()[2])
            .onClick(() => { this.addOpen = true; })
          Image($r('app.media.refresh')).width(24).height(24).fillColor(this.themeColors()[2])
            .margin({ left: 8, right: 8 })
            .onClick(() => { this.refreshWidgets(true); })
          Image($r('app.media.add')).width(24).height(24).fillColor(this.themeColors()[2])
            .onClick(() => { this.addOpen = true; })
        }
        .width('100%')
        .height(36)

        Row() {
          Column() {
            Text(this.snapshot?.title ?? '考试倒计时')
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.themeColors()[1])
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            if (this.selectedTab === 0) {
              Text(this.snapshot?.subtitle ?? '还没有考试安排')
                .fontSize(13).fontColor(this.accent).margin({ top: 6 }).width('100%')
              Text(this.snapshot?.line0 ?? '')
                .fontSize(12).fontColor(this.themeColors()[2]).margin({ top: 6 }).width('100%')
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.selectedTab === 0) {
            Column() {
              Text(this.snapshot?.days && this.snapshot.days.length > 0 ? this.snapshot.days : '—')
                .fontSize(46).fontWeight(FontWeight.Bold).fontColor(this.accent)
              Text('天').fontSize(12).fontColor(this.themeColors()[2])
            }
            .width(84)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        if (this.selectedTab !== 0) {
          Column() {
            Text(this.snapshot?.line0 ?? '').fontSize(12).fontColor(this.themeColors()[2]).width('100%')
            Text(this.snapshot?.line1 ?? '').fontSize(12).fontColor(this.themeColors()[2]).width('100%').margin({ top: 4 })
            Text(this.snapshot?.line2 ?? '').fontSize(12).fontColor(this.themeColors()[2]).width('100%').margin({ top: 4 })
            Text(this.snapshot?.line3 ?? '').fontSize(12).fontColor(this.themeColors()[2]).width('100%').margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 6 })
        }
      }
      .width('100%')
      .height('100%')
      .padding(16)
    }
    .width('100%')
    .aspectRatio(2)
    .borderRadius(14)
    .clip(true)
    .border({ width: 1, color: '#E4E4E4' })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_left')).width(27).height(27).fillColor('#222222').onClick(() => router.back())
          Text('小组件设置').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#222222').margin({ left: 17 })
          Blank()
          Image($r('app.media.help')).width(29).height(29).fillColor('#777777')
            .onClick(() => { this.helpOpen = true; })
        }.width('100%').height(70).padding({ left: 18, right: 20 }).backgroundColor('#FFFFFF')

        Row() {
          ForEach(WIDGET_TABS, (tab: string, index: number) => {
            Column() {
              Text(tab).fontSize(17).fontWeight(FontWeight.Bold)
                .fontColor(this.selectedTab === index ? '#20C997' : '#111111')
                .height(52).textAlign(TextAlign.Center)
              Divider().strokeWidth(3).color(this.selectedTab === index ? '#20C997' : '#FFFFFF')
            }.layoutWeight(1).onClick(() => { this.selectTab(index); })
          })
        }.width('100%').height(56).backgroundColor('#FFFFFF')

        Scroll() {
          Column() {
            Text('效果预览').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#A7ABB3')
              .width('100%').margin({ bottom: 10 })
            this.previewCard()

            Button(`添加小组件到桌面（已添加 ${this.publishedCount} 个）`)
              .width('100%').height(46).fontSize(15).fontColor(Color.White)
              .backgroundColor('#20C997').borderRadius(10)
              .margin({ top: 16 })
              .onClick(() => this.openAddWidget())

            Text('倒计时').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#A7ABB3')
              .width('100%').margin({ top: 22, bottom: 8 })
            Column() {
              if (this.countdowns.length === 0) {
                Text('还没有倒计时，点击下方按钮添加')
                  .fontSize(14).fontColor('#999999').padding(16)
              }
              ForEach(this.countdowns, (item: WidgetCountdownItem, index: number) => {
                Row() {
                  Column() {
                    Text(item.title).fontSize(16).fontColor('#222222')
                    Text(item.date).fontSize(12).fontColor('#999999').margin({ top: 3 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text('删除').fontSize(14).fontColor('#E5484D')
                    .onClick(() => { this.removeCountdown(index); })
                }
                .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                Divider().color('#F0F0F0')
              }, (item: WidgetCountdownItem, index: number) => `${index}-${item.title}-${item.date}`)
            }
            .width('100%').backgroundColor('#FFFFFF').borderRadius(13).clip(true)

            Button('添加倒计时')
              .width('100%').height(46).fontSize(15).fontColor('#20C997')
              .backgroundColor('#FFFFFF').borderRadius(10)
              .border({ width: 1, color: '#20C997' })
              .margin({ top: 12 })
              .onClick(() => { this.addOpen = true })

            Text('考试倒计时').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#A7ABB3')
              .width('100%').margin({ top: 22, bottom: 8 })
            Column() {
              Row() {
                Text(this.examCountdowns.length > 0 ? `已同步 ${this.examCountdowns.length} 场考试，卡片按小时轮换显示` : '还没有同步考试安排')
                  .fontSize(14).fontColor('#666666').layoutWeight(1)
                Text('同步').fontSize(14).fontColor('#20C997')
                  .onClick(() => { this.syncExamCountdowns(true).then(() => this.refreshWidgets(false)); })
              }
              .width('100%').padding(16)
              Divider().color('#F0F0F0')
              ForEach(this.examCountdowns.slice(0, 3), (item: WidgetCountdownItem, index: number) => {
                Column() {
                  Text(item.title).fontSize(15).fontColor('#222222').width('100%')
                  Text(item.date).fontSize(12).fontColor('#999999').margin({ top: 3 }).width('100%')
                }
                .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
              }, (item: WidgetCountdownItem, index: number) => `exam-${index}-${item.title}`)
            }
            .width('100%').backgroundColor('#FFFFFF').borderRadius(13).clip(true)

            Text('外观').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#A7ABB3')
              .width('100%').margin({ top: 22, bottom: 8 })
            Column() {
              this.appearanceRow('自定义背景', this.backgroundPath.length > 0 ? '已设置' : '', true, () => {
                this.chooseBackground();
              })
              Divider().color('#F0F0F0').margin({ left: 16 })
              this.appearanceRow('默认主题', this.themeLabel(), true, () => {
                this.pickTheme();
              })
              Divider().color('#F0F0F0').margin({ left: 16 })
              this.appearanceRow('标题颜色', '默认', true, () => {
                promptAction.showToast({ message: '标题颜色将在后续版本开放', duration: 1600 });
              })
              Divider().color('#F0F0F0').margin({ left: 16 })
              Row() {
                Text('不透明度').fontSize(16).fontColor('#222222').width(110)
                Slider({
                  value: Math.round(this.backgroundOpacity * 100),
                  min: 20,
                  max: 100,
                  step: 1,
                  style: SliderStyle.OutSet
                })
                  .layoutWeight(1)
                  .selectedColor('#20C997')
                  .onChange((value: number) => {
                    this.changeOpacity(value / 100);
                  })
                Text(`${Math.round(this.backgroundOpacity * 100)}%`)
                  .fontSize(15).fontColor('#20C997').width(56).textAlign(TextAlign.End)
              }
              .width('100%').height(58).padding({ left: 16, right: 16 })
              if (this.backgroundPath.length > 0) {
                Divider().color('#F0F0F0').margin({ left: 16 })
                this.appearanceRow('清除背景', '', true, () => { this.clearBackground(); })
              }
            }
            .width('100%').backgroundColor('#FFFFFF').borderRadius(13).clip(true)

            Text('提示：不透明度只影响背景图片，不影响文字；“跟随系统”主题会随系统深浅色切换。修改后点预览右上角刷新按钮即可同步到桌面。')
              .fontSize(12).fontColor('#999999').lineHeight(18)
              .width('100%').margin({ top: 16, bottom: 30 })
          }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 30 })
        }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8')
      }.width('100%').height('100%').backgroundColor('#FFFFFF')

      if (this.addOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => { this.addOpen = false; })

        Column() {
          Text('添加倒计时')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
            .width('100%').textAlign(TextAlign.Center).margin({ bottom: 18 })
          TextInput({ placeholder: '名称，例如：放寒假', text: this.countdownTitle })
            .width('100%').height(46)
            .onChange((value: string) => { this.countdownTitle = value; })
          Row() {
            Text(this.countdownDate.length > 0 ? this.countdownDate : '选择目标日期')
              .fontSize(15).fontColor(this.countdownDate.length > 0 ? '#333333' : '#999999')
              .layoutWeight(1)
            Text('选择').fontSize(14).fontColor('#20C997').onClick(() => this.pickDate())
          }
          .width('100%').height(46).padding({ left: 12, right: 12 })
          .backgroundColor('#F5F6F8').borderRadius(8).margin({ top: 12 })

          Row() {
            Button('取消')
              .layoutWeight(1).height(44).fontSize(16).fontColor('#666666')
              .backgroundColor('#F0F0F0').borderRadius(8)
              .onClick(() => { this.addOpen = false; })
            Button('添加')
              .layoutWeight(1).height(44).fontSize(16).fontColor(Color.White)
              .backgroundColor('#20C997').borderRadius(8)
              .margin({ left: 12 })
              .onClick(() => { this.addCountdown(); })
          }.width('100%').margin({ top: 22 })
        }
        .width('80%')
        .padding(22)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
      }

      if (this.showingCropper) {
        Column() {
          Row() {
            Text('×').fontSize(40).fontColor('#111111').width(60).textAlign(TextAlign.Center)
              .onClick(() => this.cancelCrop())
            Text('裁剪背景').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#111111').layoutWeight(1)
            Text('✓').fontSize(38).fontColor('#111111').width(60).textAlign(TextAlign.Center)
              .onClick(() => this.confirmCrop())
          }
          .width('100%').height(80).padding({ left: 8, right: 8 })

          Stack({ alignContent: Alignment.Center }) {
            Column().width(CROP_WIDTH).height(CROP_HEIGHT).backgroundColor('#111111')
            Image(this.cropImageUri)
              .width(this.cropBaseWidth() * this.cropScale)
              .height(this.cropBaseHeight() * this.cropScale)
              .objectFit(ImageFit.Fill)
              .translate({ x: this.cropOffsetX, y: this.cropOffsetY })
          }
          .width(CROP_WIDTH)
          .height(CROP_HEIGHT)
          .clip(true)
          .id('widgetCropBox')
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  this.cropStartOffsetX = this.cropOffsetX;
                  this.cropStartOffsetY = this.cropOffsetY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.applyCropPan(event.offsetX, event.offsetY);
                }),
              PinchGesture({ fingers: 2 })
                .onActionUpdate((event: GestureEvent) => {
                  this.applyCropScale(event.scale);
                })
            )
          )
          .borderRadius(8)

          Text('拖动调整位置，双指缩放；卡片比例为 2:1')
            .fontSize(13).fontColor('#888888').margin({ top: 18 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#F5F5F5')
        .justifyContent(FlexAlign.Start)
      }

      if (this.helpOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => { this.helpOpen = false; })

        Column() {
          Text('小组件设置说明')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#555555')
            .width('100%').textAlign(TextAlign.Center).margin({ bottom: 18 })
          Text('1. 倒计时卡片展示教务同步的考试安排；多场考试时按小时轮换。')
            .fontSize(15).fontColor('#777777').lineHeight(24).width('100%').margin({ bottom: 14 })
          Text('2. 点击“添加小组件到桌面”可打开系统小组件管理页，选择 4×2 卡片。')
            .fontSize(15).fontColor('#777777').lineHeight(24).width('100%').margin({ bottom: 14 })
          Text('3. 自定义背景会按卡片比例裁剪；不透明度只影响背景图片，不影响文字。')
            .fontSize(15).fontColor('#777777').lineHeight(24).width('100%').margin({ bottom: 20 })
          Button('知道了')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .width(140).height(46).backgroundColor('#20C997').borderRadius(8)
            .onClick(() => { this.helpOpen = false; })
        }
        .width('80%')
        .padding(24)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
      }
    }.width('100%').height('100%')
  }
}
