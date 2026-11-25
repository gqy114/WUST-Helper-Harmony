import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { CropRectangle } from './ScheduleBackgroundCrop';

export class PhotoCropImage {
  static async decode(uri: string): Promise<image.PixelMap> {
    const file = fileIo.openSync(uri.startsWith('file:///') ? uri.substring(7) : uri, fileIo.OpenMode.READ_ONLY);
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

  static async crop(uri: string, region: CropRectangle, rotation: number = 0): Promise<image.PixelMap> {
    const pixelMap = await PhotoCropImage.decode(uri);
    try {
      if (rotation !== 0) await pixelMap.rotate(rotation);
      await pixelMap.crop({ x: region.x, y: region.y, size: { width: region.width, height: region.height } });
      return pixelMap;
    } catch {
      await pixelMap.release();
      throw new Error('无法裁剪图片');
    }
  }
}
