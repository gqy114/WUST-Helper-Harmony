import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';

interface ToolEntry { title: string; desc: string; icon: Resource; enabled: boolean; }

@Entry
@Component
struct EditToolsPage {
  @State private enabledTools: ToolEntry[] = [];
  @State private disabledTools: ToolEntry[] = [];
  @State private draggingIndex: number = -1;
  @State private draggingTitle: string = '';
  @State private dragOffsetX: number = 0;
  @State private dragOffsetY: number = 0;
  @State private dragScale: number = 1;
  private dragAnchorX: number = 0;
  private dragAnchorY: number = 0;
  private allTools: ToolEntry[] = [
    { title: '校车时刻', desc: '发车时间查询', icon: $r('app.media.ic_school_bus'), enabled: true },
    { title: '学校校历', desc: '了解假期安排', icon: $r('app.media.ic_schoolcalendar'), enabled: true },
    { title: '物理实验', desc: '导入实验课表', icon: $r('app.media.ic_physical'), enabled: true },
    { title: '校园黄页', desc: '号码通讯录', icon: $r('app.media.ic_yellow_page'), enabled: true },
    { title: '查电费', desc: '寝室剩余电量', icon: $r('app.media.electricity_bill'), enabled: true },
    { title: '第二课堂', desc: '素质发展学分', icon: $r('app.media.second_classroom'), enabled: true },
    { title: '饮水机', desc: '扫码取水与结算', icon: $r('app.media.water_dispenser'), enabled: false }
  ];

  async aboutToAppear(): Promise<void> {
    const storage = AppStorage.getInstance();
    const raw = await storage.getSettingString('toolLayout', '');
    const fullRaw = await storage.getSettingString('toolFullLayout', '');
    if (fullRaw.length > 0) {
      try {
        const fullOrder = JSON.parse(fullRaw) as string[];
        this.allTools.sort((a: ToolEntry, b: ToolEntry) => {
          const ai = fullOrder.indexOf(a.title);
          const bi = fullOrder.indexOf(b.title);
          return (ai < 0 ? 999 : ai) - (bi < 0 ? 999 : bi);
        });
      } catch { /* 使用默认顺序 */ }
    }
    if (raw.length > 0) {
      try {
        const order = JSON.parse(raw) as string[];
        for (let i = 0; i < this.allTools.length; i++) this.allTools[i].enabled = order.indexOf(this.allTools[i].title) >= 0;
        if (fullRaw.length === 0) this.allTools.sort((a: ToolEntry, b: ToolEntry): number => {
          const ai = order.indexOf(a.title);
          const bi = order.indexOf(b.title);
          return (ai < 0 ? 999 : ai) - (bi < 0 ? 999 : bi);
        });
      } catch { /* 使用默认顺序 */ }
    }
    this.refreshLists();
  }

  @Builder private toolCard(item: ToolEntry) {
    Row() {
      Column() {
        Text(item.title).fontSize(18).fontWeight(FontWeight.Bold).maxLines(1).draggable(false)
        Text(item.desc).fontSize(11).fontColor('#777777').maxLines(1).margin({ top: 4 }).draggable(false)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).draggable(false)
      Image(item.icon).width(54).height(54).objectFit(ImageFit.Contain).draggable(false)
    }.width('100%').height(100).padding({ left: 12, right: 12 }).backgroundColor(Color.White).borderRadius(12)
      .draggable(false)
      .translate({ x: this.draggingTitle === item.title ? this.dragOffsetX : 0, y: this.draggingTitle === item.title ? this.dragOffsetY : 0 })
      .scale({ x: this.draggingTitle === item.title ? this.dragScale : 1, y: this.draggingTitle === item.title ? this.dragScale : 1 })
      .opacity(this.draggingTitle === item.title ? 0.94 : 1)
      .shadow(this.draggingTitle === item.title ? { radius: 24, color: '#33000000', offsetX: 0, offsetY: 10 } : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
      .zIndex(this.draggingTitle === item.title ? 20 : 0)
      .animation({ duration: 180, curve: Curve.EaseOut })
      .onClick(() => { if (this.draggingIndex < 0) this.openTool(item.title); })
      .gesture(GestureGroup(GestureMode.Sequence,
        LongPressGesture().onAction(() => {
          this.draggingIndex = this.allTools.findIndex((tool: ToolEntry) => tool.title === item.title);
          this.draggingTitle = item.title;
          this.dragOffsetX = 0;
          this.dragOffsetY = 0;
          this.dragScale = 1.06;
          this.dragAnchorX = 0;
          this.dragAnchorY = 0;
        }),
        PanGesture().onActionUpdate((event: GestureEvent) => {
          if (this.draggingIndex < 0) return;
          const moveX = event.offsetX - this.dragAnchorX;
          const moveY = event.offsetY - this.dragAnchorY;
          this.dragOffsetX = moveX;
          this.dragOffsetY = moveY;
          let delta = 0;
          if (Math.abs(moveY) >= 56) delta = moveY > 0 ? 2 : -2;
          else if (Math.abs(moveX) >= 70) delta = moveX > 0 ? 1 : -1;
          if (delta === 0) return;
          const from = this.draggingIndex;
          const enabledCount = this.enabledTools.length;
          const to = Math.max(0, Math.min(this.allTools.length, from + delta));
          if (to !== from) {
            const moved = this.allTools.splice(from, 1)[0];
            moved.enabled = to < enabledCount;
            const insertAt = Math.min(to, this.allTools.length);
            this.allTools.splice(insertAt, 0, moved);
            this.draggingIndex = insertAt;
            this.dragAnchorX = event.offsetX;
            this.dragAnchorY = event.offsetY;
            this.dragOffsetX = 0;
            this.dragOffsetY = 0;
            animateTo({ duration: 220, curve: Curve.EaseOut }, () => this.refreshLists());
          }
        }).onActionEnd(() => this.finishDragging(true))
          .onActionCancel(() => this.finishDragging(false))
      ))
  }

  private finishDragging(save: boolean): void {
    if (this.draggingIndex < 0) return;
    if (save) this.saveLayout();
    animateTo({ duration: 220, curve: Curve.EaseOut, onFinish: () => {
      this.draggingIndex = -1;
      this.draggingTitle = '';
    } }, () => {
      this.dragOffsetX = 0;
      this.dragOffsetY = 0;
      this.dragScale = 1;
    });
  }

  private refreshLists(): void {
    this.enabledTools = this.allTools.filter((item: ToolEntry) => item.enabled);
    this.disabledTools = this.allTools.filter((item: ToolEntry) => !item.enabled);
  }

  private async saveLayout(): Promise<void> {
    const enabled = this.allTools.filter((item: ToolEntry) => item.enabled).map((item: ToolEntry) => item.title);
    const full = this.allTools.map((item: ToolEntry) => item.title);
    const storage = AppStorage.getInstance();
    await storage.setSettingString('toolLayout', JSON.stringify(enabled));
    await storage.setSettingString('toolFullLayout', JSON.stringify(full));
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
      '饮水机': 'pages/main/WaterDispenserPage', '查电费': 'pages/main/ElectricityPage',
      '第二课堂': 'pages/main/SecondClassroomPage'
    };
    const target = routes[title];
    if (target !== undefined) router.pushUrl({ url: target });
  }

  build() {
    Column() {
      Row() { Text('‹').fontSize(38).onClick(() => router.back()); Text('编辑小工具').fontSize(24).fontWeight(FontWeight.Bold).margin({ left: 14 }); }.width('100%').height(76).padding({ left: 22 }).backgroundColor('#F5F6F8')
      Scroll() { Column() {
        Text('已启用').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#666666').width('100%').margin({ bottom: 8 })
        Text('单击可直接打开；长按拖动排序或移入未启用').fontSize(15).fontColor('#AAB1BC').width('100%').margin({ bottom: 14 })
        Grid() { ForEach(this.enabledTools, (item: ToolEntry) => GridItem() { this.toolCard(item) }); }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width('100%')
        Divider().margin({ top: 26, bottom: 22 })
        Text('未启用').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#666666').width('100%').margin({ bottom: 14 })
        Grid() { ForEach(this.disabledTools, (item: ToolEntry) => GridItem() { this.toolCard(item) }); }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).width('100%')
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 18 }).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start) }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start).backgroundColor('#F5F6F8')
  }
}

