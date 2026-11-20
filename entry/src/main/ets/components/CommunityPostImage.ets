interface CommunityImageLoadEvent {
  width: number;
  height: number;
}

const MAX_CACHED_RATIOS: number = 200;
const imageRatios: Map<string, number> = new Map<string, number>();

@Component
export struct CommunityPostImage {
  @Prop @Watch('restoreRatio') src: string = '';
  @Prop cornerRadius: number = 10;
  @Prop thumbnail: boolean = false;
  @State private sourceRatio: number = 1;
  @State private previewStarted: boolean = false;

  aboutToAppear(): void {
    this.restoreRatio();
  }

  private restoreRatio(): void {
    this.sourceRatio = imageRatios.get(this.src) ?? 1;
  }

  private rememberRatio(event?: CommunityImageLoadEvent): void {
    if (!this.src || !event || event.width <= 0 || event.height <= 0) return;
    const ratio = event.width / event.height;
    this.sourceRatio = ratio;
    imageRatios.delete(this.src);
    imageRatios.set(this.src, ratio);
    if (imageRatios.size > MAX_CACHED_RATIOS) {
      const oldest = imageRatios.keys().next();
      if (!oldest.done) imageRatios.delete(oldest.value);
    }
  }

  build() {
    Stack() {
      if (!this.thumbnail || this.previewStarted) {
        Image(this.src)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .autoResize(this.thumbnail)
          .onComplete((event?: CommunityImageLoadEvent) => this.rememberRatio(event))
      }
    }
    .width('100%')
    .aspectRatio(this.sourceRatio)
    .borderRadius(this.cornerRadius)
    .clip(true)
    .onVisibleAreaChange([0], (visible: boolean) => {
      if (this.thumbnail && visible && !this.previewStarted) this.previewStarted = true;
    })
  }
}
