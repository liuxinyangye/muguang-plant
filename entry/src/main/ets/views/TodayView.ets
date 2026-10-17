/**
 * 今日页（P1）
 * 对应 memory-bank/DESIGN.md 第 2 节流程 A / 流程 B
 *
 * 2026-10-15 改版：待办由「所有植物拉平按时间排序」改为「按植物分组卡片」——
 * 一盆植物一张卡片，卡片内是该植物今天到期的各项养护，一眼看清"谁该做什么"。
 *
 * 2026-10-15 二次修复：BUG-08 的卡片级补丁——卡片 ForEach 的 key 原先只有 plantId，
 * 数据变化后 ArkUI 复用旧组件，导致"新加的养护项不显示、打卡后圆圈不变"；
 * 现 key 带上每项内容签名，任何变化强制重建。同时新增卡片折叠：
 * 养护项超过阈值默认收起，点"展开全部"看全。
 */
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { TodayItem, PlantTaskGroup } from '../model/Types';
import { CareService } from '../service/CareService';
import { Notifier } from '../service/Notifier';
import { Colors, Sizes, RecordStatus } from '../common/Constants';
import { friendlyToday, todayStr } from '../common/DateUtil';
import { DataVersion } from '../common/DataVersion';
import { EditTarget } from '../common/EditTarget';

/** 植物卡片折叠阈值：养护项超过这个数就默认收起，展开后才能看全部 */
const CARD_COLLAPSE_THRESHOLD: number = 3;

@Component
export struct TodayView {
  @StorageLink('dataVersion') @Watch('onVersionChange') version: number = 0;
  @State groups: PlantTaskGroup[] = [];
  @State doneCount: number = 0;
  @State totalCount: number = 0;
  /** 已收起的植物卡片（plantId 列表）。放在视图层而不是卡片内部，
   *  这样卡片因数据变化被重建时，展开/收起状态不会丢 */
  @State collapsedIds: number[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  onVersionChange(): void {
    this.reload();
  }

  reload(): void {
    this.groups = CareService.planGrouped(todayStr());
    this.doneCount = 0;
    this.totalCount = 0;
    for (const g of this.groups) {
      this.doneCount += g.doneCount;
      this.totalCount += g.totalCount;
    }
    this.checkRemind();
  }

  /**
   * 分组 key：带上每一项的类型/周期/时间/状态签名。
   * 只要卡片内容有任何变化（新增养护项、改了周期、打卡状态变化），key 就变，
   * 强制 ForEach 重建该卡片——否则 ArkUI 会复用旧组件、渲染旧快照，
   * 表现为"新加的项不显示、打卡后圆圈不变、卡片进度数字不动"（2026-10-15 BUG-08 卡片级补丁）
   */
  private groupKey(group: PlantTaskGroup): string {
    let sig: string = '';
    for (const it of group.items) {
      sig += `${it.type}|${it.intervalDays}|${it.planTime}|${it.status}|${it.passed};`;
    }
    return `${group.plantId}-${sig}`;
  }

  /** 养护项是否多到需要折叠 */
  private canCollapse(group: PlantTaskGroup): boolean {
    return group.items.length > CARD_COLLAPSE_THRESHOLD;
  }

  private isCollapsed(plantId: number): boolean {
    return this.collapsedIds.indexOf(plantId) >= 0;
  }

  private toggleCollapse(plantId: number): void {
    if (this.isCollapsed(plantId)) {
      this.collapsedIds = this.collapsedIds.filter((id: number) => id !== plantId);
    } else {
      this.collapsedIds = this.collapsedIds.concat([plantId]);
    }
  }

  /** 当前实际展示的养护项：折叠时只显示前 N 条 */
  private visibleItems(group: PlantTaskGroup): TodayItem[] {
    if (this.canCollapse(group) && this.isCollapsed(group.plantId)) {
      return group.items.slice(0, CARD_COLLAPSE_THRESHOLD);
    }
    return group.items;
  }

  /** 把分组数据拉平，供通知检查使用 */
  private flatItems(): TodayItem[] {
    const items: TodayItem[] = [];
    for (const g of this.groups) {
      for (const it of g.items) {
        items.push(it);
      }
    }
    return items;
  }

  /**
   * 同步系统通知：有到点未做的养护发一条汇总提醒，全部完成则撤掉
   * 预览器等环境不支持通知时静默跳过，不影响界面
   */
  async checkRemind(): Promise<void> {
    try {
      const ctx: common.Context = getContext(this) as common.Context;
      await Notifier.checkToday(ctx, this.flatItems());
    } catch (err) {
      // 环境不支持通知时忽略
    }
  }

  async onTapItem(item: TodayItem): Promise<void> {
    await CareService.toggle(item.plantId, item.type, item.intervalDays, todayStr());
    DataVersion.bump();
  }

  @Builder
  headerBar() {
    Row() {
      Column() {
        Text('今天').fontSize(Sizes.FONT_TITLE).fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_MAIN)
        Text(friendlyToday()).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('设置').fontSize(Sizes.FONT_SUB).fontColor(Colors.PRIMARY)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Settings' });
        })
    }
    .width('100%')
    .padding({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, top: 16, bottom: 12 })
  }

  @Builder
  progressCard() {
    Column() {
      Row() {
        Text(this.doneCount === this.totalCount && this.totalCount > 0 ? '今天的养护都完成啦 ✓' : '今日养护')
          .fontSize(Sizes.FONT_BODY).fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_MAIN)
          .layoutWeight(1)
        Text(`${this.doneCount} / ${this.totalCount}`)
          .fontSize(Sizes.FONT_BODY).fontColor(Colors.PRIMARY)
      }
      .width('100%')

      Progress({
        value: this.totalCount === 0 ? 0 : this.doneCount * 100 / this.totalCount,
        total: 100,
        type: ProgressType.Linear
      })
        .color(Colors.DONE)
        .backgroundColor(Colors.LINE)
        .height(8)
        .margin({ top: 14 })
        .width('100%')
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .padding(Sizes.CARD_PADDING)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
  }

  @Builder
  emptyState() {
    Column() {
      Text('还没有添加植物').fontSize(Sizes.FONT_BODY).fontColor(Colors.TEXT_SUB)
      Text('先把家里的绿植录进来，浇水施肥我帮你记着').fontSize(Sizes.FONT_SUB)
        .fontColor(Colors.TEXT_FAINT).margin({ top: 8 })
      Button('添加第一盆植物')
        .fontSize(Sizes.FONT_SUB)
        .backgroundColor(Colors.PRIMARY)
        .height(Sizes.TAP_MIN)
        .margin({ top: 24 })
        .onClick(() => {
          EditTarget.id = 0;
          router.pushUrl({ url: 'pages/PlantEdit' });
        })
    }
    .width('100%')
    .height(320)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING })
  }

  /** 一盆植物的卡片：头部是植物名 / 位置 / 该植物的小组进度，内部是各项养护任务 */
  @Builder
  plantCard(group: PlantTaskGroup) {
    Column() {
      Row() {
        Text(group.plantName)
          .fontSize(Sizes.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_MAIN)
          .layoutWeight(1)
        Text(`${group.doneCount} / ${group.totalCount}`)
          .fontSize(Sizes.FONT_SUB)
          .fontColor(group.doneCount === group.totalCount ? Colors.DONE : Colors.TEXT_FAINT)
      }
      .width('100%')

      if (group.place !== '') {
        Text(`📍 ${group.place}`)
          .fontSize(12)
          .fontColor(Colors.TEXT_FAINT)
          .margin({ top: 4 })
      }

      Column() {
        ForEach(this.visibleItems(group), (item: TodayItem, index: number) => {
          if (index > 0) {
            Divider().color(Colors.LINE).strokeWidth(1)
          }
          this.taskRow(item)
          // key 带上 status：打卡后 key 变化，强制重建该行，
          // 避免 ForEach 复用旧组件导致状态不刷新（2026-10-15 BUG-08）
        }, (item: TodayItem) => `${item.plantId}-${item.type}-${item.status}`)
      }
      .width('100%')
      .margin({ top: 8 })

      // 项太多时折叠：默认只看前几条，点"展开全部"看全（2026-10-15 新增）
      if (this.canCollapse(group)) {
        Divider().color(Colors.LINE).strokeWidth(1)
        Row() {
          Text(this.isCollapsed(group.plantId) ? `展开全部 ${group.totalCount} 项` : '收起')
            .fontSize(Sizes.FONT_SUB)
            .fontColor(Colors.PRIMARY)
            .layoutWeight(1)
          Text(this.isCollapsed(group.plantId) ? '▾' : '▴')
            .fontSize(Sizes.FONT_SUB)
            .fontColor(Colors.PRIMARY)
        }
        .width('100%')
        .padding({ top: 12, bottom: 4 })
        .onClick(() => {
          this.toggleCollapse(group.plantId);
        })
      }
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .padding(Sizes.CARD_PADDING)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
  }

  /** 植物卡片内的一条养护任务 */
  @Builder
  taskRow(item: TodayItem) {
    Row() {
      Column() {
        Row() {
          Text(item.planTime).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
          if (item.passed) {
            Text('已过时间')
              .fontSize(12).fontColor(Colors.OVERDUE)
              .backgroundColor('#FDF3E3')
              .borderRadius(8)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .margin({ left: 8 })
          }
        }
        .width('100%')

        Text(`${item.typeName} · 每 ${item.intervalDays} 天`)
          .fontSize(Sizes.FONT_SUB)
          .fontColor(item.status === RecordStatus.DONE ? Colors.TEXT_FAINT : Colors.TEXT_SUB)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧打卡圈
      Stack() {
        Circle()
          .width(44).height(44)
          .fill(item.status === RecordStatus.DONE ? Colors.DONE : Color.Transparent)
          .stroke(item.status === RecordStatus.DONE ? Colors.DONE : Colors.LINE)
          .strokeWidth(2)
        Text(item.status === RecordStatus.DONE ? '✓' : '')
          .fontSize(22).fontColor(Color.White)
      }
      .width(Sizes.TAP_MIN)
      .height(Sizes.TAP_MIN)
      .onClick(() => {
        this.onTapItem(item);
      })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  build() {
    Scroll() {
      Column() {
        this.headerBar()
        if (this.groups.length === 0) {
          this.emptyState()
        } else {
          this.progressCard()
          ForEach(this.groups, (group: PlantTaskGroup) => {
            this.plantCard(group)
            // key 带内容签名：卡片数据任何变化都重建，不用旧快照（2026-10-15 BUG-08 卡片级补丁）
          }, (group: PlantTaskGroup) => this.groupKey(group))
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(Colors.PAGE_BG)
  }
}
