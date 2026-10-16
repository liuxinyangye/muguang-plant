/**
 * 数据版本号
 * 用于在编辑页面返回后，通知首页 / 花园页重新读取数据
 */
export class DataVersion {
  static readonly KEY: string = 'dataVersion';

  /** 数据发生变化时调用，通知所有监听者刷新 */
  static bump(): void {
    const v: number | undefined = AppStorage.get<number>(DataVersion.KEY);
    const current: number = v === undefined ? 0 : v;
    AppStorage.setOrCreate(DataVersion.KEY, current + 1);
  }

  /** 取得当前版本号 */
  static current(): number {
    const v: number | undefined = AppStorage.get<number>(DataVersion.KEY);
    return v === undefined ? 0 : v;
  }
}
