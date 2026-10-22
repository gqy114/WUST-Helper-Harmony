import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
export interface SecondhandListing { id?: number; bookId?: number; sellerId?: string; price?: number; condition?: string; note?: string; images?: string[]; contact?: string; status?: string; createdAt?: number; bookTitle?: string; bookAuthor?: string; bookCover?: string; }
export interface SecondhandBook { id?: number; isbn?: string; title?: string; author?: string; publisher?: string; edition?: string; category?: string; coverUrl?: string; listingCount?: number; priceMin?: number; priceMax?: number; priceAvg?: number; }
interface Response<T> { data?: T; code?: number; message?: string; }
interface Headers extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
export class SecondHandBookApi {
  private static async headers(): Promise<Headers> { const token = await AppStorage.getInstance().getAppAuthAccessToken(); return { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' }; }
  static async feed(keyword: string = '', category: string = ''): Promise<SecondhandListing[]> { const query = `?page=1&limit=50&keyword=${encodeURIComponent(keyword)}&category=${encodeURIComponent(category)}`; const response = await HttpRequest.get<Response<SecondhandListing[]>>(`https://lyzyy.love:8081/api/v1/secondhand/listings${query}`, await SecondHandBookApi.headers()); const data = response.data.data; return Array.isArray(data) ? data : []; }
  static async categories(): Promise<string[]> { const response = await HttpRequest.get<Response<string[]>>('https://lyzyy.love:8081/api/v1/secondhand/categories', await SecondHandBookApi.headers()); return Array.isArray(response.data.data) ? response.data.data : []; }
}
