import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import uniformTypeDescriptor from '@ohos.data.uniformTypeDescriptor';
import { AppStorage } from '../../store/AppStorage';
import { DynamicScheduleApi } from '../../net/DynamicScheduleApi';
import {
  initialScheduleShareState,
  ScheduleShareController,
  ScheduleShareState
} from '../../model/ScheduleShareState';

@Entry
@Component
struct CourseSharePage {
  @State private nickname: string = '我的';
  @State private avatarUrl: string = '';
  @State private share: ScheduleShareState = initialScheduleShareState();
  private shareController: ScheduleShareController = new ScheduleShareController(
    (semester: string, allowExtra: boolean) => DynamicScheduleApi.createInvite(semester, allowExtra)
  );
  private timer: number = -1;
  private appearanceId: number = 0;

  aboutToAppear(): void {
    const appearanceId: number = ++this.appearanceId;
    this.shareController.onChange = (state: ScheduleShareState): void => { this.share = state; };
    if (this.timer !== -1) clearInterval(this.timer);
    this.timer = setInterval((): void => this.shareController.tick(), 1000);
    this.loadProfile(appearanceId);
  }

  aboutToDisappear(): void {
    ++this.appearanceId;
    this.shareController.dispose();
    if (this.timer !== -1) clearInterval(this.timer);
    this.timer = -1;
  }

  private async loadProfile(appearanceId: number): Promise<void> {
    try {
      const storage: AppStorage = AppStorage.getInstance();
      const nickname: string = (await storage.getRealName()) || (await storage.getUserName()) || '我的';
      const avatarUrl: string = await storage.getAvatarUrl();
      const semester: string = (await storage.getSemester()).trim() ||
        (await storage.getSelectSemester()).trim();
      if (appearanceId !== this.appearanceId) return;
      this.nickname = nickname;
      this.avatarUrl = avatarUrl;
      await this.shareController.initialize(nickname, semester);
    } catch (_) {
      if (appearanceId !== this.appearanceId) return;
      this.share = {
        isDynamic: this.share.isDynamic,
        allowExtra: this.share.allowExtra,
        semester: '',
        loading: false,
        qrValue: '',
        expiresIn: 0,
        errorMsg: '读取分享信息失败，请重新进入页面'
      };
    }
  }

  private countdownText(): string {
    const minutes: number = Math.floor(this.share.expiresIn / 60);
    const seconds: number = this.share.expiresIn % 60;
    return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds} 内可扫码`;
  }

  /** 把二维码区域截图写到应用缓存，返回文件路径。 */
  private async createQrFile(): Promise<string> {
    const pixelMap: image.PixelMap = await this.getUIContext().getComponentSnapshot().get('courseShareQr');
    const packer: image.ImagePacker = image.createImagePacker();
    const buffer: ArrayBuffer = await packer.packing(pixelMap, { format: 'image/png', quality: 100 });
    packer.release();
    const context = getContext(this) as common.UIAbilityContext;
    const path = `${context.cacheDir}/course_qr_${Date.now()}.png`;
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
    try {
      fileIo.writeSync(file.fd, buffer);
    } finally {
      fileIo.closeSync(file);
    }
    return path;
  }

  private copyToUri(sourcePath: string, targetUri: string): void {
    const source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
    const target = fileIo.openSync(targetUri, fileIo.OpenMode.WRITE_ONLY);
    try {
      const chunk = new ArrayBuffer(64 * 1024);
      let read = 0;
      while ((read = fileIo.readSync(source.fd, chunk)) > 0) {
        fileIo.writeSync(target.fd, chunk, { length: read });
      }
    } finally {
      fileIo.closeSync(source);
      fileIo.closeSync(target);
    }
  }

  private async saveQrImage(): Promise<void> {
    if (this.share.qrValue.length === 0) {
      promptAction.showToast({ message: '二维码还没生成，请稍后再试', duration: 1800 });
      return;
    }
    try {
      const path = await this.createQrFile();
      const helper = photoAccessHelper.getPhotoAccessHelper(getContext(this));
      const configs: photoAccessHelper.PhotoCreationConfig[] = [{
        title: '课表二维码',
        fileNameExtension: 'png',
        photoType: photoAccessHelper.PhotoType.IMAGE
      }];
      const uris = await helper.showAssetsCreationDialog([`file://${path}`], configs);
      if (!uris || uris.length === 0) {
        promptAction.showToast({ message: '已取消保存', duration: 1500 });
        return;
      }
      this.copyToUri(path, uris[0]);
      promptAction.showToast({ message: '已保存到相册', duration: 1800 });
    } catch (error) {
      console.warn('CourseSharePage', `save qr failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '保存失败，请授予相册权限后重试', duration: 2200 });
    }
  }

  private async shareQrImage(): Promise<void> {
    if (this.share.qrValue.length === 0) {
      promptAction.showToast({ message: '二维码还没生成，请稍后再试', duration: 1800 });
      return;
    }
    try {
      const path = await this.createQrFile();
      const data = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PNG,
        uri: `file://${path}`,
        title: '课表二维码'
      });
      const controller = new systemShare.ShareController(data);
      const context = getContext(this) as common.UIAbilityContext;
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (error) {
      console.warn('CourseSharePage', `share qr failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '分享失败，请重试', duration: 1800 });
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(44).fontColor('#222222').width(48).textAlign(TextAlign.Center)
          .onClick(() => router.back());
        Text('课表分享').fontSize(27).fontWeight(FontWeight.Bold).fontColor('#222222').margin({ left: 18 });
        Blank().layoutWeight(1);
        Text('授权管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2A8F70');
      }.width('100%').height(88).padding({ left: 14, right: 18 }).backgroundColor(Color.White);

      Scroll() {
        Column() {
          Column() {
            Row() {
              Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(58).height(58)
                .borderRadius(29).objectFit(ImageFit.Cover);
              Column() {
                Text(`${this.nickname}的课表`).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#222222');
                Text(this.share.semester || '未选择学期').fontSize(18).fontColor('#888888').margin({ top: 8 });
              }.alignItems(HorizontalAlign.Start).margin({ left: 18 });
            }.width('100%').padding({ left: 24, top: 24, bottom: 24 });
            Column() {
              if (this.share.qrValue.length > 0) {
                QRCode(this.share.qrValue).width(270).height(270).backgroundColor(Color.White);
              } else {
                Column() {
                  if (this.share.loading) {
                    LoadingProgress().width(48).height(48).color('#20C894');
                  }
                  Text(this.share.loading ? '正在生成二维码…' :
                    (this.share.errorMsg || '正在读取分享信息…'))
                    .fontSize(16).fontColor('#888888').textAlign(TextAlign.Center)
                    .margin({ top: this.share.loading ? 14 : 0 });
                }.width(270).height(270).justifyContent(FlexAlign.Center).padding({ left: 18, right: 18 });
              }
              Text('使用武科大助手扫一扫').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#444444').margin({ top: 16 });
              Row() {
                if (this.share.qrValue.length > 0) {
                  Text(this.share.isDynamic ? this.countdownText() : '使用武科大助手扫码')
                    .fontSize(16).fontColor('#999999');
                }
                if (this.share.isDynamic) {
                  Text('↻ 刷新').fontSize(18).fontWeight(FontWeight.Bold)
                    .fontColor(this.share.loading ? '#AAAAAA' : '#2A8F70').margin({ left: 20 })
                    .enabled(!this.share.loading).onClick(() => this.shareController.refresh());
                }
              }.margin({ top: 12 });
            }.width('100%').padding({ top: 20, bottom: 20 }).id('courseShareQr');
            Divider().strokeWidth(1).color('#E5EAE8').margin({ left: 24, right: 24 });
            Row() {
              Column() {
                Text('允许查看额外安排').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333');
                Text('包括你手动添加的课程').fontSize(16).fontColor('#999999').margin({ top: 8 });
              }.alignItems(HorizontalAlign.Start).layoutWeight(1);
              Toggle({ type: ToggleType.Switch, isOn: this.share.allowExtra }).selectedColor('#2A8F70')
                .enabled(this.share.isDynamic && !this.share.loading)
                .onChange((value: boolean) => { this.shareController.setAllowExtra(value); });
            }.width('100%').padding({ left: 24, right: 24, top: 24, bottom: 28 });
          }.width('calc(100% - 32vp)').backgroundColor(Color.White).borderRadius(28);

          Row() {
            Text('⇄').fontSize(28).fontColor('#2A8F70');
            Text(this.share.isDynamic ? '切换到普通课表' : '切换到动态课表')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2A8F70').margin({ left: 12 });
          }.margin({ top: 26 }).onClick(() => this.shareController.setDynamic(!this.share.isDynamic));
          Text(this.share.isDynamic ? '动态课表允许他人实时查看你的课表变化。\n需使用安卓版本武科大助手 5.3.0.158 及以上版本。' : '普通课表二维码仅包含当前课表档案，可供武科大助手扫码导入。')
            .fontSize(16).fontColor('#999999').textAlign(TextAlign.Center).lineHeight(28).margin({ top: 28, bottom: 30 });
        }.width('100%').padding({ top: 44, bottom: 24 }).alignItems(HorizontalAlign.Center);
      }.layoutWeight(1).backgroundColor('#F7F8F7');

      Row() {
        Button('保存图片').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2A8F70')
          .backgroundColor('#EEF8F4').layoutWeight(1).height(60).borderRadius(20)
          .onClick(() => { this.saveQrImage(); });
        Button('分享二维码').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor('#20C894').layoutWeight(1.35).height(60).borderRadius(20).margin({ left: 16 })
          .onClick(() => { this.shareQrImage(); });
      }.width('100%').padding({ left: 24, right: 24, top: 16, bottom: 18 }).backgroundColor(Color.White);
    }.width('100%').height('100%').backgroundColor('#F7F8F7');
  }
}
