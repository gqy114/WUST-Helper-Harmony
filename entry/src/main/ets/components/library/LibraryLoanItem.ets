/**
 * LibraryLoanItem — 借阅记录单行条目
 *
 * 展示：书名 / 作者 / 借阅日期 / 应还日期
 * 已超期图书应还日期标红
 *
 * 文件路径：entry/src/main/ets/components/library/LibraryLoanItem.ets
 */
import { LibraryLoanItem as LoanItem, isOverdue } from '../../model/LibraryLoanModel';

@Component
export struct LibraryLoanItem {
  private loan: LoanItem = {
    title: '', author: '', loanDate: '', dueDate: '',
    returnPlace: '', callNumber: '', barCode: '',
    bibNo: '', isbn: '', publisher: '',
  };

  build() {
    Column() {
      // 书名
      Text(this.loan.title)
        .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#333333')
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      // 作者
      Text(this.loan.author)
        .fontSize(12).fontColor('#999999').margin({ top: 4 })
        .width('100%')

      // 日期行
      Row() {
        Text(`借出: ${this.loan.loanDate}`)
          .fontSize(11).fontColor('#999999')

        Blank()

        Text(`应还: ${this.loan.dueDate}`)
          .fontSize(11)
          .fontColor(isOverdue(this.loan.dueDate) ? '#f44336' : '#999999')
          .fontWeight(isOverdue(this.loan.dueDate) ? FontWeight.Bold : FontWeight.Normal)
      }
      .width('100%').margin({ top: 6 })

      // 底部分割线
      Divider().height(0.5).color('#EEEEEE').width('100%').margin({ top: 8 })
    }
    .width('100%').padding({ top: 12, left: 16, right: 16 })
    .backgroundColor(Color.White)
  }
}