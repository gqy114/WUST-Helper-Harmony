import { AppStorage } from '../../store/AppStorage';
@Component export struct VolunteerPage {
  @State private name: string = '';
  @State private studentId: string = '';
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> { const s = AppStorage.getInstance(); this.name = await s.getRealName(); this.studentId = await s.getStudentId(); }
  build() {
    Column() {
      Row() { Text('志愿工时').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#555555'); Text('VOLUNTEER').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#777777').margin({ left: 12 }); }.width('100%').padding({ left: 28, top: 32, bottom: 26 });
      Column() { Text(`姓名：${this.name}`).fontSize(23).fontWeight(FontWeight.Bold); Text(`学号：${this.studentId}`).fontSize(19).fontColor('#666666').margin({ top: 12 }); Divider().margin({ top: 22 }); Text('📅  已参与活动     0').fontSize(19).margin({ top: 24 }); Text('✅  已认证工时     0h').fontSize(19).margin({ top: 20 }); Text('🧾  未认证工时     0h').fontSize(19).margin({ top: 20 }); }.width('calc(100% - 32vp)').padding(28).backgroundColor(Color.White).borderRadius(24);
      Column() { Text('快速认证工时').fontSize(24).fontWeight(FontWeight.Bold).width('100%'); Text('输入 6 位工时码，选择工时后提交').fontSize(17).fontColor('#999999').margin({ top: 10 }); TextInput({ placeholder: '请输入 6 位工时码' }).maxLength(6).type(InputType.Number).margin({ top: 24 }); Row() { Button('扫码').layoutWeight(1).height(52).backgroundColor('#CCCCCC'); Button('认证工时').layoutWeight(1).height(52).margin({ left: 14 }).backgroundColor('#9BD39D'); }.margin({ top: 16 }); }.width('calc(100% - 32vp)').padding(28).backgroundColor(Color.White).borderRadius(24).margin({ top: 16 });
      Blank().layoutWeight(1);
    }.width('100%').height('100%').padding({ left: 16, right: 16 }).backgroundColor('#F5F6F7');
  }
}
