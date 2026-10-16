import { router } from '@kit.ArkUI';
import { AppStorage } from '../../store/AppStorage';

interface NavOption { key: string; title: string; removable: boolean; }

@Entry
@Component
struct BottomNavCustomizePage {
  @State private volunteer: boolean = true;
  @State private campus: boolean = true;
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> { const s = AppStorage.getInstance(); this.volunteer = await s.getSettingBool('navVolunteer', true); this.campus = await s.getSettingBool('navCampus', true); }
  private async setVisible(key: string, value: boolean): Promise<void> { await AppStorage.getInstance().setSettingBool(key, value); if (key === 'navVolunteer') this.volunteer = value; if (key === 'navCampus') this.campus = value; }
  @Builder private option(item: NavOption, visible: boolean): void {
    Row() { if (item.removable && visible) { Text('−').fontSize(22).fontColor(Color.White).fontWeight(FontWeight.Bold).width(28).height(28).textAlign(TextAlign.Center).backgroundColor('#999999').borderRadius(14).onClick(() => this.setVisible(item.key, false)); } Text(item.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').margin({ left: item.removable && visible ? 12 : 42 }); }.width('100%').height(78).padding({ left: 30 }).onClick(() => { if (item.removable && visible) this.setVisible(item.key, false); });
  }
  @Builder private hiddenOption(item: NavOption, visible: boolean): void { if (!visible) { Row() { Text('+').fontSize(22).fontColor(Color.White).fontWeight(FontWeight.Bold).width(28).height(28).textAlign(TextAlign.Center).backgroundColor('#20C9A0').borderRadius(14); Text(item.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#222222').margin({ left: 12 }); }.width('100%').height(78).padding({ left: 30 }).onClick(() => this.setVisible(item.key, true)); } }
  build() {
    Column() {
      Row() { Text('←').fontSize(28).onClick(() => router.back()); Text('底部导航自定义').fontSize(23).fontWeight(FontWeight.Bold).margin({ left: 18 }); }.width('100%').height(64).padding({ left: 18 }).backgroundColor(Color.White);
      Row() { Text('显示').fontSize(16).fontColor('#666666'); Text('您的操作将在下次打开应用时刷新').fontSize(16).fontColor('#666666').layoutWeight(1).textAlign(TextAlign.End); }.width('100%').padding({ left: 30, right: 30, top: 18, bottom: 14 });
      Column() { this.option({ key: 'navHome', title: '主页', removable: false }, true); if (this.volunteer) { this.option({ key: 'navVolunteer', title: '志愿者', removable: true }, true); } this.option({ key: 'navCourse', title: '课表', removable: false }, true); if (this.campus) { this.option({ key: 'navCampus', title: '校园', removable: true }, true); } this.option({ key: 'navMine', title: '个人', removable: false }, true); }.width('92%').backgroundColor(Color.White).borderRadius(18);
      Text('隐藏').fontSize(16).fontColor('#666666').width('100%').padding({ left: 30, top: 28, bottom: 10 });
      Column() { if (!this.volunteer) { this.hiddenOption({ key: 'navVolunteer', title: '志愿者', removable: true }, false); } if (!this.campus) { this.hiddenOption({ key: 'navCampus', title: '校园', removable: true }, false); } }.width('92%').backgroundColor(Color.White).borderRadius(18).padding({ top: 1, bottom: 1 });
      Button('恢复默认').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#666666').backgroundColor(Color.White).margin({ top: 28 }).onClick(async () => { await this.setVisible('navVolunteer', true); await this.setVisible('navCampus', true); });
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
