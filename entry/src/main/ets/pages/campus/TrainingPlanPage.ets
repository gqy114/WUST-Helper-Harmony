/**
 * 培养方案（新版结构化接口）。
 *
 * 后端 /UnderGraduate|Graduate/Support/getTrainingPlan 直接返回
 * { title, blocks:[{type,text,rows,links,...}] }，页面原生渲染，不再加载 HTML。
 */
import { promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { HotFeatureTopBar } from '../../components/HotFeatureTopBar';
import {
  CultivationPlanApi, TrainingPlan, TrainingPlanBlock, TrainingPlanCell,
  TrainingPlanLink, TrainingPlanRow
} from '../../net/CultivationPlanApi';

const TAG = 'TrainingPlanPage';

@Entry
@Component
struct TrainingPlanPage {
  @State private loading: boolean = true;
  @State private failed: boolean = false;
  @State private errorText: string = '';
  @State private titleText: string = '培养方案';
  @State private blocks: TrainingPlanBlock[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.failed = false;
    this.errorText = '';
    try {
      const plan: TrainingPlan = await CultivationPlanApi.fetchStructured();
      this.titleText = (plan.title || '培养方案').trim();
      this.blocks = Array.isArray(plan.blocks) ? plan.blocks : [];
      if (this.blocks.length === 0) {
        this.failed = true;
        this.errorText = '培养方案暂无内容';
      }
    } catch (error) {
      this.failed = true;
      this.errorText = error instanceof Error ? error.message : '培养方案加载失败';
      promptAction.showToast({ message: this.errorText, duration: 1800 });
    }
    this.loading = false;
  }

  private blockText(block: TrainingPlanBlock): string {
    if (block.text && block.text.trim().length > 0) return block.text.trim();
    const nested = block.blocks || [];
    const parts: string[] = [];
    for (let i = 0; i < nested.length; i++) {
      const text = this.blockText(nested[i]);
      if (text.length > 0) parts.push(text);
    }
    return parts.join(' ');
  }

  private cellText(cell: TrainingPlanCell): string {
    if (cell.text && cell.text.trim().length > 0) return cell.text.trim();
    const nested = cell.blocks || [];
    const parts: string[] = [];
    for (let i = 0; i < nested.length; i++) {
      const text = this.blockText(nested[i]);
      if (text.length > 0) parts.push(text);
    }
    return parts.join(' ');
  }

  private async openLink(url: string): Promise<void> {
    if (!url) return;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = { action: 'ohos.want.action.viewData', uri: url };
      await context.startAbility(want);
    } catch (error) {
      console.warn(TAG, `open link failed: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '无法打开该链接', duration: 1500 });
    }
  }

  @Builder
  private tableBlock(rows: TrainingPlanRow[]) {
    Column() {
      ForEach(rows, (row: TrainingPlanRow) => {
        Row() {
          ForEach(row.cells || [], (cell: TrainingPlanCell) => {
            Text(this.cellText(cell))
              .fontSize(cell.header ? 13 : 13)
              .fontWeight(cell.header ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(cell.header ? '#333333' : '#555555')
              .layoutWeight(1)
              .padding(8)
              .border({ width: 0.5, color: '#DDDDDD' })
          }, (cell: TrainingPlanCell, index: number) => `${index}-${this.cellText(cell)}`)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      }, (row: TrainingPlanRow, index: number) => `${row.sourceRow || index}`)
    }
    .width('100%')
    .border({ width: 0.5, color: '#DDDDDD' })
    .margin({ top: 8, bottom: 8 })
  }

  @Builder
  private blockView(block: TrainingPlanBlock) {
    if (block.type === 'heading') {
      Text(this.blockText(block))
        .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#333333')
        .width('100%').margin({ top: 16, bottom: 6 })
    } else if (block.type === 'table') {
      this.tableBlock(block.rows || [])
    } else if (block.type === 'links') {
      Column() {
        ForEach(block.links || [], (link: TrainingPlanLink) => {
          Text(link.text || link.url).fontSize(14).fontColor('#20C997')
            .width('100%').padding({ top: 4, bottom: 4 })
            .onClick(() => this.openLink(link.url))
        }, (link: TrainingPlanLink, index: number) => `${index}-${link.url}`)
      }.width('100%').alignItems(HorizontalAlign.Start)
    } else if (block.type === 'image') {
      Text(this.blockText(block)).fontSize(12).fontColor('#999999').width('100%').margin({ top: 4 })
    } else {
      Text(this.blockText(block))
        .fontSize(15).fontColor('#555555').lineHeight(24)
        .width('100%').margin({ top: 4, bottom: 4 })
    }
  }

  build() {
    Column() {
      HotFeatureTopBar({ title: this.titleText, onAction: () => this.load() })

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#20C997')
          Text('培养方案加载中…').fontSize(13).fontColor('#999999').margin({ top: 10 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.failed) {
        Column() {
          Image($r('app.media.empty')).width(80).height(80).objectFit(ImageFit.Contain)
          Text(this.errorText).fontSize(14).fontColor('#999999').textAlign(TextAlign.Center).margin({ top: 12 })
          Button('重试').fontSize(14).height(36).margin({ top: 16 }).backgroundColor('#20C997')
            .onClick(() => this.load())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.blocks, (block: TrainingPlanBlock, index: number) => {
              this.blockView(block)
            }, (block: TrainingPlanBlock, index: number) => `${index}-${block.type || ''}-${(block.text || '').length}`)
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 24 })
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(Color.White)
  }
}
