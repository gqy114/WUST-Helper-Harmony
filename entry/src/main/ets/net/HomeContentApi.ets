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
  private static fullImageUrl(url: string): string {
    if (!url || url.startsWith('http') || url.startsWith('file:') || url.startsWith('data:')) return url;
    return `https://lyzyy.love${url.startsWith('/') ? '' : '/'}${url}`;
  }

  static async notices(): Promise<HomeNotice[]> {
    const response = await HttpRequest.get<NoticeResponse>(
      'https://lyzyy.love:8081/operationLog/list/publishedButAndroid', { Accept: 'application/json' });
    const items = response.data.data || [];
    return items.map((item: NoticeDto) => {
      const notice: HomeNotice = { id: item.newsid || 0, title: item.title || '', content: item.content || '',
        updateTime: item.updateTime || '' };
      return notice;
    });
  }

  static async banners(): Promise<HomeBanner[]> {
    const response = await HttpRequest.get<BannerResponse>(
      'https://lyzyy.love:8081/wusthelperadminapi/v1/wusthelper/act', { Accept: 'application/json' });
    const items = response.data.data || [];
    return items.filter((item: BannerDto) => (item.imgUrl || '').trim().length > 0).map((item: BannerDto) => {
      const banner: HomeBanner = { id: item.actid || 0, title: item.title || '', content: item.content || '',
        imageUrl: HomeContentApi.fullImageUrl(item.imgUrl || '') };
      return banner;
    });
  }
}
