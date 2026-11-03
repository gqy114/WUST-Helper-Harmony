import { router } from '@kit.ArkUI';
import { AppStorage } from '../../store/AppStorage';
import { LibraryApi } from '../../net/LibraryApi';
import { LibraryLoanItem as Loan } from '../../model/LibraryLoanModel';
import { LibraryLoanItem } from '../../components/library/LibraryLoanItem';
import { LibraryEmpty } from '../../components/library/LibraryEmpty';

@Entry
@Component
struct LibraryBorrowingPage {
  @State private loans: Loan[] = [];
  @State private loading: boolean = true;
  @State private error: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    const studentId = await AppStorage.getInstance().getStudentId();
    if (!studentId) {
      this.error = '未找到学号，请先登录';
      this.loading = false;
      return;
    }
    const result = await LibraryApi.getLoanList(studentId);
    if (result.code === 200 || result.code === 0 || result.code === 10000 || result.code === 20000) {
      this.loans = result.data;
    } else {
      this.error = result.msg;
    }
    this.loading = false;
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(48).fontColor(Color.White).width(52).onClick(() => router.back())
        Text('图书借阅').fontSize(27).fontWeight(FontWeight.Bold).fontColor(Color.White).layoutWeight(1)
        Text('↻').fontSize(35).fontColor(Color.White).onClick(() => this.load())
      }
      .width('100%').height(92).padding({ left: 22, right: 28, top: 22 }).backgroundColor('#20C894')

      if (this.loading) {
        Column() { LoadingProgress().width(42).height(42).color('#20C894'); Text('正在加载借阅信息').fontColor('#888888').margin({ top: 14 }) }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error) {
        LibraryEmpty({ isError: true, errorMsg: this.error, isSessionExpired: false, onRetry: () => this.load() })
      } else if (this.loans.length === 0) {
        LibraryEmpty({ isError: false, isSessionExpired: false })
      } else {
        List({ space: 14 }) {
          ForEach(this.loans, (loan: Loan) => { ListItem() { LibraryLoanItem({ loan: loan }) } })
        }
        .width('100%').layoutWeight(1).padding({ left: 18, right: 18, top: 18, bottom: 24 })
      }
    }
    .width('100%').height('100%').backgroundColor('#F6F6F6')
  }
}
