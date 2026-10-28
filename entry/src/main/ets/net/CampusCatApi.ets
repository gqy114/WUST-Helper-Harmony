import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface CampusCatPost { id?: number; title?: string; content?: string; tags?: string[]; images?: string[]; imageUrls?: string[]; pictures?: string[]; image?: string; authorName?: string; authorAvatar?: string; likeCount?: number; commentCount?: number; createdAt?: string; }
interface CatData { posts?: CampusCatPost[]; list?: CampusCatPost[]; }
interface CatResponse { code?: number; message?: string; data?: CampusCatPost[] | CatData; }
interface CatPublishRequest { title: string; content: string; tags: string[]; images: string[]; }
interface CatHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }

export class CampusCatApi {
  private static normalizePost(post: CampusCatPost): CampusCatPost {
    let images: string[] = [];
    const rawImages: string[] | string = post.images as string[] | string;
    if (Array.isArray(rawImages)) images = rawImages;
    else if (typeof rawImages === 'string') {
      try {
        const parsed = JSON.parse(rawImages) as string[];
        images = Array.isArray(parsed) ? parsed : [rawImages];
      } catch { images = rawImages.trim() ? [rawImages] : []; }
    }
    if (images.length === 0 && post.imageUrls) images = post.imageUrls;
    if (images.length === 0 && post.pictures) images = post.pictures;
    if (images.length === 0 && post.image) images = [post.image];
    const fullImages: string[] = images.map((url: string) => url.startsWith('http') ? url : `https://lyzyy.love${url.startsWith('/') ? '' : '/'}${url}`);
    return { id: post.id, title: post.title, content: post.content, tags: post.tags || [], images: fullImages,
      imageUrls: post.imageUrls, pictures: post.pictures, image: post.image,
      authorName: post.authorName, authorAvatar: post.authorAvatar,
      likeCount: post.likeCount, commentCount: post.commentCount, createdAt: post.createdAt };
  }
  static async list(page: number = 1, limit: number = 20): Promise<CampusCatPost[]> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const result = await HttpRequest.get<CatResponse>(`https://lyzyy.love/api/v1/campus-cat/posts?page=${page}&limit=${limit}`, headers);
    const items: CampusCatPost[] = Array.isArray(result.data.data) ? result.data.data : (result.data.data?.posts || result.data.data?.list || []);
    return items.map((post: CampusCatPost) => CampusCatApi.normalizePost(post));
  }
  static async detail(id: number): Promise<CampusCatPost> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const result = await HttpRequest.get<CatResponse>(`https://lyzyy.love/api/v1/campus-cat/posts/${id}`, headers);
    const post = result.data.data as CampusCatPost;
    if (!post || !post.id) throw new Error(result.data.message || 'post not found');
    return CampusCatApi.normalizePost(post);
  }
  static async publish(title: string, content: string, tags: string[], images: string[] = []): Promise<void> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const request: CatPublishRequest = { title, content, tags, images };
    const result = await HttpRequest.postRawJson<CatResponse>('https://lyzyy.love:8081/api/v1/campus-cat/posts', JSON.stringify(request), headers);
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200) throw new Error(result.data.message || 'publish failed');
  }
}

