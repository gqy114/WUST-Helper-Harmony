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
  @State private locations: YKTLocationItem[] = [];
  @State private selected: YKTLocationItem[] = [];
  @State private balances: RoomBalance[] = [];
  @State private showAdd: boolean = false;
  @State private locationEnd: boolean = false;
  private savedRooms: YKTSavedRoom[] = [];

  aboutToAppear(): void { this.loadSavedRooms(); }

  private async loadSavedRooms(): Promise<void> {
    this.loading = true;
    const result: RoomBalance[] = [];
    try {
      const cloudRooms = await ElectricityApi.savedRooms();
      const localRooms = await this.localSavedRooms();
      const rooms: YKTSavedRoom[] = cloudRooms.length > 0 ? cloudRooms : localRooms;
      this.savedRooms = rooms;
      for (let i = 0; i < rooms.length; i++) {
        const room: YKTSavedRoom = rooms[i];
        try {
          const balance = await ElectricityApi.electricity(room.id);
          result.push({ id: room.id, name: room.name || '我的寝室', type: room.type || '', remaining: balance.remaining, unit: balance.unit });
        } catch { console.warn('ElectricityPage', `room query failed: ${room.id}`); }
      }
    } catch { console.warn('ElectricityPage', 'saved rooms unavailable'); }
    this.balances = result;
    this.loading = false;
    if (result.length === 0) { this.showAdd = true; this.loadLocations(''); }
  }

  private async localSavedRooms(): Promise<YKTSavedRoom[]> {
    const raw = await AppStorage.getInstance().getSettingString('electricityRooms', '');
    if (!raw) return [];
    try { return JSON.parse(raw) as YKTSavedRoom[]; } catch { return []; }
  }

  private async saveLocalRooms(): Promise<void> {
    const storage = AppStorage.getInstance();
    await storage.setSettingString('electricityRooms', JSON.stringify(this.savedRooms));
  }

  private async loadLocations(parentId: string): Promise<void> { this.loading = true; try { const page = await ElectricityApi.locations(parentId); this.locations = page.items || []; this.locationEnd = page.end; } catch { promptAction.showToast({ message: '地点加载失败，请稍后重试', duration: 1500 }); } this.loading = false; }
  private choose(item: YKTLocationItem): void { const next = this.selected.slice(0, this.level); next.push(item); this.selected = next; if (!this.locationEnd) { this.level += 1; this.loadLocations(item.id); } else { this.addRoom(item); } }
  private async addRoom(room: YKTLocationItem): Promise<void> {
    this.loading = true;
    try {
      const data = await ElectricityApi.electricity(room.id);
      const pathName = this.selected.map((item: YKTLocationItem) => item.name).join(' ');
      const roomType = pathName.includes('空调') ? '空调' : '寝室';
      const next = this.balances.filter((item: RoomBalance) => item.id !== room.id);
      next.push({ id: room.id, name: pathName || room.name, type: roomType, remaining: data.remaining, unit: data.unit });
      this.balances = next;
      this.savedRooms = this.savedRooms.filter((item: YKTSavedRoom) => item.id !== room.id);
      this.savedRooms.push({ id: room.id, name: pathName || room.name, type: roomType });
      await this.saveLocalRooms();
      this.showAdd = false; this.selected = []; this.level = 0;
    } catch { promptAction.showToast({ message: '电费查询失败，请稍后重试', duration: 1500 }); }
    this.loading = false;
  }
  private roomLabel(item: RoomBalance): string { const text = `${item.type}${item.name}`; return text.includes('空调') ? '空调电费' : '寝室电费'; }

  build() {
    Column() {
      Row() { Text('‹').fontSize(42).width(48).onClick(() => router.back()); Text('查电费').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 }); }.width('100%').height(76).padding({ left: 14 }).backgroundColor('#F5F6F8');
      Scroll() {
        Column() {
          Text('一卡通电费查询').fontSize(25).fontWeight(FontWeight.Bold).width('92%').margin({ top: 18, bottom: 14 });
          if (this.loading && this.balances.length === 0) { Text('正在查询寝室电费…').fontSize(18).fontColor('#999999').width('92%').margin({ top: 12 }); }
          ForEach(this.balances, (item: RoomBalance) => {
            Column() { Text(this.roomLabel(item)).fontSize(17).fontColor('#888888').width('100%'); Text(item.name).fontSize(21).fontWeight(FontWeight.Bold).width('100%').margin({ top: 8 }); Text(`${item.remaining} ${item.unit}`).fontSize(34).fontWeight(FontWeight.Bold).fontColor('#20C894').width('100%').margin({ top: 16 }); }.width('92%').padding(22).backgroundColor(Color.White).borderRadius(18).margin({ bottom: 12 });
          }, (item: RoomBalance) => item.id);
          if (!this.showAdd) { Text('+ 添加其他寝室/空调电表').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#20C894').width('92%').margin({ top: 12, bottom: 18 }).onClick(() => { this.showAdd = true; this.selected = []; this.level = 0; this.loadLocations(''); }); }
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
