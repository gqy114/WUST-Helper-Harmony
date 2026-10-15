import { HttpRequest } from './HttpRequest';
import { AppStorage } from '../store/AppStorage';
interface AIChatData { answer?: string; }
export interface AIChatResponse { code?: number; message?: string; data?: AIChatData; }
interface AIHeaders extends Record<string, string> { Authorization: string; Platform: string; Accept: string; }
export class AIApi {
  static async chat(question: string): Promise<string> {
    const token = await AppStorage.getInstance().getAppAuthAccessToken();
    const headers: AIHeaders = { Authorization: `Bearer ${token}`, Platform: 'android', Accept: 'application/json' };
    const body = JSON.stringify({ question, history: [] });
    const result = await HttpRequest.postRawJson<AIChatResponse>('https://lyzyy.love:8081/api/v1/ai/chat', body, headers);
    return result.data.data?.answer || result.data.message || '暂时没有得到回答';
  }
}
