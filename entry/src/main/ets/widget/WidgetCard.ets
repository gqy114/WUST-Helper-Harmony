/**
 * 桌面小组件卡片 UI。
 *
 * 数据由 EntryFormAbility 通过 formBindingData 注入，
 * 卡片内部只做展示，不访问网络，也不读写 Preferences。
 */
import { WeeklyWidgetCarousel } from './WeeklyWidgetCarousel';
import { DailyWidgetCarousel } from './DailyWidgetCarousel';
import { CountdownWidgetCarousel } from './CountdownWidgetCarousel';

import { WidgetScheduleOption } from './WidgetData';

const ARCHIVES_PER_PAGE = 3;
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
  @LocalStorageProp('accent') accent: string = '#61A5FA';
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

  @LocalStorageProp('scheduleArchiveId') scheduleArchiveId: string = '';
  @LocalStorageProp('scheduleOptions') scheduleOptions: string = '';
  @State private choosingArchive: boolean = false;
  @State private archivePage: number = 0;

  private archiveOptions(): WidgetScheduleOption[] {
    try {
      return JSON.parse(this.scheduleOptions || '[]') as WidgetScheduleOption[];
    } catch {
      return [];
    }
  }

  private pageOptions(): WidgetScheduleOption[] {
    const start = this.archivePage * ARCHIVES_PER_PAGE;
    return this.archiveOptions().slice(start, start + ARCHIVES_PER_PAGE);
  }

  private openArchivePicker(): void {
    this.archivePage = 0;
    this.choosingArchive = true;
    postCardAction(this, { action: 'message', params: { action: 'archiveOptions' } });
  }

  private selectArchive(id: string): void {
    this.choosingArchive = false;
    postCardAction(this, { action: 'message', params: { action: 'selectArchive', archiveId: id } });
  }

  private openApp(): void {
    postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { message: 'open' } });
  }

  @Builder
  private archivePicker() {
    Column() {
      Row({ space: 8 }) {
        Text('选择课表').fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.textColor).layoutWeight(1)
        if (this.archiveOptions().length > ARCHIVES_PER_PAGE) {
          Text('‹').fontSize(19).fontColor(this.archivePage > 0 ? this.textColor : this.subColor)
            .width(24).textAlign(TextAlign.Center).accessibilityText('上一页').onClick(() => {
              if (this.archivePage > 0) this.archivePage--;
            })
          Text('›').fontSize(19).fontColor(this.textColor).width(24).textAlign(TextAlign.Center)
            .accessibilityText('下一页').onClick(() => {
              if ((this.archivePage + 1) * ARCHIVES_PER_PAGE < this.archiveOptions().length) this.archivePage++;
            })
        }
        Text('×').fontSize(19).fontColor(this.subColor).width(24).textAlign(TextAlign.Center)
          .accessibilityText('关闭课表选项').onClick(() => { this.choosingArchive = false; })
      }.width('100%').height(23)
      ForEach(this.pageOptions(), (option: WidgetScheduleOption) => {
        Row({ space: 4 }) {
          Text(option.label).fontSize(12).fontColor(this.textColor).maxLines(1).layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.scheduleArchiveId === option.id) {
            Text('✓').fontSize(12).fontColor(this.accent)
          }
        }.width('100%').height(25).padding({ left: 4, right: 6 })
          .accessibilitySelected(this.scheduleArchiveId === option.id).onClick(() => this.selectArchive(option.id))
      }, (option: WidgetScheduleOption) => option.id)
      if (this.archiveOptions().length === 0) {
        Text('正在读取课表档案…').fontSize(12).fontColor(this.subColor).margin({ top: 8 })
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

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
      Text(label).fontSize(11).fontColor('#123A66').maxLines(1).minFontSize(9)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.accent)
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
            Text(this.title).fontSize(11).fontColor('#123A66').maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.subtitle).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#123A66')
              .maxLines(1).minFontSize(12).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(2)
        .height('100%')
        .padding({ left: 9, right: 7 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.accent)
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
            textColor: this.textColor, subColor: this.subColor,
            showArchiveSwitch: true,
            onArchiveSwitch: () => { this.openArchivePicker(); },
            onOpen: () => { this.openApp(); }
          }).layoutWeight(1)
        } else if (this.mode === 'daily') {
          DailyWidgetCarousel({
            dateText: this.title,
            weekText: this.dailyWeekday,
            showArchiveSwitch: true,
            onArchiveSwitch: () => { this.openArchivePicker(); },
            onOpen: () => { this.openApp(); },
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
      .visibility(this.choosingArchive ? Visibility.Hidden : Visibility.Visible)

      if (this.choosingArchive) {
        Column() {
          this.archivePicker()
        }.width('100%').height('100%').padding(8)
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .onClick(() => {
      if (this.mode !== 'daily' && this.mode !== 'weekly') this.openApp();
    })
  }
}
