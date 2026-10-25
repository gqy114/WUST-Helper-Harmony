import { promptAction } from '@kit.ArkUI';
import { AppStorage } from '../../store/AppStorage';

@Component
export struct VolunteerPage {
  @State private name: string = '';
  @State private studentId: string = '';
  @State private hourCode: string = '';
  @State private activeTab: string = '工时明细';
  @State private participatedCount: number = 0;
  @State private certifiedHours: number = 0;
  @State private uncertifiedHours: number = 0;

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.name = await storage.getRealName();
    this.studentId = await storage.getStudentId();
  }

  private codeCharacter(index: number): string {
    return index < this.hourCode.length ? this.hourCode.charAt(index) : '';
  }

  private certify(): void {
    if (this.hourCode.length !== 6) {
      promptAction.showToast({ message: '请输入完整的 6 位工时码', duration: 1400 });
      return;
    }
    promptAction.showToast({ message: '工时认证接口暂未接入', duration: 1400 });
  }

  @Builder
  private statistic(icon: Resource, label: string, value: string, color: string) {
    Column() {
      Image(icon).width(42).height(42).objectFit(ImageFit.Contain)
      Text(label).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#666666').margin({ top: 8 })
      Text(value).fontSize(19).fontWeight(FontWeight.Bold).fontColor(color).margin({ top: 6 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private codeInput() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
          Text(this.codeCharacter(index)).width(46).height(60).fontSize(25).fontWeight(FontWeight.Bold)
            .fontColor('#444444').textAlign(TextAlign.Center).backgroundColor('#FAFBFB')
            .border({ width: 1, color: this.hourCode.length === index ? '#9EDDC8' : '#E2E7E5' })
            .borderRadius(12).margin({ right: index < 5 ? 8 : 0 })
        })
      }.width('100%').justifyContent(FlexAlign.Center)
      TextInput({ text: this.hourCode }).width('100%').height(64).maxLength(6).type(InputType.Number)
        .fontColor(Color.Transparent).caretColor(Color.Transparent).backgroundColor(Color.Transparent)
        .onChange((value: string) => { this.hourCode = value.replace(/[^0-9]/g, '').substring(0, 6); })
    }.width('100%').height(68).margin({ top: 22 })
  }

  build() {
    Column() {
      Row() {
        Text('志愿工时').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#555555')
        Text('VOLUNTEER').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#777777').margin({ left: 12 })
      }.width('100%').padding({ left: 28, top: 30, bottom: 22 })

      Scroll() {
        Column() {
          Column() {
            Row() {
              Column() {
                Text(`姓名：${this.name || '未获取'}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
                Text(`学号：${this.studentId || '未获取'}`).fontSize(17).fontColor('#777777').margin({ top: 10 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Button('生成证书').height(48).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .backgroundColor('#4DB85A').borderRadius(12)
                .onClick(() => promptAction.showToast({ message: '暂无可生成的志愿证书', duration: 1400 }))
            }.width('100%').alignItems(VerticalAlign.Center)

            Divider().color('#EEEEEE').margin({ top: 24, bottom: 20 })

            Row() {
              this.statistic($r('app.media.participated_activities'), '已参与活动', `${this.participatedCount}`, '#333333')
              this.statistic($r('app.media.certified_man_hour'), '已认证工时', `${this.certifiedHours}h`, '#45B34C')
              this.statistic($r('app.media.uncertified_man_hour'), '未认证工时', `${this.uncertifiedHours}h`, '#F39A00')
            }.width('100%')
          }.width('100%').padding({ left: 24, right: 24, top: 24, bottom: 24 }).backgroundColor(Color.White).borderRadius(24)

          Column() {
            Row() {
              Text('快速认证工时').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#333333').layoutWeight(1)
              Text('6位码').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#168D69')
                .backgroundColor('#E8F8F2').borderRadius(16).padding({ left: 12, right: 12, top: 7, bottom: 7 })
            }.width('100%')
            Text('输入 6 位工时码，选择工时后提交').fontSize(16).fontColor('#999999').width('100%').margin({ top: 10 })
            this.codeInput()
            Row() {
              Button('扫码').layoutWeight(1).height(52).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#555555')
                .backgroundColor('#D2D2D2').borderRadius(12)
                .onClick(() => promptAction.showToast({ message: '扫码认证功能暂未接入', duration: 1400 }))
              Button('认证工时').layoutWeight(1.35).height(52).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .backgroundColor(this.hourCode.length === 6 ? '#4DB85A' : '#9BD39D').borderRadius(12).margin({ left: 14 })
                .onClick(() => this.certify())
            }.width('100%').margin({ top: 18 })
          }.width('100%').padding({ left: 24, right: 24, top: 24, bottom: 24 }).backgroundColor(Color.White).borderRadius(24).margin({ top: 16 })

          Column() {
            Row() {
              ForEach(['工时明细', '志愿招募'], (tab: string) => {
                Column() {
                  Text(tab).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.activeTab === tab ? '#20C894' : '#555555')
                    .height(48).textAlign(TextAlign.Center)
                  Divider().strokeWidth(3).color(this.activeTab === tab ? '#20C894' : Color.Transparent)
                }.layoutWeight(1).onClick(() => { this.activeTab = tab; })
              })
            }.width('100%')
            Column() {
              Text(this.activeTab === '工时明细' ? '暂无工时明细' : '暂无志愿招募信息')
                .fontSize(17).fontColor('#999999').margin({ top: 44, bottom: 44 })
            }.width('100%').alignItems(HorizontalAlign.Center)
          }.width('100%').padding({ left: 8, right: 8, top: 8 }).backgroundColor(Color.White).borderRadius(24).margin({ top: 16, bottom: 24 })
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F6F7')
  }
}
