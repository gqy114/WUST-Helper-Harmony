import { AppStorage } from './AppStorage';

/** 图书馆模块里可以被收藏的条目（公告/活动/资源）。 */
export interface LibraryFavorite {
  kind: string;   // article | resource
  id: number;
  title: string;
  link: string;
  tag: string;
}

const STORAGE_KEY = 'libraryFavorites';

/**
 * 图书馆收藏：后端没有收藏接口，这里按「本机收藏」实现，
 * 条目存在 preferences 的 libraryFavorites 里，随 AppStorage 一起持久化。
 *
 * 读取与写入都要经过同一个就绪 Promise 和写入队列：
 * 之前 ensureLoaded() 先把 loaded 置 true 再 await 读取，
 * 页面刚打开就点收藏时 items 还是空数组，写回会把旧收藏覆盖掉。
 */
export class LibraryFavorites {
  private static instance: LibraryFavorites;
  private items: LibraryFavorite[] = [];
  private loaded: boolean = false;
  private loadPromise: Promise<void> | null = null;
  private writeChain: Promise<void> = Promise.resolve();

  static getInstance(): LibraryFavorites {
    if (!LibraryFavorites.instance) {
      LibraryFavorites.instance = new LibraryFavorites();
    }
    return LibraryFavorites.instance;
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
    const raw = await AppStorage.getInstance().getSettingString(STORAGE_KEY, '[]');
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

  /** 切换收藏；返回切换后的状态（true=已收藏）。 */
  async toggle(item: LibraryFavorite): Promise<boolean> {
    await this.ensureLoaded();
    // 连续点击时按顺序落盘，后一次写入不会用旧快照覆盖前一次的结果。
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
    } else {
      this.items.unshift(item);
      favorited = true;
    }
    await this.persist();
    return favorited;
  }

  private async persist(): Promise<void> {
    await AppStorage.getInstance().setSettingString(STORAGE_KEY, JSON.stringify(this.items));
  }
}
