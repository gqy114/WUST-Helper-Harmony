/**
 * LibraryLoanModel — 图书馆借阅数据模型
 *
 * 字段名对齐安卓 LibraryHistoryBean @SerializedName("value")
 *
 * 文件路径：entry/src/main/ets/model/LibraryLoanModel.ts
 */

/** 单条借阅记录 —— 对应安卓 LibraryHistoryBean */
export interface LibraryLoanItem {
  /** 图书名称 —— JSON: "title" */
  title: string;
  /** 作者 —— JSON: "author" */
  author: string;
  /** 借阅日期 —— JSON: "loanDate" */
  loanDate: string;
  /** 应还日期 —— JSON: "dueDate" */
  dueDate: string;
  /** 归还地点 —— JSON: "locaCodeDesc" */
  returnPlace: string;
  /** 索书号 —— JSON: "callNo" */
  callNumber: string;
  /** 条形码 —— JSON: "barCode" */
  barCode: string;
  /** 书目编号 —— JSON: "bibNo" */
  bibNo: string;
  /** ISBN —— JSON: "isbn" */
  isbn: string;
  /** 出版社 —— JSON: "publisher" */
  publisher: string;
}

/** 判断是否超期 */
export function isOverdue(dueDate: string): boolean {
  if (!dueDate) return false;
  const parts = dueDate.split('-');
  if (parts.length !== 3) return false;
  const due = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  return due.getTime() < now.getTime();
}

/** 格式化借阅状态文本 */
export function getLoanStatus(dueDate: string): string {
  return isOverdue(dueDate) ? '已超期' : '在借';
}