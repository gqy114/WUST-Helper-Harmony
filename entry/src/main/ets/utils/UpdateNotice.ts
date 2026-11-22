export interface UpdateNoticeItem {
  title?: string;
  context?: string;
  content?: string;
  version?: string;
  versionName?: string;
  versionCode?: number | string;
  latestVersion?: string;
  latestVersionCode?: number | string;
  platform?: number | string;
  downloadUrl?: string;
  url?: string;
}

function isOtherPlatform(platform: number | string | undefined, text: string): boolean {
  const rawPlatform: string = `${platform ?? ''}`.trim().toLowerCase();
  // operationLog 的平台枚举中 0 表示全平台，1 表示 iOS，2 表示 Android。
  if (rawPlatform === '1' || rawPlatform === '2') return true;
  if (/ios|iphone|ipad|苹果|android|安卓/.test(rawPlatform)) return true;
  return /ios|iphone|ipad|苹果|android|安卓/.test(text) && !/鸿蒙|harmony/.test(text);
}

function hasSemanticVersionField(item: UpdateNoticeItem): boolean {
  const values: Array<string | number | undefined> = [
    item.version, item.versionName, item.latestVersion, item.versionCode, item.latestVersionCode
  ];
  return values.some((value: string | number | undefined): boolean => value !== undefined && `${value}`.trim().length > 0);
}

/**
 * operationLog 同时包含反馈、活动和版本公告，不能把第一条记录直接当成更新。
 * 只有带版本字段、明确版本号或明确更新语义的记录才允许打开更新弹窗。
 */
export function isUpdateNotice(item: UpdateNoticeItem): boolean {
  const text: string = `${item.title || ''} ${item.context || ''} ${item.content || ''}`.trim();
  if (text.length === 0) return false;

  // 这些内容是运营公告，和安装包更新无关。
  if (/问题反馈|反馈|登录问题|改密码|招新|鱼宴|验证码|暂时无法使用/.test(text)) return false;

  // 当前接口会返回 iOS/Android 公告，不能在鸿蒙端误报更新。
  if (isOtherPlatform(item.platform, text)) return false;

  const hasVersionField: boolean = hasSemanticVersionField(item);
  // 无上下文的 2026.11.22、12.01 等日期不能当作版本号。
  const hasVersionText: boolean = /(?:版本(?:号)?\s*v?\d+\.\d+(?:\.\d+)?|\bv\d+\.\d+(?:\.\d+)?\b)/i.test(text) ||
    /新版本|版本更新|版本升级|更新版本|升级版本|更新日志/i.test(text) && /\b\d+\.\d+\.\d+\b/.test(text);
  const hasUpdateLanguage: boolean = /新版本|版本更新|版本升级|更新版本|升级版本|更新日志|最新安装包|新版安装包|鸿蒙.*更新|harmony(?:os)?\s*(?:update|更新)/i.test(text);
  return hasVersionField || hasVersionText || hasUpdateLanguage;
}
