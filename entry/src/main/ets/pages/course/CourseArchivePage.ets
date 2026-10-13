import { router, promptAction } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import common from '@ohos.app.ability.common';
import { CourseArchive, getDefaultArchive } from '../../model/CourseModel';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';

@Entry
@Component
struct CourseArchivePage {
  @State private archives: CourseArchive[] = [];
  @State private currentArchiveId: string = 'mine';

  async aboutToAppear(): Promise<void> {
    const storage = PreferencesStorage.getInstance();
    const saved = await storage.getCourseArchives();
    this.archives = saved && saved.length > 0 ? saved : [getDefaultArchive()];
    await storage.setCourseArchives(this.archives);
    AppStorage.setOrCreate<CourseArchive[]>('courseArchives', this.archives);
    const currentId = await storage.getCurrentArchiveId();
    this.currentArchiveId = currentId || 'mine';
    const current = this.findArchive(this.currentArchiveId);
    if (current) {
      await storage.setCurrentCourses(current.courses);
      AppStorage.setOrCreate('currentCourses', current.courses);
    }
  }

  private findArchive(id: string): CourseArchive | undefined {
    for (let i = 0; i < this.archives.length; i++) {
      if (this.archives[i].id === id) {
        return this.archives[i];
      }
    }
    return undefined;
  }

  private async switchArchive(archive: CourseArchive): Promise<void> {
    this.currentArchiveId = archive.id;
    await PreferencesStorage.getInstance().setCurrentArchiveId(archive.id);
    await PreferencesStorage.getInstance().setCurrentCourses(archive.courses);
    AppStorage.setOrCreate('currentArchiveId', archive.id);
    AppStorage.setOrCreate('currentCourses', archive.courses);
    promptAction.showToast({ message: `已切换到${archive.name}`, duration: 1500 });
    setTimeout(() => router.back(), 800);
  }

  private async addArchiveByScan(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      });
      const content = result.originalValue;
      const parsed = JSON.parse(content) as CourseArchive;
      if (!parsed.name || !parsed.semester || !Array.isArray(parsed.courses) || parsed.courses.length === 0) {
        promptAction.showToast({ message: '二维码格式不正确', duration: 1500 });
        return;
      }
      const archive: CourseArchive = {
        id: `archive_${Date.now()}`,
        name: parsed.name,
        semester: parsed.semester,
        courses: parsed.courses,
        isMine: false
      };
      this.archives = [...this.archives, archive];
      await PreferencesStorage.getInstance().setCourseArchives(this.archives);
      AppStorage.setOrCreate<CourseArchive[]>('courseArchives', this.archives);
      promptAction.showToast({ message: `已添加${archive.name}`, duration: 1500 });
    } catch (err) {
      console.error('CourseArchivePage', `扫码或解析失败: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '扫码已取消或二维码格式错误', duration: 1500 });
    }
  }

  @Builder
  private archiveCard(archive: CourseArchive) {
    Column() {
      Row() {
        Column() {
          Text(archive.name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(archive.isMine ? '#4CAF50' : '#333333')
          Text(`${archive.name} · ${archive.semester}`)
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.currentArchiveId === archive.id) {
          Text('当前课表')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#81C784')
            .borderRadius(16)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        }
      }
      .width('100%')
      Button(this.currentArchiveId === archive.id ? '显示中' : '切换显示')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor(this.currentArchiveId === archive.id ? '#81C784' : '#4CAF50')
        .width(140)
        .height(44)
        .borderRadius(22)
        .margin({ top: 16 })
        .onClick(() => {
          if (this.currentArchiveId !== archive.id) {
            this.switchArchive(archive);
          }
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(archive.isMine ? '#E8F5E9' : '#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 12 })
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(24).fontColor('#FFFFFF').onClick(() => router.back())
        Text('课表档案管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text('添加').fontSize(18).fontColor('#FFFFFF').onClick(() => this.addArchiveByScan())
      }
      .width('100%').height(56).backgroundColor('#4CAF50').padding({ left: 16, right: 16 })
      Scroll() {
        Column() {
          ForEach(this.archives, (archive: CourseArchive) => {
            this.archiveCard(archive)
          }, (archive: CourseArchive) => archive.id)
          if (this.archives.length <= 1) {
            Text('未添加其他人课表').fontSize(16).fontColor('#CCCCCC').margin({ top: 60 })
          }
        }
        .width('100%').padding(16)
      }
      .layoutWeight(1).backgroundColor('#F5F5F5')
    }
    .width('100%').height('100%')
  }
}
