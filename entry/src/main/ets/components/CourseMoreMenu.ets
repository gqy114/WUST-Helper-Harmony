/**
 * CourseMoreMenu - 课表右上角“更多”菜单。
 */
interface MenuItem {
  icon: Resource;
  text: string;
  hasCheckbox: boolean;
}

@Component
export struct CourseMoreMenu {
  @Prop onlyThisWeek: boolean = false;
  onMenuItemClick: (index: number) => void = () => {};
  onClose: () => void = () => {};

  private menuItems: MenuItem[] = [
    { icon: $r('app.media.visible'), text: '只显示本周课程', hasCheckbox: true },
    { icon: $r('app.media.semester'), text: '选择课程学期', hasCheckbox: false },
    { icon: $r('app.media.campus'), text: '设置校区', hasCheckbox: false },
    { icon: $r('app.media.edit_week'), text: '修改本周时间', hasCheckbox: false },
    { icon: $r('app.media.calendar'), text: '切换课表档案', hasCheckbox: false },
    { icon: $r('app.media.schedule_settings'), text: '课表与日程', hasCheckbox: false },
    { icon: $r('app.media.set_background'), text: '背景与字体', hasCheckbox: false },
  ];

  build() {
    Column() {
      ForEach(this.menuItems, (item: MenuItem, index: number) => {
        Row() {
          Image(item.icon)
            .width(20)
            .height(20)
            .fillColor('#666666')
            .margin({ right: 12 })

          Text(item.text)
            .fontSize(15)
            .fontColor('#333333')
            .layoutWeight(1)

          if (item.hasCheckbox) {
            Checkbox({ name: 'onlyThisWeek' })
              .select(this.onlyThisWeek)
              .selectedColor('#4CAF50')
              .enabled(false)
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          if (item.hasCheckbox) {
            this.onMenuItemClick(0);
          } else {
            this.onMenuItemClick(index);
            this.onClose();
          }
        })
      }, (item: MenuItem, index: number) => index.toString())
    }
    .width(260)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding({ top: 8, bottom: 8 })
    .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
  }
}
