import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
export interface CampusWallReply {
  id?: number; studentId?: string; displayName?: string; realName?: string; avatarUrl?: string;
  college?: string; major?: string; content?: string; createdAt?: string; images?: string[];
  redFlowers?: number; accepted?: boolean; isAccepted?: boolean; is_accepted?: boolean;
}
export interface CampusWallBookTrade {
  id?: number; listingId?: number; bookId?: number;
  price?: number | string; sellPrice?: number | string; salePrice?: number | string; bookPrice?: number | string;
  priceCents?: number | string;
  condition?: string; bookCondition?: string; title?: string; bookTitle?: string;
  author?: string; bookAuthor?: string; publisher?: string; bookPublisher?: string;
  edition?: string; bookEdition?: string; isbn?: string; bookIsbn?: string; majors?: string[] | string;
  campus?: string; campusName?: string; meetingPlace?: string; location?: string; note?: string;
  contact?: string; contactType?: string; contactValue?: string; contactInformation?: string;
  contact_type?: string; contact_value?: string; contact_information?: string;
  contactMethod?: string; contactWay?: string; contactContent?: string; contactAccount?: string;
  contact_method?: string; contact_way?: string; contact_content?: string; contact_account?: string;
  bookContact?: string; bookContactType?: string; book_contact?: string; book_contact_type?: string;
  sellerContact?: string; seller_contact?: string; phone?: string; mobile?: string; qq?: string;
  wechat?: string; weChat?: string;
}
export interface CampusWallPost {
  id?: number;
  studentId?: string;
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
  redFlowers?: number;
  images?: string[];
  status?: string;
  resolved?: boolean;
  isResolved?: boolean;
  acceptedReplyId?: number | string;
  accepted_reply_id?: number | string;
  type?: string;
  category?: string;
  noticeType?: string;
  address?: string;
  extra?: string;
  price?: number | string;
  sellPrice?: number | string;
  salePrice?: number | string;
  bookPrice?: number | string;
  priceCents?: number | string;
  sellingPrice?: number | string;
  condition?: string;
  bookTitle?: string;
  bookAuthor?: string;
  bookPublisher?: string;
  bookEdition?: string;
  bookIsbn?: string;
  author?: string;
  publisher?: string;
  edition?: string;
  isbn?: string;
  campus?: string;
  campusName?: string;
  majors?: string[] | string;
  meetingPlace?: string;
  location?: string;
  note?: string;
  contact?: string; contactType?: string; contactValue?: string; contactInformation?: string;
  contact_type?: string; contact_value?: string; contact_information?: string;
  contactMethod?: string; contactWay?: string; contactContent?: string; contactAccount?: string;
  contact_method?: string; contact_way?: string; contact_content?: string; contact_account?: string;
  bookContact?: string; bookContactType?: string; book_contact?: string; book_contact_type?: string;
  sellerContact?: string; seller_contact?: string; phone?: string; mobile?: string; qq?: string;
  wechat?: string; weChat?: string;
  bookTrade?: CampusWallBookTrade;
  bookTradeInfo?: CampusWallBookTrade;
  listingId?: number;
  bookId?: number;
  replies?: CampusWallReply[];
  reactions?: Record<string, number>;
  myReactions?: string[];
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
export interface CampusWallNotificationActor {
  studentId?: string; realName?: string; displayName?: string; avatarUrl?: string; college?: string; major?: string;
}
export interface CampusWallNotification {
  id?: number; eventType?: string; targetType?: string; targetId?: number; postId?: number; createdAt?: string;
  readAt?: string; actor?: CampusWallNotificationActor; postTitle?: string; postTag?: string; content?: string;
}
export interface CampusWallNotificationPage { items: CampusWallNotification[]; latestId: number; unreadCount: number; }
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
interface ReplyResponse { code?: number; message?: string; }
interface ReportResponse { code?: number; message?: string; }
interface DeleteResponse { code?: number; message?: string; }
interface AcceptReplyResponse { code?: number; message?: string; data?: Record<string, number | string>; }
interface NotificationResponse { code?: number; message?: string; data?: CampusWallNotificationPage; }
interface WallHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
export class CampusWallApi {
  private static fullAssetUrl(url: string): string {
    if (!url || url.startsWith('http') || url.startsWith('file:') || url.startsWith('data:')) return url;
    return `https://lyzyy.love${url.startsWith('/') ? '' : '/'}${url}`;
  }
  private static normalizeReply(reply: CampusWallReply): CampusWallReply {
    const images: string[] = Array.isArray(reply.images) ? reply.images.map((url: string) => CampusWallApi.fullAssetUrl(url)) : [];
    // Preserve fields added by the backend (for example accepted flags) instead
    // of rebuilding a smaller reply object and silently discarding them.
    reply.avatarUrl = CampusWallApi.fullAssetUrl(reply.avatarUrl || '');
    reply.images = images;
    reply.redFlowers = reply.redFlowers || 0;
    return reply;
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
    // Keep the original response object instead of rebuilding a generic wall post.
    // Book-trade fields are extended independently by the backend; rebuilding the
    // object here used to silently discard price, publisher, edition and ISBN.
    post.images = images.map((url: string) => CampusWallApi.fullAssetUrl(url));
    post.avatarUrl = CampusWallApi.fullAssetUrl(post.avatarUrl || '');
    post.redFlowers = post.redFlowers || 0;
    post.replies = (post.replies || []).map((reply: CampusWallReply) => CampusWallApi.normalizeReply(reply));
    post.reactions = post.reactions || {};
    post.myReactions = post.myReactions || [];
    return post;
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

  static async notifications(beforeId: number = 0, limit: number = 30): Promise<CampusWallNotificationPage> {
    const cursor = beforeId > 0 ? `&beforeId=${beforeId}` : '';
    const response = await HttpRequest.get<NotificationResponse>(
      `https://lyzyy.love:8081/api/v1/campus-wall/notifications?limit=${limit}&includeCat=1${cursor}`,
      await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'notifications failed');
    const page = response.data.data || { items: [], latestId: 0, unreadCount: 0 };
    page.items = (page.items || []).map((item: CampusWallNotification) => {
      if (item.actor) item.actor.avatarUrl = CampusWallApi.fullAssetUrl(item.actor.avatarUrl || '');
      return item;
    });
    return page;
  }

  static async markNotificationsRead(throughId: number): Promise<void> {
    if (throughId <= 0) return;
    await HttpRequest.postJson<Record<string, Object>>(
      'https://lyzyy.love:8081/api/v1/campus-wall/notifications/read?includeCat=1',
      { throughId: String(throughId) }, await CampusWallApi.headers());
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
    const response = await HttpRequest.postJson<ReplyResponse>(
      `https://lyzyy.love:8081/api/v1/campus-wall/posts/${id}/replies`,
      { content }, await CampusWallApi.headers());
    const status = response.response.responseCode;
    const data = response.data;
    if (status < 200 || status >= 300 || !data || typeof data !== 'object' ||
      (data.code !== 0 && data.code !== 200)) {
      throw new Error((data && typeof data === 'object' ? data.message : '') || '留言发送失败，请稍后重试');
    }
  }

  static async report(targetType: string, targetId: number, reason: string): Promise<void> {
    const response = await HttpRequest.postJson<ReportResponse>(
      'https://lyzyy.love:8081/api/v1/campus-wall/reports',
      { targetType, targetId: String(targetId), reason }, await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'report failed');
  }

  static async deletePost(id: number): Promise<void> {
    const response = await HttpRequest.postJson<DeleteResponse>(
      `https://lyzyy.love:8081/api/v1/campus-wall/posts/${id}/delete`, {}, await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'delete post failed');
  }

  static async deleteReply(postId: number, replyId: number): Promise<void> {
    const response = await HttpRequest.postJson<DeleteResponse>(
      `https://lyzyy.love:8081/api/v1/campus-wall/posts/${postId}/replies/${replyId}/delete`, {},
      await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'delete reply failed');
  }

  static async acceptReply(postId: number, replyId: number): Promise<void> {
    const response = await HttpRequest.postJson<AcceptReplyResponse>(
      `https://lyzyy.love:8081/api/v1/campus-wall/posts/${postId}/accepted-reply`,
      { replyId: String(replyId) }, await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'accept reply failed');
  }

  static async publish(title: string, content: string, tag: string = 'wall', extra: string = '{}', images: string[] = []): Promise<void> {
    const response = await HttpRequest.postJson<PublishResponse>(
      'https://lyzyy.love:8081/api/v1/campus-wall/posts',
      { title, content, tag, extra, images: JSON.stringify(images) }, await CampusWallApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'publish failed');
  }
}
