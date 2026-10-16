/**
 * 植物编辑页（P3）
 * 新增 / 编辑植物与养护计划，对应 memory-bank/DESIGN.md 流程 A
 */
import { router, promptAction } from '@kit.ArkUI';
import { PlantForm, PlanItem } from '../model/Types';
import { PlantDao } from '../model/PlantDao';
import { PlantService } from '../service/PlantService';
import { Colors, Sizes, CareType } from '../common/Constants';
import { DataVersion } from '../common/DataVersion';
import { EditTarget } from '../common/EditTarget';

@Entry
@Component
struct PlantEdit {
  @State plantId: number = 0;
  @State plantName: string = '';
  @State species: string = '';
  @State place: string = '';
  @State plans: PlanItem[] = [];
  @State errMsg: string = '';
  // 养护类型选择器（2026-10-15：预设快选 + 自定义输入）
  @State showTypePicker: boolean = false;
  @State pickerIndex: number = -1;
  @State customType: string = '';

  aboutToAppear(): void {
    this.plantId = EditTarget.id;
    const f: PlantForm = PlantService.formOf(this.plantId);
    this.plantName = f.name;
    this.species = f.species;
    this.place = f.place;
    this.plans = f.plans;
  }

  /** 打开类型选择器，index 是正在编辑第几条养护项 */
  openTypePicker(index: number): void {
    this.pickerIndex = index;
    this.customType = '';
    this.showTypePicker = true;
  }

  /** 某个预设是否是当前养护项已选中的类型（用于高亮） */
  isPresetSelected(preset: string): boolean {
    const idx: number = this.pickerIndex;
    return idx >= 0 && idx < this.plans.length && this.plans[idx].type === preset;
  }

  /** 写入某条养护项的类型名称 */
  setPlanType(index: number, name: string): void {
    if (index < 0 || index >= this.plans.length) {
      return;
    }
    const copy: PlanItem[] = this.plans.slice(0);
    copy[index] = {
      type: name,
      intervalDays: copy[index].intervalDays,
      remindTime: copy[index].remindTime
    };
    this.plans = copy;
  }

  /** 选预设类型 */
  applyPreset(name: string): void {
    this.setPlanType(this.pickerIndex, name);
    this.showTypePicker = false;
  }

  /** 选自定义类型：校验非空、长度、同一盆植物内不重复 */
  applyCustom(): void {
    const name: string = this.customType.trim();
    if (name === '') {
      promptAction.showToast({ message: '请输入养护类型名称', duration: 1500 });
      return;
    }
    if (name.length > CareType.MAX_NAME_LEN) {
      promptAction.showToast({ message: `类型名称不要超过 ${CareType.MAX_NAME_LEN} 个字`, duration: 1500 });
      return;
    }
    for (let i = 0; i < this.plans.length; i++) {
      if (i !== this.pickerIndex && this.plans[i].type === name) {
        promptAction.showToast({ message: `已有相同类型的养护项：${name}`, duration: 1500 });
        return;
      }
    }
    this.setPlanType(this.pickerIndex, name);
    this.showTypePicker = false;
  }

  updateInterval(index: number, value: string): void {
    const copy: PlanItem[] = this.plans.slice(0);
    const n = parseInt(value);
    copy[index] = {
      type: copy[index].type,
      intervalDays: isNaN(n) ? copy[index].intervalDays : n,
      remindTime: copy[index].remindTime
    };
    this.plans = copy;
  }

  updateTime(index: number, value: string): void {
    const copy: PlanItem[] = this.plans.slice(0);
    copy[index] = {
      type: copy[index].type,
      intervalDays: copy[index].intervalDays,
      remindTime: value
    };
    this.plans = copy;
  }

  addPlan(): void {
    if (this.plans.length >= CareType.MAX_PLANS) {
      return;
    }
    // 默认类型：优先选一个还没被用过的预设，都用过了就用"养护"
    const used: string[] = [];
    for (const p of this.plans) {
      used.push(p.type);
    }
    let t: string = '养护';
    for (const preset of CareType.PRESETS) {
      if (used.indexOf(preset) < 0) {
        t = preset;
        break;
      }
    }
    const copy: PlanItem[] = this.plans.slice(0);
    copy.push({ type: t, intervalDays: 30, remindTime: '09:00' });
    this.plans = copy;
  }

  removePlan(index: number): void {
    const copy: PlanItem[] = this.plans.slice(0);
    copy.splice(index, 1);
    this.plans = copy;
  }

  async onSave(): Promise<void> {
    const form: PlantForm = {
      id: this.plantId,
      name: this.plantName.trim(),
      species: this.species.trim(),
      place: this.place.trim(),
      plans: this.plans
    };
    const err: string = PlantService.validate(form);
    if (err !== '') {
      this.errMsg = err;
      return;
    }
    this.errMsg = '';
    await PlantDao.save(form);
    DataVersion.bump();
    router.back();
  }

  onDelete(): void {
    AlertDialog.show({
      title: '删除植物',
      message: '删除后历史养护记录会保留，确定要删除吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: Colors.DANGER,
        action: () => {
          PlantDao.remove(this.plantId).then(() => {
            DataVersion.bump();
            router.back();
          });
        }
      }
    });
  }

  @Builder
  labelWithStar(text: string) {
    Row() {
      Text(text).fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
      Text('*').fontSize(Sizes.FONT_SUB).fontColor(Colors.DANGER).margin({ left: 4 })
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  basicCard() {
    Column() {
      this.labelWithStar('植物昵称')
      TextInput({ text: this.plantName, placeholder: '例如：窗台的绿萝' })
        .height(Sizes.TAP_MIN)
        .fontSize(Sizes.FONT_BODY)
        .backgroundColor('#F5F6F5')
        .onChange((v: string) => {
          this.plantName = v;
        })

      Row() {
        Text('品种').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
        Text('选填').fontSize(12).fontColor(Colors.TEXT_FAINT).margin({ left: 6 })
      }
      .width('100%')
      .margin({ top: 16, bottom: 8 })

      TextInput({ text: this.species, placeholder: '例如：绿萝' })
        .height(Sizes.TAP_MIN)
        .fontSize(Sizes.FONT_BODY)
        .backgroundColor('#F5F6F5')
        .onChange((v: string) => {
          this.species = v;
        })

      Row() {
        Text('位置').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
        Text('选填').fontSize(12).fontColor(Colors.TEXT_FAINT).margin({ left: 6 })
      }
      .width('100%')
      .margin({ top: 16, bottom: 8 })

      TextInput({ text: this.place, placeholder: '例如：客厅窗台' })
        .height(Sizes.TAP_MIN)
        .fontSize(Sizes.FONT_BODY)
        .backgroundColor('#F5F6F5')
        .onChange((v: string) => {
          this.place = v;
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
  planCard() {
    Column() {
      this.labelWithStar('养护计划')

      Text('点类型名可选常用类型，也可以自己输入，如"擦叶子""转盆"')
        .fontSize(12).fontColor(Colors.TEXT_FAINT)
        .width('100%')
        .margin({ bottom: 10 })

      ForEach(this.plans, (p: PlanItem, index: number) => {
        Row() {
          Text(`${p.type} ▾`)
            .fontSize(Sizes.FONT_SUB)
            .fontColor(Colors.PRIMARY)
            .backgroundColor(Colors.PRIMARY_LIGHT)
            .borderRadius(8)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .onClick(() => {
              this.openTypePicker(index);
            })

          Text('每').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)
            .margin({ left: 10 })
          TextInput({ text: `${p.intervalDays}` })
            .width(56)
            .height(40)
            .fontSize(Sizes.FONT_SUB)
            .backgroundColor('#F5F6F5')
            .type(InputType.Number)
            .onChange((v: string) => {
              this.updateInterval(index, v);
            })
          Text('天').fontSize(Sizes.FONT_SUB).fontColor(Colors.TEXT_SUB)

          TextInput({ text: p.remindTime, placeholder: '09:00' })
            .width(84)
            .height(40)
            .fontSize(Sizes.FONT_SUB)
            .backgroundColor('#F5F6F5')
            .margin({ left: 10 })
            .onChange((v: string) => {
              this.updateTime(index, v);
            })

          Blank()
            .layoutWeight(1)

          Text('删除')
            .fontSize(Sizes.FONT_SUB)
            .fontColor(Colors.DANGER)
            .onClick(() => {
              this.removePlan(index);
            })
        }
        .width('100%')
        .margin({ bottom: 10 })
        // key 带上会变化的字段：改类型 / 周期 / 时刻后强制重建该行（2026-10-15 BUG-08）
      }, (p: PlanItem, index: number) => `${index}-${p.type}-${p.intervalDays}-${p.remindTime}`)

      if (this.plans.length < CareType.MAX_PLANS) {
        Button('＋ 添加养护项')
          .fontSize(Sizes.FONT_SUB)
          .height(40)
          .backgroundColor(Color.Transparent)
          .fontColor(Colors.PRIMARY)
          .borderRadius(8)
          .border({ width: 1, color: Colors.PRIMARY })
          .onClick(() => {
            this.addPlan();
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

  /** 养护类型选择器：预设快选 + 自定义输入（底部弹出） */
  @Builder
  typePicker() {
    Column() {
      Text('选择养护类型')
        .fontSize(Sizes.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.TEXT_MAIN)
        .width('100%')

      Row() {
        ForEach(CareType.PRESETS, (preset: string) => {
          Text(preset)
            .fontSize(Sizes.FONT_SUB)
            .fontColor(this.isPresetSelected(preset) ? Color.White : Colors.PRIMARY)
            .backgroundColor(this.isPresetSelected(preset) ? Colors.PRIMARY : Colors.PRIMARY_LIGHT)
            .borderRadius(8)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .margin({ right: 8, top: 12 })
            .onClick(() => {
              this.applyPreset(preset);
            })
        }, (preset: string) => preset)
      }
      .width('100%')

      Text('自定义类型')
        .fontSize(12)
        .fontColor(Colors.TEXT_FAINT)
        .width('100%')
        .margin({ top: 18, bottom: 8 })

      Row() {
        TextInput({ text: this.customType, placeholder: '输入名称，如：擦叶子' })
          .height(44)
          .fontSize(Sizes.FONT_SUB)
          .backgroundColor('#F5F6F5')
          .layoutWeight(1)
          .onChange((v: string) => {
            this.customType = v;
          })
        Button('确定')
          .fontSize(Sizes.FONT_SUB)
          .height(44)
          .backgroundColor(Colors.PRIMARY)
          .margin({ left: 10 })
          .onClick(() => {
            this.applyCustom();
          })
      }
      .width('100%')

      Button('取消')
        .fontSize(Sizes.FONT_SUB)
        .height(44)
        .width('100%')
        .backgroundColor(Color.Transparent)
        .fontColor(Colors.TEXT_SUB)
        .margin({ top: 8 })
        .onClick(() => {
          this.showTypePicker = false;
        })
    }
    .width('100%')
    .backgroundColor(Colors.CARD_BG)
    .borderRadius({ topLeft: 20, topRight: 20 })
    .padding(20)
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
      Text(this.plantId > 0 ? '编辑植物' : '添加植物')
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
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          this.topBar()
          this.basicCard()
          this.planCard()

          if (this.errMsg !== '') {
            Text(this.errMsg)
              .fontSize(Sizes.FONT_SUB)
              .fontColor(Colors.DANGER)
              .width('100%')
              .padding({ left: Sizes.PAGE_PADDING, right: Sizes.PAGE_PADDING, bottom: 12 })
          }

          Button('保存')
            .width('90%')
            .height(52)
            .fontSize(Sizes.FONT_BODY)
            .backgroundColor(Colors.PRIMARY)
            .onClick(() => {
              this.onSave();
            })

          if (this.plantId > 0) {
            Button('删除这盆植物')
              .width('90%')
              .height(52)
              .fontSize(Sizes.FONT_BODY)
              .backgroundColor(Color.Transparent)
              .fontColor(Colors.DANGER)
              .border({ width: 1, color: Colors.DANGER })
              .margin({ top: 12 })
              .onClick(() => {
                this.onDelete();
              })
          }
        }
        .width('100%')
        .padding({ bottom: 32 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(Colors.PAGE_BG)

      // 养护类型选择器：遮罩 + 底部面板
      if (this.showTypePicker) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(31, 42, 38, 0.4)')
          .onClick(() => {
            this.showTypePicker = false;
          })

        this.typePicker()
      }
    }
    .width('100%')
    .height('100%')
  }
}
