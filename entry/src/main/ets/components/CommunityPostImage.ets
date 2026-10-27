interface CommunityImageLoadEvent {
  width: number;
  height: number;
}

@Component
export struct CommunityPostImage {
  @Prop src: string = '';
  @Prop cornerRadius: number = 10;
  @State private sourceRatio: number = 1;
  @State private loaded: boolean = false;

  build() {
    Image(this.src)
      .width('100%')
      .aspectRatio(this.sourceRatio)
      .objectFit(ImageFit.Contain)
      .borderRadius(this.cornerRadius)
      .opacity(this.loaded ? 1 : 0)
      .onComplete((event?: CommunityImageLoadEvent) => {
        if (event && event.width > 0 && event.height > 0) {
          this.sourceRatio = event.width / event.height;
          this.loaded = true;
        }
      })
  }
}
