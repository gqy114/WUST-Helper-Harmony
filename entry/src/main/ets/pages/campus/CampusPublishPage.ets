import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { CampusWallApi } from '../../net/CampusWallApi';
import { CampusCatApi } from '../../net/CampusCatApi';
import { AppStorage } from '../../store/AppStorage';

interface PublishParams { tag?: string; label?: string; }
interface LostFoundExtra { type: string; address: string; }
interface TeamExtra { type: string; }

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
  @State private address: string = '';
  @State private lostFoundType: string = 'found';
  @State private teamType: string = 'leader';
  @State private catTags: string[] = [];

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
    if (this.tag === 'team') return '竞赛组队';
    if (this.tag === 'help') return '求助';
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
      let publishTag = this.tag;
      let extra = '{}';
      if (this.tag === 'lost') {
        publishTag = 'lost_found';
        const lostFoundExtra: LostFoundExtra = { type: this.lostFoundType, address: this.address.trim() };
        extra = JSON.stringify(lostFoundExtra);
      } else if (this.tag === 'team') {
        const teamExtra: TeamExtra = { type: this.teamType };
        extra = JSON.stringify(teamExtra);
      }
      await CampusWallApi.publish(this.title.trim(), this.content.trim(), publishTag, extra);
      promptAction.showToast({ message: '发布成功', duration: 1200 });
      router.back();
    } catch {
      promptAction.showToast({ message: '发布失败，请检查登录状态后重试', duration: 1500 });
    } finally {
      this.submitting = false;
    }
  }

  private toggleCatTag(tag: string): void {
    const selected = this.catTags.indexOf(tag) >= 0;
    this.catTags = selected ? this.catTags.filter((item: string) => item !== tag) : this.catTags.concat([tag]);
  }

  private async submitCat(): Promise<void> {
    if (this.submitting) return;
    if (!this.title.trim() || !this.content.trim()) {
      promptAction.showToast({ message: '请填写标题和正文', duration: 1200 });
      return;
    }
    this.submitting = true;
    try {
      await CampusCatApi.publish(this.title.trim(), this.content.trim(), this.catTags);
      promptAction.showToast({ message: '发布成功', duration: 1200 });
      router.back();
    } catch {
      promptAction.showToast({ message: '发布失败，请稍后重试', duration: 1500 });
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private catComposer() {
    Column() {
      Column() {
        Text('发布校园猫帖子').fontSize(27).fontWeight(FontWeight.Bold).fontColor('#444444').margin({ bottom: 24 })
        TextInput({ placeholder: '标题', text: this.title }).width('100%').height(70).fontSize(20).fontWeight(FontWeight.Bold).placeholderColor('#A9AAAD').backgroundColor('#F6F6F6').borderRadius(16).padding({ left: 18, right: 18 }).onChange((value: string) => { this.title = value; })
        TextArea({ placeholder: '正文', text: this.content }).width('100%').height(160).fontSize(19).placeholderColor('#A9AAAD').backgroundColor('#F6F6F6').borderRadius(16).padding(18).margin({ top: 14 }).onChange((value: string) => { this.content = value; })
        Text('类型（可多选）').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#333333').width('100%').margin({ top: 20, bottom: 10 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['流浪', '领养', '日常', '求助', '晒猫'], (tag: string) => {
            Text(tag).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.catTags.indexOf(tag) >= 0 ? Color.White : '#707070').textAlign(TextAlign.Center).width(92).height(48).backgroundColor(this.catTags.indexOf(tag) >= 0 ? '#20C894' : '#ECF8F4').borderRadius(16).margin({ right: 10, bottom: 10 }).onClick(() => this.toggleCatTag(tag))
          })
        }.width('100%')
        Text('+  添加图片（最多 9 张，每张小于 5MB）').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#666666').width('100%').height(64).textAlign(TextAlign.Center).backgroundColor('#ECF8F4').borderRadius(16).margin({ top: 4 }).onClick(() => promptAction.showToast({ message: '图片功能待图片选择图标和上传流程接入', duration: 1500 }))
        Row() {
          Button('取消').layoutWeight(1).height(58).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor('#E26B58').borderRadius(10).margin({ right: 18 }).onClick(() => router.back())
          Button(this.submitting ? '发布中…' : '发布').layoutWeight(1).height(58).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor(this.submitting ? '#A4DDBB' : '#55D900').borderRadius(10).onClick(() => this.submitCat())
        }.width('100%').margin({ top: 24 })
      }.width('84%').padding({ left: 26, right: 26, top: 28, bottom: 30 }).backgroundColor(Color.White).borderRadius(24)
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).backgroundColor('#66000000')
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
    if (this.tag === 'cat') {
      this.catComposer()
    } else {
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
            Blank().layoutWeight(1)
            if (this.tag === 'lost') {
              Text(this.lostFoundType === 'found' ? '失物招领' : '寻物启事').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#B54D6B').backgroundColor('#FFF0F3').borderRadius(20).padding({ left: 18, right: 18, top: 9, bottom: 9 })
            } else if (this.tag === 'team') {
              Column() {
                Text(this.teamType === 'leader' ? '找队友' : '找队伍').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#2D75A7').backgroundColor('#E7F4FF').borderRadius(20).padding({ left: 18, right: 18, top: 9, bottom: 9 })
                Text('等待回应').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(18).padding({ left: 16, right: 16, top: 7, bottom: 7 }).margin({ top: 6 })
              }.alignItems(HorizontalAlign.End)
            } else if (this.tag === 'help') {
              Column() {
                Text('待解决').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#B06C18').backgroundColor('#FFF3DF').borderRadius(20).padding({ left: 18, right: 18, top: 9, bottom: 9 })
                Text('等待回答').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#777777').backgroundColor('#F1F2F4').borderRadius(18).padding({ left: 16, right: 16, top: 7, bottom: 7 }).margin({ top: 6 })
              }.alignItems(HorizontalAlign.End)
            }
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
              TextArea({ placeholder: this.tag === 'lost' ? '描述物品特征、时间等信息...' : (this.tag === 'team' ? '说明比赛、方向、需求和联系方式...' : (this.tag === 'help' ? '描述你需要求助的问题...' : '分享校园里的新鲜事...')), text: this.content })
                .width('100%').height(270).fontSize(19).fontColor('#333333').placeholderColor('#B4B5B8')
                .fontWeight(this.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontStyle(this.italic ? FontStyle.Italic : FontStyle.Normal)
                .decoration({ type: this.underline ? TextDecorationType.Underline : (this.strike ? TextDecorationType.LineThrough : TextDecorationType.None) })
                .backgroundColor(Color.Transparent).padding({ left: 58, right: 4, top: 4 })
                .onChange((value: string) => { this.content = value; })
            } else {
              Text(this.content || (this.tag === 'lost' ? '描述物品特征、时间等信息...' : (this.tag === 'team' ? '说明比赛、方向、需求和联系方式...' : (this.tag === 'help' ? '描述你需要求助的问题...' : '分享校园里的新鲜事...')))).fontSize(18).fontColor(this.content ? '#555555' : '#B4B5B8').maxLines(2).width('100%').height(72).padding({ left: 58, top: 8 })
            }

            if (this.tag === 'lost') {
              Row() {
                Text('地址：').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555')
                TextInput({ placeholder: '具体地址', text: this.address }).layoutWeight(1).height(48).fontSize(18).fontColor('#444444').placeholderColor('#AAAAAA').backgroundColor(Color.Transparent).padding(0).border({ width: { bottom: 1 }, color: '#CCCCCC' }).onChange((value: string) => { this.address = value; })
              }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 4 })
              Row() {
                Text('类型：').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555').margin({ right: 8 })
                Text('失物招领').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.lostFoundType === 'found' ? '#14B888' : '#77D8BC').backgroundColor(this.lostFoundType === 'found' ? '#E6F8F2' : '#F1FAF7').borderRadius(18).padding({ left: 18, right: 18, top: 10, bottom: 10 }).margin({ right: 10 }).onClick(() => { this.lostFoundType = 'found'; })
                Text('寻物启事').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.lostFoundType === 'lost' ? '#14B888' : '#77D8BC').backgroundColor(this.lostFoundType === 'lost' ? '#E6F8F2' : '#F1FAF7').borderRadius(18).padding({ left: 18, right: 18, top: 10, bottom: 10 }).onClick(() => { this.lostFoundType = 'lost'; })
              }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 10 })
            } else if (this.tag === 'team') {
              Row() {
                Text('类型：').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#555555').margin({ right: 8 })
                Text('找队友').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.teamType === 'leader' ? '#14B888' : '#77D8BC').backgroundColor(this.teamType === 'leader' ? '#E6F8F2' : '#F1FAF7').borderRadius(18).padding({ left: 18, right: 18, top: 10, bottom: 10 }).margin({ right: 10 }).onClick(() => { this.teamType = 'leader'; })
                Text('找队伍').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.teamType === 'member' ? '#14B888' : '#77D8BC').backgroundColor(this.teamType === 'member' ? '#E6F8F2' : '#F1FAF7').borderRadius(18).padding({ left: 18, right: 18, top: 10, bottom: 10 }).onClick(() => { this.teamType = 'member'; })
              }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 10 })
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
}
