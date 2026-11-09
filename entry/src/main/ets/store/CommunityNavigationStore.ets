/**
 * 校园社区页面间的轻量返回状态。
 *
 * 详情页删除帖子后记录对应 id，列表页返回时只移除这一项；
 * 详情页里做过修改（采纳答案/回复/表态）的帖子记录「已更新」，
 * 列表页返回时单独拉取这一条并原地替换，既保住分页数据和滚动位置，
 * 又不会让列表停留在这条帖子的旧状态上。
 *
 * 这些状态挂在单例上而不是页面字段里：返回时页面实例被重建也不会丢。
 */
export class CommunityNavigationStore {
  private static instance: CommunityNavigationStore;

  private deletedCampusPostIds: number[] = [];
  private deletedCatPostIds: number[] = [];
  private deletedSecondhandIds: number[] = [];
  private updatedCampusPostIds: number[] = [];
  private updatedCatPostIds: number[] = [];
  private returnPageKeys: string[] = [];
  private returnOffsets: number[] = [];

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

  /** 详情页里采纳答案、发表回复、表态等会改变列表展示状态的操作用这个标记。 */
  markCampusPostUpdated(id: number): void { this.remember(this.updatedCampusPostIds, id); }
  markCatPostUpdated(id: number): void { this.remember(this.updatedCatPostIds, id); }

  consumeDeletedCampusPostIds(): number[] {
    const ids = this.deletedCampusPostIds.slice();
    this.deletedCampusPostIds = [];
    return ids;
  }

  consumeDeletedCatPostIds(): number[] {
    const ids = this.deletedCatPostIds.slice();
    this.deletedCatPostIds = [];
    return ids;
  }

  consumeDeletedSecondhandIds(): number[] {
    const ids = this.deletedSecondhandIds.slice();
    this.deletedSecondhandIds = [];
    return ids;
  }

  consumeUpdatedCampusPostIds(): number[] {
    const ids = this.updatedCampusPostIds.slice();
    this.updatedCampusPostIds = [];
    return ids;
  }

  consumeUpdatedCatPostIds(): number[] {
    const ids = this.updatedCatPostIds.slice();
    this.updatedCatPostIds = [];
    return ids;
  }

  rememberListReturn(pageKey: string, offset: number): void {
    const index = this.returnPageKeys.indexOf(pageKey);
    if (index >= 0) {
      this.returnOffsets[index] = Math.max(0, offset);
      return;
    }
    this.returnPageKeys.push(pageKey);
    this.returnOffsets.push(Math.max(0, offset));
  }

  consumeListReturnOffset(pageKey: string): number {
    const index = this.returnPageKeys.indexOf(pageKey);
    if (index < 0) return -1;
    const offset = this.returnOffsets[index];
    this.returnPageKeys.splice(index, 1);
    this.returnOffsets.splice(index, 1);
    return offset;
  }
}
