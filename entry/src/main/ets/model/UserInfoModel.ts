/**
 * UserInfoModel — 用户信息数据模型
 *
 * 字段名对齐安卓 StudentData.Content 和 SharePreferenceLab
 *
 * 文件路径：entry/src/main/ets/model/UserInfoModel.ts
 */

/** 用户信息（本地持久化 + API 返回） */
export interface UserInfo {
  /** 学号 */
  studentId: string;
  /** 显示名称（优先昵称，回退到真实姓名） */
  userName: string;
  /** 真实姓名（API 返回 stuName） */
  realName?: string;
  /** 学院 */
  college?: string;
  /** 专业 */
  major?: string;
  /** 班级 */
  classes?: string;
  /** 头像路径 */
  avatarPath?: string;
}

/** 后端 StudentData.Content — @SerializedName("value") 为 JSON key */
export interface StudentApiContent {
  stuNum: string;
  stuName: string;
  nickName: string;
  college: string;
  major: string;
  classes: string;
}

export interface StudentApiResponse {
  code: number;
  msg: string;
  data?: StudentApiContent;
}