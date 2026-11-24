import { WidgetCountdownSlide } from './WidgetData';

const ROTATION_INTERVAL_MS: number = 20000;

@Component
export struct CountdownWidgetCarousel {
  @Prop slides: string = '';
  @Prop emptyText: string = '';
  @Prop textColor: string = '#111111';
  @Prop subColor: string = '#666666';
  @Prop accent: string = '#EC5A3C';
  @Prop initialCompact: boolean = false;
  @State private widthToHeight: number = 0;
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
      Column() {
        this.titleAndDate(slide)
        Row({ space: 4 }) {
          Text(slide.remaining).fontSize(48).minFontSize(24).fontWeight(FontWeight.Bold)
            .fontColor(this.accent).maxLines(1)
          Text('天').fontSize(13).fontColor(this.subColor)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
      }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
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
          this.icon($r('app.media.setting'), '小组件设置', () => this.onSettings())
          this.icon($r('app.media.refresh'), '刷新倒计时', () => this.onRefresh())
          this.icon($r('app.media.add'), '添加倒计时', () => this.onAdd())
        }.width('100%').height(30)
      }

      if (this.entries().length > 0) {
        Swiper() {
          ForEach(this.entries(), (slide: WidgetCountdownSlide, index: number) => {
            this.slideContent(slide)
          }, (slide: WidgetCountdownSlide, index: number) =>
            index + '|' + slide.title + '|' + slide.date + '|' + slide.elapsed + '|' + slide.remaining)
        }
        .autoPlay(this.entries().length > 1)
        .loop(this.entries().length > 1)
        .interval(ROTATION_INTERVAL_MS)
        .vertical(true)
        .indicator(false)
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
