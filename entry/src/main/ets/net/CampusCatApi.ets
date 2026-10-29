import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

export interface CampusCatPost { id?: number; title?: string; content?: string; tags?: string[]; images?: string[]; imageUrls?: string[]; pictures?: string[]; image?: string; authorName?: string; authorAvatar?: string; likeCount?: number; commentCount?: number; createdAt?: string; }
export interface CampusCatReply { id?: number; postId?: number; authorName?: string; authorAvatar?: string; content?: string; createdAt?: string; }
interface CatData { posts?: CampusCatPost[]; list?: CampusCatPost[]; }
interface CatResponse { code?: number; message?: string; data?: CampusCatPost[] | CatData; }
interface CatReplyResponse { code?: number; message?: string; data?: CampusCatReply[] | CampusCatReply; }
interface CatPublishRequest { title: string; content: string; tags: string[]; images: string[]; }
interface CatReplyRequest extends Record<string, string> { content: string; }
interface CatHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }

export class CampusCatApi {
  private static fullAssetUrl(url: string): string {
    if (!url || url.startsWith('http') || url.startsWith('file:') || url.startsWith('data:')) return url;
    return `https://lyzyy.love${url.startsWith('/') ? '' : '/'}${url}`;
  }
  private static normalizeReply(reply: CampusCatReply): CampusCatReply {
    const normalized: CampusCatReply = { id: reply.id, postId: reply.postId,
      authorName: reply.authorName, authorAvatar: CampusCatApi.fullAssetUrl(reply.authorAvatar || ''),
      content: reply.content, createdAt: reply.createdAt };
    return normalized;
  }
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
    const fullImages: string[] = images.map((url: string) => CampusCatApi.fullAssetUrl(url));
    return { id: post.id, title: post.title, content: post.content, tags: post.tags || [], images: fullImages,
      imageUrls: post.imageUrls, pictures: post.pictures, image: post.image,
      authorName: post.authorName, authorAvatar: CampusCatApi.fullAssetUrl(post.authorAvatar || ''),
      likeCount: post.likeCount, commentCount: post.commentCount, createdAt: post.createdAt };
  }
  static async list(page: number = 1, limit: number = 20): Promise<CampusCatPost[]> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const result = await HttpRequest.get<CatResponse>(`https://lyzyy.love/api/v1/campus-cat/posts?page=${page}&limit=${limit}`, headers);
    const items: CampusCatPost[] = Array.isArray(result.data.data) ? result.data.data : (result.data.data?.posts || result.data.data?.list || []);
    return items.map((post: CampusCatPost) => CampusCatApi.normalizePost(post));
  }
  static async mine(): Promise<CampusCatPost[]> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const result = await HttpRequest.get<CatResponse>('https://lyzyy.love:8081/api/v1/campus-cat/mine?limit=200&offset=0', headers);
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
  static async comments(id: number): Promise<CampusCatReply[]> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const result = await HttpRequest.get<CatReplyResponse>(`https://lyzyy.love/api/v1/campus-cat/posts/${id}/comments`, headers);
    const replies = Array.isArray(result.data.data) ? result.data.data : [];
    return replies.map((reply: CampusCatReply) => CampusCatApi.normalizeReply(reply));
  }
  static async reply(id: number, content: string): Promise<void> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const request: CatReplyRequest = { content };
    const result = await HttpRequest.postJson<CatReplyResponse>(
      `https://lyzyy.love/api/v1/campus-cat/posts/${id}/comments`, request, headers);
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200) {
      throw new Error(result.data.message || 'reply failed');
    }
  }
  static async deletePost(id: number): Promise<void> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const result = await HttpRequest.postJson<CatReplyResponse>(
      `https://lyzyy.love:8081/api/v1/campus-cat/posts/${id}/delete`, {}, headers);
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200) {
      throw new Error(result.data.message || 'delete post failed');
    }
  }
  static async publish(title: string, content: string, tags: string[], images: string[] = []): Promise<void> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: CatHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const request: CatPublishRequest = { title, content, tags, images };
    const result = await HttpRequest.postRawJson<CatResponse>('https://lyzyy.love:8081/api/v1/campus-cat/posts', JSON.stringify(request), headers);
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200) throw new Error(result.data.message || 'publish failed');
  }
}

