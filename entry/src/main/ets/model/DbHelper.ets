/**
 * 数据库初始化
 * 对应 memory-bank/DATA_MODEL.md 与 ARCHITECTURE.md 的数据访问层
 *
 * 设计说明：
 * 应用启动时尝试打开关系型数据库。若当前运行环境不支持（例如某些场景下
 * 无法获取应用上下文），会降级为「内存模式」，保证界面依然可以正常使用与演示，
 * 不会因为持久化不可用而白屏。
 */
import { relationalStore, preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbCfg } from '../common/Constants';

const DOMAIN = 0x0000;
const TAG = 'Muguang.DbHelper';

/** 建表语句，字段顺序遵循「主键 → 业务字段 → 时间字段」 */
const DDL_PLANT: string =
  'CREATE TABLE IF NOT EXISTS plant (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'name TEXT NOT NULL, ' +
  'species TEXT NOT NULL, ' +
  'place TEXT NOT NULL, ' +
  'status INTEGER NOT NULL DEFAULT 1, ' +
  'created_at INTEGER NOT NULL, ' +
  'updated_at INTEGER NOT NULL)';

const DDL_PLAN: string =
  'CREATE TABLE IF NOT EXISTS care_plan (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'plant_id INTEGER NOT NULL, ' +
  'type TEXT NOT NULL, ' +          // 2026-10-15：整数枚举 → 类型名称文本（支持自定义）
  'interval_days INTEGER NOT NULL, ' +
  'remind_time TEXT NOT NULL, ' +
  'sort_order INTEGER NOT NULL DEFAULT 0)';

const DDL_RECORD: string =
  'CREATE TABLE IF NOT EXISTS care_record (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'plant_id INTEGER NOT NULL, ' +
  'type TEXT NOT NULL, ' +          // 2026-10-15：整数枚举 → 类型名称文本
  'plan_date TEXT NOT NULL, ' +
  'status INTEGER NOT NULL, ' +
  'done_at INTEGER, ' +
  'UNIQUE (plant_id, type, plan_date))';

const DDL_INDEX_1: string = 'CREATE INDEX IF NOT EXISTS idx_care_plan_pid ON care_plan (plant_id)';
const DDL_INDEX_2: string = 'CREATE INDEX IF NOT EXISTS idx_care_record_date ON care_record (plan_date)';

export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;
  private static inited: boolean = false;
  private static memoryMode: boolean = false;

  /** 初始化：应用启动时调用一次 */
  static async init(context: common.Context): Promise<void> {
    if (DbHelper.inited) {
      return;
    }
    DbHelper.inited = true;
    try {
      const config: relationalStore.StoreConfig = {
        name: DbCfg.NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };
      const store = await relationalStore.getRdbStore(context, config);
      await DbHelper.migrateIfNeeded(context, store);
      await store.executeSql(DDL_PLANT);
      await store.executeSql(DDL_PLAN);
      await store.executeSql(DDL_RECORD);
      await store.executeSql(DDL_INDEX_1);
      await store.executeSql(DDL_INDEX_2);
      DbHelper.store = store;
      hilog.info(DOMAIN, TAG, '%{public}s', '数据库初始化成功');
    } catch (err) {
      DbHelper.memoryMode = true;
      hilog.warn(DOMAIN, TAG, '数据库不可用，已降级为内存模式: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * Schema 版本迁移（2026-10-15：v1 → v2）
   * v1 的 care_plan / care_record.type 是整数枚举（1~4），v2 改为类型名称文本以支持自定义。
   * 整数列无法直接改成文本列，开发期采用「检测到旧版本即重建表」策略（历史数据为测试数据，
   * 且应用内已提供「清空全部数据」入口，数据丢失影响可接受）。
   */
  private static async migrateIfNeeded(context: common.Context, store: relationalStore.RdbStore): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, { name: 'muguang_schema' });
      const v = await pref.get('version', 1) as number;
      if (v >= 2) {
        return;
      }
      await store.executeSql('DROP TABLE IF EXISTS care_record');
      await store.executeSql('DROP TABLE IF EXISTS care_plan');
      await store.executeSql('DROP TABLE IF EXISTS plant');
      await pref.put('version', 2);
      await pref.flush();
      hilog.info(DOMAIN, TAG, '%{public}s', 'Schema 升级 v1 → v2：养护类型改为自定义文本');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Schema 迁移失败（继续尝试建表）: %{public}s', JSON.stringify(err));
    }
  }

  /** 获取数据库实例，可能为 null（内存模式） */
  static getStore(): relationalStore.RdbStore | null {
    return DbHelper.store;
  }

  /** 是否处于内存降级模式 */
  static isMemoryMode(): boolean {
    return DbHelper.memoryMode;
  }
}
