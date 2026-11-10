import { bundleManager } from '@kit.AbilityKit';

/**
 * 应用版本信息。
 *
 * 页面不再写死版本号，统一从 AppScope/app.json5 的 versionName 读取，
 * 发版时只改一处即可，避免“设置里显示 5.x、安装包是 1.0.x”的不一致。
 */
export class AppVersion {
  private static cached: string = '';

  static versionName(): string {
    if (AppVersion.cached) return AppVersion.cached;
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      const versionName = (info.versionName || '').trim();
      if (versionName) AppVersion.cached = versionName;
      return AppVersion.cached;
    } catch (error) {
      console.warn('AppVersion', `read version failed: ${JSON.stringify(error)}`);
      return AppVersion.cached;
    }
  }

  /** 页面展示用：v1.0.3；读不到时退回 1.0.3。 */
  static label(): string {
    const name = AppVersion.versionName();
    return `v${name || '1.0.3'}`;
  }
}
