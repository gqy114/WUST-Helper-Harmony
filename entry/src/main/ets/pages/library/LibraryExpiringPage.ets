import { router } from '@kit.ArkUI';
import { AppStorage } from '../../store/AppStorage';
import { LibraryApi } from '../../net/LibraryApi';
import { LibraryLoanItem as Loan, daysUntilDue } from '../../model/LibraryLoanModel';
import { LibraryLoanItem } from '../../components/library/LibraryLoanItem';
import { LibraryEmpty } from '../../components/library/LibraryEmpty';

@Entry
@Component
struct LibraryExpiringPage {
  @State private loans: Loan[] = [];
  @State private loading: boolean = true;
  @State private error: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    const studentId = await AppStorage.getInstance().getStudentId();
    const result = await LibraryApi.getLoanList(studentId);
    if (result.code === 200 || result.code === 0 || result.code === 10000 || result.code === 20000) {
      this.loans = result.data.filter((loan: Loan) => daysUntilDue(loan.dueDate) >= 0 && daysUntilDue(loan.dueDate) <= 7);
    } else {
      this.error = result.msg;
    }
    this.loading = false;
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(48).fontColor(Color.White).width(52).onClick(() => router.back())
        Text('即将超期').fontSize(27).fontWeight(FontWeight.Bold).fontColor(Color.White).layoutWeight(1)
        Text('↻').fontSize(35).fontColor(Color.White).onClick(() => this.load())
      }.width('100%').height(92).padding({ left: 22, right: 28, top: 22 }).backgroundColor('#20C894')
      if (this.loading) {
        Column() { LoadingProgress().width(42).height(42).color('#20C894') }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error) {
        LibraryEmpty({ isError: true, errorMsg: this.error, isSessionExpired: false, onRetry: () => this.load() })
      } else if (this.loans.length === 0) {
        Column() {
          Image($r('app.media.about_to_expire')).width(120).height(120).objectFit(ImageFit.Contain)
          Text('未来 7 天内没有到期图书').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555').margin({ top: 18 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 14 }) {
          ForEach(this.loans, (loan: Loan) => { ListItem() { LibraryLoanItem({ loan: loan }) } })
        }.width('100%').layoutWeight(1).padding({ left: 18, right: 18, top: 18, bottom: 24 })
      }
    }.width('100%').height('100%').backgroundColor('#F6F6F6')
  }
}
