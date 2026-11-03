/**
 * CourseItem - course block UI.
 */
@Component
export struct CourseItem {
  @Prop courseName: string = '';
  @Prop teacher: string = '';
  @Prop location: string = '';
  @Prop color: string = '#66cc99';
  @Prop isDimmed: boolean = false;
  /** 同一位置存在跨周的其他课程时，才显示右下角翻页提示。 */
  @Prop hasAlternateCourse: boolean = false;
  @Prop fontSize: number = 11;
  @Prop italic: boolean = false;
  @Prop bgImage: Resource | null = null;
  private onItemTap?: () => void;

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.bgImage) { Image(this.bgImage).width('100%').height('100%').objectFit(ImageFit.Cover).borderRadius(8).opacity(this.isDimmed ? 0.55 : 1); }
      Column() {
        Text(this.courseName)
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDimmed ? '#666666' : '#FFFFFF')
          .fontStyle(this.italic ? FontStyle.Italic : FontStyle.Normal)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')

        Text(this.location)
          .fontSize(Math.max(9, this.fontSize - 2))
          .fontColor(this.isDimmed ? '#888888' : '#FFFFFF')
          .fontStyle(this.italic ? FontStyle.Italic : FontStyle.Normal)
          .opacity(this.isDimmed ? 1 : 0.9)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 4, top: 5, right: 4, bottom: 5 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      if (this.hasAlternateCourse) {
        Stack()
          .width(0)
          .height(0)
          .border({
          width: { left: 5, top: 5, right: 5, bottom: 5 },
          color: {
            left: '#00000000',
            top: '#00000000',
            right: '#FFFFFF',
            bottom: '#FFFFFF'
          }
        })
          .margin({ right: 4, bottom: 4 })
          .opacity(0.9)
      }
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
