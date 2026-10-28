import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
import { CampusWallApi, CampusWallPost, CampusWallReply, decodeHtmlEntities } from './CampusWallApi';
export interface SecondhandReply { id?: number; studentId?: string; displayName?: string; realName?: string; avatarUrl?: string; college?: string; major?: string; content?: string; createdAt?: string | number; redFlowers?: number; }
export interface SecondhandListing { id?: number; bookId?: number; sellerId?: string; price?: number; condition?: string; note?: string; images?: string[]; contact?: string; status?: string; createdAt?: number | string; bookTitle?: string; bookAuthor?: string; bookPublisher?: string; bookEdition?: string; bookIsbn?: string; bookCover?: string; campus?: string; campusName?: string; major?: string; sellerName?: string; displayName?: string; realName?: string; sellerAvatar?: string; avatarUrl?: string; college?: string; redFlowers?: number; replies?: SecondhandReply[]; source?: string; communityPostId?: number; }
export interface SecondhandBook { id?: number; isbn?: string; title?: string; author?: string; publisher?: string; edition?: string; category?: string; coverUrl?: string; listingCount?: number; priceMin?: number; priceMax?: number; priceAvg?: number; }
export interface SecondhandDetail { book?: SecondhandBook; listing?: SecondhandListing; replies?: SecondhandReply[]; }
interface Response<T> { data?: T; code?: number; message?: string; }
interface Headers extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
interface RecognizeRequest { isbn: string; title: string; author: string; publisher: string; edition: string; category: string; coverUrl: string; listPrice: number; ocrRaw: string; source: string; }
interface RecognizeData { book?: SecondhandBook; }
interface ListingRequest { bookId: number; price: number; condition: string; note: string; images: string[]; contact: string; ocrRaw: string; }
interface MajorItem { name?: string; label?: string; value?: string; title?: string; major?: string; majorName?: string; }
type MajorValue = string | MajorItem;
interface MajorPage { items?: MajorValue[]; list?: MajorValue[]; majors?: MajorValue[]; records?: MajorValue[]; data?: MajorValue[]; }
interface BookDetailData { book?: SecondhandBook; listings?: SecondhandListing[]; listing?: SecondhandListing; replies?: SecondhandReply[]; }
interface BookTradeExtra {
  price?: number | string; condition?: string; campus?: string; campusName?: string; major?: string;
  majors?: string[] | string; meetingPlace?: string; address?: string; contact?: string; contactType?: string;
  author?: string; publisher?: string; edition?: string; isbn?: string; note?: string; bookTitle?: string; title?: string;
  book_author?: string; book_publisher?: string; book_edition?: string; book_isbn?: string;
  salePrice?: number | string; sale_price?: number | string; bookCondition?: string; book_condition?: string;
  applicableMajors?: string[] | string; applicable_majors?: string[] | string;
  tradeCampus?: string; trade_campus?: string; tradePlace?: string; trade_place?: string;
  contactValue?: string; contact_value?: string; contact_type?: string;
  sellingPrice?: number | string; selling_price?: number | string; priceYuan?: number | string; price_yuan?: number | string;
  amount?: number | string; bookPublisher?: string; bookEdition?: string; bookIsbn?: string;
  publisherName?: string; editionInfo?: string; isbn13?: string; description?: string;
  tradeLocation?: string; trade_location?: string; contactMethod?: string; contact_method?: string;
  contactAccount?: string; contact_account?: string;
  sellPrice?: number | string; sell_price?: number | string; bookPrice?: number | string; book_price?: number | string;
  bookMajors?: string[] | string; book_majors?: string[] | string; bookCampus?: string; book_campus?: string;
  bookLocation?: string; book_location?: string; bookContact?: string; book_contact?: string;
  bookContactType?: string; book_contact_type?: string;
}
export class SecondHandBookApi {
  private static async headers(): Promise<Headers> { const token = await AppStorage.getInstance().getAppAuthAccessToken(); return { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' }; }
  static async feed(keyword: string = '', category: string = '', major: string = ''): Promise<SecondhandListing[]> { const query = `?page=1&limit=50&keyword=${encodeURIComponent(keyword)}&category=${encodeURIComponent(category)}${major.length > 0 ? `&major=${encodeURIComponent(major)}` : ''}`; const response = await HttpRequest.get<Response<SecondhandListing[]>>(`https://lyzyy.love:8081/api/v1/secondhand/listings${query}`, await SecondHandBookApi.headers()); const data = response.data.data; return Array.isArray(data) ? data.map((item: SecondhandListing) => SecondHandBookApi.normalizeListing(item)) : []; }
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

  static conditionLabel(value?: string): string {
    const condition = (value || '').trim().toLowerCase();
    if (condition === 'new' || condition === 'brand_new') return '全新';
    if (condition === 'like_new' || condition === '90_new') return '九成新';
    if (condition === 'good' || condition === '80_new') return '八成新';
    if (condition === 'fair' || condition === 'other') return '其他';
    return SecondHandBookApi.decoded(value);
  }

  static normalizeListing(item: SecondhandListing): SecondhandListing {
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
    const majorValue = extra.majors || extra.bookMajors || extra.book_majors || extra.applicableMajors || extra.applicable_majors || extra.major || '';
    const majors = Array.isArray(majorValue) ? majorValue.join('、') : majorValue;
    const details: string[] = [];
    if (majors) details.push(`适用专业：${majors}`);
    const campus = extra.campusName || extra.campus || extra.bookCampus || extra.book_campus || extra.tradeCampus || extra.trade_campus || '';
    if (campus) details.push(`面交校区：${campus}`);
    const place = extra.meetingPlace || extra.bookLocation || extra.book_location || extra.tradePlace || extra.trade_place || extra.tradeLocation || extra.trade_location || extra.address || '';
    if (place) details.push(`面交地点：${place}`);
    const author = extra.author || extra.book_author || '';
    const publisher = extra.publisher || extra.bookPublisher || extra.book_publisher || extra.publisherName || '';
    const edition = extra.edition || extra.bookEdition || extra.book_edition || extra.editionInfo || '';
    const isbn = extra.isbn || extra.bookIsbn || extra.book_isbn || extra.isbn13 || '';
    if (author) details.push(`作者：${author}`);
    if (publisher) details.push(`出版社：${publisher}`);
    if (edition) details.push(`版次：${edition}`);
    if (isbn) details.push(`ISBN：${isbn}`);
    if (extra.note || extra.description) details.push(extra.note || extra.description || '');
    if (post.content) details.push(post.content);
    const replies: SecondhandReply[] = (post.replies || []).map((reply: CampusWallReply): SecondhandReply => ({
      id: reply.id, studentId: reply.studentId, displayName: reply.displayName, realName: reply.realName,
      avatarUrl: reply.avatarUrl, college: reply.college, major: reply.major, content: SecondHandBookApi.decoded(reply.content),
      createdAt: reply.createdAt, redFlowers: reply.redFlowers
    }));
    const contactValue = extra.contact || extra.bookContact || extra.book_contact || extra.contactValue || extra.contact_value || extra.contactAccount || extra.contact_account || '';
    const contactType = extra.contactType || extra.bookContactType || extra.book_contact_type || extra.contact_type || extra.contactMethod || extra.contact_method || '';
    const contact = contactType && contactValue ? `${contactType}：${contactValue}` : contactValue;
    return SecondHandBookApi.normalizeListing({ id: post.id, communityPostId: post.id, source: 'community', sellerId: post.studentId,
      price: SecondHandBookApi.numberValue(extra.price || extra.bookPrice || extra.book_price || extra.sellPrice || extra.sell_price || extra.salePrice || extra.sale_price || extra.sellingPrice || extra.selling_price || extra.priceYuan || extra.price_yuan || extra.amount),
      condition: extra.condition || extra.bookCondition || extra.book_condition || '', note: details.join('\n'),
      images: post.images || [], contact, createdAt: post.createdAt, bookTitle: extra.bookTitle || extra.title || post.title,
      bookAuthor: author, bookPublisher: publisher, bookEdition: edition, bookIsbn: isbn,
      bookCover: (post.images || [])[0] || '', campus, campusName: campus, major: majors,
      sellerName: post.displayName || post.realName, displayName: post.displayName, realName: post.realName,
      sellerAvatar: post.avatarUrl, avatarUrl: post.avatarUrl, college: post.college, redFlowers: post.redFlowers, replies });
  }

  static async communityFeed(): Promise<SecondhandListing[]> {
    const tags: string[] = ['book_trade', 'book-trade', 'book', 'secondhand', 'second_hand_book'];
    const result: SecondhandListing[] = [];
    const seen: Set<number> = new Set<number>();
    for (const tag of tags) {
      try {
        const posts = await CampusWallApi.listPages(tag, 3);
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
  static async detail(listing: SecondhandListing): Promise<SecondhandDetail> {
    const headers = await SecondHandBookApi.headers();
    let current: SecondhandListing = listing;
    let replies: SecondhandReply[] = listing.replies || [];
    let book: SecondhandBook | undefined = undefined;
    if ((listing.bookId || 0) > 0) {
      try {
        const response = await HttpRequest.get<Response<BookDetailData>>(
          `https://lyzyy.love:8081/api/v1/secondhand/books/${listing.bookId}`, headers);
        const data = response.data.data;
        book = data?.book;
        const matched = (data?.listings || []).find((item: SecondhandListing) => item.id === listing.id);
        if (matched) current = matched;
      } catch {}
    }
    if ((listing.id || 0) > 0) {
      try {
        const response = await HttpRequest.get<Response<SecondhandReply[]>>(
          `https://lyzyy.love:8081/api/v1/secondhand/listings/${listing.id}/replies`, headers);
        replies = Array.isArray(response.data.data) ? response.data.data : replies;
      } catch {}
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
    const code = response.data.code;
    if (code !== undefined && code !== 0 && code !== 200) throw new Error(response.data.message || 'reply failed');
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
