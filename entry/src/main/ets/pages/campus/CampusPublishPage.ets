import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi } from '../../net/CampusWallApi';
import { AppStorage } from '../../store/AppStorage';

interface PublishParams { tag?: string; label?: string; }

@Entry
@Component
struct CampusPublishPage {
  @State private title: string = '';
  @State private content: string = '';
  @State private tag: string = 'wall';
  @State private label: string = '校园墙';
  @State private submitting: boolean = false;
  @State private avatarUrl: string = '';
  @State private displayName: string = '同学';
  @State private college: string = '';
  @State private editorExpanded: boolean = true;
  @State private bold: boolean = false;
  @State private italic: boolean = false;
  @State private underline: boolean = false;
  @State private strike: boolean = false;

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as PublishParams;
    if (params) {
      this.tag = params.tag || 'wall';
      this.label = this.pageTitle(params.label || '');
    }
    const storage = AppStorage.getInstance();
    this.avatarUrl = await storage.getAvatarUrl();
    this.displayName = await storage.getUserName() || await storage.getRealName() || '同学';
    this.college = await storage.getCollege();
  }

  private pageTitle(routeLabel: string): string {
    if (this.tag === 'wall') return '校园墙';
    if (routeLabel.startsWith('发布')) return routeLabel.substring(2);
    return routeLabel || '校园墙';
  }

  private async submit(): Promise<void> {
    if (this.submitting) return;
    if (this.title.trim().length === 0 || this.content.trim().length === 0) {
      promptAction.showToast({ message: '请填写标题和内容', duration: 1200 });
      return;
    }
    this.submitting = true;
    try {
      await CampusWallApi.publish(this.title.trim(), this.content.trim(), this.tag);
      promptAction.showToast({ message: '发布成功', duration: 1200 });
      router.back();
    } catch {
      promptAction.showToast({ message: '发布失败，请检查登录状态后重试', duration: 1500 });
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private formatButton(text: string, active: boolean, click: () => void) {
    Text(text)
      .fontSize(18)
      .fontWeight(text === 'B' ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(active ? Color.White : '#20C894')
      .textAlign(TextAlign.Center)
      .width(48)
      .height(42)
      .backgroundColor(active ? '#20C894' : '#ECFAF6')
      .borderRadius(16)
      .onClick(click)
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(42).fontColor('#333333').width(48).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.label).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 })
        Blank().layoutWeight(1)
        Image($r('app.media.search')).width(27).height(27).margin({ right: 24 })
        Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(46).height(46).borderRadius(23).objectFit(ImageFit.Cover)
      }.width('100%').height(96).alignItems(VerticalAlign.Center).padding({ left: 14, right: 24 }).backgroundColor('#F5F6F8')

      Scroll() {
        Column() {
          Row() {
            Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(58).height(58).borderRadius(29).objectFit(ImageFit.Cover).margin({ right: 14 })
            Column() {
              Text(this.displayName).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#655C86')
              Text(this.college).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#999999').margin({ top: 4 })
            }.alignItems(HorizontalAlign.Start)
          }.width('100%').alignItems(VerticalAlign.Center).margin({ bottom: 16 })

          Column() {
            Row() {
              Image(this.avatarUrl || $r('app.media.ic_default_avatar')).width(46).height(46).borderRadius(23).objectFit(ImageFit.Cover).margin({ right: 12 })
              TextInput({ placeholder: '标题', text: this.title })
                .layoutWeight(1).height(52).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#333333')
                .placeholderColor('#AEB0B4').backgroundColor(Color.Transparent).padding(0)
                .onChange((value: string) => { this.title = value; })
            }.width('100%').alignItems(VerticalAlign.Center)

            if (this.editorExpanded) {
              TextArea({ placeholder: '分享校园里的新鲜事...', text: this.content })
                .width('100%').height(270).fontSize(19).fontColor('#333333').placeholderColor('#B4B5B8')
                .fontWeight(this.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontStyle(this.italic ? FontStyle.Italic : FontStyle.Normal)
                .decoration({ type: this.underline ? TextDecorationType.Underline : (this.strike ? TextDecorationType.LineThrough : TextDecorationType.None) })
                .backgroundColor(Color.Transparent).padding({ left: 58, right: 4, top: 4 })
                .onChange((value: string) => { this.content = value; })
            } else {
              Text(this.content || '分享校园里的新鲜事...').fontSize(18).fontColor(this.content ? '#555555' : '#B4B5B8').maxLines(2).width('100%').height(72).padding({ left: 58, top: 8 })
            }

            Row() {
              this.formatButton('B', this.bold, () => { this.bold = !this.bold; })
              this.formatButton('/', this.italic, () => { this.italic = !this.italic; })
              this.formatButton('U', this.underline, () => { this.underline = !this.underline; })
              this.formatButton('S', this.strike, () => { this.strike = !this.strike; })
              Text('图片').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20C894').textAlign(TextAlign.Center).width(72).height(42).backgroundColor('#ECFAF6').borderRadius(16).onClick(() => promptAction.showToast({ message: '图片功能待图标和上传接口接入', duration: 1400 }))
            }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 14 })

            Row() {
              Text(this.editorExpanded ? '收起' : '展开').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#666666').padding({ left: 24, right: 24, top: 12, bottom: 12 }).onClick(() => { this.editorExpanded = !this.editorExpanded; })
              Button(this.submitting ? '发布中…' : '发布').width(126).height(50).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor(this.submitting ? '#A9DED0' : '#20C894').borderRadius(25).onClick(() => this.submit())
            }.width('100%').justifyContent(FlexAlign.End).margin({ top: 14 })
          }.width('100%').padding({ left: 18, right: 18, top: 18, bottom: 16 }).backgroundColor(Color.White).borderRadius(22).shadow({ radius: 14, color: '#24000000', offsetX: 0, offsetY: 4 })
        }.width('100%').padding({ left: 20, right: 20, top: 22, bottom: 32 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F6F8')
  }
}
