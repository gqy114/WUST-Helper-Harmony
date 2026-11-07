/**
 * 小组件设置页。
 *
 * 之前这个页面是纯静态预览：齿轮、刷新、加号、外观行都没有点击事件，
 * 也没有真正的桌面卡片，所以审核侧表现为“点击设置/刷新/添加无响应”。
 * 现在页面与 EntryFormAbility 共用 WidgetPrefs / WidgetData：
 *  - 设置：切换卡片内容类型、编辑倒计时
 *  - 刷新：重新生成数据并刷新所有已添加的卡片
 *  - 添加：打开系统小组件管理页
 */
import { promptAction, router } from '@kit.ArkUI';
import { formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { AppStorage } from '../../store/AppStorage';
import {
  WidgetCountdownItem,
  WidgetData,
  WidgetPrefs,
  WidgetSnapshot,
  WIDGET_MODE_COUNTDOWN,
  WIDGET_MODE_DAILY,
  WIDGET_MODE_WEEKLY
} from '../../widget/WidgetData';

const TAG = 'WidgetSettingsPage';
const WIDGET_TABS: string[] = ['倒计时', '每日课表', '每周课表'];
const TAB_MODES: string[] = [WIDGET_MODE_COUNTDOWN, WIDGET_MODE_DAILY, WIDGET_MODE_WEEKLY];
const ACCENT_COLORS: string[] = ['#1EC98D', '#3B82F6', '#F59E0B', '#EC4899', '#8B5CF6'];
const BUNDLE_NAME = 'wust.linghang.wusthelper';

@Entry
@Component
struct WidgetSettingsPage {
  @State private selectedTab: number = 0;
  @State private helpOpen: boolean = false;
  @State private addOpen: boolean = false;
  @State private countdownTitle: string = '';
  @State private countdownDate: string = '';
  @State private countdowns: WidgetCountdownItem[] = [];
  @State private snapshot: WidgetSnapshot | null = null;
  @State private accent: string = '#1EC98D';
  @State private publishedCount: number = 0;
  @State private busy: boolean = false;

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
    this.snapshot = await WidgetData.build(storage);
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
      this.snapshot = await WidgetData.build(storage);
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

  @Builder
  private toolbarIcon(label: string, action: () => void) {
    Text(label)
      .fontSize(24)
      .fontColor('#666666')
      .width(40)
      .height(40)
      .textAlign(TextAlign.Center)
      .onClick(action)
  }

  @Builder
  private previewCard() {
    Column() {
      Row() {
        Text(this.snapshot?.title ?? '梧桐助手')
          .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#111111')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        this.toolbarIcon('⚙', () => { this.addOpen = true; })
        Image($r('app.media.refresh')).width(24).height(24).fillColor('#666666')
          .margin({ left: 4, right: 4 })
          .onClick(() => { this.refreshWidgets(true); })
        this.toolbarIcon('+', () => { this.addOpen = true; })
      }
      .width('100%')
      .height(52)

      Text(this.snapshot?.subtitle ?? '还没有添加倒计时')
        .fontSize(13).fontColor(this.accent)
        .width('100%').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.selectedTab !== 0) {
        Column() {
          Text(this.snapshot?.line0 ?? '').fontSize(12).fontColor('#444444').width('100%')
          Text(this.snapshot?.line1 ?? '').fontSize(12).fontColor('#444444').width('100%').margin({ top: 4 })
          Text(this.snapshot?.line2 ?? '').fontSize(12).fontColor('#444444').width('100%').margin({ top: 4 })
          Text(this.snapshot?.line3 ?? '').fontSize(12).fontColor('#444444').width('100%').margin({ top: 4 })
        }
        .width('100%').alignItems(HorizontalAlign.Start).margin({ top: 10 })
      } else {
        Text(this.snapshot?.line0 ?? '')
          .fontSize(13).fontColor('#666666').width('100%').margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
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
                Text('还没有倒计时，点击右下角“添加倒计时”')
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

            Text('外观').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#A7ABB3')
              .width('100%').margin({ top: 22, bottom: 8 })
            Row() {
              ForEach(ACCENT_COLORS, (color: string) => {
                Stack() {
                  Circle().width(34).height(34).fill(color)
                  if (this.accent === color) {
                    Text('✓').fontSize(18).fontColor(Color.White).fontWeight(FontWeight.Bold)
                  }
                }
                .width(46).height(46)
                .onClick(() => { this.selectAccent(color); })
              })
            }
            .width('100%').padding(10).backgroundColor('#FFFFFF').borderRadius(13)

            Text('提示：小组件数据来自 App 内已保存的课表与倒计时。修改后点预览右上角的刷新按钮即可同步到桌面。')
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
          Text('1. 小组件展示倒计时或今日课表，数据来自 App 内已保存的内容。')
            .fontSize(15).fontColor('#777777').lineHeight(24).width('100%').margin({ bottom: 14 })
          Text('2. 点击“添加小组件到桌面”可打开系统小组件管理页。')
            .fontSize(15).fontColor('#777777').lineHeight(24).width('100%').margin({ bottom: 14 })
          Text('3. 修改设置后点预览卡片的刷新按钮即可同步到桌面。')
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
