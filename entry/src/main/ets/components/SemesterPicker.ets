/**
 * SemesterPicker - 选择课程学期底部选择器。
 */
@Component
export struct SemesterPicker {
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop selectedSemester: string = '2026-2027-1';
  onCancel: () => void = () => {};
  onConfirm: (semester: string) => void = () => {};

  @State private pickerValue: number = 0;
  @State private showPanel: boolean = false;
  @State private panelTranslateY: number = 500;
  @State private maskOpacity: number = 0;
  private semesterList: string[] = [
    '2025-2026-1',
    '2025-2026-2',
    '2026-2027-1',
    '2026-2027-2',
    '2027-2028-1',
    '2027-2028-2',
    '2028-2029-1'
  ];

  aboutToAppear(): void {
    const index = this.semesterList.indexOf(this.selectedSemester);
    this.pickerValue = index >= 0 ? index : 2;
  }

  onVisibleChange(): void {
    if (this.visible && !this.showPanel) {
      this.showPanel = true;
      this.panelTranslateY = 500;
      this.maskOpacity = 0;
      setTimeout(() => {
        this.panelTranslateY = 0;
        this.maskOpacity = 1;
      }, 10);
    } else if (!this.visible && this.showPanel) {
      this.panelTranslateY = 500;
      this.maskOpacity = 0;
      setTimeout(() => {
        this.showPanel = false;
      }, 300);
    }
  }

  private handleCancel(): void {
    this.panelTranslateY = 500;
    this.maskOpacity = 0;
    setTimeout(() => {
      this.onCancel();
    }, 300);
  }

  private handleConfirm(): void {
    const semester = this.semesterList[this.pickerValue];
    this.panelTranslateY = 500;
    this.maskOpacity = 0;
    setTimeout(() => {
      this.onConfirm(semester);
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
              .width(60)
              .onClick(() => {
                this.handleCancel();
              })

            Blank()

            Text(`最新学期：${this.semesterList[this.pickerValue]}`)
              .fontSize(14)
              .fontColor('#999999')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()

            Text('确定')
              .fontSize(16)
              .fontColor('#4CAF50')
              .fontWeight(FontWeight.Medium)
              .width(60)
              .textAlign(TextAlign.End)
              .onClick(() => {
                this.handleConfirm();
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .border({ width: { bottom: 0.5 }, color: '#EEEEEE' })

          TextPicker({ range: this.semesterList, selected: this.pickerValue })
            .width('85%')
            .height(280)
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
