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

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(48).fontColor(Color.White).fontWeight(FontWeight.Lighter).width(52).onClick(() => router.back())
        Text('图书馆').fontSize(28).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 12 }).layoutWeight(1)
        Image($r('app.media.search')).width(30).height(30).fillColor(Color.White).onClick(() => this.openEntry(this.entries[0]))
      }
      .width('100%').height(96).padding({ left: 22, right: 28, top: 24 }).backgroundColor(LIBRARY_GREEN)

      Scroll() {
        Row({ space: 34 }) {
          Text('图书服务').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
          Text('收藏').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
          Text('公告通知').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
          Text('首页推荐').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
          Text('活动资讯').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
          Text('资源导航').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
        }
        .height(58).padding({ left: 20, right: 20 }).alignItems(VerticalAlign.Center)
        .constraintSize({ minWidth: 650 })
      }
      .width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .backgroundColor(Color.White).border({ width: { bottom: 3 }, color: '#91D04E' })

      Scroll() {
        Column({ space: 24 }) {
          ForEach(this.entries, (item: LibraryEntry) => { this.serviceCard(item) })
          Text('领航工作室出品').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#777777').margin({ top: 8, bottom: 30 })
        }
        .width('100%').padding({ left: 22, right: 22, top: 34 })
      }
      .width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor('#F7F7F7')
  }
}
