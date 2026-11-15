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
    return LibraryFavorites.parseItems(raw);
  }

  private static parseItems(raw: string): LibraryFavorite[] {
    try {
      const parsed = JSON.parse(raw) as LibraryFavorite[];
      if (!Array.isArray(parsed)) return [];
      return parsed.filter((item: LibraryFavorite) => !!item && !!item.kind && (item.id || 0) > 0);
    } catch {
      return [];
    }
  }

  /**
   * 迁移串行化：迁移过程中切账号时，后一个账号会排在迁移结束后再判断归属，
   * 不会出现两个账号同时认领同一份旧收藏。
   */
  private static migrateChain: Promise<void> = Promise.resolve();

  static migrateFor(sid: string): Promise<void> {
    const run = LibraryFavorites.migrateChain.then((): Promise<void> =>
      LibraryFavorites.migrateForInternal(sid));
    LibraryFavorites.migrateChain = run.then((): void => undefined, (): void => undefined);
    return run;
  }

  /**
   * 把旧版本全局收藏迁移给“该收藏的归属账号”。
   * 迁移只写空的本机收藏，避免覆盖用户新点的收藏；切回原账号时会再次触发。
   */
  private static async migrateForInternal(sid: string): Promise<void> {
    const account = (sid || '').trim();
    if (!account) return;
    const storage = AppStorage.getInstance();
    // 旧版本已经记录过收藏归属账号：只有本人登录才迁移，避免 A 的收藏转给 B。
    const ownerKey = 'libraryFavoritesMigrationOwner';
    const owner = (await storage.getSettingString(ownerKey, '')).trim();
    if (owner && owner !== account) {
      // 不是归属账号：不清旧数据、也不写全局迁移标记，等原账号切回来还能迁移。
      return;
    }
    if (owner === account) {
      const done = await storage.getSettingBool(LibraryFavorites.MIGRATION_FLAG, false);
      if (done) return;
    }
    if (!owner) {
      await storage.setSettingString(ownerKey, account);
    }
    const legacy = await storage.getSettingString(LEGACY_STORAGE_KEY, '');
    if (legacy && legacy !== '[]') {
      const key = `${STORAGE_PREFIX}${account}`;
      const existingRaw = await storage.getSettingString(key, '');
      const existing = LibraryFavorites.parseItems(existingRaw);
      const legacyItems = LibraryFavorites.parseItems(legacy);
      // 本机新收藏与旧收藏合并去重：既不丢旧记录，也不覆盖迁移期间新点的收藏。
      const merged: LibraryFavorite[] = existing.slice();
      for (let i = 0; i < legacyItems.length; i++) {
        const candidate = legacyItems[i];
        const duplicated = merged.some((item: LibraryFavorite) =>
          item.kind === candidate.kind && item.id === candidate.id);
        if (!duplicated) merged.push(candidate);
      }
      if (merged.length > 0) {
        await storage.setSettingString(key, JSON.stringify(merged));
      }
      await storage.setSettingString(LEGACY_STORAGE_KEY, '[]');
    }
    await storage.setSettingBool(LibraryFavorites.MIGRATION_FLAG, true);
  }

  /** 应用启动/进入收藏页时调用：按当前账号补一次迁移（切回原账号也能看到旧收藏）。 */
  static async migrateLegacyForCurrentAccount(): Promise<void> {
    const sid = (await AppStorage.getInstance().getStudentId()).trim();
    await LibraryFavorites.migrateFor(sid);
  }

  private async loadFor(sid: string): Promise<void> {
    const storage = AppStorage.getInstance();
    // 加载前补一次迁移：切回原账号时旧收藏立即出现。
    await LibraryFavorites.migrateFor(sid);
    const key = this.storageKey(sid);
    const raw = await storage.getSettingString(key, '');
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
    // 读取期间可能切账号：加载完成后再确认一次，发现变化就按新账号重新加载，避免闪出上一个账号的收藏。
    for (let attempt = 0; attempt < 3; attempt++) {
      await this.ensureLoaded();
      const current = (await AppStorage.getInstance().getStudentId()).trim();
      if (current === this.loadedSid) break;
    }
    return this.items.slice();
  }

  /** 收藏列表是同步缓存，列表页渲染时直接调用（需先 list() 完成加载）。 */
  has(kind: string, id: number): boolean {
    const key = this.keyOf(kind, id);
    return this.items.some((item: LibraryFavorite) => this.keyOf(item.kind, item.id) === key);
  }

  /** 切换收藏；返回切换后的状态（true=已收藏）。只写入本机，写操作排队避免并发丢数据。 */
  async toggle(item: LibraryFavorite): Promise<boolean> {
    // 在入队时就记下账号：排队期间即使切号，也不会把这次操作写到新账号。
    const sidAtCall = (await AppStorage.getInstance().getStudentId()).trim();
    const run = this.writeChain.then((): Promise<boolean> => this.applyToggle(item, sidAtCall));
    this.writeChain = run.then((): void => undefined, (): void => undefined);
    return run;
  }

  private async applyToggle(item: LibraryFavorite, sidAtCall: string): Promise<boolean> {
    await this.ensureLoaded();
    if (this.loadedSid !== sidAtCall) {
      console.warn('LibraryFavorites', 'account changed before toggle applied, drop write');
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
