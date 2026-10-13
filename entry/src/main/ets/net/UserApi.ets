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
const UG_STUDENT_INFO_URL = 'https://www.lyzyy.love/UnderGraduate/Support/getStudentInfoPage';

export class UserApi {
  /**
   * 获取用户信息
   * @param token 登录后保存的教务 Cookie
   */
  static async getUserInfo(token: string): Promise<StudentApiResponse> {
    try {
      const result = await HttpRequest.request<StudentApiResponse>(
        UG_STUDENT_INFO_URL, 'GET',
        { headers: { Cookie: token, Accept: 'application/json' } },
      );
      const respData = result.data;
      if (respData && (respData.code === 200 || respData.code === 0 || respData.code === 10000 ||
        respData.data !== undefined || respData.dataObject !== undefined || respData.value !== undefined)) {
        if (!respData.data) {
          respData.data = respData.dataObject || respData.value || {
            studentNumber: respData.studentNumber,
            name: respData.name,
            college: respData.college,
            major: respData.major,
            clazz: respData.clazz
          };
        }
        return respData;
      }
      return { code: respData?.code ?? -1, msg: respData?.msg ?? '请求失败' };
    } catch {
      console.warn('UserApi', 'getUserInfo error');
      return { code: -1, msg: '网络请求失败' };
    }
  }
}
