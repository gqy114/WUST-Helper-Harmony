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
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> { this.loading = true; try { this.listings = await SecondHandBookApi.feed(this.query); } catch { promptAction.showToast({ message: '二手书信息加载失败', duration: 1500 }); } this.loading = false; }
  private money(value: number | undefined): string { return `¥${(value || 0).toFixed(2)}`; }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).width(48).onClick(() => router.back()); Text('二手书').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 }); Blank().layoutWeight(1); Image($r('app.media.search')).width(25).height(25).onClick(() => { this.searching = !this.searching; }); }.width('100%').height(76).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8');
      if (this.searching) { Row() { TextInput({ placeholder: '搜索书名、作者', text: this.query }).layoutWeight(1).fontSize(18).onChange((value: string) => { this.query = value; }).onSubmit(() => this.load()); Text('搜索').fontSize(17).fontColor('#857A25').margin({ left: 10 }).onClick(() => this.load()); }.width('92%').height(52).padding({ left: 16, right: 12 }).backgroundColor(Color.White).borderRadius(26); }
      Scroll() { Column() { if (this.loading) { Text('加载中…').fontSize(18).fontColor('#999999').margin({ top: 36 }); } else if (this.listings.length === 0) { Text('暂无二手书信息').fontSize(18).fontColor('#999999').margin({ top: 36 }); } else { ForEach(this.listings, (item: SecondhandListing) => { Row() { if (item.bookCover) { Image(item.bookCover).width(92).height(116).objectFit(ImageFit.Cover).borderRadius(10).margin({ right: 16 }); } Column() { Text(item.bookTitle || '未命名书籍').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#857A25').maxLines(2); if (item.bookAuthor) { Text(item.bookAuthor).fontSize(15).fontColor('#888888'); } Text(item.condition || '成色未知').fontSize(16).fontColor('#555555').margin({ top: 8 }); if (item.note) { Text(item.note).fontSize(15).fontColor('#777777').maxLines(2); } Text(this.money(item.price)).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#B26E2A').margin({ top: 8 }); }.layoutWeight(1); }.width('92%').padding(16).backgroundColor(Color.White).borderRadius(16).margin({ top: 10 }).onClick(() => { if (item.contact) { promptAction.showToast({ message: `联系方式：${item.contact}`, duration: 2200 }); } }); }, (item: SecondhandListing) => `${item.id || item.bookId || item.bookTitle}`); } }.width('100%').padding({ bottom: 24 }).backgroundColor('#F5F6F8'); }.layoutWeight(1);
      Row() { Text('发布二手书').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White).textAlign(TextAlign.Center).width('88%').height(54).backgroundColor('#857A25').borderRadius(27); }.margin({ bottom: 16 }).onClick(() => router.pushUrl({ url: 'pages/campus/SecondHandBookPublishPage' }));
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
