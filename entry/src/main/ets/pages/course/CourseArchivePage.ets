import { ScheduleWidgetRefresh } from '../../widget/ScheduleWidgetRefresh';
import { router, promptAction } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { DynamicScheduleApi, readScheduleQrToken } from '../../net/DynamicScheduleApi';
import { CourseArchive, CourseData } from '../../model/CourseModel';
import { AppStorage as PreferencesStorage } from '../../store/AppStorage';

interface CourseArchiveParams {
  scanOnOpen?: boolean;
}

@Entry
@Component
struct CourseArchivePage {
  @State private archives: CourseArchive[] = [];
  @State private currentArchiveId: string = 'mine';

  @State private pendingArchive: CourseArchive | null = null;
  @State private relation: string = '情侣课表';
  private pendingEpoch: number = 0;
  @State private importing: boolean = false;
  private active: boolean = false;
  private scanOpened: boolean = false;
  // 连点两个档案时只允许第一个切换生效，避免把共享课表当成“我的课表”存回去。
  private switching: boolean = false;
  // 每次手动切换档案递增；导入过程中切过档案，旧导入结果必须丢弃。
  private archiveEpoch: number = 0;

  private termStartForSemester(semester: string): string {
    const parts = semester.split('-');
    if (parts.length < 3) return '';
    const year = Number(parts[0]);
    const term = parts[2].trim();
    if (!year) return '';
    const start = term === '1' ? new Date(year, 8, 1) : new Date(year + 1, 1, 15);
    while (start.getDay() !== 1) start.setDate(start.getDate() + 1);
    const mm = (start.getMonth() + 1).toString().padStart(2, '0');
    const dd = start.getDate().toString().padStart(2, '0');
    return `${start.getFullYear()}-${mm}-${dd}`;
  }

  async aboutToAppear(): Promise<void> {
    this.active = true;
    const storage = PreferencesStorage.getInstance();
    const saved = await storage.getCourseArchives();
    this.currentArchiveId = await storage.getCurrentArchiveId();
    this.archives = await this.withOwnArchive(saved);
  }

  private async withOwnArchive(saved: CourseArchive[]): Promise<CourseArchive[]> {
    const storage = PreferencesStorage.getInstance();
    const previous = saved.find(item => item.id === 'mine');
    const isMine = this.currentArchiveId === 'mine';
    const own: CourseArchive = {
      id: 'mine', name: '我的课表', isMine: true,
      semester: isMine ? await storage.getSemester() : (previous?.semester || await storage.getSemester()),
      termStartDate: isMine ? await storage.getTermStartDate() : previous?.termStartDate,
      courses: isMine ? await storage.getCurrentCourses() : (previous?.courses || [])
    };
    return [own, ...saved.filter(item => item.id !== 'mine')];
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

  private async switchArchive(archive: CourseArchive, returnToCourse: boolean = true): Promise<void> {
    if (this.switching || this.importing || this.pendingArchive) return;
    this.switching = true;
    this.archiveEpoch++;
    const storage = PreferencesStorage.getInstance();
    const epoch = storage.getSessionEpoch();
    try {
      await this.activateArchive(archive, epoch);
      if (epoch !== storage.getSessionEpoch() || !this.active) return;
      promptAction.showToast({ message: '已切换到' + this.archiveTitle(archive) });
      if (returnToCourse) router.back();
    } catch {
      promptAction.showToast({ message: '切换课表失败，请重试' });
    } finally {
      this.switching = false;
    }
  }

  private async activateArchive(archive: CourseArchive, epoch: number): Promise<void> {
    const storage = PreferencesStorage.getInstance();
    const saved = await storage.getCourseArchives();
    const archives = await this.withOwnArchive(saved);
    if (epoch !== storage.getSessionEpoch()) return;
    await storage.setCourseArchives(archives, epoch);
    const target = archives.find(item => item.id === archive.id) || archive;
    const start = target.termStartDate || (target.id === 'mine' ? '' : this.termStartForSemester(target.semester));
    if (!await storage.activateCourseArchive(target, start, epoch)) return;
    const courses = await storage.getCurrentCourses();
    if (epoch !== storage.getSessionEpoch()) return;
    this.archives = archives;
    this.currentArchiveId = target.id;
    AppStorage.setOrCreate('courseArchives', archives);
    AppStorage.setOrCreate('currentArchiveId', target.id);
    AppStorage.setOrCreate('currentCourses', courses);
    const version = AppStorage.get<number>('courseDataVersion') ?? 0;
    AppStorage.setOrCreate<number>('courseDataVersion', version + 1);
    ScheduleWidgetRefresh.run(getContext(this) as common.UIAbilityContext, epoch);
  }

  private confirmDelete(archive: CourseArchive): void {
    AlertDialog.show({
      title: '删除课表档案', message: '确认删除「' + this.archiveTitle(archive) + '」吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteArchive(archive); } }
    });
  }

  private async deleteArchive(archive: CourseArchive): Promise<void> {
    if (archive.id === 'mine' || this.switching || this.importing || this.pendingArchive) return;
    this.switching = true;
    this.archiveEpoch++;
    const storage = PreferencesStorage.getInstance();
    const epoch = storage.getSessionEpoch();
    try {
      if (await storage.getCurrentArchiveId() === archive.id) {
        const mine = this.archives.find(item => item.id === 'mine');
        if (!mine) return;
        await this.activateArchive(mine, epoch);
        if (this.currentArchiveId !== 'mine') return;
      }
      if (!await storage.removeCourseArchive(archive.id, epoch)) return;
      const next = await this.withOwnArchive(await storage.getCourseArchives());
      if (epoch !== storage.getSessionEpoch() || !this.active) return;
      this.archives = next;
      AppStorage.setOrCreate('courseArchives', next);
    } catch {
      promptAction.showToast({ message: '删除课表失败，请重试' });
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
    if (this.importing || this.switching || this.pendingArchive) return;
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
              ownerStudentId: parsed.ownerStudentId,
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
      if (!archive.termStartDate) archive.termStartDate = this.termStartForSemester(archive.semester);
      if (!this.active || accountEpoch !== storage.getSessionEpoch()) return;
      if (importEpoch !== this.archiveEpoch) {
        promptAction.showToast({ message: '档案已切换，请重新扫码导入', duration: 1800 });
        return;
      }
      this.pendingEpoch = accountEpoch;
      this.relation = '情侣课表';
      this.pendingArchive = archive;
    } catch (error) {
      promptAction.showToast({ message: (error as Error).message || '导入失败，请重试' });
    } finally {
      this.importing = false;
    }
  }

  private async saveImportedArchive(): Promise<void> {
    const archive = this.pendingArchive;
    if (!archive || this.importing) return;
    const storage = PreferencesStorage.getInstance();
    const epoch = this.pendingEpoch;
    this.importing = true;
    try {
      const saved = await storage.getCourseArchives();
      if (!this.active || epoch !== storage.getSessionEpoch()) return;
      const next = await this.withOwnArchive(saved.filter(item => item.id !== archive.id));
      archive.relation = this.relation;
      next.push(archive);
      await storage.setCourseArchives(next, epoch);
      if (!this.active || epoch !== storage.getSessionEpoch()) return;
      this.archives = next;
      AppStorage.setOrCreate('courseArchives', next);
      promptAction.showToast({ message: '已添加课表' });
      this.pendingArchive = null;
      if ((router.getParams() as CourseArchiveParams | undefined)?.scanOnOpen) router.back();
    } catch {
      promptAction.showToast({ message: '保存课表失败，请重试' });
    } finally {
      this.importing = false;
    }
  }

  private archiveTitle(archive: CourseArchive): string {
    return archive.isMine ? '我的课表' : archive.relation ? archive.relation + '（' + archive.name + '）' : archive.name;
  }

  private archiveColor(archive: CourseArchive): string {
    return archive.isMine ? '#438969' : archive.relation === '情侣课表' ? '#A25068' : '#666666';
  }

  @Builder
  private archiveCard(archive: CourseArchive) {
    Stack({ alignContent: Alignment.End }) {
      Image(archive.isMine ? $r('app.media.archive_sun') :
        archive.relation === '情侣课表' ? $r('app.media.archive_heart') : $r('app.media.archive_pin'))
        .width(66).height(66).fillColor(this.archiveColor(archive)).opacity(0.15).margin({ right: 24 })
      Column() {
        Row({ space: 8 }) {
          Text(this.archiveTitle(archive)).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.archiveColor(archive)).layoutWeight(1).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.currentArchiveId === archive.id) {
            Text('当前课表').fontSize(12).fontColor(Color.White).backgroundColor(this.archiveColor(archive))
              .borderRadius(14).padding({ left: 10, right: 10, top: 5, bottom: 5 })
          }
        }.width('100%')
        Text([archive.isMine ? '我的课表' : archive.relation || '共享课表', archive.semester,
          archive.isMine ? '' : archive.name].filter((value: string) => !!value).join(' · '))
          .fontSize(13).fontColor(this.archiveColor(archive)).margin({ top: 8 }).maxLines(2)
        Row({ space: 10 }) {
          Button(this.currentArchiveId === archive.id ? '显示中' : '显示')
            .fontSize(14).fontColor(Color.White).backgroundColor(this.archiveColor(archive))
            .opacity(this.currentArchiveId === archive.id ? 0.65 : 1).width(102).height(39)
            .enabled(this.currentArchiveId !== archive.id).onClick(() => { this.switchArchive(archive); })
          if (!archive.isMine) {
            Button('删除').fontSize(14).fontColor(this.archiveColor(archive)).backgroundColor('#FFFFFF')
              .width(102).height(39).onClick(() => { this.confirmDelete(archive); })
          }
        }.margin({ top: 14 })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
    }.width('100%').borderRadius(12)
      .backgroundColor(archive.isMine ? '#EAF7EE' : archive.relation === '情侣课表' ? '#FBEDEF' : '#F7F7F7')
      .shadow({ radius: 3, color: '#19000000', offsetY: 1 }).margin({ bottom: 12 })
  }

  @Builder
  private relationDialog(archive: CourseArchive) {
    Column({ space: 12 }) {
      Text('标记课表关系').fontSize(20).fontWeight(FontWeight.Bold)
      Text('姓名：' + archive.name).fontSize(14)
      if (archive.ownerStudentId) {
        Text('学号：' + archive.ownerStudentId).fontSize(14)
      }
      Text('学期：' + archive.semester).fontSize(14)
      Text('选择关系').fontSize(14).fontWeight(FontWeight.Medium).margin({ top: 4 })
      ForEach(['情侣课表', '同学课表', '朋友课表', '室友课表'], (label: string) => {
        Row({ space: 8 }) {
          Radio({ value: label, group: 'archiveRelation' }).checked(this.relation === label)
            .onChange((checked: boolean) => { if (checked) this.relation = label; })
          Text(label).fontSize(15)
        }.width('100%').onClick(() => { this.relation = label; })
      })
      Row({ space: 8 }) {
        Blank()
        Button('取消').backgroundColor(Color.Transparent).fontColor('#777777')
          .enabled(!this.importing).onClick(() => { this.pendingArchive = null; })
        Button('添加').backgroundColor('#16A978').fontColor(Color.White)
          .enabled(!this.importing).onClick(() => { this.saveImportedArchive(); })
      }.width('100%')
    }.alignItems(HorizontalAlign.Start).width('86%').padding(20)
      .backgroundColor(Color.White).borderRadius(16)
  }

  onBackPress(): boolean {
    if (!this.pendingArchive) return false;
    if (!this.importing) this.pendingArchive = null;
    return true;
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Button('←').fontSize(22).fontColor(Color.White).backgroundColor(Color.Transparent)
            .width(44).height(44).padding(0).accessibilityText('返回').onClick(() => router.back())
          Text('课表档案管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).layoutWeight(1)
          Button(this.importing ? '导入中' : '添加').fontSize(16).fontColor(Color.White)
            .backgroundColor(Color.Transparent).enabled(!this.importing).onClick(() => this.addArchiveByScan())
        }.width('100%').height(56).backgroundColor('#16B983').padding({ left: 8, right: 8 })
        Scroll() {
          Column() {
            ForEach(this.archives, (archive: CourseArchive) => {
              this.archiveCard(archive)
            }, (archive: CourseArchive) => archive.id + ':' + (archive.relation || '') + ':' + archive.semester)
          }.width('100%').padding(14)
        }.layoutWeight(1).width('100%').backgroundColor('#F4F5F6')
      }.width('100%').height('100%')
      if (this.pendingArchive) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor('#66000000')
          this.relationDialog(this.pendingArchive)
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%')
  }
}
