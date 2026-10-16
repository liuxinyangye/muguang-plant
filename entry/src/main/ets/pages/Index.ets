/**
 * 首页（导航容器）
 * 底部三个 Tab：今日 / 花园 / 记录
 * 对应 memory-bank/DESIGN.md 第 1 节「页面结构与导航」
 */
import { TodayView } from '../views/TodayView';
import { GardenView } from '../views/GardenView';
import { RecordView } from '../views/RecordView';
import { Colors, Sizes } from '../common/Constants';
import { DataVersion } from '../common/DataVersion';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  onPageShow(): void {
    // 从编辑页 / 设置页返回时，通知各页重新读取数据
    DataVersion.bump();
  }

  @Builder
  tabItem(title: string, index: number) {
    Column() {
      Column()
        .width(24)
        .height(4)
        .borderRadius(2)
        .backgroundColor(this.currentIndex === index ? Colors.PRIMARY : Color.Transparent)
      Text(title)
        .fontSize(Sizes.FONT_SUB)
        .fontColor(this.currentIndex === index ? Colors.PRIMARY : Colors.TEXT_FAINT)
        .margin({ top: 6 })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        TodayView()
      }
      .tabBar(this.tabItem('今日', 0))

      TabContent() {
        GardenView()
      }
      .tabBar(this.tabItem('花园', 1))

      TabContent() {
        RecordView()
      }
      .tabBar(this.tabItem('记录', 2))
    }
    .barHeight(56)
    .barBackgroundColor(Colors.CARD_BG)
    .scrollable(true)
    .animationDuration(200)
    .onChange((index: number) => {
      this.currentIndex = index;
      // 切 Tab 时刷新一次数据，保证切过去看到的就是最新状态（2026-10-15 BUG-08）
      DataVersion.bump();
    })
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.PAGE_BG)
  }
}
