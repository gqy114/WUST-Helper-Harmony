import { WidgetCountdownSlide } from './WidgetData';

const ROTATION_INTERVAL_MS: number = 20000;

@Component
export struct CountdownWidgetCarousel {
  @Prop @Watch('onSlidesChanged') slides: string = '';
  @Prop emptyText: string = '';
  @Prop textColor: string = '#111111';
  @Prop subColor: string = '#666666';
  @Prop accent: string = '#EC5A3C';
  @Prop initialCompact: boolean = false;
  @State private widthToHeight: number = 0;
  @State private locked: boolean = false;
  @State private slideIndex: number = 0;
  private swiperController: SwiperController = new SwiperController();
  onSettings: () => void = () => {};
  onRefresh: () => void = () => {};
  onAdd: () => void = () => {};

  private compact(): boolean {
    return this.widthToHeight > 0 ? this.widthToHeight < 1.45 : this.initialCompact;
  }

  private entries(): WidgetCountdownSlide[] {
    try {
      return JSON.parse(this.slides || '[]') as WidgetCountdownSlide[];
    } catch {
      return [];
    }
  }

  private remainingDays(slide: WidgetCountdownSlide): number {
    const value = Number(slide.remaining);
    return isNaN(value) ? Number.MAX_SAFE_INTEGER : value;
  }

  /** 锁定时当前倒计时已经结束，自动切到下一个还没结束的倒计时。 */
  private onSlidesChanged(): void {
    if (!this.locked) return;
    const list = this.entries();
    if (list.length === 0) return;
    const index = Math.min(this.slideIndex, list.length - 1);
    if (this.remainingDays(list[index]) > 0) return;
    for (let i = 0; i < list.length; i++) {
      if (this.remainingDays(list[i]) > 0) {
        this.slideIndex = i;
        try { this.swiperController.changeIndex(i, true); } catch (error) {}
        return;
      }
    }
  }

  @Builder
  private lockIcon(size: number) {
    Image($r('app.media.ic_widget_lock'))
      .width(size).height(size).objectFit(ImageFit.Contain)
      .fillColor(this.locked ? '#61A5FA' : this.subColor)
      .accessibilityText(this.locked ? '取消锁定当前倒计时' : '锁定当前倒计时')
      .onClick(() => { this.locked = !this.locked; })
  }

  @Builder
  private icon(source: Resource, label: string, action: () => void) {
    Image(source).width(26).height(28).objectFit(ImageFit.Contain).padding(3)
      .fillColor(this.subColor).accessibilityText(label).onClick(action)
  }

  @Builder
  private titleAndDate(slide: WidgetCountdownSlide) {
    Column({ space: 3 }) {
      Text(slide.title).fontSize(this.compact() ? 17 : 16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Text(slide.date).fontSize(this.compact() ? 10 : 12).fontColor(this.subColor)
        .maxLines(1).minFontSize(8).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private counter(label: string, value: string, color: string) {
    Column({ space: 3 }) {
      Text(label).fontSize(11).fontColor(this.subColor).maxLines(1)
      Text(value).fontSize(30).fontColor(color).maxLines(1).minFontSize(14)
    }.width(52).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private slideContent(slide: WidgetCountdownSlide) {
    if (this.compact()) {
      // 2*2 卡片空间小：锁图标缩到接近标题一个字大小，叠在右上角。
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          this.titleAndDate(slide)
          Row({ space: 4 }) {
            Text(slide.remaining).fontSize(48).minFontSize(24).fontWeight(FontWeight.Bold)
              .fontColor(this.accent).maxLines(1)
            Text('天').fontSize(13).fontColor(this.subColor)
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
        }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
        this.lockIcon(15)
      }.width('100%').height('100%')
    } else {
      Row({ space: 4 }) {
        Column() { this.titleAndDate(slide) }.layoutWeight(1)
        this.counter('开始天数', slide.elapsed, this.textColor)
        this.counter('剩余天数', slide.remaining, this.accent)
      }.width('100%').height('100%').alignItems(VerticalAlign.Center)
    }
  }

  build() {
    Column() {
      if (!this.compact()) {
        Row({ space: 5 }) {
          Text('倒计时').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.textColor).layoutWeight(1)
          this.lockIcon(26)
          this.icon($r('app.media.setting'), '小组件设置', () => this.onSettings())
          this.icon($r('app.media.refresh'), '刷新倒计时', () => this.onRefresh())
          this.icon($r('app.media.add'), '添加倒计时', () => this.onAdd())
        }.width('100%').height(30)
      }

      if (this.entries().length > 0) {
        Swiper(this.swiperController) {
          ForEach(this.entries(), (slide: WidgetCountdownSlide, index: number) => {
            this.slideContent(slide)
          }, (slide: WidgetCountdownSlide, index: number) =>
            index + '|' + slide.title + '|' + slide.date + '|' + slide.elapsed + '|' + slide.remaining)
        }
        .autoPlay(!this.locked && this.entries().length > 1)
        .loop(this.entries().length > 1)
        .interval(ROTATION_INTERVAL_MS)
        .vertical(true)
        .indicator(false)
        .onChange((index: number) => { this.slideIndex = index; })
        .width('100%')
        .layoutWeight(1)
      } else {
        Text(this.emptyText || '暂无待显示的倒计时').fontSize(13).fontColor(this.subColor)
          .width('100%').textAlign(TextAlign.Center).layoutWeight(1)
      }
    }
    .width('100%').height('100%').padding(12)
    .onAreaChange((_oldArea: Area, area: Area) => {
      const height = Number(area.height);
      if (height > 0) this.widthToHeight = Number(area.width) / height;
    })
  }
}
