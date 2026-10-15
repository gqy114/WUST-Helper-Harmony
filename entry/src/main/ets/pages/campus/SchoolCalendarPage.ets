import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpRequest } from '../../net/HttpRequest';

interface CalendarResponse { code?: number; data?: string; message?: string; }

@Entry @Component
struct SchoolCalendarPage {
  @State private calendarUrl: string = '';
  @State private loading: boolean = true;
  @State private failed: boolean = false;

  aboutToAppear(): void { this.loadCalendar(); }
  private async loadCalendar(): Promise<void> {
    this.loading = true; this.failed = false;
    try {
      const result = await HttpRequest.get<CalendarResponse>('https://www.lyzyy.love/admin/common/getCalendar');
      if ((result.data.code === 200 || result.data.code === 0) && result.data.data) { this.calendarUrl = result.data.data; }
      else { this.failed = true; }
    } catch { this.failed = true; }
    this.loading = false;
  }
  build() {
    Column() {
      Row() { Text('‹').fontSize(42).width(48).textAlign(TextAlign.Center).onClick(() => router.back()); Text('学校校历').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }); Blank().layoutWeight(1); Text('刷新').fontSize(17).fontColor('#20B984').onClick(() => this.loadCalendar()); }.width('100%').height(76).padding({ left: 14, right: 20 }).backgroundColor(Color.White);
      if (this.loading) { LoadingProgress().width(40).height(40).layoutWeight(1).margin({ top: 30 }); }
      else if (this.failed || !this.calendarUrl) { Column() { Text('校历加载失败').fontSize(18).fontColor('#666666'); Text('请检查网络后重试').fontSize(14).fontColor('#AAAAAA').margin({ top: 8 }); Button('重新加载').backgroundColor('#1EC98D').fontColor(Color.White).margin({ top: 18 }).onClick(() => this.loadCalendar()); }.layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center); }
      else { Scroll() { Column() { Image(this.calendarUrl).width('100%').objectFit(ImageFit.Contain).onComplete(() => { promptAction.showToast({ message: '校历加载完成', duration: 800 }); }).onError(() => { this.failed = true; }); }.width('100%').padding(12); }.layoutWeight(1); }
    }.width('100%').height('100%').backgroundColor('#F5F6F8');
  }
}
