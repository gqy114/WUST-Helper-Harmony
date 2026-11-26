import { PhotoCropImage } from '../../utils/PhotoCropImage';
import { image } from '@kit.ImageKit';
import { coverScale, cropOffset, sourceCrop } from '../../utils/ScheduleBackgroundCrop';
import { router, promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { ScheduleSettings, DEFAULT_SETTINGS } from '../../model/CourseModel';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';
import { ScheduleBackgroundService } from '../../utils/ScheduleBackgroundService';

interface BackgroundParams {
  aspect?: number;
}

@Entry
@Component
struct BackgroundSetting {
  @State private bgOpacity: number = DEFAULT_SETTINGS.bgOpacity;
  @State private fontSize: number = DEFAULT_SETTINGS.fontSize;
  @State private bgFullscreen: boolean = DEFAULT_SETTINGS.bgFullscreen;
  @State private italic: boolean = DEFAULT_SETTINGS.italic;
  @State private bgImage: string = DEFAULT_SETTINGS.bgImage;

  @State private draft: image.PixelMap | undefined = undefined;
  @State private frameWidth: number = 0;
  @State private zoom: number = 1;
  @State private offsetX: number = 0;
  @State private offsetY: number = 0;
  @State private busy: boolean = false;
  private aspect: number = 0;
  private imageWidth: number = 1;
  private imageHeight: number = 1;
  private stagingUri: string = '';
  private gestureZoom: number = 1;
  private gestureX: number = 0;
  private gestureY: number = 0;
  private active: boolean = true;

  aboutToAppear(): void {
    const params = router.getParams() as BackgroundParams | undefined;
    const aspect = params?.aspect ?? 0;
    if (aspect > 0 && Number.isFinite(aspect)) this.aspect = aspect;
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const settings = await PreferencesStorage.getInstance().getScheduleSettings();
    AppStorage.setOrCreate<ScheduleSettings>('scheduleSettings', settings);
    this.bgOpacity = settings.bgOpacity;
    this.fontSize = settings.fontSize;
    this.bgFullscreen = settings.bgFullscreen;
    this.italic = settings.italic;
    this.bgImage = settings.bgImage;
  }

  private async saveSettings(): Promise<void> {
    const settings: ScheduleSettings = {
      bgImage: this.bgImage,
      bgOpacity: this.bgOpacity,
      bgFullscreen: this.bgFullscreen,
      fontSize: this.fontSize,
      italic: this.italic,
    };
    // PreferencesStorage 负责持久化，系统 AppStorage 负责通知 @StorageLink。
    await PreferencesStorage.getInstance().setScheduleSettings(settings);
    AppStorage.setOrCreate<ScheduleSettings>('scheduleSettings', settings);
  }

  aboutToDisappear(): void {
    this.active = false;
    this.closeCrop();
  }

  onBackPress(): boolean {
    if (this.busy) return true;
    if (!this.draft) return false;
    this.closeCrop();
    return true;
  }

  private async pickBackgroundImage(): Promise<void> {
    if (this.busy) return;
    if (this.aspect <= 0) {
      promptAction.showToast({ message: '请返回课表，等待课表显示后再设置背景' });
      return;
    }
    this.busy = true;
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (!result.photoUris?.length || !this.active) return;
      const context = getContext(this) as common.UIAbilityContext;
      this.stagingUri = ScheduleBackgroundService.persist(context, result.photoUris[0]);
      const preview = await PhotoCropImage.decode(this.stagingUri);
      if (!this.active) {
        await preview.release();
        return;
      }
      this.draft = preview;
      const size = preview.getImageInfoSync().size;
      this.imageWidth = size.width;
      this.imageHeight = size.height;
      this.zoom = 1;
      this.offsetX = 0;
      this.offsetY = 0;
      this.frameWidth = 0;
    } catch (err) {
      this.closeCrop();
      promptAction.showToast({ message: '无法打开这张图片，请换一张试试' });
    } finally {
      this.busy = false;
    }
  }

  private closeCrop(): void {
    const previous = this.draft;
    this.draft = undefined;
    if (previous) previous.release().catch(() => {});
    if (this.stagingUri) {
      ScheduleBackgroundService.removeOwned(getContext(this) as common.UIAbilityContext, this.stagingUri);
      this.stagingUri = '';
    }
  }

  private frameHeight(): number {
    return this.frameWidth / this.aspect;
  }

  private imageScale(): number {
    return coverScale(this.imageWidth, this.imageHeight, this.frameWidth, this.frameHeight()) * this.zoom;
  }

  private previewZoom(): number {
    const contain = Math.min(this.frameWidth / this.imageWidth, this.frameHeight() / this.imageHeight);
    return contain > 0 ? this.imageScale() / contain : 1;
  }

  private moveImage(x: number, y: number): void {
    const scale = this.imageScale();
    this.offsetX = cropOffset(x, this.imageWidth * scale, this.frameWidth);
    this.offsetY = cropOffset(y, this.imageHeight * scale, this.frameHeight());
  }

  private zoomImage(zoom: number): void {
    const previous = this.zoom;
    this.zoom = Math.max(1, Math.min(5, zoom));
    this.moveImage(this.offsetX * this.zoom / previous, this.offsetY * this.zoom / previous);
  }

  private sizeCropFrame(areaWidth: number, areaHeight: number): void {
    const width = Math.min(areaWidth - 32, Math.max(0, areaHeight - 24) * this.aspect, 520);
    if (width <= 0 || width === this.frameWidth) return;
    const factor = this.frameWidth > 0 ? width / this.frameWidth : 1;
    this.frameWidth = width;
    this.moveImage(this.offsetX * factor, this.offsetY * factor);
  }

  private async applyCrop(): Promise<void> {
    if (!this.draft || !this.stagingUri || this.frameWidth <= 0 || this.busy) return;
    this.busy = true;
    const context = getContext(this) as common.UIAbilityContext;
    const oldImage = this.bgImage;
    const oldOpacity = this.bgOpacity;
    let croppedUri = '';
    try {
      const region = sourceCrop(this.imageWidth, this.imageHeight, this.frameWidth, this.frameHeight(),
        this.zoom, this.offsetX, this.offsetY);
      croppedUri = await ScheduleBackgroundService.saveCropped(context, this.stagingUri, region);
      this.bgImage = croppedUri;
      if (this.bgOpacity === 0) this.bgOpacity = 1;
      await this.saveSettings();
      ScheduleBackgroundService.removeOwned(context, oldImage);
      this.closeCrop();
      promptAction.showToast({ message: '背景已更新' });
    } catch (err) {
      this.bgImage = oldImage;
      this.bgOpacity = oldOpacity;
      ScheduleBackgroundService.removeOwned(context, croppedUri);
      promptAction.showToast({ message: '设置背景失败，保留了当前裁剪，请重试' });
    } finally {
      this.busy = false;
    }
  }

  @Builder
  private cropEditor() {
    Column() {
      Row() {
        Button('取消').fontColor('#555555').backgroundColor(Color.Transparent)
          .enabled(!this.busy).onClick(() => this.closeCrop())
        Text('裁剪课表背景').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#222222').layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button(this.busy ? '保存中' : '设为背景').fontColor('#008E70').backgroundColor(Color.Transparent)
          .enabled(!this.busy && this.frameWidth > 0).onClick(() => this.applyCrop())
      }.width('100%').height(56).backgroundColor(Color.White)
      Stack() {
        if (this.draft && this.frameWidth > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Stack() {
              Image(this.draft).width('100%').height('100%').objectFit(ImageFit.Contain).autoResize(false)
                .scale({ x: this.previewZoom(), y: this.previewZoom() })
            }.width('100%').height('100%').translate({ x: this.offsetX, y: this.offsetY })
            .hitTestBehavior(HitTestMode.None)
            Column().width('100%').height('100%').border({ width: 2, color: '#FFFFFF' })
              .hitTestBehavior(HitTestMode.None)
          }.width(this.frameWidth).height(this.frameHeight()).clip(true).backgroundColor(Color.Black)
          .gesture(GestureGroup(GestureMode.Exclusive,
            PinchGesture({ fingers: 2 }).onActionStart(() => { this.gestureZoom = this.zoom; })
              .onActionUpdate((event: GestureEvent) => { if (!this.busy) this.zoomImage(this.gestureZoom * event.scale); }),
            PanGesture({ fingers: 1, direction: PanDirection.All, distance: 3 })
              .onActionStart(() => { this.gestureX = this.offsetX; this.gestureY = this.offsetY; })
              .onActionUpdate((event: GestureEvent) => {
                if (!this.busy) this.moveImage(this.gestureX + event.offsetX, this.gestureY + event.offsetY);
              })
          ))
        }
      }.width('100%').layoutWeight(1).backgroundColor('#202124')
      .onAreaChange((_, area) =>
        this.sizeCropFrame(Number.parseFloat(String(area.width)), Number.parseFloat(String(area.height))))
      Text('白框内区域将按当前课表页的显示比例保存')
        .fontSize(12).fontColor('#666666').padding({ top: 8 })
      Row({ space: 12 }) {
        Text('缩放').fontSize(14).fontColor('#555555')
        Slider({ value: this.zoom, min: 1, max: 5, step: 0.05 }).layoutWeight(1)
          .enabled(!this.busy).onChange((value: number) => this.zoomImage(value))
        Button('重置').fontColor('#008E70').backgroundColor(Color.Transparent).enabled(!this.busy)
          .onClick(() => { this.zoomImage(1); this.moveImage(0, 0); })
      }.width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor(Color.White)
    }.width('100%').height('100%').backgroundColor(Color.White)
  }

  private async clearBackgroundImage(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const oldImage = this.bgImage;
    try {
      this.bgImage = '';
      await this.saveSettings();
      ScheduleBackgroundService.removeOwned(context, oldImage);
      promptAction.showToast({ message: '已清除背景', duration: 1500 });
    } catch (err) {
      this.bgImage = oldImage;
      console.error('BackgroundSetting', `clear background failed: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '清除背景失败', duration: 1500 });
    }
  }

  build() {
    Stack() {
      this.settingsContent()
      if (this.draft) {
        this.cropEditor()
      }
    }.width('100%').height('100%')
  }

  @Builder
  private settingsContent() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor('#333333')
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })

        Text('背景~~字体')
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })

        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 16 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              if (this.bgImage) {
                Image(this.bgImage)
                  .width('100%')
                  .height(320)
                  .objectFit(ImageFit.Contain)
                  .opacity(this.bgOpacity)
              } else {
                Column()
                  .width('100%')
                  .height(320)
                  .backgroundColor('#F5F5F5')
                Text('暂无背景')
                  .fontSize(14)
                  .fontColor('#999999')
              }
            }
            .width('100%')
            .height(320)
            .onClick(() => {
              this.pickBackgroundImage();
            })

            Text('清除背景')
              .fontSize(16)
              .fontColor('#FF4444')
              .width('100%')
              .height(48)
              .textAlign(TextAlign.Center)
              .backgroundColor('#FFFFFF')
              .onClick(() => {
                this.clearBackgroundImage();
              })
          }
          .width('90%')
          .borderRadius(12)
          .clip(true)
          .margin({ top: 16 })
          .backgroundColor('#FFFFFF')

          Text('点击上方图片可选择背景')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12, bottom: 16 })

          Column() {
            Row() {
              Text('背景全屏')
                .fontSize(16)
                .fontColor('#333333')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.bgFullscreen })
                .selectedColor('#4CAF50')
                .onChange((isOn: boolean) => {
                  this.bgFullscreen = isOn;
                  this.saveSettings();
                })
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })

            Row() {
              Text('不透明度')
                .fontSize(16)
                .fontColor('#333333')
                .width(80)
              Slider({
                value: this.bgOpacity,
                min: 0,
                max: 1,
                step: 0.05,
                style: SliderStyle.OutSet
              })
                .blockColor('#009688')
                .selectedColor('#009688')
                .trackColor('#DDDDDD')
                .layoutWeight(1)
                .margin({ left: 8, right: 8 })
                .onChange((value: number) => {
                  this.bgOpacity = value;
                  this.saveSettings();
                })
              Text(`${Math.round(this.bgOpacity * 100)}%`)
                .fontSize(14)
                .fontColor('#666666')
                .width(50)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })

            Row() {
              Text('字体大小')
                .fontSize(16)
                .fontColor('#333333')
                .width(80)
              Slider({
                value: this.fontSize,
                min: 9,
                max: 16,
                step: 1,
                style: SliderStyle.OutSet
              })
                .blockColor('#009688')
                .selectedColor('#009688')
                .trackColor('#DDDDDD')
                .layoutWeight(1)
                .margin({ left: 8, right: 8 })
                .onChange((value: number) => {
                  this.fontSize = value;
                  this.saveSettings();
                })
              Text(`${this.fontSize}sp`)
                .fontSize(14)
                .fontColor('#666666')
                .width(50)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })

            Row() {
              Text('斜体显示')
                .fontSize(16)
                .fontColor('#333333')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.italic })
                .selectedColor('#4CAF50')
                .onChange((isOn: boolean) => {
                  this.italic = isOn;
                  this.saveSettings();
                })
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .margin({ top: 8 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
