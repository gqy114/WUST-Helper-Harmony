import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import {
  TrainingPlanApi,
  TrainingPlanCourse,
  TrainingPlanCreditCategory,
  TrainingPlanData,
  TrainingPlanGeneralCategory,
  TrainingPlanSummary
} from '../../net/TrainingPlanApi';

const EMPTY_SUMMARY: TrainingPlanSummary = {
  credits: 0,
  courseCount: 0,
  failedCount: 0,
  failedCredits: 0,
  missingRequired: 0,
  missingRequiredCredits: 0,
  missingCredits: 0,
  unselectedCourseCount: 0,
  termCount: 0,
  averageCreditPerTerm: 0,
  categories: 0,
  planCourseCount: 0
};

const EMPTY_DATA: TrainingPlanData = {
  reminder: '',
  summary: EMPTY_SUMMARY,
  courses: [],
  creditCategories: [],
  generalCategories: []
};

@Entry
@Component
struct MajorProgressPage {
  @State private data: TrainingPlanData = EMPTY_DATA;
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;
  @State private errorText: string = '';
  @State private detailMode: string = 'overview';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    this.errorText = '';
    try {
      this.data = await TrainingPlanApi.fetchData();
    } catch (error) {
      this.loadFailed = true;
      this.errorText = error instanceof Error ? error.message : '培养方案加载失败';
      promptAction.showToast({ message: this.errorText, duration: 1800 });
    }
    this.loading = false;
  }

  private goBack(): void {
    if (this.detailMode !== 'overview') {
      this.detailMode = 'overview';
      return;
    }
    router.back();
  }

  private pageTitle(): string {
    if (this.detailMode === 'summary') return '课程统计';
    if (this.detailMode === 'credit') return '毕业学分';
    if (this.detailMode === 'general') return '通识选修';
    if (this.detailMode === 'courses') return '课程明细';
    return '主修进度';
  }

  private statusColor(status: string): string {
    if (status.includes('不及格') || status.includes('未通过')) return '#E45149';
    if (status.includes('未选') || status.includes('未修')) return '#F29A25';
    return '#20C894';
  }

  private statusBackground(status: string): string {
    if (status.includes('不及格') || status.includes('未通过')) return '#FFF0EF';
    if (status.includes('未选') || status.includes('未修')) return '#FFF6E9';
    return '#EAF9F4';
  }

  private reminderText(): string {
    if (this.data.reminder.trim().length > 0) return this.data.reminder;
    if (this.data.summary.missingRequired > 0 || this.data.summary.missingCredits > 0) {
      return '存在未获必修课程或尚未完成的计划学分，请查看下方明细。';
    }
    return '当前培养方案完成情况正常。';
  }

  private creditProgress(earned: number, required: number): number {
    if (required <= 0) return earned > 0 ? 100 : 0;
    return Math.min(100, Math.max(0, earned / required * 100));
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(44)
          .fontColor(Color.White)
          .width(48)
          .textAlign(TextAlign.Center)
          .onClick(() => this.goBack())
        Text(this.pageTitle())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ left: 18 })
        Blank().layoutWeight(1)
        Text('↻')
          .fontSize(36)
          .fontColor(Color.White)
          .visibility(this.detailMode === 'overview' ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => this.load())
      }
      .width('100%')
      .height(88)
      .padding({ left: 14, right: 24 })
      .backgroundColor('#20C894')

      if (this.loading) {
        Column() {
          LoadingProgress().width(48).height(48).color('#20C894')
          Text('正在获取主修进度…').fontSize(18).fontColor('#777777').margin({ top: 18 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadFailed) {
        Column() {
          Text('主修进度获取失败').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#444444')
          Text(this.errorText || '请检查网络或登录状态')
            .fontSize(17)
            .fontColor('#888888')
            .textAlign(TextAlign.Center)
            .margin({ top: 14 })
          Button('重新加载')
            .width(150)
            .height(50)
            .fontSize(18)
            .fontColor(Color.White)
            .backgroundColor('#20C894')
            .margin({ top: 26 })
            .onClick(() => this.load())
        }
        .width('88%')
        .padding(28)
        .backgroundColor(Color.White)
        .borderRadius(22)
        .margin({ top: 26 })
      } else if (this.detailMode === 'overview') {
        this.overview()
      } else if (this.detailMode === 'summary') {
        this.summaryDetail()
      } else if (this.detailMode === 'credit') {
        this.creditDetail()
      } else if (this.detailMode === 'general') {
        this.generalDetail()
      } else {
        this.courseDetail()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F7')
  }

  @Builder
  private overview(): void {
    Scroll() {
      Column() {
        Column() {
          Text('已修学分').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#666666')
          Text(`${this.data.summary.credits}分`)
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor('#20C894')
            .margin({ top: 22 })
          Text(`课程 ${this.data.summary.courseCount} 门 · 不及格 ${this.data.summary.failedCount} 门 · 必修未获 ${this.data.summary.missingRequired} 门`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#555555')
            .margin({ top: 24 })
          Text(this.reminderText())
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.data.summary.missingRequired > 0 || this.data.summary.missingCredits > 0 ? '#D94A43' : '#20A978')
            .width('100%')
            .margin({ top: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(28)
        .backgroundColor(Color.White)
        .borderRadius(24)

        Column() {
          Text('完成概览').fontSize(24).fontWeight(FontWeight.Bold).width('100%')
          Row() {
            this.stat(`${this.data.summary.courseCount}门`, '已修课程')
            this.stat(`${this.data.summary.failedCount}门`, '不及格')
          }.width('100%').margin({ top: 28 })
          Row() {
            this.stat(`${this.data.summary.missingRequired}门`, '必修未获')
            this.stat(`${this.data.summary.missingCredits}分`, '未选学分')
          }.width('100%').margin({ top: 24 })
        }
        .width('100%')
        .padding(28)
        .backgroundColor(Color.White)
        .borderRadius(24)
        .margin({ top: 16 })

        Column() {
          Text('查看明细').fontSize(24).fontWeight(FontWeight.Bold).width('100%')
          this.detail('课程统计', '学期、已修、不及格、未选和必修未获统计', `${this.data.summary.courseCount} 门`, 'summary')
          this.detail('毕业学分完成情况', '按课程性质展示要求学分和已获学分', `${this.data.creditCategories.length} 个类别`, 'credit')
          this.detail('通识选修类别', '按通识类别展示要求学分和已获学分', `${this.data.generalCategories.length} 个类别`, 'general')
          this.detail('培养方案课程明细', '查看每门课程的学期、学分和修读状态', `${this.data.courses.length} 门课程`, 'courses')
        }
        .width('100%')
        .padding(28)
        .backgroundColor(Color.White)
        .borderRadius(24)
        .margin({ top: 16, bottom: 20 })
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
  }

  @Builder
  private summaryDetail(): void {
    Scroll() {
      Column() {
        this.metric('统计学期', `${this.data.summary.termCount} 个`)
        this.metric('已修课程', `${this.data.summary.courseCount} 门`)
        this.metric('已修学分', `${this.data.summary.credits} 分`)
        this.metric('平均每学期学分', `${this.data.summary.averageCreditPerTerm} 分`)
        this.metric('不及格课程', `${this.data.summary.failedCount} 门 / ${this.data.summary.failedCredits} 分`, '#E45149')
        this.metric('未选课程', `${this.data.summary.unselectedCourseCount} 门 / ${this.data.summary.missingCredits} 分`, '#F29A25')
        this.metric('必修未获', `${this.data.summary.missingRequired} 门 / ${this.data.summary.missingRequiredCredits} 分`, '#E45149')
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
  }

  @Builder
  private creditDetail(): void {
    Scroll() {
      Column() {
        if (this.data.creditCategories.length === 0) {
          this.empty('暂无毕业学分分类数据')
        } else {
          ForEach(this.data.creditCategories, (item: TrainingPlanCreditCategory) => {
            this.creditCard(item.name, item.attribute, item.earnedCredit, item.requiredCredit)
          }, (item: TrainingPlanCreditCategory, index: number) => `${item.name}-${item.attribute}-${index}`)
        }
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
  }

  @Builder
  private generalDetail(): void {
    Scroll() {
      Column() {
        if (this.data.generalCategories.length === 0) {
          this.empty('暂无通识选修分类数据')
        } else {
          ForEach(this.data.generalCategories, (item: TrainingPlanGeneralCategory) => {
            this.creditCard(item.name, '通识选修', item.earnedCredit, item.requiredCredit)
          }, (item: TrainingPlanGeneralCategory, index: number) => `${item.name}-${index}`)
        }
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
  }

  @Builder
  private courseDetail(): void {
    Scroll() {
      Column() {
        if (this.data.courses.length === 0) {
          this.empty('暂无培养方案课程数据')
        } else {
          ForEach(this.data.courses, (item: TrainingPlanCourse) => {
            Column() {
              Row() {
                Column() {
                  Text(item.courseName).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
                  Text(`${item.term}${item.courseCode ? ` · ${item.courseCode}` : ''}`)
                    .fontSize(15)
                    .fontColor('#8A8A8A')
                    .margin({ top: 7 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(item.status)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.statusColor(item.status))
                  .backgroundColor(this.statusBackground(item.status))
                  .borderRadius(14)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              }.width('100%')
              Row() {
                Text(`${item.credit} 学分`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#20C894')
                if (item.courseNature) {
                  Text(item.courseNature).fontSize(15).fontColor('#666666').margin({ left: 18 })
                }
                if (item.courseAttribute) {
                  Text(item.courseAttribute).fontSize(15).fontColor('#666666').margin({ left: 12 })
                }
              }.width('100%').margin({ top: 16 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(20)
            .backgroundColor(Color.White)
            .borderRadius(18)
            .margin({ bottom: 12 })
          }, (item: TrainingPlanCourse, index: number) => `${item.term}-${item.courseCode}-${index}`)
        }
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
  }

  @Builder
  private stat(value: string, label: string): void {
    Column() {
      Text(value).fontSize(34).fontWeight(FontWeight.Bold).fontColor('#20C894')
      Text(label).fontSize(17).fontColor('#777777').margin({ top: 4 })
    }
    .width('50%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private detail(title: string, desc: string, value: string, mode: string): void {
    Row() {
      Column() {
        Text(title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#555555')
        Text(desc).fontSize(15).fontColor('#888888').margin({ top: 7 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(`${value}  ›`).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20C894')
    }
    .width('100%')
    .padding({ top: 22, bottom: 4 })
    .onClick(() => { this.detailMode = mode; })
  }

  @Builder
  private metric(label: string, value: string, color: string = '#20C894'): void {
    Row() {
      Text(label).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
      Blank().layoutWeight(1)
      Text(value).fontSize(20).fontWeight(FontWeight.Bold).fontColor(color)
    }
    .width('100%')
    .padding(22)
    .backgroundColor(Color.White)
    .borderRadius(18)
    .margin({ bottom: 12 })
  }

  @Builder
  private creditCard(name: string, attribute: string, earned: number, required: number): void {
    Column() {
      Row() {
        Column() {
          Text(name).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#333333')
          if (attribute) {
            Text(attribute).fontSize(15).fontColor('#888888').margin({ top: 7 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(`${earned} / ${required} 分`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(earned >= required ? '#20C894' : '#258CD6')
      }.width('100%')
      Progress({ value: this.creditProgress(earned, required), total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(8)
        .color(earned >= required ? '#20C894' : '#258CD6')
        .backgroundColor('#E8EBED')
        .margin({ top: 18 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(22)
    .backgroundColor(Color.White)
    .borderRadius(18)
    .margin({ bottom: 12 })
  }

  @Builder
  private empty(message: string): void {
    Column() {
      Text(message).fontSize(18).fontColor('#888888')
    }
    .width('100%')
    .padding(40)
    .backgroundColor(Color.White)
    .borderRadius(20)
  }
}
