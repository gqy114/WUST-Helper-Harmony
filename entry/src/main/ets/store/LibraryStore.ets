/**
 * LibraryStore — 图书馆借阅全局状态
 *
 * 文件路径：entry/src/main/ets/store/LibraryStore.ets
 */
import { LibraryLoanItem } from '../model/LibraryLoanModel';

@Observed
export class LibraryStore {
  private static instance: LibraryStore;

  loanList: LibraryLoanItem[] = [];
  loading: boolean = false;
  errorMsg: string = '';

  static getInstance(): LibraryStore {
    if (!LibraryStore.instance) {
      LibraryStore.instance = new LibraryStore();
    }
    return LibraryStore.instance;
  }

  /** 重置全状态 */
  reset(): void {
    this.loanList = [];
    this.loading = false;
    this.errorMsg = '';
  }
}