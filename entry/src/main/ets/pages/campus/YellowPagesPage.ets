import { router } from '@kit.ArkUI';
import { Want } from '@kit.AbilityKit';

interface YellowPageEntry {
  name: string;
  phone: string;
}

interface YellowPageGroup {
  title: string;
  icon: Resource;
  color: string;
  entries: YellowPageEntry[];
  expanded: boolean;
}

@Entry
@Component
export struct YellowPagesPage {
  @State private groups: YellowPageGroup[] = [
    { title: '学生常用', icon: $r('app.media.student_services'), color: '#16AAA8', expanded: false, entries: [
      { name: '保卫处1', phone: '027-68893272' }, { name: '保卫处2', phone: '027-68893392' },
      { name: '黄家湖校区综合办公室', phone: '027-68893276' }, { name: '洪山校区综合办公室', phone: '027-51012586' },
      { name: '教务处', phone: '027-68862468' }, { name: '后勤集团', phone: '027-68862221' },
      { name: '校园医院', phone: '027-68893271' }
    ] },
    { title: '党政部门', icon: $r('app.media.party_administrative_departments'), color: '#DD2B1C', expanded: false, entries: [
      { name: '学校办公室', phone: '027-68862478' }, { name: '黄家湖校区综合办公室', phone: '027-68893276' },
      { name: '洪山校区综合办公室', phone: '027-51012586' }, { name: '纪委（监察处）', phone: '027-68862473' },
      { name: '党委组织部（机关党委）', phone: '027-68862793' }, { name: '党委宣传部', phone: '027-68862589' },
      { name: '党委学生工作部（武装部、学生工作室）', phone: '027-68862673' }, { name: '工会（妇委会、教代会）', phone: '027-68863508' },
      { name: '团委', phone: '027-68862339' }
    ] },
    { title: '行政部门', icon: $r('app.media.administrative_departments'), color: '#7DBB58', expanded: false, entries: [
      { name: '研究生学位与学科建设处', phone: '027-68862605' }, { name: '研究生培养教育处', phone: '027-68862116' },
      { name: '研究生招生就业处', phone: '027-68862630' }, { name: '人事处', phone: '027-68862406' },
      { name: '教务处', phone: '027-68862468' }, { name: '教学质量监控与评估处', phone: '027-68862505' },
      { name: '发展规划处（高等教育研究所）', phone: '027-68862410' }, { name: '财务处', phone: '027-68862458' },
      { name: '审计处', phone: '027-68862466' }, { name: '国有资产与实验室管理处', phone: '027-68862502' },
      { name: '基建与后勤管理处', phone: '027-68862819' }, { name: '国际交流合作处', phone: '027-68862606' },
      { name: '离退休工作处（离退休党总支）', phone: '027-68864266' }, { name: '保卫处（党委保卫部）', phone: '027-68862202' },
      { name: '教职工住宅建设与改革领导小组办公室', phone: '027-68862635' }, { name: '采购与招标管理办公室', phone: '027-68862385' }
    ] },
    { title: '直属部门', icon: $r('app.media.directly_affiliated_departments'), color: '#EAB52B', expanded: false, entries: [
      { name: '工程训练中心', phone: '027-68863669' }, { name: '现代教育训练中心', phone: '027-68862211' },
      { name: '图书馆', phone: '027-68862320' }, { name: '档案馆', phone: '027-68862017' },
      { name: '学报编辑部', phone: '027-68862317' }, { name: '后勤集团', phone: '027-68862221' },
      { name: '资产经营有限公司（科技园有限责任公司）', phone: '027-68862221' }, { name: '校园医院', phone: '027-68893271' },
      { name: '耐火材料与冶金炉窑国家重点实验室', phone: '027-68862405' }, { name: '国家硅钢工程研究院', phone: '027-68862772' },
      { name: '绿色制造与节能减排中心', phone: '027-68862815' }, { name: '继续教育学院（职业技术学院）', phone: '027-51012585' },
      { name: '时属黄天佑医院（临床学院）', phone: '027-87891586' }
    ] }
  ];

  private toggle(index: number): void {
    const next: YellowPageGroup[] = [];
    for (let i = 0; i < this.groups.length; i++) {
      const group = this.groups[i];
      next.push({ title: group.title, icon: group.icon, color: group.color, entries: group.entries, expanded: i === index ? !group.expanded : group.expanded });
    }
    this.groups = next;
  }

  private dial(phone: string): void {
    const want: Want = {
      action: 'ohos.want.action.dial',
      uri: `tel:${phone}`
    };
    try {
      const context = getContext(this);
      context.startAbility(want).catch(() => {
        console.warn('YellowPagesPage', `无法打开拨号界面: ${phone}`);
      });
    } catch {
      console.warn('YellowPagesPage', `拨号调用失败: ${phone}`);
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(38).fontColor('#333333').onClick(() => router.back())
        Text('黄页').fontSize(24).fontWeight(FontWeight.Bold).margin({ left: 14 })
      }.width('100%').height(76).padding({ left: 20 }).backgroundColor(Color.White)

      Scroll() {
        Column() {
          ForEach(this.groups, (group: YellowPageGroup, index: number) => {
            Column() {
              Row() {
                Image(group.icon).width(58).height(58)
                Text(group.title).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#666666').layoutWeight(1).margin({ left: 24 })
                Text(group.expanded ? '⌃' : '⌄').fontSize(34).fontColor('#666666').width(52).textAlign(TextAlign.Center)
              }.width('100%').height(102).onClick(() => this.toggle(index))
              if (group.expanded) {
                Column() {
                  ForEach(group.entries, (entry: YellowPageEntry) => {
                    Row() {
                      Image($r('app.media.calling')).width(22).height(22).margin({ right: 12 })
                      Text(entry.name).fontSize(18).fontColor('#444444').layoutWeight(1)
                      Text(entry.phone).fontSize(17).fontColor(group.color)
                    }.width('100%').height(48).padding({ left: 82, right: 18 })
                      .onClick(() => this.dial(entry.phone))
                  })
                }.width('100%').backgroundColor('#FAFAFA').transition(TransitionEffect.OPACITY)
              }
              Divider().color('#DDDDDD').height(1).margin({ left: 82 })
            }.width('100%')
          })
        }.width('100%').padding({ left: 34, right: 34, top: 18 })
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#FAFAFA')
  }
}
