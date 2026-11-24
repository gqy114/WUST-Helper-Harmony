import { WeeklyWidgetGrid } from './WeeklyWidgetGrid';
import { WeeklyWidgetPages } from './WidgetData';

@Component
export struct WeeklyWidgetCarousel {
  @Prop @Watch('loadPages') pagesJson: string = '';
  @Prop currentWeek: number = 1;
  @Prop title: string = '';
  @Prop courses: string = '';
  @Prop campus: string = '黄家湖校区';
  @Prop subtitle: string = '';
  @Prop textColor: string = '#111111';
  @Prop subColor: string = '#666666';
  @State private pages: WeeklyWidgetPages = { grids: [], weekGridIndexes: [] };

  aboutToAppear(): void {
    this.loadPages();
  }

  private loadPages(): void {
    try {
      this.pages = JSON.parse(this.pagesJson) as WeeklyWidgetPages;
    } catch {
      this.pages = { grids: [], weekGridIndexes: [] };
    }
  }

  @Builder
  private weekContent(title: string, courses: string, emptyText: string) {
    Column() {
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%')
      WeeklyWidgetGrid({
        courses: courses, campus: this.campus, subtitle: emptyText, textColor: this.textColor, subColor: this.subColor
      }).layoutWeight(1)
    }.width('100%').height('100%')
  }

  build() {
    if (this.pages.weekGridIndexes.length > 0) {
      Swiper() {
        ForEach(this.pages.weekGridIndexes, (gridIndex: number, index: number) => {
          this.weekContent('第' + (index + 1) + '周', this.pages.grids[this.pages.weekGridIndexes[index]], '本周没有课程')
        }, (gridIndex: number, index: number) => String(index))
      }
      .index(Math.max(0, Math.min(this.currentWeek - 1, this.pages.weekGridIndexes.length - 1)))
      .vertical(true)
      .loop(false)
      .cachedCount(1)
      .indicator(false)
      .width('100%').height('100%')
    } else {
      this.weekContent(this.title, this.courses, this.subtitle)
    }
  }
}
