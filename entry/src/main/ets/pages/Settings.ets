/**
 * 我的 / 设置页（P5）
 * 提醒总开关 + 数据说明 + 关于
 */
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Colors, Sizes, PrefKeys } from '../common/Constants';
import { PlantDao } from '../model/PlantDao';
import { RecordDao } from '../model/RecordDao';
import { DataVersion } from '../common/DataVersion';
import { PlantService } from '../service/PlantService';
import { CareService } from '../service/CareService';
import { Notifier } from '../service/Notifier';

const DOMAIN = 0x0000;
const TAG = 'Muguang.Settings';

@Entry
@Component
struct Settings {
  @State remindEnabled: boolean = true;
  @State lastCare: string = '暂无记录';
  @State plantCount: number = 0;
  @State activeCount: number = 0;

  aboutToAppear(): void {
    this.loadPref();
    this.lastCare = CareService.lastCareText();
    this.plantCount = PlantService.allCount();
    this.activeCount = PlantService.activeCount();
  }

  /** 读取提醒开关（失败则保持默认值） */
  async loadPref(): Promise<void> {
    try {
      const ctx = getContext(this) as common.Context;
      const pref = await preferences.getPreferences(ctx, { name: PrefKeys.STORE_NAME });
      const v = await pref.get(PrefKeys.REMIND_ENABLED, true);
      this.remindEnabled = v as boolean;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '读取设置失败: %{public}s', JSON.stringify(err));
    }
  }

  /** 保存提醒开关 */
  async savePref(value: boolean): Promise<void> {
    try {
      const ctx = getContext(this) as common.Context;
      const pref = await preferences.getPreferences(ctx, { name: PrefKeys.STORE_NAME });
      await pref.put(PrefKeys.REMIND_ENABLED, value);
      await pref.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '保存设置失败: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 清空全部数据：二次确认后删除所有植物、养护计划与养护记录
   * 与 design/settings.html 原型、DESIGN.md 第 3 节「删除确认」对齐
   */
  async confirmClear(): Promise<void> {
    const result = await promptAction.showDialog({
      title: '清空全部数据？',
      message: '将删除所有植物、养护计划与养护记录，且无法恢复。确定要清空吗？',
      buttons: [
        { text: '取消', color: Colors.TEXT_SUB },
        { text: '确定清空', color: Colors.DANGER }
      ]
    });
    if (result.index === 1) {
      await PlantDao.removeAll();
      await RecordDao.removeAll();
      this.plantCount = 0;
      this.activeCount = 0;
      this.lastCare = '暂无记录';
      DataVersion.bump();
      promptAction.showToast({ message: '已清空全部数据', duration: 2000 });
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB).layoutWeight(1)
      Text(value).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_MAIN)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  remindCard() {
    Column() {
      Text('提醒').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
        .width('100%')
        .margin({ bottom: 12 })

      Row() {
        Column() {
          Text('养护提醒').fontSize(Sizes.FONT_BODY).fontColor(Colors.TEXT_MAIN)
          Text('到点未做的养护会弹出系统通知').fontSize(12).fontColor(Colors.TEXT_FAINT)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.remindEnabled })
          .selectedColor(Colors.PRIMARY)
          .onChange((isOn: boolean) => {
            this.remindEnabled = isOn;
            this.savePref(isOn);
            if (isOn) {
              // 打开提醒时顺手请求一次系统通知授权（仅首次弹框）
              const ctx = getContext(this) as common.UIAbilityContext;
              Notifier.ensureAuthorized(ctx);
            }
          })
      }
      .width('100%')

      Button('发送测试通知')
        .fontSize(Sizes.FONT_SUB)
        .fontColor(Colors.PRIMARY)
        .backgroundColor(Colors.PRIMARY_LIGHT)
        .width('100%')
        .height(40)
        .margin({ top: 14 })
        .onClick(async () => {
          const ctx = getContext(this) as common.UIAbilityContext;
          const ok: boolean = await Notifier.sendTest(ctx);
          if (!ok) {
            promptAction.showToast({
              message: '当前环境暂不支持系统通知，真机可见效果',
              duration: 2000
            });
          }
        })
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .padding(Sizes.CARD_PADDING)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
  }

  @Builder
  dataCard() {
    Column() {
      Text('数据情况').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
        .width('100%')
        .margin({ bottom: 12 })

      this.infoRow('植物数量', `${this.plantCount} 盆`)
      this.infoRow('养护中', `${this.activeCount} 盆`)
      this.infoRow('最近一次养护', this.lastCare)

      Row() {
        Column() {
          Text('清空全部数据').fontSize(Sizes.FONT_BODY).fontColor(Colors.TEXT_MAIN)
          Text('删除所有植物、养护计划与养护记录').fontSize(12)
            .fontColor(Colors.TEXT_FAINT).margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('清空')
          .fontSize(Sizes.FONT_SUB)
          .fontColor(Colors.DANGER)
          .backgroundColor(Color.Transparent)
          .height(36)
          .borderRadius(8)
          .border({ width: 1, color: Colors.DANGER })
          .onClick(() => {
            this.confirmClear();
          })
      }
      .width('100%')
      .margin({ top: 10 })

      Text('所有数据只保存在这台设备上，应用不会联网、不会上传任何信息。')
        .fontSize(12)
        .fontColor(Colors.TEXT_FAINT)
        .margin({ top: 12 })
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .padding(Sizes.CARD_PADDING)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
  }

  @Builder
  aboutCard() {
    Column() {
      Text('关于').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
        .width('100%')
        .margin({ bottom: 12 })

      this.infoRow('应用名称', '沐光')
      this.infoRow('版本', '1.0.0')
      this.infoRow('开发平台', 'HarmonyOS')

      Text('一款帮您按时浇水施肥、记录每盆植物成长的本地应用。')
        .fontSize(12)
        .fontColor(Colors.TEXT_FAINT)
        .margin({ top: 12 })
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius(Sizes.RADIUS)
    .border({ width: 1, color: Colors.LINE })
    .padding(Sizes.CARD_PADDING)
    .margin({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
  }

  @Builder
  topBar() {
    Row() {
      Text('返回')
        .fontSize(Sizes.FONT_SUB)
        .fontColor(Colors.PRIMARY)
        .onClick(() => {
          router.back();
        })
      Text('我的')
        .fontSize(Sizes.FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_MAIN)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text(' ')
        .fontSize(Sizes.FONT_SUB)
        .width(40)
    }
    .width('100%')
    .padding({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, top: 16, bottom: 16 })
  }

  build() {
    Column() {
      this.topBar()

      Scroll() {
        Column() {
          this.remindCard()
          this.dataCard()
          this.aboutCard()
        }
        .width('100%')
        .padding({ bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.PAGE_BG)
  }
}
