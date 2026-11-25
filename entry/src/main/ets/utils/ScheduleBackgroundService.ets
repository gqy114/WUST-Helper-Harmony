import { image } from '@kit.ImageKit';
import { CropRectangle } from './ScheduleBackgroundCrop';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

/**
 * 将系统选图器授予的临时 URI 转存到应用私有目录。
 *
 * 真机上的 PhotoPicker URI 只保证在当前授权窗口内可读，不能直接作为
 * 课表背景长期保存；复制后使用 file:// URI，预览、重启和版本更新后都能读取。
 */
export class ScheduleBackgroundService {
  private static readonly DIRECTORY_NAME: string = 'schedule_backgrounds';

  /** ArkTS 不允许把 catch 到的值原样再抛出，统一转换成 Error。 */
  static asError(error: Object): Error {
    if (error instanceof Error) {
      return error;
    }
    return new Error(`schedule background error: ${JSON.stringify(error)}`);
  }

  static persist(context: common.UIAbilityContext, sourceUri: string): string {
    if (!sourceUri) {
      throw new Error('background source uri is empty');
    }

    const directory = ScheduleBackgroundService.getDirectory(context);
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }

    const extension = ScheduleBackgroundService.getExtension(sourceUri);
    const targetPath = `${directory}/schedule_background_${Date.now()}${extension}`;
    const sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
    try {
      const targetFile = fileIo.openSync(
        targetPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      try {
        fileIo.copyFileSync(sourceFile.fd, targetFile.fd);
      } finally {
        fileIo.closeSync(targetFile);
      }
    } catch (err) {
      if (fileIo.accessSync(targetPath)) {
        fileIo.unlinkSync(targetPath);
      }
      throw ScheduleBackgroundService.asError(err);
    } finally {
      fileIo.closeSync(sourceFile);
    }

    return `file://${targetPath}`;
  }

  static async decode(uri: string): Promise<image.PixelMap> {
    const file = fileIo.openSync(ScheduleBackgroundService.toPath(uri), fileIo.OpenMode.READ_ONLY);
    try {
      const source = image.createImageSource(file.fd);
      try {
        const size = (await source.getImageInfo()).size;
        const scale = Math.min(1, 2048 / Math.max(size.width, size.height));
        return await source.createPixelMap({
          editable: true,
          desiredSize: {
            width: Math.max(1, Math.round(size.width * scale)),
            height: Math.max(1, Math.round(size.height * scale))
          }
        });
      } finally {
        await source.release();
      }
    } finally {
      fileIo.closeSync(file);
    }
  }

  static async saveCropped(context: common.UIAbilityContext, sourceUri: string,
    crop: CropRectangle): Promise<string> {
    const pixelMap = await ScheduleBackgroundService.decode(sourceUri);
    try {
      await pixelMap.crop({ x: crop.x, y: crop.y, size: { width: crop.width, height: crop.height } });
      const path = `${ScheduleBackgroundService.getDirectory(context)}/schedule_crop_${Date.now()}.jpg`;
      const packer = image.createImagePacker();
      try {
        const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        try {
          await packer.packToFile(pixelMap, file.fd, { format: 'image/jpeg', quality: 94 });
        } finally {
          fileIo.closeSync(file);
        }
        return `file://${path}`;
      } catch (err) {
        ScheduleBackgroundService.removeOwned(context, path);
        throw ScheduleBackgroundService.asError(err);
      } finally {
        await packer.release();
      }
    } finally {
      await pixelMap.release();
    }
  }

  /** 只删除本服务创建的文件，避免误删系统相册内容。 */
  static removeOwned(context: common.UIAbilityContext, imageUri: string): void {
    if (!imageUri) {
      return;
    }
    const path = ScheduleBackgroundService.toPath(imageUri);
    const directoryPrefix = `${ScheduleBackgroundService.getDirectory(context)}/`;
    if (!path.startsWith(directoryPrefix)) {
      return;
    }
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (err) {
      console.warn('ScheduleBackgroundService', `remove background failed: ${JSON.stringify(err)}`);
    }
  }

  private static getDirectory(context: common.UIAbilityContext): string {
    return `${context.filesDir}/${ScheduleBackgroundService.DIRECTORY_NAME}`;
  }

  private static toPath(uri: string): string {
    return uri.startsWith('file://') ? uri.substring('file://'.length) : uri;
  }

  private static getExtension(uri: string): string {
    const cleanUri = uri.split('?')[0].toLowerCase();
    const supportedExtensions: string[] = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', '.gif', '.bmp'];
    for (let index = 0; index < supportedExtensions.length; index++) {
      const extension = supportedExtensions[index];
      if (cleanUri.endsWith(extension)) {
        return extension;
      }
    }
    return '.jpg';
  }
}
