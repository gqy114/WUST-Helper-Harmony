import { router } from '@kit.ArkUI';
import { CampusNewsApi, NewsArticle, NewsCategory, NewsCollege } from '../../net/CampusNewsApi';

const TAG = 'CampusPage';
const PAGE_SIZE = 20;
const FEED_INSET = 16;
const FEED_GAP = 10;
const CONTROL_COLOR = '#82888A';
const SEARCH_INPUT_ID = 'campusNewsSearchInput';

@Component
struct CampusNewsCover {
  @Prop src: string = '';
  @Prop dashboard: boolean = false;
  @State private ratio: number = 1;
  @State private failed: boolean = false;

  build() {
    if (!this.failed) {
      if (this.dashboard) {
        Image(this.src)
          .width('100%').aspectRatio(this.ratio).objectFit(ImageFit.Contain).autoResize(false)
          .onComplete((event) => {
            if (event && event.width > 0 && event.height > 0) this.ratio = event.width / event.height;
          })
          .onError(() => { this.failed = true; })
      } else {
        Image(this.src).width(86).height(74).objectFit(ImageFit.Contain).margin({ left: 12 })
          .onError(() => { this.failed = true; })
      }
    }
  }
}

interface CampusShortcut {
  title: string;
  description: string;
  icon: Resource;
  route: string;
}

const CAMPUS_SHORTCUTS: CampusShortcut[] = [
  { title: '学校校历', description: '了解校历与假期安排', icon: $r('app.media.ic_schoolcalendar'), route: 'pages/campus/SchoolCalendarPage' },
  { title: '校车时刻', description: '查询各校区发车时间', icon: $r('app.media.ic_school_bus'), route: 'pages/campus/SchoolBusPage' },
  { title: '校园黄页', description: '查询校园常用号码', icon: $r('app.media.ic_yellow_page'), route: 'pages/campus/YellowPagesPage' },
  { title: '物理实验', description: '查询并导入实验课表', icon: $r('app.media.ic_physical'), route: 'pages/course/PhysicalExperimentPage' }
];

@Component
export struct CampusPage {
  @State private articles: NewsArticle[] = [];
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private errorText: string = '';
  @State private page: number = 1;
  @State private hasMore: boolean = true;
  @State private dashboard: boolean = false;
  @State private dashboardColumnWidth: number = 0;
  @State private searching: boolean = false;
  @State private searchText: string = '';
  @State private keyword: string = '';
  @State private filterOpen: boolean = false;
  @State private colleges: NewsCollege[] = [];
  @State private categories: NewsCategory[] = [];
  @State private collegeId: string = '';
  @State private categoryUrl: string = '';
  @State private collegesLoading: boolean = false;
  @State private categoriesLoading: boolean = false;
  private requestGeneration: number = 0;
  private categoryGeneration: number = 0;
  private readonly listScroller: Scroller = new Scroller();
  private readonly dashboardScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load(true);
  }

  private async load(reset: boolean): Promise<void> {
    // 先判断是否正在加载：重复点“加载更多”不能推进代次，
    // 否则正在进行的请求回来时会被判定过期，loadingMore 永远复位不了。
    if (!reset && (this.loadingMore || !this.hasMore || this.loading)) return;
    const generation = ++this.requestGeneration;
    const keyword = this.keyword;
    if (reset) {
      this.page = 1;
      this.hasMore = true;
      this.loading = true;
      this.errorText = '';
      this.articles = [];
    } else {
      this.loadingMore = true;
    }
    try {
      const result = keyword
        ? await CampusNewsApi.search(keyword, this.page, PAGE_SIZE)
        : await CampusNewsApi.articles(this.page, PAGE_SIZE, this.collegeId, this.categoryUrl);
      if (generation !== this.requestGeneration) return;
      const items = result.items || [];
      this.articles = reset ? items : this.articles.concat(items);
      this.hasMore = typeof result.total === 'number'
        ? items.length > 0 && this.articles.length < result.total
        : items.length >= (result.page_size || PAGE_SIZE);
      this.page = this.page + 1;
      this.errorText = '';
    } catch (error) {
      if (generation !== this.requestGeneration) return;
      const message = error instanceof Error ? error.message : '校园资讯加载失败';
      console.warn(TAG, `load news failed: ${message}`);
      this.errorText = message;
    } finally {
      if (generation === this.requestGeneration) {
        this.loading = false;
        this.loadingMore = false;
      }
    }
  }

  private openArticle(item: NewsArticle): void {
    const id = (item.id || '').trim();
    if (!id) {
      this.errorText = '这篇资讯缺少详情编号，无法打开';
      return;
    }
    router.pushUrl({
      url: 'pages/campus/CampusNewsDetailPage',
      params: { id: id, title: item.title || '资讯详情' }
    });
  }

  private openShortcut(route: string): void {
    router.pushUrl({ url: route });
  }

  private coverOf(item: NewsArticle): string {
    const cover = item.cover_url?.trim() || item.images?.find((url: string) => !!url?.trim())?.trim() || '';
    return cover.startsWith('//') ? 'https:' + cover : cover;
  }

  private search(): void {
    if (!this.searching) {
      this.searching = true;
      setTimeout(() => {
        if (this.searching) this.getUIContext().getFocusController().requestFocus(SEARCH_INPUT_ID);
      }, 150);
      return;
    }
    const keyword = this.searchText.trim();
    if (this.keyword !== keyword || this.errorText) {
      this.keyword = keyword;
      const scroller = this.dashboard ? this.dashboardScroller : this.listScroller;
      scroller.scrollEdge(Edge.Top);
      this.load(true);
    }
  }

  private closeSearch(): void {
    this.searching = false;
    this.searchText = '';
    if (this.keyword) {
      this.keyword = '';
      const scroller = this.dashboard ? this.dashboardScroller : this.listScroller;
      scroller.scrollEdge(Edge.Top);
      this.load(true);
    }
  }

  private async toggleFilter(): Promise<void> {
    this.filterOpen = !this.filterOpen;
    if (!this.filterOpen || this.colleges.length > 0 || this.collegesLoading) return;
    this.collegesLoading = true;
    try {
      this.colleges = await CampusNewsApi.colleges();
    } catch (error) {
      console.warn(TAG, 'load news colleges failed');
    } finally {
      this.collegesLoading = false;
    }
  }

  private async selectCollege(id: string): Promise<void> {
    if (this.collegeId === id) return;
    this.collegeId = id;
    this.categoryUrl = '';
    this.categories = [];
    const generation = ++this.categoryGeneration;
    this.categoriesLoading = !!id;
    this.load(true);
    if (!id) return;
    try {
      const categories = await CampusNewsApi.categories(id);
      if (generation !== this.categoryGeneration) return;
      this.categories = categories;
    } catch (error) {
      if (generation === this.categoryGeneration) console.warn(TAG, 'load news categories failed');
    } finally {
      if (generation === this.categoryGeneration) this.categoriesLoading = false;
    }
  }

  private selectCategory(url: string): void {
    this.categoryUrl = url;
    this.filterOpen = false;
    this.load(true);
  }

  private sourceOptions(): NewsCollege[] {
    const options: NewsCollege[] = [{ id: '', name: '全部来源' }];
    return options.concat(this.colleges);
  }

  private categoryOptions(): NewsCategory[] {
    const options: NewsCategory[] = [{ college_id: this.collegeId, name: '全部栏目', url: '' }];
    return options.concat(this.categories);
  }

  private sourceLabel(): string {
    if (!this.collegeId) return '全部来源';
    const college = this.colleges.find((item: NewsCollege) => item.id === this.collegeId);
    return college?.name || '全部来源';
  }

  private categoryLabel(): string {
    if (!this.categoryUrl) return '全部栏目';
    const category = this.categories.find((item: NewsCategory) => item.url === this.categoryUrl);
    return category?.name || '全部栏目';
  }

  @Builder
  private filterRow(label: string, selected: boolean, action: () => void) {
    Row() {
      Text(label).fontSize(15).fontColor(selected ? '#20C997' : '#333333')
        .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (selected) {
        Text('✓').fontSize(16).fontColor('#20C997').margin({ left: 6 })
      }
    }
    .width('100%').height(48).padding({ left: 16, right: 12 })
    .backgroundColor(selected ? '#EAF8F3' : Color.Transparent)
    .borderRadius(10)
    .onClick(action)
  }

  @Builder
  private filterPanel() {
    Row({ space: 10 }) {
      Column() {
        Text('学校与学院').fontSize(12).fontColor('#999999').width('100%')
          .padding({ left: 16, top: 14, bottom: 8 })
        Scroll() {
          Column() {
            ForEach(this.sourceOptions(), (college: NewsCollege) => {
              this.filterRow(college.name, this.collegeId === college.id, () => { this.selectCollege(college.id); })
            }, (college: NewsCollege) => college.id + (this.collegeId === college.id ? '#on' : '#off'))
            if (this.collegesLoading) {
              Row() {
                LoadingProgress().width(20).height(20).color('#20C997')
                Text('来源加载中…').fontSize(12).fontColor('#999999').margin({ left: 8 })
              }.width('100%').padding(16)
            }
          }.width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
      .width('48%').height('100%').backgroundColor(Color.White).borderRadius(12).clip(true)

      Column() {
        Text('栏目').fontSize(12).fontColor('#999999').width('100%')
          .padding({ left: 16, top: 14, bottom: 8 })
        if (this.collegeId.length === 0) {
          Text('先选择学校或学院').fontSize(14).fontColor('#999999').width('100%').padding(16)
        } else {
          Scroll() {
            Column() {
              ForEach(this.categoryOptions(), (category: NewsCategory) => {
                this.filterRow(category.name, this.categoryUrl === category.url, () => { this.selectCategory(category.url); })
              }, (category: NewsCategory) => category.url + (this.categoryUrl === category.url ? '#on' : '#off'))
              if (this.categoriesLoading) {
                Row() {
                  LoadingProgress().width(20).height(20).color('#20C997')
                  Text('栏目加载中…').fontSize(12).fontColor('#999999').margin({ left: 8 })
                }.width('100%').padding(16)
              }
            }.width('100%')
          }.layoutWeight(1).scrollBar(BarState.Off)
        }
      }
      .width('48%').height('100%').backgroundColor(Color.White).borderRadius(12).clip(true)
    }
    .width('100%').height(360).padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(Color.White).borderRadius(12).clip(true).zIndex(10)
    .margin({ top: 76 })
  }

  @Builder
  private activeFilterBar() {
    if (this.collegeId.length > 0) {
      Row({ space: 8 }) {
        Text(this.sourceLabel()).fontSize(12).fontColor('#20C997').maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.categoryUrl.length > 0) {
          Text('/ ' + this.categoryLabel()).fontSize(12).fontColor('#20C997').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Blank()
        Text('清除').fontSize(12).fontColor('#888888').onClick(() => {
          this.selectCollege('');
        })
      }.width('100%').padding({ left: 16, right: 16, top: 8 })
    }
  }

  @Builder
  private newsHeader() {
    Row() {
      if (this.searching) {
        Row() {
          TextInput({ placeholder: '搜索校园资讯', text: this.searchText })
            .id(SEARCH_INPUT_ID)
            .layoutWeight(1).height(42).fontSize(14).backgroundColor(Color.Transparent)
            .enterKeyType(EnterKeyType.Search)
            .cancelButton({ style: CancelButtonStyle.INVISIBLE })
            .onChange((value: string) => { this.searchText = value; })
            .onSubmit(() => { this.search(); })
          Button('×', { type: ButtonType.Normal }).width(40).height(42).padding(0)
            .fontSize(24).fontColor(CONTROL_COLOR).backgroundColor(Color.Transparent)
            .accessibilityText('关闭搜索').onClick(() => { this.closeSearch(); })
        }.layoutWeight(1).height(42).backgroundColor(Color.White).borderRadius(12).clip(true)
      } else {
        Text('校园').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#555555')
        Text('SCHOOL').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#777777').margin({ left: 12 })
        Blank()
      }
      this.toolbarButton($r('app.media.refresh'), '刷新校园资讯', () => { this.load(true); })
    this.toolbarButton($r('app.media.filter'), '筛选校园资讯', () => { this.toggleFilter(); })
    this.toolbarButton($r('app.media.search'), '搜索校园资讯', () => { this.search(); })
      if (this.dashboard) {
        this.toolbarButton($r('app.media.campus_news_list'), '切换为列表', () => { this.dashboard = false; })
      } else {
        this.toolbarButton($r('app.media.campus_news_dashboard'), '切换为瀑布流', () => { this.dashboard = true; })
      }
    }.width('100%').height(76).padding({ left: this.searching ? 16 : 24, right: 16 })
  }

  @Builder
  private toolbarButton(icon: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Image(icon).width(24).height(24).fillColor(CONTROL_COLOR)
    }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
    .accessibilityText(label).onClick(action)
  }

  @Builder
  private title(item: NewsArticle, lines: number) {
    Text(item.title || '未命名资讯').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333333')
      .width('100%').maxLines(lines).textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private articleMeta(item: NewsArticle) {
    Row({ space: 8 }) {
      Text(item.category_name || '校园资讯').fontSize(11).fontColor(CONTROL_COLOR)
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text((item.published_at || '').substring(0, 10)).fontSize(11).fontColor(CONTROL_COLOR).maxLines(1)
    }.width('100%').margin({ top: 10 })
  }

  @Builder
  private articleCard(item: NewsArticle, dashboard: boolean) {
    Column() {
      if (dashboard) {
        if (this.coverOf(item)) {
          CampusNewsCover({ src: this.coverOf(item), dashboard: true })
        }
        Column() {
          this.title(item, 4)
          if (item.summary?.trim()) {
            Text(item.summary).fontSize(12).fontColor('#777777').width('100%').maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 6 })
          }
          this.articleMeta(item)
        }.width('100%').padding(14)
      } else {
        Column() {
          Row() {
            Column() {
              this.title(item, 3)
            }.layoutWeight(1)
            if (this.coverOf(item)) {
              CampusNewsCover({ src: this.coverOf(item) })
            }
          }.width('100%')
          this.articleMeta(item)
        }.width('100%').padding(14)
      }
    }.width(dashboard ? this.dashboardColumnWidth : '100%')
    .backgroundColor(Color.White).borderRadius(12).clip(true)
    .onClick(() => this.openArticle(item))
  }

  @Builder
  private newsSection() {
    if (this.loading) {
      Column() {
        LoadingProgress().width(36).height(36).color('#20C997')
        Text('校园资讯加载中…').fontSize(13).fontColor('#999999').margin({ top: 10 })
      }.width('100%').padding({ top: 40, bottom: 40 }).justifyContent(FlexAlign.Center)
    } else if (this.errorText.length > 0 && this.articles.length === 0) {
      Row() {
        Image($r('app.media.empty')).width(30).height(30).objectFit(ImageFit.Contain)
        Column() {
          Text(this.keyword ? '搜索失败' : '校园资讯暂不可用').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#555555').width('100%')
          Text(this.errorText).fontSize(11).fontColor('#999999').margin({ top: 2 }).width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
        if (!this.keyword) {
          Text('旧版入口').fontSize(12).fontColor('#888888').margin({ right: 10 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/common/WebPage',
                params: { title: '校园资讯', url: 'https://news.wustlinghang.cn' }
              });
            })
        }
        Text('重试').fontSize(13).fontColor('#20C997').onClick(() => this.load(true))
      }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(Color.White).borderRadius(12).margin({ bottom: 16 })
    } else if (this.articles.length === 0) {
      // 接口成功但暂时没有数据时也要有可见内容，不能留给用户一整页空白。
      Row() {
        Image($r('app.media.empty')).width(30).height(30).objectFit(ImageFit.Contain)
        Column() {
          Text(this.keyword ? '没有找到相关资讯' : '暂无校园资讯').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#555555').width('100%')
          Text(this.keyword ? '试试其他关键词' : '稍后再试，或点击右侧刷新').fontSize(11).fontColor('#999999').margin({ top: 2 }).width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
        Text('刷新').fontSize(13).fontColor('#20C997').onClick(() => this.load(true))
      }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(Color.White).borderRadius(12).margin({ bottom: 16 })
    } else {
      Column() {
        if (this.errorText.length > 0) {
          Text(this.errorText).fontSize(12).fontColor('#C0392B').margin({ top: 4, bottom: 8 })
        }
        if (this.hasMore) {
          Text(this.loadingMore ? '加载中…' : '加载更多')
            .fontSize(13).fontColor('#20C997').padding(10)
            .onClick(() => this.load(false))
        }
      }.width('100%').margin({ bottom: 8 })
    }
  }

  @Builder
  private feedFooter() {
    Column() {
      this.newsSection()
      if (!this.keyword) {
      Text('校园服务').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#444444')
        .width('100%').margin({ top: 14, bottom: 12 })

      ForEach(CAMPUS_SHORTCUTS, (item: CampusShortcut) => {
        Row() {
          Image(item.icon).width(44).height(44).borderRadius(12)
          Column() {
            Text(item.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#333333').width('100%')
            Text(item.description).fontSize(12).fontColor('#999999').margin({ top: 4 }).width('100%')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })
          Text('›').fontSize(22).fontColor('#BBBBBB')
        }
        .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor(Color.White).borderRadius(12).margin({ bottom: 10 })
        .onClick(() => this.openShortcut(item.route))
      }, (item: CampusShortcut) => item.route)
      }
    }.width('100%').padding({ top: 10, bottom: 20 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.newsHeader()
        if (!this.searching) this.activeFilterBar()
      if (this.dashboard) {
        WaterFlow({ scroller: this.dashboardScroller, footer: () => { this.feedFooter(); } }) {
          if (this.dashboardColumnWidth > 0) {
            ForEach(this.articles, (item: NewsArticle) => {
              FlowItem() {
                this.articleCard(item, true)
              }.width(this.dashboardColumnWidth)
            }, (item: NewsArticle) => item.id || item.url || item.title || '')
          }
        }
        .columnsTemplate('1fr 1fr').columnsGap(FEED_GAP).rowsGap(FEED_GAP)
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .padding({ left: FEED_INSET, right: FEED_INSET })
        .onAreaChange((_, area) => {
          const available = Number.parseFloat(String(area.width)) - FEED_INSET * 2 - FEED_GAP;
          if (available > 0) this.dashboardColumnWidth = available / 2;
        })
      } else {
        List({ scroller: this.listScroller, space: FEED_GAP }) {
          ForEach(this.articles, (item: NewsArticle) => {
            ListItem() {
              this.articleCard(item, false)
            }
          }, (item: NewsArticle) => item.id || item.url || item.title || '')
          ListItem() {
            this.feedFooter()
          }
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .padding({ left: FEED_INSET, right: FEED_INSET })
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F6F7')
  if (this.filterOpen) {
    this.filterPanel()
  }
  }
  .width('100%').height('100%')
}
}
