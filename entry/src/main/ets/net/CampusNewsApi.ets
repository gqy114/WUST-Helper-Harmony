/**
 * 校园资讯接口（后端 /News/Support）。
 *
 * 旧的 https://news.wustlinghang.cn 网页已弃用，改为后端新闻服务：
 * 列表 /articles、搜索 /search、详情 /articles/:id。
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

  private static messageOf(resp: NewsEnvelope<object> | undefined, fallback: string): string {
    const message = (resp?.message || resp?.msg || '').trim();
    return message || fallback;
  }

  static async articles(page: number = 1, pageSize: number = 20, collegeId: string = '',
    categoryUrl: string = ''): Promise<NewsListPage> {
    const params = [`page=${page}`, `page_size=${pageSize}`];
    if (collegeId) params.push(`college_id=${encodeURIComponent(collegeId)}`);
    if (categoryUrl) params.push(`category_url=${encodeURIComponent(categoryUrl)}`);
    const query = `?${params.join('&')}`;
    try {
      const result = await HttpRequest.request<NewsEnvelope<NewsListPage>>(`${PRIMARY}/articles${query}`, 'GET',
        { headers: CampusNewsApi.headers() });
      const resp = result.data;
      if (resp && CampusNewsApi.success(resp.code) && resp.data) {
        return resp.data;
      }
      throw new Error(CampusNewsApi.messageOf(resp, '校园资讯加载失败'));
    } catch (error) {
      // 主后端失败时由 HttpRequest 自动切换备用节点，这里只负责给出可读错误。
      const message = error instanceof Error && error.message ? error.message : '校园资讯加载失败';
      throw new Error(message === '[object Object]' ? '校园资讯加载失败' : message);
    }
  }

  static async detail(id: string): Promise<NewsDetail> {
    const result = await HttpRequest.request<NewsEnvelope<NewsDetail>>(
      `${PRIMARY}/articles/${encodeURIComponent(id)}`, 'GET', { headers: CampusNewsApi.headers() });
    const resp = result.data;
    if (resp && CampusNewsApi.success(resp.code) && resp.data) {
      return resp.data;
    }
    throw new Error(CampusNewsApi.messageOf(resp, '资讯详情加载失败'));
  }

  static async search(keyword: string, page: number = 1, pageSize: number = 20): Promise<NewsListPage> {
    const query = `?q=${encodeURIComponent(keyword)}&page=${page}&page_size=${pageSize}`;
    const result = await HttpRequest.request<NewsEnvelope<NewsListPage>>(`${PRIMARY}/search${query}`, 'GET',
      { headers: CampusNewsApi.headers() });
    const resp = result.data;
    if (resp && CampusNewsApi.success(resp.code) && resp.data) {
      return resp.data;
    }
    throw new Error(CampusNewsApi.messageOf(resp, '搜索失败'));
  }
}
