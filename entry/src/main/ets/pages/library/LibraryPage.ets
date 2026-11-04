import { router } from '@kit.ArkUI';

interface LibraryEntry {
  title: string;
  description: string;
  icon: Resource;
  route: string;
}

const LIBRARY_GREEN: string = '#20C894';

@Entry
@Component
struct LibraryPage {
  @State private selectedTab: number = 0;
  private navTabs: string[] = ['图书服务', '收藏', '公告通知', '首页推荐', '活动资讯', '资源导航'];
  private entries: LibraryEntry[] = [
    { title: '馆藏查询', description: '查询喜欢的图书收藏吧～', icon: $r('app.media.library_catalog'), route: 'catalog' },
    { title: '图书借阅', description: '随时了解图书借阅情况～', icon: $r('app.media.book_borrowing'), route: 'pages/library/LibraryBorrowingPage' },
    { title: '读者信息', description: '查看账户状态与借阅额度', icon: $r('app.media.reader_information'), route: 'pages/library/LibraryReaderInfoPage' },
    { title: '即将超期', description: '查看 7 天内到期图书并续借', icon: $r('app.media.about_to_expire'), route: 'pages/library/LibraryExpiringPage' },
  ];

  private openEntry(item: LibraryEntry): void {
    if (item.route === 'catalog') {
      router.pushUrl({ url: 'pages/common/WebPage', params: { title: '馆藏查询', url: 'https://libsys.wust.edu.cn/' } });
      return;
    }
    router.pushUrl({ url: item.route });
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
    .onClick(() => { this.selectedTab = index; })
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
  private emptyContent() {
    Column() {
      Image($r('app.media.empty')).width(92).height(92).objectFit(ImageFit.Contain)
      Text('没有内容').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#42C99A').margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
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
      } else {
        this.emptyContent()
      }
    }
    .width('100%').height('100%').backgroundColor('#F7F7F7')
  }
}
