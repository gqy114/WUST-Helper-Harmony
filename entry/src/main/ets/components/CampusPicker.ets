/**
 * CampusPicker - 校区底部选择器，使用 TextPicker 和底部滑入动画。
 */
@Component
export struct CampusPicker {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop selectedCampus: string = '黄家湖校区';
  onCancel: () => void = () => {};
  onConfirm: (campus: string) => void = () => {};

  @State private pickerValue: number = 0;
  @State private showPanel: boolean = false;
  @State private panelTranslateY: number = 400;
  @State private maskOpacity: number = 0;
  private campusList: string[] = ['黄家湖校区', '青山校区'];

  aboutToAppear(): void {
    const index = this.campusList.indexOf(this.selectedCampus);
    this.pickerValue = index >= 0 ? index : 0;
  }

  onVisibleChange(): void {
    if (this.visible && !this.showPanel) {
      this.showPanel = true;
      this.panelTranslateY = 400;
      this.maskOpacity = 0;
      setTimeout(() => {
        this.panelTranslateY = 0;
        this.maskOpacity = 1;
      }, 10);
    } else if (!this.visible && this.showPanel) {
      this.panelTranslateY = 400;
      this.maskOpacity = 0;
      setTimeout(() => {
        this.showPanel = false;
      }, 300);
    }
  }

  private handleCancel(): void {
    this.panelTranslateY = 400;
    this.maskOpacity = 0;
    setTimeout(() => {
      this.onCancel();
    }, 300);
  }

  private handleConfirm(): void {
    const campus = this.campusList[this.pickerValue];
    this.panelTranslateY = 400;
    this.maskOpacity = 0;
    setTimeout(() => {
      this.onConfirm(campus);
    }, 300);
  }

  build() {
    if (this.showPanel) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#40000000')
          .opacity(this.maskOpacity)
          .animation({ duration: 300, curve: Curve.EaseOut })
          .onClick(() => {
            this.handleCancel();
          })

        Column() {
          Row() {
            Text('取消')
              .fontSize(16)
              .fontColor('#666666')
              .onClick(() => {
                this.handleCancel();
              })

            Blank()

            Text('确定')
              .fontSize(16)
              .fontColor('#4CAF50')
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                this.handleConfirm();
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .border({ width: { bottom: 0.5 }, color: '#EEEEEE' })

          TextPicker({ range: this.campusList, selected: this.pickerValue })
            .width('85%')
            .height(240)
            .animation({ duration: 220, curve: Curve.EaseOut })
            .disappearTextStyle({ color: '#999999', font: { size: 18 } })
            .textStyle({ color: '#999999', font: { size: 18 } })
            .selectedTextStyle({ color: '#4CAF50', font: { size: 18, weight: FontWeight.Medium } })
            .divider(null)
            .onChange((value: string | string[], index: number | number[]) => {
              if (typeof index === 'number') {
                this.pickerValue = index;
              }
            })
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius({ topLeft: 12, topRight: 12 })
        .translate({ y: this.panelTranslateY })
        .opacity(this.maskOpacity)
        .animation({ duration: 300, curve: Curve.EaseOut })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
    }
  }
}
