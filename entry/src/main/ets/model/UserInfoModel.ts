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
  stuNum?: string;
  studentNumber?: string;
  studentId?: string;
  studentName?: string;
  student_name?: string;
  userName?: string;
  stuName?: string;
  name?: string;
  nickName?: string;
  college?: string;
  department?: string;
  academy?: string;
  school?: string;
  major?: string;
  classes?: string;
  clazz?: string;
  className?: string;
  class?: string;
  class_name?: string;
  data?: StudentApiContent;
  value?: StudentApiContent;
  content?: StudentApiContent;
  studentInfo?: StudentApiContent;
}

export interface StudentApiResponse {
  code: number | string;
  msg?: string;
  data?: StudentApiContent;
  /** 部分接口版本使用 dataObject/value/message 包装学生信息。 */
  dataObject?: StudentApiContent;
  value?: StudentApiContent;
  message?: string;
  studentNumber?: string;
  name?: string;
  college?: string;
  major?: string;
  clazz?: string;
  studentInfo?: StudentApiContent;
}
