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

/**
 * operationLog 同时包含反馈、活动和版本公告，不能把第一条记录直接当成更新。
 * 只有带版本信息或明确更新语义的记录才允许打开更新弹窗。
 */
export function isUpdateNotice(item: UpdateNoticeItem): boolean {
  const text: string = `${item.title || ''} ${item.context || ''} ${item.content || ''}`.trim();
  const lowerText: string = text.toLowerCase();
  if (text.length === 0) return false;

  // 这些内容是运营公告，和安装包更新无关。
  if (/问题反馈|反馈|登录问题|改密码|招新|鱼宴|验证码|暂时无法使用/.test(text)) return false;

  const platformText: string = `${item.platform ?? ''} ${lowerText}`;
  // 当前接口会返回 iOS/Android 公告，不能在鸿蒙端误报更新。
  if (/ios|iphone|ipad|苹果|android|安卓/.test(platformText) && !/鸿蒙|harmony/.test(lowerText)) return false;

  const hasVersionField: boolean = item.version !== undefined || item.versionName !== undefined ||
    item.versionCode !== undefined || item.latestVersion !== undefined || item.latestVersionCode !== undefined;
  const hasVersionText: boolean = /(?:^|[\s(]v?)\d+\.\d+(?:\.\d+)?(?:[\s)]|$)/i.test(text);
  const hasUpdateLanguage: boolean = /新版本|版本更新|版本升级|更新版本|升级版本|更新日志|安装包|版本号|鸿蒙.*更新|harmony(?:os)?\s*(?:update|更新)/i.test(text);
  return hasVersionField || hasVersionText || hasUpdateLanguage;
}
