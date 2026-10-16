import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';

const BASE: string = 'https://i.ilife798.com';
interface WaterHeaders { Accept: string; ApplicationType: string; VersionCode: string; UserAgent: string; Authorization?: string; }
export class WaterDispenserApi {
  private static async request(path: string, method: 'GET' | 'POST' = 'GET', body?: Record<string, string>): Promise<string> {
    const token: string = (await AppStorage.getInstance().getAppAuthAccessToken()).trim();
    const headers: Record<string, string> = {}; headers.Accept = 'application/json'; headers.ApplicationType = '1,1'; headers.VersionCode = '31006'; headers['User-Agent'] = 'Android_ilife798_3.1.6_minimal';
    if (token.length > 0) headers.Authorization = token;
    const result = await HttpRequest.get<string>(BASE + path, headers);
    return result.data;
  }
  static async useQr(id: string): Promise<string> { return WaterDispenserApi.request(`/api/v1/qr/use?id=${encodeURIComponent(id)}`); }
  static async home(deviceId: string): Promise<string> { return WaterDispenserApi.request(`/api/v1/ui/app/dev/home/1?did=${encodeURIComponent(deviceId)}&apply=0`); }
  static async wallet(): Promise<string> { return WaterDispenserApi.request('/api/v1/acc/wallet/owner?all=true'); }
  static async start(deviceId: string): Promise<string> { return WaterDispenserApi.request(`/api/v1/dev/start?did=${encodeURIComponent(deviceId)}&upgrade=false&rcp=false&ptype=91&cnt=1&args=%7B%7D`); }
  static async end(deviceId: string): Promise<string> { return WaterDispenserApi.request(`/api/v1/dev/end?did=${encodeURIComponent(deviceId)}&rcp=false`); }
}
