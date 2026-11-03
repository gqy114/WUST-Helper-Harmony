import { promptAction } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import { AppStorage } from '../../store/AppStorage';
import {
  VolunteerActivity,
  VolunteerApi,
  VolunteerHourCodeInfo,
  VolunteerLog,
  VolunteerPageData
} from '../../net/VolunteerApi';

@Component
export struct VolunteerPage {
  @State private name: string = '';
  @State private studentId: string = '';
  @State private hourCode: string = '';
  @State private activeTab: string = '工时明细';
  @State private participatedCount: number = 0;
  @State private certifiedHours: number = 0;
  @State private uncertifiedHours: number = 0;
  @State private loadingCode: boolean = false;
  @State private submitting: boolean = false;
  @State private showHourSelector: boolean = false;
  @State private activityName: string = '';
  @State private activityDate: string = '';
  @State private activityOwner: string = '';
  @State private availableHours: number[] = [];
  @State private selectedHours: number = 0;
  @State private volunteerLogs: VolunteerLog[] = [];
  @State private volunteerActivities: VolunteerActivity[] = [];
  @State private loadingData: boolean = false;
  @State private dataError: string = '';
  @State private registeringId: string = '';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    const storage = AppStorage.getInstance();
    this.name = await storage.getRealName();
    this.studentId = await storage.getStudentId();
    if (this.loadingData) return;
    this.loadingData = true;
    this.dataError = '';
    try {
      const data: VolunteerPageData = await VolunteerApi.getPageData();
      this.volunteerLogs = data.logs;
      this.volunteerActivities = data.activities;

      // sumTime 在部分账号或设备上会返回 0，但明细接口仍有完整数据。
      // 页面渲染前再根据明细做最终校正，避免顶部统计与下方明细不一致。
      let certifiedFromLogs: number = 0;
      let uncertifiedFromLogs: number = 0;
      data.logs.forEach((log: VolunteerLog): void => {
        if (log.certified) {
          certifiedFromLogs += log.hours;
        } else {
          uncertifiedFromLogs += log.hours;
        }
      });
      this.participatedCount = Math.max(data.summary.participatedCount, data.logs.length);
      this.certifiedHours = Math.max(data.summary.certifiedHours, certifiedFromLogs);
      this.uncertifiedHours = Math.max(data.summary.uncertifiedHours, uncertifiedFromLogs);
    } catch (error) {
      this.dataError = this.errorMessage(error as Object, '志愿工时获取失败');
      promptAction.showToast({ message: this.dataError, duration: 2200 });
    } finally {
      this.loadingData = false;
    }
  }

  // 顶部统计直接以当前已经渲染出来的明细为兜底，避免部分设备上
  // sumTime 返回全 0 或状态更新顺序不同，出现“明细有数据、顶部仍为 0”。
  private displayedParticipatedCount(): number {
    return Math.max(this.participatedCount, this.volunteerLogs.length);
  }

  private displayedCertifiedHours(): number {
    let hours: number = 0;
    this.volunteerLogs.forEach((log: VolunteerLog): void => {
      if (log.certified) hours += log.hours;
    });
    return Math.max(this.certifiedHours, hours);
  }

  private displayedUncertifiedHours(): number {
    let hours: number = 0;
    this.volunteerLogs.forEach((log: VolunteerLog): void => {
      if (!log.certified) hours += log.hours;
    });
    return Math.max(this.uncertifiedHours, hours);
  }

  private codeCharacter(index: number): string {
    return index < this.hourCode.length ? this.hourCode.charAt(index) : '';
  }

  private extractHourCode(content: string): string {
    const text: string = content.trim();
    if (/^\d{6}$/.test(text)) return text;
    const namedMatch: RegExpMatchArray | null = text.match(/(?:randomString|verifyCode|hourCode|code)["']?\s*(?:=|:|%3D)\s*["']?(\d{6})/i);
    if (namedMatch && namedMatch[1]) return namedMatch[1];
    const standaloneMatch: RegExpMatchArray | null = text.match(/(?:^|\D)(\d{6})(?:\D|$)/);
    return standaloneMatch && standaloneMatch[1] ? standaloneMatch[1] : '';
  }

  private async scanHourCode(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const permissionResult = await atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA']);
      if (!permissionResult.authResults || permissionResult.authResults[0] !== 0) {
        promptAction.showToast({ message: '需要相机权限才能扫码认证', duration: 1600 });
        return;
      }
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      };
      const result = await scanBarcode.startScanForResult(context, options);
      const code: string = this.extractHourCode(result.originalValue || '');
      if (code.length !== 6) {
        promptAction.showToast({ message: '未识别到有效的六位工时码', duration: 1800 });
        return;
      }
      this.hourCode = code;
      await this.certify();
    } catch (error) {
      console.info('VolunteerPage', `扫码取消或失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '扫码已取消', duration: 1300 });
    }
  }

  private errorMessage(error: Object, fallback: string): string {
    const message: string = `${error}`.replace(/^Error:\s*/, '');
    return message.length > 0 && message !== '[object Object]' ? message : fallback;
  }

  private async certify(): Promise<void> {
    if (this.hourCode.length !== 6) {
      promptAction.showToast({ message: '请输入完整的 6 位工时码', duration: 1400 });
      return;
    }
    if (this.loadingCode) return;
    this.loadingCode = true;
    try {
      const info: VolunteerHourCodeInfo = await VolunteerApi.getHourCodeInfo(this.hourCode);
      this.activityName = info.activityName;
      this.activityDate = info.participateDate;
      this.activityOwner = info.crater;
      this.availableHours = info.volunteerTimes;
      this.selectedHours = info.volunteerTimes[0];
      this.showHourSelector = true;
    } catch (error) {
      promptAction.showToast({ message: this.errorMessage(error as Object, '工时码查询失败'), duration: 2200 });
    } finally {
      this.loadingCode = false;
    }
  }

  private async confirmCertification(): Promise<void> {
    if (this.selectedHours <= 0 || this.submitting) return;
    this.submitting = true;
    try {
      await VolunteerApi.certifyHours(this.hourCode, this.selectedHours);
      this.showHourSelector = false;
      this.hourCode = '';
      promptAction.showToast({ message: '工时认证成功', duration: 1800 });
      await this.load();
    } catch (error) {
      promptAction.showToast({ message: this.errorMessage(error as Object, '工时认证失败'), duration: 2200 });
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private statistic(icon: Resource, label: string, value: string, color: string) {
    Column() {
      Image(icon).width(42).height(42).objectFit(ImageFit.Contain)
      Text(label).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#666666').margin({ top: 8 })
      Text(value).fontSize(19).fontWeight(FontWeight.Bold).fontColor(color).margin({ top: 6 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  private formatHours(hours: number): string {
    return Number.isInteger(hours) ? `${hours}` : hours.toFixed(1);
  }

  private async registerActivity(activity: VolunteerActivity): Promise<void> {
    if (this.registeringId.length > 0) return;
    this.registeringId = activity.id;
    try {
      await VolunteerApi.registerActivity(activity.id);
      promptAction.showToast({ message: '报名成功', duration: 1600 });
      await this.load();
    } catch (error) {
      promptAction.showToast({ message: this.errorMessage(error as Object, '报名失败'), duration: 2200 });
    } finally {
      this.registeringId = '';
    }
  }

  @Builder
  private volunteerLogCard(log: VolunteerLog) {
    Column() {
      Row() {
        Column() {
          Text(log.activityName).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333').maxLines(2)
          if (log.organizationName.length > 0) {
            Text(log.organizationName).fontSize(14).fontColor('#888888').margin({ top: 6 }).maxLines(1)
          }
          Text(`日期：${log.participateDate || '暂无'}`).fontSize(14).fontColor('#999999').margin({ top: 7 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column() {
          Text(`+${this.formatHours(log.hours)} 小时`).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(log.certified ? '#45B34C' : '#F39A00')
          Text(log.certified ? '已认证' : '未认证').fontSize(13)
            .fontColor(log.certified ? '#2E8F5D' : '#E57A19')
            .backgroundColor(log.certified ? '#E8F8F0' : '#FFF1E4').borderRadius(14)
            .padding({ left: 11, right: 11, top: 5, bottom: 5 }).margin({ top: 10 })
        }.alignItems(HorizontalAlign.End).margin({ left: 12 })
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').padding({ left: 18, right: 18, top: 18, bottom: 18 })
      .backgroundColor('#FAFBFB').borderRadius(16).margin({ top: 10 })
  }

  @Builder
  private volunteerActivityCard(activity: VolunteerActivity) {
    Column() {
      Text(activity.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333').width('100%').maxLines(2)
      Text(`时间：${activity.time || '待通知'}`).fontSize(14).fontColor('#777777').width('100%').margin({ top: 9 })
      Text(`地点：${activity.location}`).fontSize(14).fontColor('#777777').width('100%').margin({ top: 6 })
      Row() {
        Text(`招募人数：${activity.recruitNum}`).fontSize(14).fontColor('#888888').layoutWeight(1)
        Button(this.registeringId === activity.id ? '报名中…' : '立即报名').height(38).fontSize(15)
          .fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor('#20C894').borderRadius(19)
          .onClick(() => { this.registerActivity(activity); })
      }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 12 })
    }.width('100%').padding({ left: 18, right: 18, top: 18, bottom: 16 })
      .backgroundColor('#FAFBFB').borderRadius(16).margin({ top: 10 })
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
              this.statistic($r('app.media.participated_activities'), '已参与活动',
                `${this.displayedParticipatedCount()}`, '#333333')
              this.statistic($r('app.media.certified_man_hour'), '已认证工时',
                `${this.displayedCertifiedHours()}h`, '#45B34C')
              this.statistic($r('app.media.uncertified_man_hour'), '未认证工时',
                `${this.displayedUncertifiedHours()}h`, '#F39A00')
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
                .onClick(() => { this.scanHourCode(); })
              Button('认证工时').layoutWeight(1.35).height(52).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .backgroundColor(this.hourCode.length === 6 ? '#4DB85A' : '#9BD39D').borderRadius(12).margin({ left: 14 })
                .onClick(() => { this.certify(); })
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
            if (this.loadingData && this.volunteerLogs.length === 0 && this.volunteerActivities.length === 0) {
              Column() {
                LoadingProgress().width(34).height(34).color('#20C894')
                Text('正在同步志愿数据…').fontSize(15).fontColor('#999999').margin({ top: 12 })
              }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 38, bottom: 38 })
            } else if (this.dataError.length > 0 && this.volunteerLogs.length === 0 && this.volunteerActivities.length === 0) {
              Column() {
                Text(this.dataError).fontSize(15).fontColor('#999999').textAlign(TextAlign.Center)
                Button('重新加载').height(40).fontSize(15).fontColor(Color.White).backgroundColor('#20C894')
                  .borderRadius(20).margin({ top: 14 }).onClick(() => { this.load(); })
              }.width('100%').alignItems(HorizontalAlign.Center).padding({ left: 24, right: 24, top: 34, bottom: 34 })
            } else if (this.activeTab === '工时明细') {
              if (this.volunteerLogs.length === 0) {
                Text('暂无工时明细').fontSize(17).fontColor('#999999').margin({ top: 44, bottom: 44 })
              } else {
                Column() {
                  ForEach(this.volunteerLogs, (log: VolunteerLog, index: number) => {
                    this.volunteerLogCard(log)
                  }, (log: VolunteerLog, index: number) => `${log.activityName}-${log.participateDate}-${index}`)
                }.width('100%')
              }
            } else {
              if (this.volunteerActivities.length === 0) {
                Text('暂无志愿招募信息').fontSize(17).fontColor('#999999').margin({ top: 44, bottom: 44 })
              } else {
                Column() {
                  ForEach(this.volunteerActivities, (activity: VolunteerActivity, index: number) => {
                    this.volunteerActivityCard(activity)
                  }, (activity: VolunteerActivity, index: number) => `${activity.id}-${index}`)
                }.width('100%')
              }
            }
          }.width('100%').padding({ left: 8, right: 8, top: 8 }).backgroundColor(Color.White).borderRadius(24).margin({ top: 16, bottom: 24 })
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)

      if (this.showHourSelector) {
        Stack({ alignContent: Alignment.Center }) {
          Column() {}
            .width('100%').height('100%').backgroundColor('#66000000')
            .onClick(() => { if (!this.submitting) this.showHourSelector = false; })
          Column() {
            Text('确认志愿工时').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#333333')
            Text(this.activityName).fontSize(19).fontWeight(FontWeight.Medium).fontColor('#444444')
              .width('100%').margin({ top: 20 })
            if (this.activityDate.length > 0) {
              Text(`活动日期：${this.activityDate}`).fontSize(15).fontColor('#888888').width('100%').margin({ top: 8 })
            }
            if (this.activityOwner.length > 0) {
              Text(`活动负责人：${this.activityOwner}`).fontSize(15).fontColor('#888888').width('100%').margin({ top: 6 })
            }
            Text('请选择本次真实服务时长').fontSize(16).fontColor('#555555').width('100%').margin({ top: 22, bottom: 12 })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.availableHours, (hours: number) => {
                Text(`${hours}h`).fontSize(17).fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedHours === hours ? Color.White : '#20A878')
                  .backgroundColor(this.selectedHours === hours ? '#20C894' : '#E8F8F2')
                  .borderRadius(18).padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .margin({ right: 10, bottom: 10 }).onClick(() => { this.selectedHours = hours; })
              }, (hours: number) => `${hours}`)
            }.width('100%')
            Row() {
              Button('取消').layoutWeight(1).height(48).fontSize(17).fontColor('#666666')
                .backgroundColor('#F1F2F3').borderRadius(12)
                .onClick(() => { this.showHourSelector = false; })
              Button(this.submitting ? '提交中…' : '确认认证').layoutWeight(1.35).height(48).fontSize(17)
                .fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor('#20C894')
                .borderRadius(12).margin({ left: 12 }).onClick(() => { this.confirmCertification(); })
            }.width('100%').margin({ top: 18 })
          }.width('88%').padding(24).backgroundColor(Color.White).borderRadius(24)
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%').backgroundColor('#F5F6F7')
  }
}
