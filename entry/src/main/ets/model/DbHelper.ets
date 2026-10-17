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
  'interval_days INTEGER NOT NULL DEFAULT 0, ' + // 2026-10-17：记账键加「周期」维度
  'plan_date TEXT NOT NULL, ' +
  'status INTEGER NOT NULL, ' +
  'done_at INTEGER, ' +
  'UNIQUE (plant_id, type, interval_days, plan_date))';

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
   * Schema 版本迁移
   * v1 → v2（2026-10-15）：care_plan / care_record.type 由整数枚举（1~4）改为类型名称文本。
   *   整数列无法直接改成文本列，开发期采用「检测到旧版本即重建表」策略（历史数据为测试数据，
   *   且应用内已提供「清空全部数据」入口，数据丢失影响可接受）。
   * v2 → v3（2026-10-17）：care_record 记账键加「周期」维度
   *   （(植物+类型+日期) → (植物+类型+周期+日期)），唯一约束随之改为四列。
   *   旧记录按 (植物+类型) 回填周期：唯一匹配的计划则继承其 interval_days，
   *   同类型多条时挂到 sort_order 最小的计划（旧数据本就共享一条记录，无法拆分），
   *   匹配不到计划的孤儿记录周期记为 0。SQLite 不能改约束，采用建新表→拷贝→换名重建。
   */
  private static async migrateIfNeeded(context: common.Context, store: relationalStore.RdbStore): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, { name: 'muguang_schema' });
      const v = await pref.get('version', 1) as number;
      if (v >= 3) {
        return;
      }
      if (v < 2) {
        await store.executeSql('DROP TABLE IF EXISTS care_record');
        await store.executeSql('DROP TABLE IF EXISTS care_plan');
        await store.executeSql('DROP TABLE IF EXISTS plant');
        await pref.put('version', 2);
        await pref.flush();
        hilog.info(DOMAIN, TAG, '%{public}s', 'Schema 升级 v1 → v2：养护类型改为自定义文本');
      }
      if (v < 3) {
        await DbHelper.migrateRecordV3(store);
        await pref.put('version', 3);
        await pref.flush();
        hilog.info(DOMAIN, TAG, '%{public}s', 'Schema 升级 v2 → v3：记录记账键加周期维度');
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Schema 迁移失败（继续尝试建表）: %{public}s', JSON.stringify(err));
    }
  }

  /** v2 → v3：给 care_record 加 interval_days 列、按计划回填、重建唯一约束 */
  private static async migrateRecordV3(store: relationalStore.RdbStore): Promise<void> {
    // 列已存在（上次迁移中途失败）则跳过加列
    let hasInterval: boolean = false;
    const cols: relationalStore.ResultSet = await store.querySql('PRAGMA table_info(care_record)');
    while (cols.goToNextRow()) {
      if (cols.getString(cols.getColumnIndex('name')) === 'interval_days') {
        hasInterval = true;
      }
    }
    cols.close();
    if (!hasInterval) {
      await store.executeSql('ALTER TABLE care_record ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 0');
    }
    // 按 (植物+类型) 找计划回填周期；匹配不到留 0（COALESCE 防止 NULL 写入 NOT NULL 列）
    await store.executeSql(
      'UPDATE care_record SET interval_days = COALESCE((' +
      'SELECT interval_days FROM care_plan ' +
      'WHERE care_plan.plant_id = care_record.plant_id AND care_plan.type = care_record.type ' +
      'ORDER BY sort_order ASC LIMIT 1), 0)');
    // 同键多条只留 id 最大的一条（旧数据理论上唯一，防御性去重）
    await store.executeSql(
      'DELETE FROM care_record WHERE id NOT IN (' +
      'SELECT MAX(id) FROM care_record GROUP BY plant_id, type, interval_days, plan_date)');
    // 重建表以更换唯一约束（SQLite 不支持直接改约束）
    await store.executeSql('DROP TABLE IF EXISTS care_record_v3');
    await store.executeSql(
      'CREATE TABLE care_record_v3 (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'plant_id INTEGER NOT NULL, ' +
      'type TEXT NOT NULL, ' +
      'interval_days INTEGER NOT NULL DEFAULT 0, ' +
      'plan_date TEXT NOT NULL, ' +
      'status INTEGER NOT NULL, ' +
      'done_at INTEGER, ' +
      'UNIQUE (plant_id, type, interval_days, plan_date))');
    await store.executeSql(
      'INSERT INTO care_record_v3 (id, plant_id, type, interval_days, plan_date, status, done_at) ' +
      'SELECT id, plant_id, type, interval_days, plan_date, status, done_at FROM care_record');
    await store.executeSql('DROP TABLE care_record');
    await store.executeSql('ALTER TABLE care_record_v3 RENAME TO care_record');
    // 换名后原索引丢失，重建（init 中的 IF NOT EXISTS 变 no-op）
    await store.executeSql('CREATE INDEX IF NOT EXISTS idx_care_record_date ON care_record (plan_date)');
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
