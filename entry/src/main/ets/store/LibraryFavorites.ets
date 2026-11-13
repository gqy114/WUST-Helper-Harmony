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
  // 串行化加载：页面刚打开时 list() 与用户点击触发的 toggle() 不能各读一份再互相覆盖。
  private loadChain: Promise<void> = Promise.resolve();
  // 串行化写操作：连续快速收藏时按顺序落盘，避免后一次写入覆盖前一次。
  private writeChain: Promise<void> = Promise.resolve();
  // 旧数据只迁移一次，避免切换账号时把上一个账号的收藏带给新账号。
  private static readonly MIGRATION_FLAG = 'libraryFavoritesMigrationDone';

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

  private async loadFor(sid: string): Promise<void> {
    const storage = AppStorage.getInstance();
    const key = this.storageKey(sid);
    let raw = await storage.getSettingString(key, '');
    const migrated = await storage.getSettingBool(LibraryFavorites.MIGRATION_FLAG, false);
    // 未登录时直接用旧版全局 key，不能清空它，否则游客收藏会在下次启动时丢失。
    if (!migrated && sid) {
      // 旧版本不区分账号，收藏存在 libraryFavorites；只迁移给升级后第一个登录的账号。
      const legacy = await storage.getSettingString(LEGACY_STORAGE_KEY, '');
      if (!raw && legacy && legacy !== '[]') {
        raw = legacy;
        await storage.setSettingString(key, legacy);
      }
      await storage.setSettingString(LEGACY_STORAGE_KEY, '[]');
      await storage.setSettingBool(LibraryFavorites.MIGRATION_FLAG, true);
    }
    this.items = this.parse(raw);
    this.loadedSid = sid;
    this.loaded = true;
  }

  /** 账号变化时重新读取；并发调用共享同一次加载。 */
  private async ensureLoaded(): Promise<void> {
    const storage = AppStorage.getInstance();
    const wanted = (await storage.getStudentId()).trim();
    if (this.loaded && wanted === this.loadedSid) return;
    const run = this.loadChain.then(async (): Promise<void> => {
      const sid = (await storage.getStudentId()).trim();
      if (this.loaded && sid === this.loadedSid) return;
      await this.loadFor(sid);
    });
    this.loadChain = run.catch((): void => undefined);
    await run;
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

  /** 切换收藏；返回切换后的状态（true=已收藏）。只写入本机，写操作排队避免并发丢数据。 */
  async toggle(item: LibraryFavorite): Promise<boolean> {
    const run = this.writeChain.then((): Promise<boolean> => this.applyToggle(item));
    this.writeChain = run.then((): void => undefined, (): void => undefined);
    return run;
  }

  private async applyToggle(item: LibraryFavorite): Promise<boolean> {
    // 记住发起修改的账号；如果加载期间切了账号，这次修改直接丢弃，绝不写到新账号。
    const sidAtCall = (await AppStorage.getInstance().getStudentId()).trim();
    await this.ensureLoaded();
    if (this.loadedSid !== sidAtCall) {
      console.warn('LibraryFavorites', 'account changed during toggle, drop write');
      return false;
    }
    const sid = this.loadedSid;
    const key = this.keyOf(item.kind, item.id);
    const next = this.items.slice();
    const index = next.findIndex((value: LibraryFavorite) => this.keyOf(value.kind, value.id) === key);
    let favorited = false;
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.unshift(item);
      favorited = true;
    }
    await AppStorage.getInstance().setSettingString(this.storageKey(sid), JSON.stringify(next));
    if (this.loadedSid === sid) {
      this.items = next;
    }
    return favorited;
  }
}
