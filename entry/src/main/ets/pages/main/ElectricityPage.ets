import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { ElectricityApi, YKTLocationItem, YKTSavedRoom } from '../../net/ElectricityApi';
import { AppStorage } from '../../store/AppStorage';

interface RoomBalance { id: string; name: string; type: string; remaining: string; unit: string; }

@Entry
@Component
struct ElectricityPage {
  @State private level: number = 0;
  @State private loading: boolean = false;
  @State private refreshing: boolean = false;
  @State private locations: YKTLocationItem[] = [];
  @State private selected: YKTLocationItem[] = [];
  @State private balances: RoomBalance[] = [];
  @State private showAdd: boolean = false;
  @State private locationEnd: boolean = false;
  private savedRooms: YKTSavedRoom[] = [];
  private roomAccount: string = '';
  private roomEpoch: number = -1;

  aboutToAppear(): void { this.loadSavedRooms(); }

  private async loadSavedRooms(): Promise<void> {
    this.loading = true;
    const storage = AppStorage.getInstance();
    this.roomEpoch = storage.getSessionEpoch();
    this.roomAccount = (await storage.getStudentId()).trim();
    if (!await this.isRoomSessionCurrent()) {
      this.loading = false;
      return;
    }
    const result: RoomBalance[] = [];
    try {
      let cloudRooms: YKTSavedRoom[] = [];
      try { cloudRooms = await ElectricityApi.savedRooms(); } catch { console.warn('ElectricityPage', 'cloud rooms unavailable'); }
      // 缓存读取期间重登时，存储层可能临时返回空值。等同账号的新会话稳定后再读。
      const readEpoch = storage.getSessionEpoch();
      let localRooms = await this.localSavedRooms();
      if (!await this.isRoomSessionCurrent()) return;
      if (readEpoch !== this.roomEpoch) localRooms = await this.localSavedRooms();
      const snapshotEpoch = this.roomEpoch;
      const rooms: YKTSavedRoom[] = cloudRooms.concat(localRooms.filter(local =>
        !cloudRooms.some(cloud => cloud.id === local.id)));
      this.savedRooms = rooms;
      for (let i = 0; i < rooms.length; i++) {
        const room: YKTSavedRoom = rooms[i];
        try {
          const balance = await ElectricityApi.electricity(room.id);
          if (!await this.isRoomSessionCurrent()) return;
          result.push({ id: room.id, name: room.name || '我的寝室', type: room.type || '', remaining: balance.remaining, unit: balance.unit });
          room.remaining = balance.remaining;
          room.unit = balance.unit;
        } catch { console.warn('ElectricityPage', `room query failed: ${room.id}`); }
      }
      // 后台读到空列表不代表用户删除了电表；迟到的快照也不能覆盖重登后的缓存。
      if (rooms.length > 0) await this.saveLocalRooms(snapshotEpoch);
    } catch { console.warn('ElectricityPage', 'saved rooms unavailable'); }
    finally { this.loading = false; }
    if (!await this.isRoomSessionCurrent()) return;
    this.balances = result;
    if (result.length === 0 && this.savedRooms.length === 0) { this.showAdd = true; this.loadLocations(''); }
    else if (result.length === 0) { promptAction.showToast({ message: '电费查询失败，请点击刷新重试', duration: 1800 }); }
  }

  private async localSavedRooms(): Promise<YKTSavedRoom[]> {
    const raw = await AppStorage.getInstance().getElectricityRoomsCache();
    if (!raw) return [];
    try { return JSON.parse(raw) as YKTSavedRoom[]; } catch { return []; }
  }

  private async saveLocalRooms(epoch: number = this.roomEpoch): Promise<void> {
    await AppStorage.getInstance().setElectricityRoomsCache(
      this.roomAccount, epoch, JSON.stringify(this.savedRooms), true);
  }

  private async isRoomSessionCurrent(): Promise<boolean> {
    if (!this.roomAccount) return false;
    const storage = AppStorage.getInstance();
    const account = (await storage.getStudentId()).trim();
    const loggedIn = await storage.getIsLogin();
    // 同一学号重新保存登录态会换 session epoch，但电表仍属于这个账号，不能清空。
    if (loggedIn && account === this.roomAccount) {
      this.roomEpoch = storage.getSessionEpoch();
      return true;
    }
    if (loggedIn && account !== this.roomAccount) {
      this.balances = [];
      this.savedRooms = [];
    }
    return false;
  }

  private async refreshBalances(): Promise<void> {
    if (this.loading || this.refreshing || this.showAdd) return;
    if (this.savedRooms.length === 0) {
      promptAction.showToast({ message: '请先添加寝室或空调电表', duration: 1500 });
      return;
    }
    this.refreshing = true;
    let failed = 0;
    const updated = this.balances.slice();
    try {
      if (!await this.isRoomSessionCurrent()) return;
      for (let i = 0; i < this.savedRooms.length; i++) {
        const room = this.savedRooms[i];
        try {
          const balance = await ElectricityApi.electricity(room.id);
          if (!await this.isRoomSessionCurrent()) return;
          const index = updated.findIndex((item: RoomBalance) => item.id === room.id);
          const current = index >= 0 ? updated[index] : undefined;
          const next: RoomBalance = {
            id: room.id, name: current?.name || room.name || '我的寝室',
            type: current?.type || room.type || '', remaining: balance.remaining, unit: balance.unit
          };
          if (index >= 0) updated[index] = next;
          else updated.push(next);
        } catch {
          failed++;
        }
      }
      if (!await this.isRoomSessionCurrent()) return;
      this.balances = updated;
      // 把最新余额写进本地电表记录，快捷卡片才能直接读到。
      for (let i = 0; i < this.savedRooms.length; i++) {
        const item = updated.find((value: RoomBalance) => value.id === this.savedRooms[i].id);
        if (item) {
          this.savedRooms[i].remaining = item.remaining;
          this.savedRooms[i].unit = item.unit;
        }
      }
      await this.saveLocalRooms();
      const message = failed === 0 ? '电费已刷新' :
        (failed === this.savedRooms.length ? '刷新失败，请检查网络后重试' : `有${failed}个电表刷新失败，请重试`);
      promptAction.showToast({ message, duration: 1800 });
    } finally {
      this.refreshing = false;
    }
  }

  private async loadLocations(parentId: string): Promise<void> { this.loading = true; try { const page = await ElectricityApi.locations(parentId); this.locations = page.items || []; this.locationEnd = page.end; } catch { promptAction.showToast({ message: '地点加载失败，请稍后重试', duration: 1500 }); } this.loading = false; }
  private choose(item: YKTLocationItem): void { const next = this.selected.slice(0, this.level); next.push(item); this.selected = next; if (!this.locationEnd) { this.level += 1; this.loadLocations(item.id); } else { this.addRoom(item); } }
  private async addRoom(room: YKTLocationItem): Promise<void> {
    this.loading = true;
    try {
      const data = await ElectricityApi.electricity(room.id);
      if (!await this.isRoomSessionCurrent()) return;
      const pathName = this.selected.map((item: YKTLocationItem) => item.name).join(' ');
      const roomType = pathName.includes('空调') ? '空调' : '寝室';
      const next = this.balances.filter((item: RoomBalance) => item.id !== room.id);
      next.push({ id: room.id, name: pathName || room.name, type: roomType, remaining: data.remaining, unit: data.unit });
      this.balances = next;
      this.savedRooms = this.savedRooms.filter((item: YKTSavedRoom) => item.id !== room.id);
      const savedRoom: YKTSavedRoom = { id: room.id, name: pathName || room.name, type: roomType,
        remaining: data.remaining, unit: data.unit };
      this.savedRooms.push(savedRoom);
      await this.saveLocalRooms();
      this.showAdd = false; this.selected = []; this.level = 0;
    } catch { promptAction.showToast({ message: '电费查询失败，请稍后重试', duration: 1500 }); }
    finally { this.loading = false; }
  }
  private roomLabel(item: RoomBalance): string { const text = `${item.type}${item.name}`; return text.includes('空调') ? '空调电费' : '寝室电费'; }

  build() {
    Column() {
      Row() { Text('‹').fontSize(42).width(48).onClick(() => router.back()); Text('查电费').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 }); }.width('100%').height(76).padding({ left: 14 }).backgroundColor('#F5F6F8');
      Scroll() {
        Column() {
          Row() {
            Text('一卡通电费查询').fontSize(25).fontWeight(FontWeight.Bold).layoutWeight(1);
            Button(this.refreshing ? '刷新中…' : '刷新')
              .fontSize(16).fontColor(Color.White).backgroundColor('#20C894')
              .enabled(!this.loading && !this.refreshing && !this.showAdd)
              .onClick(() => { this.refreshBalances(); });
          }.width('92%').margin({ top: 18, bottom: 14 });
          if (this.loading && this.balances.length === 0) { Text('正在查询寝室电费…').fontSize(18).fontColor('#999999').width('92%').margin({ top: 12 }); }
          ForEach(this.balances, (item: RoomBalance) => {
            Column() { Text(this.roomLabel(item)).fontSize(17).fontColor('#888888').width('100%'); Text(item.name).fontSize(21).fontWeight(FontWeight.Bold).width('100%').margin({ top: 8 }); Text(`${item.remaining} ${item.unit}`).fontSize(34).fontWeight(FontWeight.Bold).fontColor('#20C894').width('100%').margin({ top: 16 }); }.width('92%').padding(22).backgroundColor(Color.White).borderRadius(18).margin({ bottom: 12 });
          }, (item: RoomBalance) => item.id);
          if (!this.showAdd) { Text('+ 添加其他寝室/空调电表').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#20C894').width('92%').margin({ top: 12, bottom: 18 }).onClick(() => { if (this.refreshing) return; this.showAdd = true; this.selected = []; this.level = 0; this.loadLocations(''); }); }
          if (this.showAdd) {
            Text(this.balances.length > 0 ? '添加其他寝室' : '请选择寝室').fontSize(22).fontWeight(FontWeight.Bold).width('92%').margin({ top: 14, bottom: 12 });
            Row() { ForEach(this.selected, (item: YKTLocationItem) => Text(item.name).fontSize(15).fontColor('#B26E2A').margin({ right: 8 })); }.width('92%').margin({ bottom: 8 });
            if (!this.loading) { ForEach(this.locations, (item: YKTLocationItem) => { Row() { Text(item.name).fontSize(19).layoutWeight(1); Text('›').fontSize(28).fontColor('#999999'); }.width('92%').height(62).padding({ left: 18, right: 18 }).backgroundColor(Color.White).borderRadius(12).margin({ top: 10 }).onClick(() => this.choose(item)); }, (item: YKTLocationItem) => item.id); }
          }
        }.width('100%').padding({ bottom: 30 }).alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Start);
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off);
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start).backgroundColor('#F5F6F8');
  }
}
