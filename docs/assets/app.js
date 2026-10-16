/* ============================================================
   沐光 · 植物养护助手 — web 可交互版 数据层与共享逻辑
   与鸿蒙端保持一致：
   - 数据模型   ↔ model/Types.ets（plant / care_plan / care_record 三张表）
   - 到期规则   ↔ service/CareService.ets（周期模型）
   - 统计口径   ↔ CareService.adherence()（应做/完成/漏做/完成率）
   存储：浏览器 localStorage（键 muguang_web_v1），首次打开自动写入演示数据
   ============================================================ */
(function () {
  'use strict';

  var KEY = 'muguang_web_v1';

  /* ---------- 日期工具（对应 common/DateUtil.ets） ---------- */
  function pad2(n) { return (n < 10 ? '0' : '') + n; }
  function toDateStr(d) {
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
  }
  function todayStr() { return toDateStr(new Date()); }
  function nowTimeStr() {
    var d = new Date();
    return pad2(d.getHours()) + ':' + pad2(d.getMinutes());
  }
  function addDays(dateStr, n) {
    var p = dateStr.split('-');
    var d = new Date(+p[0], +p[1] - 1, +p[2]);
    d.setDate(d.getDate() + n);
    return toDateStr(d);
  }
  /** 最近 n 天（含今天），由远到近 */
  function lastNDays(n) {
    var out = [];
    for (var i = n - 1; i >= 0; i--) { out.push(addDays(todayStr(), -i)); }
    return out;
  }
  /** 计划时刻是否已过（HH:mm 字典序比较） */
  function isTimePassed(planTime, now) { return planTime <= now; }
  function fmtTime(ts) {
    var d = new Date(ts);
    return pad2(d.getHours()) + ':' + pad2(d.getMinutes());
  }
  var WEEK = ['日', '一', '二', '三', '四', '五', '六'];
  function fmtDateCN(dateStr) {
    var p = dateStr.split('-');
    return (+p[1]) + ' 月 ' + (+p[2]) + ' 日';
  }
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

  /* ---------- 存取 ---------- */
  function blank() {
    return { plants: [], plans: [], records: [], prefs: { remind: true }, seq: 0 };
  }
  function load() {
    try {
      var raw = localStorage.getItem(KEY);
      if (!raw) { return null; }
      var s = JSON.parse(raw);
      if (!s || !Array.isArray(s.plants)) { return null; }
      s.prefs = s.prefs || { remind: true };
      s.seq = s.seq || 0;
      return s;
    } catch (e) { return null; }
  }
  function save(s) { localStorage.setItem(KEY, JSON.stringify(s)); }
  function nextId(s) { s.seq = (s.seq || 0) + 1; return s.seq; }

  /* ---------- 演示数据（日期相对"今天"动态生成，保证任何日子打开都是新鲜状态） ----------
     今日清单与真机截图一致：绿萝 bb 4 项（浇水已打卡）+ 龟背竹 1 项 = 5 项待办 */
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

    function done(plantId, type, dateStr, hhmm) {
      s.records.push({ id: nextId(s), plantId: plantId, type: type, planDate: dateStr, status: 1, doneAt: ts(dateStr, hhmm) });
    }
    // 绿萝浇水：每 2 天，近 30 天全勤；今天早上 09:05 已打卡
    for (var d = -30; d <= 0; d += 2) { done(p1.id, '浇水', rel(d), d === 0 ? '09:05' : '08:58'); }
    // 施肥 / 修剪：30 天前做过 → 今天正好到期（未打卡，过点提醒）
    done(p1.id, '施肥', rel(-30), '09:07');
    done(p1.id, '修剪', rel(-30), '09:10');
    // 换盆：90 天前做过 → 今天到期（未打卡）
    done(p1.id, '换盆', rel(-90), '10:20');
    // 龟背竹浇水：每 3 天，上次 3 天前 → 今天到期（未打卡）
    for (var e = -30; e <= -3; e += 3) { done(p2.id, '浇水', rel(e), '08:35'); }
    // 小仙人掌浇水：14 天周期，昨天刚做过 → 今天不应做（30 天视图内全勤，不留"从未完成"缺口）
    done(p3.id, '浇水', rel(-29), '10:02');
    done(p3.id, '浇水', rel(-15), '10:06');
    done(p3.id, '浇水', rel(-1), '10:05');

    save(s);
    return s;
  }

  var state = load() || seed();
  save(state);

  /* ---------- 领域逻辑（对应 CareService.ets） ---------- */
  var ST = { WAIT: 0, DONE: 1, SKIPPED: 2 };       // RecordStatus
  var PS = { ACTIVE: 1, ARCHIVED: 0 };              // PlantStatus
  var PRESETS = ['浇水', '施肥', '修剪', '换盆'];    // CareType.PRESETS
  var MAX_PLANS = 6;

  function activePlants() {
    return state.plants.filter(function (p) { return p.status === PS.ACTIVE; });
  }
  function plantById(id) {
    for (var i = 0; i < state.plants.length; i++) { if (state.plants[i].id === id) { return state.plants[i]; } }
    return null;
  }
  function plansOf(plantId) {
    return state.plans.filter(function (pl) { return pl.plantId === plantId; })
      .sort(function (a, b) { return a.sortOrder - b.sortOrder; });
  }
  function recordOf(plantId, type, date) {
    for (var i = 0; i < state.records.length; i++) {
      var r = state.records[i];
      if (r.plantId === plantId && r.type === type && r.planDate === date) { return r; }
    }
    return null;
  }
  /** 最近一次完成日（严格早于 date），没有返回 '' */
  function lastDoneDate(plantId, type, date) {
    var last = '';
    for (var i = 0; i < state.records.length; i++) {
      var r = state.records[i];
      if (r.plantId === plantId && r.type === type && r.status === ST.DONE && r.planDate < date) {
        if (r.planDate > last) { last = r.planDate; }
      }
    }
    return last;
  }
  /** 到期规则：① 不早于加入日；② 从未完成 或 最近完成日 + 周期 <= 当天 */
  function isDue(plant, plan, date) {
    if (date < toDateStr(new Date(plant.createdAt))) { return false; }
    var last = lastDoneDate(plant.id, plan.type, date);
    if (last === '') { return true; }
    return date >= addDays(last, plan.intervalDays);
  }
  function statusOf(plantId, type, date) {
    var r = recordOf(plantId, type, date);
    return r ? r.status : ST.WAIT;
  }
  /** 某天的全部待办（今日页 / 记录页同源） */
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
        var st = statusOf(p.id, plan.type, date);
        var passed = false;
        if (date === todayStr()) {
          passed = st === ST.WAIT && isTimePassed(plan.remindTime, now);
        }
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
  /** 今日页按植物分组（一盆一卡） */
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
  /** 切换打卡：未完成 → 完成；已完成 → 撤销 */
  function toggle(plantId, type, date) {
    var r = recordOf(plantId, type, date);
    if (r && r.status === ST.DONE) {
      state.records.splice(state.records.indexOf(r), 1);
    } else if (r) {
      r.status = ST.DONE; r.doneAt = Date.now();
    } else {
      state.records.push({ id: nextId(state), plantId: plantId, type: type, planDate: date, status: ST.DONE, doneAt: Date.now() });
    }
    save(state);
  }
  /** 近 n 天完成率（与记录页清单同源，数字对得上） */
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
  /** 记录页：按日分组，由近到远，无任务的日子不展示 */
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
  /** 连续养护天数：今天有记录从今天数，否则从昨天数；连续中断记 0 */
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
  /** 右侧栏统计 */
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
    if (topPlantId !== '') {
      var tp = plantById(+topPlantId); // 注意：localStorage 反序列化后 key 是字符串，需转数字
      if (tp) { topPlantName = tp.name; }
    }
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

  /* ---------- 植物增改删（对应 PlantService / PlantEdit） ---------- */
  function addPlant(form) {
    var p = { id: nextId(state), name: form.name, species: form.species, place: form.place, status: PS.ACTIVE, createdAt: Date.now() };
    state.plants.push(p);
    form.plans.forEach(function (pl, i) {
      state.plans.push({ id: nextId(state), plantId: p.id, type: pl.type, intervalDays: pl.intervalDays, remindTime: pl.remindTime, sortOrder: i + 1 });
    });
    save(state);
    return p;
  }
  function updatePlant(form) {
    var p = plantById(form.id);
    if (!p) { return; }
    p.name = form.name; p.species = form.species; p.place = form.place;
    // 计划整组替换（记录按 plantId+type+date 存，改类型名后旧记录不再参与新周期计算）
    state.plans = state.plans.filter(function (pl) { return pl.plantId !== p.id; });
    form.plans.forEach(function (pl, i) {
      state.plans.push({ id: nextId(state), plantId: p.id, type: pl.type, intervalDays: pl.intervalDays, remindTime: pl.remindTime, sortOrder: i + 1 });
    });
    save(state);
  }
  function setArchived(id, archived) {
    var p = plantById(id);
    if (p) { p.status = archived ? PS.ARCHIVED : PS.ACTIVE; save(state); }
  }
  function deletePlant(id) {
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
  function resetDemo() {
    localStorage.removeItem(KEY);
    state = seed();
  }
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
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  /* ---------- 共享 UI：Toast / 通知横幅 ---------- */
  var toastTimer = null;
  function toast(msg) {
    var t = document.getElementById('mgToast');
    if (!t) {
      t = document.createElement('div');
      t.id = 'mgToast'; t.className = 'toast';
      document.body.appendChild(t);
    }
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.classList.remove('show'); }, 1800);
  }
  var notifTimer = null;
  /** web 版"通知"演示：顶部横幅（真实系统通知在鸿蒙端，见 Notifier.ets） */
  function notif(title, body) {
    var n = document.getElementById('mgNotif');
    if (!n) {
      n = document.createElement('div');
      n.id = 'mgNotif'; n.className = 'notif';
      n.innerHTML = '<span class="n-ico">🌿</span><div class="n-body"></div><span class="n-tag">web 演示</span>';
      document.body.appendChild(n);
    }
    n.querySelector('.n-body').innerHTML = '<b>' + esc(title) + '</b><span>' + esc(body) + '</span>';
    n.classList.add('show');
    clearTimeout(notifTimer);
    notifTimer = setTimeout(function () { n.classList.remove('show'); }, 3600);
  }

  /* ---------- 导出 ---------- */
  window.MG = {
    KEY: KEY,
    ST: ST, PS: PS, PRESETS: PRESETS, MAX_PLANS: MAX_PLANS,
    state: function () { return state; },
    reload: function () { state = load() || seed(); return state; },
    // 日期
    todayStr: todayStr, nowTimeStr: nowTimeStr, addDays: addDays, lastNDays: lastNDays,
    fmtDateCN: fmtDateCN, fmtDateFullCN: fmtDateFullCN, relLabel: relLabel, fmtTime: fmtTime,
    // 查询
    activePlants: activePlants, plantById: plantById, plansOf: plansOf,
    planOf: planOf, planGrouped: planGrouped, adherence: adherence, groupsOf: groupsOf,
    overview: overview, streak: streak,
    // 变更
    toggle: toggle, addPlant: addPlant, updatePlant: updatePlant,
    setArchived: setArchived, deletePlant: deletePlant, clearAll: clearAll,
    resetDemo: resetDemo, setRemind: setRemind,
    // 展示
    emojiFor: emojiFor, esc: esc, toast: toast, notif: notif
  };
})();
