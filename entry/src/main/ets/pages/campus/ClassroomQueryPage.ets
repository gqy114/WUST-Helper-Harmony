import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

@Entry @Component
struct ClassroomQueryPage {
  @State private startWeek: string = ''; @State private endWeek: string = ''; @State private weekday: string = ''; @State private period: string = ''; @State private building: string = ''; @State private room: string = '';
  @Builder private field(value: string, placeholder: string, onChange: (value: string) => void) { TextInput({ placeholder, text: value }).width('100%').height(74).fontSize(22).fontColor('#555555').backgroundColor(Color.White).borderRadius(38).padding({ left: 28, right: 20 }).onChange(onChange); }
  build() { Column() {
    Row() { Text('‹').fontSize(48).fontColor(Color.White).width(48).onClick(() => router.back()); Text('空教室查询').fontSize(29).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 18 }); }.width('100%').height(96).padding({ left: 28 }).alignItems(VerticalAlign.Center).backgroundColor('#20C894');
    Scroll() { Column() { Text('留空代表不限，输入一个时间段和教室条件即可查询').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#777777').width('92%').margin({ top: 34, bottom: 24 }); this.field(this.startWeek, '开始周次（如 1）', (v: string) => { this.startWeek = v; }); this.field(this.endWeek, '结束周次（留空则等于开始周次）', (v: string) => { this.endWeek = v; }); this.field(this.weekday, '请选择星期', (v: string) => { this.weekday = v; }); this.field(this.period, '节次范围', (v: string) => { this.period = v; }); this.field(this.building, '教学楼（可输入关键字）', (v: string) => { this.building = v; }); this.field(this.room, '教室编号（可输入关键字，如 101）', (v: string) => { this.room = v; }); Button('查询教室').width('92%').height(72).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor('#20C894').borderRadius(38).margin({ top: 24 }).onClick(() => promptAction.showToast({ message: '查询功能即将接入', duration: 1500 })); Blank().height(40); }.width('100%').padding({ bottom: 30 }).alignItems(HorizontalAlign.Center); }.layoutWeight(1).width('100%').backgroundColor('#F5F6F8').scrollBar(BarState.Off);
  }.width('100%').height('100%').backgroundColor('#F5F6F8'); }
}
