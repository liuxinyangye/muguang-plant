/**
 * 养护业务逻辑
 * 负责：生成某天应做的养护任务、打卡 / 撤销、完成率统计
 * 对应 memory-bank/DATA_MODEL.md 第 3 节的统计口径
 *
 * 到期规则（周期模型）：
 * 某盆植物某类养护在某天"应做"，当且仅当
 *   ① 该天不早于植物的加入日期（加入家的日子之前，不产生任何任务）
 *   ② 从未完成过，或 最近一次完成日（严格早于该天）+ 周期天数 <= 该天
 * 完成后从次日开始顺延一个周期；当天完成的任务当天仍留在清单里（显示"已做"）。
 */
import { CareRecord, Adherence, TodayItem, DateGroup, PlantTaskGroup, Plant, CarePlan } from '../model/Types';
import { RecordDao } from '../model/RecordDao';
import { PlantDao } from '../model/PlantDao';
import { PlantService } from './PlantService';
import { RecordStatus } from '../common/Constants';
import { lastNDays, todayStr, nowTimeStr, isTimePassed, addDays, toDateStr } from '../common/DateUtil';

export class CareService {

  /** 判断某盆植物某类养护在某天是否到期应做 */
  private static isDue(plant: Plant, plan: CarePlan, date: string): boolean {
    // ① 植物还没加入家的日子，不应做任何事
    const createdDate: string = toDateStr(new Date(plant.createdAt));
    if (date < createdDate) {
      return false;
    }
    // ② 按周期判断：最近一次完成（严格早于该天，同类型同周期分开算）+ 周期 <= 该天
    const lastDone: string = RecordDao.lastDoneDate(plant.id, plan.type, plan.intervalDays, date);
    if (lastDone === '') {
      return true; // 从未完成过，从加入那天起一直应做
    }
    const nextDue: string = addDays(lastDone, plan.intervalDays);
    return date >= nextDue;
  }

  /**
   * 生成某一天的养护待办
   * 由「养护中的植物 × 到期的养护计划」组合出待办项，并带上打卡状态
   */
  static planOf(date: string): TodayItem[] {
    const result: TodayItem[] = [];
    const plants = PlantDao.activeOn();
    const now: string = nowTimeStr();

    for (const p of plants) {
      const plans = PlantDao.plansOf(p.id);
      for (const plan of plans) {
        if (!CareService.isDue(p, plan, date)) {
          continue;
        }
        const status: number = RecordDao.statusOf(p.id, plan.type, plan.intervalDays, date);
        let passed: boolean = false;
        if (date === todayStr()) {
          passed = status === RecordStatus.WAIT && isTimePassed(plan.remindTime, now);
        }
        result.push({
          plantId: p.id,
          plantName: p.name,
          place: p.place,
          type: plan.type,
          typeName: plan.type,
          intervalDays: plan.intervalDays,
          planTime: plan.remindTime,
          status: status,
          passed: passed
        });
      }
    }
    result.sort((a: TodayItem, b: TodayItem) => a.planTime < b.planTime ? -1 : 1);
    return result;
  }

  /** 计划里已完成的条数 */
  static doneCount(items: TodayItem[]): number {
    let n: number = 0;
    for (const it of items) {
      if (it.status === RecordStatus.DONE) {
        n++;
      }
    }
    return n;
  }

  /**
   * 生成最近 n 天的按日分组数据，用于记录页
   * 由近到远排列；没有养护任务的日子（如植物加入之前）不展示
   */
  static groupsOf(days: number): DateGroup[] {
    const dates: string[] = lastNDays(days);
    const result: DateGroup[] = [];
    for (let i = dates.length - 1; i >= 0; i--) {
      const date: string = dates[i];
      const items: TodayItem[] = CareService.planOf(date);
      if (items.length === 0) {
        continue;
      }
      result.push({
        date: date,
        items: items,
        doneCount: CareService.doneCount(items),
        totalCount: items.length
      });
    }
    return result;
  }

  /**
   * 切换打卡状态（记账键含周期：同类型多条计划各自独立，2026-10-17）
   * 当前未完成 → 标记为已完成；当前已完成 → 撤销（删除记录）
   */
  static async toggle(plantId: number, type: string, intervalDays: number, date: string): Promise<void> {
    const current: number = RecordDao.statusOf(plantId, type, intervalDays, date);
    if (current === RecordStatus.DONE) {
      await RecordDao.undo(plantId, type, intervalDays, date);
    } else {
      await RecordDao.setStatus(plantId, type, intervalDays, date, RecordStatus.DONE);
    }
  }

  /** 主动跳过 */
  static async skip(plantId: number, type: string, intervalDays: number, date: string): Promise<void> {
    await RecordDao.setStatus(plantId, type, intervalDays, date, RecordStatus.SKIPPED);
  }

  /**
   * 计算最近 n 天的完成率
   * 应做总数 = 各天"到期任务"之和（与记录页展示的清单同源，保证数字对得上）
   * 已做数   = 到期任务中 status = 已完成的条数
   * 漏做数   = 到期任务中未完成也未跳过的条数
   * 完成率   = 已做 / 应做，保留一位小数
   */
  static adherence(days: number): Adherence {
    const dates: string[] = lastNDays(days);

    let total: number = 0;
    let done: number = 0;
    let skipped: number = 0;
    for (const d of dates) {
      const items: TodayItem[] = CareService.planOf(d);
      total += items.length;
      for (const it of items) {
        if (it.status === RecordStatus.DONE) {
          done++;
        } else if (it.status === RecordStatus.SKIPPED) {
          skipped++;
        }
      }
    }

    let missed: number = total - done - skipped;
    if (missed < 0) {
      missed = 0;
    }

    let rate: number = 0;
    if (total > 0) {
      rate = Math.round(done * 1000 / total) / 10;
    }
    if (rate > 100) {
      rate = 100;
    }

    return { total: total, done: done, missed: missed, rate: rate };
  }

  /** 今日完成情况（首页进度用） */
  static todayProgress(): Adherence {
    const items: TodayItem[] = CareService.planOf(todayStr());
    let done: number = 0;
    for (const it of items) {
      if (it.status === RecordStatus.DONE) {
        done++;
      }
    }
    const total: number = items.length;
    let rate: number = 0;
    if (total > 0) {
      rate = Math.round(done * 1000 / total) / 10;
    }
    return { total: total, done: done, missed: total - done, rate: rate };
  }

  /** 最近一次养护的文字，没有记录返回「暂无记录」 */
  static lastCareText(): string {
    let latest: CareRecord | null = null;
    for (const r of RecordDao.inRange('0000-00-00', '9999-99-99')) {
      if (r.status !== RecordStatus.DONE) {
        continue;
      }
      if (latest === null || r.planDate > latest.planDate) {
        latest = r;
      }
    }
    if (latest === null) {
      return '暂无记录';
    }
    const p = PlantDao.findById(latest.plantId);
    const name: string = p === null ? '某盆植物' : p.name;
    return `${latest.planDate} ${latest.type} ${name}`;
  }

  /**
   * 今日页按植物分组的待办（2026-10-15 新增）
   * 一盆植物一张卡片：卡片头是植物名与位置，卡片内是该植物今天到期的各项养护
   */
  static planGrouped(date: string): PlantTaskGroup[] {
    const items: TodayItem[] = CareService.planOf(date);
    const result: PlantTaskGroup[] = [];
    for (const it of items) {
      let group: PlantTaskGroup | null = null;
      for (const g of result) {
        if (g.plantId === it.plantId) {
          group = g;
          break;
        }
      }
      if (group === null) {
        group = {
          plantId: it.plantId,
          plantName: it.plantName,
          place: it.place,
          items: [],
          doneCount: 0,
          totalCount: 0
        };
        result.push(group);
      }
      group.items.push(it);
      group.totalCount++;
      if (it.status === RecordStatus.DONE) {
        group.doneCount++;
      }
    }
    return result;
  }
}
