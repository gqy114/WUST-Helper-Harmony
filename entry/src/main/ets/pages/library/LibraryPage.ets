/**
 * LibraryPage — 图书馆借阅主页面
 *
 * 对应安卓 LibraryHistoryActivity（在借列表页面）
 * 逻辑：
 *   1. aboutToAppear 校验登录态 → 未登录跳转 LoginPage
 *   2. 调用 getLoanList() 获取在借列表
 *   3. 成功 → List<LibraryLoanItem>
 *   4. 失败 → LibraryEmpty 展示错误/重试
 *   5. 无数据 → LibraryEmpty 展示空状态
 *
 * 文件路径：entry/src/main/ets/pages/library/LibraryPage.ets
 */
import { RouterUtil } from '../../utils/RouterUtil';
import { AppStorage } from '../../store/AppStorage';
import { LibraryApi } from '../../net/LibraryApi';
import { LibraryStore } from '../../store/LibraryStore';
import { LibraryLoanItem as LoanItem } from '../../model/LibraryLoanModel';
import { LibraryLoanItem } from '../../components/library/LibraryLoanItem';
import { LibraryEmpty } from '../../components/library/LibraryEmpty';

const TAG = 'LibraryPage';

@Entry
@Component
struct LibraryPage {
  @State private loanList: LoanItem[] = [];
  @State private loading: boolean = true;
  @State private errorMsg: string = '';
  @State private sessionExpired: boolean = false;

  private store: LibraryStore = LibraryStore.getInstance();

  aboutToAppear(): void {
    this.verifyAndLoad();
  }

  private async verifyAndLoad(): Promise<void> {
    try {
      const s = AppStorage.getInstance();
      const token = await s.getToken();
      const isLogin = await s.getIsLogin();
      if (!token || !isLogin) {
        RouterUtil.toLogin();
        return;
      }
      await this.fetchLoans();
    } catch {
      console.error(TAG, 'verify error');
      this.loading = false;
      this.errorMsg = '登录状态校验失败';
    }
  }

  private async fetchLoans(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    this.sessionExpired = false;

    try {
      // 尝试使用主 Token 请求（图书馆接口可能复用主登录态）
      const s = AppStorage.getInstance();
      const token = await s.getToken();

      const resp = await LibraryApi.getLoanList(token ?? '');

      if (resp.code === 200 || resp.code === 0 || resp.code === 20000) {
        this.loanList = resp.data;
        this.store.loanList = resp.data;
        this.errorMsg = '';
      } else if (resp.code === 401 || resp.code === 403) {
        this.sessionExpired = true;
        this.errorMsg = resp.msg;
      } else {
        this.errorMsg = resp.msg || '借阅数据获取失败';
      }
    } catch {
      console.warn(TAG, 'fetchLoans error');
      this.errorMsg = '网络请求失败';
    } finally {
      this.loading = false;
    }
  }

  private retry(): void {
    this.fetchLoans();
  }

  build() {
    Column() {
      // 标题
      Text('当前借阅')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333')
        .margin({ top: 12, bottom: 4 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#1ec98d')
          Text('加载中...').fontSize(14).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.errorMsg || this.sessionExpired) {
        LibraryEmpty({
          isError: !this.sessionExpired,
          errorMsg: this.errorMsg,
          isSessionExpired: this.sessionExpired,
          onRetry: () => this.retry(),
        })
      } else if (this.loanList.length === 0) {
        LibraryEmpty({ isError: false, isSessionExpired: false })
      } else {
        Scroll() {
          Column() {
            ForEach(this.loanList, (loan: LoanItem) => {
              LibraryLoanItem({ loan: loan })
            })
          }
          .width('100%').padding({ bottom: 24 })
        }
        .width('100%').layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}
