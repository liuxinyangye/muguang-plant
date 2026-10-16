/**
 * 记录页（P4）
 * 对应 memory-bank/DESIGN.md 的 P4 页面职责与 DATA_MODEL.md 的统计口径
 */
import { Adherence, DateGroup, TodayItem } from '../model/Types';
import { CareService } from '../service/CareService';
import { Colors, Sizes, RecordStatus } from '../common/Constants';
import { DataVersion } from '../common/DataVersion';

@Component
export struct RecordView {
  @StorageLink('dataVersion') @Watch('onVersionChange') version: number = 0;
  @State days: number = 7;
  @State stat: Adherence = { total: 0, done: 0, missed: 0, rate: 0 };
  @State groups: DateGroup[] = [];
  @State dayOptions: number[] = [7, 30];

  aboutToAppear(): void {
    this.reload();
  }

  onVersionChange(): void {
    this.reload();
  }

  reload(): void {
    this.stat = CareService.adherence(this.days);
    this.groups = CareService.groupsOf(this.days);
  }

  @Builder
  headerBar() {
    Column() {
      Text('记录').fontSize(Sizes.FONT_TITLE).fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_MAIN)
      Text('看看最近的养护情况').fontSize(Sizes.FONT_SUB)
        .fontColor(Colors.TEXT_SUB).margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, top: 16, bottom: 12 })
  }

  @Builder
  segmented() {
    Row() {
      ForEach(this.dayOptions, (d: number) => {
        Text(d === 7 ? '近 7 天' : '近 30 天')
          .fontSize(Sizes.FONT_SUB)
          .fontColor(this.days === d ? Color.White : Colors.TEXT_SUB)
          .backgroundColor(this.days === d ? Colors.PRIMARY : Color.Transparent)
          .borderRadius(10)
          .textAlign(TextAlign.Center)
          .height(36)
          .layoutWeight(1)
          .onClick(() => {
            this.days = d;
            this.reload();
          })
      }, (d: number) => `${d}`)
    }
    .width('100%')
    .padding(4)
    .backgroundColor('#EDEFEE')
    .borderRadius(12)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
  }

  @Builder
  statCard() {
    Column() {
      Text(`${this.stat.rate}%`)
        .fontSize(40).fontWeight(FontWeight.Medium).fontColor(Colors.PRIMARY)
      Text('完成率').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
        .margin({ top: 4 })

      Row() {
        // 三个统计小块直接内联：@Builder 传参在父组件重渲染时不会更新，
        // 会出现"完成率变了、应做/已完成还是旧值"的问题（2026-10-15 BUG-08）
        Column() {
          Text(`${this.stat.total}`).fontSize(Sizes.FONT_BODY).fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_MAIN)
          Text('应做').fontSize(12).fontColor(Colors.TEXT_FAINT).margin({ top: 4 })
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.stat.done}`).fontSize(Sizes.FONT_BODY).fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_MAIN)
          Text('已完成').fontSize(12).fontColor(Colors.TEXT_FAINT).margin({ top: 4 })
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.stat.missed}`).fontSize(Sizes.FONT_BODY).fontWeight(FontWeight.Medium)
            .fontColor(Colors.TEXT_MAIN)
          Text('漏做').fontSize(12).fontColor(Colors.TEXT_FAINT).margin({ top: 4 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .padding(Sizes.CARD_PADDING)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
  }

  @Builder
  dayBlock(group: DateGroup) {
    Column() {
      Row() {
        Text(group.date).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
          .layoutWeight(1)
        Text(group.totalCount === 0 ? '无任务' : `${group.doneCount} / ${group.totalCount}`)
          .fontSize(Sizes.FONT_SUB)
          .fontColor(group.totalCount > 0 && group.doneCount === group.totalCount
            ? Colors.DONE : Colors.TEXT_FAINT)
      }
      .width('100%')
      .padding({ bottom: 10 })

      if (group.items.length === 0) {
        Text('这一天没有养护任务').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_FAINT)
          .padding({ bottom: 6 })
      } else {
        ForEach(group.items, (item: TodayItem) => {
          Row() {
            Text(item.planTime).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_FAINT)
              .width(56)
            Text(`${item.plantName} ${item.typeName}`).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_MAIN)
              .layoutWeight(1)
            Text(item.status === RecordStatus.DONE ? '已做'
              : (item.status === RecordStatus.SKIPPED ? '跳过' : '未做'))
              .fontSize(12)
              .fontColor(item.status === RecordStatus.DONE ? Colors.DONE : Colors.OVERDUE)
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          // key 带上 status：打卡后强制重建该行（2026-10-15 BUG-08）
        }, (item: TodayItem) => `${item.plantId}-${item.type}-${item.status}`)
      }
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .padding(Sizes.CARD_PADDING)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 10 })
  }

  build() {
    Scroll() {
      Column() {
        this.headerBar()
        this.segmented()
        this.statCard()
        ForEach(this.groups, (group: DateGroup) => {
          this.dayBlock(group)
          // key 带上完成数：打卡后该日分组的统计变化能反映到界面（2026-10-15 BUG-08）
        }, (group: DateGroup) => `${group.date}-${group.doneCount}-${group.totalCount}`)

        if (this.groups.length === 0) {
          Column() {
            Text('这段时间还没有养护记录').fontSize(Sizes.FONT_BODY).fontColor(Colors.TEXT_SUB)
            Text('添加一盆植物，从这里开始看它的成长').fontSize(Sizes.FONT_SUB)
              .fontColor(Colors.TEXT_FAINT).margin({ top: 6 })
          }
          .width('100%')
          .padding({ top: 48 })
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
