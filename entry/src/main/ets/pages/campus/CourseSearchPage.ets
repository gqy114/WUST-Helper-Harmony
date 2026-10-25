import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct CourseSearchPage {
  @State private courseName: string = '';
  @State private teacher: string = '';
  @State private classroom: string = '';
  @State private weekday: string = '';
  @State private startPeriod: number = 1;
  @State private endPeriod: number = 1;
  @State private periodSelected: boolean = false;
  @State private picker: string = '';
  @State private pendingWeekday: string = '周一';
  @State private pendingStart: number = 1;
  @State private pendingEnd: number = 1;

  @Builder
  private field(value: string, placeholder: string, onChange: (value: string) => void) {
    TextInput({ placeholder, text: value }).width('92%').height(58).fontSize(18).fontWeight(FontWeight.Normal)
      .fontColor('#666666').placeholderColor('#AAAAAA').backgroundColor(Color.White)
      .borderRadius(29).padding({ left: 28, right: 20 }).onChange(onChange)
  }

  private openPicker(type: string): void {
    this.picker = type;
    this.pendingWeekday = this.weekday || '不限';
    this.pendingStart = this.periodSelected ? this.startPeriod : 0;
    this.pendingEnd = this.periodSelected ? this.endPeriod : 0;
  }

  private confirmPicker(): void {
    if (this.picker === 'period' && ((this.pendingStart === 0) !== (this.pendingEnd === 0))) {
      promptAction.showToast({ message: '开始和结束节次需同时选择', duration: 1500 });
      return;
    }
    if (this.picker === 'period' && this.pendingStart > 0 && this.pendingEnd < this.pendingStart) {
      promptAction.showToast({ message: '请选择正确范围', duration: 1500 });
      return;
    }
    if (this.picker === 'weekday') {
      this.weekday = this.pendingWeekday === '不限' ? '' : this.pendingWeekday;
    } else {
      this.periodSelected = this.pendingStart > 0 && this.pendingEnd > 0;
      if (this.periodSelected) { this.startPeriod = this.pendingStart; this.endPeriod = this.pendingEnd; }
    }
    this.picker = '';
  }

  private search(): void {
    if (this.courseName.trim().length === 0) {
      promptAction.showToast({ message: '请输入课程名', duration: 1500 });
      return;
    }
    router.pushUrl({ url: 'pages/campus/CourseSearchResultPage', params: {
      courseName: this.courseName.trim(), teacher: this.teacher.trim(), classroom: this.classroom.trim(),
      weekday: this.weekday, startPeriod: this.periodSelected ? String(this.startPeriod) : '',
      endPeriod: this.periodSelected ? String(this.endPeriod) : ''
    } });
  }

  @Builder
  private pickerOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => { this.picker = ''; });
      Column() {
        Row() {
          Text('取消').fontSize(18).fontColor('#999999').layoutWeight(1).onClick(() => { this.picker = ''; });
          Text(this.picker === 'weekday' ? '选择星期' : '选择节次范围').fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor('#333333').textAlign(TextAlign.Center).layoutWeight(2);
          Text('确定').fontSize(18).fontColor('#20C894').layoutWeight(1).textAlign(TextAlign.End)
            .onClick(() => this.confirmPicker());
        }.width('100%').height(54).padding({ left: 20, right: 20 });
        if (this.picker === 'weekday') {
          TextPicker({ range: ['不限', '周一', '周二', '周三', '周四', '周五', '周六', '周日'], selected: ['不限', '周一', '周二', '周三', '周四', '周五', '周六', '周日'].indexOf(this.pendingWeekday) })
            .width('100%').height(250).onChange((value: string | string[], index: number | number[]) => {
              const selected = Array.isArray(index) ? index[0] : index;
              this.pendingWeekday = ['不限', '周一', '周二', '周三', '周四', '周五', '周六', '周日'][selected];
            });
        } else {
          Row() {
            TextPicker({ range: ['不限', '第1节', '第2节', '第3节', '第4节', '第5节', '第6节', '第7节', '第8节', '第9节', '第10节', '第11节', '第12节'], selected: this.pendingStart })
              .layoutWeight(1).height(250).onChange((value: string | string[], index: number | number[]) => {
                const selected = Array.isArray(index) ? index[0] : index; this.pendingStart = selected;
              });
            TextPicker({ range: ['不限', '第1节', '第2节', '第3节', '第4节', '第5节', '第6节', '第7节', '第8节', '第9节', '第10节', '第11节', '第12节'], selected: this.pendingEnd })
              .layoutWeight(1).height(250).onChange((value: string | string[], index: number | number[]) => {
                const selected = Array.isArray(index) ? index[0] : index; this.pendingEnd = selected;
              });
          }.width('100%');
        }
      }.width('92%').backgroundColor(Color.White).borderRadius(20).padding({ bottom: 12 }).onClick(() => {});
    }.width('100%').height('100%');
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Text('‹').fontSize(32).fontColor(Color.White).width(48).onClick(() => router.back());
          Text('课程搜索').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 12 });
        }.width('100%').height(56).padding({ left: 16 }).alignItems(VerticalAlign.Center).backgroundColor('#20C894');
        Scroll() {
          Column() {
            this.field(this.courseName, '课程名（必填）', (value: string) => { this.courseName = value; });
            this.field(this.teacher, '教师（可选）', (value: string) => { this.teacher = value; });
            this.field(this.classroom, '教室（可选）', (value: string) => { this.classroom = value; });
            Text(this.weekday || '请选择星期（可选）').width('92%').height(58).fontSize(18).fontColor(this.weekday ? '#666666' : '#AAAAAA')
              .backgroundColor(Color.White).borderRadius(29).padding({ left: 28 }).onClick(() => this.openPicker('weekday'));
            Text(this.periodSelected ? `第${this.startPeriod}节 - 第${this.endPeriod}节` : '节次（可选）').width('92%').height(58).fontSize(18)
              .fontColor(this.periodSelected ? '#666666' : '#AAAAAA').backgroundColor(Color.White).borderRadius(29)
              .padding({ left: 28 }).onClick(() => this.openPicker('period'));
            Button('开始搜索').width('92%').height(60).fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(Color.White).backgroundColor('#20C894').borderRadius(29).margin({ top: 24 }).onClick(() => this.search());
            Blank().height(40);
          }.width('100%').padding({ top: 38, bottom: 30 }).alignItems(HorizontalAlign.Center);
        }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8').scrollBar(BarState.Off);
      }.width('100%').height('100%').backgroundColor('#F5F6F8');
      if (this.picker.length > 0) { this.pickerOverlay(); }
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
