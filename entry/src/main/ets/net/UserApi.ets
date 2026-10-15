/**
 * UserApi — 用户信息网络接口
 *
 * 对应安卓 NewApiHelper.getUserInfo(listener)
 * 接口：WustApi.UG_STUDENT_INFO_V2
 *
 * 文件路径：entry/src/main/ets/net/UserApi.ets
 */
import { HttpRequest } from './HttpRequest';
import { StudentApiResponse, StudentApiContent } from '../model/UserInfoModel';

// iOS 当前生效实现：本科教务取数入口，凭登录 Cookie 获取学生信息页。
// 安卓端使用带 8081 端口的接口，并通过 Bearer Token 认证。
const UG_STUDENT_INFO_URL = 'https://lyzyy.love:8081/UnderGraduate/Support/getStudentInfoPage';
const GRADUATE_STUDENT_INFO_URL = 'https://www.lyzyy.love:8009/personal-info';
const UG_PARSE_LOGIN_URL = 'https://www.lyzyy.love:8081/mywustBasic/UnderGraduateStudent/login?username=';
const UG_PARSE_INFO_URL = 'https://www.lyzyy.love:8081/mywustBasic/UnderGraduateStudent/getStudentInfo';

interface StudentPageResponse {
  code: number | string;
  message?: string;
  msg?: string;
  data?: string;
}

interface ParseTokenResponse {
  code: number | string;
  message?: string;
  data?: string;
}

function normalizeStudentInfo(raw: StudentApiResponse): StudentApiContent | undefined {
  let source: StudentApiContent = raw.data ?? raw.dataObject ?? raw.value ?? raw.studentInfo ?? {
    stuNum: raw.studentNumber,
    stuName: raw.name,
    college: raw.college,
    major: raw.major,
    classes: raw.clazz
  };
  source = source.data ?? source.value ?? source.content ?? source.studentInfo ?? source;
  source = source.data ?? source.value ?? source.content ?? source.studentInfo ?? source;
  const result: StudentApiContent = {
    stuNum: source.stuNum ?? source.studentNumber ?? source.studentId,
    stuName: source.stuName ?? source.name ?? source.studentName ?? source.student_name ?? source.userName,
    nickName: source.nickName,
    college: source.college ?? source.department ?? source.academy ?? source.school,
    major: source.major,
    classes: source.classes ?? source.clazz ?? source.className ?? source.class ?? source.class_name,
  };
  const hasValue = !!(result.stuNum || result.stuName || result.nickName || result.college || result.major || result.classes);
  return hasValue ? result : undefined;
}

export class UserApi {
  /**
   * 获取用户信息
   * @param token 登录后保存的教务 Cookie
   */
  static async getUserInfo(token: string, studentId: string = ''): Promise<StudentApiResponse> {
    try {
      console.info('UserApi', `getStudentInfoPage start tokenLen=${token.length} studentId=${studentId}`);
      const result = await HttpRequest.request<StudentApiResponse>(
        UG_STUDENT_INFO_URL, 'GET',
        { headers: {
          Authorization: `Bearer ${token}`,
          Token: token,
          Cookie: token,
          Platform: 'android',
          Accept: 'application/json'
        } },
      );
      const rawData: StudentApiResponse | string = result.data as StudentApiResponse | string;
      if (typeof rawData === 'string') {
        return await UserApi.parseStudentPage(rawData, studentId);
      }
      const respData: StudentApiResponse = rawData;
      console.info('UserApi', `getStudentInfoPage response code=${String(respData.code)} hasData=${respData.data !== undefined}`);
      const pageResponse: StudentPageResponse = respData as StudentPageResponse;
      if (typeof pageResponse.data === 'string' && pageResponse.data.length > 0) {
        return await UserApi.parseStudentPage(pageResponse.data, studentId);
      }
      const normalized = normalizeStudentInfo(respData);
      console.info('UserApi', `normalized student info=${JSON.stringify(normalized)}`);
      if (respData && (respData.code === 200 || respData.code === 0 || respData.code === 10000 ||
        String(respData.code) === '200' || respData.data !== undefined ||
        respData.dataObject !== undefined || respData.value !== undefined || respData.name !== undefined ||
        respData.studentNumber !== undefined)) {
        if (normalized) {
          respData.data = normalized;
          return respData;
        }
      }
      // 兼容旧版教务节点：部分账号只能从 www 节点读取 Cookie 会话。
      const legacy = await HttpRequest.request<StudentApiResponse>(
        'https://www.lyzyy.love/UnderGraduate/Support/getStudentInfoPage', 'GET',
        { headers: { Authorization: `Bearer ${token}`, Token: token, Cookie: token, Platform: 'android', Accept: 'application/json' } }
      );
      const legacyRaw = legacy.data;
      if (typeof legacyRaw === 'string') return await UserApi.parseStudentPage(legacyRaw, studentId);
      const legacyInfo = normalizeStudentInfo(legacyRaw);
      if (legacyInfo) {
        legacyRaw.data = legacyInfo;
        return legacyRaw;
      }
      // 部分环境返回 HTML 页面串，按接口文档补走解析服务。
      return { code: respData?.code ?? -1, msg: respData?.msg ?? respData?.message ?? '请求失败' };
    } catch {
      console.warn('UserApi', 'getUserInfo error');
      return { code: -1, msg: '网络请求失败' };
    }
  }

  private static async parseStudentPage(page: string, studentId: string): Promise<StudentApiResponse> {
    const login = await HttpRequest.request<ParseTokenResponse>(
      UG_PARSE_LOGIN_URL + encodeURIComponent(studentId), 'POST',
      { headers: { Accept: 'application/json' } });
    const authData = login.data.data ?? '';
    if (!authData) return { code: -1, msg: '解析服务登录失败' };
    const parsed = await HttpRequest.postJson<StudentApiResponse>(UG_PARSE_INFO_URL, { webpage: page }, {
      Authorization: `Wuster ${authData}`,
      Accept: 'application/json',
    });
    const parsedResponse = parsed.data;
    const parsedInfo = normalizeStudentInfo(parsedResponse);
    console.info('UserApi', `parsed student info=${JSON.stringify(parsedInfo)}`);
    if (parsedInfo) parsedResponse.data = parsedInfo;
    return parsedResponse;
  }

  /** 研究生个人信息接口：登录即返回完整学生资料。 */
  static async getGraduateUserInfo(studentId: string, password: string): Promise<StudentApiResponse> {
    const result = await HttpRequest.request<StudentApiResponse>(GRADUATE_STUDENT_INFO_URL, 'POST', {
      headers: { Accept: 'application/json' },
      body: { student_id: studentId, password },
    });
    const response: StudentApiResponse = result.data;
    const normalized = normalizeStudentInfo(response);
    if (normalized) response.data = normalized;
    return response;
  }
}
