import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';

interface ToolEntry { title: string; desc: string; icon: Resource; enabled: boolean; }

@Entry
@Component
struct EditToolsPage {
  @State private enabledTools: ToolEntry[] = [];
  @State private disabledTools: ToolEntry[] = [];
  @State private draggingIndex: number = -1;
  private allTools: ToolEntry[] = [
    { title: '校车时刻', desc: '发车时间查询', icon: $r('app.media.ic_school_bus'), enabled: true },
    { title: '学校校历', desc: '了解假期安排', icon: $r('app.media.ic_schoolcalendar'), enabled: true },
    { title: '物理实验', desc: '导入实验课表', icon: $r('app.media.ic_physical'), enabled: true },
    { title: '校园黄页', desc: '号码通讯录', icon: $r('app.media.ic_yellow_page'), enabled: true },
    { title: '饮水机', desc: '扫码取水与结算', icon: $r('app.media.water_dispenser'), enabled: true },
    { title: '查电费', desc: '寝室剩余电量', icon: $r('app.media.electricity_bill'), enabled: true }
  ];

  async aboutToAppear(): Promise<void> {
    const raw = await AppStorage.getInstance().getSettingString('toolLayout', '');
    if (raw.length > 0) {
      try {
        const order = JSON.parse(raw) as string[];
        this.allTools.sort((a: ToolEntry, b: ToolEntry) => order.indexOf(a.title) - order.indexOf(b.title));
      } catch { /* 使用默认顺序 */ }
    }
    this.refreshLists();
  }

  @Builder private toolCard(item: ToolEntry) {
    Row() {
      Column() {
        Text(item.title).fontSize(18).fontWeight(FontWeight.Bold).maxLines(1)
        Text(item.desc).fontSize(11).fontColor('#777777').maxLines(1).margin({ top: 4 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Image(item.icon).width(54).height(54).objectFit(ImageFit.Contain)
    }.width('100%').height(100).padding({ left: 12, right: 12 }).backgroundColor(Color.White).borderRadius(12)
      .onClick(() => { if (this.draggingIndex < 0) this.openTool(item.title); })
      .gesture(LongPressGesture().onAction(() => {
        this.draggingIndex = this.allTools.findIndex((tool: ToolEntry) => tool.title === item.title);
      }))
      .parallelGesture(PanGesture().onActionUpdate((event: GestureEvent) => {
        if (this.draggingIndex < 0 || Math.abs(event.offsetY) < 36) return;
        const from = this.draggingIndex;
        const enabledCount = this.enabledTools.length;
        const delta = event.offsetY > 0 ? 1 : -1;
        const to = Math.max(0, Math.min(this.allTools.length - 1, from + delta));
        if (to !== from) {
          const moved = this.allTools.splice(from, 1)[0];
          moved.enabled = to < enabledCount;
          this.allTools.splice(to, 0, moved);
          this.draggingIndex = to;
          this.refreshLists();
        }
      }).onActionEnd(() => { if (this.draggingIndex >= 0) { this.saveLayout(); this.draggingIndex = -1; } }))
  }

  private refreshLists(): void {
    this.enabledTools = this.allTools.filter((item: ToolEntry) => item.enabled);
    this.disabledTools = this.allTools.filter((item: ToolEntry) => !item.enabled);
  }

  private async saveLayout(): Promise<void> {
    const enabled = this.allTools.filter((item: ToolEntry) => item.enabled).map((item: ToolEntry) => item.title);
    await AppStorage.getInstance().setSettingString('toolLayout', JSON.stringify(enabled));
  }

  private toggle(title: string): void {
    for (let i = 0; i < this.allTools.length; i++) {
      if (this.allTools[i].title === title) this.allTools[i].enabled = !this.allTools[i].enabled;
    }
    this.refreshLists();
    this.saveLayout();
  }

  private openTool(title: string): void {
    const routes: Record<string, string> = {
      '校车时刻': 'pages/campus/SchoolBusPage', '学校校历': 'pages/campus/SchoolCalendarPage',
      '物理实验': 'pages/course/PhysicalExperimentPage', '校园黄页': 'pages/campus/YellowPagesPage',
      '饮水机': 'pages/main/WaterDispenserPage', '查电费': 'pages/main/ElectricityPage'
    };
    const target = routes[title];
    if (target !== undefined) router.pushUrl({ url: target });
  }

  build() {
    Column() {
      Row() { Text('‹').fontSize(38).onClick(() => router.back()); Text('编辑小工具').fontSize(24).fontWeight(FontWeight.Bold).margin({ left: 14 }); }.width('100%').height(76).padding({ left: 22 }).backgroundColor('#F5F6F8')
      Scroll() { Column() {
        Text('已启用').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#666666').width('100%').margin({ bottom: 8 })
        Text('单击可直接打开；点击卡片移入未启用').fontSize(15).fontColor('#AAB1BC').width('100%').margin({ bottom: 14 })
        Grid() { ForEach(this.enabledTools, (item: ToolEntry) => GridItem() { this.toolCard(item) }); }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width('100%')
        Divider().margin({ top: 26, bottom: 22 })
        Text('未启用').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#666666').width('100%').margin({ bottom: 14 })
        Grid() { ForEach(this.disabledTools, (item: ToolEntry) => GridItem() { this.toolCard(item) }); }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width('100%')
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 18 }).alignItems(HorizontalAlign.Start) }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start).backgroundColor('#F5F6F8')
  }
}

