import { router } from '@kit.ArkUI';
import {
  LibraryApi, LibraryNotice, LibraryHomeArticle, LibraryArticle, LibraryResource,
  articleTagLabel, resourceTypeLabel
} from '../../net/LibraryApi';
import { LibraryFavorites, LibraryFavorite } from '../../store/LibraryFavorites';

interface LibraryEntry {
  title: string;
  description: string;
  icon: Resource;
  route: string;
}

const LIBRARY_GREEN: string = '#20C894';
const RESOURCE_TYPES: number[] = [1, 2, 3, 4];

@Entry
@Component
struct LibraryPage {
  @State private selectedTab: number = 0;
  @State private loading: boolean = false;
  @State private errorText: string = '';
  @State private notice: LibraryNotice = {};
  @State private hasNotice: boolean = false;
  @State private noticeOpen: boolean = false;
  @State private homeArticles: LibraryHomeArticle[] = [];
  @State private articles: LibraryArticle[] = [];
  @State private resources: LibraryResource[] = [];
  @State private favorites: LibraryFavorite[] = [];
  // 收藏状态存在非响应式 store 里，改这个计数器触发列表刷新。
  @State private favoriteTick: number = 0;
  private tabsLoaded: boolean[] = [true, false, false, false, false, false];
  // 每个栏目自己的错误文案：切走再切回来时恢复，避免空白且没有重试入口。
  private tabErrors: string[] = ['', '', '', '', '', ''];
  private favoritesStore: LibraryFavorites = LibraryFavorites.getInstance();

  private navTabs: string[] = ['图书服务', '我的收藏', '公告通知', '首页推荐', '活动资讯', '资源导航'];
  private entries: LibraryEntry[] = [
    { title: '馆藏查询', description: '查询喜欢的图书收藏吧～', icon: $r('app.media.library_catalog'), route: 'catalog' },
    { title: '图书借阅', description: '随时了解图书借阅情况～', icon: $r('app.media.book_borrowing'), route: 'pages/library/LibraryBorrowingPage' },
    { title: '读者信息', description: '查看账户状态与借阅额度', icon: $r('app.media.reader_information'), route: 'pages/library/LibraryReaderInfoPage' },
    { title: '即将超期', description: '查看 7 天内到期图书并续借', icon: $r('app.media.about_to_expire'), route: 'pages/library/LibraryExpiringPage' },
  ];

  aboutToAppear(): void {
    this.refreshFavorites();
  }

  private async refreshFavorites(): Promise<void> {
    this.favorites = await this.favoritesStore.list();
    this.favoriteTick = this.favoriteTick + 1;
  }

  private selectTab(index: number): void {
    this.selectedTab = index;
    if (index === 1) {
      this.refreshFavorites();
      return;
    }
    // 恢复该栏目自己的错误状态：否则从别的栏目切回来时错误已被清空，
    // 数据又没加载成功，页面就成了没有重试入口的空白页。
    this.errorText = this.tabErrors[index];
    if (!this.tabsLoaded[index]) {
      this.loadTab(index);
    }
  }

  private async loadTab(index: number): Promise<void> {
    this.loading = true;
    this.tabErrors[index] = '';
    if (this.selectedTab === index) {
      this.errorText = '';
    }
    try {
      if (index === 2) {
        this.notice = (await LibraryApi.latestNotice()) || {};
        this.hasNotice = (this.notice.id || 0) > 0;
        if (this.articles.length === 0) {
          this.articles = await LibraryApi.articles();
        }
      } else if (index === 3) {
        this.homeArticles = await LibraryApi.homeArticles();
      } else if (index === 4) {
        this.articles = await LibraryApi.articles();
      } else if (index === 5) {
        this.resources = await LibraryApi.resources(0);
      }
      if (this.isEmptyTab(index)) {
        this.tabErrors[index] = '暂时没有内容，请稍后重试';
        this.tabsLoaded[index] = true;
      } else {
        this.tabErrors[index] = '';
        this.tabsLoaded[index] = true;
      }
    } catch {
      // 失败时不把该栏目标记为已加载：切回来会重新请求，错误页始终带「重新加载」。
      this.tabErrors[index] = '加载失败，请稍后重试';
      this.tabsLoaded[index] = false;
    }
    if (this.selectedTab === index) {
      this.errorText = this.tabErrors[index];
    }
    this.loading = false;
  }

  private isEmptyTab(index: number): boolean {
    if (index === 2) return !this.hasNotice && this.noticeArticles().length === 0;
    if (index === 3) return this.homeArticles.length === 0;
    if (index === 4) return this.articles.length === 0;
    if (index === 5) return this.resources.length === 0;
    return false;
  }

  private reloadCurrent(): void {
    const index = this.selectedTab;
    if (index > 0) {
      this.tabsLoaded[index] = true;
      this.loadTab(index);
    }
  }

  private openEntry(item: LibraryEntry): void {
    if (item.route === 'catalog') {
      router.pushUrl({ url: 'pages/common/WebPage', params: { title: '馆藏查询', url: 'https://libsys.wust.edu.cn/' } });
      return;
    }
    router.pushUrl({ url: item.route });
  }

  private openLink(title: string, url: string): void {
    if (!url) return;
    router.pushUrl({ url: 'pages/common/WebPage', params: { title: title || '图书馆', url } });
  }

  private formatDate(value?: string): string {
    const text = (value || '').trim();
    if (!text) return '';
    const stamp = Date.parse(text);
    if (isNaN(stamp)) return text;
    const date = new Date(stamp);
    const pad = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private noticeArticles(): LibraryArticle[] {
    return this.articles.filter((item: LibraryArticle) => articleTagLabel(item.tag) === '通知');
  }

  private resourcesOfType(type: number): LibraryResource[] {
    return this.resources.filter((item: LibraryResource) => item.type === type);
  }

  private isFavorite(kind: string, id: number): boolean {
    // 依赖 favoriteTick，收藏变化后列表会重新渲染。
    return this.favoriteTick >= 0 && this.favoritesStore.has(kind, id);
  }

  private async toggleArticleFavorite(item: LibraryArticle): Promise<void> {
    await this.favoritesStore.toggle({
      kind: 'article', id: item.id || 0, title: item.title || '',
      link: item.link || '', tag: articleTagLabel(item.tag)
    });
    await this.refreshFavorites();
  }

  private async toggleResourceFavorite(item: LibraryResource): Promise<void> {
    await this.favoritesStore.toggle({
      kind: 'resource', id: item.id || 0, title: item.title || '',
      link: item.inLink || item.outLink || '', tag: '资源'
    });
    await this.refreshFavorites();
  }

  private async removeFavorite(item: LibraryFavorite): Promise<void> {
    await this.favoritesStore.toggle(item);
    await this.refreshFavorites();
  }

  @Builder
  private serviceCard(item: LibraryEntry) {
    Row() {
      Column() {
        Text(item.title).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#303030')
        Text(item.description).fontSize(16).fontColor('#777777').margin({ top: 18 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image(item.icon).width(92).height(92).objectFit(ImageFit.Contain).margin({ left: 16 })
    }
    .width('100%').height(144).padding({ left: 48, right: 38 })
    .backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 8, color: '#1A000000', offsetY: 3 })
    .onClick(() => this.openEntry(item))
  }

  @Builder
  private navigationItem(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedTab === index ? '#333333' : '#666666')
        .height(48)
        .textAlign(TextAlign.Center)
      Divider()
        .width('100%')
        .height(3)
        .color(this.selectedTab === index ? '#91D04E' : '#E5E5E5')
    }
    .width(index === 0 ? 96 : 104)
    .height(51)
    .onClick(() => this.selectTab(index))
  }

  @Builder
  private bellIcon() {
    Image($r('app.media.bell')).width(26).height(26).objectFit(ImageFit.Contain).margin({ right: 10 })
  }

  @Builder
  private statusContent() {
    if (this.loading) {
      Column() {
        LoadingProgress().width(42).height(42).color(LIBRARY_GREEN)
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    } else if (this.errorText.length > 0) {
      Column() {
        Text(this.errorText).fontSize(17).fontColor('#888888')
        Button('重新加载').margin({ top: 16 }).backgroundColor(LIBRARY_GREEN).fontColor(Color.White)
          .onClick(() => this.reloadCurrent())
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  private serviceContent() {
    Scroll() {
      Column({ space: 24 }) {
        ForEach(this.entries, (item: LibraryEntry) => { this.serviceCard(item) })
        Text('领航工作室出品').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#777777').margin({ top: 8, bottom: 30 })
      }
      .width('100%').padding({ left: 22, right: 22, top: 28 })
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off)
  }

  @Builder
  private emptyContent(text: string) {
    Column() {
      Image($r('app.media.empty')).width(92).height(92).objectFit(ImageFit.Contain)
      Text(text).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#42C99A').margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private favoritesContent() {
    if (this.favorites.length === 0) {
      this.emptyContent('还没有收藏内容')
    } else {
      List() {
        ForEach(this.favorites, (item: LibraryFavorite) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.tag).fontSize(14).fontColor('#8A8A8A')
                Text(item.title).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ top: 6 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Image($r('app.media.bell')).width(24).height(24).objectFit(ImageFit.Contain).opacity(0.25)
              Text('取消').fontSize(15).fontColor('#E6584A').margin({ left: 12 })
                .onClick(() => this.removeFavorite(item))
            }
            .width('100%').padding({ left: 22, right: 22, top: 18, bottom: 18 }).backgroundColor(Color.White)
            .border({ width: { bottom: 1 }, color: '#EFEFEF' })
            .onClick(() => this.openLink(item.title, item.link))
          }
        }, (item: LibraryFavorite) => `${item.kind}-${item.id}`)
      }.width('100%').layoutWeight(1).backgroundColor(Color.White)
    }
  }

  @Builder
  private noticeContent() {
    Scroll() {
      Column() {
        if (this.hasNotice) {
          Column() {
            Row() {
              this.bellIcon()
              Text('最新通知').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
            }.width('100%')
            Text(this.notice.title || '').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#333333')
              .width('100%').margin({ top: 12 })
            Text(this.formatDate(this.notice.createdAt)).fontSize(15).fontColor('#999999')
              .width('100%').textAlign(TextAlign.End).margin({ top: 10 })
          }
          .width('100%').padding({ left: 22, right: 22, top: 18, bottom: 18 }).backgroundColor(Color.White)
          .border({ width: { bottom: 1 }, color: '#EFEFEF' })
          .onClick(() => { this.noticeOpen = true; })
        }
        if (this.noticeArticles().length > 0) {
          Row() {
            this.bellIcon()
            Text('通知公告').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
          }.width('100%').padding({ left: 22, right: 22, top: 16, bottom: 10 }).backgroundColor('#F7F7F7')
          ForEach(this.noticeArticles(), (item: LibraryArticle) => {
            Column() {
              Row() {
                this.bellIcon()
                Text(articleTagLabel(item.tag)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#C28B1E')
              }.width('100%')
              Text(item.title || '').fontSize(19).fontWeight(FontWeight.Medium).fontColor('#333333')
                .width('100%').margin({ top: 10 })
              Text(item.link || '').fontSize(15).fontColor('#7A8581').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 8 })
            }
            .width('100%').padding({ left: 22, right: 22, top: 16, bottom: 16 }).backgroundColor(Color.White)
            .border({ width: { bottom: 1 }, color: '#EFEFEF' })
            .onClick(() => this.openLink(item.title || '', item.link || ''))
          }, (item: LibraryArticle) => `notice-${item.id}`)
        }
        if (!this.hasNotice && this.noticeArticles().length === 0) {
          this.statusContent()
        }
      }.width('100%')
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).backgroundColor('#F7F7F7')
  }

  @Builder
  private homeContent() {
    Scroll() {
      Column() {
        ForEach(this.homeArticles, (item: LibraryHomeArticle, index: number) => {
          Column() {
            Image(item.pictureLink || '').width('100%').height(260).objectFit(ImageFit.Cover)
            Text('馆内推荐').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
              .width('100%').margin({ top: 14 })
            Text(`推荐内容 ${index + 1}`).fontSize(17).fontColor('#888888').width('100%').margin({ top: 8 })
          }
          .width('100%').padding({ left: 22, right: 22, top: 18, bottom: 22 }).backgroundColor(Color.White)
          .border({ width: { bottom: 1 }, color: '#EFEFEF' })
          .onClick(() => this.openLink('首页推荐', item.articleLink || ''))
        }, (item: LibraryHomeArticle) => `home-${item.id}`)
        if (this.homeArticles.length === 0) {
          this.statusContent()
        }
      }.width('100%')
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).backgroundColor('#F7F7F7')
  }

  @Builder
  private activityContent() {
    Scroll() {
      Column() {
        ForEach(this.articles, (item: LibraryArticle) => {
          Row() {
            Column() {
              Row() {
                this.bellIcon()
                Text(articleTagLabel(item.tag)).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#C28B1E')
              }.width('100%')
              Text(item.title || '').fontSize(19).fontWeight(FontWeight.Medium).fontColor('#333333')
                .width('100%').margin({ top: 10 })
              Text(item.link || '').fontSize(15).fontColor('#7A8581').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 8 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text(this.isFavorite('article', item.id || 0) ? '★' : '☆')
              .fontSize(26).fontColor(this.isFavorite('article', item.id || 0) ? '#F2B01E' : '#BBBBBB')
              .margin({ left: 10 })
              .onClick(() => this.toggleArticleFavorite(item))
          }
          .width('100%').padding({ left: 22, right: 22, top: 16, bottom: 16 }).backgroundColor(Color.White)
          .border({ width: { bottom: 1 }, color: '#EFEFEF' })
          .onClick(() => this.openLink(item.title || '', item.link || ''))
        }, (item: LibraryArticle) => `article-${item.id}`)
        if (this.articles.length === 0) {
          this.statusContent()
        }
      }.width('100%')
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).backgroundColor('#F7F7F7')
  }

  @Builder
  private resourceRow(item: LibraryResource) {
    Row() {
      Column() {
        Text(item.title || '').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333')
        if ((item.content || '').length > 0 && item.content !== '无') {
          Text(item.content || '').fontSize(15).fontColor('#888888').maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 6 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(this.isFavorite('resource', item.id || 0) ? '★' : '☆')
        .fontSize(26).fontColor(this.isFavorite('resource', item.id || 0) ? '#F2B01E' : '#BBBBBB')
        .margin({ left: 10 })
        .onClick(() => this.toggleResourceFavorite(item))
    }
    .width('100%').padding({ left: 22, right: 22, top: 15, bottom: 15 }).backgroundColor(Color.White)
    .border({ width: { bottom: 1 }, color: '#EFEFEF' })
    .onClick(() => this.openLink(item.title || '', item.inLink || item.outLink || ''))
  }

  @Builder
  private resourceContent() {
    Scroll() {
      Column() {
        ForEach(RESOURCE_TYPES, (type: number) => {
          if (this.resourcesOfType(type).length > 0) {
            Text(resourceTypeLabel(type)).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#333333')
              .width('100%').padding({ left: 22, right: 22, top: 18, bottom: 8 }).backgroundColor('#F7F7F7')
            ForEach(this.resourcesOfType(type), (item: LibraryResource) => {
              this.resourceRow(item)
            }, (item: LibraryResource) => `resource-${item.id}`)
          }
        }, (type: number) => `type-${type}`)
        if (this.resources.length === 0) {
          this.statusContent()
        }
      }.width('100%')
    }
    .width('100%').layoutWeight(1).scrollBar(BarState.Off).backgroundColor('#F7F7F7')
  }

  @Builder
  private noticeDialog() {
    Column() {
      Column() {
        Text(this.notice.title || '最新通知').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').width('100%')
        Text(this.formatDate(this.notice.createdAt)).fontSize(14).fontColor('#999999').width('100%').margin({ top: 8 })
        Scroll() {
          Text(this.notice.content || '暂无内容').fontSize(17).fontColor('#444444').lineHeight(26).width('100%')
        }
        .height(240).width('100%').margin({ top: 16 })
        Button('关闭').width('100%').height(48).backgroundColor(LIBRARY_GREEN).fontColor(Color.White)
          .margin({ top: 18 }).onClick(() => { this.noticeOpen = false; })
      }
      .width('84%').padding({ left: 24, right: 24, top: 24, bottom: 24 }).backgroundColor(Color.White).borderRadius(16)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#99000000')
    .onClick(() => { this.noticeOpen = false; })
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('‹').fontSize(42).fontColor(Color.White).fontWeight(FontWeight.Lighter).width(46).onClick(() => router.back())
          Text('图书馆').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 8 }).layoutWeight(1)
          Image($r('app.media.search')).width(27).height(27).fillColor(Color.White).onClick(() => this.openEntry(this.entries[0]))
        }
        .width('100%').height(72).padding({ left: 18, right: 24, top: 8 }).backgroundColor(LIBRARY_GREEN)

        Scroll() {
          Row() {
            ForEach(this.navTabs, (title: string, index: number) => {
              this.navigationItem(title, index)
            })
          }
          .height(51)
          .constraintSize({ minWidth: 616 })
        }
        .width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .backgroundColor(Color.White)

        if (this.selectedTab === 0) {
          this.serviceContent()
        } else if (this.selectedTab === 1) {
          this.favoritesContent()
        } else if (this.selectedTab === 2) {
          this.noticeContent()
        } else if (this.selectedTab === 3) {
          this.homeContent()
        } else if (this.selectedTab === 4) {
          this.activityContent()
        } else {
          this.resourceContent()
        }
      }
      .width('100%').height('100%').backgroundColor('#F7F7F7')

      if (this.noticeOpen) {
        this.noticeDialog()
      }
    }
    .width('100%').height('100%')
  }
}
