import { WeeklyWidgetGrid } from './WeeklyWidgetGrid';
import { WeeklyWidgetPages } from './WidgetData';

@Component
export struct WeeklyWidgetCarousel {
  @Prop @Watch('loadPages') pagesJson: string = '';
  @Prop @Watch('onCurrentWeekChanged') currentWeek: number = 1;
  @Prop title: string = '';
  @Prop courses: string = '';
  @Prop campus: string = '黄家湖校区';
  @Prop subtitle: string = '';
  @Prop textColor: string = '#111111';
  @Prop subColor: string = '#666666';
  @Prop showArchiveSwitch: boolean = false;
  onArchiveSwitch: () => void = () => {};
  onOpen: () => void = () => {};
  @State private pages: WeeklyWidgetPages = { grids: [], weekGridIndexes: [] };
  @State private locked: boolean = false;
  @State private displayIndex: number = 0;
  private initialized: boolean = false;
  private lastCurrentWeek: number = 1;
  private swiperController: SwiperController = new SwiperController();
  // 滑到非本周后 30 秒自动回到本周；每次滑动都会重新计时。
  private returnTimer: number = -1;
  private autoReturning: boolean = false;

  aboutToAppear(): void {
    this.lastCurrentWeek = this.currentWeek;
    this.loadPages();
  }

  private onCurrentWeekChanged(): void {
    const length = this.pages.weekGridIndexes.length;
    if (length === 0) {
      this.lastCurrentWeek = this.currentWeek;
      return;
    }
    const oldIndex = Math.max(0, Math.min(this.lastCurrentWeek - 1, length - 1));
    const nextIndex = this.currentPageIndex();
    // 未锁定时，停留在旧“本周”则跟随到新本周；手动滑到别的周则保留。
    if (!this.locked && this.displayIndex === oldIndex) this.displayIndex = nextIndex;
    this.lastCurrentWeek = this.currentWeek;
  }

  aboutToDisappear(): void {
    this.clearReturnTimer();
  }

  private currentPageIndex(): number {
    return Math.max(0, Math.min(this.currentWeek - 1, this.pages.weekGridIndexes.length - 1));
  }

  private clearReturnTimer(): void {
    if (this.returnTimer !== -1) {
      clearTimeout(this.returnTimer);
      this.returnTimer = -1;
    }
  }

  private startAutoReturn(): void {
    this.clearReturnTimer();
    this.returnTimer = setTimeout(() => {
      this.returnTimer = -1;
      this.autoReturning = true;
      try {
        this.swiperController.changeIndex(this.currentPageIndex(), true);
      } catch (error) {
        this.autoReturning = false;
      }
    }, 30000);
  }

  private toggleLock(): void {
    this.locked = !this.locked;
    if (this.locked) {
      // 锁定后常驻当前非本周课表，不再自动回本周。
      this.clearReturnTimer();
    } else if (this.displayIndex !== this.currentPageIndex()) {
      this.startAutoReturn();
    }
  }

  private onPageChanged(index: number): void {
    this.displayIndex = index;
    // 自动回本周触发的 onChange 不重新计时，也不打断“常驻本周”。
    if (this.autoReturning) {
      this.autoReturning = false;
      this.clearReturnTimer();
      return;
    }
    if (this.locked) return;
    this.clearReturnTimer();
    if (index === this.currentPageIndex()) return;
    this.startAutoReturn();
  }

  private loadPages(): void {
    try {
      this.pages = JSON.parse(this.pagesJson) as WeeklyWidgetPages;
    } catch {
      this.pages = { grids: [], weekGridIndexes: [] };
    }
    if (!this.initialized) {
      // 首次添加卡片可能先收到空 pages，等真正拿到周数据后再定位到本周。
      if (this.pages.weekGridIndexes.length > 0) {
        this.displayIndex = this.currentPageIndex();
        this.initialized = true;
      } else {
        this.displayIndex = 0;
      }
    } else {
      // 数据刷新时保留用户当前停留的周，避免锁定页被重置回本周。
      this.displayIndex = Math.max(0, Math.min(this.displayIndex, this.pages.weekGridIndexes.length - 1));
    }
  }

  @Builder
  private weekContent(title: string, courses: string, emptyText: string) {
    Column() {
      Row({ space: 6 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        // 只有手动滑到非本周后才显示锁按钮；再滑回本周自动隐藏。
        if (this.displayIndex !== this.currentPageIndex()) {
          Image($r('app.media.ic_widget_lock')).width(22).height(28).objectFit(ImageFit.Contain)
            .fillColor(this.locked ? '#61A5FA' : this.subColor)
            .accessibilityText(this.locked ? '取消锁定当前周课表' : '锁定当前周课表')
            .onClick(() => this.toggleLock())
        }
        if (this.showArchiveSwitch) {
          Image($r('app.media.widget_archive_switch')).width(22).height(28)
            .objectFit(ImageFit.Contain).fillColor(this.subColor)
            .accessibilityText('切换课表档案').onClick(() => this.onArchiveSwitch())
        }
      }.width('100%').height(28)
      WeeklyWidgetGrid({
        courses: courses, campus: this.campus, subtitle: emptyText, textColor: this.textColor, subColor: this.subColor
      }).layoutWeight(1).onClick(() => this.onOpen())
    }.width('100%').height('100%')
  }

  build() {
    if (this.pages.weekGridIndexes.length > 0) {
      Swiper(this.swiperController) {
        ForEach(this.pages.weekGridIndexes, (gridIndex: number, index: number) => {
          this.weekContent('第' + (index + 1) + '周', this.pages.grids[this.pages.weekGridIndexes[index]], '本周没有课程')
        }, (gridIndex: number, index: number) =>
          `${index}-${gridIndex}-${this.pages.grids[this.pages.weekGridIndexes[index]] || ''}`)
      }
      .index(this.displayIndex)
      .onChange((index: number) => this.onPageChanged(index))
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
