import router from '@ohos.router';
import { ClassroomApi } from '../../net/ClassroomApi';
import { CourseStore } from '../../store/CourseStore';
import { promptAction } from '@kit.ArkUI';

interface ClassroomReportedCourse {
  classroom: string;
  weekDay: number;
  startWeek: number;
  endWeek: number;
  startSection: number;
  endSection: number;
  courseName: string;
  teacher: string;
}
@Entry @Component
struct ClassroomResultPage {
  @State private rooms: string[] = [];
  @State private loading: boolean = true;
  @State private error: string = '';
  private params: Record<string, string> = {};
  aboutToAppear(): void { this.params = router.getParams() as Record<string, string>; this.loadRooms(); }
  private async loadRooms(): Promise<void> { this.loading = true; try { const storage = (await import('../../store/AppStorage')).AppStorage.getInstance(); const semester = await storage.getSemester(); const courses: ClassroomReportedCourse[] = CourseStore.getInstance().courses.filter((item) => item.location).map((item): ClassroomReportedCourse => ({ classroom: item.location, weekDay: item.dayOfWeek, startWeek: 1, endWeek: 25, startSection: item.startPeriod, endSection: item.endPeriod, courseName: item.courseName, teacher: item.teacher })); await ClassroomApi.reportCourses(semester, courses); this.rooms = await ClassroomApi.query(this.params); } catch (error) { this.error = error instanceof Error ? error.message : '空教室查询失败'; promptAction.showToast({ message: this.error, duration: 1800 }); } finally { this.loading = false; } }
  build() { Column() { Row() { Text('‹').fontSize(36).fontColor(Color.White).width(36).onClick(() => router.back()); Text('空教室结果').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 12 }); Blank().layoutWeight(1); Text('调整筛选').fontSize(16).fontColor(Color.White).onClick(() => router.back()); }.width('100%').height(56).padding({ left: 16, right: 16 }).alignItems(VerticalAlign.Center).backgroundColor('#23C087'); Scroll() { if (this.loading) { Text('正在查询空教室…').fontSize(16).fontColor('#999999').layoutWeight(1); } else if (this.error.length > 0) { Text(this.error).fontSize(18).fontColor('#999999').layoutWeight(1); } else { Column() { Text(`${this.rooms.length} 间空教室`).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#203C35').width('100%'); Text(`第 ${this.params.startWeek || '1'} 周 · ${this.params.weekday || '周一'} · 第 ${this.params.startPeriod || '1'} 节`).fontSize(16).fontColor('#168C68').width('100%').padding(16).backgroundColor('#E8F7F0').borderRadius(18).margin({ top: 18 }); Grid() { ForEach(this.rooms, (room: string) => GridItem() { Text(room).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#203C35').textAlign(TextAlign.Center).width('100%').height(80).backgroundColor(Color.White).borderRadius(16); }, (room: string) => room); }.columnsTemplate('1fr 1fr').columnsGap(14).rowsGap(14).margin({ top: 20 }); }.width('100%').padding(24); } }.layoutWeight(1).scrollBar(BarState.Off); }.width('100%').height('100%').backgroundColor('#F5F6F8'); }
}
