import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import request from '@ohos.request';
import { AppStorage } from '../../store/AppStorage';
import { UserApi } from '../../net/UserApi';
import { StudentApiContent } from '../../model/UserInfoModel';
import { ApiService } from '../../net/ApiService';

interface InfoSettingsParams {
  name?: string;
  studentId?: string;
}

@Entry
@Component
struct InfoSettingsPage {
  @State private nickname: string = '未设置昵称';
  @State private studentId: string = '';
  @State private major: string = '未获取专业';
  @State private classes: string = '未获取班级';
  @State private college: string = '未获取院系';
  @State private avatarUrl: string = '';
  @State private cropImageUri: string = '';
  @State private cropScale: number = 1;
  @State private cropRotation: number = 0;
  @State private showingCropper: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as InfoSettingsParams;
    if (params && params.name) this.nickname = params.name;
    if (params && params.studentId) this.studentId = params.studentId;
    this.loadUserInfo();
  }

  private async loadUserInfo(): Promise<void> {
    console.info('InfoSettingsPage', 'loadUserInfo start');
    const storage = AppStorage.getInstance();
    this.avatarUrl = await storage.getAvatarUrl();
    this.nickname = (await storage.getUserName()) || (await storage.getRealName()) || '未设置昵称';
    this.studentId = (await storage.getStudentId()) || '未获取学号';
    this.major = (await storage.getMajor()) || '未获取专业';
    this.college = (await storage.getCollege()) || '未获取院系';
    this.classes = (await storage.getClasses()) || '未获取班级';
    // 页面打开时刷新一次教务资料，保证展示的是后端当前信息。
    let token = await storage.getToken();
    console.info('InfoSettingsPage', `tokenLen=${token.length} studentId=${this.studentId}`);
    const savedStudentId = await storage.getStudentId();
    const savedPassword = await storage.getPassword();
    const isGraduate = await storage.getIsGraduate();
    if (isGraduate) {
      try {
        const response = await UserApi.getGraduateUserInfo(await storage.getStudentId(), await storage.getPassword());
        await this.applyUserInfo(response.data, storage);
      } catch (error) {
        console.warn('InfoSettingsPage', `load graduate info failed: ${JSON.stringify(error)}`);
      }
    } else {
      try {
        // Cookie 丢失时重新登录换取教务 Cookie，避免页面只显示缓存占位符。
        if (!token && savedStudentId && savedPassword) {
          const login = await ApiService.loginUndergrad(savedStudentId, savedPassword);
          if (login.data?.token) {
            token = login.data.token;
            await storage.setToken(token);
          }
        }
        if (!token) return;
        const response = await UserApi.getUserInfo(token, savedStudentId);
        const data = response.data;
        console.info('InfoSettingsPage', `apply data=${JSON.stringify(data)}`);
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
          if (classes) { this.classes = classes; await storage.setClasses(classes); }
        }
      } catch (error) {
        console.warn('InfoSettingsPage', `load student info failed: ${JSON.stringify(error)}`);
      }
    }
  }

  private async applyUserInfo(data: StudentApiContent | undefined, storage: AppStorage): Promise<void> {
    if (!data) return;
    const realName = data.stuName || data.name || '';
    const studentId = data.stuNum || data.studentNumber || data.studentId || '';
    const major = data.major || '';
    const college = data.college || '';
    const classes = data.classes || data.clazz || '';
    if (realName) { this.nickname = realName; await storage.setRealName(realName); await storage.setUserName(realName); }
    if (studentId) { this.studentId = studentId; await storage.setStudentId(studentId); }
    if (major) { this.major = major; await storage.setMajor(major); }
    if (college) { this.college = college; await storage.setCollege(college); }
    if (classes) { this.classes = classes; await storage.setClasses(classes); }
  }

  private async chooseAvatar(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      if (result.photoUris && result.photoUris.length > 0) {
        this.cropImageUri = result.photoUris[0];
        this.cropScale = 1;
        this.cropRotation = 0;
        this.showingCropper = true;
      }
    } catch (error) {
      console.error('InfoSettingsPage', `choose avatar failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '选择图片失败', duration: 1500 });
    }
  }

  private cancelCrop(): void {
    this.showingCropper = false;
    this.cropImageUri = '';
    this.cropScale = 1;
    this.cropRotation = 0;
  }

  private async confirmCrop(): Promise<void> {
    if (!this.cropImageUri) return;
    const localUri = this.cropImageUri;
    // Show the result immediately while the multipart upload is in progress.
    this.avatarUrl = localUri;
    this.showingCropper = false;
    this.cropImageUri = '';
    try {
      const storage = AppStorage.getInstance();
      const token = await storage.getAppAuthAccessToken();
      if (!token) throw new Error('missing app auth token');
      const task = await request.uploadFile(getContext(this), {
        url: 'https://lyzyy.love:8081/api/v1/profile/avatar',
        method: 'POST',
        header: { 'Authorization': `Bearer ${token}` },
        files: [{ filename: 'avatar.jpg', name: 'avatar', uri: localUri, type: 'image/jpeg' }],
        data: [],
      });
      const states = await new Promise<Array<request.TaskState>>((resolve, reject) => {
        task.on('complete', (items: Array<request.TaskState>) => resolve(items));
        task.on('fail', (items: Array<request.TaskState>) => reject(new Error(JSON.stringify(items))));
      });
      if (!states.length || states[0].responseCode !== 0) throw new Error('avatar upload failed');
      // The upload API returns the canonical URL through the normal auth profile.
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      this.avatarUrl = await storage.getAvatarUrl();
      promptAction.showToast({ message: '头像已同步', duration: 1200 });
    } catch (error) {
      // Keep the selected local image visible if the network is temporarily unavailable.
      await AppStorage.getInstance().setAvatarUrl(localUri);
      console.warn('InfoSettingsPage', `avatar upload failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '头像已更新，服务器同步失败', duration: 1800 });
    }
  }

  @Builder
  private cropperView(): void {
    Column() {
      Row() {
        Text('×').fontSize(40).fontColor('#111111').width(64).textAlign(TextAlign.Center)
          .onClick(() => this.cancelCrop());
        Text('裁剪').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#111111').layoutWeight(1);
        Text('✓').fontSize(38).fontColor('#111111').width(64).textAlign(TextAlign.Center)
          .onClick(() => this.confirmCrop());
      }.width('100%').height(88).padding({ left: 10, right: 10 });
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height('100%').backgroundColor('#777777');
        Image(this.cropImageUri).width('100%').height(420).objectFit(ImageFit.Contain)
          .scale({ x: this.cropScale, y: this.cropScale })
          .rotate({ angle: this.cropRotation });
        Circle().width(300).height(300).fill('#00000000').stroke('#ffffff99').strokeWidth(2);
      }.width('100%').layoutWeight(1).clip(true);
      Row() {
        Column() {
          Text('↻').fontSize(42).fontColor('#999999');
          Text('旋转').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333');
        }.width('50%').onClick(() => { this.cropRotation = (this.cropRotation + 90) % 360; });
        Column() {
          Text('▣').fontSize(36).fontColor('#20bd91');
          Text('缩放').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333');
        }.width('50%').onClick(() => { this.cropScale = this.cropScale >= 2.2 ? 1 : this.cropScale + 0.2; });
      }.width('100%').height(130).justifyContent(FlexAlign.SpaceAround).backgroundColor(Color.White);
    }.width('100%').height('100%').backgroundColor(Color.White);
  }

  @Builder
  private divider(): void {
    Divider().strokeWidth(1).color('#f2f2f2').margin({ left: 32, right: 24 });
  }

  @Builder
  private nicknameRow(): void {
    Row() { Text('昵称').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333'); Blank().layoutWeight(1); Text(this.nickname).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '68%' }); }.width('100%').height(84).padding({ left: 32, right: 24 }); this.divider();
  }

  @Builder
  private majorRow(): void {
    Row() { Text('专业').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333'); Blank().layoutWeight(1); Text(this.major).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '68%' }); }.width('100%').height(84).padding({ left: 32, right: 24 }); this.divider();
  }

  @Builder
  private classesRow(): void {
    Row() { Text('班级').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333'); Blank().layoutWeight(1); Text(this.classes).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '68%' }); }.width('100%').height(84).padding({ left: 32, right: 24 }); this.divider();
  }

  @Builder
  private collegeRow(): void {
    Row() { Text('院系').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333'); Blank().layoutWeight(1); Text(this.college).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '68%' }); }.width('100%').height(84).padding({ left: 32, right: 24 }); this.divider();
  }

  @Builder
  private valueRow(label: string, value: string): void {
    Row() {
      Text(label).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333');
      Blank().layoutWeight(1);
      Text(value)
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
        .textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '68%' }).margin({ left: 18 });
    }
    .width('100%').height(92).padding({ left: 32, right: 24 });
    this.divider();
  }

  build() {
    Stack() {
      if (this.showingCropper) {
        this.cropperView();
      } else {
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
        Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(72).height(72).borderRadius(36)
          .objectFit(ImageFit.Cover).margin({ left: 18 });
          }.onClick(() => this.chooseAvatar())
          .width('100%').height(120).padding({ left: 32, right: 32 });
          this.divider();
          this.nicknameRow();
          this.majorRow();
          this.classesRow();
          this.collegeRow();

          Row() {
        Text('课表二维码').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333');
        Blank().layoutWeight(1);
        Image($r('app.media.qrcode_scanner')).width(32).height(32)
          .objectFit(ImageFit.Contain).margin({ left: 18 });
          }
          .width('100%').height(92).padding({ left: 32, right: 28 })
          .onClick(() => router.pushUrl({ url: 'pages/course/CourseSharePage' }));
          this.divider();
          Blank().layoutWeight(1);
        }
        .width('100%').height('100%').backgroundColor(Color.White);
      }
    }
    .width('100%').height('100%').backgroundColor(Color.White);
  }
}
