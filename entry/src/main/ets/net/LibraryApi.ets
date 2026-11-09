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
import { AppStorage } from '../store/AppStorage';

/** 服务端收藏（/api/v1/library/favorites），跟随账号跨设备同步。 */
const LIBRARY_FAVORITES_URL = 'https://lyzyy.love:8081/api/v1/library/favorites';

/** 收藏条目：kind 为 article（活动资讯）或 resource（资源导航）。 */
export interface LibraryFavoriteEntry {
  id?: number;
  kind: string;
  itemId: number;
  title: string;
  link: string;
  tag: string;
  createdAt?: number;
}

interface FavoriteItemPayload {
  item?: LibraryFavoriteEntry;
}

interface FavoriteListPayload {
  items?: LibraryFavoriteEntry[];
}

interface FavoriteEnvelope {
  code?: number;
  message?: string;
  msg?: string;
  data?: FavoriteListPayload | FavoriteItemPayload | boolean | null;
}

/** POST /api/v1/library/favorites 的请求体。 */
interface FavoriteAddBody {
  kind: string;
  itemId: number;
  title: string;
  link: string;
  tag: string;
}

/** POST /api/v1/library/favorites/remove 的请求体。 */
interface FavoriteRemoveBody {
  kind: string;
  itemId: number;
}

interface FavoriteHeaders extends Record<string, string> {
  Authorization: string;
  Platform: string;
  Accept: string;
}

/** 当前借阅列表 —— 对应 WustApi.LIBRARY_CURRENT_LOANS_V2 */
const CURRENT_LOANS_URL = 'https://smarttool.wust.edu.cn:3001/api/wx/huiwen/patron/loans';
const READER_INFO_URL = 'https://smarttool.wust.edu.cn:3001/api/wx/huiwen/patron/info';

export interface LibraryReaderInfo {
  name?: string;
  patronName?: string;
  cardNo?: string;
  readerCode?: string;
  type?: string;
  readerType?: string;
  status?: string;
  loanCount?: number;
  currentLoanCount?: number;
  loanLimit?: number;
  maxLoanCount?: number;
  expiryDate?: string;
  expireDate?: string;
}

interface ReaderApiWrapper {
  code?: number;
  msg?: string;
  data?: LibraryReaderInfo;
}

export interface LibraryReaderResult {
  code: number;
  msg: string;
  data: LibraryReaderInfo;
}

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

  static async getReaderInfo(token: string): Promise<LibraryReaderResult> {
    try {
      const result = await HttpRequest.request<ReaderApiWrapper>(READER_INFO_URL, 'GET', {
        headers: { Authorization: token ? `Bearer ${token}` : '', Platform: 'android' },
      });
      const resp = result.data;
      if (resp && (resp.code === 200 || resp.code === 0 || resp.code === 10000 || resp.code === 20000)) {
        return { code: resp.code ?? 0, msg: resp.msg ?? 'ok', data: resp.data ?? {} };
      }
      return { code: resp?.code ?? -1, msg: resp?.msg ?? '读者信息获取失败', data: {} };
    } catch {
      console.warn('LibraryApi', 'getReaderInfo error');
      return { code: -1, msg: '网络请求失败', data: {} };
    }
  }

  /** 最新通知：对应安卓 LIBRARY_NOTICE_V2，无需登录。 */
  static async latestNotice(): Promise<LibraryNotice | null> {
    try {
      const result = await HttpRequest.request<NoticeWrapper>(NOTICE_URL, 'GET', { headers: { Platform: 'android' } });
      const resp = result.data;
      if (resp && (resp.code === 200 || resp.code === 0) && resp.data && (resp.data.id || 0) > 0) {
        return resp.data;
      }
      return null;
    } catch {
      console.warn('LibraryApi', 'latestNotice error');
      return null;
    }
  }

  /** 首页推荐图片：对应安卓 LIBRARY_HOME_ARTICLES_V2。 */
  static async homeArticles(): Promise<LibraryHomeArticle[]> {
    try {
      const result = await HttpRequest.request<HomeArticleWrapper>(HOME_ARTICLE_URL, 'GET', { headers: { Platform: 'android' } });
      const resp = result.data;
      if (resp && (resp.code === 200 || resp.code === 0) && Array.isArray(resp.data)) {
        return visibleHomeArticles(resp.data);
      }
      return [];
    } catch {
      console.warn('LibraryApi', 'homeArticles error');
      return [];
    }
  }

  /** 活动/通知/讲座列表：对应安卓 LIBRARY_ACTIVITY_ARTICLES_V2。 */
  static async articles(): Promise<LibraryArticle[]> {
    try {
      const result = await HttpRequest.request<ArticleListWrapper>(ARTICLE_LIST_URL, 'GET', { headers: { Platform: 'android' } });
      const resp = result.data;
      if (resp && (resp.code === 200 || resp.code === 0) && resp.data && Array.isArray(resp.data.rows)) {
        return visibleArticles(resp.data.rows);
      }
      return [];
    } catch {
      console.warn('LibraryApi', 'articles error');
      return [];
    }
  }

  /** 资源导航：对应安卓 LIBRARY_RESOURCES_V2，resourceType 1..4，0 为全部。 */
  static async resources(resourceType: number): Promise<LibraryResource[]> {
    try {
      const url = `${RESOURCE_LIST_URL}?resourceType=${resourceType}`;
      const result = await HttpRequest.request<ResourceWrapper>(url, 'GET', { headers: { Platform: 'android' } });
      const resp = result.data;
      if (resp && (resp.code === 200 || resp.code === 0) && resp.data && Array.isArray(resp.data.rows)) {
        return resp.data.rows;
      }
      return [];
    } catch {
      console.warn('LibraryApi', 'resources error');
      return [];
    }
  }

  /** 服务端收藏列表：未登录或接口不可用时返回 null，调用方继续用本机缓存。 */
  static async listFavorites(): Promise<LibraryFavoriteEntry[] | null> {
    const headers = await LibraryApi.favoriteHeaders();
    if (!headers) return null;
    try {
      const result = await HttpRequest.get<FavoriteEnvelope>(LIBRARY_FAVORITES_URL, headers, true);
      const resp = result.data;
      if (!isOkFavoriteCode(resp?.code)) return null;
      const payload = resp?.data as FavoriteListPayload | undefined;
      const items = payload?.items;
      return Array.isArray(items) ? items : [];
    } catch {
      console.warn('LibraryApi', 'listFavorites error');
      return null;
    }
  }

  /** 新增/更新一条服务端收藏；未登录或失败返回 false。 */
  static async addFavorite(item: LibraryFavoriteEntry): Promise<boolean> {
    const headers = await LibraryApi.favoriteHeaders();
    if (!headers) return false;
    try {
      const body: FavoriteAddBody = {
        kind: item.kind,
        itemId: item.itemId,
        title: item.title,
        link: item.link,
        tag: item.tag,
      };
      const result = await HttpRequest.postRawJson<FavoriteEnvelope>(
        LIBRARY_FAVORITES_URL, JSON.stringify(body), headers, true);
      return isOkFavoriteCode(result.data?.code);
    } catch {
      console.warn('LibraryApi', 'addFavorite error');
      return false;
    }
  }

  /** 取消一条服务端收藏；未登录或失败返回 false。 */
  static async removeFavorite(kind: string, itemId: number): Promise<boolean> {
    const headers = await LibraryApi.favoriteHeaders();
    if (!headers) return false;
    try {
      const body: FavoriteRemoveBody = { kind, itemId };
      const result = await HttpRequest.postRawJson<FavoriteEnvelope>(`${LIBRARY_FAVORITES_URL}/remove`,
        JSON.stringify(body), headers, true);
      return isOkFavoriteCode(result.data?.code);
    } catch {
      console.warn('LibraryApi', 'removeFavorite error');
      return false;
    }
  }

  private static async favoriteHeaders(): Promise<FavoriteHeaders | null> {
    const token = (await AppStorage.getInstance().getAppAuthAccessToken()).trim();
    if (!token) return null;
    return { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
  }
}

function isOkFavoriteCode(code?: number): boolean {
  return code === 200 || code === 0 || code === 10000 || code === 20000;
}

const NOTICE_URL = 'https://smarttool.wust.edu.cn:3001/api/wx/notice/new';
const HOME_ARTICLE_URL = 'https://smarttool.wust.edu.cn:3001/api/wx/home/getHomeArticle';
const ARTICLE_LIST_URL = 'https://smarttool.wust.edu.cn:3001/api/wx/article/getArticleList';
const RESOURCE_LIST_URL = 'https://smarttool.wust.edu.cn:3001/api/wx/resource/getResourcesList';

export interface LibraryNotice {
  id?: number;
  title?: string;
  publisher?: string;
  content?: string;
  createdAt?: string;
}

export interface LibraryHomeArticle {
  id?: number;
  pictureLink?: string;
  articleLink?: string;
  show?: number;
  totalView?: number;
}

export interface LibraryArticle {
  id?: number;
  title?: string;
  link?: string;
  tag?: string;
  type?: number;
  sortNum?: number;
  show?: number;
  totalView?: number;
}

export interface LibraryResource {
  id?: number;
  title?: string;
  type?: number;
  content?: string;
  inLink?: string;
  outLink?: string;
  serviceStatus?: number;
}

interface NoticeWrapper { code?: number; msg?: string; data?: LibraryNotice; }
interface HomeArticleWrapper { code?: number; msg?: string; data?: LibraryHomeArticle[]; }
interface ArticleListWrapper { code?: number; msg?: string; data?: LibraryArticlePage; }
interface LibraryArticlePage { count?: number; rows?: LibraryArticle[]; }
interface ResourceWrapper { code?: number; msg?: string; data?: LibraryResourcePage; }
interface LibraryResourcePage { count?: number; rows?: LibraryResource[]; }

/** 首页推荐只展示 show=1 的条目（后端还有 show=0 的隐藏项）。 */
export function visibleHomeArticles(items: LibraryHomeArticle[]): LibraryHomeArticle[] {
  return items.filter((item: LibraryHomeArticle) => item.show === 1 && !!(item.pictureLink || item.articleLink));
}

/** 活动资讯只展示 show=1 的条目，顺序沿用后端 sortNum/返回顺序。 */
export function visibleArticles(rows: LibraryArticle[]): LibraryArticle[] {
  return rows.filter((row: LibraryArticle) => row.show === 1 && !!(row.title || row.link));
}

export function articleTagLabel(tag?: string): string {
  const value = (tag || '').trim();
  if (value === '活动' || value === '通知' || value === '讲座') return value;
  return value || '通知';
}

/** 资源导航按 type 分组时的标题。 */
export function resourceTypeLabel(type: number): string {
  if (type === 1) return '中文资源';
  if (type === 2) return '外文资源';
  if (type === 3) return '开放资源';
  if (type === 4) return '智能服务';
  return '其他资源';
}


