// 社区消息里的 @ 统一按学号存储，展示时用接口返回的 mentionUsers 转成昵称。
export interface MentionUser {
  studentId?: string;
  displayName?: string;
  realName?: string;
  nickname?: string;
  name?: string;
  id?: string | number;
}

/** 把文本里的 @学号 替换成 @昵称；没有对应昵称的保持原样。 */
export function formatMentionText(text: string, users?: MentionUser[]): string {
  let result = text || '';
  if (users === undefined || users.length === 0) return result;
  const replaced: string[] = [];
  for (let index = 0; index < users.length; index++) {
    const user = users[index];
    const studentId = `${user.studentId || user.id || ''}`.trim();
    const name = `${user.displayName || user.realName || user.nickname || user.name || ''}`.trim();
    if (studentId.length === 0 || name.length === 0) continue;
    if (replaced.indexOf(studentId) >= 0) continue;
    replaced.push(studentId);
    result = result.split(`@${studentId}`).join(`@${name}`);
  }
  return result;
}
