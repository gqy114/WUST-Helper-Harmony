/**
 * CourseItem - course block UI.
 */
@Component
export struct CourseItem {
  private courseName: string = '';
  private teacher: string = '';
  private location: string = '';
  private color: string = '#66cc99';
  private isDimmed: boolean = false;
  private onItemTap?: () => void;

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Text(this.courseName)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDimmed ? '#666666' : '#FFFFFF')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')

        Text(this.location)
          .fontSize(11)
          .fontColor(this.isDimmed ? '#888888' : '#FFFFFF')
          .opacity(this.isDimmed ? 1 : 0.9)
          .maxLines(3)
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 4, top: 5, right: 4, bottom: 5 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Stack()
        .width(0)
        .height(0)
        .border({
        width: { left: 5, top: 5, right: 5, bottom: 5 },
        color: {
          left: '#00000000',
          top: '#00000000',
          right: this.isDimmed ? '#D2D7DC' : '#FFFFFF',
          bottom: this.isDimmed ? '#D2D7DC' : '#FFFFFF'
        }
      })
        .margin({ right: 4, bottom: 4 })
        .opacity(0.7)
    }
    .width('100%')
    .height('100%')
    .borderRadius(8)
    .backgroundColor(this.isDimmed ? '#D6DCE0' : this.color)
    .onClick(() => {
      if (this.onItemTap !== undefined && this.onItemTap !== null) {
        this.onItemTap();
      }
    })
  }
}
