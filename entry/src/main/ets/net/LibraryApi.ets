/**
 * LibraryApi — 图书馆网络接口
 *
 * 对应安卓 NewApiHelper → RequestCenter.getWithoutToken(LIBRARY_CURRENT_LOANS_V2)
 * 接口：WustApi.LIBRARY_CURRENT_LOANS_V2
 *
 * 文件路径：entry/src/main/ets/net/LibraryApi.ets
 */
import { HttpRequest } from './HttpRequest';
import { LibraryLoanItem } from '../model/LibraryLoanModel';

/** 当前借阅列表 —— 对应 WustApi.LIBRARY_CURRENT_LOANS_V2 */
const CURRENT_LOANS_URL = 'https://smarttool.wust.edu.cn:3001/api/wx/huiwen/patron/loans';

/** API 原始返回条目字段名一致 */
interface LoanApiRaw {
  title?: string;
  author?: string;
  loanDate?: string;
  dueDate?: string;
  locaCodeDesc?: string;
  callNo?: string;
  barCode?: string;
  bibNo?: string;
  isbn?: string;
  publisher?: string;
}

interface GeneratedTypeLiteralInterface_1 {
  items?: LoanApiRaw[];
}

interface LoanApiWrapper {
  code?: number;
  msg?: string;
  data?: LoanApiRaw[] | GeneratedTypeLiteralInterface_1;
}

function normalize(raw: LoanApiRaw): LibraryLoanItem {
  return {
    title: raw.title ?? '',
    author: raw.author ?? '',
    loanDate: raw.loanDate ?? '',
    dueDate: raw.dueDate ?? '',
    returnPlace: raw.locaCodeDesc ?? '',
    callNumber: raw.callNo ?? '',
    barCode: raw.barCode ?? '',
    bibNo: raw.bibNo ?? '',
    isbn: raw.isbn ?? '',
    publisher: raw.publisher ?? '',
  };
}

interface GeneratedTypeLiteralInterface_2 {
  code: number;
  msg: string;
  data: LibraryLoanItem[];
}

export class LibraryApi {
  /**
   * 获取当前在借图书列表
   * @param token 图书馆 Bearer Token（来自 SharePreferenceLab.getLibraryToken）
   */
  static async getLoanList(token: string): Promise<GeneratedTypeLiteralInterface_2> {
    try {
      const result = await HttpRequest.request<LoanApiWrapper>(
        CURRENT_LOANS_URL, 'GET',
        {
          headers: {
            Authorization: token ? `Bearer ${token}` : '',
            Platform: 'android',
          },
        },
      );
      const resp = result.data;

      if (resp && (resp.code === 200 || resp.code === 0 || resp.code === 10000 || resp.code === 20000)) {
        let rawList: LoanApiRaw[] = [];
        if (resp.data instanceof Array) {
          rawList = resp.data;
        } else if (resp.data?.items instanceof Array) {
          rawList = resp.data.items;
        }
        const list: LibraryLoanItem[] = rawList.map((r: LoanApiRaw) => normalize(r));
        return { code: resp.code ?? 0, msg: resp.msg ?? 'ok', data: list };
      }

      if (resp?.code === 401 || resp?.code === 403) {
        return { code: resp.code, msg: '图书馆登录已过期，请重新登录', data: [] };
      }

      return { code: resp?.code ?? -1, msg: resp?.msg ?? '请求失败', data: [] };
    } catch {
      console.warn('LibraryApi', 'getLoanList error');
      return { code: -1, msg: '网络请求失败', data: [] };
    }
  }
}


