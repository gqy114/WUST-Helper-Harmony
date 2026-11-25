import { PhotoCropImage } from '../../utils/PhotoCropImage';
import { coverScale, cropOffset, sourceCrop } from '../../utils/ScheduleBackgroundCrop';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
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
  private cropImageUri: string = '';
  @State private cropPreview: image.PixelMap | undefined = undefined;
  @State private cropScale: number = 1;
  @State private cropRotation: number = 0;
  @State private cropOffsetX: number = 0;
  @State private cropOffsetY: number = 0;
  @State private cropperBusy: boolean = false;
  @State private showingCropper: boolean = false;
  // 原图尺寸：用于计算 Cover 填充后左右/上下可平移的范围。
  @State private cropImageWidth: number = 0;
  @State private cropImageHeight: number = 0;
  @State private cropSize: number = 280;
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
    console.info('InfoSettingsPage', 'load profile start');
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
        console.info('InfoSettingsPage', `apply profile fields=${data ? Object.keys(data).length : 0}`);
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
    if (this.cropperBusy) return;
    this.cropperBusy = true;
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (!result.photoUris?.length) return;
      const uri = result.photoUris[0];
      const preview = await PhotoCropImage.decode(uri);
      const size = preview.getImageInfoSync().size;
      this.cropImageUri = uri;
      this.cropImageWidth = size.width;
      this.cropImageHeight = size.height;
      this.cropPreview = preview;
      this.resetCrop();
      this.showingCropper = true;
    } catch {
      promptAction.showToast({ message: '无法打开这张图片，请换一张试试' });
    } finally {
      this.cropperBusy = false;
    }
  }

  private cancelCrop(): void {
    this.showingCropper = false;
    this.cropImageUri = '';
    const preview = this.cropPreview;
    this.cropPreview = undefined;
    if (preview) preview.release().catch(() => {});
    this.resetCrop();
  }

  onBackPress(): boolean {
    if (this.cropperBusy) return true;
    if (!this.showingCropper) return false;
    this.cancelCrop();
    return true;
  }

  aboutToDisappear(): void {
    this.cancelCrop();
  }

  private resetCrop(): void {
    this.cropScale = 1;
    this.cropRotation = 0;
    this.cropOffsetX = 0;
    this.cropOffsetY = 0;
  }

  private rotatedWidth(): number {
    return this.cropRotation % 180 === 0 ? this.cropImageWidth : this.cropImageHeight;
  }

  private rotatedHeight(): number {
    return this.cropRotation % 180 === 0 ? this.cropImageHeight : this.cropImageWidth;
  }

  private cover(): number {
    return coverScale(this.rotatedWidth(), this.rotatedHeight(), this.cropSize, this.cropSize);
  }

  private previewZoom(): number {
    return this.cover() * this.cropScale /
      Math.min(this.cropSize / this.cropImageWidth, this.cropSize / this.cropImageHeight);
  }

  private moveCrop(x: number, y: number): void {
    const scale = this.cover() * this.cropScale;
    this.cropOffsetX = cropOffset(x, this.rotatedWidth() * scale, this.cropSize);
    this.cropOffsetY = cropOffset(y, this.rotatedHeight() * scale, this.cropSize);
  }

  private applyCropScale(scale: number): void {
    const previous = this.cropScale;
    this.cropScale = Math.min(5, Math.max(1, scale));
    this.moveCrop(this.cropOffsetX * this.cropScale / previous, this.cropOffsetY * this.cropScale / previous);
  }

  private rotateCrop(): void {
    const previousX = this.cropOffsetX;
    const previousY = this.cropOffsetY;
    this.cropRotation = (this.cropRotation + 90) % 360;
    this.moveCrop(-previousY, previousX);
  }

  private async confirmCrop(): Promise<void> {
    if (!this.cropImageUri || !this.cropPreview || this.cropperBusy) return;
    this.cropperBusy = true;
    const storage = PreferenceStorage.getInstance();
    const sessionEpoch = storage.getSessionEpoch();
    const sessionSid = (await storage.getStudentId()).trim();
    try {
      if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) throw new Error('account changed');
      const region = sourceCrop(this.rotatedWidth(), this.rotatedHeight(), this.cropSize, this.cropSize,
        this.cropScale, this.cropOffsetX, this.cropOffsetY);
      const pixels = await PhotoCropImage.crop(this.cropImageUri, region, this.cropRotation);
      const packer = image.createImagePacker();
      try {
        const size = pixels.getImageInfoSync().size;
        if (size.width > 640) await pixels.scale(640 / size.width, 640 / size.width);
        const jpeg = await packer.packing(pixels, { format: 'image/jpeg', quality: 92 });
        await this.uploadAvatar(jpeg, sessionSid, sessionEpoch);
      } finally {
        await packer.release().catch(() => {});
        await pixels.release().catch(() => {});
      }
      this.cancelCrop();
      promptAction.showToast({ message: '头像已同步' });
    } catch {
      if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) {
        this.cancelCrop();
        promptAction.showToast({ message: '账号已切换，本次头像修改已取消' });
      } else {
        promptAction.showToast({ message: '头像未能同步，请检查登录或网络后重试' });
      }
    } finally {
      this.cropperBusy = false;
    }
  }

  /** 账号或会话代次是否已变化（切号后旧操作必须作废）。 */
  private async isAccountChanged(storage: PreferenceStorage, sid: string, epoch: number): Promise<boolean> {
    if (storage.getSessionEpoch() !== epoch) return true;
    return (await storage.getStudentId()).trim() !== sid;
  }

  private async uploadAvatar(jpeg: ArrayBuffer, sessionSid: string, sessionEpoch: number): Promise<void> {
    const storage = PreferenceStorage.getInstance();
    if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) throw new Error('account changed');
    let token = (await storage.getAppAuthAccessToken()).trim();
    if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) throw new Error('account changed');
    let response = token ? await UserApi.uploadAppAvatar(jpeg, token) : undefined;
    if (!response || response.code === 401) {
      if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) throw new Error('account changed');
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) throw new Error('account changed');
      token = (await storage.getAppAuthAccessToken()).trim();
      if (!token) throw new Error('missing app auth token');
      if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) throw new Error('account changed');
      response = await UserApi.uploadAppAvatar(jpeg, token);
    }
    const updatedAvatar = response.data?.avatarUrl?.trim() || '';
    if (response.code !== 200 || !updatedAvatar) throw new Error('avatar rejected by server');
    if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) throw new Error('account changed');
    if (!(await storage.setAvatarUrlForAccount(sessionEpoch, sessionSid, updatedAvatar))) {
      throw new Error('account changed');
    }
    if (await this.isAccountChanged(storage, sessionSid, sessionEpoch)) {
      throw new Error('account changed');
    }
    this.avatarUrl = updatedAvatar;
  }

  @Builder
  private cropperView(): void {
    Column() {
      Row() {
        Button('取消').fontColor('#555555').backgroundColor(Color.Transparent)
          .enabled(!this.cropperBusy).onClick(() => this.cancelCrop())
        Text('裁剪头像').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#111111')
          .layoutWeight(1).textAlign(TextAlign.Center)
        Button(this.cropperBusy ? '上传中' : '上传头像').fontColor('#008E70').backgroundColor(Color.Transparent)
          .enabled(!this.cropperBusy).onClick(() => this.confirmCrop())
      }.width('100%').height(56)
      Stack({ alignContent: Alignment.Center }) {
        if (this.cropPreview) {
          Stack({ alignContent: Alignment.Center }) {
            Stack() {
              Image(this.cropPreview).width('100%').height('100%').objectFit(ImageFit.Contain).autoResize(false)
                .scale({ x: this.previewZoom(), y: this.previewZoom() })
                .rotate({ angle: this.cropRotation })
            }.width('100%').height('100%').translate({ x: this.cropOffsetX, y: this.cropOffsetY })
            .hitTestBehavior(HitTestMode.None)
            Circle().width('100%').height('100%').fill(Color.Transparent)
              .stroke('#FFFFFF').strokeWidth(1).hitTestBehavior(HitTestMode.None)
          }.width(this.cropSize).height(this.cropSize).clip(true).backgroundColor(Color.Black)
          .gesture(GestureGroup(GestureMode.Parallel,
            PanGesture({ fingers: 1, distance: 3 })
              .onActionStart(() => { this.cropStartOffsetX = this.cropOffsetX; this.cropStartOffsetY = this.cropOffsetY; })
              .onActionUpdate((event: GestureEvent) => {
                if (!this.cropperBusy) this.moveCrop(this.cropStartOffsetX + event.offsetX, this.cropStartOffsetY + event.offsetY);
              }),
            PinchGesture({ fingers: 2 })
              .onActionStart(() => { this.cropStartScale = this.cropScale; })
              .onActionUpdate((event: GestureEvent) => {
                if (!this.cropperBusy) this.applyCropScale(this.cropStartScale * event.scale);
              })
          ))
        }
      }.width('100%').layoutWeight(1).backgroundColor('#202124')
      .onAreaChange((_, area) => {
        const size = Math.min(320, Number.parseFloat(String(area.width)) - 32, Number.parseFloat(String(area.height)) - 24);
        if (size > 0 && size !== this.cropSize) {
          const factor = size / this.cropSize;
          this.cropSize = size;
          this.moveCrop(this.cropOffsetX * factor, this.cropOffsetY * factor);
        }
      })
      Row({ space: 6 }) {
        Text('缩放').fontSize(13)
        Slider({ value: this.cropScale, min: 1, max: 5, step: 0.05 }).layoutWeight(1)
          .enabled(!this.cropperBusy).onChange((value: number) => this.applyCropScale(value))
        Button('旋转').backgroundColor(Color.Transparent).fontColor('#008E70')
          .enabled(!this.cropperBusy).onClick(() => this.rotateCrop())
        Button('重置').backgroundColor(Color.Transparent).fontColor('#008E70')
          .enabled(!this.cropperBusy).onClick(() => this.resetCrop())
      }.width('100%').height(60).padding({ left: 16, right: 8 })
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
