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

interface PendingFavorites {
  adds: LibraryFavorite[];
  removes: LibraryFavorite[];
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

function validFavorite(item: LibraryFavorite): boolean {
  return !!item && !!item.kind && (item.id || 0) > 0;
}

function normalizeFavorite(item: LibraryFavorite): LibraryFavorite {
  const result: LibraryFavorite = {
    kind: item.kind,
    id: item.id,
    title: item.title || '',
    link: item.link || '',
    tag: item.tag || '',
  };
  return result;
}

/**
 * 图书馆收藏：服务端（/api/v1/library/favorites）为准，本机 preferences 作为离线缓存。
 *
 * - 收藏/取消收藏先改本机，再尝试同步服务端；失败进待同步队列（持久化），重启后继续补发。
 * - 本机缓存与待同步队列都按学号隔离，切换账号会重新加载，不会看到上一个账号的收藏。
 * - 未登录时只写本机，登录后首次进入「我的收藏」会把本机条目推到服务端并拉取云端列表。
 *
 * 读取与写入都要经过同一个就绪 Promise 和写入队列：之前 ensureLoaded() 先把 loaded
 * 置 true 再 await 读取，页面刚打开就点收藏时 items 还是空数组，写回会覆盖旧收藏。
 */
export class LibraryFavorites {
  private static instance: LibraryFavorites;
  private items: LibraryFavorite[] = [];
  private loaded: boolean = false;
  private loadedSid: string = '';
  private loadPromise: Promise<void> | null = null;
  private loadSid: string = '';
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

  private pendingKey(): string {
    return `${this.storageKey}_pending`;
  }

  /**
   * 按当前登录学号确保数据已加载。
   * 学号变化（切换账号）时必须丢弃上一个账号的内存数据并从新账号的 key 重新读取，
   * 否则收藏页会显示上一个账号的收藏，甚至把它的收藏同步到新账号。
   */
  private async ensureLoaded(): Promise<void> {
    const sid = (await AppStorage.getInstance().getStudentId()).trim();
    if (this.loaded && sid === this.loadedSid) return;
    if (sid !== this.loadedSid) {
      this.resetForAccount();
    }
    if (!this.loadPromise) {
      this.loadSid = sid;
      this.loadPromise = this.loadFromStorage(sid);
    }
    await this.loadPromise;
    this.loaded = true;
    this.loadedSid = this.loadSid;
  }

  private resetForAccount(): void {
    this.items = [];
    this.pendingAdds = [];
    this.pendingRemoves = [];
    this.synced = false;
    this.lastToggleServerOk = true;
    this.loaded = false;
    this.loadedSid = '';
    this.loadPromise = null;
    this.loadSid = '';
  }

  private async loadFromStorage(sid: string): Promise<void> {
    const storage = AppStorage.getInstance();
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
    let items: LibraryFavorite[] = [];
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as LibraryFavorite[];
        items = Array.isArray(parsed) ? parsed.filter(validFavorite) : [];
      } catch {
        items = [];
      }
    }

    let normalized: LibraryFavorite[] = [];
    if (items.length > 0) {
      normalized = items.map(normalizeFavorite);
    }

    const rawPending = await storage.getSettingString(this.pendingKey(), '');
    let adds: LibraryFavorite[] = [];
    let removes: LibraryFavorite[] = [];
    if (rawPending) {
      try {
        const parsed = JSON.parse(rawPending) as PendingFavorites;
        adds = Array.isArray(parsed.adds) ? parsed.adds.filter(validFavorite) : [];
        removes = Array.isArray(parsed.removes) ? parsed.removes.filter(validFavorite) : [];
      } catch {
        adds = [];
        removes = [];
      }
    }

    // 读取期间可能已经切换了账号：旧结果直接丢弃。
    if (sid !== (await AppStorage.getInstance().getStudentId()).trim()) return;
    this.items = normalized;
    this.pendingAdds = adds;
    this.pendingRemoves = removes;
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
    // 离线操作也要落盘：重启后仍然知道还有哪些改动没同步。
    await this.persistPending();
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
    await this.persistPending();
    this.synced = true;
    return true;
  }

  private async flushPending(): Promise<boolean> {
    const adds = this.pendingAdds.slice();
    for (const item of adds) {
      if (await LibraryApi.addFavorite(toEntry(item))) {
        this.pendingAdds = this.pendingAdds.filter((value: LibraryFavorite) =>
          this.keyOf(value.kind, value.id) !== this.keyOf(item.kind, item.id));
        await this.persistPending();
      }
    }
    const removes = this.pendingRemoves.slice();
    for (const item of removes) {
      if (await LibraryApi.removeFavorite(item.kind, item.id)) {
        this.pendingRemoves = this.pendingRemoves.filter((value: LibraryFavorite) =>
          this.keyOf(value.kind, value.id) !== this.keyOf(item.kind, item.id));
        await this.persistPending();
      }
    }
    return this.pendingAdds.length === 0 && this.pendingRemoves.length === 0;
  }

  private async persist(): Promise<void> {
    await AppStorage.getInstance().setSettingString(this.storageKey, JSON.stringify(this.items));
  }

  private async persistPending(): Promise<void> {
    const storage = AppStorage.getInstance();
    if (this.pendingAdds.length === 0 && this.pendingRemoves.length === 0) {
      await storage.setSettingString(this.pendingKey(), '');
      return;
    }
    const payload: PendingFavorites = { adds: this.pendingAdds, removes: this.pendingRemoves };
    await storage.setSettingString(this.pendingKey(), JSON.stringify(payload));
  }
}
