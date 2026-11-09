import { AppStorage } from './AppStorage';
import { LibraryApi, LibraryFavoriteEntry } from '../net/LibraryApi';

/** 图书馆模块里可以被收藏的条目（公告/活动/资源）。 */
export interface LibraryFavorite {
  kind: string;   // article | resource
  id: number;
  title: string;
  link: string;
  tag: string;
}

const STORAGE_PREFIX = 'libraryFavorites';

function toEntry(item: LibraryFavorite): LibraryFavoriteEntry {
  return { kind: item.kind, itemId: item.id, title: item.title, link: item.link, tag: item.tag };
}

function toFavorite(entry: LibraryFavoriteEntry): LibraryFavorite {
  return {
    kind: entry.kind || '',
    id: entry.itemId || 0,
    title: entry.title || '',
    link: entry.link || '',
    tag: entry.tag || '',
  };
}

/**
 * 图书馆收藏：服务端（/api/v1/library/favorites）为准，本机 preferences 作为离线缓存。
 *
 * - 收藏/取消收藏先改本机，再尝试同步服务端；同步失败进待同步队列，下次进页面时重试。
 * - 本机缓存按学号隔离，切换账号不会看到别人的收藏。
 * - 未登录时只写本机，登录后首次进入「我的收藏」会把本机条目推到服务端并拉取云端列表。
 *
 * 读取与写入都要经过同一个就绪 Promise 和写入队列：之前 ensureLoaded() 先把 loaded
 * 置 true 再 await 读取，页面刚打开就点收藏时 items 还是空数组，写回会覆盖旧收藏。
 */
export class LibraryFavorites {
  private static instance: LibraryFavorites;
  private items: LibraryFavorite[] = [];
  private loaded: boolean = false;
  private loadPromise: Promise<void> | null = null;
  private writeChain: Promise<void> = Promise.resolve();
  private storageKey: string = STORAGE_PREFIX;
  private synced: boolean = false;
  private pendingAdds: LibraryFavorite[] = [];
  private pendingRemoves: LibraryFavorite[] = [];
  private lastToggleServerOk: boolean = true;

  static getInstance(): LibraryFavorites {
    if (!LibraryFavorites.instance) {
      LibraryFavorites.instance = new LibraryFavorites();
    }
    return LibraryFavorites.instance;
  }

  /** 是否已成功和服务端对齐（页面用来显示同步状态）。 */
  isSynced(): boolean {
    return this.synced;
  }

  /** 最近一次收藏/取消是否已同步到服务端（未登录或断网时为 false）。 */
  isLastToggleSynced(): boolean {
    return this.lastToggleServerOk;
  }

  private async ensureLoaded(): Promise<void> {
    if (this.loaded) return;
    if (!this.loadPromise) {
      this.loadPromise = this.loadFromStorage();
    }
    await this.loadPromise;
    this.loaded = true;
  }

  private async loadFromStorage(): Promise<void> {
    const storage = AppStorage.getInstance();
    const sid = (await storage.getStudentId()).trim();
    this.storageKey = sid ? `${STORAGE_PREFIX}_${sid}` : STORAGE_PREFIX;
    let raw = await storage.getSettingString(this.storageKey, '');
    if (!raw && sid) {
      // 旧版本未按学号隔离，迁移一次到当前账号。
      const legacy = await storage.getSettingString(STORAGE_PREFIX, '');
      if (legacy) {
        raw = legacy;
        await storage.setSettingString(this.storageKey, legacy);
      }
    }
    if (!raw) {
      this.items = [];
      return;
    }
    try {
      const parsed = JSON.parse(raw) as LibraryFavorite[];
      this.items = Array.isArray(parsed)
        ? parsed.filter((item: LibraryFavorite) => !!item && !!item.kind && (item.id || 0) > 0)
        : [];
    } catch {
      this.items = [];
    }
  }

  private keyOf(kind: string, id: number): string {
    return `${kind}-${id}`;
  }

  async list(): Promise<LibraryFavorite[]> {
    await this.ensureLoaded();
    return this.items.slice();
  }

  /** 收藏列表是同步缓存，列表页渲染时直接调用。 */
  has(kind: string, id: number): boolean {
    const key = this.keyOf(kind, id);
    return this.items.some((item: LibraryFavorite) => this.keyOf(item.kind, item.id) === key);
  }

  /** 切换收藏；返回切换后的状态（true=已收藏）。服务端同步失败时排队，不影响本机结果。 */
  async toggle(item: LibraryFavorite): Promise<boolean> {
    await this.ensureLoaded();
    // 连续点击时按顺序执行，后一次不会用旧快照覆盖前一次的结果。
    const run = this.writeChain.then(() => this.applyToggle(item));
    this.writeChain = run.then(() => {}, () => {});
    return run;
  }

  private async applyToggle(item: LibraryFavorite): Promise<boolean> {
    const key = this.keyOf(item.kind, item.id);
    const index = this.items.findIndex((value: LibraryFavorite) => this.keyOf(value.kind, value.id) === key);
    let favorited = false;
    if (index >= 0) {
      this.items.splice(index, 1);
      this.pendingAdds = this.pendingAdds.filter((value: LibraryFavorite) => this.keyOf(value.kind, value.id) !== key);
    } else {
      this.items.unshift(item);
      this.pendingRemoves = this.pendingRemoves.filter((value: LibraryFavorite) => this.keyOf(value.kind, value.id) !== key);
      favorited = true;
    }
    await this.persist();

    const ok = favorited
      ? await LibraryApi.addFavorite(toEntry(item))
      : await LibraryApi.removeFavorite(item.kind, item.id);
    if (ok) {
      this.synced = true;
    } else if (favorited) {
      this.pendingAdds.push(item);
    } else {
      this.pendingRemoves.push(item);
    }
    this.lastToggleServerOk = ok;
    return favorited;
  }

  /**
   * 与服务端对齐：先补发离线期间的增删，再拉取云端列表覆盖本机。
   * 返回是否同步成功；失败时保留本机数据（离线可用）。
   */
  async syncFromServer(): Promise<boolean> {
    await this.ensureLoaded();
    // 同步也进写入队列，避免和用户刚点的收藏互相覆盖。
    const run = this.writeChain.then(() => this.applySync());
    this.writeChain = run.then(() => {}, () => {});
    return run;
  }

  private async applySync(): Promise<boolean> {
    const flushed = await this.flushPending();
    if (!flushed) return false;
    const remote = await LibraryApi.listFavorites();
    if (remote === null) return false;
    this.items = remote
      .filter((entry: LibraryFavoriteEntry) => !!entry.kind && (entry.itemId || 0) > 0)
      .map((entry: LibraryFavoriteEntry) => toFavorite(entry));
    await this.persist();
    this.synced = true;
    return true;
  }

  private async flushPending(): Promise<boolean> {
    const adds = this.pendingAdds.slice();
    for (const item of adds) {
      if (await LibraryApi.addFavorite(toEntry(item))) {
        this.pendingAdds = this.pendingAdds.filter((value: LibraryFavorite) =>
          this.keyOf(value.kind, value.id) !== this.keyOf(item.kind, item.id));
      }
    }
    const removes = this.pendingRemoves.slice();
    for (const item of removes) {
      if (await LibraryApi.removeFavorite(item.kind, item.id)) {
        this.pendingRemoves = this.pendingRemoves.filter((value: LibraryFavorite) =>
          this.keyOf(value.kind, value.id) !== this.keyOf(item.kind, item.id));
      }
    }
    return this.pendingAdds.length === 0 && this.pendingRemoves.length === 0;
  }

  private async persist(): Promise<void> {
    await AppStorage.getInstance().setSettingString(this.storageKey, JSON.stringify(this.items));
  }
}
