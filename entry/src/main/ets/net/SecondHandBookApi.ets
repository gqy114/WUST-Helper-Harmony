import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
export interface SecondhandListing { id?: number; bookId?: number; sellerId?: string; price?: number; condition?: string; note?: string; images?: string[]; contact?: string; status?: string; createdAt?: number; bookTitle?: string; bookAuthor?: string; bookCover?: string; campus?: string; campusName?: string; major?: string; }
export interface SecondhandBook { id?: number; isbn?: string; title?: string; author?: string; publisher?: string; edition?: string; category?: string; coverUrl?: string; listingCount?: number; priceMin?: number; priceMax?: number; priceAvg?: number; }
interface Response<T> { data?: T; code?: number; message?: string; }
interface Headers extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
interface RecognizeRequest { isbn: string; title: string; author: string; publisher: string; edition: string; category: string; coverUrl: string; listPrice: number; ocrRaw: string; source: string; }
interface RecognizeData { book?: SecondhandBook; }
interface ListingRequest { bookId: number; price: number; condition: string; note: string; images: string[]; contact: string; ocrRaw: string; }
interface MajorItem { name?: string; label?: string; value?: string; title?: string; major?: string; majorName?: string; }
type MajorValue = string | MajorItem;
interface MajorPage { items?: MajorValue[]; list?: MajorValue[]; majors?: MajorValue[]; records?: MajorValue[]; data?: MajorValue[]; }
export class SecondHandBookApi {
  private static async headers(): Promise<Headers> { const token = await AppStorage.getInstance().getAppAuthAccessToken(); return { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' }; }
  static async feed(keyword: string = '', category: string = '', major: string = ''): Promise<SecondhandListing[]> { const query = `?page=1&limit=50&keyword=${encodeURIComponent(keyword)}&category=${encodeURIComponent(category)}${major.length > 0 ? `&major=${encodeURIComponent(major)}` : ''}`; const response = await HttpRequest.get<Response<SecondhandListing[]>>(`https://lyzyy.love:8081/api/v1/secondhand/listings${query}`, await SecondHandBookApi.headers()); const data = response.data.data; return Array.isArray(data) ? data : []; }
  static async categories(): Promise<string[]> { const response = await HttpRequest.get<Response<string[]>>('https://lyzyy.love:8081/api/v1/secondhand/categories', await SecondHandBookApi.headers()); return Array.isArray(response.data.data) ? response.data.data : []; }
  static async majors(): Promise<string[]> {
    // 专业数据来自校园社区二手书接口。旧的 /secondhand/majors 路由未部署，
    // 请求它只会得到 404，页面随后把异常吞掉并表现为专业列表为空。
    const response = await HttpRequest.get<Response<MajorValue[] | MajorPage>>('https://lyzyy.love:8081/api/v1/campus-wall/book-trade/majors', await SecondHandBookApi.headers());
    if (response.data.code !== undefined && response.data.code !== 0 && response.data.code !== 200) {
      throw new Error(response.data.message || 'major list load failed');
    }
    const data = response.data.data;
    let values: MajorValue[] = [];
    if (Array.isArray(data)) values = data;
    else if (data) values = data.items || data.list || data.majors || data.records || data.data || [];
    const names: string[] = [];
    values.forEach((value: MajorValue) => {
      const name = typeof value === 'string' ? value : (value.name || value.majorName || value.major || value.label || value.title || value.value || '');
      const normalized = name.trim();
      if (normalized.length > 0 && names.indexOf(normalized) < 0) names.push(normalized);
    });
    return names;
  }
  static async publishManual(title: string, price: number, edition: string, meetingPlace: string, contact: string, note: string, images: string[] = []): Promise<void> {
    const headers = await SecondHandBookApi.headers();
    const recognize: RecognizeRequest = { isbn: '', title, author: '', publisher: '', edition, category: '', coverUrl: '', listPrice: 0, ocrRaw: '', source: 'manual' };
    const recognized = await HttpRequest.postRawJson<Response<RecognizeData>>('https://lyzyy.love:8081/api/v1/secondhand/recognize', JSON.stringify(recognize), headers);
    const bookId = recognized.data.data?.book?.id || 0;
    if (bookId <= 0) throw new Error(recognized.data.message || 'book recognize failed');
    const fullNote = meetingPlace.trim().length > 0 ? `面交地点：${meetingPlace.trim()}\n${note.trim()}`.trim() : note.trim();
    const listing: ListingRequest = { bookId, price, condition: '', note: fullNote, images, contact, ocrRaw: '' };
    const result = await HttpRequest.postRawJson<Response<SecondhandListing>>('https://lyzyy.love:8081/api/v1/secondhand/listings', JSON.stringify(listing), headers);
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200) throw new Error(result.data.message || 'publish failed');
  }
}
