/**
 * 数据类型定义
 * 与 memory-bank/DATA_MODEL.md 的表结构一一对应
 */

/** 植物（对应表 plant） */
export interface Plant {
  id: number;
  name: string;            // 植物昵称，如 "窗台的绿萝"
  species: string;         // 品种，如 "绿萝"
  place: string;           // 位置，如 "客厅窗台"
  status: number;          // 1=养护中 0=已归档
  createdAt: number;
  updatedAt: number;
}

/** 养护计划（对应表 care_plan）：某盆植物的某一类养护周期 */
export interface CarePlan {
  id: number;
  plantId: number;
  type: string;            // 养护类型名称，预设（浇水/施肥/修剪/换盆）或自定义（如"擦叶子"）
  intervalDays: number;    // 每 N 天一次
  remindTime: string;      // HH:mm，当天内的提醒时刻
  sortOrder: number;
}

/** 养护记录（对应表 care_record）：某盆植物某类养护在某天的打卡 */
export interface CareRecord {
  id: number;
  plantId: number;
  type: string;            // 养护类型名称，与养护计划的 type 对应
  planDate: string;        // YYYY-MM-DD
  status: number;          // 1=已完成 2=跳过
  doneAt: number;          // 实际打卡时间戳，未打卡为 0
}

/** 今日页的一条待办项（由 plant + care_plan + care_record 组合而来） */
export interface TodayItem {
  plantId: number;
  plantName: string;
  place: string;           // 植物位置，如"客厅窗台"
  type: string;            // 养护类型名称
  typeName: string;        // 展示用类型名（与 type 相同，保留字段减少视图改动）
  intervalDays: number;    // 周期，用于展示 "每 N 天"
  planTime: string;        // 当天提醒时刻 HH:mm
  status: number;          // 0=待做 1=已完成 2=跳过
  passed: boolean;         // 是否已过提醒时刻且未打卡
}

/** 今日页按植物分组的待办（一盆植物一张卡片） */
export interface PlantTaskGroup {
  plantId: number;
  plantName: string;
  place: string;
  items: TodayItem[];
  doneCount: number;
  totalCount: number;
}

/** 完成率统计结果 */
export interface Adherence {
  total: number;           // 应做总数
  done: number;            // 已完成数
  missed: number;          // 漏做/跳过数
  rate: number;            // 完成率，0~100 保留一位小数
}

/** 养护计划表单项（页面编辑用） */
export interface PlanItem {
  type: string;            // 养护类型名称，预设或自定义
  intervalDays: number;    // 每 N 天一次
  remindTime: string;      // HH:mm
}

/** 植物表单（页面提交用） */
export interface PlantForm {
  id: number;              // 0 表示新增
  name: string;
  species: string;
  place: string;
  plans: PlanItem[];       // 养护计划列表，至少 1 条
}

/** 按日期分组的记录（记录页用） */
export interface DateGroup {
  date: string;            // YYYY-MM-DD
  items: TodayItem[];
  doneCount: number;
  totalCount: number;
}

/** 统计卡片数据 */
export interface StatCard {
  title: string;
  value: string;
  sub: string;
}
