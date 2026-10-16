/**
 * 花园页（P2）
 * 对应 memory-bank/DESIGN.md 的 P2 页面职责
 */
import { router } from '@kit.ArkUI';
import { Plant } from '../model/Types';
import { PlantDao } from '../model/PlantDao';
import { Colors, Sizes, PlantStatus } from '../common/Constants';
import { DataVersion } from '../common/DataVersion';
import { EditTarget } from '../common/EditTarget';

@Component
export struct GardenView {
  @StorageLink('dataVersion') @Watch('onVersionChange') version: number = 0;
  @State list: Plant[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  onVersionChange(): void {
    this.reload();
  }

  reload(): void {
    // 必须拷贝成新数组：PlantDao.all() 返回的是内部数组引用，
    // 直接赋值给 @State 时引用没变，界面感知不到数据更新（2026-10-15 BUG-08）
    const src: Plant[] = PlantDao.all();
    const copy: Plant[] = [];
    for (const p of src) {
      copy.push({
        id: p.id, name: p.name, species: p.species, place: p.place,
        status: p.status, createdAt: p.createdAt, updatedAt: p.updatedAt
      });
    }
    this.list = copy;
  }

  @Builder
  headerBar() {
    Row() {
      Column() {
        Text('花园').fontSize(Sizes.FONT_TITLE).fontWeight(FontWeight.Medium)
          .fontColor(Colors.TEXT_MAIN)
        Text(`共 ${this.list.length} 盆植物`).fontSize(Sizes.FONT_SUB)
          .fontColor(Colors.TEXT_SUB).margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('＋ 添加')
        .fontSize(Sizes.FONT_SUB)
        .height(40)
        .backgroundColor(Colors.PRIMARY)
        .onClick(() => {
          EditTarget.id = 0;
          router.pushUrl({ url: 'pages/PlantEdit' });
        })
    }
    .width('100%')
    .padding({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, top: 16, bottom: 12 })
  }

  @Builder
  emptyState() {
    Column() {
      Text('花园还是空的').fontSize(Sizes.FONT_BODY).fontColor(Colors.TEXT_SUB)
      Text('把家里的植物录进来，到点我会提醒你').fontSize(Sizes.FONT_SUB)
        .fontColor(Colors.TEXT_FAINT).margin({ top: 8 })
      Button('添加植物')
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

  @Builder
  plantCard(item: Plant) {
    Column() {
      Row() {
        Text(item.name)
          .fontSize(Sizes.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.status === PlantStatus.ACTIVE ? Colors.TEXT_MAIN : Colors.TEXT_FAINT)
          .layoutWeight(1)

        Text(item.status === PlantStatus.ACTIVE ? '养护中' : '已归档')
          .fontSize(12)
          .fontColor(item.status === PlantStatus.ACTIVE ? Colors.PRIMARY : Colors.TEXT_FAINT)
          .backgroundColor(item.status === PlantStatus.ACTIVE ? Colors.PRIMARY_LIGHT : '#F0F1F0')
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      }
      .width('100%')

      Text(`品种：${item.species === '' ? '未填写' : item.species} · ${item.place === '' ? '位置未填写' : item.place}`)
        .fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
        .margin({ top: 8 })

      Text(`养护：${PlantDao.careTextOf(item.id)}`)
        .fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_FAINT)
        .margin({ top: 4 })

      Row() {
        Button('编辑')
          .fontSize(Sizes.FONT_SUB)
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontColor(Colors.PRIMARY)
          .borderRadius(8)
          .border({ width: 1, color: Colors.PRIMARY })
          .onClick(() => {
            EditTarget.id = item.id;
            router.pushUrl({ url: 'pages/PlantEdit' });
          })

        Button(item.status === PlantStatus.ACTIVE ? '归档' : '恢复')
          .fontSize(Sizes.FONT_SUB)
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontColor(Colors.TEXT_SUB)
          .borderRadius(8)
          .border({ width: 1, color: Colors.LINE })
          .margin({ left: 10 })
          .onClick(async () => {
            const next: number = item.status === PlantStatus.ACTIVE
              ? PlantStatus.ARCHIVED : PlantStatus.ACTIVE;
            await PlantDao.setStatus(item.id, next);
            DataVersion.bump();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 14 })
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
        if (this.list.length === 0) {
          this.emptyState()
        } else {
          ForEach(this.list, (item: Plant) => {
            this.plantCard(item)
            // key 带上 status / updatedAt：归档、编辑后强制重建卡片（2026-10-15 BUG-08）
          }, (item: Plant) => `${item.id}-${item.status}-${item.updatedAt}`)
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
