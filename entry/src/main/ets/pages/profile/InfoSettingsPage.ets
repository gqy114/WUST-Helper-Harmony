import router from '@ohos.router';
import { AppStorage } from '../../store/AppStorage';
import { UserApi } from '../../net/UserApi';

@Entry
@Component
struct InfoSettingsPage {
  @State private nickname: string = '';
  @State private studentId: string = '';
  @State private major: string = '';
  @State private classes: string = '';
  @State private college: string = '';

  aboutToAppear() {
    this.loadUserInfo();
  }

  private async loadUserInfo(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.nickname = (await storage.getUserName()) || (await storage.getRealName()) || '未设置昵称';
    this.studentId = (await storage.getStudentId()) || '未获取学号';
    this.major = (await storage.getMajor()) || '未获取专业';
    this.college = (await storage.getCollege()) || '未获取院系';
    this.classes = '未获取班级';

    // 页面打开时刷新一次教务资料，保证展示的是后端当前信息。
    const token = await storage.getToken();
    if (token) {
      const response = await UserApi.getUserInfo(token);
      const data = response.data;
      if (data) {
        const realName = data.stuName || data.name || '';
        const studentId = data.stuNum || data.studentNumber || data.studentId || '';
        const major = data.major || '';
        const college = data.college || '';
        const classes = data.classes || data.clazz || '';
        if (realName) {
          this.nickname = realName;
          await storage.setRealName(realName);
          if (!(await storage.getUserName())) await storage.setUserName(realName);
        }
        if (studentId) { this.studentId = studentId; await storage.setStudentId(studentId); }
        if (major) { this.major = major; await storage.setMajor(major); }
        if (college) { this.college = college; await storage.setCollege(college); }
        if (classes) { this.classes = classes; }
      }
    }
  }

  @Builder
  private divider(): void {
    Divider().strokeWidth(1).color('#f2f2f2').margin({ left: 32, right: 24 });
  }

  @Builder
  private valueRow(label: string, value: string): void {
    Row() {
      Text(label).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333');
      Text(value)
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
        .textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1).margin({ left: 18 });
    }
    .width('100%').height(92).padding({ left: 32, right: 24 });
    this.divider();
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(44).fontColor('#333333').width(48).textAlign(TextAlign.Center)
          .onClick(() => router.back());
        Text('信息设置').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#222222')
          .margin({ left: 22 });
      }
      .width('100%').height(88).padding({ left: 16, right: 20 });
      Divider().strokeWidth(10).color('#f7f7f7');

      Row() {
        Text('头像').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333');
        Blank().layoutWeight(1);
        Image($r('app.media.ic_default_avatar')).width(72).height(72).borderRadius(36)
          .objectFit(ImageFit.Cover).margin({ left: 18 });
      }
      .width('100%').height(120).padding({ left: 32, right: 32 });
      this.divider();
      this.valueRow('昵称', this.nickname);
      this.valueRow('专业', this.major);
      this.valueRow('班级', this.classes);
      this.valueRow('院系', this.college);

      Row() {
        Text('课表二维码').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333');
        Blank().layoutWeight(1);
        Image($r('app.media.qrcode_scanner')).width(32).height(32)
          .objectFit(ImageFit.Contain).margin({ left: 18 });
      }
      .width('100%').height(92).padding({ left: 32, right: 28 });
      this.divider();
      Blank().layoutWeight(1);
    }
    .width('100%').height('100%').backgroundColor(Color.White);
  }
}
