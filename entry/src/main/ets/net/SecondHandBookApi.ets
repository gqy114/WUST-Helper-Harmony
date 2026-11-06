import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
import { CampusWallApi, CampusWallBookTrade, CampusWallPost, CampusWallReply, decodeHtmlEntities } from './CampusWallApi';
export interface SecondhandReply { id?: number; studentId?: string; displayName?: string; realName?: string; avatarUrl?: string; college?: string; major?: string; content?: string; createdAt?: string | number; redFlowers?: number; }
export interface SecondhandBook { id?: number; isbn?: string; title?: string; author?: string; publisher?: string; edition?: string; category?: string; coverUrl?: string; listingCount?: number; priceMin?: number; priceMax?: number; priceAvg?: number; }
export interface SecondhandContactFields {
  contact?: string; contactType?: string; contactValue?: string; contactInformation?: string;
  contact_type?: string; contact_value?: string; contact_information?: string;
  contactMethod?: string; contactWay?: string; contactContent?: string; contactAccount?: string;
  contact_method?: string; contact_way?: string; contact_content?: string; contact_account?: string;
  bookContact?: string; bookContactType?: string; book_contact?: string; book_contact_type?: string;
  sellerContact?: string; seller_contact?: string; phone?: string; mobile?: string; qq?: string;
  wechat?: string; weChat?: string;
}
export interface SecondhandListing extends SecondhandContactFields { id?: number; bookId?: number; sellerId?: string; price?: number; sellPrice?: number | string; salePrice?: number | string; bookPrice?: number | string; amount?: number | string; condition?: string; bookCondition?: string; note?: string; images?: string[]; status?: string; createdAt?: number | string; bookTitle?: string; bookAuthor?: string; bookPublisher?: string; bookEdition?: string; bookIsbn?: string; bookCover?: string; campus?: string; campusName?: string; major?: string; majors?: string[] | string; sellerName?: string; displayName?: string; realName?: string; sellerAvatar?: string; avatarUrl?: string; college?: string; redFlowers?: number; replies?: SecondhandReply[]; source?: string; communityPostId?: number; book?: SecondhandBook; extra?: string; seller?: SecondhandContactFields; trade?: SecondhandContactFields; contactInfo?: string | SecondhandContactFields; contact_info?: string | SecondhandContactFields; }
export interface SecondhandDetail { book?: SecondhandBook; listing?: SecondhandListing; replies?: SecondhandReply[]; }
interface Response<T> { data?: T; code?: number; message?: string; }
interface Headers extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
interface RecognizeRequest { isbn: string; title: string; author: string; publisher: string; edition: string; category: string; coverUrl: string; listPrice: number; ocrRaw: string; source: string; }
interface RecognizeData { book?: SecondhandBook; }
interface ListingRequest { bookId: number; price: number; condition: string; note: string; images: string[]; contact: string; ocrRaw: string; }
interface MajorItem { name?: string; label?: string; value?: string; title?: string; major?: string; majorName?: string; }
type MajorValue = string | MajorItem;
interface MajorPage { items?: MajorValue[]; list?: MajorValue[]; majors?: MajorValue[]; records?: MajorValue[]; data?: MajorValue[]; }
interface ListingPage { items?: SecondhandListing[]; list?: SecondhandListing[]; listings?: SecondhandListing[]; records?: SecondhandListing[]; content?: SecondhandListing[]; data?: SecondhandListing[]; }
interface BookDetailData { book?: SecondhandBook; listings?: SecondhandListing[]; listing?: SecondhandListing; replies?: SecondhandReply[]; }
interface ListingDetailData extends SecondhandListing { listing?: SecondhandListing; item?: SecondhandListing; }
interface BookTradeExtra extends SecondhandContactFields {
  id?: number; listingId?: number; listing_id?: number; bookId?: number; book_id?: number;
  bookTrade?: CampusWallBookTrade; bookTradeInfo?: CampusWallBookTrade;
  price?: number | string; condition?: string; campus?: string; campusName?: string; major?: string;
  majors?: string[] | string; meetingPlace?: string; address?: string; contact?: string; contactType?: string;
  author?: string; publisher?: string; edition?: string; isbn?: string; note?: string; bookTitle?: string; title?: string;
  book_author?: string; book_publisher?: string; book_edition?: string; book_isbn?: string;
  salePrice?: number | string; sale_price?: number | string; bookCondition?: string; book_condition?: string;
  applicableMajors?: string[] | string; applicable_majors?: string[] | string;
  tradeCampus?: string; trade_campus?: string; tradePlace?: string; trade_place?: string;
  contactInfo?: string | SecondhandContactFields; contact_info?: string | SecondhandContactFields;
  seller?: SecondhandContactFields; trade?: SecondhandContactFields;
  sellingPrice?: number | string; selling_price?: number | string; priceYuan?: number | string; price_yuan?: number | string;
  priceCents?: number | string; price_cents?: number | string;
  amount?: number | string; bookPublisher?: string; bookEdition?: string; bookIsbn?: string;
  publisherName?: string; editionInfo?: string; isbn13?: string; description?: string;
  tradeLocation?: string; trade_location?: string; contactMethod?: string; contact_method?: string;
  sellPrice?: number | string; sell_price?: number | string; bookPrice?: number | string; book_price?: number | string;
  bookMajors?: string[] | string; book_majors?: string[] | string; bookCampus?: string; book_campus?: string;
  bookLocation?: string; book_location?: string;
}
export class SecondHandBookApi {
  private static async headers(): Promise<Headers> { const token = await AppStorage.getInstance().getAppAuthAccessToken(); return { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' }; }
  static async feed(keyword: string = '', category: string = '', major: string = '', page: number = 1, limit: number = 20): Promise<SecondhandListing[]> {
    const query = `?page=${page}&limit=${limit}&keyword=${encodeURIComponent(keyword)}&category=${encodeURIComponent(category)}${major.length > 0 ? `&major=${encodeURIComponent(major)}` : ''}`;
    const response = await HttpRequest.get<Response<SecondhandListing[] | ListingPage>>(`https://lyzyy.love:8081/api/v1/secondhand/listings${query}`, await SecondHandBookApi.headers());
    const data = response.data.data;
    const values: SecondhandListing[] = Array.isArray(data) ? data : (data?.items || data?.list || data?.listings || data?.records || data?.content || data?.data || []);
    return values.map((item: SecondhandListing) => SecondHandBookApi.normalizeListing(item));
  }
  static async categories(): Promise<string[]> { const response = await HttpRequest.get<Response<string[]>>('https://lyzyy.love:8081/api/v1/secondhand/categories', await SecondHandBookApi.headers()); return Array.isArray(response.data.data) ? response.data.data : []; }

  private static bookTradeExtra(post: CampusWallPost): BookTradeExtra {
    if (!post.extra) return {};
    try { return JSON.parse(post.extra) as BookTradeExtra; } catch { return {}; }
  }

  private static numberValue(value?: number | string): number {
    if (typeof value === 'number') return value;
    const parsed = Number((value || '').replace(/[^0-9.]/g, ''));
    return isNaN(parsed) ? 0 : parsed;
  }

  static decoded(value?: string): string { return decodeHtmlEntities(value || ''); }

  private static contactPair(fields?: SecondhandContactFields | CampusWallBookTrade | CampusWallPost): string[] {
    if (!fields) return ['', ''];
    const value = fields.contact || fields.contactValue || fields.contact_value || fields.contactInformation ||
      fields.contact_information || fields.contactContent || fields.contact_content || fields.contactAccount ||
      fields.contact_account || fields.bookContact || fields.book_contact || fields.sellerContact ||
      fields.seller_contact || fields.phone || fields.mobile || fields.qq || fields.wechat || fields.weChat || '';
    let type = fields.contactType || fields.contact_type || fields.contactMethod || fields.contact_method ||
      fields.contactWay || fields.contact_way || fields.bookContactType || fields.book_contact_type || '';
    if (!type && fields.qq) type = 'QQ';
    if (!type && (fields.wechat || fields.weChat)) type = '微信';
    if (!type && (fields.phone || fields.mobile)) type = '手机号';
    return [SecondHandBookApi.decoded(type).trim(), SecondHandBookApi.decoded(value).trim()];
  }

  private static contactInfoPair(info?: string | SecondhandContactFields): string[] {
    if (!info) return ['', ''];
    if (typeof info === 'string') return ['', SecondHandBookApi.decoded(info).trim()];
    return SecondHandBookApi.contactPair(info);
  }

  private static formatContact(pairs: string[][]): string {
    let type = '';
    let value = '';
    for (const pair of pairs) {
      if (value || !pair[1]) continue;
      value = pair[1];
      type = pair[0] || '';
    }
    if (!value) return '';
    if (!type) {
      // 类型与号码可能分开存放（例如 post.contactType='QQ'、extra.contactValue='12345678'）。
      // 只从“有类型没有号码”的来源补齐类型：这些来源没有自己的号码，
      // 不会把另一种联系方式（如另一个卖家的微信）的类型误配给当前号码。
      for (const pair of pairs) {
        if (!pair[1] && pair[0]) { type = pair[0]; break; }
      }
    }
    if (!type || value.indexOf('：') >= 0 || value.indexOf(':') >= 0) return value;
    return `${type}：${value}`;
  }

  private static normalizedContact(item: SecondhandListing): string {
    let extra: BookTradeExtra = {};
    if (item.extra) {
      try { extra = JSON.parse(item.extra) as BookTradeExtra; } catch {}
    }
    return SecondHandBookApi.formatContact([
      SecondHandBookApi.contactPair(item), SecondHandBookApi.contactInfoPair(item.contactInfo),
      SecondHandBookApi.contactInfoPair(item.contact_info), SecondHandBookApi.contactPair(item.seller),
      SecondHandBookApi.contactPair(item.trade), SecondHandBookApi.contactPair(extra),
      SecondHandBookApi.contactInfoPair(extra.contactInfo), SecondHandBookApi.contactInfoPair(extra.contact_info),
      SecondHandBookApi.contactPair(extra.seller), SecondHandBookApi.contactPair(extra.trade),
      SecondHandBookApi.contactPair(extra.bookTrade), SecondHandBookApi.contactPair(extra.bookTradeInfo)
    ]);
  }

  private static text(value?: string): string { return (value || '').trim(); }

  // 详情接口可能只返回部分字段（例如仅补回联系方式），直接替换会把列表里已有的
  // id、sellerId、价格和书籍信息清空。这里逐字段合并：详情有值则覆盖，无值保留列表数据。
  private static mergeListing(base: SecondhandListing, incoming?: SecondhandListing): SecondhandListing {
    if (!incoming) return base;
    const merged: SecondhandListing = base;
    merged.id = (incoming.id || 0) > 0 ? incoming.id : merged.id;
    merged.bookId = (incoming.bookId || 0) > 0 ? incoming.bookId : merged.bookId;
    merged.sellerId = SecondHandBookApi.text(incoming.sellerId) || merged.sellerId;
    merged.price = incoming.price !== undefined && incoming.price !== null ? incoming.price : merged.price;
    merged.condition = SecondHandBookApi.text(incoming.condition) || merged.condition;
    merged.note = SecondHandBookApi.text(incoming.note) || merged.note;
    merged.status = SecondHandBookApi.text(incoming.status) || merged.status;
    merged.images = (incoming.images && incoming.images.length > 0) ? incoming.images : merged.images;
    merged.createdAt = incoming.createdAt !== undefined && incoming.createdAt !== null ? incoming.createdAt : merged.createdAt;
    merged.bookTitle = SecondHandBookApi.text(incoming.bookTitle) || merged.bookTitle;
    merged.bookAuthor = SecondHandBookApi.text(incoming.bookAuthor) || merged.bookAuthor;
    merged.bookPublisher = SecondHandBookApi.text(incoming.bookPublisher) || merged.bookPublisher;
    merged.bookEdition = SecondHandBookApi.text(incoming.bookEdition) || merged.bookEdition;
    merged.bookIsbn = SecondHandBookApi.text(incoming.bookIsbn) || merged.bookIsbn;
    merged.bookCover = SecondHandBookApi.text(incoming.bookCover) || merged.bookCover;
    merged.campus = SecondHandBookApi.text(incoming.campus) || merged.campus;
    merged.campusName = SecondHandBookApi.text(incoming.campusName) || merged.campusName;
    merged.major = SecondHandBookApi.text(incoming.major) || merged.major;
    merged.majors = incoming.majors !== undefined ? incoming.majors : merged.majors;
    merged.sellerName = SecondHandBookApi.text(incoming.sellerName) || merged.sellerName;
    merged.displayName = SecondHandBookApi.text(incoming.displayName) || merged.displayName;
    merged.realName = SecondHandBookApi.text(incoming.realName) || merged.realName;
    merged.sellerAvatar = SecondHandBookApi.text(incoming.sellerAvatar) || merged.sellerAvatar;
    merged.avatarUrl = SecondHandBookApi.text(incoming.avatarUrl) || merged.avatarUrl;
    merged.college = SecondHandBookApi.text(incoming.college) || merged.college;
    if (merged.redFlowers === undefined) merged.redFlowers = incoming.redFlowers;
    merged.source = SecondHandBookApi.text(incoming.source) || merged.source;
    merged.communityPostId = (incoming.communityPostId || 0) > 0 ? incoming.communityPostId : merged.communityPostId;
    merged.extra = SecondHandBookApi.text(incoming.extra) || merged.extra;
    merged.book = incoming.book || merged.book;
    merged.contact = SecondHandBookApi.normalizedContact(incoming) || merged.contact;
    merged.replies = (incoming.replies && incoming.replies.length > 0) ? incoming.replies : merged.replies;
    return merged;
  }

  static conditionLabel(value?: string): string {
    const condition = (value || '').trim().toLowerCase();
    if (condition === 'new' || condition === 'brand_new') return '全新';
    if (condition === 'like_new' || condition === '90_new') return '九成新';
    if (condition === 'good' || condition === '80_new') return '八成新';
    if (condition === 'fair' || condition === 'other') return '其他';
    return SecondHandBookApi.decoded(value);
  }

  static normalizeListing(item: SecondhandListing): SecondhandListing {
    const book = item.book;
    if (book) {
      item.bookId = item.bookId || book.id;
      item.bookTitle = item.bookTitle || book.title;
      item.bookAuthor = item.bookAuthor || book.author;
      item.bookPublisher = item.bookPublisher || book.publisher;
      item.bookEdition = item.bookEdition || book.edition;
      item.bookIsbn = item.bookIsbn || book.isbn;
      item.bookCover = item.bookCover || book.coverUrl;
    }
    item.price = SecondHandBookApi.numberValue(item.price ?? item.sellPrice ?? item.salePrice ?? item.bookPrice ?? item.amount);
    item.condition = item.condition || item.bookCondition;
    item.contact = SecondHandBookApi.normalizedContact(item);
    const majorValue = item.majors || item.major;
    item.major = Array.isArray(majorValue) ? majorValue.join('、') : majorValue;
    item.bookTitle = SecondHandBookApi.decoded(item.bookTitle);
    item.bookAuthor = SecondHandBookApi.decoded(item.bookAuthor);
    item.bookPublisher = SecondHandBookApi.decoded(item.bookPublisher);
    item.bookEdition = SecondHandBookApi.decoded(item.bookEdition);
    item.bookIsbn = SecondHandBookApi.decoded(item.bookIsbn);
    item.note = SecondHandBookApi.decoded(item.note);
    item.condition = SecondHandBookApi.conditionLabel(item.condition);
    item.replies = (item.replies || []).map((reply: SecondhandReply): SecondhandReply => {
      reply.content = SecondHandBookApi.decoded(reply.content);
      return reply;
    });
    return item;
  }

  static fromCommunityPost(post: CampusWallPost): SecondhandListing {
    const extra = SecondHandBookApi.bookTradeExtra(post);
    const trade: CampusWallBookTrade = post.bookTrade || post.bookTradeInfo || extra.bookTrade || extra.bookTradeInfo || {};
    const listingId = trade.listingId || trade.id || post.listingId || extra.listingId || extra.listing_id || 0;
    const bookId = trade.bookId || post.bookId || extra.bookId || extra.book_id || 0;
    const majorValue = trade.majors || post.majors || extra.majors || extra.bookMajors || extra.book_majors || extra.applicableMajors || extra.applicable_majors || extra.major || '';
    const majors = Array.isArray(majorValue) ? majorValue.join('、') : majorValue;
    const details: string[] = [];
    if (majors) details.push(`适用专业：${majors}`);
    const campus = trade.campusName || trade.campus || post.campusName || post.campus || extra.campusName || extra.campus || extra.bookCampus || extra.book_campus || extra.tradeCampus || extra.trade_campus || '';
    if (campus) details.push(`面交校区：${campus}`);
    const place = trade.meetingPlace || trade.location || post.meetingPlace || post.location || extra.meetingPlace || extra.bookLocation || extra.book_location || extra.tradePlace || extra.trade_place || extra.tradeLocation || extra.trade_location || extra.address || '';
    if (place) details.push(`面交地点：${place}`);
    const author = trade.bookAuthor || trade.author || post.bookAuthor || post.author || extra.author || extra.book_author || '';
    const publisher = trade.bookPublisher || trade.publisher || post.bookPublisher || post.publisher || extra.publisher || extra.bookPublisher || extra.book_publisher || extra.publisherName || '';
    const edition = trade.bookEdition || trade.edition || post.bookEdition || post.edition || extra.edition || extra.bookEdition || extra.book_edition || extra.editionInfo || '';
    const isbn = trade.bookIsbn || trade.isbn || post.bookIsbn || post.isbn || extra.isbn || extra.bookIsbn || extra.book_isbn || extra.isbn13 || '';
    if (author) details.push(`作者：${author}`);
    if (publisher) details.push(`出版社：${publisher}`);
    if (edition) details.push(`版次：${edition}`);
    if (isbn) details.push(`ISBN：${isbn}`);
    if (trade.note || post.note || extra.note || extra.description) details.push(trade.note || post.note || extra.note || extra.description || '');
    if (post.content) details.push(post.content);
    const replies: SecondhandReply[] = (post.replies || []).map((reply: CampusWallReply): SecondhandReply => ({
      id: reply.id, studentId: reply.studentId, displayName: reply.displayName, realName: reply.realName,
      avatarUrl: reply.avatarUrl, college: reply.college, major: reply.major, content: SecondHandBookApi.decoded(reply.content),
      createdAt: reply.createdAt, redFlowers: reply.redFlowers
    }));
    const contact = SecondHandBookApi.formatContact([
      SecondHandBookApi.contactPair(trade), SecondHandBookApi.contactPair(post), SecondHandBookApi.contactPair(extra),
      SecondHandBookApi.contactInfoPair(extra.contactInfo), SecondHandBookApi.contactInfoPair(extra.contact_info),
      SecondHandBookApi.contactPair(extra.seller), SecondHandBookApi.contactPair(extra.trade)
    ]);
    const cents = trade.priceCents ?? post.priceCents ?? extra.priceCents ?? extra.price_cents;
    const price = cents !== undefined ? SecondHandBookApi.numberValue(cents) / 100 :
      SecondHandBookApi.numberValue(trade.price ?? trade.sellPrice ?? trade.salePrice ?? trade.bookPrice ?? post.price ?? post.sellPrice ?? post.salePrice ?? post.bookPrice ?? post.sellingPrice ?? extra.price ?? extra.bookPrice ?? extra.book_price ?? extra.sellPrice ?? extra.sell_price ?? extra.salePrice ?? extra.sale_price ?? extra.sellingPrice ?? extra.selling_price ?? extra.priceYuan ?? extra.price_yuan ?? extra.amount);
    return SecondHandBookApi.normalizeListing({ id: listingId || post.id, bookId, communityPostId: post.id, source: 'community', sellerId: post.studentId,
      price,
      condition: trade.condition || trade.bookCondition || post.condition || extra.condition || extra.bookCondition || extra.book_condition || '', note: details.join('\n'),
      images: post.images || [], contact, createdAt: post.createdAt, bookTitle: trade.bookTitle || trade.title || post.bookTitle || extra.bookTitle || extra.title || post.title,
      bookAuthor: author, bookPublisher: publisher, bookEdition: edition, bookIsbn: isbn,
      bookCover: (post.images || [])[0] || '', campus, campusName: campus, major: majors,
      sellerName: post.displayName || post.realName, displayName: post.displayName, realName: post.realName,
      sellerAvatar: post.avatarUrl, avatarUrl: post.avatarUrl, college: post.college, redFlowers: post.redFlowers, replies });
  }

  static async communityFeed(page: number = 1): Promise<SecondhandListing[]> {
    const tags: string[] = ['book_trade', 'book-trade', 'book', 'secondhand', 'second_hand_book'];
    const result: SecondhandListing[] = [];
    const seen: Set<number> = new Set<number>();
    for (const tag of tags) {
      try {
        const posts = await CampusWallApi.list(page, tag);
        posts.forEach((post: CampusWallPost) => {
          const id = post.id || 0;
          if (id <= 0 || seen.has(id)) return;
          seen.add(id);
          result.push(SecondHandBookApi.fromCommunityPost(post));
        });
      } catch {}
    }
    return result;
  }
  static async detail(listing: SecondhandListing, requireReplies: boolean = false): Promise<SecondhandDetail> {
    const headers = await SecondHandBookApi.headers();
    let current: SecondhandListing = listing;
    let replies: SecondhandReply[] = listing.replies || [];
    let book: SecondhandBook | undefined = undefined;
    if ((listing.id || 0) > 0) {
      try {
        // 列表接口可能为保护卖家隐私省略联系方式，详情接口会在登录后返回完整交易资料。
        // 该请求以 URL 中的 listing.id 定位商品，因此只做字段合并，不整体替换。
        const response = await HttpRequest.get<Response<ListingDetailData>>(
          `https://lyzyy.love:8081/api/v1/secondhand/listings/${listing.id}`, headers);
        const data = response.data.data;
        const detailed = data?.listing || data?.item || data;
        // 详情里若显式给出了不同的 ID，说明返回的不是当前商品，直接忽略。
        if (detailed && (!(detailed.id || 0) || detailed.id === listing.id)) {
          current = SecondHandBookApi.mergeListing(current, detailed);
        }
      } catch {}
    }
    if ((listing.bookId || 0) > 0) {
      try {
        const response = await HttpRequest.get<Response<BookDetailData>>(
          `https://lyzyy.love:8081/api/v1/secondhand/books/${listing.bookId}`, headers);
        const data = response.data.data;
        book = data?.book;
        // 书籍详情返回的是同一本书下的商品集合，单条 listing 不保证就是当前商品，
        // 必须核对 ID，否则会把另一位卖家的联系方式、价格错当成本商品的。
        const single = data?.listing;
        const matched = (data?.listings || []).find((item: SecondhandListing) => item.id === listing.id) ||
          ((single && single.id === listing.id) ? single : undefined);
        if (matched) {
          current = SecondHandBookApi.mergeListing(current, matched);
        }
      } catch {}
    }
    if ((listing.id || 0) > 0) {
      try {
        const response = await HttpRequest.get<Response<SecondhandReply[]>>(
          `https://lyzyy.love:8081/api/v1/secondhand/listings/${listing.id}/replies`, headers);
        const status = response.response.responseCode;
        const data = response.data;
        if (status < 200 || status >= 300 || !data || typeof data !== 'object' ||
          (data.code !== 0 && data.code !== 200) || !Array.isArray(data.data)) {
          throw new Error('留言刷新失败');
        }
        replies = data.data;
      } catch (error) {
        // Older backends may not have the replies endpoint. A normal details
        // load can still show the book, but a post-send refresh must report it.
        if (requireReplies) {
          const message = error instanceof Error && error.message ? error.message : '留言刷新失败';
          throw new Error(message);
        }
      }
    }
    if (book) {
      book.title = SecondHandBookApi.decoded(book.title);
      book.author = SecondHandBookApi.decoded(book.author);
      book.publisher = SecondHandBookApi.decoded(book.publisher);
      book.edition = SecondHandBookApi.decoded(book.edition);
      book.isbn = SecondHandBookApi.decoded(book.isbn);
    }
    current.replies = replies;
    const normalized = SecondHandBookApi.normalizeListing(current);
    return { book, listing: normalized, replies: normalized.replies || replies };
  }

  static async reply(listingId: number, content: string): Promise<void> {
    const response = await HttpRequest.postJson<Response<Object>>(
      `https://lyzyy.love:8081/api/v1/secondhand/listings/${listingId}/replies`,
      { content }, await SecondHandBookApi.headers());
    const status = response.response.responseCode;
    const data = response.data;
    if (status < 200 || status >= 300 || !data || typeof data !== 'object' ||
      (data.code !== 0 && data.code !== 200)) {
      const message = data && typeof data === 'object' ? data.message : '';
      if (status === 404 || (data && typeof data === 'object' && data.code === 404)) {
        throw new Error(message || '书籍不存在或留言服务暂不可用');
      }
      if (status === 409 || (data && typeof data === 'object' && data.code === 409)) {
        throw new Error(message || '书籍已售出，无法留言');
      }
      throw new Error(message || '留言发送失败，请稍后重试');
    }
  }
  static async removeListing(listingId: number): Promise<void> {
    const response = await HttpRequest.postJson<Response<Object>>(
      `https://lyzyy.love:8081/api/v1/secondhand/listings/${listingId}/status`,
      { status: 'removed' }, await SecondHandBookApi.headers());
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'remove listing failed');
  }
  static async majors(): Promise<string[]> {
    // 专业数据来自校园社区二手书接口。旧的 /secondhand/majors 路由未部署，
    // 请求它只会得到 404，页面随后把异常吞掉并表现为专业列表为空。
    const response = await HttpRequest.get<Response<MajorValue[] | MajorPage>>('https://lyzyy.love:8081/api/v1/campus-wall/book-trade/majors', await SecondHandBookApi.headers());
    if (response.data.code !== undefined && response.data.code !== 0 && response.data.code !== 200) {
      throw new Error(response.data.message || 'major list load failed');
    }
    const data = response.data.data;
    let values: MajorValue[] = [];
    if (Array.isArray(data)) values = data;
    else if (data) values = data.items || data.list || data.majors || data.records || data.data || [];
    const names: string[] = [];
    values.forEach((value: MajorValue) => {
      const name = typeof value === 'string' ? value : (value.name || value.majorName || value.major || value.label || value.title || value.value || '');
      const normalized = name.trim();
      if (normalized.length > 0 && names.indexOf(normalized) < 0) names.push(normalized);
    });
    return names;
  }
  static async publishManual(title: string, price: number, edition: string, meetingPlace: string, contact: string,
    note: string, images: string[] = [], condition: string = '', major: string = '', campus: string = '',
    contactType: string = '', author: string = '', publisher: string = '', isbn: string = ''): Promise<void> {
    const headers = await SecondHandBookApi.headers();
    const recognize: RecognizeRequest = { isbn, title, author, publisher, edition, category: major, coverUrl: '', listPrice: 0, ocrRaw: '', source: 'manual' };
    const recognized = await HttpRequest.postRawJson<Response<RecognizeData>>('https://lyzyy.love:8081/api/v1/secondhand/recognize', JSON.stringify(recognize), headers);
    const bookId = recognized.data.data?.book?.id || 0;
    if (bookId <= 0) throw new Error(recognized.data.message || 'book recognize failed');
    const details: string[] = [];
    if (major.trim()) details.push(`适用专业：${major.trim()}`);
    if (campus.trim()) details.push(`面交校区：${campus.trim()}`);
    if (meetingPlace.trim()) details.push(`面交地点：${meetingPlace.trim()}`);
    if (note.trim()) details.push(note.trim());
    const listing: ListingRequest = { bookId, price, condition, note: details.join('\n'), images,
      contact: contactType.trim() ? `${contactType.trim()}：${contact.trim()}` : contact.trim(), ocrRaw: '' };
    const result = await HttpRequest.postRawJson<Response<SecondhandListing>>('https://lyzyy.love:8081/api/v1/secondhand/listings', JSON.stringify(listing), headers);
    if (result.data.code !== undefined && result.data.code !== 0 && result.data.code !== 200) throw new Error(result.data.message || 'publish failed');
  }
}
