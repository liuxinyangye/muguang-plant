/**
 * 植物业务逻辑
 * 对应 memory-bank/ARCHITECTURE.md 的业务层
 * 负责：表单校验、表单生成、数量统计
 */
import { Plant, PlantForm, PlanItem } from '../model/Types';
import { PlantDao } from '../model/PlantDao';
import { todayStr } from '../common/DateUtil';
import { CareType } from '../common/Constants';

export class PlantService {

  /** 空表单，用于新增（默认带一条"每 2 天浇一次水"） */
  static emptyForm(): PlantForm {
    const plans: PlanItem[] = [{ type: CareType.DEFAULT, intervalDays: 2, remindTime: '09:00' }];
    return {
      id: 0,
      name: '',
      species: '',
      place: '',
      plans: plans
    };
  }

  /** 由已有植物生成表单，用于编辑 */
  static formOf(id: number): PlantForm {
    const p = PlantDao.findById(id);
    if (p === null) {
      return PlantService.emptyForm();
    }
    const plans: PlanItem[] = [];
    for (const cp of PlantDao.plansOf(id)) {
      plans.push({ type: cp.type, intervalDays: cp.intervalDays, remindTime: cp.remindTime });
    }
    if (plans.length === 0) {
      plans.push({ type: CareType.DEFAULT, intervalDays: 2, remindTime: '09:00' });
    }
    return {
      id: p.id,
      name: p.name,
      species: p.species,
      place: p.place,
      plans: plans
    };
  }

  /**
   * 校验表单
   * 返回错误提示文字；返回空字符串表示校验通过
   */
  static validate(form: PlantForm): string {
    if (form.name.trim() === '') {
      return '请填写植物昵称';
    }
    if (form.name.length > 20) {
      return '植物昵称不要超过 20 个字';
    }
    if (form.species.length > 20) {
      return '品种不要超过 20 个字';
    }
    if (form.place.length > 20) {
      return '位置不要超过 20 个字';
    }
    if (form.plans.length === 0) {
      return '请至少添加一条养护计划';
    }
    if (form.plans.length > CareType.MAX_PLANS) {
      return `每盆植物最多 ${CareType.MAX_PLANS} 条养护计划`;
    }
    const seen: string[] = [];
    for (const p of form.plans) {
      const name: string = p.type.trim();
      if (name === '') {
        return '请填写养护类型名称';
      }
      if (name.length > CareType.MAX_NAME_LEN) {
        return `养护类型名称不要超过 ${CareType.MAX_NAME_LEN} 个字`;
      }
      if (seen.indexOf(name) >= 0) {
        return `同一盆植物不能有重复的养护类型：${name}`;
      }
      seen.push(name);
      if (p.intervalDays < 1 || p.intervalDays > 365) {
        return `${name}的周期请填 1 ~ 365 之间的天数`;
      }
      if (p.remindTime.length !== 5 || p.remindTime.indexOf(':') !== 2) {
        return `${name}的提醒时间请按 HH:mm 填写，如 09:00`;
      }
    }
    return '';
  }

  /** 养护中的植物数量 */
  static activeCount(): number {
    return PlantDao.activeOn().length;
  }

  /** 全部植物（含已归档） */
  static allCount(): number {
    return PlantDao.all().length;
  }

  /** 友好的日期短标签，如 "10-15" */
  static shortDate(date: string): string {
    if (date.length >= 10) {
      return `${date.substring(5, 7)}-${date.substring(8, 10)}`;
    }
    return date;
  }

  /** 今天 */
  static today(): string {
    return todayStr();
  }
}
