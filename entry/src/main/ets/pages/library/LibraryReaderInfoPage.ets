import { router } from '@kit.ArkUI';
import { AppStorage } from '../../store/AppStorage';
import { LibraryApi, LibraryReaderInfo } from '../../net/LibraryApi';

@Entry
@Component
struct LibraryReaderInfoPage {
  @State private info: LibraryReaderInfo = {};
  @State private studentId: string = '';
  @State private loading: boolean = true;
  @State private error: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.studentId = await AppStorage.getInstance().getStudentId();
    const result = await LibraryApi.getReaderInfo(this.studentId);
    if (result.code === 200 || result.code === 0 || result.code === 10000 || result.code === 20000) {
      this.info = result.data;
    } else {
      this.error = result.msg;
    }
    this.loading = false;
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(17).fontColor('#888888').width(112)
      Text(value || '--').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#333333').layoutWeight(1)
    }.width('100%').padding({ top: 17, bottom: 17 }).border({ width: { bottom: 1 }, color: '#EEEEEE' })
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(48).fontColor(Color.White).width(52).onClick(() => router.back())
        Text('读者信息').fontSize(27).fontWeight(FontWeight.Bold).fontColor(Color.White).layoutWeight(1)
        Text('↻').fontSize(35).fontColor(Color.White).onClick(() => this.load())
      }.width('100%').height(92).padding({ left: 22, right: 28, top: 22 }).backgroundColor('#20C894')

      if (this.loading) {
        Column() { LoadingProgress().width(42).height(42).color('#20C894') }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error) {
        Column() {
          Image($r('app.media.reader_information')).width(120).height(120).objectFit(ImageFit.Contain)
          Text(this.error).fontSize(18).fontColor('#E84C4C').margin({ top: 18 })
          Button('重新加载').fontSize(17).backgroundColor('#20C894').margin({ top: 22 }).onClick(() => this.load())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Image($r('app.media.reader_information')).width(112).height(112).objectFit(ImageFit.Contain).margin({ top: 26, bottom: 18 })
            Column() {
              this.infoRow('姓名', this.info.name || this.info.patronName || '--')
              this.infoRow('读者证号', this.info.cardNo || this.info.readerCode || this.studentId)
              this.infoRow('读者类型', this.info.type || this.info.readerType || '--')
              this.infoRow('账户状态', this.info.status || '正常')
              this.infoRow('当前借阅', `${this.info.loanCount || this.info.currentLoanCount || 0} 本`)
              this.infoRow('借阅额度', `${this.info.loanLimit || this.info.maxLoanCount || 0} 本`)
              this.infoRow('有效期至', this.info.expiryDate || this.info.expireDate || '--')
            }
            .width('100%').padding({ left: 22, right: 22 }).backgroundColor(Color.White).borderRadius(12)
          }.width('100%').padding({ left: 20, right: 20, bottom: 28 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#F6F6F6')
  }
}
