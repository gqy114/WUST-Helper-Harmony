import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
import { ApiService } from './ApiService';
export interface YKTLocationItem { id: string; name: string; }
export interface YKTLocationPage { type: string; end: boolean; items: YKTLocationItem[]; }
export interface YKTLocationResponse { code: number; message: string; data?: YKTLocationPage; }
export interface YKTElectricity { roomId: string; remaining: string; unit: string; }
export interface YKTElectricityResponse { code: number; message: string; data?: YKTElectricity; }
export interface YKTSavedRoom { id: string; name?: string; type?: string; }
interface YKTCloudElectricity { rooms?: YKTSavedRoom[]; }
interface YKTCloudPayload { electricity?: YKTCloudElectricity; }
interface YKTCloudData { data?: YKTCloudPayload; }
interface YKTCloudResponse { code?: number; message?: string; data?: YKTCloudData; }
interface YKTResponseEnvelope { code?: number; message?: string; }
export class ElectricityApi {
  private static async get<T>(path: string, retry: boolean = true): Promise<T> {
    const storage = AppStorage.getInstance(); const token = await storage.getAppAuthAccessToken();
    const result = await HttpRequest.get<T>(`https://lyzyy.love:8081/api/v1/ykt/${path}`, { Authorization: `Bearer ${token}`, Accept: 'application/json' });
    const body = result.data as T;
    const envelope = result.data as YKTResponseEnvelope;
    if (envelope.code === 401 && retry) { await storage.setAppAuthAccessToken(''); await ApiService.loginAppAuthFromSavedCredentials(storage); return ElectricityApi.get<T>(path, false); }
    return body;
  }
  static async locations(parentId: string = ''): Promise<YKTLocationPage> { const suffix = parentId ? `?parentId=${encodeURIComponent(parentId)}` : ''; const response = await ElectricityApi.get<YKTLocationResponse>(`locations${suffix}`); if (response.code !== 200 || !response.data) throw new Error(response.message || 'locations failed'); return response.data; }
  static async electricity(roomId: string): Promise<YKTElectricity> { const response = await ElectricityApi.get<YKTElectricityResponse>(`electricity?roomId=${encodeURIComponent(roomId)}`); if (response.code !== 200 || !response.data) throw new Error(response.message || 'electricity failed'); return response.data; }
  static async savedRooms(retry: boolean = true): Promise<YKTSavedRoom[]> {
    const storage = AppStorage.getInstance();
    const studentId = await storage.getStudentId();
    let token = await storage.getAppAuthAccessToken();
    if (!studentId) return [];
    if (!token && retry) {
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      token = await storage.getAppAuthAccessToken();
    }
    if (!token) return [];
    const result = await HttpRequest.get<YKTCloudResponse>(`https://lyzyy.love:8081/Misc/Support/sync?studentId=${encodeURIComponent(studentId)}`, { Authorization: `Bearer ${token}`, Accept: 'application/json' });
    if (result.data.code === 401 && retry) {
      await storage.setAppAuthAccessToken('');
      await ApiService.loginAppAuthFromSavedCredentials(storage);
      return ElectricityApi.savedRooms(false);
    }
    return result.data.data?.data?.electricity?.rooms || [];
  }
}
