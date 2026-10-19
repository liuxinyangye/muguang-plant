/**
 * 系统通知服务（Notification Kit）
 * 对应 memory-bank/TECH_STACK.md 中 Notification Kit 的使用方式
 *
 * 实现策略（轻量，不需要后台运行权限）：
 *   进入今日页 / 打卡状态变化时，检查今日待办中"已过提醒时刻且未完成"的项：
 *   - 有 → 发一条汇总通知（固定 slot id，重复进入只覆盖更新，不会堆叠）
 *   - 全部完成，或提醒开关关闭 → 撤掉提醒通知
 *   后台定时提醒需要 BackgroundTasks 倒计时代理，已列为已知改进点（见 PROGRESS.md）。
 */
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TodayItem } from '../model/Types';
import { PrefKeys, RecordStatus } from '../common/Constants';

const DOMAIN = 0x0000;
const TAG = 'Muguang.Notifier';

/** 提醒通知的固定 slot：同一 id 再次发布会覆盖旧通知，避免堆叠 */
const REMIND_SLOT: number = 1001;

export class Notifier {

  /** 读取提醒总开关（Preferences 读不到时默认开启） */
  static async enabled(ctx: common.Context): Promise<boolean> {
    try {
      const pref = await preferences.getPreferences(ctx, { name: PrefKeys.STORE_NAME });
      const v = await pref.get(PrefKeys.REMIND_ENABLED, true);
      return v as boolean;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '读取提醒开关失败: %{public}s', JSON.stringify(err));
      return true;
    }
  }

  /** 确保通知已授权：未授权时弹一次系统对话框（仅首次弹，拒绝后不再弹） */
  static async ensureAuthorized(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const on: boolean = await notificationManager.isNotificationEnabled();
      if (on) {
        return true;
      }
      await notificationManager.requestEnableNotification(ctx);
      return await notificationManager.isNotificationEnabled();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '通知授权失败: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /** 发布一条文本通知；返回是否成功（预览器等环境会失败，由调用方兜底提示） */
  static async publish(ctx: common.Context, title: string, text: string): Promise<boolean> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: REMIND_SLOT,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text
          }
        }
      };
      await notificationManager.publish(request);
      return true;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '发布通知失败: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /**
   * 检查今日待办并同步通知状态
   * 开关关闭 → 撤掉旧通知；有到点未做的项 → 发汇总提醒；全部完成 → 撤掉
   */
  static async checkToday(ctx: common.Context, items: TodayItem[]): Promise<void> {
    if (!(await Notifier.enabled(ctx))) {
      await Notifier.cancelRemind();
      return;
    }
    const pending: TodayItem[] = [];
    for (const it of items) {
      if (it.status === RecordStatus.WAIT && it.passed) {
        pending.push(it);
      }
    }
    if (pending.length === 0) {
      await Notifier.cancelRemind();
      return;
    }
    let text: string = '';
    if (pending.length === 1) {
      text = `${pending[0].plantName} ${pending[0].typeName}还没做（${pending[0].planTime} 该做啦）`;
    } else {
      text = `今天还有 ${pending.length} 项养护没完成，去看看？`;
    }
    await Notifier.publish(ctx, '沐光提醒你', text);
  }

  /** 撤掉提醒通知（没有发过时取消会失败，静默忽略） */
  static async cancelRemind(): Promise<void> {
    try {
      await notificationManager.cancel(REMIND_SLOT);
    } catch (err) {
      // 没有通知可撤，忽略
    }
  }

  /** 设置页「发送测试通知」用：先确保授权，再直接发一条（不受总开关限制）
   *  返回 'sent' 已发送 / 'no_auth' 未授权 / 'failed' 发送失败，供调用方给出明确反馈 */
  static async sendTest(ctx: common.UIAbilityContext): Promise<string> {
    const authorized: boolean = await Notifier.ensureAuthorized(ctx);
    if (!authorized) {
      return 'no_auth';
    }
    const published: boolean = await Notifier.publish(ctx, '沐光 · 测试通知', '通知功能正常，到点我会提醒你照顾植物');
    return published ? 'sent' : 'failed';
  }
}
