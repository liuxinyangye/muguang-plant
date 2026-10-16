/**
 * 植物数据访问（含养护计划）
 * 对应 memory-bank/ARCHITECTURE.md 的数据访问层
 *
 * 工作方式：内存数组作为本次运行的「工作副本」，数据库作为持久化镜像。
 * 启动时从数据库读入内存；每次写入先更新内存，再尽力写库。
 * 这样即使数据库不可用（例如预览环境），界面依然可正常演示。
 */
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbHelper } from './DbHelper';
import { Plant, CarePlan, PlantForm, PlanItem } from './Types';
import { DbCfg, PlantStatus } from '../common/Constants';
import { nowMs } from '../common/DateUtil';

const DOMAIN = 0x0000;
const TAG = 'Muguang.PlantDao';

export class PlantDao {
  private static list: Plant[] = [];
  private static planList: CarePlan[] = [];
  private static memId: number = 1;
  private static memPlanId: number = 1;
  private static loaded: boolean = false;

  /** 从数据库读入内存，应用启动时调用一次 */
  static async load(): Promise<void> {
    if (PlantDao.loaded) {
      return;
    }
    PlantDao.loaded = true;
    const store = DbHelper.getStore();
    if (store === null) {
      return;
    }
    try {
      const rs: relationalStore.ResultSet =
        await store.querySql('SELECT id, name, species, place, status, created_at, updated_at FROM plant ORDER BY id ASC');
      while (rs.goToNextRow()) {
        const item: Plant = {
          id: rs.getLong(rs.getColumnIndex('id')),
          name: rs.getString(rs.getColumnIndex('name')),
          species: rs.getString(rs.getColumnIndex('species')),
          place: rs.getString(rs.getColumnIndex('place')),
          status: rs.getLong(rs.getColumnIndex('status')),
          createdAt: rs.getLong(rs.getColumnIndex('created_at')),
          updatedAt: rs.getLong(rs.getColumnIndex('updated_at'))
        };
        PlantDao.list.push(item);
        if (item.id >= PlantDao.memId) {
          PlantDao.memId = item.id + 1;
        }
      }
      rs.close();

      const rs2: relationalStore.ResultSet =
        await store.querySql('SELECT id, plant_id, type, interval_days, remind_time, sort_order FROM care_plan ORDER BY plant_id ASC, sort_order ASC');
      while (rs2.goToNextRow()) {
        const p: CarePlan = {
          id: rs2.getLong(rs2.getColumnIndex('id')),
          plantId: rs2.getLong(rs2.getColumnIndex('plant_id')),
          type: rs2.getString(rs2.getColumnIndex('type')),
          intervalDays: rs2.getLong(rs2.getColumnIndex('interval_days')),
          remindTime: rs2.getString(rs2.getColumnIndex('remind_time')),
          sortOrder: rs2.getLong(rs2.getColumnIndex('sort_order'))
        };
        PlantDao.planList.push(p);
        if (p.id >= PlantDao.memPlanId) {
          PlantDao.memPlanId = p.id + 1;
        }
      }
      rs2.close();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '读取植物失败: %{public}s', JSON.stringify(err));
    }
  }

  /** 全部植物 */
  static all(): Plant[] {
    return PlantDao.list;
  }

  /** 养护中的植物 */
  static activeOn(): Plant[] {
    const result: Plant[] = [];
    for (const p of PlantDao.list) {
      if (p.status === PlantStatus.ACTIVE) {
        result.push(p);
      }
    }
    return result;
  }

  /** 某盆植物的养护计划，按添加顺序排序 */
  static plansOf(plantId: number): CarePlan[] {
    const result: CarePlan[] = [];
    for (const p of PlantDao.planList) {
      if (p.plantId === plantId) {
        result.push(p);
      }
    }
    result.sort((a: CarePlan, b: CarePlan) => a.sortOrder < b.sortOrder ? -1 : 1);
    return result;
  }

  /** 某盆植物养护计划的文字摘要，如 "浇水 每2天 · 施肥 每30天" */
  static careTextOf(plantId: number): string {
    const plans = PlantDao.plansOf(plantId);
    if (plans.length === 0) {
      return '未设置养护计划';
    }
    const parts: string[] = [];
    for (const p of plans) {
      parts.push(`${p.type} 每${p.intervalDays}天`);
    }
    return parts.join(' · ');
  }

  /** 按 id 取植物 */
  static findById(id: number): Plant | null {
    for (const p of PlantDao.list) {
      if (p.id === id) {
        return p;
      }
    }
    return null;
  }

  /** 新增或更新植物，返回植物 id */
  static async save(form: PlantForm): Promise<number> {
    const store = DbHelper.getStore();
    const ts = nowMs();
    let id: number = form.id;

    if (id === 0) {
      const item: Plant = {
        id: 0,
        name: form.name,
        species: form.species,
        place: form.place,
        status: PlantStatus.ACTIVE,
        createdAt: ts,
        updatedAt: ts
      };
      if (store !== null) {
        try {
          const bucket: relationalStore.ValuesBucket = {
            'name': item.name,
            'species': item.species,
            'place': item.place,
            'status': item.status,
            'created_at': item.createdAt,
            'updated_at': item.updatedAt
          };
          id = await store.insert(DbCfg.T_PLANT, bucket);
        } catch (err) {
          hilog.warn(DOMAIN, TAG, '写入植物失败: %{public}s', JSON.stringify(err));
          id = PlantDao.memId++;
        }
      } else {
        id = PlantDao.memId++;
      }
      item.id = id;
      PlantDao.list.push(item);
    } else {
      const item = PlantDao.findById(id);
      if (item !== null) {
        item.name = form.name;
        item.species = form.species;
        item.place = form.place;
        item.updatedAt = ts;
        if (store !== null) {
          try {
            await store.executeSql(
              'UPDATE plant SET name = ?, species = ?, place = ?, updated_at = ? WHERE id = ?',
              [item.name, item.species, item.place, item.updatedAt, item.id]);
          } catch (err) {
            hilog.warn(DOMAIN, TAG, '更新植物失败: %{public}s', JSON.stringify(err));
          }
        }
      }
    }

    await PlantDao.replacePlans(id, form.plans, store);
    return id;
  }

  /** 重写某盆植物的全部养护计划 */
  private static async replacePlans(id: number, plans: PlanItem[], store: relationalStore.RdbStore | null): Promise<void> {
    const kept: CarePlan[] = [];
    for (const p of PlantDao.planList) {
      if (p.plantId !== id) {
        kept.push(p);
      }
    }
    PlantDao.planList = kept;

    if (store !== null) {
      try {
        await store.executeSql('DELETE FROM care_plan WHERE plant_id = ?', [id]);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '清理养护计划失败: %{public}s', JSON.stringify(err));
      }
    }

    let order: number = 0;
    for (const pi of plans) {
      let pid: number = 0;
      if (store !== null) {
        try {
          const bucket: relationalStore.ValuesBucket = {
            'plant_id': id,
            'type': pi.type,
            'interval_days': pi.intervalDays,
            'remind_time': pi.remindTime,
            'sort_order': order
          };
          pid = await store.insert(DbCfg.T_PLAN, bucket);
        } catch (err) {
          pid = PlantDao.memPlanId++;
        }
      } else {
        pid = PlantDao.memPlanId++;
      }
      PlantDao.planList.push({
        id: pid,
        plantId: id,
        type: pi.type,
        intervalDays: pi.intervalDays,
        remindTime: pi.remindTime,
        sortOrder: order
      });
      order++;
    }
  }

  /** 清空全部植物与养护计划（设置页"清空全部数据"用，2026-10-15 新增） */
  static async removeAll(): Promise<void> {
    PlantDao.list = [];
    PlantDao.planList = [];
    const store = DbHelper.getStore();
    if (store !== null) {
      try {
        await store.executeSql('DELETE FROM care_plan');
        await store.executeSql('DELETE FROM plant');
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '清空植物失败: %{public}s', JSON.stringify(err));
      }
    }
  }

  /** 启用 / 归档 */
  static async setStatus(id: number, status: number): Promise<void> {
    const item = PlantDao.findById(id);
    if (item === null) {
      return;
    }
    item.status = status;
    item.updatedAt = nowMs();
    const store = DbHelper.getStore();
    if (store !== null) {
      try {
        await store.executeSql('UPDATE plant SET status = ?, updated_at = ? WHERE id = ?', [status, item.updatedAt, id]);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '更新状态失败: %{public}s', JSON.stringify(err));
      }
    }
  }

  /** 删除植物（历史养护记录保留） */
  static async remove(id: number): Promise<void> {
    const kept: Plant[] = [];
    for (const p of PlantDao.list) {
      if (p.id !== id) {
        kept.push(p);
      }
    }
    PlantDao.list = kept;
    const keptPlans: CarePlan[] = [];
    for (const p of PlantDao.planList) {
      if (p.plantId !== id) {
        keptPlans.push(p);
      }
    }
    PlantDao.planList = keptPlans;

    const store = DbHelper.getStore();
    if (store !== null) {
      try {
        await store.executeSql('DELETE FROM care_plan WHERE plant_id = ?', [id]);
        await store.executeSql('DELETE FROM plant WHERE id = ?', [id]);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '删除植物失败: %{public}s', JSON.stringify(err));
      }
    }
  }
}
