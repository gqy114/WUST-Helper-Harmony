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
  @State private section: string = '';
  @State private picker: string = '';
  @State private results: CourseData[] = [];
  @State private searching: boolean = false;

  private field(value: string, placeholder: string, onChange: (value: string) => void): void {
    TextInput({ placeholder, text: value }).width('92%').height(74).fontSize(22).fontColor('#555555')
      .backgroundColor(Color.White).borderRadius(38).padding({ left: 28, right: 20 }).onChange(onChange)
  }

  private async search(): Promise<void> {
    if (this.courseName.length === 0 && this.teacher.length === 0 && this.classroom.length === 0) {
      promptAction.showToast({ message: '请至少输入一项查询条件' });
      return;
    }
    this.searching = true;
    try {
      const storage = AppStorage.getInstance();
      const token = await storage.getToken();
      const semester = await storage.getSemester();
      const response = await CourseApi.getCourseTable(semester || '', token);
      const name = this.courseName.toLowerCase();
      const teacher = this.teacher.toLowerCase();
      const room = this.classroom.toLowerCase();
      this.results = response.data.filter((item: CourseData) => {
        return item.courseName.toLowerCase().indexOf(name) >= 0 &&
          item.teacher.toLowerCase().indexOf(teacher) >= 0 &&
          item.location.toLowerCase().indexOf(room) >= 0 &&
          (this.weekday.length === 0 || `周${['一','二','三','四','五','六','日'][item.dayOfWeek - 1]}` === this.weekday) &&
          (this.section.length === 0 || (item.startPeriod <= Number(this.section) && item.endPeriod >= Number(this.section)));
      });
      if (this.results.length === 0) promptAction.showToast({ message: '没有找到符合条件的课程' });
    } catch {
      promptAction.showToast({ message: '课程查询失败，请稍后重试' });
    } finally { this.searching = false; }
  }

  build() {
    Column() {
      Row() { Text('‹').fontSize(38).fontColor(Color.White).onClick(() => router.back()); Text('课程搜索').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 14 }); }
        .width('100%').height(76).padding({ left: 22 }).backgroundColor('#20C894')
      Scroll() {
        Column() {
          this.field(this.courseName, '课程名', (v: string) => { this.courseName = v; });
          this.field(this.teacher, '教师（可选）', (v: string) => { this.teacher = v; });
          this.field(this.classroom, '教室（可选）', (v: string) => { this.classroom = v; });
          Text(this.weekday || '请选择星期（可选）').width('92%').height(74).fontSize(22).fontColor(this.weekday ? '#555555' : '#BBBBBB').backgroundColor(Color.White).borderRadius(38).padding({ left: 28 }).onClick(() => { this.picker = 'weekday'; });
          Text(this.section ? `第${this.section}节（可选）` : '节次（可选）').width('92%').height(74).fontSize(22).fontColor(this.section ? '#555555' : '#BBBBBB').backgroundColor(Color.White).borderRadius(38).padding({ left: 28 }).onClick(() => { this.picker = 'section'; });
          Button(this.searching ? '搜索中...' : '开始搜索').width('92%').height(72).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor('#20C894').borderRadius(38).margin({ top: 24 }).onClick(() => this.search());
          ForEach(this.results, (item: CourseData) => Row() { Text(item.courseName).fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1); Text(`${item.teacher} · ${item.location}`).fontSize(14).fontColor('#777777'); }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(12).margin({ top: 10 }));
          if (this.picker.length > 0) {
            Column() {
              Text(this.picker === 'weekday' ? '选择星期' : '选择节次').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 10 });
              if (this.picker === 'weekday') { TextPicker({ range: ['周一','周二','周三','周四','周五','周六','周日'] }).width('100%').onChange((value: string | string[], index: number) => { this.weekday = Array.isArray(value) ? value[0] : value; }); }
              else { TextPicker({ range: ['1','2','3','4','5','6','7','8','9','10','11','12'] }).width('100%').onChange((value: string | string[], index: number) => { this.section = Array.isArray(value) ? value[0] : value; }); }
              Text('确定').fontSize(19).fontColor('#20C894').width('100%').textAlign(TextAlign.End).margin({ top: 12 }).onClick(() => { this.picker = ''; });
            }.width('92%').padding(20).backgroundColor(Color.White).borderRadius(18).margin({ top: 18 })
          }
        }.width('100%').padding({ top: 40, bottom: 30 }).alignItems(HorizontalAlign.Center)
      }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F6F8')
  }
}
