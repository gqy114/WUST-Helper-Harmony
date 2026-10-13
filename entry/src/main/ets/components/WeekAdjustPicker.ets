/**
 * WeekAdjustPicker - 使用系统 TextPicker 选择开学后的周数。
 * TextPicker 负责滚动、吸附和边界处理，不再手动计算 Scroll 偏移。
 */
@Component
export struct WeekAdjustPicker {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop currentWeek: number = 1;
  onConfirm: (week: number) => void = () => {};
  onCancel: () => void = () => {};

  @State private pickerValue: number = 1;
  @State private showPanel: boolean = false;
  @State private maskOpacity: number = 0;
  @State private panelScale: number = 0.8;
  private weekList: string[] = [];

  aboutToAppear(): void {
    if (this.weekList.length === 0) {
      for (let week = 1; week <= 25; week++) {
        this.weekList.push(`${week}周`);
      }
    }
    this.pickerValue = this.clampWeek(this.currentWeek);
  }

  private clampWeek(week: number): number {
    if (week < 1) {
      return 1;
    }
    if (week > 25) {
      return 25;
    }
    return Math.round(week);
  }

  private onVisibleChange(): void {
    if (this.visible) {
      this.pickerValue = this.clampWeek(this.currentWeek);
      this.showPanel = true;
      this.maskOpacity = 0;
      this.panelScale = 0.8;
      setTimeout(() => {
        this.maskOpacity = 0.5;
        this.panelScale = 1;
      }, 20);
    } else if (this.showPanel) {
      this.maskOpacity = 0;
      this.panelScale = 0.8;
      setTimeout(() => {
        this.showPanel = false;
      }, 250);
    }
  }

  private close(notifyCancel: boolean = true): void {
    if (notifyCancel) {
      this.onCancel();
    }
    this.maskOpacity = 0;
    this.panelScale = 0.8;
    setTimeout(() => {
      if (!this.visible) {
        this.showPanel = false;
      }
    }, 250);
  }

  build() {
    if (this.showPanel) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(this.maskOpacity)
          .onClick(() => this.close())

        Column() {
          Text(`当前：开学后第${this.pickerValue}周`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 24, bottom: 16 })

          TextPicker({
            range: this.weekList,
            selected: this.pickerValue - 1
          })
            .width(300)
            .height(120)
            .disappearTextStyle({ color: '#999999', font: { size: 18 } })
            .textStyle({ color: '#999999', font: { size: 18 } })
            .selectedTextStyle({ color: '#FF4444', font: { size: 18, weight: FontWeight.Bold } })
            .divider(null)
            .onChange((value: string | string[], index: number | number[]) => {
              if (typeof index === 'number') {
                this.pickerValue = this.clampWeek(index + 1);
                console.info('WeekAdjustPicker',
                  `onChange: value=${value.toString()}, index=${index}, week=${this.pickerValue}`);
              }
            })

          Row() {
            Button('取消')
              .fontSize(18)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF6B6B')
              .width(140)
              .height(48)
              .borderRadius(8)
              .onClick(() => this.close())

            Blank().width(24)

            Button('确定')
              .fontSize(18)
              .fontColor('#FFFFFF')
              .backgroundColor('#7ED321')
              .width(140)
              .height(48)
              .borderRadius(8)
              .onClick(() => {
                this.onConfirm(this.pickerValue);
                this.close(false);
              })
          }
          .margin({ top: 24, bottom: 24 })
        }
        .width(340)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .scale({ x: this.panelScale, y: this.panelScale })
        .opacity(this.maskOpacity > 0 ? 1 : 0)
        .animation({ duration: 250, curve: Curve.EaseOut })
      }
      .width('100%')
      .height('100%')
    }
  }
}
