import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
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
}
export function decodeHtmlEntities(value: string): string {
  let result = value;
  for (let index = 0; index < 3; index++) {
    const decoded = result.replace(/&#(\d+);/g, (_match: string, code: string) => String.fromCharCode(Number(code)))
      .replace(/&#x([0-9a-fA-F]+);/g, (_match: string, code: string) => String.fromCharCode(parseInt(code, 16)))
      .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'");
    if (decoded === result) break;
    result = decoded;
  }
  return result;
}
interface WallData { posts?: CampusWallPost[]; list?: CampusWallPost[]; }
interface WallResponse { code?: number; data?: WallData | CampusWallPost[]; }
interface ReactionData { added?: boolean; }
interface ReactionResponse { data?: ReactionData; }
interface WallHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
export class CampusWallApi {
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
      if (items.length > 0 || aliases.length === 1) return items;
    }
    return [];
  }

  static async detail(id: number): Promise<CampusWallPost> {
    const response = await HttpRequest.get<CampusWallPost>(`https://lyzyy.love:8081/api/v1/campus-wall/posts/${id}`, await CampusWallApi.headers());
    return response.data;
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

  static async publish(title: string, content: string, tag: string = 'wall'): Promise<void> {
    await HttpRequest.postJson<Record<string, string>>(
      'https://lyzyy.love:8081/api/v1/campus-wall/posts',
      { title, content, tag, extra: '{}', images: '[]' }, await CampusWallApi.headers());
  }
}
