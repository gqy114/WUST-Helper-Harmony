/**
 * 校园资讯接口（后端 /News/Support）。
 *
 * 主节点不可用（例如部署未包含新闻服务、返回 404）时自动切换备用节点，
 * 避免用户只看到“加载失败”。
 */
import { HttpRequest } from './HttpRequest';

const PRIMARY = 'https://lyzyy.love:8081/News/Support';
const BACKUP = 'http://port.happylandmc.cc:52144/News/Support';

export interface NewsArticle {
  id?: string;
  college_id?: string;
  category_name?: string;
  title?: string;
  url?: string;
  published_at?: string;
  summary?: string;
  images?: string[];
  cover_url?: string;
}

export interface NewsListPage {
  items?: NewsArticle[];
  page?: number;
  page_size?: number;
  total?: number;
}

export interface NewsDetail {
  id?: string;
  title?: string;
  url?: string;
  published_at?: string;
  category_name?: string;
  content_html?: string;
  content_text?: string;
  images?: string[];
}

interface NewsEnvelope<T> {
  code?: number;
  message?: string;
  msg?: string;
  data?: T;
}

interface NewsMessageEnvelope {
  code?: number;
  message?: string;
  msg?: string;
}

export class CampusNewsApi {
  private static headers(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Accept'] = 'application/json';
    headers['Platform'] = 'android';
    return headers;
  }

  private static success(code: number | undefined): boolean {
    return code === 0 || code === 200 || code === 10000;
  }

  private static messageOf(resp: NewsMessageEnvelope | undefined, fallback: string): string {
    const message = (resp?.message || resp?.msg || '').trim();
    return message || fallback;
  }

  /** 依次尝试主节点、备用节点；都失败才抛错。 */
  private static async get<T>(path: string): Promise<T> {
    const urls: string[] = [`${PRIMARY}${path}`, `${BACKUP}${path}`];
    let lastMessage = '校园资讯加载失败';
    for (let i = 0; i < urls.length; i++) {
      try {
        const result = await HttpRequest.request<NewsEnvelope<T>>(urls[i], 'GET', {
          headers: CampusNewsApi.headers(),
          pinBackend: true
        });
        const resp = result.data;
        if (resp && CampusNewsApi.success(resp.code) && resp.data) {
          return resp.data;
        }
        lastMessage = CampusNewsApi.messageOf(resp, lastMessage);
      } catch (error) {
        const message = error instanceof Error ? error.message : '';
        if (message && message !== '[object Object]') lastMessage = message;
      }
    }
    throw new Error(lastMessage);
  }

  static async articles(page: number = 1, pageSize: number = 20, collegeId: string = '',
    categoryUrl: string = ''): Promise<NewsListPage> {
    const params: string[] = [`page=${page}`, `page_size=${pageSize}`];
    if (collegeId) params.push(`college_id=${encodeURIComponent(collegeId)}`);
    if (categoryUrl) params.push(`category_url=${encodeURIComponent(categoryUrl)}`);
    return CampusNewsApi.get<NewsListPage>(`/articles?${params.join('&')}`);
  }

  static async detail(id: string): Promise<NewsDetail> {
    return CampusNewsApi.get<NewsDetail>(`/articles/${encodeURIComponent(id)}`);
  }

  static async search(keyword: string, page: number = 1, pageSize: number = 20): Promise<NewsListPage> {
    const query = `?q=${encodeURIComponent(keyword)}&page=${page}&page_size=${pageSize}`;
    return CampusNewsApi.get<NewsListPage>(`/search${query}`);
  }
}
