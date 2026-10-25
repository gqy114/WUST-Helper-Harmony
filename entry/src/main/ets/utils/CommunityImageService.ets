import { photoAccessHelper } from '@kit.MediaLibraryKit';
import request from '@ohos.request';
import common from '@ohos.app.ability.common';
import { AppStorage } from '../store/AppStorage';

interface UploadData { url?: string; }
interface UploadResponse { code?: number; message?: string; data?: UploadData; }

export class CommunityImageService {
  static async select(current: string[], limit: number = 9): Promise<string[]> {
    const remaining = limit - current.length;
    if (remaining <= 0) return current;
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = remaining;
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select(options);
    const next = current.slice();
    (result.photoUris || []).forEach((uri: string) => {
      if (next.indexOf(uri) < 0 && next.length < limit) next.push(uri);
    });
    return next;
  }

  static async uploadAll(context: common.Context, uris: string[], kind: string): Promise<string[]> {
    const urls: string[] = [];
    for (let index = 0; index < uris.length; index++) {
      urls.push(await CommunityImageService.uploadOne(context, uris[index], kind, index));
    }
    return urls;
  }

  private static endpoint(kind: string): string {
    if (kind === 'cat') return 'https://lyzyy.love:8081/api/v1/campus-cat/upload';
    if (kind === 'secondhand') return 'https://lyzyy.love:8081/api/v1/secondhand/upload';
    return 'https://lyzyy.love:8081/api/v1/campus-wall/upload';
  }

  private static fileInfo(uri: string, index: number): string[] {
    const lower = uri.toLowerCase();
    if (lower.indexOf('.png') >= 0) return [`image_${index}.png`, 'image/png'];
    if (lower.indexOf('.webp') >= 0) return [`image_${index}.webp`, 'image/webp'];
    if (lower.indexOf('.gif') >= 0) return [`image_${index}.gif`, 'image/gif'];
    return [`image_${index}.jpg`, 'image/jpeg'];
  }

  private static async uploadOne(context: common.Context, uri: string, kind: string, index: number): Promise<string> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    if (!token) throw new Error('missing access token');
    const info = CommunityImageService.fileInfo(uri, index);
    const task = await request.uploadFile(context, {
      url: CommunityImageService.endpoint(kind),
      method: 'POST',
      header: { Authorization: `Bearer ${token}`, Accept: 'application/json', Platform: 'android' },
      files: [{ filename: info[0], name: 'file', uri, type: info[1] }],
      data: []
    });
    const states = await new Promise<Array<request.TaskState>>((resolve, reject) => {
      task.on('complete', (items: Array<request.TaskState>) => resolve(items));
      task.on('fail', (items: Array<request.TaskState>) => reject(new Error(JSON.stringify(items))));
    });
    if (states.length === 0 || states[0].responseCode !== 0) throw new Error('image upload failed');
    const response = JSON.parse(states[0].message) as UploadResponse;
    if (response.code !== undefined && response.code !== 0 && response.code !== 200) throw new Error(response.message || 'image upload failed');
    const url = response.data?.url || '';
    if (!url) throw new Error('missing uploaded image url');
    return url;
  }
}
