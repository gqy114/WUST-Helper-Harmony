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

const UG_STUDENT_INFO_URL = 'https://lyzyy.love:8081/UnderGraduate/Support/getStudentInfoPage';

export class UserApi {
  /**
   * 获取用户信息
   * @param token 登录 Bearer Token
   */
  static async getUserInfo(token: string): Promise<StudentApiResponse> {
    try {
      const result = await HttpRequest.request<StudentApiResponse>(
        UG_STUDENT_INFO_URL, 'GET',
        { headers: { Authorization: `Bearer ${token}`, Platform: 'android' } },
      );
      const respData = result.data;
      if (respData && (respData.code === 200 || respData.code === 0 || respData.code === 10000)) {
        return respData;
      }
      return { code: respData?.code ?? -1, msg: respData?.msg ?? '请求失败' };
    } catch {
      console.warn('UserApi', 'getUserInfo error');
      return { code: -1, msg: '网络请求失败' };
    }
  }
}
