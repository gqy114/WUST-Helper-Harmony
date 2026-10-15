import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { TrainingPlanApi, TrainingPlanSummary } from '../../net/TrainingPlanApi';

@Entry @Component
struct TrainingPlanPage {
  @State private loading: boolean = true;
  @State private data: TrainingPlanSummary = { credits: 0, courseCount: 0, failedCount: 0, missingRequired: 0, missingCredits: 0, categories: 0, planCourseCount: 0 };
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> { this.loading = true; try { this.data = await TrainingPlanApi.fetchSummary(); } catch { promptAction.showToast({ message: '培养方案加载失败', duration: 1500 }); } this.loading = false; }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('培养方案').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }); Blank().layoutWeight(1); Text('刷新').fontSize(17).fontColor('#20B984').onClick(() => this.load()); }.width('100%').height(76).padding({ left: 14, right: 20 }).backgroundColor(Color.White);
      Scroll() { Column() {
        Column() { Text('培养方案完成情况').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#555555'); Text(this.loading ? '加载中…' : `${this.data.credits} 分`).fontSize(44).fontWeight(FontWeight.Bold).fontColor('#F57C00').margin({ top: 18 }); Text(`已修课程 ${this.data.courseCount} 门`).fontSize(18).fontColor('#666666').margin({ top: 10 }); }.width('100%').padding(26).backgroundColor(Color.White).borderRadius(20);
        Column() { Text('修读概览').fontSize(22).fontWeight(FontWeight.Bold).width('100%'); Row() { this.stat(`${this.data.courseCount} 门`, '已修课程'); this.stat(`${this.data.failedCount} 门`, '不及格'); }.margin({ top: 24 }); Row() { this.stat(`${this.data.missingRequired} 门`, '必修未获'); this.stat(`${this.data.missingCredits} 分`, '未选学分'); }.margin({ top: 22 }); }.width('100%').padding(26).backgroundColor(Color.White).borderRadius(20).margin({ top: 16 });
        Column() { Text('培养方案统计').fontSize(22).fontWeight(FontWeight.Bold).width('100%'); this.line('课程类别', `${this.data.categories} 个类别`); this.line('方案课程总数', `${this.data.planCourseCount} 门课程`); this.line('学习状态', this.data.missingRequired > 0 || this.data.missingCredits > 0 ? '仍有课程待完成' : '当前进度正常'); }.width('100%').padding(26).backgroundColor(Color.White).borderRadius(20).margin({ top: 16 });
      }.width('100%').padding(16).backgroundColor('#F5F6F7'); }.layoutWeight(1);
    }.width('100%').height('100%').backgroundColor('#F5F6F7');
  }
  @Builder private stat(value: string, label: string) { Column() { Text(value).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#20B984'); Text(label).fontSize(15).fontColor('#777777').margin({ top: 6 }); }.layoutWeight(1); }
  @Builder private line(label: string, value: string) { Row() { Text(label).fontSize(17).fontColor('#555555').layoutWeight(1); Text(value).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20B984'); }.width('100%').padding({ top: 16, bottom: 16 }); }
}
