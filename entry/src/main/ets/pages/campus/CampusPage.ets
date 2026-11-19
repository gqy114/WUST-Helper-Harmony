import { router } from '@kit.ArkUI';
import { CampusNewsApi, NewsArticle } from '../../net/CampusNewsApi';

const TAG = 'CampusPage';

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
  private requestGeneration: number = 0;

  aboutToAppear(): void {
    this.load(true);
  }

  private async load(reset: boolean): Promise<void> {
    // 先判断是否正在加载：重复点“加载更多”不能推进代次，
    // 否则正在进行的请求回来时会被判定过期，loadingMore 永远复位不了。
    if (!reset && (this.loadingMore || !this.hasMore)) return;
    const generation = ++this.requestGeneration;
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
      const result = await CampusNewsApi.articles(this.page, 20);
      if (generation !== this.requestGeneration) return;
      const items = result.items || [];
      this.articles = reset ? items : this.articles.concat(items);
      const total = result.total || 0;
      this.hasMore = items.length > 0 && this.articles.length < total;
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
          Text('校园资讯暂不可用').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#555555').width('100%')
          Text(this.errorText).fontSize(11).fontColor('#999999').margin({ top: 2 }).width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
        Text('旧版入口').fontSize(12).fontColor('#888888').margin({ right: 10 })
          .onClick(() => {
            // 新接口尚未部署时保留可用的旧入口。
            router.pushUrl({
              url: 'pages/common/WebPage',
              params: { title: '校园资讯', url: 'https://news.wustlinghang.cn' }
            });
          })
        Text('重试').fontSize(13).fontColor('#20C997').onClick(() => this.load(true))
      }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(Color.White).borderRadius(12).margin({ bottom: 16 })
    } else if (this.articles.length === 0) {
      // 接口成功但暂时没有数据时也要有可见内容，不能留给用户一整页空白。
      Row() {
        Image($r('app.media.empty')).width(30).height(30).objectFit(ImageFit.Contain)
        Column() {
          Text('暂无校园资讯').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#555555').width('100%')
          Text('稍后再试，或点击右侧刷新').fontSize(11).fontColor('#999999').margin({ top: 2 }).width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
        Text('刷新').fontSize(13).fontColor('#20C997').onClick(() => this.load(true))
      }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(Color.White).borderRadius(12).margin({ bottom: 16 })
    } else {
      Column() {
        ForEach(this.articles, (item: NewsArticle) => {
          Column() {
            Text(item.title || '未命名资讯').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333333')
              .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (item.summary) {
              Text(item.summary).fontSize(12).fontColor('#888888').width('100%').maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 6 })
            }
            Row() {
              Text(item.category_name || '校园资讯').fontSize(11).fontColor('#20C997')
              Blank()
              Text((item.published_at || '').substring(0, 10)).fontSize(11).fontColor('#AAAAAA')
            }.width('100%').margin({ top: 8 })
          }
          .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12).margin({ bottom: 10 })
          .onClick(() => this.openArticle(item))
        }, (item: NewsArticle) => item.id || item.title || '')

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

  build() {
    Column() {
      Row() {
        Text('校园').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#555555')
        Text('SCHOOL').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#777777').margin({ left: 12 })
        Blank()
        Image($r('app.media.refresh')).width(22).height(22)
          .onClick(() => this.load(true))
      }.width('100%').padding({ left: 28, right: 24, top: 32, bottom: 18 })

      Scroll() {
        Column() {
          this.newsSection()

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
        .width('100%').padding({ left: 18, right: 18, bottom: 24 })
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor('#F5F6F7')
  }
}
