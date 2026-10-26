import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
export interface CampusWallReply { id?: number; displayName?: string; realName?: string; avatarUrl?: string; college?: string; major?: string; content?: string; createdAt?: string; images?: string[]; }
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
  extra?: string;
  replies?: CampusWallReply[];
  reactions?: Record<string, number>;
}
export interface CampusWallExtra { type?: string; address?: string; acceptedReplyId?: number | string; }
export function campusWallExtra(post: CampusWallPost): CampusWallExtra {
  if (!post.extra) return {};
  try { return JSON.parse(post.extra) as CampusWallExtra; } catch { return {}; }
}
export function campusWallRelativeTime(value?: string): string {
  if (!value) return '';
  const stamp = Date.parse(value);
  if (isNaN(stamp)) return value;
  const elapsed = Math.max(0, Date.now() - stamp);
  const minutes = Math.floor(elapsed / 60000);
  if (minutes < 1) return '刚刚';
  if (minutes < 60) return `${minutes}分钟前`;
  const hours = Math.floor(elapsed / 3600000);
  if (hours < 24) return `${hours}小时前`;
  const days = Math.floor(elapsed / 86400000);
  if (days < 30) return `${days}天前`;
  const months = Math.floor(days / 30);
  if (months < 12) return `${months}个月前`;
  return `${Math.floor(days / 365)}年前`;
}
export interface CampusRedFlowerRank {
  rank: number;
  studentId: string;
  studentType?: string;
  realName?: string;
  displayName?: string;
  avatarUrl?: string;
  college?: string;
  major?: string;
  redFlowers: number;
  participating: boolean;
}
export interface CampusRedFlowerRanking { top: CampusRedFlowerRank[]; mine: CampusRedFlowerRank; }
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
interface FlowerRankingResponse { code?: number; message?: string; data?: CampusRedFlowerRanking; }
interface ReactionData { added?: boolean; }
interface ReactionResponse { data?: ReactionData; }
interface PublishResponse { code?: number; message?: string; }
interface WallHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
export class CampusWallApi {
  private static fullAssetUrl(url: string): string {
    if (!url || url.startsWith('http') || url.startsWith('file:') || url.startsWith('data:')) return url;
    return `https://lyzyy.love${url.startsWith('/') ? '' : '/'}${url}`;
  }
  private static normalizeReply(reply: CampusWallReply): CampusWallReply {
    const images: string[] = Array.isArray(reply.images) ? reply.images.map((url: string) => CampusWallApi.fullAssetUrl(url)) : [];
    return { id: reply.id, displayName: reply.displayName, realName: reply.realName,
      avatarUrl: CampusWallApi.fullAssetUrl(reply.avatarUrl || ''), college: reply.college,
      major: reply.major, content: reply.content, createdAt: reply.createdAt, images };
  }
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
    const fullImages: string[] = images.map((url: string) => CampusWallApi.fullAssetUrl(url));
    return { id: post.id, title: post.title, content: post.content, tag: post.tag,
      displayName: post.displayName, realName: post.realName, avatarUrl: CampusWallApi.fullAssetUrl(post.avatarUrl || ''),
      college: post.college, major: post.major, createdAt: post.createdAt,
      likeCount: post.likeCount, replyCount: post.replyCount, images: fullImages,
      status: post.status, resolved: post.resolved, isResolved: post.isResolved,
      type: post.type, category: post.category, noticeType: post.noticeType, extra: post.extra,
      replies: (post.replies || []).map((reply: CampusWallReply) => CampusWallApi.normalizeReply(reply)), reactions: post.reactions || {} };
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

  static async listPages(tag: string, maxPages: number = 5): Promise<CampusWallPost[]> {
    const posts: CampusWallPost[] = [];
    const seen: Set<number> = new Set<number>();
    for (let page = 1; page <= maxPages; page++) {
      const items = await CampusWallApi.list(page, tag);
      for (const post of items) {
        const id = post.id || 0;
        if (id === 0 || !seen.has(id)) {
          posts.push(post);
          if (id > 0) seen.add(id);
        }
      }
      if (items.length < 20) break;
    }
    return posts;
  }

  static async detail(id: number): Promise<CampusWallPost> {
    const response = await HttpRequest.get<WallDetailResponse>(`https://lyzyy.love:8081/api/v1/campus-wall/posts/${id}`, await CampusWallApi.headers());
    return CampusWallApi.normalizePost(response.data.data || {});
  }

  static async flowerRanking(): Promise<CampusRedFlowerRanking> {
    const response = await HttpRequest.get<FlowerRankingResponse>(
      'https://lyzyy.love:8081/api/v1/campus-wall/red-flowers/ranking', await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'ranking failed');
    const ranking: CampusRedFlowerRanking = response.data.data || { top: [], mine: {
      rank: 0, studentId: '', redFlowers: 0, participating: false
    } };
    ranking.top = (ranking.top || []).map((item: CampusRedFlowerRank) => {
      item.avatarUrl = CampusWallApi.fullAssetUrl(item.avatarUrl || '');
      return item;
    });
    ranking.mine.avatarUrl = CampusWallApi.fullAssetUrl(ranking.mine.avatarUrl || '');
    return ranking;
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

  static async publish(title: string, content: string, tag: string = 'wall', extra: string = '{}', images: string[] = []): Promise<void> {
    const response = await HttpRequest.postJson<PublishResponse>(
      'https://lyzyy.love:8081/api/v1/campus-wall/posts',
      { title, content, tag, extra, images: JSON.stringify(images) }, await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'publish failed');
  }
}
