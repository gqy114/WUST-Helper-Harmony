import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CourseApi } from '../../net/CourseApi';
import { CourseData } from '../../model/CourseModel';
import { AppStorage } from '../../store/AppStorage';

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
  @State private results: CourseData[] = [];
  @State private searching: boolean = false;

  @Builder
  private field(value: string, placeholder: string, onChange: (value: string) => void) {
    TextInput({ placeholder, text: value }).width('92%').height(58).fontSize(18).fontWeight(FontWeight.Normal)
      .fontColor('#666666').placeholderColor('#AAAAAA').backgroundColor(Color.White)
      .borderRadius(29).padding({ left: 28, right: 20 }).onChange(onChange)
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

  private async search(): Promise<void> {
    if (this.courseName.trim().length === 0 && this.teacher.trim().length === 0 && this.classroom.trim().length === 0) {
      promptAction.showToast({ message: '请至少输入一项查询条件', duration: 1500 });
      return;
    }
    this.searching = true;
    try {
      const storage = AppStorage.getInstance();
      const response = await CourseApi.getCourseTable(await storage.getSemester(), await storage.getToken());
      const name = this.courseName.trim().toLowerCase();
      const teacher = this.teacher.trim().toLowerCase();
      const room = this.classroom.trim().toLowerCase();
      const courses: CourseData[] = response.data || [];
      this.results = courses.filter((item: CourseData) => {
        const weekdayMatches = this.weekday.length === 0 || `周${['一', '二', '三', '四', '五', '六', '日'][item.dayOfWeek - 1]}` === this.weekday;
        const periodMatches = !this.periodSelected || (item.startPeriod <= this.endPeriod && item.endPeriod >= this.startPeriod);
        return item.courseName.toLowerCase().indexOf(name) >= 0 && item.teacher.toLowerCase().indexOf(teacher) >= 0 &&
          item.location.toLowerCase().indexOf(room) >= 0 && weekdayMatches && periodMatches;
      });
      if (this.results.length === 0) promptAction.showToast({ message: '没有找到符合条件的课程', duration: 1500 });
    } catch {
      promptAction.showToast({ message: '课程查询失败，请稍后重试', duration: 1500 });
    } finally { this.searching = false; }
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
          TextPicker({ range: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'], selected: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'].indexOf(this.pendingWeekday) })
            .width('100%').height(250).onChange((value: string | string[], index: number | number[]) => {
              const selected = Array.isArray(index) ? index[0] : index;
              this.pendingWeekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][selected];
            });
        } else {
          Row() {
            TextPicker({ range: ['第1节', '第2节', '第3节', '第4节', '第5节', '第6节', '第7节', '第8节', '第9节', '第10节', '第11节', '第12节'], selected: this.pendingStart - 1 })
              .layoutWeight(1).height(250).onChange((value: string | string[], index: number | number[]) => {
                const selected = Array.isArray(index) ? index[0] : index; this.pendingStart = selected + 1;
              });
            TextPicker({ range: ['第1节', '第2节', '第3节', '第4节', '第5节', '第6节', '第7节', '第8节', '第9节', '第10节', '第11节', '第12节'], selected: this.pendingEnd - 1 })
              .layoutWeight(1).height(250).onChange((value: string | string[], index: number | number[]) => {
                const selected = Array.isArray(index) ? index[0] : index; this.pendingEnd = selected + 1;
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
            this.field(this.courseName, '课程名', (value: string) => { this.courseName = value; });
            this.field(this.teacher, '教师（可选）', (value: string) => { this.teacher = value; });
            this.field(this.classroom, '教室（可选）', (value: string) => { this.classroom = value; });
            Text(this.weekday || '请选择星期（可选）').width('92%').height(58).fontSize(18).fontColor(this.weekday ? '#666666' : '#AAAAAA')
              .backgroundColor(Color.White).borderRadius(29).padding({ left: 28 }).onClick(() => this.openPicker('weekday'));
            Text(this.periodSelected ? `第${this.startPeriod}节 - 第${this.endPeriod}节` : '节次（可选）').width('92%').height(58).fontSize(18)
              .fontColor(this.periodSelected ? '#666666' : '#AAAAAA').backgroundColor(Color.White).borderRadius(29)
              .padding({ left: 28 }).onClick(() => this.openPicker('period'));
            Button(this.searching ? '搜索中…' : '开始搜索').width('92%').height(60).fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(Color.White).backgroundColor('#20C894').borderRadius(29).margin({ top: 24 }).onClick(() => this.search());
            ForEach(this.results, (item: CourseData) => {
              Row() {
                Column() {
                  Text(item.courseName).fontSize(18).fontWeight(FontWeight.Bold).width('100%');
                  Text(`${item.teacher} · ${item.location}`).fontSize(14).fontColor('#777777').width('100%').margin({ top: 5 });
                }.layoutWeight(1);
              }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(12).margin({ top: 10 });
            })
            Blank().height(40);
          }.width('100%').padding({ top: 38, bottom: 30 }).alignItems(HorizontalAlign.Center);
        }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8').scrollBar(BarState.Off);
      }.width('100%').height('100%').backgroundColor('#F5F6F8');
      if (this.picker.length > 0) { this.pickerOverlay(); }
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
