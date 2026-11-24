/**
 * 桌面小组件卡片 UI。
 *
 * 数据由 EntryFormAbility 通过 formBindingData 注入，
 * 卡片内部只做展示，不访问网络，也不读写 Preferences。
 */
import { WeeklyWidgetCarousel } from './WeeklyWidgetCarousel';
import { DailyWidgetCarousel } from './DailyWidgetCarousel';
import { CountdownWidgetCarousel } from './CountdownWidgetCarousel';

const LINE_COUNT = 4;
const QUICK_TILE_BLUE = '#61A5FA';

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
  @LocalStorageProp('accent') accent: string = '#EC5A3C';
  @LocalStorageProp('bg') bg: string = '';
  @LocalStorageProp('bgOpacity') bgOpacity: number = 0.7;
  @LocalStorageProp('cardBg') cardBg: string = '#FFFFFF';
  @LocalStorageProp('textColor') textColor: string = '#111111';
  @LocalStorageProp('subColor') subColor: string = '#666666';
  @LocalStorageProp('campus') campus: string = '黄家湖校区';
  @LocalStorageProp('weeklyPages') weeklyPages: string = '';
  @LocalStorageProp('weeklyCurrentWeek') weeklyCurrentWeek: number = 1;
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
  private quickTile(label: string, icon: Resource, route: string) {
    Column({ space: 3 }) {
      Image(icon).width(24).height(24).objectFit(ImageFit.Contain)
      Text(label).fontSize(11).fontColor(Color.White).maxLines(1).minFontSize(9)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(QUICK_TILE_BLUE)
    .borderRadius(11)
    .accessibilityText(label)
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
    Column({ space: 5 }) {
      Row() {
        Text('快捷功能').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor).layoutWeight(1)
        Image($r('app.media.setting')).width(26).height(24).padding(3)
          .objectFit(ImageFit.Contain).fillColor(this.textColor).accessibilityText('小组件设置')
          .onClick(() => {
            postCardAction(this, { action: 'router', abilityName: 'EntryAbility',
              params: { widgetRoute: 'pages/profile/WidgetSettingsPage' } });
          })
      }.width('100%').height(25)

      Row({ space: 5 }) {
        Row({ space: 8 }) {
          Image($r('app.media.quick_widget_electricity')).width(25).height(25).objectFit(ImageFit.Contain)
          Column({ space: 2 }) {
            Text(this.title).fontSize(11).fontColor(Color.White).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.subtitle).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Color.White)
              .maxLines(1).minFontSize(12).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(2)
        .height('100%')
        .padding({ left: 9, right: 7 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(QUICK_TILE_BLUE)
        .borderRadius(11)
        .accessibilityText('电量 ' + this.title + ' ' + this.subtitle)
        .onClick(() => {
          postCardAction(this, { action: 'router', abilityName: 'EntryAbility',
            params: { widgetRoute: 'pages/main/ElectricityPage' } });
        })
        this.quickTile('成绩查询', $r('app.media.quick_widget_grades'), 'pages/campus/grade/GradePage')
        this.quickTile('校园墙', $r('app.media.quick_widget_campus_wall'), 'pages/campus/CampusWallPage')
      }.width('100%').layoutWeight(1)

      Row({ space: 5 }) {
        this.quickTile('教室查询', $r('app.media.quick_widget_classroom'), 'pages/campus/ClassroomQueryPage')
        this.quickTile('图书馆', $r('app.media.quick_widget_library'), 'pages/library/LibraryPage')
        this.quickTile('培养方案', $r('app.media.quick_widget_plan'), 'pages/campus/TrainingPlanPage')
        Blank().layoutWeight(1)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%')
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
          WeeklyWidgetCarousel({
            pagesJson: this.weeklyPages, currentWeek: this.weeklyCurrentWeek,
            title: this.title, courses: this.weeklyCourses, campus: this.campus, subtitle: this.subtitle,
            textColor: this.textColor, subColor: this.subColor
          })
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
      .padding(this.mode === 'countdown' ? 0 : (this.mode === 'quick' ? 10 : 8))
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
