import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { AppStorage } from '../../store/AppStorage';
import {
  SecondClassroomActivity,
  SecondClassroomApi,
  SecondClassroomModule,
  SecondClassroomSummary
} from '../../net/SecondClassroomApi';

const CACHE_KEY = 'secondClassroomSummaryCache';
const SYNC_KEY = 'secondClassroomLastSync';

@Entry
@Component
struct SecondClassroomPage {
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private selectedTab: number = 0;
  @State private totalCredit: number = 0;
  @State private evaluation: string = '--';
  @State private modules: SecondClassroomModule[] = [];
  @State private activities: SecondClassroomActivity[] = [];
  @State private activityTotal: number = 0;
  @State private lastSync: string = '--';
  @State private hasData: boolean = false;

  aboutToAppear(): void {
    this.restoreCache().then(() => this.loadSummary(false));
  }

  private async restoreCache(): Promise<void> {
    const storage = AppStorage.getInstance();
    const raw = await storage.getSettingString(CACHE_KEY, '');
    this.lastSync = await storage.getSettingString(SYNC_KEY, '--');
    if (!raw) return;
    try {
      this.applySummary(JSON.parse(raw) as SecondClassroomSummary);
    } catch {
      console.warn('SecondClassroomPage', 'invalid local cache');
    }
  }

  private applySummary(data: SecondClassroomSummary): void {
    this.totalCredit = Number(data.total_credit) || 0;
    this.evaluation = data.evaluation || '--';
    this.modules = data.modules || [];
    this.activities = data.activities?.rows || [];
    this.activityTotal = data.activities?.totalSize || this.activities.length;
    this.hasData = true;
  }

  private async loadSummary(manual: boolean): Promise<void> {
    if (manual) this.refreshing = true;
    else this.loading = true;
    try {
      const summary = await SecondClassroomApi.summary(1, 100);
      this.applySummary(summary);
      this.lastSync = this.formatTime(new Date());
      const storage = AppStorage.getInstance();
      await storage.setSettingString(CACHE_KEY, JSON.stringify(summary));
      await storage.setSettingString(SYNC_KEY, this.lastSync);
      if (manual) promptAction.showToast({ message: '第二课堂数据已更新', duration: 1200 });
    } catch (error) {
      const message = error instanceof Error ? error.message : '第二课堂数据获取失败';
      promptAction.showToast({
        message: this.hasData ? `更新失败，已显示上次数据：${message}` : message,
        duration: 2200
      });
    } finally {
      this.loading = false;
      this.refreshing = false;
    }
  }

  private formatTime(date: Date): string {
    const pad = (value: number): string => value < 10 ? `0${value}` : `${value}`;
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private credit(value: number | string | undefined): string {
    const numberValue = Number(value || 0);
    if (Math.floor(numberValue) === numberValue) return `${numberValue}`;
    return numberValue.toFixed(1).replace(/\.0$/, '');
  }

  private ratio(earned: number, required: number): number {
    if (required <= 0) return 100;
    return Math.max(0, Math.min(100, earned / required * 100));
  }

  @Builder
  private progressBar(earned: number, required: number, color: string) {
    Stack({ alignContent: Alignment.Start }) {
      Row().width('100%').height(7).backgroundColor('#E2E6E7').borderRadius(4)
      Row().width(`${this.ratio(earned, required)}%`).height(7).backgroundColor(color).borderRadius(4)
    }.width('100%').height(7)
  }

  @Builder
  private moduleCard(item: SecondClassroomModule) {
    Column() {
      Row() {
        Text(item.name || '未命名模块')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#252525')
          .layoutWeight(1).maxLines(2)
        Text(`${this.credit(item.earned_credit)} / ${this.credit(item.required_credit)} 分`)
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#2B9BE8').borderRadius(7)
      }.width('100%').alignItems(VerticalAlign.Center)

      Row() {
        Text(`必修已获 ${this.credit(item.earned_compulsory_credit)} 分 · 要求 ${this.credit(item.required_compulsory_credit)} 分`)
          .fontSize(15).fontColor('#5F6267').layoutWeight(1).maxLines(1)
        Column() { this.progressBar(item.earned_compulsory_credit, item.required_compulsory_credit, '#24C491') }
          .width('47%')
      }.width('100%').margin({ top: 17 }).alignItems(VerticalAlign.Center)

      Row() {
        Text(`选修已获 ${this.credit(item.earned_elective_credit)} 分 · 要求 ${this.credit(item.required_elective_credit)} 分`)
          .fontSize(15).fontColor('#5F6267').layoutWeight(1).maxLines(1)
        Column() { this.progressBar(item.earned_elective_credit, item.required_elective_credit, '#24C491') }
          .width('47%')
      }.width('100%').margin({ top: 12 }).alignItems(VerticalAlign.Center)
    }
    .width('100%').padding({ left: 20, right: 20, top: 20, bottom: 20 })
    .backgroundColor(Color.White).borderRadius(14).margin({ bottom: 13 })
    .shadow({ radius: 5, color: '#15000000', offsetX: 0, offsetY: 2 })
  }

  private activityTitle(item: SecondClassroomActivity): string {
    return item.XMNR || item.MKNR || '第二课堂活动';
  }

  private activityMeta(item: SecondClassroomActivity): string {
    const parts: string[] = [];
    if (item.MKNR && item.MKNR !== item.XMNR) parts.push(item.MKNR);
    if (item.XN) parts.push(`${item.XN}${item.XQ ? ` 第${item.XQ}学期` : ''}`);
    if (item.HDRQ) parts.push(item.HDRQ);
    return parts.join(' · ');
  }

  @Builder
  private activityCard(item: SecondClassroomActivity) {
    Column() {
      Row() {
        Text(this.activityTitle(item)).fontSize(19).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
        if (item.HDJF !== undefined) {
          Text(`+${this.credit(item.HDJF)} 分`).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20C894')
        }
      }.width('100%')
      if (this.activityMeta(item)) {
        Text(this.activityMeta(item)).fontSize(15).fontColor('#888888').width('100%').margin({ top: 10 })
      }
      if (item.SHZT) {
        Text(item.SHZT).fontSize(14).fontColor('#20A779').padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('#E8F8F2').borderRadius(12).margin({ top: 12 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(20).backgroundColor(Color.White)
      .borderRadius(14).margin({ bottom: 13 }).shadow({ radius: 5, color: '#15000000', offsetX: 0, offsetY: 2 })
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_arrow_left')).width(26).height(26).objectFit(ImageFit.Contain)
          .fillColor(Color.White).onClick(() => router.back())
        Text('第二课堂').fontSize(27).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 18 })
        Blank()
        if (this.refreshing) {
          LoadingProgress().width(28).height(28).color(Color.White)
        } else {
          Image($r('app.media.refresh')).width(30).height(30).objectFit(ImageFit.Contain)
            .fillColor(Color.White).onClick(() => this.loadSummary(true))
        }
      }.width('100%').height(88).padding({ left: 22, right: 24 }).backgroundColor('#20C894')

      if (this.loading && !this.hasData) {
        Column() {
          LoadingProgress().width(42).height(42).color('#20C894')
          Text('正在同步第二课堂数据…').fontSize(16).fontColor('#888888').margin({ top: 16 })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Column() {
              Text('素质发展总学分').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#5E6268').width('100%')
              Text(`${this.credit(this.totalCredit)}分`).fontSize(44).fontWeight(FontWeight.Bold).fontColor('#20C894')
                .width('100%').margin({ top: 12 })
              Text(`评价：${this.evaluation}`).fontSize(18).fontColor('#55585D').width('100%').margin({ top: 18 })
              Text(`最后同步：${this.lastSync}`).fontSize(15).fontColor('#A4A8AE').width('100%').margin({ top: 12 })
            }.width('92%').padding({ left: 22, right: 22, top: 24, bottom: 22 }).alignItems(HorizontalAlign.Start)
              .backgroundColor(Color.White).borderRadius(15).margin({ top: 18 })
              .shadow({ radius: 5, color: '#15000000', offsetX: 0, offsetY: 2 })

            Row() {
              Column() {
                Text('模块学分').fontSize(19).fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedTab === 0 ? '#20C894' : '#55585D')
                Row().width('100%').height(3).backgroundColor(this.selectedTab === 0 ? '#20C894' : '#00000000').margin({ top: 16 })
              }.width('50%').onClick(() => { this.selectedTab = 0; })
              Column() {
                Text('活动记录').fontSize(19).fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedTab === 1 ? '#20C894' : '#55585D')
                Row().width('100%').height(3).backgroundColor(this.selectedTab === 1 ? '#20C894' : '#00000000').margin({ top: 16 })
              }.width('50%').onClick(() => { this.selectedTab = 1; })
            }.width('100%').margin({ top: 25 })

            Column() {
              Row() {
                Row().width(7).height(26).backgroundColor('#20C894').borderRadius(4)
                Text(this.selectedTab === 0 ? '模块学分' : '活动记录')
                  .fontSize(21).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1)
                Text(this.selectedTab === 0 ? `共 ${this.modules.length} 个模块` : `共 ${this.activityTotal} 条`)
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#60646A')
              }.width('100%').margin({ bottom: 15 }).alignItems(VerticalAlign.Center)

              if (this.selectedTab === 0) {
                if (this.modules.length === 0) {
                  Text('暂无模块学分数据').fontSize(17).fontColor('#999999').margin({ top: 36, bottom: 50 })
                } else {
                  ForEach(this.modules, (item: SecondClassroomModule) => { this.moduleCard(item) },
                    (item: SecondClassroomModule, index: number) => item.id || `${index}`)
                }
              } else {
                if (this.activities.length === 0) {
                  Text('暂无活动记录').fontSize(17).fontColor('#999999').margin({ top: 36, bottom: 50 })
                } else {
                  ForEach(this.activities, (item: SecondClassroomActivity) => { this.activityCard(item) },
                    (item: SecondClassroomActivity, index: number) => item.ID || `${index}`)
                }
              }
            }.width('92%').alignItems(HorizontalAlign.Start).margin({ top: 22, bottom: 30 })
          }.width('100%').alignItems(HorizontalAlign.Center)
        }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#F4F5F7')
  }
}
