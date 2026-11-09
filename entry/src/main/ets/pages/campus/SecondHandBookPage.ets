import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { SecondHandBookApi, SecondhandListing } from '../../net/SecondHandBookApi';
import { AppStorage } from '../../store/AppStorage';
import { CommunityNavigationStore } from '../../store/CommunityNavigationStore';

@Entry
@Component
struct SecondHandBookPage {
  @State private listings: SecondhandListing[] = [];
  @State private query: string = '';
  @State private searching: boolean = false;
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private nativePage: number = 1;
  @State private communityPage: number = 1;
  @State private nativeHasMore: boolean = true;
  @State private communityHasMore: boolean = true;
  private readonly pageSize: number = 20;
  // 每次刷新递增；旧的分页/首屏响应只有在代次未变时才允许写回列表和页码。
  private requestGeneration: number = 0;
  @State private avatarUrl: string = '';
  @State private selfMajor: string = '';
  @State private majors: string[] = [];
  @State private activeMajorMode: string = '全部专业';
  @State private pendingMajorMode: string = '全部专业';
  @State private filterOpen: boolean = false;
  @State private activeMajor: string = '全部专业';
  @State private pendingMajor: string = '全部专业';
  @State private activeMajors: string[] = [];
  @State private pendingMajors: string[] = [];
  @State private activeCampus: string = '全部校区';
  @State private pendingCampus: string = '全部校区';
  @State private activeSort: string = '默认排序';
  @State private pendingSort: string = '默认排序';
  @State private refreshing: boolean = false;
  private listScroller: Scroller = new Scroller();
  private pendingRestoreOffset: number = -1;
  private readonly pageKey: string = 'secondhand';

  aboutToAppear(): void { this.loadProfile(); this.loadMajors(); }
  onPageShow(): void {
    const navigation = CommunityNavigationStore.getInstance();
    const deletedCampusIds = navigation.consumeDeletedCampusPostIds();
    const deletedSecondhandIds = navigation.consumeDeletedSecondhandIds();
    if (deletedCampusIds.length > 0 || deletedSecondhandIds.length > 0) {
      this.listings = this.listings.filter((item: SecondhandListing) => item.source === 'community'
        ? deletedCampusIds.indexOf(item.communityPostId || item.id || 0) < 0
        : deletedSecondhandIds.indexOf(item.id || 0) < 0);
    }
    const returnOffset = navigation.consumeListReturnOffset(this.pageKey);
    if (returnOffset >= 0) {
      this.pendingRestoreOffset = returnOffset;
      if (this.listings.length > 0) {
        this.restoreListOffset();
      } else {
        this.load().then((): void => { this.restoreListOffset(); });
      }
      return;
    }
    this.load();
  }
  private openDetail(item: SecondhandListing): void {
    CommunityNavigationStore.getInstance().rememberListReturn(this.pageKey, this.listScroller.currentOffset().yOffset);
    router.pushUrl({ url: 'pages/campus/SecondHandBookDetailPage', params: { listing: JSON.stringify(item) } });
  }
  private async loadProfile(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.avatarUrl = await storage.getAvatarUrl();
    this.selfMajor = await storage.getMajor();
  }

  private async loadMajors(): Promise<void> {
    try { this.majors = await SecondHandBookApi.majors(); } catch { this.majors = []; }
  }

  private restoreListOffset(): void {
    if (this.pendingRestoreOffset < 0) return;
    const offset = this.pendingRestoreOffset;
    this.pendingRestoreOffset = -1;
    setTimeout((): void => {
      this.listScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
    }, 80);
  }
  private async refreshList(): Promise<void> {
    if (this.refreshing) return;
    this.refreshing = true;
    try {
      await this.load();
    } finally {
      this.refreshing = false;
    }
  }
  private async load(): Promise<void> {
    const generation = ++this.requestGeneration;
    this.loading = true;
    this.loadingMore = false;
    this.listings = [];
    this.nativePage = 1;
    this.communityPage = 1;
    this.nativeHasMore = true;
    this.communityHasMore = true;
    let listings: SecondhandListing[] = [];
    let community: SecondhandListing[] = [];
    try {
      listings = await SecondHandBookApi.feed(this.query, '', '', 1, this.pageSize);
      listings.forEach((item: SecondhandListing) => { if (!item.source) item.source = 'secondhand'; });
    } catch {}
    if (generation !== this.requestGeneration) return;
    try { community = await SecondHandBookApi.communityFeed(1); } catch {}
    if (generation !== this.requestGeneration) return;
    this.nativeHasMore = listings.length >= this.pageSize;
    this.communityHasMore = community.length >= this.pageSize;
    const keyword = this.query.trim().toLowerCase();
    const matched = keyword.length === 0 ? community : community.filter((item: SecondhandListing) =>
      `${item.bookTitle || ''} ${item.note || ''} ${item.bookAuthor || ''}`.toLowerCase().indexOf(keyword) >= 0);
    this.listings = this.appendUniqueListings([], listings.concat(matched));
    if (this.listings.length === 0 && listings.length === 0 && community.length === 0) {
      promptAction.showToast({ message: '暂无二手书信息', duration: 1200 });
    }
    this.loading = false;
  }

  private listingKey(item: SecondhandListing): string {
    return `${item.source || 'secondhand'}-${item.communityPostId || item.id || item.bookId || item.bookTitle || ''}`;
  }

  private appendUniqueListings(current: SecondhandListing[], incoming: SecondhandListing[]): SecondhandListing[] {
    const result = current.slice();
    const keys: string[] = result.map((item: SecondhandListing) => this.listingKey(item));
    incoming.forEach((item: SecondhandListing) => {
      const key = this.listingKey(item);
      if (keys.indexOf(key) < 0) { result.push(item); keys.push(key); }
    });
    return result;
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || (!this.nativeHasMore && !this.communityHasMore)) return;
    const generation = this.requestGeneration;
    this.loadingMore = true;
    let incoming: SecondhandListing[] = [];
    if (this.nativeHasMore) {
      const nextNativePage = this.nativePage + 1;
      try {
        const nativeItems = await SecondHandBookApi.feed(this.query, '', '', nextNativePage, this.pageSize);
        if (generation !== this.requestGeneration) return;
        nativeItems.forEach((item: SecondhandListing) => { if (!item.source) item.source = 'secondhand'; });
        incoming = incoming.concat(nativeItems);
        this.nativePage = nextNativePage;
        this.nativeHasMore = nativeItems.length >= this.pageSize;
      } catch {
        if (generation !== this.requestGeneration) return;
        this.nativeHasMore = false;
      }
    }
    if (this.communityHasMore) {
      const nextCommunityPage = this.communityPage + 1;
      try {
        const communityItems = await SecondHandBookApi.communityFeed(nextCommunityPage);
        if (generation !== this.requestGeneration) return;
        const keyword = this.query.trim().toLowerCase();
        const matched = keyword.length === 0 ? communityItems : communityItems.filter((item: SecondhandListing) =>
          `${item.bookTitle || ''} ${item.note || ''} ${item.bookAuthor || ''}`.toLowerCase().indexOf(keyword) >= 0);
        incoming = incoming.concat(matched);
        this.communityPage = nextCommunityPage;
        this.communityHasMore = communityItems.length >= this.pageSize;
      } catch {
        if (generation !== this.requestGeneration) return;
        this.communityHasMore = false;
      }
    }
    this.listings = this.appendUniqueListings(this.listings, incoming);
    this.loadingMore = false;
  }

  private money(value: number | undefined): string { return `¥${(value || 0).toFixed(2)}`; }

  private campusMatches(item: SecondhandListing): boolean {
    if (this.activeCampus === '全部校区') return true;
    const text = `${item.campus || ''}${item.campusName || ''}${item.note || ''}`.toLowerCase();
    return text.indexOf(this.activeCampus.toLowerCase()) >= 0;
  }

  private majorMatches(item: SecondhandListing): boolean {
    if (this.activeMajorMode === '全部专业') return true;
    const itemMajor = `${item.major || ''} ${item.note || ''}`.trim().toLowerCase();
    if (this.activeMajorMode === '我的专业') {
      return this.selfMajor.length > 0 && itemMajor.indexOf(this.selfMajor.toLowerCase()) >= 0;
    }
    if (this.activeMajors.length === 0) return true;
    return this.activeMajors.some((major: string) => itemMajor.indexOf(major.toLowerCase()) >= 0);
  }

  private visibleListings(): SecondhandListing[] {
    const result = this.listings.filter((item: SecondhandListing) => this.majorMatches(item) && this.campusMatches(item));
    if (this.activeSort === '最新发布') return result.sort((a: SecondhandListing, b: SecondhandListing) => this.createdStamp(b.createdAt) - this.createdStamp(a.createdAt));
    if (this.activeSort === '价格升序') return result.sort((a: SecondhandListing, b: SecondhandListing) => (a.price || 0) - (b.price || 0));
    if (this.activeSort === '价格降序') return result.sort((a: SecondhandListing, b: SecondhandListing) => (b.price || 0) - (a.price || 0));
    return result;
  }

  private createdStamp(value?: number | string): number {
    if (typeof value === 'number') return value < 100000000000 ? value * 1000 : value;
    const stamp = Date.parse(value || '');
    return isNaN(stamp) ? 0 : stamp;
  }

  private openFilter(): void {
    this.pendingMajor = this.activeMajor;
    this.pendingMajors = this.activeMajors.slice();
    this.pendingMajorMode = this.activeMajorMode;
    this.pendingCampus = this.activeCampus;
    this.pendingSort = this.activeSort;
    animateTo({ duration: 240, curve: Curve.EaseInOut }, () => { this.filterOpen = true; });
  }

  private closeFilter(): void { animateTo({ duration: 240, curve: Curve.EaseInOut }, () => { this.filterOpen = false; }); }

  private applyFilter(): void {
    this.activeMajor = this.pendingMajor;
    this.activeMajors = this.pendingMajors.slice();
    this.activeMajorMode = this.pendingMajorMode;
    this.activeCampus = this.pendingCampus;
    this.activeSort = this.pendingSort;
    this.closeFilter();
    this.load();
  }

  private chooseMajorMode(mode: string): void {
    if (mode === '指定专业') {
      this.pendingMajorMode = mode;
      this.pendingMajor = this.pendingMajors.join('、');
      if (this.majors.length === 0) this.loadMajors();
      return;
    }
    this.pendingMajorMode = mode;
    this.pendingMajor = mode;
    this.pendingMajors = [];
  }

  private togglePendingMajor(major: string): void {
    if (this.pendingMajors.indexOf(major) >= 0) {
      this.pendingMajors = this.pendingMajors.filter((item: string) => item !== major);
    } else {
      this.pendingMajors = this.pendingMajors.concat([major]);
    }
  }

  @Builder
  private optionTag(label: string, selected: boolean) {
    Text(label).fontSize(17).fontWeight(FontWeight.Medium).fontColor(selected ? '#20C894' : '#777777')
      .backgroundColor(selected ? '#E7F8F2' : '#F5F5F5').borderRadius(20)
      .padding({ left: 18, right: 18, top: 9, bottom: 9 }).margin({ right: 10, bottom: 10 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
    Column() {
      Row() {
        Text('‹').fontSize(42).width(48).onClick(() => router.back());
        Text('二手书').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 });
        Blank().layoutWeight(1);
        Image($r('app.media.filter')).width(24).height(24).margin({ right: 18 }).onClick(() => {
          if (this.filterOpen) this.closeFilter(); else this.openFilter();
        });
        Image($r('app.media.search')).width(25).height(25).margin({ right: 18 }).onClick(() => { this.searching = !this.searching; });
        Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover);
      }.width('100%').height(76).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');

      if (this.filterOpen) {
        Column() {
          Text('选择专业').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555').width('100%').margin({ bottom: 10 });
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(['全部专业', '我的专业', '指定专业'], (item: string) => {
              Column() { this.optionTag(item, this.pendingMajorMode === item); }
                .onClick(() => { this.chooseMajorMode(item); });
            })
          }.width('100%');
          if (this.pendingMajorMode === '指定专业') {
            if (this.majors.length === 0) {
              Text('专业列表加载中…').fontSize(15).fontColor('#999999').width('100%').margin({ bottom: 8 })
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.majors, (major: string) => {
                  Column() { this.optionTag(major, this.pendingMajors.indexOf(major) >= 0); }
                    .onClick(() => {
                      this.togglePendingMajor(major);
                      this.pendingMajor = this.pendingMajors.join('、');
                    })
                }, (major: string) => major)
              }.width('100%').margin({ bottom: 8 })
            }
          }
          Text('选择校区').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555').width('100%').margin({ bottom: 10 });
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(['全部校区', '黄家湖', '青山', '洪山'], (item: string) => {
              Column() { this.optionTag(item, this.pendingCampus === item); }.onClick(() => { this.pendingCampus = item; });
            })
          }.width('100%');
          Text('排序方式').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555').width('100%').margin({ top: 6, bottom: 10 });
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(['默认排序', '最新发布', '价格升序', '价格降序'], (item: string) => {
              Column() { this.optionTag(item, this.pendingSort === item); }.onClick(() => { this.pendingSort = item; });
            })
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

      if (this.searching) {
        Row() {
          TextInput({ placeholder: '搜索书名、作者', text: this.query }).layoutWeight(1).fontSize(18)
            .onChange((value: string) => { this.query = value; }).onSubmit(() => this.load());
          Text('搜索').fontSize(17).fontColor('#857A25').margin({ left: 10 }).onClick(() => this.load());
        }.width('92%').height(52).padding({ left: 16, right: 12 }).backgroundColor(Color.White).borderRadius(26).margin({ bottom: 10 });
      }

      Refresh({ refreshing: this.refreshing }) {
        List({ scroller: this.listScroller }) {
          if (this.loading) {
            ListItem() { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); }
          } else if (this.visibleListings().length === 0) {
            ListItem() { Text('暂无符合条件的书籍').fontSize(18).fontColor('#999999').margin({ top: 80 }); }
          } else {
            ForEach(this.visibleListings(), (item: SecondhandListing) => {
              ListItem() { Row() {
                if (item.bookCover) { Image(item.bookCover).width(92).height(116).objectFit(ImageFit.Cover).borderRadius(10).margin({ right: 16 }); }
                Column() {
                  Text(item.bookTitle || '未命名书籍').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#857A25').maxLines(2);
                  if (item.bookAuthor) { Text(item.bookAuthor).fontSize(15).fontColor('#888888'); }
                  Text(SecondHandBookApi.conditionLabel(item.condition) || '成色未知').fontSize(16).fontColor('#555555').margin({ top: 8 });
                  if (item.note) { Text(item.note).fontSize(15).fontColor('#777777').maxLines(2); }
                  Text(this.money(item.price)).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#B26E2A').margin({ top: 8 });
                }.layoutWeight(1);
              }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ top: 10 })
                .onClick(() => this.openDetail(item)); }
            }, (item: SecondhandListing) => `${item.source || 'secondhand'}-${item.id || item.bookId || item.bookTitle}`)
          }
          if (!this.loading && this.listings.length > 0) { ListItem() { Row() { if (this.loadingMore) { LoadingProgress().width(22).height(22).color('#857A25'); Text('正在加载更多…').fontSize(15).fontColor('#888888').margin({ left: 8 }); } else if (!this.nativeHasMore && !this.communityHasMore) { Text('已经到底了').fontSize(15).fontColor('#AAAAAA'); } }.width('100%').height(54).justifyContent(FlexAlign.Center); } }
        }.width('100%').layoutWeight(1).backgroundColor('#F5F6F8').onReachEnd(() => this.loadMore());
      }.width('100%').layoutWeight(1).onRefreshing((): void => { this.refreshList(); });

      Row() {
        Text('发布二手书').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .textAlign(TextAlign.Center).width('88%').height(54).backgroundColor('#857A25').borderRadius(27);
      }.margin({ bottom: 16 }).onClick(() => router.pushUrl({ url: 'pages/campus/SecondHandBookPublishPage' }));
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
    }.width('100%').height('100%');
  }
}
