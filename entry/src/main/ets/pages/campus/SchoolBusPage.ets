import router from '@ohos.router';

interface BusTime { hour: number; minute: number; }

@Entry
@Component
struct SchoolBusPage {
  @State private nowMinutes: number = 0;
  @State private showPicker: boolean = false;
  @State private fromCampus: string = '黄家湖校区';
  @State private toCampus: string = '青山校区';
  @State private dayType: string = '工作日';
  @State private appliedFrom: string = '黄家湖校区';
  @State private appliedTo: string = '青山校区';
  @State private appliedDay: string = '工作日';
  @State private availableDestinations: string[] = ['青山校区', '洪山校区'];
  @State private availableDays: string[] = ['工作日', '周末'];
  private campuses: string[] = ['黄家湖校区', '青山校区', '洪山校区'];
  private syncPickerOptions(): void {
    const destinations: string[] = [];
    for (const campus of this.campuses) {
      if (campus !== this.fromCampus) destinations.push(campus);
    }
    this.availableDestinations = destinations;
    const days: string[] = ['工作日'];
    if (this.fromCampus !== '洪山校区' && this.toCampus !== '洪山校区') days.push('周末');
    this.availableDays = days;
    if (days.length === 1) this.dayType = '工作日';
  }
  private normalizeDay(): void { this.syncPickerOptions(); }
  private timer: number = 0;
  private readonly schedules: Record<string, BusTime[]> = {
    '黄家湖校区-青山校区-工作日': [{hour:6,minute:40},{hour:10,minute:15},{hour:12,minute:10},{hour:16,minute:10},{hour:17,minute:0},{hour:17,minute:55},{hour:20,minute:50}],
    '黄家湖校区-青山校区-周末': [{hour:17,minute:0}],
    '青山校区-黄家湖校区-工作日': [{hour:6,minute:30},{hour:6,minute:50},{hour:8,minute:30},{hour:12,minute:50},{hour:14,minute:20},{hour:17,minute:30}],
    '青山校区-黄家湖校区-周末': [{hour:6,minute:50}],
    '黄家湖校区-洪山校区-工作日': [{hour:10,minute:15},{hour:12,minute:10},{hour:16,minute:10},{hour:17,minute:0},{hour:17,minute:55}],
    '洪山校区-黄家湖校区-工作日': [{hour:6,minute:30},{hour:6,minute:40},{hour:6,minute:50},{hour:8,minute:50},{hour:13,minute:0}],
    '洪山校区-青山校区-工作日': [{hour:7,minute:0},{hour:9,minute:10},{hour:13,minute:10},{hour:17,minute:20}],
    '青山校区-洪山校区-工作日': [{hour:7,minute:0},{hour:12,minute:0},{hour:16,minute:10},{hour:17,minute:20}]
  };
  private getBusTimes(): BusTime[] { const result = this.schedules[`${this.appliedFrom}-${this.appliedTo}-${this.appliedDay}`]; return result === undefined ? [] : result; }

  aboutToAppear(): void { this.refreshNow(); this.syncPickerOptions(); this.timer = setInterval(() => this.refreshNow(), 30000); }
  aboutToDisappear(): void { if (this.timer > 0) clearInterval(this.timer); }
  private refreshNow(): void { const d = new Date(); this.nowMinutes = d.getHours() * 60 + d.getMinutes(); }
  private formatTime(item: BusTime): string { return item.hour + ':' + (item.minute < 10 ? '0' : '') + item.minute; }
  private firstOtherCampus(current: string): string { for (const campus of this.campuses) { if (campus !== current) return campus; } return ''; }
  private isDeparted(item: BusTime): boolean { return this.nowMinutes >= item.hour * 60 + item.minute; }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
    Column() {
      Column() {
        Row() {
          Text('‹').fontSize(38).fontColor(Color.White).width(42).textAlign(TextAlign.Center).onClick(() => router.back());
          Text('校车').fontSize(25).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 12 });
        }.width('100%').padding({ left: 14, top: 22 });
        Row() {
          Column() {
            Text(`${this.appliedFrom.replace('校区', '')}  →  ${this.appliedTo.replace('校区', '')}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White).maxLines(1);
            Text(this.appliedDay === '周末' ? '周六至周日' : '周一至周五').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ top: 12 });
          }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          Image($r('app.media.schoolbus')).width(112).height(76).objectFit(ImageFit.Contain);
        }.width('100%').padding({ left: 58, right: 34, top: 24, bottom: 30 });
      }.width('100%').backgroundColor('#20C894').onClick(() => { animateTo({ duration: 260, curve: Curve.EaseOut }, () => { this.showPicker = true; }); });
      Scroll() {
        Stack({ alignContent: Alignment.TopStart }) {
          Divider().vertical(true).strokeWidth(1).color('#DADADA').height(Math.max(40, this.getBusTimes().length * 82 - 42)).margin({ left: 57, top: 41 });
          Column() { ForEach(this.getBusTimes(), (item: BusTime) => {
            Row() {
              Text('●').fontSize(16).fontColor('#D8D8D8').width(46).textAlign(TextAlign.Center);
              Text(this.formatTime(item)).fontSize(26).fontWeight(FontWeight.Bold)
                .fontColor('#666666').layoutWeight(1);
              Text(this.isDeparted(item) ? '已发车' : '候车').fontSize(17).fontWeight(FontWeight.Bold)
                .fontColor(this.isDeparted(item) ? '#AEB7C5' : '#F2B632').width(74).textAlign(TextAlign.End);
              Text('○').fontSize(23).fontColor(this.isDeparted(item) ? '#B8C1CF' : '#F2B632').width(34).textAlign(TextAlign.Center);
            }.width('100%').height(82).padding({ left: 34, right: 18 }).border({ width: { bottom: 1 }, color: '#EEEEEE' });
          }, (item: BusTime) => `${item.hour}:${item.minute}`); }.width('100%');
        }.width('100%').alignContent(Alignment.TopStart);
      }.layoutWeight(1).backgroundColor(Color.White).align(Alignment.TopStart);
    }.width('100%').height('100%').backgroundColor(Color.White);
    if (this.showPicker) {
      Column() {
        Row() { Text('取消').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#777777').layoutWeight(1).onClick(() => { animateTo({ duration: 220 }, () => { this.showPicker = false; }); }); Text('校区选择').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#666666').layoutWeight(1).textAlign(TextAlign.Center); Text('确定').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#45C98C').layoutWeight(1).textAlign(TextAlign.End).onClick(() => { this.appliedFrom = this.fromCampus; this.appliedTo = this.toCampus; this.appliedDay = this.dayType; animateTo({ duration: 220 }, () => { this.showPicker = false; }); }); }.width('100%').height(68).padding({ left: 24, right: 24 }).backgroundColor(Color.White);
        Row() {
          Scroll() { Column() { ForEach(this.campuses, (item: string) => Text(item).fontSize(20).fontWeight(item === this.fromCampus ? FontWeight.Bold : FontWeight.Normal).fontColor(item === this.fromCampus ? '#7BDDA8' : '#AAAAAA').height(48).width('100%').textAlign(TextAlign.Center).onClick(() => { this.fromCampus = item; if (this.toCampus === item) this.toCampus = this.firstOtherCampus(item); this.normalizeDay(); })); } }.layoutWeight(1).height('100%').scrollable(ScrollDirection.Vertical);
          Scroll() { Column() { ForEach(this.availableDestinations, (item: string) => Text(item).fontSize(20).fontWeight(item === this.toCampus ? FontWeight.Bold : FontWeight.Normal).fontColor(item === this.toCampus ? '#7BDDA8' : '#AAAAAA').height(48).width('100%').textAlign(TextAlign.Center).onClick(() => { this.toCampus = item; this.normalizeDay(); })); } }.layoutWeight(1).height('100%').scrollable(ScrollDirection.Vertical);
          Scroll() { Column() { ForEach(this.availableDays, (item: string) => Text(item).fontSize(20).fontWeight(item === this.dayType ? FontWeight.Bold : FontWeight.Normal).fontColor(item === this.dayType ? '#7BDDA8' : '#AAAAAA').height(48).width('100%').textAlign(TextAlign.Center).onClick(() => { this.dayType = item; })); } }.layoutWeight(1).height('100%').scrollable(ScrollDirection.Vertical);
        }.width('100%').height(150).padding({ top: 12, bottom: 12 }).backgroundColor(Color.White).border({ width: { top: 1 }, color: '#EEEEEE' });
      }.width('100%').height(218).backgroundColor(Color.White).shadow({ radius: 16, color: '#33000000', offsetY: -4 }).zIndex(10).enabled(true);
      Column().width('100%').height('100%').backgroundColor('#66000000').zIndex(0);
    }
    }.width('100%').height('100%');
  }
}
