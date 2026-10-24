import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { SecondHandBookApi, SecondhandListing } from '../../net/SecondHandBookApi';

@Entry
@Component
struct SecondHandBookPage {
  @State private listings: SecondhandListing[] = [];
  @State private query: string = '';
  @State private searching: boolean = false;
  @State private loading: boolean = true;
  @State private filterOpen: boolean = false;
  @State private filterType: string = '';
  @State private activeCampus: string = '全部校区';
  @State private pendingCampus: string = '全部校区';
  @State private activeSort: string = '默认排序';
  @State private pendingSort: string = '默认排序';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    try { this.listings = await SecondHandBookApi.feed(this.query); }
    catch { promptAction.showToast({ message: '二手书信息加载失败', duration: 1500 }); }
    this.loading = false;
  }

  private money(value: number | undefined): string { return `¥${(value || 0).toFixed(2)}`; }

  private campusMatches(item: SecondhandListing): boolean {
    if (this.activeCampus === '全部校区') return true;
    const text = `${item.campus || ''}${item.campusName || ''}${item.note || ''}`.toLowerCase();
    return text.indexOf(this.activeCampus.toLowerCase()) >= 0;
  }

  private visibleListings(): SecondhandListing[] {
    const result = this.listings.filter((item: SecondhandListing) => this.campusMatches(item));
    if (this.activeSort === '最新发布') return result.sort((a: SecondhandListing, b: SecondhandListing) => (b.createdAt || 0) - (a.createdAt || 0));
    if (this.activeSort === '价格升序') return result.sort((a: SecondhandListing, b: SecondhandListing) => (a.price || 0) - (b.price || 0));
    if (this.activeSort === '价格降序') return result.sort((a: SecondhandListing, b: SecondhandListing) => (b.price || 0) - (a.price || 0));
    return result;
  }

  private openCampusFilter(): void {
    this.pendingCampus = this.activeCampus;
    this.filterType = 'campus';
    animateTo({ duration: 240, curve: Curve.EaseInOut }, () => { this.filterOpen = true; });
  }

  private openSortFilter(): void {
    this.pendingSort = this.activeSort;
    this.filterType = 'sort';
    animateTo({ duration: 240, curve: Curve.EaseInOut }, () => { this.filterOpen = true; });
  }

  private closeFilter(): void { animateTo({ duration: 240, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }

  private applyFilter(): void {
    if (this.filterType === 'campus') this.activeCampus = this.pendingCampus;
    if (this.filterType === 'sort') this.activeSort = this.pendingSort;
    this.closeFilter();
  }

  @Builder
  private filterButton(label: string) {
    Row() {
      Text(label).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#50535A').maxLines(1);
      Text('▾').fontSize(15).fontColor('#777A80').margin({ left: 8 });
    }.justifyContent(FlexAlign.Center).height(52).layoutWeight(1)
  }

  @Builder
  private optionTag(label: string, selected: boolean) {
    Text(label).fontSize(17).fontWeight(FontWeight.Medium).fontColor(selected ? '#20C894' : '#777777')
      .backgroundColor(selected ? '#E7F8F2' : '#F5F5F5').borderRadius(20)
      .padding({ left: 18, right: 18, top: 9, bottom: 9 }).margin({ right: 10, bottom: 10 })
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).width(48).onClick(() => router.back());
        Text('二手书').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 });
        Blank().layoutWeight(1);
        Image($r('app.media.search')).width(25).height(25).onClick(() => { this.searching = !this.searching; });
      }.width('100%').height(76).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');

      if (this.searching) {
        Row() {
          TextInput({ placeholder: '搜索书名、作者', text: this.query }).layoutWeight(1).fontSize(18)
            .onChange((value: string) => { this.query = value; }).onSubmit(() => this.load());
          Text('搜索').fontSize(17).fontColor('#857A25').margin({ left: 10 }).onClick(() => this.load());
        }.width('92%').height(52).padding({ left: 16, right: 12 }).backgroundColor(Color.White).borderRadius(26);
      }

      Row() {
        Column() { this.filterButton('全部专业'); }.layoutWeight(1)
          .onClick(() => promptAction.showToast({ message: '专业筛选稍后开放', duration: 1100 }));
        Column() { this.filterButton(this.activeCampus); }.layoutWeight(1).onClick(() => this.openCampusFilter());
        Column() { this.filterButton(this.activeSort); }.layoutWeight(1).onClick(() => this.openSortFilter());
      }.width('100%').padding({ left: 10, right: 10, top: 4, bottom: 4 });

      if (this.filterOpen) {
        Column() {
          Text(this.filterType === 'campus' ? '选择校区' : '选择排序方式')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555').width('100%').margin({ bottom: 10 });
          Flex({ wrap: FlexWrap.Wrap }) {
            if (this.filterType === 'campus') {
              ForEach(['全部校区', '黄家湖', '青山', '洪山'], (item: string) => {
                Column() { this.optionTag(item, this.pendingCampus === item); }.onClick(() => { this.pendingCampus = item; });
              })
            } else {
              ForEach(['默认排序', '最新发布', '价格升序', '价格降序'], (item: string) => {
                Column() { this.optionTag(item, this.pendingSort === item); }.onClick(() => { this.pendingSort = item; });
              })
            }
          }.width('100%');
          Row() {
            Text('取消').fontSize(17).fontColor('#999999').layoutWeight(1).onClick(() => this.closeFilter());
            Text('确定').fontSize(17).fontColor('#20C894').onClick(() => this.applyFilter());
          }.width('100%').margin({ top: 4 });
        }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ bottom: 10 })
          .shadow({ radius: 12, color: '#22000000', offsetY: 3 })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 0, y: -80 })))
          .animation({ duration: 240, curve: Curve.EaseInOut });
      }

      Scroll() {
        Column() {
          if (this.loading) {
            Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 });
          } else if (this.visibleListings().length === 0) {
            Text('暂无符合条件的书籍').fontSize(18).fontColor('#999999').margin({ top: 80 });
          } else {
            ForEach(this.visibleListings(), (item: SecondhandListing) => {
              Row() {
                if (item.bookCover) { Image(item.bookCover).width(92).height(116).objectFit(ImageFit.Cover).borderRadius(10).margin({ right: 16 }); }
                Column() {
                  Text(item.bookTitle || '未命名书籍').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#857A25').maxLines(2);
                  if (item.bookAuthor) { Text(item.bookAuthor).fontSize(15).fontColor('#888888'); }
                  Text(item.condition || '成色未知').fontSize(16).fontColor('#555555').margin({ top: 8 });
                  if (item.note) { Text(item.note).fontSize(15).fontColor('#777777').maxLines(2); }
                  Text(this.money(item.price)).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#B26E2A').margin({ top: 8 });
                }.layoutWeight(1);
              }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ top: 10 })
                .onClick(() => { if (item.contact) promptAction.showToast({ message: `联系方式：${item.contact}`, duration: 2200 }); });
            }, (item: SecondhandListing) => `${item.id || item.bookId || item.bookTitle}`)
          }
        }.width('100%').padding({ bottom: 24 }).backgroundColor('#F5F6F8');
      }.layoutWeight(1);

      Row() {
        Text('发布二手书').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .textAlign(TextAlign.Center).width('88%').height(54).backgroundColor('#857A25').borderRadius(27);
      }.margin({ bottom: 16 }).onClick(() => router.pushUrl({ url: 'pages/campus/SecondHandBookPublishPage' }));
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
