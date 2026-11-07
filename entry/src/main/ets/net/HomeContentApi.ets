import { HttpRequest } from './HttpRequest';

export interface HomeBanner {
  id: number;
  title: string;
  content: string;
  imageUrl: string;
}

export interface HomeNotice {
  id: number;
  title: string;
  content: string;
  updateTime: string;
}

interface NoticeDto {
  newsid?: number;
  title?: string;
  content?: string;
  updateTime?: string;
}

interface BannerDto {
  actid?: number;
  title?: string;
  content?: string;
  imgUrl?: string;
}

interface NoticeResponse { code?: number; message?: string; data?: NoticeDto[]; }
interface BannerResponse { code?: number; message?: string; data?: BannerDto[]; }

export class HomeContentApi {
  /** 启动页预取后，第一屏直接复用；60 秒内不重复请求。 */
  private static bannersCache: HomeBanner[] | null = null;
  private static bannersFetchedAt: number = 0;
  private static noticesCache: HomeNotice[] | null = null;
  private static noticesFetchedAt: number = 0;
  private static readonly CACHE_TTL_MS: number = 60_000;

  private static fullImageUrl(url: string): string {
    if (!url || url.startsWith('http') || url.startsWith('file:') || url.startsWith('data:')) return url;
    return `https://lyzyy.love${url.startsWith('/') ? '' : '/'}${url}`;
  }

  /** 启动页预取：把主页第一屏要用的轮播和公告先拉下来，失败静默。 */
  static async preload(): Promise<void> {
    try {
      await HomeContentApi.banners();
    } catch {
      console.warn('HomeContentApi', 'preload banners failed');
    }
    try {
      await HomeContentApi.notices();
    } catch {
      console.warn('HomeContentApi', 'preload notices failed');
    }
  }

  static async notices(): Promise<HomeNotice[]> {
    if (HomeContentApi.noticesCache !== null &&
      Date.now() - HomeContentApi.noticesFetchedAt < HomeContentApi.CACHE_TTL_MS) {
      return [...HomeContentApi.noticesCache];
    }
    const response = await HttpRequest.get<NoticeResponse>(
      'https://lyzyy.love:8081/operationLog/list/publishedButAndroid', { Accept: 'application/json' });
    const items = response.data.data || [];
    const notices = items.map((item: NoticeDto) => {
      const notice: HomeNotice = { id: item.newsid || 0, title: item.title || '', content: item.content || '',
        updateTime: item.updateTime || '' };
      return notice;
    });
    HomeContentApi.noticesCache = notices;
    HomeContentApi.noticesFetchedAt = Date.now();
    return [...notices];
  }

  static async banners(): Promise<HomeBanner[]> {
    if (HomeContentApi.bannersCache !== null &&
      Date.now() - HomeContentApi.bannersFetchedAt < HomeContentApi.CACHE_TTL_MS) {
      return [...HomeContentApi.bannersCache];
    }
    const response = await HttpRequest.get<BannerResponse>(
      'https://lyzyy.love:8081/wusthelperadminapi/v1/wusthelper/act', { Accept: 'application/json' });
    const items = response.data.data || [];
    const banners = items.filter((item: BannerDto) => (item.imgUrl || '').trim().length > 0)
      .map((item: BannerDto) => {
        const banner: HomeBanner = { id: item.actid || 0, title: item.title || '', content: item.content || '',
          imageUrl: HomeContentApi.fullImageUrl(item.imgUrl || '') };
        return banner;
      });
    HomeContentApi.bannersCache = banners;
    HomeContentApi.bannersFetchedAt = Date.now();
    return [...banners];
  }
}
