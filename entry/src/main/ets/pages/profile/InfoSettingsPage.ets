import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import request from '@ohos.request';
import { AppStorage as PreferenceStorage } from '../../store/AppStorage';
import { UserApi } from '../../net/UserApi';
import { StudentApiContent } from '../../model/UserInfoModel';
import { ApiService } from '../../net/ApiService';

interface InfoSettingsParams {
  name?: string;
  studentId?: string;
}

AppStorage.setOrCreate<number>('profileVersion', 0);

@Entry
@Component
struct InfoSettingsPage {
  @StorageLink('profileVersion') @Watch('onProfileVersionChanged') private profileVersion: number = 0;
  @State private nickname: string = '未设置昵称';
  @State private studentId: string = '';
  @State private major: string = '未获取专业';
  @State private classes: string = '未获取班级';
  @State private college: string = '未获取院系';
  @State private avatarUrl: string = '';
  @State private cropImageUri: string = '';
  @State private cropScale: number = 1;
  @State private cropRotation: number = 0;
  @State private cropOffsetX: number = 0;
  @State private cropOffsetY: number = 0;
  @State private cropperBusy: boolean = false;
  @State private showingCropper: boolean = false;
  // 原图尺寸：用于计算 Cover 填充后左右/上下可平移的范围。
  @State private cropImageWidth: number = 0;
  @State private cropImageHeight: number = 0;
  // 裁剪框边长（px，vp 同值）：截图按这个尺寸输出方图，展示时再裁圆角。
  private readonly CROP_SIZE: number = 300;
  private cropStartOffsetX: number = 0;
  private cropStartOffsetY: number = 0;
  private cropStartScale: number = 1;

  aboutToAppear() {
    const params = router.getParams() as InfoSettingsParams;
    if (params && params.name) this.nickname = params.name;
    if (params && params.studentId) this.studentId = params.studentId;
    this.loadUserInfo();
  }

  private onProfileVersionChanged(): void {
    this.refreshNickname();
  }

  private async refreshNickname(): Promise<void> {
    const storage = PreferenceStorage.getInstance();
    this.nickname = (await storage.getUserName()) || (await storage.getRealName()) || '未设置昵称';
  }

  private async applyRealName(realName: string, storage: PreferenceStorage): Promise<void> {
    if (!realName) return;
    await storage.setRealName(realName);
    const savedNickname = (await storage.getUserName()).trim();
    if (!savedNickname || savedNickname === '木有设置' || savedNickname === '未设置昵称') {
      await storage.setUserName(realName);
      this.nickname = realName;
      return;
    }
    this.nickname = savedNickname;
  }

  private async loadUserInfo(): Promise<void> {
    console.info('InfoSettingsPage', 'loadUserInfo start');
    const storage = PreferenceStorage.getInstance();
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
        await this.applyRealName(realName, storage);
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

  private async applyUserInfo(data: StudentApiContent | undefined, storage: PreferenceStorage): Promise<void> {
    if (!data) return;
    const realName = data.stuName || data.name || '';
    const studentId = data.stuNum || data.studentNumber || data.studentId || '';
    const major = data.major || '';
    const college = data.college || '';
    const classes = data.classes || data.clazz || '';
    await this.applyRealName(realName, storage);
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
        await this.loadCropImageSize(this.cropImageUri);
        this.resetCrop();
        this.showingCropper = true;
      }
    } catch (error) {
      console.error('InfoSettingsPage', `choose avatar failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '选择图片失败', duration: 1500 });
    }
  }

  /** 读取原图宽高，Cover 填充后按真实溢出量限制拖动范围。 */
  private async loadCropImageSize(uri: string): Promise<void> {
    try {
      const source = image.createImageSource(uri);
      const info = await source.getImageInfo();
      this.cropImageWidth = info.size.width;
      this.cropImageHeight = info.size.height;
      source.release();
    } catch (error) {
      console.warn('InfoSettingsPage', `read avatar size failed: ${JSON.stringify(error)}`);
      this.cropImageWidth = 0;
      this.cropImageHeight = 0;
    }
  }

  private cancelCrop(): void {
    this.showingCropper = false;
    this.cropImageUri = '';
    this.resetCrop();
  }

  private resetCrop(): void {
    this.cropScale = 1;
    this.cropRotation = 0;
    this.cropOffsetX = 0;
    this.cropOffsetY = 0;
  }

  /** Cover 填充后图片的显示宽度（px）。没有读到原图尺寸时按正方形处理。 */
  private cropBaseWidth(): number {
    if (this.cropImageWidth <= 0 || this.cropImageHeight <= 0) return this.CROP_SIZE;
    return this.CROP_SIZE * Math.max(1, this.cropImageWidth / this.cropImageHeight);
  }

  private cropBaseHeight(): number {
    if (this.cropImageWidth <= 0 || this.cropImageHeight <= 0) return this.CROP_SIZE;
    return this.CROP_SIZE * Math.max(1, this.cropImageHeight / this.cropImageWidth);
  }

  /** 放大后允许平移的范围：图片始终填满裁剪框，不露出底色。 */
  private cropPanLimitX(): number {
    return Math.max(0, (this.cropBaseWidth() * this.cropScale - this.CROP_SIZE) / 2);
  }

  private cropPanLimitY(): number {
    return Math.max(0, (this.cropBaseHeight() * this.cropScale - this.CROP_SIZE) / 2);
  }

  private clampCropOffset(): void {
    const limitX = this.cropPanLimitX();
    const limitY = this.cropPanLimitY();
    this.cropOffsetX = Math.min(limitX, Math.max(-limitX, this.cropOffsetX));
    this.cropOffsetY = Math.min(limitY, Math.max(-limitY, this.cropOffsetY));
  }

  private applyCropPan(offsetX: number, offsetY: number): void {
    const limitX = this.cropPanLimitX();
    const limitY = this.cropPanLimitY();
    this.cropOffsetX = Math.min(limitX, Math.max(-limitX, this.cropStartOffsetX + offsetX));
    this.cropOffsetY = Math.min(limitY, Math.max(-limitY, this.cropStartOffsetY + offsetY));
  }

  private applyCropScale(scale: number): void {
    this.cropScale = Math.min(4, Math.max(1, scale));
    this.clampCropOffset();
  }

  private rotateCrop(): void {
    this.cropRotation = (this.cropRotation + 90) % 360;
    // 旋转后可视区域变化，重新把平移量收进允许范围。
    this.clampCropOffset();
  }

  private async confirmCrop(): Promise<void> {
    if (!this.cropImageUri || this.cropperBusy) return;
    this.cropperBusy = true;
    const context = getContext(this) as common.UIAbilityContext;
    let localPath = '';
    try {
      // 先把裁剪框当前画面（含缩放/平移/旋转）截图，再关闭编辑器。
      const snapshot = await this.getUIContext().getComponentSnapshot().get('avatarCropBox');
      this.showingCropper = false;
      const packer = image.createImagePacker();
      const options: image.PackingOption = { format: 'image/jpeg', quality: 92 };
      const buffer = await packer.packing(snapshot, options);
      localPath = `${context.cacheDir}/avatar_${Date.now()}.jpg`;
      const file = fileIo.openSync(localPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, buffer);
      } finally {
        fileIo.closeSync(file);
      }
      this.avatarUrl = `file://${localPath}`;
    } catch (error) {
      console.error('InfoSettingsPage', `crop avatar failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '裁剪图片失败，请重试', duration: 1500 });
      this.cropperBusy = false;
      this.cropImageUri = '';
      return;
    }

    try {
      await this.uploadAvatar(context, localPath);
    } catch (error) {
      // 网络失败时保留本地裁剪结果，避免用户以为没换成功。
      await PreferenceStorage.getInstance().setAvatarUrl(`file://${localPath}`);
      console.warn('InfoSettingsPage', `avatar upload failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '头像已更新，服务器同步失败', duration: 1800 });
    } finally {
      this.cropperBusy = false;
      this.cropImageUri = '';
      this.resetCrop();
    }
  }

  /**
   * 上传裁剪后的本地文件。
   *
   * request.uploadFile 只给任务状态、拿不到响应体，所以“业务是否成功”用
   * /auth/me 的头像地址确认：地址为空、仍是旧地址都视为失败，保留本地裁剪图。
   */
  private async uploadAvatar(context: common.UIAbilityContext, localPath: string): Promise<void> {
    const storage = PreferenceStorage.getInstance();
    const previousAvatar = (await storage.getAvatarUrl()).trim();
    let token = (await storage.getAppAuthAccessToken()).trim();
    if (!token) {
      // 换设备/重装后内存里的应用令牌可能为空，先用已保存的学校凭据恢复一次。
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      token = (await storage.getAppAuthAccessToken()).trim();
    }
    if (!token) throw new Error('missing app auth token');
    const fileName = localPath.substring(localPath.lastIndexOf('/') + 1);
    const task = await request.uploadFile(context, {
      url: 'https://lyzyy.love:8081/api/v1/profile/avatar',
      method: 'POST',
      header: { 'Authorization': `Bearer ${token}` },
      files: [{ filename: fileName, name: 'avatar', uri: `internal://cache/${fileName}`, type: 'image/jpeg' }],
      data: [],
    });
    const states = await new Promise<Array<request.TaskState>>((resolve, reject) => {
      task.on('complete', (items: Array<request.TaskState>) => resolve(items));
      task.on('fail', (items: Array<request.TaskState>) => reject(new Error(JSON.stringify(items))));
    });
    if (states.length === 0 || states[0].responseCode !== 0) {
      throw new Error(`avatar upload task failed: ${JSON.stringify(states)}`);
    }
    const profile = await UserApi.getAppProfile();
    const updatedAvatar = (profile?.avatarUrl || '').trim();
    if (!updatedAvatar || updatedAvatar === previousAvatar) {
      throw new Error('avatar not updated on server');
    }
    await storage.setAvatarUrl(updatedAvatar);
    this.avatarUrl = updatedAvatar;
    promptAction.showToast({ message: '头像已同步', duration: 1200 });
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
        Column().width('100%').height('100%').backgroundColor('#111111');
        Stack() {
          Image(this.cropImageUri)
            .width(this.CROP_SIZE).height(this.CROP_SIZE)
            .objectFit(ImageFit.Cover)
            .scale({ x: this.cropScale, y: this.cropScale })
            .translate({ x: this.cropOffsetX, y: this.cropOffsetY })
            .rotate({ angle: this.cropRotation });
        }
        .id('avatarCropBox')
        .width(this.CROP_SIZE)
        .height(this.CROP_SIZE)
        .clip(true)
        .gesture(
          GestureGroup(GestureMode.Parallel,
            PanGesture({ fingers: 1, distance: 1 })
              .onActionStart(() => {
                this.cropStartOffsetX = this.cropOffsetX;
                this.cropStartOffsetY = this.cropOffsetY;
              })
              .onActionUpdate((event: GestureEvent) => {
                this.applyCropPan(event.offsetX, event.offsetY);
              }),
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.cropStartScale = this.cropScale;
              })
              .onActionUpdate((event: GestureEvent) => {
                this.applyCropScale(this.cropStartScale * event.scale);
              })
          )
        );
        // 圆形提示层只是参考线，不在 avatarCropBox 内，不会进截图。
        Circle().width(this.CROP_SIZE).height(this.CROP_SIZE).fill('#00000000')
          .stroke('#ffffffaa').strokeWidth(2);
      }.width('100%').layoutWeight(1);
      Row() {
        Column() {
          Text('↻').fontSize(42).fontColor('#999999');
          Text('旋转').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333');
        }.width('50%').onClick(() => this.rotateCrop());
        Column() {
          Text('⟲').fontSize(42).fontColor('#999999');
          Text('重置').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333');
        }.width('50%').onClick(() => this.resetCrop());
      }.width('100%').height(130).justifyContent(FlexAlign.SpaceAround).backgroundColor(Color.White);
    }.width('100%').height('100%').backgroundColor(Color.White);
  }

  @Builder
  private divider(): void {
    Divider().strokeWidth(1).color('#f2f2f2').margin({ left: 32, right: 24 });
  }

  @Builder
  private nicknameRow(): void {
    Row() {
      Text('昵称').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333');
      Blank().layoutWeight(1);
      Text(this.nickname).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333')
        .textAlign(TextAlign.End).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' });
      Text('›').fontSize(28).fontColor('#999999').margin({ left: 10 });
    }
    .width('100%').height(84).padding({ left: 32, right: 24 })
    .onClick(() => router.pushUrl({
      url: 'pages/profile/EditNamePage',
      params: { name: this.nickname }
    }));
    this.divider();
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
