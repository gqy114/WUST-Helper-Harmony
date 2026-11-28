import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util, buffer } from '@kit.ArkTS';

export function stringToBytes(value: string): Uint8Array {
  return new Uint8Array(buffer.from(value, 'utf-8').buffer);
}

export function bytesToString(value: Uint8Array): string {
  return buffer.from(value.buffer, value.byteOffset, value.byteLength).toString('utf-8');
}

export function base64Encode(value: Uint8Array): string {
  return new util.Base64Helper().encodeToStringSync(value);
}

export function base64Decode(value: string): Uint8Array {
  return new util.Base64Helper().decodeSync(value);
}

export function randomBytes(length: number): Uint8Array {
  return cryptoFramework.createRandom().generateRandomSync(length).data;
}

/** RSA-OAEP(SHA-256) 加密 32 字节 AES 会话密钥，返回 Base64。 */
export async function encryptSessionKey(publicKeyDer: Uint8Array, sessionKey: Uint8Array): Promise<string> {
  const generator = cryptoFramework.createAsyKeyGenerator('RSA2048');
  const keyPair = await generator.convertKey({ data: publicKeyDer }, null);
  const cipher = cryptoFramework.createCipher('RSA2048|PKCS1_OAEP|SHA256|MGF1_SHA256');
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, keyPair.pubKey, null);
  const encrypted = await cipher.doFinal({ data: sessionKey });
  return base64Encode(encrypted.data);
}

async function aesKey(keyBytes: Uint8Array): Promise<cryptoFramework.SymKey> {
  const generator = cryptoFramework.createSymKeyGenerator('AES256');
  return generator.convertKey({ data: keyBytes });
}

/** AES-256-GCM 加密；输出为密文 + 16 字节认证标签（与协议 data 字段一致）。 */
export async function aesGcmEncrypt(keyBytes: Uint8Array, nonce: Uint8Array, aad: string,
  plainText: string): Promise<Uint8Array> {
  const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
  const params: cryptoFramework.GcmParamsSpec = {
    iv: { data: nonce },
    aad: { data: stringToBytes(aad) },
    authTag: { data: new Uint8Array(16) },
    algName: 'GcmParamsSpec'
  };
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, await aesKey(keyBytes), params);
  const output = await cipher.doFinal({ data: stringToBytes(plainText) });
  return output.data;
}

/** AES-256-GCM 解密；data 为密文 + 16 字节认证标签。 */
export async function aesGcmDecrypt(keyBytes: Uint8Array, nonce: Uint8Array, aad: string,
  data: Uint8Array): Promise<string> {
  if (data.length <= 16) throw new Error('加密消息长度异常');
  const cipherText = data.slice(0, data.length - 16);
  const tag = data.slice(data.length - 16);
  const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
  const params: cryptoFramework.GcmParamsSpec = {
    iv: { data: nonce },
    aad: { data: stringToBytes(aad) },
    authTag: { data: tag },
    algName: 'GcmParamsSpec'
  };
  await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, await aesKey(keyBytes), params);
  const output = await cipher.doFinal({ data: cipherText });
  return bytesToString(output.data);
}
