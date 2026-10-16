/**
 * 常量与主题配置
 * 对应 memory-bank/DESIGN.md 第 4 节「视觉方向」
 */

/** 配色（青绿主色天然贴合植物主题） */
export class Colors {
  static readonly PRIMARY: string = '#3A7D6E';      // 主色：柔和青绿
  static readonly PRIMARY_LIGHT: string = '#E8F1EE'; // 主色浅底
  static readonly DONE: string = '#7BAE7F';          // 已完成
  static readonly OVERDUE: string = '#E0A458';       // 已过时间
  static readonly DANGER: string = '#C25B5B';        // 危险操作
  static readonly PAGE_BG: string = '#F7F8F7';       // 页面背景
  static readonly CARD_BG: string = '#FFFFFF';       // 卡片背景
  static readonly TEXT_MAIN: string = '#1F2A26';     // 主文字
  static readonly TEXT_SUB: string = '#6B7A74';      // 次要文字
  static readonly TEXT_FAINT: string = '#A8B5B0';    // 极浅文字
  static readonly LINE: string = '#E3E7E5';          // 分割线
}

/** 尺寸（整体偏大，单手操作友好） */
export class Sizes {
  static readonly RADIUS: number = 16;
  static readonly PAGE_PADDING: number = 20;
  static readonly CARD_PADDING: number = 18;
  static readonly TAP_MIN: number = 48;
  static readonly FONT_TITLE: number = 24;
  static readonly FONT_BODY: number = 18;
  static readonly FONT_SUB: number = 15;
}

/** 数据库配置 */
export class DbCfg {
  static readonly NAME: string = 'muguang.db';
  static readonly T_PLANT: string = 'plant';
  static readonly T_PLAN: string = 'care_plan';
  static readonly T_RECORD: string = 'care_record';
}

/** Preferences 键名 */
export class PrefKeys {
  static readonly STORE_NAME: string = 'muguang_pref';
  static readonly REMIND_ENABLED: string = 'remind_enabled';
  static readonly FONT_SCALE: string = 'font_scale';
  static readonly FIRST_LAUNCH: string = 'first_launch';
}

/** 养护记录状态 */
export class RecordStatus {
  static readonly WAIT: number = 0;    // 待做（未打卡）
  static readonly DONE: number = 1;    // 已完成
  static readonly SKIPPED: number = 2; // 主动跳过
}

/** 植物状态 */
export class PlantStatus {
  static readonly ACTIVE: number = 1;   // 养护中
  static readonly ARCHIVED: number = 0; // 已归档
}

/**
 * 养护类型（2026-10-15 改造：由 4 个固定整数枚举改为「预设 + 自定义文本」）
 * type 字段直接存类型名称（如 "浇水" / "擦叶子"），列表展示与数据库读写都不再需要映射
 */
export class CareType {
  static readonly PRESETS: string[] = ['浇水', '施肥', '修剪', '换盆']; // 常用预设，一键选择
  static readonly DEFAULT: string = '浇水';   // 新增养护项时的默认类型
  static readonly MAX_PLANS: number = 6;      // 每盆植物最多几条养护计划
  static readonly MAX_NAME_LEN: number = 8;   // 自定义类型名最长几个字
}
