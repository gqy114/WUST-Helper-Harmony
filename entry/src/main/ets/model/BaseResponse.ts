// model/BaseResponse.ts

/**
 * 对应原 Android 端 BaseData / TokenData / GraduateLoginData
 */
export interface BaseResponse<T = unknown> {
  code: number;
  msg: string;
  data?: T;
}

export interface TokenDataContent {
  token: string;
  student_id: string;
  student_type: string;
}

export interface GraduateLoginDataContent {
  studentNumber: string;
  name: string;
  college: string;
  major: string;
  clazz: string;
  birthday: string;
  sex: string;
  nationality: string;
  hometown: string;
  idNumber: string;
}

export interface AppAuthDataContent {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  refreshExpiresAt: number;
  user?: {
    displayName: string;
    avatarUrl: string;
  };
}

export function isSuccess(code: number): boolean {
  return code === 200 || code === 0 || code === 10000 || code === 11000;
}
