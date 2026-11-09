/**
 * 校园社区页面间的轻量返回状态。
 *
 * 详情页删除帖子后记录对应 id，列表页返回时只移除这一项，避免为了刷新
 * 整个列表而丢失分页数据和滚动位置。
 */
export class CommunityNavigationStore {
  private static instance: CommunityNavigationStore;

  private deletedCampusPostIds: number[] = [];
  private deletedCatPostIds: number[] = [];
  private deletedSecondhandIds: number[] = [];

  static getInstance(): CommunityNavigationStore {
    if (!CommunityNavigationStore.instance) {
      CommunityNavigationStore.instance = new CommunityNavigationStore();
    }
    return CommunityNavigationStore.instance;
  }

  private remember(ids: number[], id: number): void {
    if (id > 0 && ids.indexOf(id) < 0) ids.push(id);
  }

  markCampusPostDeleted(id: number): void { this.remember(this.deletedCampusPostIds, id); }
  markCatPostDeleted(id: number): void { this.remember(this.deletedCatPostIds, id); }
  markSecondhandDeleted(id: number): void { this.remember(this.deletedSecondhandIds, id); }

  isCampusPostDeleted(id: number): boolean { return id > 0 && this.deletedCampusPostIds.indexOf(id) >= 0; }
  isCatPostDeleted(id: number): boolean { return id > 0 && this.deletedCatPostIds.indexOf(id) >= 0; }
  isSecondhandDeleted(id: number): boolean { return id > 0 && this.deletedSecondhandIds.indexOf(id) >= 0; }
}
