/**
 * 沐光小程序 · 数据层
 * 与鸿蒙端 CareService.ets / web 版 assets/app.js 同源：
 * 同一套周期到期规则、打卡逻辑、统计口径，存储换成 wx.Storage
 */
var KEY = 'muguang_mp_v2';
var OLD_KEY = 'muguang_mp_v1';

/* ---------- 日期工具 ---------- */
function pad2(n) { return (n < 10 ? '0' : '') + n; }
function toDateStr(d) { return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate()); }
function todayStr() { return toDateStr(new Date()); }
function nowTimeStr() { var d = new Date(); return pad2(d.getHours()) + ':' + pad2(d.getMinutes()); }
function addDays(dateStr, n) {
  var p = dateStr.split('-');
  var d = new Date(+p[0], +p[1] - 1, +p[2]);
  d.setDate(d.getDate() + n);
  return toDateStr(d);
}
function lastNDays(n) {
  var out = [];
  for (var i = n - 1; i >= 0; i--) { out.push(addDays(todayStr(), -i)); }
  return out;
}
function isTimePassed(planTime, now) { return planTime <= now; }
function fmtTime(ts) { var d = new Date(ts); return pad2(d.getHours()) + ':' + pad2(d.getMinutes()); }
var WEEK = ['日', '一', '二', '三', '四', '五', '六'];
function fmtDateCN(dateStr) { var p = dateStr.split('-'); return (+p[1]) + ' 月 ' + (+p[2]) + ' 日'; }
function fmtDateFullCN(dateStr) {
  var p = dateStr.split('-');
  var d = new Date(+p[0], +p[1] - 1, +p[2]);
  return (+p[1]) + ' 月 ' + (+p[2]) + ' 日 周' + WEEK[d.getDay()];
}
function relLabel(dateStr) {
  var t = todayStr();
  if (dateStr === t) { return '今天'; }
  if (dateStr === addDays(t, -1)) { return '昨天'; }
  return fmtDateCN(dateStr);
}

/* ---------- 存取（wx.Storage） ---------- */
function blank() { return { plants: [], plans: [], records: [], prefs: { remind: true }, seq: 0 }; }
function parseRaw(raw) {
  if (!raw) { return null; }
  var s = typeof raw === 'string' ? JSON.parse(raw) : raw;
  if (!s || !Array.isArray(s.plants)) { return null; }
  return s;
}
function load() {
  try {
    var s = parseRaw(wx.getStorageSync(KEY));
    if (s) { s.prefs = s.prefs || { remind: true }; s.seq = s.seq || 0; return s; }
  } catch (e) { /* 落到迁移逻辑 */ }
  try {
    var old = parseRaw(wx.getStorageSync(OLD_KEY));
    if (old) { return migrateV1(old); }
  } catch (e) { /* 忽略，走种子 */ }
  return null;
}
/** v1 → v2：记录键从 (植物+类型+日期) 扩为 (植物+类型+周期+日期)。
 *  旧记录按 plantId+type 找计划：唯一匹配则继承其 intervalDays；
 *  同类型多条时挂到 sortOrder 最小的计划（旧数据本就共享一条记录，无法拆分）；
 *  匹配不到计划的记录视为孤儿，直接丢弃（开发期测试数据）。
 *  同一 (植物+类型+周期+日期) 若出现多条，保留 doneAt 最新的一条。 */
function migrateV1(old) {
  old.prefs = old.prefs || { remind: true };
  old.seq = old.seq || 0;
  var seen = {};
  old.records = (old.records || []).filter(function (r) {
    var plans = (old.plans || []).filter(function (pl) { return pl.plantId === r.plantId && pl.type === r.type; });
    if (plans.length === 0) { return false; }
    plans.sort(function (a, b) { return a.sortOrder - b.sortOrder; });
    r.intervalDays = plans[0].intervalDays;
    var k = r.plantId + '|' + r.type + '|' + r.intervalDays + '|' + r.planDate;
    if (seen[k]) { return (r.doneAt || 0) > (seen[k].doneAt || 0) ? (seen[k] = r, false) : false; }
    seen[k] = r;
    return true;
  });
  save(old);
  wx.removeStorageSync(OLD_KEY);
  return old;
}
function save(s) { wx.setStorageSync(KEY, s); }
function nextId(s) { s.seq = (s.seq || 0) + 1; return s.seq; }

/* ---------- 演示数据（与 web 版一致，日期相对今天动态生成） ---------- */
function seed() {
  var s = blank();
  function rel(n) { return addDays(todayStr(), n); }
  function ts(dateStr, hhmm) {
    var p = dateStr.split('-'), t = hhmm.split(':');
    return new Date(+p[0], +p[1] - 1, +p[2], +t[0], +t[1]).getTime();
  }
  var p1 = { id: nextId(s), name: '绿萝 bb', species: '绿萝', place: '客厅电视柜', status: 1, createdAt: ts(rel(-100), '10:00') };
  var p2 = { id: nextId(s), name: '龟背竹', species: '龟背竹', place: '书房窗台', status: 1, createdAt: ts(rel(-100), '10:00') };
  var p3 = { id: nextId(s), name: '小仙人掌', species: '金琥', place: '卧室飘窗', status: 1, createdAt: ts(rel(-100), '10:00') };
  s.plants.push(p1, p2, p3);
  s.plans.push(
    { id: nextId(s), plantId: p1.id, type: '浇水', intervalDays: 2, remindTime: '09:00', sortOrder: 1 },
    { id: nextId(s), plantId: p1.id, type: '施肥', intervalDays: 30, remindTime: '09:00', sortOrder: 2 },
    { id: nextId(s), plantId: p1.id, type: '修剪', intervalDays: 30, remindTime: '09:00', sortOrder: 3 },
    { id: nextId(s), plantId: p1.id, type: '换盆', intervalDays: 90, remindTime: '09:00', sortOrder: 4 },
    { id: nextId(s), plantId: p2.id, type: '浇水', intervalDays: 3, remindTime: '08:30', sortOrder: 1 },
    { id: nextId(s), plantId: p3.id, type: '浇水', intervalDays: 14, remindTime: '10:00', sortOrder: 1 }
  );
  function done(plantId, type, intervalDays, dateStr, hhmm) {
    s.records.push({ id: nextId(s), plantId: plantId, type: type, intervalDays: intervalDays, planDate: dateStr, status: 1, doneAt: ts(dateStr, hhmm) });
  }
  for (var d = -30; d <= 0; d += 2) { done(p1.id, '浇水', 2, rel(d), d === 0 ? '09:05' : '08:58'); }
  done(p1.id, '施肥', 30, rel(-30), '09:07');
  done(p1.id, '修剪', 30, rel(-30), '09:10');
  done(p1.id, '换盆', 90, rel(-90), '10:20');
  for (var e = -30; e <= -3; e += 3) { done(p2.id, '浇水', 3, rel(e), '08:35'); }
  done(p3.id, '浇水', 14, rel(-29), '10:02');
  done(p3.id, '浇水', 14, rel(-15), '10:06');
  done(p3.id, '浇水', 14, rel(-1), '10:05');
  save(s);
  return s;
}

var state = load() || seed();
save(state);

/* ---------- 领域逻辑（与 CareService.ets 对应） ---------- */
var ST = { WAIT: 0, DONE: 1, SKIPPED: 2 };
var PS = { ACTIVE: 1, ARCHIVED: 0 };
var PRESETS = ['浇水', '施肥', '修剪', '换盆'];
var MAX_PLANS = 10; // 2026-10-17 小佳反馈 6 条太少，放宽到 10（与 CareType.MAX_PLANS 保持一致）

function activePlants() { return state.plants.filter(function (p) { return p.status === PS.ACTIVE; }); }
function plantById(id) {
  id = +id;
  for (var i = 0; i < state.plants.length; i++) { if (state.plants[i].id === id) { return state.plants[i]; } }
  return null;
}
function plansOf(plantId) {
  plantId = +plantId;
  return state.plans.filter(function (pl) { return pl.plantId === plantId; })
    .sort(function (a, b) { return a.sortOrder - b.sortOrder; });
}
/* 记录记账键 = 植物 + 类型 + 周期 + 日期（2026-10-17 加周期维度：
   同类型多条计划（如两个不同周期的「施肥」）各自独立记账、互不干扰） */
function recordOf(plantId, type, intervalDays, date) {
  plantId = +plantId; intervalDays = +intervalDays;
  for (var i = 0; i < state.records.length; i++) {
    var r = state.records[i];
    if (r.plantId === plantId && r.type === type && r.intervalDays === intervalDays && r.planDate === date) { return r; }
  }
  return null;
}
function lastDoneDate(plantId, type, intervalDays, date) {
  plantId = +plantId; intervalDays = +intervalDays;
  var last = '';
  for (var i = 0; i < state.records.length; i++) {
    var r = state.records[i];
    if (r.plantId === plantId && r.type === type && r.intervalDays === intervalDays && r.status === ST.DONE && r.planDate < date) {
      if (r.planDate > last) { last = r.planDate; }
    }
  }
  return last;
}
function isDue(plant, plan, date) {
  if (date < toDateStr(new Date(plant.createdAt))) { return false; }
  var last = lastDoneDate(plant.id, plan.type, plan.intervalDays, date);
  if (last === '') { return true; }
  return date >= addDays(last, plan.intervalDays);
}
function statusOf(plantId, type, intervalDays, date) {
  var r = recordOf(plantId, type, intervalDays, date);
  return r ? r.status : ST.WAIT;
}
function planOf(date) {
  var result = [];
  var now = nowTimeStr();
  var plants = activePlants();
  for (var i = 0; i < plants.length; i++) {
    var p = plants[i];
    var plans = plansOf(p.id);
    for (var j = 0; j < plans.length; j++) {
      var plan = plans[j];
      if (!isDue(p, plan, date)) { continue; }
      var st = statusOf(p.id, plan.type, plan.intervalDays, date);
      var passed = false;
      if (date === todayStr()) { passed = st === ST.WAIT && isTimePassed(plan.remindTime, now); }
      result.push({
        plantId: p.id, plantName: p.name, place: p.place,
        type: plan.type, intervalDays: plan.intervalDays, planTime: plan.remindTime,
        status: st, passed: passed
      });
    }
  }
  result.sort(function (a, b) { return a.planTime < b.planTime ? -1 : (a.planTime > b.planTime ? 1 : 0); });
  return result;
}
function doneCount(items) {
  var n = 0;
  items.forEach(function (it) { if (it.status === ST.DONE) { n++; } });
  return n;
}
function planGrouped(date) {
  var items = planOf(date);
  var result = [];
  items.forEach(function (it) {
    var g = null;
    for (var i = 0; i < result.length; i++) { if (result[i].plantId === it.plantId) { g = result[i]; break; } }
    if (!g) {
      g = { plantId: it.plantId, plantName: it.plantName, place: it.place, items: [], doneCount: 0, totalCount: 0 };
      result.push(g);
    }
    g.items.push(it);
    g.totalCount++;
    if (it.status === ST.DONE) { g.doneCount++; }
  });
  return result;
}
function toggle(plantId, type, intervalDays, date) {
  plantId = +plantId; intervalDays = +intervalDays;
  var r = recordOf(plantId, type, intervalDays, date);
  if (r && r.status === ST.DONE) {
    state.records.splice(state.records.indexOf(r), 1);
  } else if (r) {
    r.status = ST.DONE; r.doneAt = Date.now();
  } else {
    state.records.push({ id: nextId(state), plantId: plantId, type: type, intervalDays: intervalDays, planDate: date, status: ST.DONE, doneAt: Date.now() });
  }
  save(state);
}
function adherence(days) {
  var total = 0, done = 0, skipped = 0;
  lastNDays(days).forEach(function (d) {
    planOf(d).forEach(function (it) {
      total++;
      if (it.status === ST.DONE) { done++; }
      else if (it.status === ST.SKIPPED) { skipped++; }
    });
  });
  var missed = Math.max(0, total - done - skipped);
  var rate = total > 0 ? Math.round(done * 1000 / total) / 10 : 0;
  return { total: total, done: done, missed: missed, rate: Math.min(100, rate) };
}
function groupsOf(days) {
  var dates = lastNDays(days);
  var result = [];
  for (var i = dates.length - 1; i >= 0; i--) {
    var items = planOf(dates[i]);
    if (items.length === 0) { continue; }
    result.push({ date: dates[i], items: items, doneCount: doneCount(items), totalCount: items.length });
  }
  return result;
}
function streak() {
  var hasDone = function (d) {
    return state.records.some(function (r) { return r.status === ST.DONE && r.planDate === d; });
  };
  var d = todayStr();
  if (!hasDone(d)) { d = addDays(d, -1); if (!hasDone(d)) { return 0; } }
  var n = 0;
  while (hasDone(d)) { n++; d = addDays(d, -1); }
  return n;
}
function overview() {
  var typeCount = {}, plantCount = {};
  state.records.forEach(function (r) {
    if (r.status !== ST.DONE) { return; }
    typeCount[r.type] = (typeCount[r.type] || 0) + 1;
    plantCount[r.plantId] = (plantCount[r.plantId] || 0) + 1;
  });
  function top(obj) {
    var best = '', bn = 0;
    Object.keys(obj).forEach(function (k) { if (obj[k] > bn) { bn = obj[k]; best = k; } });
    return best;
  }
  var topPlantId = top(plantCount);
  var topPlantName = '—';
  if (topPlantId !== '') { var tp = plantById(+topPlantId); if (tp) { topPlantName = tp.name; } }
  return {
    plantTotal: state.plants.filter(function (p) { return p.status === PS.ACTIVE; }).length,
    archived: state.plants.filter(function (p) { return p.status === PS.ARCHIVED; }).length,
    planTotal: state.plans.length,
    checkins: state.records.filter(function (r) { return r.status === ST.DONE; }).length,
    topType: top(typeCount) || '—',
    topPlant: topPlantName,
    streak: streak()
  };
}

/* ---------- 植物增改删 ---------- */
/** 同盆养护类型不重复（与 PlantEdit 一致），保留第一条 */
/* 有效性过滤：仅剔除空类型行。
   注意：同盆允许同类型多条（如两个不同周期的「施肥」），不做去重——
   去重曾导致用户添加的项在保存时被静默合并（2026-10-17 修复）。 */
function validPlans(plans) {
  return plans.filter(function (pl) { return pl && pl.type; });
}
function addPlant(form) {
  var p = { id: nextId(state), name: form.name, species: form.species, place: form.place, status: PS.ACTIVE, createdAt: Date.now() };
  state.plants.push(p);
  validPlans(form.plans).forEach(function (pl, i) {
    state.plans.push({ id: nextId(state), plantId: p.id, type: pl.type, intervalDays: pl.intervalDays, remindTime: pl.remindTime, sortOrder: i + 1 });
  });
  save(state);
  return p;
}
function updatePlant(form) {
  var p = plantById(form.id);
  if (!p) { return; }
  p.name = form.name; p.species = form.species; p.place = form.place;
  state.plans = state.plans.filter(function (pl) { return pl.plantId !== p.id; });
  validPlans(form.plans).forEach(function (pl, i) {
    state.plans.push({ id: nextId(state), plantId: p.id, type: pl.type, intervalDays: pl.intervalDays, remindTime: pl.remindTime, sortOrder: i + 1 });
  });
  save(state);
}
function setArchived(id, archived) {
  var p = plantById(id);
  if (p) { p.status = archived ? PS.ARCHIVED : PS.ACTIVE; save(state); }
}
function deletePlant(id) {
  id = +id;
  state.plants = state.plants.filter(function (p) { return p.id !== id; });
  state.plans = state.plans.filter(function (pl) { return pl.plantId !== id; });
  state.records = state.records.filter(function (r) { return r.plantId !== id; });
  save(state);
}
function clearAll() {
  var prefs = state.prefs;
  state = blank();
  state.prefs = prefs;
  save(state);
}
function resetDemo() { wx.removeStorageSync(KEY); state = seed(); }
function setRemind(on) { state.prefs.remind = on; save(state); }

/* ---------- 展示辅助 ---------- */
var EMOJI_RULES = [
  [/仙人|掌|球|琥/, '🌵'], [/萝/, '🌿'], [/竹/, '🌱'], [/玫瑰|月季/, '🌹'],
  [/多肉|肉肉/, '🪴'], [/兰/, '🌺'], [/菊/, '🌼'], [/梅/, '🌸'],
  [/松|柏/, '🌲'], [/树|榕|樟|枫/, '🌳'], [/花/, '🌸'], [/草|苔/, '🌿']
];
function emojiFor(p) {
  var text = (p.name || '') + (p.species || '');
  for (var i = 0; i < EMOJI_RULES.length; i++) {
    if (EMOJI_RULES[i][0].test(text)) { return EMOJI_RULES[i][1]; }
  }
  return '🪴';
}

module.exports = {
  KEY: KEY, ST: ST, PS: PS, PRESETS: PRESETS, MAX_PLANS: MAX_PLANS,
  state: function () { return state; },
  todayStr: todayStr, nowTimeStr: nowTimeStr, addDays: addDays, lastNDays: lastNDays,
  fmtDateCN: fmtDateCN, fmtDateFullCN: fmtDateFullCN, relLabel: relLabel, fmtTime: fmtTime,
  activePlants: activePlants, plantById: plantById, plansOf: plansOf,
  planOf: planOf, planGrouped: planGrouped, adherence: adherence, groupsOf: groupsOf,
  overview: overview, streak: streak,
  toggle: toggle, addPlant: addPlant, updatePlant: updatePlant,
  setArchived: setArchived, deletePlant: deletePlant, clearAll: clearAll,
  resetDemo: resetDemo, setRemind: setRemind,
  emojiFor: emojiFor
};
