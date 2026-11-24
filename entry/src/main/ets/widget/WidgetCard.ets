/**
 * 桌面小组件卡片 UI。
 *
 * 数据由 EntryFormAbility 通过 formBindingData 注入，
 * 卡片内部只做展示，不访问网络，也不读写 Preferences。
 */
import { WeeklyWidgetGrid } from './WeeklyWidgetGrid';
import { DailyWidgetCarousel } from './DailyWidgetCarousel';
import { CountdownWidgetCarousel } from './CountdownWidgetCarousel';

const LINE_COUNT = 4;
// 快捷功能按钮使用 App 图标同款蓝色，保持品牌一致。
const QUICK_TILE_BG: string = '#61A5FA';

let widgetStorage: LocalStorage = new LocalStorage();

@Entry(widgetStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('mode') mode: string = 'countdown';
  @LocalStorageProp('title') title: string = '武科大助手';
  @LocalStorageProp('subtitle') subtitle: string = '正在加载数据…';
  @LocalStorageProp('line0') line0: string = '';
  @LocalStorageProp('line1') line1: string = '';
  @LocalStorageProp('line2') line2: string = '';
  @LocalStorageProp('line3') line3: string = '';
  @LocalStorageProp('countdownSlides') countdownSlides: string = '';
  @LocalStorageProp('countdownCompact') countdownCompact: boolean = false;
  @LocalStorageProp('accent') accent: string = '#61A5FA';
  @LocalStorageProp('bg') bg: string = '';
  @LocalStorageProp('bgOpacity') bgOpacity: number = 0.7;
  @LocalStorageProp('cardBg') cardBg: string = '#FFFFFF';
  @LocalStorageProp('textColor') textColor: string = '#111111';
  @LocalStorageProp('subColor') subColor: string = '#666666';
  @LocalStorageProp('campus') campus: string = '黄家湖校区';
  @LocalStorageProp('weeklyCourses') weeklyCourses: string = '';
  @LocalStorageProp('dailyCourses') dailyCourses: string = '';
  @LocalStorageProp('dailyWeekday') dailyWeekday: string = '';

  private lineAt(index: number): string {
    if (index === 0) return this.line0;
    if (index === 1) return this.line1;
    if (index === 2) return this.line2;
    return this.line3;
  }

  private lineIndexes(): number[] {
    const result: number[] = [];
    for (let i = 0; i < LINE_COUNT; i++) result.push(i);
    return result;
  }

  @Builder
  private courseContent() {
    Column() {
      Row() {
        Column() {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.subtitle)
            .fontSize(12)
            .fontColor(this.accent)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Divider().color('#33000000').margin({ top: 8, bottom: 6 }).strokeWidth(0.5)

      Column() {
        ForEach(this.lineIndexes(), (index: number) => {
          if (this.lineAt(index).length > 0) {
            Text(this.lineAt(index))
              .fontSize(12)
              .fontColor(this.subColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ bottom: 4 })
          }
        }, (index: number) => `${index}-${this.lineAt(index)}`)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private quickTile(label: string, route: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#123A66')
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.accent)
    .borderRadius(12)
    .margin(4)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { widgetRoute: route }
      });
    })
  }

  @Builder
  private quickContent() {
    Column() {
      Row() {
        Text('快捷功能')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .layoutWeight(1)
        Text('⚙')
          .fontSize(16)
          .fontColor(this.subColor)
      }
      .width('100%')
      .margin({ bottom: 6 })

      Row() {
        Column() {
          Text(this.title)
            .fontSize(11)
            .fontColor(this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitle)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .maxLines(1)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 10, right: 10 })
        .backgroundColor(this.accent)
        .borderRadius(12)
        .margin(4)
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility',
            params: { widgetRoute: 'pages/main/ElectricityPage' }
          });
        })
        this.quickTile('成绩查询', 'pages/campus/grade/GradePage')
        this.quickTile('校园墙', 'pages/campus/CampusWallPage')
      }
      .width('100%')
      .layoutWeight(1)

      Row() {
        this.quickTile('教室查询', 'pages/campus/ClassroomQueryPage')
        this.quickTile('图书馆', 'pages/library/LibraryPage')
        this.quickTile('培养方案', 'pages/campus/TrainingPlanPage')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      // 底色 + 背景图；不透明度只作用于背景图，不影响文字。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.cardBg)
      if (this.bg.length > 0) {
        Image(this.bg)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.bgOpacity)
      }

      Column() {
        if (this.mode === 'quick') {
          this.quickContent()
        } else if (this.mode === 'countdown') {
          CountdownWidgetCarousel({
            slides: this.countdownSlides,
            emptyText: this.subtitle,
            initialCompact: this.countdownCompact,
            accent: this.accent,
            textColor: this.textColor,
            subColor: this.subColor,
            onSettings: () => {
              postCardAction(this, { action: 'router', abilityName: 'EntryAbility',
                params: { widgetRoute: 'pages/profile/WidgetSettingsPage' } });
            },
            onRefresh: () => {
              postCardAction(this, { action: 'message', params: { action: 'refresh' } });
            },
            onAdd: () => {
              postCardAction(this, { action: 'router', abilityName: 'EntryAbility',
                params: { widgetRoute: 'pages/profile/WidgetSettingsPage?addCountdown' } });
            }
          })
        } else if (this.mode === 'weekly') {
          Text(this.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%')
          WeeklyWidgetGrid({ courses: this.weeklyCourses, campus: this.campus, subtitle: this.subtitle,
            textColor: this.textColor, subColor: this.subColor })
            .layoutWeight(1)
        } else if (this.mode === 'daily') {
          DailyWidgetCarousel({
            dateText: this.title,
            weekText: this.dailyWeekday,
            courses: this.dailyCourses,
            emptyText: this.subtitle,
            accent: this.accent,
            textColor: this.textColor,
            subColor: this.subColor,
            onSettings: () => {
              postCardAction(this, { action: 'router', abilityName: 'EntryAbility',
                params: { widgetRoute: 'pages/profile/WidgetSettingsPage' } });
            },
            onRefresh: () => {
              postCardAction(this, { action: 'message', params: { action: 'refresh' } });
            }
          })
        } else {
          this.courseContent()
        }
      }
      .width('100%')
      .height('100%')
      .padding(this.mode === 'countdown' ? 0 : (this.mode === 'weekly' || this.mode === 'daily' ? 8 : 16))
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {
          message: 'open'
        }
      });
    })
  }
}
