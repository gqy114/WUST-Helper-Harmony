import { CommunityPostImage } from './CommunityPostImage';

@Component
export struct CommunityPostImagePreview {
  @Prop images: string[] = [];

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      CommunityPostImage({ src: this.images[0] || '' })
      if (this.images.length > 1) {
        Text(`共 ${this.images.length} 张`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor('#99000000')
          .borderRadius(18)
          .margin({ right: 10, bottom: 10 })
      }
    }.width('100%')
  }
}
