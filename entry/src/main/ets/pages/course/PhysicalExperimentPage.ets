import { router, promptAction } from '@kit.ArkUI';
import { PhysicalExperimentApi, PhysicalExperimentCourse } from '../../net/PhysicalExperimentApi';
import { CourseStore } from '../../store/CourseStore';
import { CourseData } from '../../model/CourseModel';
import { AppStorage } from '../../store/AppStorage';

@Entry
@Component
export struct PhysicalExperimentPage {
  @State private courses: PhysicalExperimentCourse[] = [];
  @State private loading: boolean = false;
  @State private error: string = '';
  private store: CourseStore = CourseStore.getInstance();

  aboutToAppear(): void { this.loadCourses(); }

  private async loadCourses(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const semester = await AppStorage.getInstance().getSemester();
      this.courses = await PhysicalExperimentApi.getCourses(semester || '');
    } catch (e) {
      this.error = e instanceof Error ? e.message : '物理实验课表获取失败';
    } finally {
      this.loading = false;
    }
  }

  private importCourses(): void {
    const imported: CourseData[] = [];
    for (let i = 0; i < this.courses.length; i++) {
      const item = this.courses[i];
      imported.push({
        courseName: item.courseName || item.name || '物理实验',
        teacher: '',
        location: item.classroom || '',
        dayOfWeek: item.weekDay || 1,
        startPeriod: item.startSection || 1,
        endPeriod: item.endSection || item.startSection || 1,
        weekRanges: item.startWeek && item.endWeek ? `${item.startWeek}-${item.endWeek}` : '1-16'
      });
    }
    if (imported.length === 0) {
      promptAction.showToast({ message: '暂无可导入的实验课程' });
      return;
    }
    this.store.setCourses(this.store.courses.concat(imported));
    promptAction.showToast({ message: `已导入${imported.length}门实验课程` });
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(36).fontColor('#333333').onClick(() => router.back())
        Text('物理实验').fontSize(22).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1)
        Text('刷新').fontSize(16).fontColor('#1ec98d').onClick(() => this.loadCourses())
      }.width('100%').height(56).padding({ left: 18, right: 18 }).backgroundColor(Color.White)

      if (this.loading) {
        LoadingProgress().width(42).height(42).layoutWeight(1)
      } else if (this.error.length > 0) {
        Column() {
          Text('物理实验课表加载失败').fontSize(18).fontColor('#333333')
          Text(this.error).fontSize(14).fontColor('#999999').margin({ top: 10 })
          Button('重试').backgroundColor('#1ec98d').fontColor(Color.White).margin({ top: 18 }).onClick(() => this.loadCourses())
        }.layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          Text(`共${this.courses.length}门实验课程`).fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 12 })
          ForEach(this.courses, (item: PhysicalExperimentCourse) => {
            Row() {
              Text(item.courseName || item.name || '物理实验').fontSize(16).fontColor('#333333').layoutWeight(1)
              Text(item.classroom || '待定').fontSize(14).fontColor('#888888')
            }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(10).margin({ bottom: 10 })
          })
          Button('导入到课表').width('90%').height(48).backgroundColor('#1ec98d').fontColor(Color.White).margin({ top: 12 }).onClick(() => this.importCourses())
        }.width('100%').padding(16).layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor('#F5F6F7')
  }
}
