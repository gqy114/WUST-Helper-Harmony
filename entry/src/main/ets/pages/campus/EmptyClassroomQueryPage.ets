import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct ClassroomQueryPage {
  @State private startWeek: string = '';
  @State private endWeek: string = '';
  @State private weekday: string = '';
  @State private startPeriod: number = 1;
  @State private endPeriod: number = 1;
  @State private periodSelected: boolean = false;
  @State private building: string = '';
  @State private room: string = '';
  @State private picker: string = '';
  @State private pendingWeekday: string = '周一';
  @State private pendingStart: number = 1;
  @State private pendingEnd: number = 1;

  @Builder
  private field(value: string, placeholder: string, onChange: (value: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .width('92%').height(58).fontSize(18).fontWeight(FontWeight.Normal)
      .fontColor('#666666').placeholderColor('#999999').backgroundColor(Color.White)
      .borderRadius(29).padding({ left: 28, right: 20 }).onChange(onChange);
  }

  private openPicker(type: string): void {
    this.picker = type;
    this.pendingWeekday = this.weekday || '周一';
    this.pendingStart = this.startPeriod;
    this.pendingEnd = this.endPeriod;
  }

  private confirmPicker(): void {
    if (this.picker === 'period' && this.pendingEnd < this.pendingStart) {
      promptAction.showToast({ message: '请选择正确范围', duration: 1500 });
      return;
    }
    if (this.picker === 'weekday') {
      this.weekday = this.pendingWeekday;
    } else {
      this.startPeriod = this.pendingStart;
      this.endPeriod = this.pendingEnd;
      this.periodSelected = true;
    }
    this.picker = '';
  }

  private submitQuery(): void {
    if (this.startWeek.trim().length === 0) {
      promptAction.showToast({ message: '请输入开始周次', duration: 1500 });
      return;
    }
    if (!/^\d+$/.test(this.startWeek.trim()) || Number(this.startWeek.trim()) < 1) {
      promptAction.showToast({ message: '开始周次格式不正确', duration: 1500 });
      return;
    }
    if (this.weekday.length === 0) {
      promptAction.showToast({ message: '请选择星期', duration: 1500 });
      return;
    }
    if (!this.periodSelected) {
      promptAction.showToast({ message: '请选择节次范围', duration: 1500 });
      return;
    }
    if (this.endWeek.trim().length > 0 && (!/^\d+$/.test(this.endWeek.trim()) || Number(this.endWeek.trim()) < Number(this.startWeek.trim()))) {
      promptAction.showToast({ message: '结束周次范围不正确', duration: 1500 });
      return;
    }
    router.pushUrl({ url: 'pages/campus/ClassroomResultPage', params: {
      startWeek: this.startWeek.trim(),
      endWeek: this.endWeek.trim().length > 0 ? this.endWeek.trim() : this.startWeek.trim(),
      weekday: this.weekday,
      startPeriod: String(this.startPeriod),
      endPeriod: String(this.endPeriod),
      building: this.building.trim(),
      room: this.room.trim()
    } });
  }

  @Builder
  private pickerOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
        .onClick(() => { this.picker = ''; });
      Column() {
        Row() {
          Text('取消').fontSize(18).fontColor('#999999').layoutWeight(1)
            .onClick(() => { this.picker = ''; });
          Text(this.picker === 'weekday' ? '选择星期' : '选择节次范围')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
            .textAlign(TextAlign.Center).layoutWeight(2);
          Text('确定').fontSize(18).fontColor('#20C894').layoutWeight(1)
            .textAlign(TextAlign.End).onClick(() => this.confirmPicker());
        }.width('100%').height(54).padding({ left: 20, right: 20 });
        if (this.picker === 'weekday') {
          TextPicker({ range: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'], selected: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'].indexOf(this.pendingWeekday) })
            .width('100%').height(250)
            .onChange((value: string | string[], index: number | number[]) => { let i: number = Array.isArray(index) ? index[0] : index; this.pendingWeekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][i]; });
        } else {
          Row() {
            TextPicker({ range: ['第1节', '第2节', '第3节', '第4节', '第5节', '第6节', '第7节', '第8节', '第9节', '第10节', '第11节', '第12节'], selected: this.pendingStart - 1 })
              .layoutWeight(1).height(250)
              .onChange((value: string | string[], index: number | number[]) => { let i: number = Array.isArray(index) ? index[0] : index; this.pendingStart = i + 1; });
            TextPicker({ range: ['第1节', '第2节', '第3节', '第4节', '第5节', '第6节', '第7节', '第8节', '第9节', '第10节', '第11节', '第12节'], selected: this.pendingEnd - 1 })
              .layoutWeight(1).height(250)
              .onChange((value: string | string[], index: number | number[]) => { let i: number = Array.isArray(index) ? index[0] : index; this.pendingEnd = i + 1; });
          }.width('100%');
        }
      }.width('92%').backgroundColor(Color.White).borderRadius(20).padding({ bottom: 12 })
        .onClick(() => {});
    }.width('100%').height('100%');
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Text('‹').fontSize(32).fontColor(Color.White).width(48).onClick(() => router.back());
          Text('空教室查询').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 12 });
        }.width('100%').height(56).padding({ left: 16 }).alignItems(VerticalAlign.Center).backgroundColor('#20C894');
        Scroll() {
          Column() {
            Text('留空代表不限，输入一个时间段和教室条件即可查询').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#777777').width('92%').margin({ top: 34, bottom: 24 });
            this.field(this.startWeek, '开始周次（如 1）', (v: string) => { this.startWeek = v; });
            this.field(this.endWeek, '结束周次（留空则等于开始周次）', (v: string) => { this.endWeek = v; });
            Text(this.weekday || '请选择星期').width('92%').height(58).fontSize(18).fontWeight(FontWeight.Normal).fontColor(this.weekday ? '#666666' : '#AAAAAA').backgroundColor(Color.White).borderRadius(29).padding({ left: 28 }).onClick(() => this.openPicker('weekday'));
            Text(this.periodSelected ? `第${this.startPeriod}节 - 第${this.endPeriod}节` : '节次范围').width('92%').height(58).fontSize(18).fontWeight(FontWeight.Normal).fontColor(this.periodSelected ? '#666666' : '#AAAAAA').backgroundColor(Color.White).borderRadius(29).padding({ left: 28 }).onClick(() => this.openPicker('period'));
            this.field(this.building, '教学楼（可输入关键字）', (v: string) => { this.building = v; });
            this.field(this.room, '教室编号（可输入关键字，如 101）', (v: string) => { this.room = v; });
            Button('查询教室').width('92%').height(60).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor('#20C894').borderRadius(29).margin({ top: 24 }).onClick(() => this.submitQuery());
            Blank().height(40);
          }.width('100%').padding({ bottom: 30 }).alignItems(HorizontalAlign.Center);
        }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8').scrollBar(BarState.Off);
      }.width('100%').height('100%').backgroundColor('#F5F6F8');
      if (this.picker.length > 0) {
        this.pickerOverlay();
      }
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}


