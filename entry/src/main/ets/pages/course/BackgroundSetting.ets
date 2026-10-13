import { router, promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { ScheduleSettings, DEFAULT_SETTINGS } from '../../model/CourseModel';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';

@Entry
@Component
struct BackgroundSetting {
  @State private bgOpacity: number = DEFAULT_SETTINGS.bgOpacity;
  @State private fontSize: number = DEFAULT_SETTINGS.fontSize;
  @State private bgFullscreen: boolean = DEFAULT_SETTINGS.bgFullscreen;
  @State private italic: boolean = DEFAULT_SETTINGS.italic;
  @State private bgImage: string = DEFAULT_SETTINGS.bgImage;

  aboutToAppear(): void {
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

  private async pickBackgroundImage(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;

      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      if (result.photoUris && result.photoUris.length > 0) {
        this.bgImage = result.photoUris[0];
        await this.saveSettings();
        console.info('BackgroundSetting', `selected background image: ${this.bgImage}`);
      }
    } catch (err) {
      console.error('BackgroundSetting', `pick background image failed: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '选择图片失败', duration: 1500 });
    }
  }

  build() {
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
                  .objectFit(ImageFit.Cover)
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
                this.bgImage = '';
                this.saveSettings();
                promptAction.showToast({ message: '已清除背景', duration: 1500 });
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
