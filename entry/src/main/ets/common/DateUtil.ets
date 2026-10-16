/**
 * 日期时间工具
 * 统一使用字符串格式：日期 YYYY-MM-DD，时间 HH:mm
 */

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 把 Date 转成 YYYY-MM-DD */
export function toDateStr(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

/** 把 Date 转成 HH:mm */
export function toTimeStr(d: Date): string {
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

/** 今天，YYYY-MM-DD */
export function todayStr(): string {
  return toDateStr(new Date());
}

/** 当前时刻，HH:mm */
export function nowTimeStr(): string {
  return toTimeStr(new Date());
}

/** 当前毫秒时间戳 */
export function nowMs(): number {
  return new Date().getTime();
}

/**
 * 判断某个提醒时间是否已经过去（用于"已过时间"标签）
 * 传入 "08:00" 与 "09:30"，返回 true
 */
export function isTimePassed(remindTime: string, currentTime: string): boolean {
  return remindTime < currentTime;
}

/**
 * 取最近 n 天的日期字符串数组（含今天），由早到晚
 */
export function lastNDays(n: number): string[] {
  const result: string[] = [];
  const base = new Date();
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(base.getFullYear(), base.getMonth(), base.getDate() - i);
    result.push(toDateStr(d));
  }
  return result;
}

/**
 * 两个 YYYY-MM-DD 是否同一天
 */
export function isSameDate(a: string, b: string): boolean {
  return a === b;
}

/**
 * 某日期往后推 n 天，例如 addDays('2026-10-15', 3) 返回 '2026-10-18'
 * 用于养护周期顺延：上次浇水日期 + 周期 = 下次应浇日期
 */
export function addDays(dateStr: string, n: number): string {
  const parts: string[] = dateStr.split('-');
  const y = parseInt(parts[0]);
  const m = parseInt(parts[1]);
  const d = parseInt(parts[2]);
  return toDateStr(new Date(y, m - 1, d + n));
}

/** 友好的中文日期，例如 "10 月 15 日 周三" */
export function friendlyToday(): string {
  const d = new Date();
  const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return `${d.getMonth() + 1} 月 ${d.getDate()} 日 ${week[d.getDay()]}`;
}
