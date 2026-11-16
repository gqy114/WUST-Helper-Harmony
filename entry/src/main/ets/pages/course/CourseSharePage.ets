import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import uniformTypeDescriptor from '@ohos.data.uniformTypeDescriptor';
import { AppStorage } from '../../store/AppStorage';
import { CourseData } from '../../model/CourseModel';
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
  // 普通课表二维码的实际内容：紧凑课表档案（扫码导入用）。
  private staticQrPayload: string = '';
  // 课程多时拆成多张二维码，扫码端依次扫完再导入。
  @State private qrParts: string[] = [];
  // 同一份课表的多张二维码共享这个标识，扫码端据此拒绝混扫。
  private shareId: string = '';
  // 华为文档：QRCode 组件最多支持 512 个字符，超过会被截断。
  private static readonly QR_MAX_CHARS = 500;

  aboutToAppear(): void {
    const appearanceId: number = ++this.appearanceId;
    this.shareController.onChange = (state: ScheduleShareState): void => {
      if (!state.isDynamic && state.qrValue.length > 0) {
        if (this.staticQrPayload.length === 0) {
          this.qrParts = [];
          state.qrValue = '';
          state.errorMsg = '当前课表没有课程，暂无可分享内容';
        } else {
          const parts = CourseSharePage.chunkify(this.staticQrPayload, this.shareId);
          this.qrParts = parts;
          if (parts.length === 0) {
            state.qrValue = '';
            state.errorMsg = '课表内容过长，无法生成二维码，请改用动态课表分享';
          } else {
            state.qrValue = parts[0];
            state.errorMsg = parts.length > 1 ? `课程较多，请依次扫描 ${parts.length} 张二维码` : '';
          }
        }
      } else {
        this.qrParts = [];
      }
      this.share = state;
    };
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
      try {
        const courses = await storage.getCurrentCourses();
        this.staticQrPayload = courses.length > 0
          ? CourseSharePage.encodeArchive(`${nickname}的课表`, semester, courses)
          : '';
        // 同一份课表的多张二维码共享标识，扫码端会拒绝把两份课表混在一起。
        this.shareId = CourseSharePage.makeShareId();
      } catch (_) {
        this.staticQrPayload = '';
        this.shareId = '';
      }
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

  private static cleanField(value: string): string {
    return (value || '').replace(/[|;~\r\n]/g, ' ').trim();
  }

  /**
   * 把课表压缩成便于扫码的文本：
   * WUSTC1|学期|名称|课程1;课程2;...
   * 每门课：课程名~教师~周几~开始节~结束节~周次~地点
   * 鸿蒙端扫码导入按同一格式解析，长度可控在 QRCode 组件的 512 字符内。
   */
  static encodeArchive(name: string, semester: string, courses: CourseData[]): string {
    const head = `WUSTC1|${CourseSharePage.cleanField(semester)}|${CourseSharePage.cleanField(name)}`;
    const rows: string[] = [];
    for (let i = 0; i < courses.length; i++) {
      const course = courses[i];
      rows.push([
        CourseSharePage.cleanField(course.courseName),
        CourseSharePage.cleanField(course.teacher),
        `${course.dayOfWeek}`,
        `${course.startPeriod}`,
        `${course.endPeriod}`,
        CourseSharePage.cleanField(course.weekRanges),
        CourseSharePage.cleanField(course.location),
        // 物理实验标记与具体日期要一并带上，否则导入后信息丢失。
        course.isPhysicalExperiment ? '1' : '0',
        CourseSharePage.cleanField(course.physicalDate || '')
      ].join('~'));
    }
    return `${head}|${rows.join(';')}`;
  }

  static makeShareId(): string {
    return `${Date.now().toString(36)}${Math.floor(Math.random() * 0xffff).toString(16)}`;
  }

  /** 把紧凑课表拆成多张二维码；超过 9 张视为无法分享。 */
  static chunkify(payload: string, shareId: string): string[] {
    const max = CourseSharePage.QR_MAX_CHARS;
    if (payload.length <= max) return [payload];
    const id = shareId || CourseSharePage.makeShareId();
    // 预留 "WUSTC2|<shareId>|9/9|" 前缀空间。
    const chunkSize = max - 12 - id.length;
    if (chunkSize <= 0) return [];
    const raw: string[] = [];
    // 按 Unicode 码点切分：直接 substring 会把 emoji/生僻字的代理对从中间截断，扫码后变乱码。
    const chars: string[] = [];
    for (const ch of payload) {
      chars.push(ch);
    }
    for (let start = 0; start < chars.length; start += chunkSize) {
      raw.push(chars.slice(start, start + chunkSize).join(''));
    }
    if (raw.length > 9) return [];
    const total = raw.length;
    const parts: string[] = [];
    for (let i = 0; i < raw.length; i++) {
      parts.push(`WUSTC2|${id}|${i + 1}/${total}|${raw[i]}`);
    }
    return parts;
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
      // SDK 要求传应用文件 URI，不能手拼 file:// + 路径。
      const uris = await helper.showAssetsCreationDialog([fileUri.getUriFromPath(path)], configs);
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
        uri: fileUri.getUriFromPath(path),
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
              if (!this.share.isDynamic && this.qrParts.length > 0) {
                Column() {
                  ForEach(this.qrParts, (part: string, index: number) => {
                    Column() {
                      QRCode(part).width(240).height(240).backgroundColor(Color.White);
                      Text(this.qrParts.length > 1 ? `第 ${index + 1} / ${this.qrParts.length} 张` : '')
                        .fontSize(13).fontColor('#888888').margin({ top: 6 });
                    }.margin({ bottom: 12 });
                  }, (part: string, index: number) => `${index}-${part.length}`);
                }
              } else if (this.share.qrValue.length > 0) {
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
