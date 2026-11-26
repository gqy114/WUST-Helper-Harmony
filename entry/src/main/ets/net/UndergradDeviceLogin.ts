import { webSocket } from '@kit.NetworkKit';
import { http } from '@kit.NetworkKit';
import { url } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  aesGcmDecrypt, aesGcmEncrypt, base64Decode, base64Encode, bytesToString, encryptSessionKey,
  randomBytes, stringToBytes
} from './DeviceLoginCrypto';

export const DEVICE_LOGIN_BASE: string = 'https://port.happylandmc.cc:52145';
const DEVICE_LOGIN_WS: string = 'wss://port.happylandmc.cc:52145/UnderGraduate/Support/deviceLogin/connect';
const CLIENT_AAD: string = 'wust-device-to-server-v1';
const SERVER_AAD: string = 'wust-server-to-device-v1';
const SESSION_TIMEOUT_MS: number = 180000;
const START_TIMEOUT_MS: number = 15000;
const MAX_BODY_BYTES: number = 10 * 1024 * 1024;
const ALLOWED_HOSTS: string[] = ['auth.wust.edu.cn', 'portal.wust.edu.cn', 'bkjx.wust.edu.cn'];

export interface DeviceAppUser {
  id?: number;
  studentId?: string;
  studentType?: string;
  realName?: string;
  displayName?: string;
  avatarUrl?: string;
  college?: string;
  major?: string;
  clazz?: string;
}

export interface DeviceAppAuth {
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: number;
  refreshExpiresAt?: number;
  user?: DeviceAppUser;
}

export interface DeviceLoginData {
  token?: string;
  student_id?: string;
  student_type?: string;
  status?: string;
  appAuth?: DeviceAppAuth;
}

export interface DeviceLoginOutcome {
  code: number;
  message: string;
  data?: DeviceLoginData;
}

interface RelayRequest {
  kind: string;
  id?: number;
  method?: string;
  url?: string;
  headers?: Record<string, string[]>;
  body_base64?: string;
}

interface RelayResponse {
  kind: string;
  id?: number;
  status_code?: number;
  headers?: Record<string, string[]>;
  body_base64?: string;
  error?: string;
}

interface DevicePayload extends RelayRequest { result?: DeviceLoginOutcome; }

interface ServerMessage {
  kind?: string;
  public_key?: string;
  nonce?: string;
  data?: string;
  result?: DeviceLoginOutcome;
}

function headersToRecord(headers: Object | undefined): Record<string, string[]> {
  const result: Record<string, string[]> = {};
  if (!headers) return result;
  const source = headers as Record<string, Object>;
  const keys = Object.keys(source);
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    const value = source[key];
    if (Array.isArray(value)) {
      result[key] = (value as string[]).map((item: string) => `${item}`);
    } else if (value !== undefined && value !== null) {
      result[key] = [`${value}`];
    }
  }
  return result;
}

function joinHeader(values: string[], name: string): string {
  return name.toLowerCase() === 'cookie' ? values.join('; ') : values.join(', ');
}

function isAllowedUrl(raw: string): boolean {
  try {
    const parsed = new url.URL(raw);
    if (parsed.protocol !== 'https:') return false;
    if (parsed.port.length > 0 && parsed.port !== '443') return false;
    if (parsed.username.length > 0 || parsed.password.length > 0) return false;
    return ALLOWED_HOSTS.indexOf(parsed.hostname) >= 0;
  } catch (error) {
    return false;
  }
}

/** 转发后端要求手机访问的学校请求，原样返回状态码、响应头和响应体。 */
async function relaySchoolRequest(request: RelayRequest): Promise<RelayResponse> {
  const id = request.id ?? 0;
  const target = request.url ?? '';
  if (!isAllowedUrl(target)) {
    return { kind: 'response', id, error: '学校地址不受信任，已拒绝转发' };
  }
  const method = (request.method ?? 'GET').toUpperCase();
  if (method !== 'GET' && method !== 'POST') {
    return { kind: 'response', id, error: '不支持的请求方法' };
  }
  const headers: Record<string, string> = {};
  const sourceHeaders = request.headers ?? {};
  const names = Object.keys(sourceHeaders);
  for (let i = 0; i < names.length; i++) {
    const name = names[i];
    const lower = name.toLowerCase();
    if (lower === 'host' || lower === 'content-length' || lower === 'connection' ||
      lower === 'proxy-connection' || lower === 'accept-encoding') continue;
    headers[name] = joinHeader(sourceHeaders[name], name);
  }
  headers['Accept-Encoding'] = 'identity';

  let body: ArrayBuffer | undefined = undefined;
  if (request.body_base64 && request.body_base64.length > 0) {
    if (request.body_base64.length > Math.ceil(MAX_BODY_BYTES / 3) * 4) {
      return { kind: 'response', id, error: '请求体过大' };
    }
    const bytes = base64Decode(request.body_base64);
    if (bytes.length > MAX_BODY_BYTES) {
      return { kind: 'response', id, error: '请求体过大' };
    }
    body = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  }

  const client = http.createHttp();
  try {
    const response = await client.request(target, {
      method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
      header: headers,
      extraData: body,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 15000,
      readTimeout: 30000,
      maxLimit: MAX_BODY_BYTES,
      maxRedirects: 0
    });
    let encoded = '';
    if (response.result instanceof ArrayBuffer) {
      encoded = base64Encode(new Uint8Array(response.result));
    } else if (typeof response.result === 'string') {
      encoded = base64Encode(stringToBytes(response.result));
    }
    return {
      kind: 'response',
      id,
      status_code: response.responseCode,
      headers: headersToRecord(response.header),
      body_base64: encoded
    };
  } catch (error) {
    return { kind: 'response', id, error: `手机无法访问学校：${(error as Error).message ?? '网络错误'}` };
  } finally {
    client.destroy();
  }
}

/**
 * 本科设备登录：WebSocket + RSA-OAEP + AES-256-GCM。
 * 失败时抛出 Error，由调用方决定是否回退旧登录。
 */
class DeviceLoginUnavailableError extends Error {}

export class UndergradDeviceLogin {
  static canFallback(error: Error): boolean {
    return error instanceof DeviceLoginUnavailableError;
  }

  static async login(studentId: string, password: string): Promise<DeviceLoginOutcome> {
    const username = studentId.trim();
    const pwd = password.trim();
    const socket = webSocket.createWebSocket();
    let sessionKey: Uint8Array | undefined = undefined;
    let settled = false;
    let startSubmitted = false;
    let timer: number = -1;
    let startTimer: number = -1;

    return new Promise<DeviceLoginOutcome>((resolve, reject) => {
      const cleanup = (): void => {
        settled = true;
        clearTimeout(timer);
        clearTimeout(startTimer);
        try {
          socket.close().catch((): void => {});
        } catch {}
      };
      const finish = (outcome: DeviceLoginOutcome): void => {
        if (settled) return;
        cleanup();
        resolve(outcome);
      };
      const fail = (message: string): void => {
        if (settled) return;
        cleanup();
        reject(startSubmitted ? new Error(message) : new DeviceLoginUnavailableError(message));
      };
      const sendJson = async (payload: string, isStart: boolean = false): Promise<void> => {
        if (!sessionKey) throw new Error('加密通道尚未建立');
        const nonce = randomBytes(12);
        const encrypted = await aesGcmEncrypt(sessionKey, nonce, CLIENT_AAD, payload);
        if (settled) return;
        if (isStart) startSubmitted = true;
        const sent = await socket.send(JSON.stringify({ nonce: base64Encode(nonce), data: base64Encode(encrypted) }));
        if (!sent) throw new Error('登录消息发送失败');
        if (isStart) clearTimeout(startTimer);
      };

      timer = setTimeout(() => fail('登录超时，请检查网络后重试'), SESSION_TIMEOUT_MS);
      startTimer = setTimeout(() => fail('登录服务响应超时，请重试'), START_TIMEOUT_MS);

      socket.on('open', () => {
        // 连接已建立，等待后端下发 RSA 公钥。
      });
      socket.on('close', () => {
        if (!settled) fail('登录连接已断开，请重试');
      });
      socket.on('error', () => {
        if (!settled) fail('无法连接登录服务，请检查网络');
      });
      socket.on('message', async (error: BusinessError, data: string | ArrayBuffer) => {
        try {
          if (settled) return;
          if (error) throw error;
          const raw = typeof data === 'string' ? data : bytesToString(new Uint8Array(data));
          const message = JSON.parse(raw) as ServerMessage;
          if (message.kind === 'key' && message.public_key && !sessionKey) {
            sessionKey = randomBytes(32);
            const encryptedKey = await encryptSessionKey(base64Decode(message.public_key), sessionKey);
            if (settled) return;
            const sent = await socket.send(JSON.stringify({ kind: 'key', encrypted_key: encryptedKey }));
            if (!sent) throw new Error('登录密钥发送失败');
            await sendJson(JSON.stringify({ kind: 'start', username, password: pwd }), true);
            return;
          }
          if (!startSubmitted || !sessionKey || !message.nonce || !message.data) return;
          const plain = await aesGcmDecrypt(sessionKey, base64Decode(message.nonce), SERVER_AAD,
            base64Decode(message.data));
          if (settled) return;
          const payload = JSON.parse(plain) as DevicePayload;
          if (payload.kind === 'request') {
            const response = await relaySchoolRequest(payload as RelayRequest);
            await sendJson(JSON.stringify(response as RelayResponse));
            return;
          }
          if (payload.kind === 'result' && payload.result) {
            finish(payload.result);
          }
        } catch (error) {
          fail(`登录过程出错：${(error as Error).message ?? '未知错误'}`);
        }
      });

      socket.connect(DEVICE_LOGIN_WS, { header: { Platform: 'harmony' } }).then((connected: boolean): void => {
        if (!connected) fail('无法连接登录服务，请检查网络');
      }).catch((): void => {
        fail('无法连接登录服务，请检查网络');
      });
    });
  }

  /** 用已有教务 Cookie 换取新的 App 会话；无需密码。 */
  static async complete(studentId: string, cookie: string): Promise<DeviceLoginOutcome> {
    const client = http.createHttp();
    try {
      const response = await client.request(`${DEVICE_LOGIN_BASE}/UnderGraduate/Support/deviceLogin/complete`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Platform': 'harmony',
          'Accept': 'application/json'
        },
        extraData: JSON.stringify({ student_id: studentId, cookie }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        maxRedirects: 0
      });
      if (response.responseCode !== 200) {
        return { code: response.responseCode, message: '登录服务未能恢复会话' };
      }
      const body = typeof response.result === 'string' ? response.result : bytesToString(new Uint8Array(response.result as ArrayBuffer));
      const parsed = JSON.parse(body) as DeviceLoginOutcome;
      return parsed;
    } finally {
      client.destroy();
    }
  }
}
