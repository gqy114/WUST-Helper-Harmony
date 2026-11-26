import { router, promptAction } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { DynamicScheduleApi, readScheduleQrToken } from '../../net/DynamicScheduleApi';
import { CourseArchive, CourseData, getDefaultArchive } from '../../model/CourseModel';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';

interface CourseArchiveParams {
  scanOnOpen?: boolean;
}

@Entry
@Component
struct CourseArchivePage {
  @State private archives: CourseArchive[] = [];
  @State private currentArchiveId: string = 'mine';

  @State private importing: boolean = false;
  private active: boolean = false;
  private scanOpened: boolean = false;
  // 连点两个档案时只允许第一个切换生效，避免把共享课表当成“我的课表”存回去。
  private switching: boolean = false;
  // 每次手动切换档案递增；导入过程中切过档案，旧导入结果必须丢弃。
  private archiveEpoch: number = 0;

  async aboutToAppear(): Promise<void> {
    this.active = true;
    const storage = PreferencesStorage.getInstance();
    const saved = await storage.getCourseArchives();
    this.archives = saved && saved.length > 0 ? saved : [getDefaultArchive()];
    this.currentArchiveId = await storage.getCurrentArchiveId();
  }

  onPageShow(): void {
    const params = router.getParams() as CourseArchiveParams | undefined;
    if (params?.scanOnOpen && !this.scanOpened) {
      this.scanOpened = true;
      this.addArchiveByScan();
    }
  }

  aboutToDisappear(): void {
    this.active = false;
  }

  private async switchArchive(archive: CourseArchive): Promise<void> {
    if (this.switching) return;
    this.switching = true;
    this.archiveEpoch++;
    const storage = PreferencesStorage.getInstance();
    try {
    if (this.currentArchiveId === 'mine') {
      const myCourses = await storage.getCurrentCourses();
      const semester = await storage.getSemester();
      const mine: CourseArchive = {
        id: 'mine', name: '我的课表', semester, termStartDate: await storage.getTermStartDate(),
        courses: myCourses, isMine: true
      };
      this.archives = this.archives.map((item: CourseArchive) => item.id === 'mine' ? mine : item);
      await storage.setCourseArchives(this.archives);
    }

    await storage.setCurrentArchiveId(archive.id);
    await storage.setCurrentArchiveCourses(archive.id, archive.courses);
    this.currentArchiveId = archive.id;
    AppStorage.setOrCreate('currentArchiveId', archive.id);
    AppStorage.setOrCreate('currentCourses', archive.courses);
    const version = AppStorage.get<number>('courseDataVersion') ?? 0;
    AppStorage.setOrCreate<number>('courseDataVersion', version + 1);
    promptAction.showToast({ message: `已切换到${archive.name}`, duration: 1500 });
    setTimeout(() => router.back(), 800);
    } finally {
      this.switching = false;
    }
  }

  /** 解析分享页生成的紧凑课表（WUSTC1|学期|名称|课程…），保留物理实验信息。 */
  static parseCompact(content: string): CourseArchive | null {
    const parts = content.split('|');
    if (parts.length < 4 || parts[0] !== 'WUSTC1') return null;
    const semester = parts[1].trim();
    const name = parts[2].trim();
    const rows = parts[3].split(';').filter((row: string) => row.trim().length > 0);
    if (!name || !semester || rows.length === 0) return null;
    const courses: CourseData[] = [];
    for (let i = 0; i < rows.length; i++) {
      const fields = rows[i].split('~');
      if (fields.length < 7) return null;
      const course: CourseData = {
        courseName: fields[0],
        teacher: fields[1],
        dayOfWeek: Number(fields[2]) || 0,
        startPeriod: Number(fields[3]) || 0,
        endPeriod: Number(fields[4]) || 0,
        weekRanges: fields[5],
        location: fields[6]
      };
      if (fields.length >= 9 && fields[7] === '1') {
        course.isPhysicalExperiment = true;
        course.physicalDate = fields[8];
      }
      courses.push(course);
    }
    return { id: `archive_${Date.now()}`, name, semester, courses, isMine: false };
  }

  private async scanOnce(context: common.UIAbilityContext): Promise<string> {
    const result = await scanBarcode.startScanForResult(context, {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableMultiMode: false,
      enableAlbum: true
    });
    return result.originalValue;
  }

  /** 收集一张或多张二维码（WUSTC2|i/n|片段），拼回完整内容。 */
  private async collectQrContent(context: common.UIAbilityContext): Promise<string> {
    const parts: string[] = [];
    let total = 0;
    let shareId = '';
    for (let round = 0; round < 12; round++) {
      const content = await this.scanOnce(context);
      if (!content.startsWith('WUSTC2|')) {
        return total === 0 ? content.trim() : '';
      }
      const match = /^WUSTC2\|([0-9a-z]+)\|(\d+)\/(\d+)\|([\s\S]*)$/.exec(content);
      if (!match) return '';
      const scannedId = match[1];
      const index = Number(match[2]);
      const count = Number(match[3]);
      if (count < 1 || count > 9 || index < 1 || index > count) return '';
      // 不同课表的二维码不能混扫，否则会拼出一份混合课表。
      if (shareId && (scannedId !== shareId || count !== total)) {
        promptAction.showToast({ message: '这些二维码不属于同一份课表，请重新扫码', duration: 2200 });
        return '';
      }
      shareId = scannedId;
      total = count;
      parts[index - 1] = match[4];
      let collected = 0;
      for (let i = 0; i < total; i++) {
        if (parts[i] !== undefined && parts[i].length >= 0) collected++;
      }
      if (collected < total) {
        promptAction.showToast({
          message: `已扫描 ${collected}/${total} 张，请继续扫描下一张`,
          duration: 1800
        });
        continue;
      }
      return parts.join('');
    }
    return '';
  }

  private async addArchiveByScan(): Promise<void> {
    if (this.importing) return;
    this.importing = true;
    const storage = PreferencesStorage.getInstance();
    const accountEpoch = storage.getSessionEpoch();
    // 导入期间用户可能切换到别的档案；记录代次，写回前校验。
    const importEpoch = this.archiveEpoch;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const permission = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context,
        ['ohos.permission.CAMERA']);
      if (permission.authResults[0] !== 0) {
        promptAction.showToast({ message: '需要相机权限才能扫码' });
        return;
      }

      let content: string;
      try {
        content = await this.collectQrContent(context);
      } catch {
        promptAction.showToast({ message: '扫码已取消或无法读取二维码' });
        return;
      }
      if (!content) {
        promptAction.showToast({ message: '二维码不完整，请重新扫码' });
        return;
      }

      let archive: CourseArchive | null = null;
      if (content.toLowerCase().startsWith('wusthelper://')) {
        const token = readScheduleQrToken(content);
        if (!token) {
          promptAction.showToast({ message: '课表二维码无效，请让分享人重新生成' });
          return;
        }
        archive = await DynamicScheduleApi.redeemInvite(token);
      } else if (content.startsWith('WUSTC1|')) {
        archive = CourseArchivePage.parseCompact(content);
      } else if (content.startsWith('{')) {
        try {
          const parsed = JSON.parse(content) as CourseArchive;
          if (parsed?.name && parsed.semester && Array.isArray(parsed.courses) && parsed.courses.length > 0) {
            archive = {
              id: 'archive_' + Date.now(),
              name: parsed.name,
              semester: parsed.semester,
              courses: parsed.courses,
              isMine: false
            };
          }
        } catch {
          archive = null;
        }
      }
      if (!archive) {
        promptAction.showToast({ message: '这不是有效的课表二维码' });
        return;
      }
      if (!archive.termStartDate) archive.termStartDate = PreferencesStorage.archiveTermStartForSemester(archive.semester);
      if (!this.active || accountEpoch !== storage.getSessionEpoch()) return;
      if (importEpoch !== this.archiveEpoch) {
        promptAction.showToast({ message: '档案已切换，请重新扫码导入', duration: 1800 });
        return;
      }
      const archives = await storage.getCourseArchives();
      if (!this.active || accountEpoch !== storage.getSessionEpoch()) return;
      if (importEpoch !== this.archiveEpoch) {
        promptAction.showToast({ message: '档案已切换，请重新扫码导入', duration: 1800 });
        return;
      }
      const next = archives.filter((item: CourseArchive) => item.id !== archive?.id);
      if (next.length === 0) next.push(getDefaultArchive());
      next.push(archive);
      await storage.setCourseArchives(next, accountEpoch);
      if (!this.active || accountEpoch !== storage.getSessionEpoch()) return;
      if (importEpoch !== this.archiveEpoch) return;
      this.archives = next;
      AppStorage.setOrCreate<CourseArchive[]>('courseArchives', next);
      promptAction.showToast({ message: '已添加课表，可在档案中切换显示' });
    } catch (error) {
      promptAction.showToast({ message: (error as Error).message || '导入失败，请重试' });
    } finally {
      this.importing = false;
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
        Text(this.importing ? '导入中' : '添加').fontSize(18).fontColor('#FFFFFF')
          .enabled(!this.importing).onClick(() => this.addArchiveByScan())
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
