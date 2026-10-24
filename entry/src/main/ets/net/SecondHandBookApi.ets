import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
export interface SecondhandListing { id?: number; bookId?: number; sellerId?: string; price?: number; condition?: string; note?: string; images?: string[]; contact?: string; status?: string; createdAt?: number; bookTitle?: string; bookAuthor?: string; bookCover?: string; }
export interface SecondhandBook { id?: number; isbn?: string; title?: string; author?: string; publisher?: string; edition?: string; category?: string; coverUrl?: string; listingCount?: number; priceMin?: number; priceMax?: number; priceAvg?: number; }
interface Response<T> { data?: T; code?: number; message?: string; }
interface Headers extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
interface RecognizeRequest { isbn: string; title: string; author: string; publisher: string; edition: string; category: string; coverUrl: string; listPrice: number; ocrRaw: string; source: string; }
interface RecognizeData { book?: SecondhandBook; }
interface ListingRequest { bookId: number; price: number; condition: string; note: string; images: string[]; contact: string; ocrRaw: string; }
export class SecondHandBookApi {
  private static async headers(): Promise<Headers> { const token = await AppStorage.getInstance().getAppAuthAccessToken(); return { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' }; }
  static async feed(keyword: string = '', category: string = ''): Promise<SecondhandListing[]> { const query = `?page=1&limit=50&keyword=${encodeURIComponent(keyword)}&category=${encodeURIComponent(category)}`; const response = await HttpRequest.get<Response<SecondhandListing[]>>(`https://lyzyy.love:8081/api/v1/secondhand/listings${query}`, await SecondHandBookApi.headers()); const data = response.data.data; return Array.isArray(data) ? data : []; }
  static async categories(): Promise<string[]> { const response = await HttpRequest.get<Response<string[]>>('https://lyzyy.love:8081/api/v1/secondhand/categories', await SecondHandBookApi.headers()); return Array.isArray(response.data.data) ? response.data.data : []; }
  static async publishManual(title: string, price: number, edition: string, meetingPlace: string, contact: string, note: string): Promise<void> {
    const headers = await SecondHandBookApi.headers();
    const recognize: RecognizeRequest = { isbn: '', title, author: '', publisher: '', edition, category: '', coverUrl: '', listPrice: 0, ocrRaw: '', source: 'manual' };
    const recognized = await HttpRequest.postRawJson<Response<RecognizeData>>('https://lyzyy.love:8081/api/v1/secondhand/recognize', JSON.stringify(recognize), headers);
    const bookId = recognized.data.data?.book?.id || 0;
    if (bookId <= 0) throw new Error(recognized.data.message || 'book recognize failed');
    const fullNote = meetingPlace.trim().length > 0 ? `面交地点：${meetingPlace.trim()}\n${note.trim()}`.trim() : note.trim();
    const listing: ListingRequest = { bookId, price, condition: '', note: fullNote, images: [], contact, ocrRaw: '' };
    const result = await HttpRequest.postRawJson<Response<SecondhandListing>>('https://lyzyy.love:8081/api/v1/secondhand/listings', JSON.stringify(listing), headers);
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200) throw new Error(result.data.message || 'publish failed');
  }
}
