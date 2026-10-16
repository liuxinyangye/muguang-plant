/**
 * 养护记录数据访问
 * 对应 memory-bank/DATA_MODEL.md 的 care_record 表
 *
 * 与 PlantDao 相同的策略：内存为主，数据库为持久化镜像。
 */
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbHelper } from './DbHelper';
import { CareRecord } from './Types';
import { DbCfg, RecordStatus } from '../common/Constants';
import { nowMs } from '../common/DateUtil';

const DOMAIN = 0x0000;
const TAG = 'Muguang.RecordDao';

export class RecordDao {
  private static list: CareRecord[] = [];
  private static memId: number = 1;
  private static loaded: boolean = false;

  /** 从数据库读入内存 */
  static async load(): Promise<void> {
    if (RecordDao.loaded) {
      return;
    }
    RecordDao.loaded = true;
    const store = DbHelper.getStore();
    if (store === null) {
      return;
    }
    try {
      const rs: relationalStore.ResultSet =
        await store.querySql('SELECT id, plant_id, type, plan_date, status, done_at FROM care_record ORDER BY plan_date ASC');
      while (rs.goToNextRow()) {
        const item: CareRecord = {
          id: rs.getLong(rs.getColumnIndex('id')),
          plantId: rs.getLong(rs.getColumnIndex('plant_id')),
          type: rs.getString(rs.getColumnIndex('type')),
          planDate: rs.getString(rs.getColumnIndex('plan_date')),
          status: rs.getLong(rs.getColumnIndex('status')),
          doneAt: rs.getLong(rs.getColumnIndex('done_at'))
        };
        RecordDao.list.push(item);
        if (item.id >= RecordDao.memId) {
          RecordDao.memId = item.id + 1;
        }
      }
      rs.close();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '读取记录失败: %{public}s', JSON.stringify(err));
    }
  }

  /** 查某一天某类养护的一条记录 */
  private static find(plantId: number, type: string, date: string): CareRecord | null {
    for (const r of RecordDao.list) {
      if (r.plantId === plantId && r.type === type && r.planDate === date) {
        return r;
      }
    }
    return null;
  }

  /**
   * 打卡 / 跳过：存在则改状态，不存在则新增
   * 唯一约束保证同一天同一类养护只有一条记录
   */
  static async setStatus(plantId: number, type: string, date: string, status: number): Promise<void> {
    const store = DbHelper.getStore();
    const ts = nowMs();
    const exist = RecordDao.find(plantId, type, date);

    if (exist === null) {
      const item: CareRecord = {
        id: 0,
        plantId: plantId,
        type: type,
        planDate: date,
        status: status,
        doneAt: ts
      };
      if (store !== null) {
        try {
          const bucket: relationalStore.ValuesBucket = {
            'plant_id': plantId,
            'type': type,
            'plan_date': date,
            'status': status,
            'done_at': ts
          };
          item.id = await store.insert(DbCfg.T_RECORD, bucket);
        } catch (err) {
          hilog.warn(DOMAIN, TAG, '写入记录失败: %{public}s', JSON.stringify(err));
          item.id = RecordDao.memId++;
        }
      } else {
        item.id = RecordDao.memId++;
      }
      RecordDao.list.push(item);
    } else {
      exist.status = status;
      exist.doneAt = ts;
      if (store !== null) {
        try {
          await store.executeSql(
            'UPDATE care_record SET status = ?, done_at = ? WHERE plant_id = ? AND type = ? AND plan_date = ?',
            [status, ts, plantId, type, date]);
        } catch (err) {
          hilog.warn(DOMAIN, TAG, '更新记录失败: %{public}s', JSON.stringify(err));
        }
      }
    }
  }

  /** 撤销打卡：删除该条记录 */
  static async undo(plantId: number, type: string, date: string): Promise<void> {
    const kept: CareRecord[] = [];
    for (const r of RecordDao.list) {
      if (!(r.plantId === plantId && r.type === type && r.planDate === date)) {
        kept.push(r);
      }
    }
    RecordDao.list = kept;

    const store = DbHelper.getStore();
    if (store !== null) {
      try {
        await store.executeSql(
          'DELETE FROM care_record WHERE plant_id = ? AND type = ? AND plan_date = ?',
          [plantId, type, date]);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '撤销记录失败: %{public}s', JSON.stringify(err));
      }
    }
  }

  /** 取某条记录的状态，没有记录返回 0（待做） */
  static statusOf(plantId: number, type: string, date: string): number {
    const r = RecordDao.find(plantId, type, date);
    return r === null ? RecordStatus.WAIT : r.status;
  }

  /**
   * 某盆植物某类养护「最近一次完成」的日期
   * 只看 status = 已完成 的记录，且严格早于 beforeDate（当天的完成从次日才开始顺延周期）
   * 返回 '' 表示从未完成过
   * 用于计算周期到期：最近完成日 + 周期 = 下次应做日
   */
  static lastDoneDate(plantId: number, type: string, beforeDate: string): string {
    let latest: string = '';
    for (const r of RecordDao.list) {
      if (r.plantId === plantId && r.type === type && r.status === RecordStatus.DONE
        && r.planDate < beforeDate) {
        if (r.planDate > latest) {
          latest = r.planDate;
        }
      }
    }
    return latest;
  }

  /** 清空全部养护记录（设置页"清空全部数据"用，2026-10-15 新增） */
  static async removeAll(): Promise<void> {
    RecordDao.list = [];
    const store = DbHelper.getStore();
    if (store !== null) {
      try {
        await store.executeSql('DELETE FROM care_record');
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '清空记录失败: %{public}s', JSON.stringify(err));
      }
    }
  }

  /** 日期区间内的全部记录（含两端） */
  static inRange(from: string, to: string): CareRecord[] {
    const result: CareRecord[] = [];
    for (const r of RecordDao.list) {
      if (r.planDate >= from && r.planDate <= to) {
        result.push(r);
      }
    }
    return result;
  }

  /** 统计区间内已完成 / 跳过数量 */
  static countInRange(from: string, to: string, status: number): number {
    let count: number = 0;
    for (const r of RecordDao.list) {
      if (r.planDate >= from && r.planDate <= to && r.status === status) {
        count++;
      }
    }
    return count;
  }
}
