import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
export interface CampusWallReply { id?: number; displayName?: string; realName?: string; avatarUrl?: string; college?: string; major?: string; content?: string; createdAt?: string; }
export interface CampusWallPost {
  id?: number;
  title?: string;
  content?: string;
  tag?: string;
  displayName?: string;
  realName?: string;
  avatarUrl?: string;
  college?: string;
  major?: string;
  createdAt?: string;
  likeCount?: number;
  replyCount?: number;
  images?: string[];
  status?: string;
  resolved?: boolean;
  isResolved?: boolean;
  type?: string;
  category?: string;
  noticeType?: string;
  replies?: CampusWallReply[];
  reactions?: Record<string, number>;
}
export function decodeHtmlEntities(value: string): string {
  let result = value.replace(/<br\s*\/?>/gi, '\n');
  for (let index = 0; index < 3; index++) {
    const decoded = result.replace(/&#(\d+);/g, (_match: string, code: string) => String.fromCodePoint(Number(code)))
      .replace(/&#x([0-9a-fA-F]+);/g, (_match: string, code: string) => String.fromCodePoint(parseInt(code, 16)))
      .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'");
    if (decoded === result) break;
    result = decoded;
  }
  return result;
}
interface WallData { posts?: CampusWallPost[]; list?: CampusWallPost[]; }
interface WallResponse { code?: number; data?: WallData | CampusWallPost[]; }
interface WallDetailResponse { code?: number; data?: CampusWallPost; }
interface ReactionData { added?: boolean; }
interface ReactionResponse { data?: ReactionData; }
interface PublishResponse { code?: number; message?: string; }
interface WallHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
export class CampusWallApi {
  private static normalizePost(post: CampusWallPost): CampusWallPost {
    let images: string[] = [];
    const rawImages: string[] | string = post.images as string[] | string;
    if (Array.isArray(rawImages)) images = rawImages;
    else if (typeof rawImages === 'string') {
      try {
        const parsed = JSON.parse(rawImages) as string[];
        images = Array.isArray(parsed) ? parsed : [rawImages];
      } catch { images = rawImages.trim() ? [rawImages] : []; }
    }
    const fullImages: string[] = images.map((url: string) => url.startsWith('http') ? url : `https://lyzyy.love${url.startsWith('/') ? '' : '/'}${url}`);
    return { id: post.id, title: post.title, content: post.content, tag: post.tag,
      displayName: post.displayName, realName: post.realName, avatarUrl: post.avatarUrl,
      college: post.college, major: post.major, createdAt: post.createdAt,
      likeCount: post.likeCount, replyCount: post.replyCount, images: fullImages,
      status: post.status, resolved: post.resolved, isResolved: post.isResolved,
      type: post.type, category: post.category, noticeType: post.noticeType, replies: post.replies || [], reactions: post.reactions || {} };
  }
  private static async headers(): Promise<WallHeaders> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    return { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
  }
  static async list(page: number = 1, tag: string = 'wall'): Promise<CampusWallPost[]> {
    const headers = await CampusWallApi.headers();
    const aliases: string[] = tag === 'lost' ? ['lost', 'found', 'lost_found'] : tag === 'team' ? ['team', 'match', 'competition'] : tag === 'help' ? ['help', 'ask'] : [tag];
    for (const currentTag of aliases) {
      const response = await HttpRequest.get<WallResponse>(`https://lyzyy.love:8081/api/v1/campus-wall/posts?page=${page}&tag=${encodeURIComponent(currentTag)}`, headers);
      const data = response.data.data;
      const items: CampusWallPost[] = Array.isArray(data) ? data : (data?.posts || data?.list || []);
      if (items.length > 0 || aliases.length === 1) return items.map((post: CampusWallPost) => CampusWallApi.normalizePost(post));
    }
    return [];
  }

  static async detail(id: number): Promise<CampusWallPost> {
    const response = await HttpRequest.get<WallDetailResponse>(`https://lyzyy.love:8081/api/v1/campus-wall/posts/${id}`, await CampusWallApi.headers());
    return CampusWallApi.normalizePost(response.data.data || {});
  }

  static async toggleReaction(id: number, type: string = 'like'): Promise<boolean> {
    const response = await HttpRequest.postJson<ReactionResponse>(
      `https://lyzyy.love:8081/api/v1/campus-wall/posts/${id}/reactions`,
      { type }, await CampusWallApi.headers());
    return response.data.data?.added ?? false;
  }

  static async reply(id: number, content: string): Promise<void> {
    await HttpRequest.postJson<Record<string, string>>(
      `https://lyzyy.love:8081/api/v1/campus-wall/posts/${id}/replies`,
      { content }, await CampusWallApi.headers());
  }

  static async publish(title: string, content: string, tag: string = 'wall', extra: string = '{}'): Promise<void> {
    const response = await HttpRequest.postJson<PublishResponse>(
      'https://lyzyy.love:8081/api/v1/campus-wall/posts',
      { title, content, tag, extra, images: '[]' }, await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'publish failed');
  }
}
