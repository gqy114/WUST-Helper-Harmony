import router from '@ohos.router';

interface ToolEntry { title: string; desc: string; icon: Resource; enabled: boolean; }

@Entry
@Component
struct EditToolsPage {
  @State private enabledTools: ToolEntry[] = [];
  @State private disabledTools: ToolEntry[] = [];
  private allTools: ToolEntry[] = [
    { title: '校车时刻', desc: '发车时间查询', icon: $r('app.media.ic_school_bus'), enabled: true },
    { title: '学校校历', desc: '了解假期安排', icon: $r('app.media.ic_schoolcalendar'), enabled: true },
    { title: '物理实验', desc: '导入实验课表', icon: $r('app.media.ic_physical'), enabled: true },
    { title: '校园黄页', desc: '号码通讯录', icon: $r('app.media.ic_yellow_page'), enabled: true },
    { title: '饮水机', desc: '扫码取水与结算', icon: $r('app.media.water_dispenser'), enabled: true },
    { title: '查电费', desc: '寝室剩余电量', icon: $r('app.media.electricity_bill'), enabled: true }
  ];

  aboutToAppear(): void { this.enabledTools = this.allTools.filter((item: ToolEntry) => item.enabled); }

  @Builder private toolCard(item: ToolEntry) {
    Row() {
      Image(item.icon).width(54).height(54).objectFit(ImageFit.Contain)
      Column() { Text(item.title).fontSize(19).fontWeight(FontWeight.Bold); Text(item.desc).fontSize(14).fontColor('#777777').margin({ top: 4 }); }.alignItems(HorizontalAlign.Start).margin({ left: 16 })
    }.width('100%').height(112).padding({ left: 24 }).backgroundColor(Color.White).borderRadius(16)
      .onClick(() => this.toggle(item.title))
  }

  private toggle(title: string): void {
    const enabled: ToolEntry[] = []; const disabled: ToolEntry[] = [];
    for (let i = 0; i < this.allTools.length; i++) {
      const item = this.allTools[i];
      const next: ToolEntry = { title: item.title, desc: item.desc, icon: item.icon, enabled: item.title === title ? !item.enabled : item.enabled };
      this.allTools[i] = next;
      (next.enabled ? enabled : disabled).push(next);
    }
    this.enabledTools = enabled; this.disabledTools = disabled;
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
      }.width('100%').padding(18) }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F6F8')
  }
}
