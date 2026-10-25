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
  @State private showLogin: boolean = false;
  @State private studentId: string = '';
  @State private physicalPassword: string = '';
  private store: CourseStore = CourseStore.getInstance();

  aboutToAppear(): void { this.prepare(); }

  private async prepare(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.studentId = await storage.getStudentId();
    this.physicalPassword = await storage.getPhysicalExperimentPassword();
    if (!this.physicalPassword) {
      this.showLogin = true;
      return;
    }
    await this.loadCourses();
  }

  private async confirmLogin(): Promise<void> {
    const password = this.physicalPassword.trim();
    if (!password) {
      promptAction.showToast({ message: '物理实验密码不能为空', duration: 1500 });
      return;
    }
    this.showLogin = false;
    this.physicalPassword = password;
    await this.loadCourses(true);
  }

  private async loadCourses(savePassword: boolean = false): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const storage = AppStorage.getInstance();
      this.courses = await PhysicalExperimentApi.getCourses(await storage.getSemester(), this.physicalPassword);
      if (savePassword) await storage.setPhysicalExperimentPassword(this.physicalPassword);
    } catch (e) {
      this.error = e instanceof Error ? e.message : '物理实验课表获取失败';
      if (savePassword) this.showLogin = true;
    } finally {
      this.loading = false;
    }
  }

  private async logoutPhysical(): Promise<void> {
    await AppStorage.getInstance().setPhysicalExperimentPassword('');
    this.physicalPassword = '';
    this.courses = [];
    this.error = '';
    this.showLogin = true;
  }

  private importCourses(): void {
    const imported: CourseData[] = this.courses.map((item: PhysicalExperimentCourse): CourseData => ({
      courseName: item.courseName || item.className || item.name || item.course || '物理实验',
      teacher: item.teacher || '', location: item.classroom || '', dayOfWeek: item.weekDay || 1,
      startPeriod: item.startSection || item.section || 1,
      endPeriod: item.endSection || item.startSection || item.section || 1,
      weekRanges: item.startWeek && item.endWeek ? `${item.startWeek}-${item.endWeek}` : '1-16'
    }));
    if (imported.length === 0) {
      promptAction.showToast({ message: '暂无可导入的实验课程' });
      return;
    }
    this.store.setCourses(this.store.courses.concat(imported));
    promptAction.showToast({ message: `已导入${imported.length}门实验课程` });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Text('‹').fontSize(36).fontColor('#333333').onClick(() => router.back())
          Text('物理实验').fontSize(22).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1)
          Text('退出').fontSize(15).fontColor('#888888').margin({ right: 18 }).onClick(() => this.logoutPhysical())
          Text('刷新').fontSize(16).fontColor('#1ec98d').onClick(() => this.loadCourses())
        }.width('100%').height(56).padding({ left: 18, right: 18 }).backgroundColor(Color.White)

        if (this.loading) {
          LoadingProgress().width(42).height(42).layoutWeight(1)
        } else if (this.error.length > 0) {
          Column() {
            Text('物理实验课表加载失败').fontSize(18).fontColor('#333333')
            Text(this.error).fontSize(14).fontColor('#999999').margin({ top: 10 }).textAlign(TextAlign.Center)
            Button('重新登录').backgroundColor('#1ec98d').fontColor(Color.White).margin({ top: 18 })
              .onClick(() => { this.physicalPassword = ''; this.showLogin = true; })
          }.layoutWeight(1).padding(24).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column() {
              Text(`共${this.courses.length}门实验课程`).fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 12 })
              ForEach(this.courses, (item: PhysicalExperimentCourse) => {
                Row() {
                  Column() {
                    Text(item.courseName || item.className || item.name || item.course || '物理实验').fontSize(16).fontColor('#333333')
                    if (item.date || item.startClock || item.endClock) {
                      Text(`${item.date || ''} ${item.startClock || ''}-${item.endClock || ''}`.trim())
                        .fontSize(13).fontColor('#999999').margin({ top: 5 })
                    }
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Text(item.classroom || '待定').fontSize(14).fontColor('#888888')
                }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(10).margin({ bottom: 10 })
              })
              Button('导入到课表').width('90%').height(48).backgroundColor('#1ec98d').fontColor(Color.White)
                .margin({ top: 12, bottom: 24 }).onClick(() => this.importCourses())
            }.width('100%').padding(16)
          }.width('100%').layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor('#F5F6F7')

      if (this.showLogin) {
        Column() {
          Column() {
            Text('物理实验登录').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%')
            TextInput({ text: this.studentId, placeholder: '学号' }).fontSize(17).fontColor('#999999').enabled(false)
              .width('100%').height(58).margin({ top: 18 }).backgroundColor(Color.Transparent)
            Divider().color('#E5E5E5')
            TextInput({ text: this.physicalPassword, placeholder: '物理实验密码' }).type(InputType.Password)
              .fontSize(17).width('100%').height(58).backgroundColor(Color.Transparent)
              .onChange((value: string) => { this.physicalPassword = value; })
            Divider().color('#E5E5E5')
            Text('密码是物理实验预约系统的密码').fontSize(14).fontColor('#9CA3AF').width('100%')
              .textAlign(TextAlign.End).margin({ top: 14, bottom: 16 })
            Divider().color('#EFEFEF')
            Text('确认').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#2785EF').width('100%').height(52)
              .textAlign(TextAlign.Center).onClick(() => this.confirmLogin())
          }.width('84%').padding({ left: 24, right: 24, top: 24 }).backgroundColor(Color.White).borderRadius(16)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#99000000')
      }
    }.width('100%').height('100%')
  }
}
