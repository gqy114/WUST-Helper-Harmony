import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { SecondHandBookApi } from '../../net/SecondHandBookApi';

@Entry
@Component
struct SecondHandBookPublishPage {
  @State private title: string = '';
  @State private price: string = '';
  @State private meetingPlace: string = '';
  @State private edition: string = '';
  @State private contact: string = '';
  @State private note: string = '';
  @State private submitting: boolean = false;

  private async submit(): Promise<void> {
    if (this.submitting) return;
    const amount = Number(this.price);
    if (!this.title.trim()) { promptAction.showToast({ message: '请填写书名', duration: 1200 }); return; }
    if (!this.price.trim() || isNaN(amount) || amount < 0) { promptAction.showToast({ message: '请填写正确售价', duration: 1200 }); return; }
    if (!this.contact.trim()) { promptAction.showToast({ message: '请填写联系方式', duration: 1200 }); return; }
    this.submitting = true;
    try {
      await SecondHandBookApi.publishManual(this.title.trim(), amount, this.edition.trim(), this.meetingPlace.trim(), this.contact.trim(), this.note.trim());
      promptAction.showToast({ message: '发布成功', duration: 1200 });
      router.back();
    } catch {
      promptAction.showToast({ message: '发布失败，请稍后重试', duration: 1500 });
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private selectorPlaceholder(text: string) {
    Row() { Text(text).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#66686F').layoutWeight(1); Text('▾').fontSize(18).fontColor('#78868A'); }
      .width('100%').height(62).padding({ left: 18, right: 18 }).backgroundColor('#F6F6F9').borderRadius(14)
      .onClick(() => promptAction.showToast({ message: '选择功能暂未开放', duration: 1100 }))
  }

  @Builder
  private inputField(placeholder: string, value: string, change: (value: string) => void) {
    TextInput({ placeholder, text: value }).width('100%').height(62).fontSize(18).fontColor('#444444').placeholderColor('#A7A8AD').backgroundColor('#F6F6F9').borderRadius(14).padding({ left: 18, right: 18 }).onChange(change)
  }

  build() {
    Column() {
      Row() { Text('‹').fontSize(42).width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('发布二手书').fontSize(28).fontWeight(FontWeight.Bold).margin({ left: 12 }); }.width('100%').height(88).padding({ left: 14 }).backgroundColor('#F5F6F8')
      Scroll() {
        Column() {
          Column() {
            Row() { Text('书籍实拍').fontSize(21).fontWeight(FontWeight.Bold).layoutWeight(1); Text('已选 0 张').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#20C894').padding({ left: 14, right: 14, top: 7, bottom: 7 }).backgroundColor('#ECF9F5').borderRadius(18); }.width('100%')
            Text('最多上传 9 张，点按图片可设为封面').fontSize(16).fontColor('#999999').width('100%').margin({ top: 10 })
            Column() { Text('+').fontSize(34).fontColor('#20C894'); Text('添加图片').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20C894').margin({ top: 4 }); }.width(112).height(112).justifyContent(FlexAlign.Center).backgroundColor('#ECF9F5').borderRadius(16).margin({ top: 18, bottom: 22 }).onClick(() => promptAction.showToast({ message: '图片选择暂未开放', duration: 1200 }))
            this.inputField('书名（必填）', this.title, (value: string) => { this.title = value; })
            Row() { Text('¥').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#D0583B').margin({ right: 8 }); TextInput({ placeholder: '售价', text: this.price }).layoutWeight(1).fontSize(20).fontWeight(FontWeight.Bold).type(InputType.Number).backgroundColor(Color.Transparent).onChange((value: string) => { this.price = value; }); Text('整本 / 整套').fontSize(15).fontColor('#777777'); }.width('100%').height(62).padding({ left: 18, right: 18 }).backgroundColor('#F6F6F9').borderRadius(14).margin({ top: 12 })
            Column() { this.selectorPlaceholder('适用专业：请选择'); }.margin({ top: 12 })
            Row() { Column() { this.selectorPlaceholder('品相：请选择'); }.layoutWeight(1).margin({ right: 10 }); Column() { this.selectorPlaceholder('校区：请选择'); }.layoutWeight(1); }.width('100%').margin({ top: 12 })
            Column() { this.inputField('面交地点（选填）', this.meetingPlace, (value: string) => { this.meetingPlace = value; }); }.margin({ top: 12 })
            Column() { this.inputField('版次 / 版本（选填，如第七版）', this.edition, (value: string) => { this.edition = value; }); }.margin({ top: 12 })
            Text('交易联系').fontSize(21).fontWeight(FontWeight.Bold).width('100%').margin({ top: 24, bottom: 12 })
            Row() { Text('方式  ▾').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#66686F').width(110).height(62).textAlign(TextAlign.Center).backgroundColor('#F6F6F9').borderRadius(14).margin({ right: 10 }).onClick(() => promptAction.showToast({ message: '联系方式选择暂未开放', duration: 1100 })); TextInput({ placeholder: '填写联系方式（必填）', text: this.contact }).layoutWeight(1).height(62).fontSize(17).backgroundColor('#F6F6F9').borderRadius(14).padding({ left: 16, right: 16 }).onChange((value: string) => { this.contact = value; }); }.width('100%')
            Text('仅在买家点击联系时展示，售出后关闭').fontSize(14).fontColor('#999999').width('100%').margin({ top: 8 })
            TextArea({ placeholder: '补充说明（选填）\n笔记、缺页、附件等情况', text: this.note }).width('100%').height(128).fontSize(17).backgroundColor('#F6F6F9').borderRadius(14).padding(18).margin({ top: 18 }).onChange((value: string) => { this.note = value; })
            Row() { Text('更多书籍资料（选填）').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20C894').layoutWeight(1); Text('▾').fontSize(18).fontColor('#78868A'); }.width('100%').height(60).onClick(() => promptAction.showToast({ message: '更多资料暂未开放', duration: 1100 }))
            Row() { Text('收起').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#666666').width(100).textAlign(TextAlign.Center); Button(this.submitting ? '发布中…' : '发布二手书').layoutWeight(1).height(56).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor(this.submitting ? '#A4DCCA' : '#20C894').borderRadius(28).onClick(() => this.submit()); }.width('100%').padding({ top: 16 }).border({ width: { top: 1 }, color: '#EEEEEE' })
          }.width('100%').padding({ left: 22, right: 22, top: 22, bottom: 22 }).backgroundColor(Color.White).borderRadius(22)
        }.width('100%').padding({ left: 16, right: 16, bottom: 28 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F6F8')
  }
}
