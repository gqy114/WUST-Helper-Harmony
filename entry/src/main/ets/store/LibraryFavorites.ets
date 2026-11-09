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
const MIGRATION_OWNER_KEY = 'libraryFavoritesMigrationOwner';

function toEntry(item: LibraryFavorite): LibraryFavoriteEntry {
  return { kind: item.kind, itemId: item.id, title: item.title, link: item.link, tag: item.tag };
}

function toFavorite(entry: LibraryFavoriteEntry): LibraryFavorite {
  const result: LibraryFavorite = {
    kind: entry.kind || '',
    id: entry.itemId || 0,
    title: entry.title || '',
    link: entry.link || '',
    tag: entry.tag || '',
  };
  return result;
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

function sameFavorite(left: LibraryFavorite, right: LibraryFavorite): boolean {
  return left.kind === right.kind && left.id === right.id;
}

/**
 * 图书馆收藏：服务端（/api/v1/library/favorites）为准，本机 preferences 作为离线缓存。
 *
 * - 收藏/取消收藏先改本机，再尝试同步服务端；失败进待同步队列（持久化），重启后继续补发。
 * - 本机缓存与待同步队列都按学号隔离；切换账号会重新加载，不会看到上一个账号的收藏。
 * - 旧版本的全局 libraryFavorites 只认领给第一个登录的账号，避免被后续账号重复继承。
 * - 账号首次同步时，本地已有收藏会先补传再拉取，云端空列表不会把旧收藏清掉。
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
  // 账号切换时递增；异步任务发现代次变化就放弃写入，避免旧账号数据污染新账号。
  private accountEpoch: number = 0;

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

  private syncedKey(): string {
    return `${this.storageKey}_synced`;
  }

  private pendingKey(): string {
    return `${this.storageKey}_pending`;
  }

  /**
   * 按当前登录学号确保数据已加载。
   * 学号变化（切换账号）时必须丢弃上一个账号的内存数据并从新账号的 key 重新读取。
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
    this.accountEpoch = this.accountEpoch + 1;
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
      // 旧版本的全局缓存没有归属：只让第一个登录的账号认领一次，
      // 否则换一个没有收藏的账号会再次继承同一份旧收藏。
      const owner = await storage.getSettingString(MIGRATION_OWNER_KEY, '');
      if (!owner) {
        const legacy = await storage.getSettingString(STORAGE_PREFIX, '');
        if (legacy) {
          raw = legacy;
          await storage.setSettingString(this.storageKey, legacy);
        }
        await storage.setSettingString(MIGRATION_OWNER_KEY, sid);
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

    // 该账号从未成功同步过：本地收藏（含从旧版本迁移来的）要先补传，
    // 否则首次拉取空的云端列表会把它们覆盖掉。
    const everSynced = await storage.getSettingBool(this.syncedKey(), false);
    if (!everSynced) {
      for (const item of normalized) {
        if (!adds.some((value: LibraryFavorite) => sameFavorite(value, item))) {
          adds.push(item);
        }
      }
    }

    // 读取期间可能已经切换了账号：旧结果直接丢弃。
    const stillSid = (await storage.getStudentId()).trim();
    if (sid !== stillSid) return;
    this.items = normalized;
    this.pendingAdds = adds.filter((value: LibraryFavorite) =>
      !removes.some((removed: LibraryFavorite) => sameFavorite(removed, value)));
    this.pendingRemoves = removes;
    if (!everSynced && this.pendingAdds.length > 0) {
      // 首次同步前就落盘待补发队列，避免进程被杀后旧收藏再也没机会上传。
      await this.persistPendingWithKey(this.storageKey);
    }
  }

  /** 异步等待之后确认账号没变：既看代次，也直接比较当前学号。 */
  private async sameAccount(epoch: number): Promise<boolean> {
    if (this.accountEpoch !== epoch) return false;
    const sid = (await AppStorage.getInstance().getStudentId()).trim();
    return sid === this.loadedSid;
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
    // 队列里的任务可能排到账号切换之后才执行，这里按最新账号再确认一次。
    await this.ensureLoaded();
    const epoch = this.accountEpoch;
    const storageKey = this.storageKey;
    const key = this.keyOf(item.kind, item.id);
    const index = this.items.findIndex((value: LibraryFavorite) => this.keyOf(value.kind, value.id) === key);
    // 这条收藏如果一直没同步成功（还在待补发队列里），取消时只需撤掉补发，
    // 不需要再排一个删除请求。
    const neverSynced = this.pendingAdds.some((value: LibraryFavorite) =>
      this.keyOf(value.kind, value.id) === key);
    let favorited = false;
    if (index >= 0) {
      this.items.splice(index, 1);
      this.pendingAdds = this.pendingAdds.filter((value: LibraryFavorite) => this.keyOf(value.kind, value.id) !== key);
    } else {
      this.items.unshift(item);
      this.pendingRemoves = this.pendingRemoves.filter((value: LibraryFavorite) => this.keyOf(value.kind, value.id) !== key);
      favorited = true;
    }
    await this.persistWithKey(storageKey);

    const ok = favorited
      ? await LibraryApi.addFavorite(toEntry(item))
      : await LibraryApi.removeFavorite(item.kind, item.id);
    if (!await this.sameAccount(epoch)) return favorited;
    if (ok) {
      this.synced = true;
    } else if (favorited) {
      this.pendingAdds.push(item);
    } else if (!neverSynced) {
      this.pendingRemoves.push(item);
    }
    this.lastToggleServerOk = ok;
    // 离线操作也要落盘：重启后仍然知道还有哪些改动没同步。
    await this.persistPendingWithKey(storageKey);
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
    await this.ensureLoaded();
    const epoch = this.accountEpoch;
    const storageKey = this.storageKey;
    const flushed = await this.flushPending();
    if (!await this.sameAccount(epoch)) return false;
    if (!flushed) return false;
    const remote = await LibraryApi.listFavorites();
    if (!await this.sameAccount(epoch)) return false;
    if (remote === null) return false;
    this.items = remote
      .filter((entry: LibraryFavoriteEntry) => !!entry.kind && (entry.itemId || 0) > 0)
      .map((entry: LibraryFavoriteEntry) => toFavorite(entry));
    await this.persistWithKey(storageKey);
    await this.persistPendingWithKey(storageKey);
    await AppStorage.getInstance().setSettingBool(`${storageKey}_synced`, true);
    this.synced = true;
    return true;
  }

  private async flushPending(): Promise<boolean> {
    await this.ensureLoaded();
    // 补发过程中可能切换账号：每次发送前、每个请求返回后都要核对，
    // 否则 A 剩下的收藏会带着 B 的登录态发到 B 的账号上。
    const epoch = this.accountEpoch;
    const storageKey = this.storageKey;
    const adds = this.pendingAdds.slice();
    for (const item of adds) {
      if (!await this.sameAccount(epoch)) return false;
      const ok = await LibraryApi.addFavorite(toEntry(item));
      if (!await this.sameAccount(epoch)) return false;
      if (ok) {
        this.pendingAdds = this.pendingAdds.filter((value: LibraryFavorite) =>
          this.keyOf(value.kind, value.id) !== this.keyOf(item.kind, item.id));
        await this.persistPendingWithKey(storageKey);
      }
    }
    const removes = this.pendingRemoves.slice();
    for (const item of removes) {
      if (!await this.sameAccount(epoch)) return false;
      const ok = await LibraryApi.removeFavorite(item.kind, item.id);
      if (!await this.sameAccount(epoch)) return false;
      if (ok) {
        this.pendingRemoves = this.pendingRemoves.filter((value: LibraryFavorite) =>
          this.keyOf(value.kind, value.id) !== this.keyOf(item.kind, item.id));
        await this.persistPendingWithKey(storageKey);
      }
    }
    return this.pendingAdds.length === 0 && this.pendingRemoves.length === 0;
  }

  private async persistWithKey(storageKey: string): Promise<void> {
    await AppStorage.getInstance().setSettingString(storageKey, JSON.stringify(this.items));
  }

  private async persistPendingWithKey(storageKey: string): Promise<void> {
    const storage = AppStorage.getInstance();
    const pendingKey = `${storageKey}_pending`;
    if (this.pendingAdds.length === 0 && this.pendingRemoves.length === 0) {
      await storage.setSettingString(pendingKey, '');
      return;
    }
    const payload: PendingFavorites = { adds: this.pendingAdds, removes: this.pendingRemoves };
    await storage.setSettingString(pendingKey, JSON.stringify(payload));
  }
}
