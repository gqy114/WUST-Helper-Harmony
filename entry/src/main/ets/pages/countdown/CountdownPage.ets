import { promptAction, router } from '@kit.ArkUI';

@Entry
@Component
struct CountdownPage {
  @State private currentDate: string = '';
  @State private eventCount: number = 0;
  @State private showAddDialog: boolean = false;
  @State private dialogOpacity: number = 0;
  @State private dialogScale: number = 0.85;
  @State private courseName: string = '';
  @State private examTime: string = '';
  @State private examTimestamp: number = 0;
  @State private remark: string = '';
  @State private showTimePicker: boolean = false;
  @State private timePickerOpacity: number = 0;
  @State private timePickerScale: number = 0.94;
  @State private pickerDate: Date = new Date();
  @State private pickerHour: number = 0;
  @State private pickerMinute: number = 0;
  @State private showPastTimeWarning: boolean = false;
  @State private warningOpacity: number = 0;
  @State private warningScale: number = 0.88;

  aboutToAppear(): void {
    this.updateDate();
  }

  private updateDate(): void {
    const date = new Date();
    const year = date.getFullYear().toString();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    this.currentDate = year + '-' + month + '-' + day;
  }

  private addCountdown(): void {
    this.showAddDialog = true;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.dialogOpacity = 1;
      this.dialogScale = 1;
    });
  }

  private closeAddDialog(): void {
    animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.dialogOpacity = 0;
      this.dialogScale = 0.85;
    });
    setTimeout(() => {
      this.showAddDialog = false;
    }, 180);
  }

  private saveCountdown(): void {
    if (this.courseName.trim().length === 0) {
      promptAction.showToast({ message: '请输入课程名称', duration: 1500 });
      return;
    }
    if (this.examTimestamp <= Date.now()) {
      this.showInvalidTimeWarning();
      return;
    }
    this.eventCount++;
    this.closeAddDialog();
    promptAction.showToast({ message: '已添加倒计时', duration: 1500 });
  }

  private initializePickerWithCurrentTime(): void {
    const now = new Date();
    this.pickerDate = new Date(now.getTime());
    this.pickerHour = now.getHours();
    this.pickerMinute = now.getMinutes();
  }

  private getPickerTime(): Date {
    return new Date(
      this.pickerDate.getFullYear(),
      this.pickerDate.getMonth(),
      this.pickerDate.getDate(),
      this.pickerHour,
      this.pickerMinute,
      0,
      0
    );
  }

  private formatExamTime(date: Date): string {
    const year = date.getFullYear().toString();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return year + '-' + month + '-' + day + ' ' + hour + ':' + minute;
  }

  private openTimePicker(resetToNow: boolean): void {
    if (resetToNow) {
      this.initializePickerWithCurrentTime();
    }
    this.showTimePicker = true;
    this.timePickerOpacity = 0;
    this.timePickerScale = 0.94;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.timePickerOpacity = 1;
      this.timePickerScale = 1;
    });
  }

  private closeTimePicker(): void {
    animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.timePickerOpacity = 0;
      this.timePickerScale = 0.94;
    });
    setTimeout(() => {
      this.showTimePicker = false;
    }, 180);
  }

  private confirmPickerTime(): void {
    const selectedTime = this.getPickerTime();
    if (selectedTime.getTime() <= Date.now()) {
      this.showTimePicker = false;
      this.showInvalidTimeWarning();
      return;
    }
    this.examTimestamp = selectedTime.getTime();
    this.examTime = this.formatExamTime(selectedTime);
    this.closeTimePicker();
  }

  private showInvalidTimeWarning(): void {
    this.showPastTimeWarning = true;
    this.warningOpacity = 0;
    this.warningScale = 0.88;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.warningOpacity = 1;
      this.warningScale = 1;
    });
  }

  private returnToTimePicker(): void {
    animateTo({ duration: 160, curve: Curve.EaseIn }, () => {
      this.warningOpacity = 0;
      this.warningScale = 0.88;
    });
    setTimeout(() => {
      this.showPastTimeWarning = false;
      this.openTimePicker(false);
    }, 160);
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Column() {
          Row() {
            Text('←')
              .fontSize(34)
              .fontColor('#FFFFFF')
              .width(56)
              .textAlign(TextAlign.Center)
              .onClick(() => router.back())
            Text('倒计时')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Image($r('app.media.refresh'))
              .width(28)
              .height(28)
              .fillColor('#FFFFFF')
              .margin({ right: 20 })
              .onClick(() => this.updateDate())
          }
          .width('100%')
          .height(70)
          .alignItems(VerticalAlign.Center)

          Text(this.currentDate)
            .fontSize(19)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .width('100%')
            .margin({ left: 50, top: 12 })

          Text('正在进行  ♡ ' + this.eventCount.toString())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width('100%')
            .margin({ left: 50, top: 26 })

          Text('正当利用时间!你要理解什么，不要急近求远。')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .width('100%')
            .margin({ left: 50, top: 28, bottom: 36 })
        }
        .width('100%')
        .backgroundColor('#20C78A')

        Stack({ alignContent: Alignment.Center }) {
          Column() {
            Text('✈')
              .fontSize(72)
              .fontColor('#83D39B')
              .margin({ bottom: 14 })
            Text('没有内容')
              .fontSize(25)
              .fontWeight(FontWeight.Bold)
              .fontColor('#20C78A')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#FAFAFA')
      }
      .width('100%')
      .height('100%')

      Column() {
        Text('+')
          .fontSize(44)
          .fontWeight(FontWeight.Normal)
          .fontColor('#FFFFFF')
          .width(72)
          .height(72)
          .textAlign(TextAlign.Center)
      }
      .width(72)
      .height(72)
      .borderRadius(36)
      .backgroundColor('#FFAD55')
      .shadow({ radius: 8, color: '#40000000', offsetX: 0, offsetY: 4 })
      .margin({ right: 28, bottom: 34 })
      .onClick(() => this.addCountdown())

      if (this.showAddDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#000000')
            .opacity(0.58)
            .onClick(() => this.closeAddDialog())

          Column() {
          Row() {
            Text('←')
              .fontSize(34)
              .fontColor('#333333')
              .width(56)
              .textAlign(TextAlign.Center)
              .onClick(() => this.closeAddDialog())
            Text('添加倒计时')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111111')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text('✓')
              .fontSize(30)
              .fontColor('#111111')
              .width(56)
              .textAlign(TextAlign.Center)
              .onClick(() => this.saveCountdown())
          }
          .width('100%')
          .height(70)
          .alignItems(VerticalAlign.Center)

          Row() {
            Text('课程名称:')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#444444')
              .width(118)
            TextInput({ text: this.courseName, placeholder: '输入考试科目' })
              .id('countdownCourseInput')
              .layoutWeight(1)
              .height(44)
              .fontSize(17)
              .fontColor('#333333')
              .placeholderColor('#AAAAAA')
              .backgroundColor('#FFFFFF')
              .onChange((value: string) => { this.courseName = value; })
          }
          .width('100%')
          .padding({ left: 24, right: 20 })
          .margin({ top: 18 })

          Row() {
            Text('考试时间:')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#444444')
              .width(118)
            Text(this.examTime.length > 0 ? this.examTime : '点击选择时间')
              .fontSize(17)
              .fontColor(this.examTime.length > 0 ? '#333333' : '#AAAAAA')
              .layoutWeight(1)
              .onClick(() => this.chooseExamTime())
          }
          .width('100%')
          .padding({ left: 24, right: 20 })
          .margin({ top: 24 })

          Row() {
            Text('备注:')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#444444')
              .width(118)
              .alignSelf(ItemAlign.Start)
            TextInput({ text: this.remark, placeholder: '输入考试地点、注意事项等...' })
              .layoutWeight(1)
              .height(110)
              .fontSize(16)
              .fontColor('#333333')
              .placeholderColor('#AAAAAA')
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#DDDDDD' })
              .borderRadius(12)
              .padding(14)
              .onChange((value: string) => { this.remark = value; })
          }
          .width('100%')
          .padding({ left: 24, right: 20 })
          .margin({ top: 26, bottom: 28 })
          }
          .width('86%')
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .scale({ x: this.dialogScale, y: this.dialogScale })
          .opacity(this.dialogOpacity)
        }
        .width('100%')
        .height('100%')
      }

      if (this.showTimePicker) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#000000')
            .opacity(0.48)

          Column() {
            Row() {
              Text('取消')
                .fontSize(19)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1688F4')
                .padding({ left: 22, right: 22, top: 16, bottom: 16 })
                .onClick(() => this.closeTimePicker())
              Blank()
              Text('确定')
                .fontSize(19)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1688F4')
                .padding({ left: 22, right: 22, top: 16, bottom: 16 })
                .onClick(() => this.confirmPickerTime())
            }
            .width('100%')
            .height(58)
            .alignItems(VerticalAlign.Center)

            Divider().color('#EEEEEE')

            Row() {
              DatePicker({
                start: new Date(new Date().getFullYear() - 4, 0, 1),
                end: new Date(new Date().getFullYear() + 4, 11, 31),
                selected: this.pickerDate
              })
                .width('60%')
                .height(210)
                .onDateChange((value: Date) => {
                  this.pickerDate = value;
                })

              TimePicker({ selected: this.getPickerTime() })
                .width('40%')
                .height(210)
                .useMilitaryTime(true)
                .onChange((value: TimePickerResult) => {
                  this.pickerHour = value.hour;
                  this.pickerMinute = value.minute;
                })
            }
            .width('100%')
            .height(210)
          }
          .width('95%')
          .backgroundColor('#FFFFFF')
          .scale({ x: this.timePickerScale, y: this.timePickerScale })
          .opacity(this.timePickerOpacity)
        }
        .width('100%')
        .height('100%')
      }

      if (this.showPastTimeWarning) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#000000')
            .opacity(0.5)

          Column() {
            Column() {
              Text('×')
                .fontSize(58)
                .fontWeight(FontWeight.Lighter)
                .fontColor('#F06F73')
                .textAlign(TextAlign.Center)
            }
            .width(82)
            .height(82)
            .border({ width: 4, color: '#F06F73' })
            .borderRadius(41)
            .justifyContent(FlexAlign.Center)
            .margin({ top: 30 })

            Text('提示')
              .fontSize(25)
              .fontWeight(FontWeight.Bold)
              .fontColor('#555555')
              .margin({ top: 14 })

            Text('请选择未来的一个时间!')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor('#777777')
              .margin({ top: 24 })

            Button('确定')
              .width(132)
              .height(52)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor('#62E000')
              .borderRadius(10)
              .margin({ top: 30, bottom: 30 })
              .onClick(() => this.returnToTimePicker())
          }
          .width('78%')
          .backgroundColor('#FFFFFF')
          .borderRadius(24)
          .alignItems(HorizontalAlign.Center)
          .scale({ x: this.warningScale, y: this.warningScale })
          .opacity(this.warningOpacity)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  private chooseExamTime(): void {
    this.openTimePicker(true);
  }
}

