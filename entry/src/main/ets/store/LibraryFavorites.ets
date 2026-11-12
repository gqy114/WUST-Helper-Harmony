import { AppStorage } from './AppStorage';

/** 图书馆模块里可以被收藏的条目（公告/活动/资源）。 */
export interface LibraryFavorite {
  kind: string;   // article | resource
  id: number;
  title: string;
  link: string;
  tag: string;
}

const LEGACY_STORAGE_KEY = 'libraryFavorites';
const STORAGE_PREFIX = 'libraryFavorites_';

/**
 * 图书馆收藏：只保存在本机，不做云端同步。
 *
 * 产品约定：活动资讯、资源导航的“内容”从服务端获取，但“收藏了哪一条”
 * 只记录在当前设备上。换设备/重装后需要重新收藏。
 * 收藏按学号隔离，切换账号不会看到上一个账号的收藏。
 */
export class LibraryFavorites {
  private static instance: LibraryFavorites;
  private items: LibraryFavorite[] = [];
  private loaded: boolean = false;
  private loadedSid: string = '';

  static getInstance(): LibraryFavorites {
    if (!LibraryFavorites.instance) {
      LibraryFavorites.instance = new LibraryFavorites();
    }
    return LibraryFavorites.instance;
  }

  private storageKey(sid: string): string {
    return sid ? `${STORAGE_PREFIX}${sid}` : LEGACY_STORAGE_KEY;
  }

  private parse(raw: string): LibraryFavorite[] {
    try {
      const parsed = JSON.parse(raw) as LibraryFavorite[];
      if (!Array.isArray(parsed)) return [];
      return parsed.filter((item: LibraryFavorite) => !!item && !!item.kind && (item.id || 0) > 0);
    } catch {
      return [];
    }
  }

  /** 首次读取时把旧版本共用的全局收藏迁移给当前账号；账号变化时重新读取。 */
  private async ensureLoaded(): Promise<void> {
    const storage = AppStorage.getInstance();
    const sid = (await storage.getStudentId()).trim();
    if (this.loaded && sid === this.loadedSid) return;
    const key = this.storageKey(sid);
    let raw = await storage.getSettingString(key, '');
    if (!raw && sid) {
      // 旧版本不区分账号，收藏存在 libraryFavorites；迁移一次后清空，避免被多个账号重复认领。
      const legacy = await storage.getSettingString(LEGACY_STORAGE_KEY, '');
      if (legacy && legacy !== '[]') {
        raw = legacy;
        await storage.setSettingString(key, legacy);
        await storage.setSettingString(LEGACY_STORAGE_KEY, '[]');
      }
    }
    this.items = this.parse(raw);
    this.loadedSid = sid;
    this.loaded = true;
  }

  private keyOf(kind: string, id: number): string {
    return `${kind}-${id}`;
  }

  async list(): Promise<LibraryFavorite[]> {
    await this.ensureLoaded();
    return this.items.slice();
  }

  /** 收藏列表是同步缓存，列表页渲染时直接调用（需先 list() 完成加载）。 */
  has(kind: string, id: number): boolean {
    const key = this.keyOf(kind, id);
    return this.items.some((item: LibraryFavorite) => this.keyOf(item.kind, item.id) === key);
  }

  /** 切换收藏；返回切换后的状态（true=已收藏）。只写入本机。 */
  async toggle(item: LibraryFavorite): Promise<boolean> {
    await this.ensureLoaded();
    const key = this.keyOf(item.kind, item.id);
    const index = this.items.findIndex((value: LibraryFavorite) => this.keyOf(value.kind, value.id) === key);
    let favorited = false;
    if (index >= 0) {
      this.items.splice(index, 1);
    } else {
      this.items.unshift(item);
      favorited = true;
    }
    await this.persist();
    return favorited;
  }

  private async persist(): Promise<void> {
    const key = this.storageKey(this.loadedSid);
    await AppStorage.getInstance().setSettingString(key, JSON.stringify(this.items));
  }
}
