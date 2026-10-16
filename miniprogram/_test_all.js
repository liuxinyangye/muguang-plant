/* 小程序验证：① mg.js 数据层逻辑（mock wx）② JSON 配置合法性 ③ JS 语法 ④ WXML 静态检查 */
'use strict';
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const root = __dirname;
const NODE = 'C:/Users/Lenovo/.workbuddy/binaries/node/versions/22.22.2-6/node.exe';
let pass = 0, fail = 0;
function check(name, cond, extra) {
  if (cond) { pass++; console.log('  ✓ ' + name); }
  else { fail++; console.log('  ✗ ' + name + (extra ? ' → ' + extra : '')); }
}

/* ---------- ① 数据层逻辑（mock wx.Storage） ---------- */
console.log('== mg.js 数据层逻辑 ==');
const mpStore = {};
global.wx = {
  getStorageSync: k => (k in mpStore ? mpStore[k] : ''),
  setStorageSync: (k, v) => { mpStore[k] = v; },
  removeStorageSync: k => { delete mpStore[k]; },
  showToast: () => {}, showModal: () => {}
};
const mg = require(path.join(root, 'utils', 'mg.js'));

const items = mg.planOf(mg.todayStr());
check('今日 5 项待办', items.length === 5, '实际 ' + items.length);
check('1 项已完成', items.filter(i => i.status === 1).length === 1);
check('小仙人掌今天不应做', items.filter(i => i.plantName === '小仙人掌').length === 0);
check('分组 2 组', mg.planGrouped(mg.todayStr()).length === 2);
const g = mg.planGrouped(mg.todayStr());
check('绿萝组 4 项 1 完成', g.find(x => x.plantName === '绿萝 bb').totalCount === 4 && g.find(x => x.plantName === '绿萝 bb').doneCount === 1);

const t = items.find(i => i.plantName === '龟背竹');
mg.toggle(t.plantId, t.type, mg.todayStr());
check('打卡后已完成', mg.planOf(mg.todayStr()).find(i => i.plantId === t.plantId).status === 1);
check('wx.Storage 已写入', !!mpStore['muguang_mp_v1']);
mg.toggle(t.plantId, t.type, mg.todayStr());
check('再点撤销', mg.planOf(mg.todayStr()).find(i => i.plantId === t.plantId).status === 0);

check('明天不顺延（未打卡）', mg.planOf(mg.addDays(mg.todayStr(), 1)).filter(i => i.plantId === t.plantId).length > 0);
mg.toggle(t.plantId, t.type, mg.todayStr());
check('打卡后明天不再应做', mg.planOf(mg.addDays(mg.todayStr(), 1)).filter(i => i.plantId === t.plantId).length === 0);
mg.toggle(t.plantId, t.type, mg.todayStr());

const a7 = mg.adherence(7), a30 = mg.adherence(30);
check('近 7 天 11 应做 / 7 完成 / 63.6%', a7.total === 11 && a7.done === 7 && a7.rate === 63.6, JSON.stringify(a7));
check('近 30 天 31 应做 / 27 完成 / 87.1%', a30.total === 31 && a30.done === 27 && a30.rate === 87.1, JSON.stringify(a30));
check('记录页 7 天 6 组', mg.groupsOf(7).length === 6);
check('最勤植物=绿萝 bb', mg.overview().topPlant === '绿萝 bb');
check('连续养护 5 天', mg.streak() === 5);

const pid = mg.addPlant({ name: '测试月季', species: '月季', place: '阳台', plans: [{ type: '浇水', intervalDays: 1, remindTime: '08:00' }] }).id;
check('新增后 4 盆', mg.state().plants.length === 4);
mg.updatePlant({ id: pid, name: '测试月季', species: '月季', place: '阳台', plans: [{ type: '浇水', intervalDays: 7, remindTime: '08:00' }, { type: '浇水', intervalDays: 3, remindTime: '09:00' }] });
check('同盆重复类型被去重', mg.plansOf(pid).length === 1, '实际 ' + mg.plansOf(pid).length);
mg.setArchived(pid, true);
check('归档后今日仍 5 项', mg.planOf(mg.todayStr()).length === 5);
mg.deletePlant(pid);
check('删除后 3 盆且记录同步清掉', mg.state().plants.length === 3 && mg.plansOf(pid).length === 0);
mg.clearAll();
check('清空后 0 盆', mg.state().plants.length === 0);
check('清空后 adherence 为 0', mg.adherence(7).total === 0);

/* ---------- ② JSON 配置合法性 ---------- */
console.log('== JSON 配置 ==');
const jsonFiles = ['app.json', 'project.config.json', 'sitemap.json',
  'pages/index/index.json', 'pages/garden/garden.json', 'pages/record/record.json', 'pages/settings/settings.json'];
jsonFiles.forEach(function (f) {
  try {
    const j = JSON.parse(fs.readFileSync(path.join(root, f), 'utf8'));
    check('合法 JSON: ' + f, true);
    if (f === 'app.json') {
      check('app.json 注册 4 个页面', j.pages.length === 4);
      check('tabBar 4 项', j.tabBar.list.length === 4);
      j.pages.forEach(function (p) {
        check('页面文件存在: ' + p, ['js', 'json', 'wxml', 'wxss'].every(ext => fs.existsSync(path.join(root, p + '.' + ext))));
      });
    }
  } catch (e) {
    check('合法 JSON: ' + f, false, e.message);
  }
});

/* ---------- ③ JS 语法 ---------- */
console.log('== JS 语法 ==');
['app.js', 'utils/mg.js', 'pages/index/index.js', 'pages/garden/garden.js', 'pages/record/record.js', 'pages/settings/settings.js'].forEach(function (f) {
  try {
    execSync('"' + NODE + '" --check "' + path.join(root, f) + '"', { stdio: 'pipe' });
    check('语法合法: ' + f, true);
  } catch (e) { check('语法合法: ' + f, false); }
});

/* ---------- ④ WXML 静态检查 ---------- */
console.log('== WXML 静态检查 ==');
['pages/index/index.wxml', 'pages/garden/garden.wxml', 'pages/record/record.wxml', 'pages/settings/settings.wxml'].forEach(function (f) {
  const xml = fs.readFileSync(path.join(root, f), 'utf8');
  // 标签配对（粗粒度：view/text/block/input/picker/label/button）
  const tags = ['view', 'text', 'block', 'input', 'picker', 'label', 'button', 'scroll-view'];
  let ok = true, msg = '';
  tags.forEach(function (tag) {
    const open = (xml.match(new RegExp('<' + tag + '(\\s|>|/)', 'g')) || []).length;
    const close = (xml.match(new RegExp('</' + tag + '>', 'g')) || []).length;
    const selfClose = (xml.match(new RegExp('<' + tag + '[^>]*/>', 'g')) || []).length;
    if (open !== close + selfClose) { ok = false; msg = tag + ': ' + open + ' open vs ' + close + ' close + ' + selfClose + ' self'; }
  });
  check('标签配对: ' + f, ok, msg);
  // wx:for 必须配 wx:key
  const forCount = (xml.match(/wx:for="/g) || []).length;
  const keyCount = (xml.match(/wx:key=/g) || []).length;
  check('wx:for/wx:key 配对: ' + f, forCount === keyCount, forCount + ' for vs ' + keyCount + ' key');
  // 同一标签不出现重复属性
  const dupAttr = /<(\w+)([^>]*)>/.test(xml) && (function () {
    const m = xml.match(/<(\w+)((?:\s+[\w-]+="[^"]*")+)\s*>/g) || [];
    return m.some(function (tagHtml) {
      const attrs = tagHtml.match(/[\w-]+="/g) || [];
      return attrs.length !== new Set(attrs).size;
    });
  })();
  check('无重复属性: ' + f, !dupAttr);
  // 页面 js 中绑定的函数都在 wxml 里能找到对应 bind/catch
  const jsFile = f.replace('.wxml', '.js');
  const js = fs.readFileSync(path.join(root, jsFile), 'utf8');
  const handlers = new Set();
  const hre = /(?:bind|catch)tap="(\w+)"/g;
  let hm;
  while ((hm = hre.exec(xml)) !== null) { handlers.add(hm[1]); }
  const missing = [...handlers].filter(h => !new RegExp('(function\\s+' + h + '\\b|' + h + '\\s*[:=]\\s*function|' + h + '\\s*\\(\\s*\\)\\s*\\{)').test(js));
  check('事件处理函数已定义: ' + f, missing.length === 0, missing.length ? '缺失: ' + missing.join(',') : '');
});

console.log('\n结果：' + pass + ' 通过，' + fail + ' 失败');
process.exit(fail > 0 ? 1 : 0);
