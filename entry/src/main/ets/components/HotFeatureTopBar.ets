import { router } from '@kit.ArkUI';

const BAR_HEIGHT: number = 56;
export const HOT_FEATURE_BAR_COLOR: string = '#23C087';

/** 首页热门功能入口共用的顶部栏，尺寸和配色与成绩查询一致。 */
@Component
export struct HotFeatureTopBar {
  @Prop title: string = '';
  @Prop actionVisible: boolean = true;
  actionIcon: Resource = $r('app.media.refresh');
  actionLabel: string = '刷新';
  onAction?: () => void;
  onBack: () => void = () => { router.back(); };

  build() {
    Row() {
      Row() {
        Text('←').fontSize(24).fontColor(Color.White)
      }
      .width(BAR_HEIGHT).height('100%').justifyContent(FlexAlign.Center)
      .accessibilityText('返回')
      .onClick(() => this.onBack())

      Text(this.title)
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .layoutWeight(1).textAlign(TextAlign.Center)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.actionVisible && this.onAction) {
        Row() {
          Image(this.actionIcon).width(22).height(22).fillColor(Color.White).objectFit(ImageFit.Contain)
        }
        .width(BAR_HEIGHT).height('100%').justifyContent(FlexAlign.Center)
        .accessibilityText(this.actionLabel)
        .onClick(() => this.onAction?.())
      } else {
        Row().width(BAR_HEIGHT)
      }
    }
    .width('100%').height(BAR_HEIGHT)
    .backgroundColor(HOT_FEATURE_BAR_COLOR)
    .alignItems(VerticalAlign.Center)
  }
}
