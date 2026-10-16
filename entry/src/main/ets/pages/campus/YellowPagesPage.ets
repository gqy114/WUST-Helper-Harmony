import { router } from '@kit.ArkUI';

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
      { name: '学生工作处', phone: '027-68862879' }, { name: '教务处', phone: '027-68862896' }
    ] },
    { title: '党政部门', icon: $r('app.media.party_administrative_departments'), color: '#DD2B1C', expanded: false, entries: [
      { name: '党委办公室', phone: '027-68862111' }, { name: '纪委办公室', phone: '027-68862112' }
    ] },
    { title: '行政部门', icon: $r('app.media.administrative_departments'), color: '#7DBB58', expanded: false, entries: [
      { name: '校长办公室', phone: '027-68862111' }, { name: '财务处', phone: '027-68862113' }
    ] },
    { title: '直属部门', icon: $r('app.media.directly_affiliated_departments'), color: '#EAB52B', expanded: false, entries: [
      { name: '图书馆', phone: '027-68862818' }, { name: '网络中心', phone: '027-68862120' }
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
                      Text(entry.name).fontSize(18).fontColor('#444444').layoutWeight(1)
                      Text(entry.phone).fontSize(17).fontColor(group.color)
                    }.width('100%').height(48).padding({ left: 82, right: 18 })
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
