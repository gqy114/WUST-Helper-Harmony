/**
 * GradeModel — 成绩数据模型
 *
 * 字段名与安卓 GradeBean.java 保持完全一致
 * JSON key = @SerializedName("value")，字段名 = Java 字段名
 *
 * 文件路径：entry/src/main/ets/model/GradeModel.ts
 */

/** 本科生成绩单条记录 —— 对应安卓 GradeBean */
export interface GradeBean {
  courseNum: string;
  courseName: string;
  /** 分数，String 类型保存，含 "92" / "优秀" / "通过" 等 */
  grade: string;
  /** 学分，String 类型，默认 "0" */
  courseCredit: string;
  /** 学时 */
  courseHours: string;
  /** 绩点，String 类型，默认 "0" */
  gradePoint: string;
  /** 考核方式：考试 / 考查 */
  evaluationMode: string;
  /** 考试性质：期末 / 补考 / 重修 */
  examNature: string;
  /** 课程性质：必修 / 选修 / 通识 */
  courseNature: string;
  /** 学年学期，如 "2025-2026-1" */
  schoolTerm: string;
  /** 缺考标记 */
  missExamTag: number;
  /** 补考标记 */
  reExamTag: number;
  /** 重修标记 */
  rebuildTag: number;
}

/** 研究生成绩单条记录 —— 对应安卓 GraduateGradeBean */
export interface GraduateGradeBean {
  name: string;
  credit: string;
  point: string;
  term: string;
}

/** 成绩统计摘要 */
export interface GradeStatSummary {
  totalCredits: string;
  averageGpa: string;
  courseCount: number;
  failedCount: number;
}

/** 计算统计摘要 */
export function calcGradeSummary(items: GradeBean[]): GradeStatSummary {
  let totalCredits = 0;
  let totalGpaSum = 0;
  let failedCount = 0;

  for (const item of items) {
    const credit = parseFloat(item.courseCredit) || 0;
    const gpa = parseFloat(item.gradePoint) || 0;
    totalCredits += credit;
    totalGpaSum += credit * gpa;

    const scoreNum = parseFloat(item.grade);
    if (isNaN(scoreNum)) {
      if (item.grade === '不及格' || item.grade === '不通过') failedCount++;
    } else if (scoreNum < 60) {
      failedCount++;
    }
  }

  const avgGpa = totalCredits > 0 ? totalGpaSum / totalCredits : 0;

  return {
    totalCredits: totalCredits.toFixed(1),
    averageGpa: avgGpa.toFixed(2),
    courseCount: items.length,
    failedCount: failedCount,
  };
}