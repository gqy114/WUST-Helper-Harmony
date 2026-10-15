import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface CampusCatPost { id?: number; title?: string; content?: string; images?: string[]; authorName?: string; authorAvatar?: string; likeCount?: number; commentCount?: number; createdAt?: string; }
interface CatData { posts?: CampusCatPost[]; list?: CampusCatPost[]; }
interface CatResponse { data?: CampusCatPost[] | CatData; }
interface CatHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }

export class CampusCatApi {
  static async list(page: number = 1, limit: number = 20): Promise<CampusCatPost[]> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const result = await HttpRequest.get<CatResponse>(`https://lyzyy.love:8081/api/v1/campus-cat/posts?page=${page}&limit=${limit}`, headers);
    if (Array.isArray(result.data.data)) return result.data.data;
    return result.data.data?.posts || result.data.data?.list || [];
  }
}
