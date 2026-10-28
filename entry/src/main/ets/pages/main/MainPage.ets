/**
 * MainPage.ets — 主页（4-Tab 底部导航）
 *
 * 迁移来源：MainMvpActivity.java + activity_main.xml
 * 文件路径：entry/src/main/ets/pages/main/MainPage.ets
 */
import { AppStorage } from '../../store/AppStorage';
import { RouterUtil } from '../../utils/RouterUtil';
import { common } from '@kit.AbilityKit';
import { CoursePage } from '../course/CoursePage';
import { MinePage } from '../mine/MinePage';
import { VolunteerPage } from '../volunteer/VolunteerPage';
import { CampusPage } from '../campus/CampusPage';
import { ApiService } from '../../net/ApiService';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { HomeBanner, HomeContentApi, HomeNotice } from '../../net/HomeContentApi';
import { TeachingSessionService } from '../../service/TeachingSessionService';

// ═══════════════════════════════════════════════ 常量 ═══════════════════════════════════════════════

const TAG = 'MainPage';


enum TabIndex { HOME = 0, VOLUNTEER = 1, COURSE = 2, CAMPUS = 3, MINE = 4 }

const TAB_LABELS: string[] = ['主页', '志愿者', '课表', '校园', '个人'];


/** 双击退出间隔 (ms) */
const EXIT_INTERVAL = 2000;

interface CardItem {
  title: string;
  desc: string;
  bgColor: string;
  titleColor: string;
  icon: Resource;
  rotated?: boolean;
  route?: string;
  url?: string;
  onCardClick?: () => void;
}

//热门功能2列Grid数组：倒计时、图书馆、培养方案、教室查询、双创学分、AI问答、主修进度
const hotFuncList: CardItem[] = [
  { title: "倒计时", desc: "鸽子模拟器 咕咕咕", bgColor: "#E3F2FD", titleColor: "#3949ab", icon: $r('app.media.ic_countdown'), route: "pages/countdown/CountdownPage" },
  { title: "图书馆", desc: "检索借阅与图书", bgColor: "#FFE5E5", titleColor: "#e53935", icon: $r('app.media.ic_library_normal'), route: "pages/library/LibraryPage" },
  { title: "培养方案", desc: "掌握修读情况", bgColor: "#FFF3E0", titleColor: "#f57c00", icon: $r('app.media.ic_credit'), route: "pages/campus/TrainingPlanPage" },
  { title: "教室查询", desc: "空教室与课程", bgColor: "#F3E5F5", titleColor: "#7b1fa2", icon: $r('app.media.ic_emptyroom'), route: "pages/campus/ClassroomQueryPage" },
  { title: "双创学分", desc: "创新创业学分", bgColor: "#E0F7FA", titleColor: "#009688", icon: $r('app.media.ic_double_create_credit'), route: "pages/common/WebPage", url: "" },
  { title: "AI问答", desc: "智能问答助手", bgColor: "#E8EAF6", titleColor: "#5c6bc0", icon: $r('app.media.ic_ai_chat'), route: "pages/ai/AIAssistantPage" },
  { title: "主修进度", desc: "学分完成情况", bgColor: "#F5E5DC", titleColor: "#8d6e63", icon: $r('app.media.ic_graduation_audit'), route: "pages/campus/MajorProgressPage" }
]

//小工具模块数组
const toolList: CardItem[] = [
  { title: "校车时刻", desc: "发车时间查询", bgColor: "#ffffff", titleColor: "#333333", icon: $r('app.media.ic_school_bus'), route: "pages/campus/SchoolBusPage" },
  { title: "学校校历", desc: "了解假期安排", bgColor: "#ffffff", titleColor: "#333333", icon: $r('app.media.ic_schoolcalendar'), route: "pages/campus/SchoolCalendarPage" },
  { title: "物理实验", desc: "导入实验课表", bgColor: "#ffffff", titleColor: "#333333", icon: $r('app.media.ic_physical'), route: "pages/course/PhysicalExperimentPage" },
  { title: "校园黄页", desc: "号码通讯录", bgColor: "#ffffff", titleColor: "#333333", icon: $r('app.media.ic_yellow_page'), route: "pages/campus/YellowPagesPage" },
  { title: "饮水机", desc: "扫码取水与结算", bgColor: "#ffffff", titleColor: "#333333", icon: $r('app.media.water_dispenser'), route: "pages/main/WaterDispenserPage" },
  { title: "查电费", desc: "寝室剩余电量", bgColor: "#ffffff", titleColor: "#333333", icon: $r('app.media.electricity_bill'), route: "pages/main/ElectricityPage" }
]

//校园墙单独通栏对象
const campusWallItem: CardItem = {
  title: "校园墙",
  desc: "查看校园新鲜事",
  bgColor: "#FFE5EC",
  titleColor: "#c2185b",
  icon: $r('app.media.ic_campus_wall'),
  route: "pages/campus/CampusWallPage"
}

const campusCommunityList: CardItem[] = [
  campusWallItem,
  { title: '失物招领', desc: '找回丢失物品', bgColor: '#E7F8E9', titleColor: '#27865D', icon: $r('app.media.campus_found'), route: 'pages/campus/CampusLostPage' },
  { title: '竞赛组队', desc: '找队友找队伍', bgColor: '#E4F3FF', titleColor: '#2478B5', icon: $r('app.media.campus_match'), route: 'pages/campus/CampusMatchPage' },
  { title: '求助', desc: '提问并采纳答案', bgColor: '#FFF0D9', titleColor: '#B56A12', icon: $r('app.media.campus_help'), route: 'pages/campus/CampusHelpPage' },
  { title: '二手书', desc: '闲置书籍买卖', bgColor: '#FFF8D8', titleColor: '#857A25', icon: $r('app.media.second_hand_book'), route: 'pages/campus/SecondHandBookPage' }
]


// ═══════════════════════════════════════════════ 主页组件 ═══════════════════════════════════════════════

@Entry
@Component
struct MainPage {
  // ── @State 响应式变量 ──
  /** 当前选中 Tab 索引 */
  @State private currentTab: number = 2;
  @State private catSleep: boolean = false;
  @State private catGirl: boolean = false;
  @State private showCampusCat: boolean = true;
  @State private showVolunteerTab: boolean = true;
  @State private showCampusTab: boolean = true;
  @State private visibleToolTitles: string[] = [];
  @State private homeBanners: HomeBanner[] = [];
  @State private homeNoticeText: string = '欢迎使用武科大助手，随时随地开启校园之旅';
  /** 底部导航栏是否隐藏 */
  @State private barHidden: boolean = false;
  // ── 非 @State 内部变量 ──
  private lastBackTime: number = 0;
  private tabsController: TabsController = new TabsController();
  private teachingRetryTimer: number = -1;

  // ═══════════════════════════════════════════════ 生命周期 ═══════════════════════════════════════════════

  aboutToAppear(): void {
    console.info(TAG, 'aboutToAppear');
    this.loadDefaultTab();
    this.loadCatVisibility();
    this.loadNavigationVisibility();
    this.loadToolLayout();
    this.loadHomeContent();
    this.updateCatState();
    this.startTeachingSessionRetry();
    console.info(TAG, `[module-debug] toolList.length=${toolList.length}`);
    console.info(TAG, `[module-debug] campusWallItem.title=${campusWallItem.title}, desc=${campusWallItem.desc}, route=${campusWallItem.route}`);
  }

  private updateCatState(): void {
    const hour = new Date().getHours();
    this.catSleep = hour >= 22 || hour < 6 || (hour >= 12 && hour < 14);
  }

  private async loadDefaultTab(): Promise<void> {
    const courseAsHome = await AppStorage.getInstance().getCourseAsHome();
    this.currentTab = courseAsHome ? TabIndex.COURSE : TabIndex.HOME;
  }

  /** onPageShow — 页面显示，校验登录态 */
  onPageShow(): void {
    console.info(TAG, 'onPageShow');
    this.updateCatState();
    this.loadCatVisibility();
    this.loadNavigationVisibility();
    this.loadToolLayout();
    this.refreshCatEasterEgg();
    this.verifyLoginState();
  }

  aboutToDisappear(): void {
    if (this.teachingRetryTimer !== -1) {
      clearInterval(this.teachingRetryTimer);
      this.teachingRetryTimer = -1;
    }
  }

  private startTeachingSessionRetry(): void {
    if (this.teachingRetryTimer !== -1) return;
    this.teachingRetryTimer = setInterval(() => {
      TeachingSessionService.ensureSession(true).then((ok: boolean) => {
        if (ok) console.info(TAG, 'teaching session restored in background');
      });
    }, 60_000);
  }

  private async loadToolLayout(): Promise<void> {
    const raw = await AppStorage.getInstance().getSettingString('toolLayout', '');
    const defaults: string[] = toolList.map((item: CardItem) => item.title);
    if (raw.length === 0) { this.visibleToolTitles = defaults; return; }
    try {
      const saved = JSON.parse(raw) as string[];
      this.visibleToolTitles = defaults.filter((title: string) => saved.indexOf(title) >= 0)
        .sort((a: string, b: string) => saved.indexOf(a) - saved.indexOf(b));
    } catch { this.visibleToolTitles = defaults; }
  }

  private async loadHomeContent(): Promise<void> {
    try {
      this.homeBanners = await HomeContentApi.banners();
    } catch (error) {
      console.warn(TAG, `load home banners failed: ${JSON.stringify(error)}`);
    }
    try {
      const notices: HomeNotice[] = await HomeContentApi.notices();
      if (notices.length > 0) {
        const latest = notices[notices.length - 1];
        this.homeNoticeText = latest.content || latest.title || this.homeNoticeText;
      }
    } catch (error) {
      console.warn(TAG, `load home notices failed: ${JSON.stringify(error)}`);
    }
  }

  private async loadCatVisibility(): Promise<void> {
    this.showCampusCat = await AppStorage.getInstance().getSettingBool('showCampusCat', true);
  }

  private async loadNavigationVisibility(): Promise<void> {
    const s = AppStorage.getInstance();
    this.showVolunteerTab = await s.getSettingBool('navVolunteer', true);
    this.showCampusTab = await s.getSettingBool('navCampus', true);
    if (!this.showVolunteerTab && this.currentTab === TabIndex.VOLUNTEER) this.currentTab = TabIndex.HOME;
    if (!this.showCampusTab && this.currentTab === TabIndex.CAMPUS) this.currentTab = TabIndex.HOME;
  }

  /** onBackPress — 双击退出 */
  onBackPress(): boolean {
    return this.handleExit();
  }

  // ═══════════════════════════════════════════════ 登录校验 + 会话失效═══════════════════════════════════════════════

  /** 教务失效不退出 App，仅在后台尝试恢复。 */
  private async verifyLoginState(): Promise<void> {
    try {
      await TeachingSessionService.ensureSession(false);
      // Token 有效，后台静默刷新 AppAuth
      this.silentRefreshAppAuth();
    } catch {
      console.error(TAG, 'verifyLoginState error');
    }
  }

  /** 后台静默刷新 AppAuth Token */
  private async silentRefreshAppAuth(): Promise<void> {
    try {
      await ApiService.loginAppAuthFromSavedCredentials(AppStorage.getInstance());
    } catch {
      console.warn(TAG, 'silentRefreshAppAuth error');
    }
  }

  /** 教务会话失效时保留本地数据和 App 登录态。 */
  private onSessionExpired(): void {
    TeachingSessionService.ensureSession(true);
  }

  private async clearLoginState(): Promise<void> {
    try {
      const s = AppStorage.getInstance();
      await s.setToken('');
      await s.setTokenUpdateTime(0);
      await s.setTokenLastUseTime(0);
      await s.setIsLogin(false);
      await s.setMessage('');
    } catch {
      console.error(TAG, 'clearLoginState error');
    }
  }

  /** API 认证失败自动恢复（Token 刷新 + 重试） */
  private async onApiAuthFailure<T>(retryFunc?: () => Promise<T>): Promise<boolean> {
    try {
      const s = AppStorage.getInstance();
      const sid = await s.getStudentId();
      const pwd = await s.getPassword();
      if (!sid || !pwd) return false;
      const restored = await TeachingSessionService.ensureSession(true);
      if (!restored) return false;
      if (retryFunc) await retryFunc();
      return true;
    } catch {
      console.error(TAG, 'onApiAuthFailure');
      return false;
    }
  }

  // ═══════════════════════════════════════════════ Tab 切换 & 双击退出═══════════════════════════════════════════════

  private onTabChange(index: number): void {
    if (index !== this.currentTab) this.refreshCatEasterEgg();
    this.currentTab = index;
    console.info(TAG, `tab → ${index} ${TAB_LABELS[index] ?? ''}`);
  }

  private switchToTab(tab: TabIndex): void {
    if (tab === this.currentTab) return;
    this.refreshCatEasterEgg();
    this.currentTab = tab;
  }

  private refreshCatEasterEgg(): void {
    // 每次刷新独立抽样：命中 1% 显示猫娘，否则显示普通校园猫。
    this.catGirl = Math.random() < 0.01;
  }

  private handleExit(): boolean {
    const now = Date.now();
    if (now - this.lastBackTime > EXIT_INTERVAL) {
      promptAction.showToast({ message: '再按一次退出程序', duration: 2000 });
      this.lastBackTime = now;
      return true;
    }
    try {
      (getContext(this) as common.UIAbilityContext)?.terminateSelf();
    } catch {
      console.warn(TAG, 'exit error');
    }
    return true;
  }

  private async syncOnForeground(): Promise<void> {
    await this.verifyLoginState();
  }

  /** 导航栏隐藏切换（供子页面回调） */
  private toggleNavBar(hidden: boolean): void {
    this.barHidden = hidden;
  }

  // ═══════════════════════════════════════════════ 预加载 & 同步═══════════════════════════════════════════════

  private preloadAllTabs(): void {
    console.info(TAG, `preload ${TAB_LABELS.length} tabs`);
  }

  // ═══════════════════════════════════════════════ UI 布局 ═══════════════════════════════════════════════

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Tabs({
        barPosition: BarPosition.End,
        index: this.currentTab,
        controller: this.tabsController,
      }) {
        // ── Tab 0：主页 ──
        TabContent() {
          this.HomePage()
        }
        .tabBar(this.TabBarBuilder(TabIndex.HOME))

        // ── Tab 1：志愿者 ──
        if (this.showVolunteerTab) {
          TabContent() { VolunteerPage() }.tabBar(this.TabBarBuilder(TabIndex.VOLUNTEER))
        }

        // ── Tab 2：课表 ──
        TabContent() {
          CoursePage()
        }
        .tabBar(this.TabBarBuilder(TabIndex.COURSE))

        // ── Tab 3：校园 ──
        if (this.showCampusTab) {
          TabContent() { CampusPage() }.tabBar(this.TabBarBuilder(TabIndex.CAMPUS))
        }

        // ── Tab 4：个人中心 ──
        TabContent() {
          MinePage()
        }
        .tabBar(this.TabBarBuilder(TabIndex.MINE))

      }
      .vertical(false)
      .scrollable(false)
      .barHeight(64)
      .barMode(BarMode.Fixed)
      .shadow({ radius: 4, color: '#0D000000', offsetY: -2 })
      .width('100%')
      .height('100%')
      .onChange((index: number) => {
        this.currentTab = index;
      })
      if (this.currentTab === TabIndex.HOME && this.showCampusCat) {
        Image(this.catGirl
          ? (this.catSleep ? $r('app.media.campus_cat_girl_sleep') : $r('app.media.campus_cat_girl'))
          : (this.catSleep ? $r('app.media.campus_cat_sleep') : $r('app.media.campus_cat')))
          .width(108).height(108).objectFit(ImageFit.Contain)
          .margin({ right: 8, bottom: 62 })
          .zIndex(10)
          .onClick(() => { this.refreshCatEasterEgg(); router.pushUrl({ url: 'pages/campus/CampusCatPage' }); });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  // ═══════════════════════════════════════════════ @Builder ═══════════════════════════════════════════════

  @Builder
  private TabBarBuilder(tab: TabIndex) {
    Column() {
      Image(this.tabIcon(tab))
        .width(24).height(24).objectFit(ImageFit.Contain)
      Text(TAB_LABELS[tab])
        .fontSize(10)
        .fontColor(this.currentTab === tab ? '#1EC98D' : '#999999')
        .margin({ top: 2 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private tabIcon(tab: TabIndex): Resource {
    const map: string[] = [
      this.currentTab === tab ? 'ic_home_checked' : 'ic_home_normal',
      this.currentTab === tab ? 'ic_volunteering_checked' : 'ic_volunteering_normal',
      this.currentTab === tab ? 'ic_course_checked' : 'ic_course_normal',
      this.currentTab === tab ? 'ic_campus_checked' : 'ic_campus_normal',
      this.currentTab === tab ? 'ic_mine_checked' : 'ic_mine_normal',
    ];
    return $r('app.media.' + (map[tab] ?? 'ic_course_normal'));
  }

  /** 热门功能卡片统一跳转 */
  private openHotFeature(item: CardItem): void {
    if (item.onCardClick) {
      item.onCardClick();
      return;
    }
    if (!item.route) {
      promptAction.showToast({ message: `${item.title} 功能开发中`, duration: 2000 });
      return;
    }

    if (item.route === 'pages/common/WebPage') {
      router.pushUrl({
        url: item.route,
        params: { title: item.title, url: item.url ?? '' }
      });
      return;
    }

    router.pushUrl({ url: item.route });
  }

  /** 主页内容 */

  /** 主页内容 */
  @Builder
  private HomePage() {
    Scroll() {
      Column() {
        Row() {
          Text('主页').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333333')
          Text('HOME').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#666666').margin({ left: 12 })
        }
        .width('100%').padding({ left: 16, top: 10, bottom: 18 })

        // ── Banner ──
        Swiper() {
          if (this.homeBanners.length > 0) {
            ForEach(this.homeBanners, (banner: HomeBanner) => {
              Image(banner.imageUrl).width('100%').height('100%').objectFit(ImageFit.Cover)
            }, (banner: HomeBanner, index: number) => `${banner.id || index}-${banner.imageUrl}`)
          } else {
            Row() {
              Column() {
                Text('武科大助手').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Text('校园生活 一手掌握').fontSize(14).fontColor('#FFFFFF').opacity(0.8).margin({ top: 6 })
              }.alignItems(HorizontalAlign.Start)
              Blank()
            }.padding(20).width('100%').height('100%').alignItems(VerticalAlign.Center)
              .linearGradient({ angle: 135, colors: [['#667eea', 0], ['#764ba2', 1]] })
          }
        }
        .width('100%')
        .height(150)
        .autoPlay(this.homeBanners.length > 1)
        .interval(4500)
        .loop(this.homeBanners.length > 1)
        .borderRadius(16)
        .clip(true)
        .margin({ left: 16, right: 16 })

        // ── 公告栏 ──
        Row() {
          // 使用矢量资源替代 emoji，避免鸿蒙设备缺少 emoji 字体时显示黑方块。
          Image($r('app.media.notifications')).width(20).height(20).objectFit(ImageFit.Contain).margin({ right: 8 })
          Text(this.homeNoticeText).fontSize(13).fontColor('#666666').maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 12,
          bottom: 12
        })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .margin({ left: 16, right: 16, top: 12 })

          // ── 热门功能标题 ──
          Text('热门功能')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ left: 16, right: 16, top: 24 })

          // ── 成绩查询（通栏） ──
          Column() {
            this.HotWideCard({
              title: '成绩查询',
              desc: '成绩查询 绩点计算 平均绩点',
              bgColor: '#E7F6E9',
              titleColor: '#4CAF50',
              icon: $r('app.media.ic_grade_normal'),
              onCardClick: () => {
                console.info(TAG, '成绩查询卡片点击，准备跳转 GradePage');
                router.pushUrl({ url: 'pages/campus/grade/GradePage' });
              }
            })
          }
          .width('100%')
          .margin({ left: 16, right: 16, top: 12 })


          // ── 倒计时跨两行，右侧图书馆与培养方案 ──
          Row() {
            this.HotCountdownCard(hotFuncList[0])
            Column() {
              this.HotSmallCard(hotFuncList[1])
              Column() {
                this.HotSmallCard(hotFuncList[2])
              }
              .margin({ top: 12 })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 16 })

          Row() {
            Column() {
              this.HotSmallCard(hotFuncList[3])
            }
            .layoutWeight(1)
            .margin({ right: 12 })
            Column() {
              this.HotSmallCard(hotFuncList[4])
            }
            .layoutWeight(1)
          }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .margin({ top: 16 })

          Row() {
            Column() {
              this.HotSmallCard(hotFuncList[6])
            }
            .layoutWeight(1)
            .margin({ right: 12 })
            Column() {
              this.HotSmallCard(hotFuncList[5])
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 16 })

          // ── 校园社区标题 ──
          Row() {
            Text('校园社区').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333').layoutWeight(1)
            Row() {
              Image($r('app.media.info')).width(42).height(42).padding(8).backgroundColor('#EEEEEE').borderRadius(21)
                .onClick(() => this.showCommunityRules())
              Image($r('app.media.notifications')).width(42).height(42).padding(8).backgroundColor('#EEEEEE').borderRadius(21).margin({ left: 10 })
                .onClick(() => router.pushUrl({ url: 'pages/campus/CommunityNotificationsPage' }))
            }
          }.width('100%').padding({ left: 16, right: 16 }).margin({ top: 24 })

          Grid() {
            ForEach(campusCommunityList, (item: CardItem) => {
              GridItem() { this.CardItem(item) }
            }, (item: CardItem) => item.title)
          }
          .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12)
          .width('100%').padding({ left: 16, right: 16 }).margin({ top: 12 })

          Column() {
            // ── 小工具标题 ──
            Row() {
              Text('小工具').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333').layoutWeight(1)
              Image($r('app.media.edit_tools')).width(42).height(42).padding(8).backgroundColor('#EEEEEE').borderRadius(21)
                .onClick(() => router.pushUrl({ url: 'pages/main/EditToolsPage' }))
            }.width('100%').margin({ top: 24 })

            // ── 小工具网格 ──
            Grid() {
              ForEach(toolList.filter((item: CardItem) => this.visibleToolTitles.indexOf(item.title) >= 0)
                .sort((a: CardItem, b: CardItem) => this.visibleToolTitles.indexOf(a.title) - this.visibleToolTitles.indexOf(b.title)), (item: CardItem) => {
                GridItem() {
                  this.CardItem(item)
                }
              }, (item: CardItem) => item.title)
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(12)
            .rowsGap(12)
            .width('100%')
            .margin({ top: 12 })

          }.width('100%').padding({ left: 16, right: 16 })

          // ── 底部版权 ──
          Text('领航工作室出品')
            .fontSize(13)
            .fontColor('#BBBBBB')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 24, bottom: 40 })

      }.width('100%').backgroundColor('#F5F6F8')
    }
    .padding({ bottom: 100 })
  }

  private showCommunityRules(): void {
    promptAction.showDialog({
      title: '校园社区规则',
      message: '1. 遵守法律法规：不发布违法、诈骗、色情、侵权或泄露隐私的内容。\n\n2. 友善交流：禁止人身攻击、歧视、骚扰、引战、刷屏和恶意举报。\n\n3. 请按板块发布真实、准确的信息：不发布广告或重复内容。\n\n4. 谨慎公开联系方式；线下认领、组队和求助时请核实身份，注意人身与财产安全。\n\n5. 违规内容可能被删除，严重违规将限制使用。',
      buttons: [{ text: '知道了', color: '#55D600' }]
    });
  }

    /** 热门功能：通栏成绩卡片 */
    @Builder
    private HotWideCard(item: CardItem) {
      Row() {
        Column() {
          Text(item.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(item.titleColor)
          Text(item.desc)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(item.titleColor)
            .maxLines(1)
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Image(item.icon)
          .width(128)
          .height(128)
          .objectFit(ImageFit.Contain)
          .translate({ x: 16, y: 20 })
      }
      .width('100%')
      .height(144)
      .padding({ left: 18, right: 4 })
      .backgroundColor(item.bgColor)
      .borderRadius(12)
      .clip(true)
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.openHotFeature(item))
    }

    /** 热门功能：左侧跨两行的倒计时卡片 */
    @Builder
    private HotCountdownCard(item: CardItem) {
      Column() {
        Image(item.icon)
          .width(70)
          .height(70)
          .objectFit(ImageFit.Contain)
        Text(item.title)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.titleColor)
          .margin({ top: 12 })
        Text(item.desc)
          .fontSize(11)
          .fontColor(item.titleColor)
          .maxLines(1)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .height(212)
      .backgroundColor(item.bgColor)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })
      .onClick(() => this.openHotFeature(item))
    }

    /** 热门功能：两列常规卡片 */
    @Builder
    private HotSmallCard(item: CardItem) {
      Row() {
        Column() {
          Text(item.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(item.titleColor)
            .maxLines(1)
          Text(item.desc)
            .fontSize(11)
            .fontColor(item.titleColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Image(item.icon)
          .width(54)
          .height(54)
          .objectFit(ImageFit.Contain)
          .margin({ left: 2 })

      }
      .width('100%')
      .height(100)
      .padding({ left: 12, right: 8 })
      .backgroundColor(item.bgColor)
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.openHotFeature(item))
    }

    /** 通用卡片组件 */
    @Builder
    private CardItem(item: CardItem) {
      Row() {
        Column() {
          Text(item.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(item.titleColor)
          Text(item.desc)
            .fontSize(11)
            .fontColor(item.titleColor)
            .margin({ top: 3 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 10 })
        Image(item.icon)
          .width(54)
          .height(54)
          .objectFit(ImageFit.Contain)

          .rotate({ angle: item.rotated ? -45 : 0 })
      }
      .width('100%')
      .height(100)
      .padding({ left: 12, right: 12, top: 14, bottom: 14 })
      .backgroundColor(item.bgColor)
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (item.onCardClick) {
          item.onCardClick();
          return;
        }
        if (item.route) {
          this.openHotFeature(item)
        }
      })
    }
  }






