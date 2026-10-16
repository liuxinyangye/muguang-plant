// 花园页：植物列表 + 新增/编辑（弹出层）+ 归档/恢复/删除
var mg = require('../../utils/mg.js');

Page({
  data: {
    plants: [],          // 渲染用列表（含 emoji）
    countLabel: '',
    // 编辑弹层
    sheetVisible: false,
    sheetTitle: '添加植物',
    editingId: 0,
    nickname: '',
    species: '',
    place: '',
    nicknameError: false,
    planRows: [],        // [{ type, intervalDays, remindTime }]
    // 类型选择器
    pickerVisible: false,
    pickerIndex: -1,
    customType: '',
    presets: mg.PRESETS,
    maxPlans: mg.MAX_PLANS
  },

  onShow: function () {
    this.refresh();
  },

  noop: function () {},

  refresh: function () {
    var that = this;
    var plants = mg.state().plants.map(function (p) {
      return {
        id: p.id, name: p.name, species: p.species, place: p.place,
        status: p.status, emoji: mg.emojiFor(p),
        plans: mg.plansOf(p.id).map(function (pl) {
          return { type: pl.type, intervalDays: pl.intervalDays, remindTime: pl.remindTime };
        })
      };
    });
    var ov = mg.overview();
    this.setData({
      plants: plants,
      countLabel: ov.plantTotal + ' 盆养护中' + (ov.archived > 0 ? ' · ' + ov.archived + ' 盆已归档' : '')
    });
  },

  /* ---------- 编辑弹层 ---------- */
  openSheet: function (id) {
    var editingId = id || 0;
    var p = editingId ? mg.plantById(editingId) : null;
    var planRows;
    if (p) {
      var plans = mg.plansOf(p.id);
      planRows = plans.length > 0
        ? plans.map(function (pl) { return { type: pl.type, intervalDays: pl.intervalDays, remindTime: pl.remindTime }; })
        : [{ type: '浇水', intervalDays: 2, remindTime: '09:00' }];
    } else {
      planRows = [{ type: '浇水', intervalDays: 2, remindTime: '09:00' }];
    }
    this.setData({
      sheetVisible: true,
      sheetTitle: editingId ? '编辑植物' : '添加植物',
      editingId: editingId,
      nickname: p ? p.name : '',
      species: p ? (p.species || '') : '',
      place: p ? (p.place || '') : '',
      nicknameError: false,
      planRows: planRows
    });
  },

  closeSheet: function () { this.setData({ sheetVisible: false }); },

  onNicknameInput: function (e) {
    this.setData({ nickname: e.detail.value, nicknameError: false });
  },
  onSpeciesInput: function (e) { this.setData({ species: e.detail.value }); },
  onPlaceInput: function (e) { this.setData({ place: e.detail.value }); },

  onIntervalInput: function (e) {
    var idx = +e.currentTarget.dataset.idx;
    var key = 'planRows[' + idx + '].intervalDays';
    this.setData({ [key]: Math.max(1, parseInt(e.detail.value, 10) || 1) });
  },
  onTimeInput: function (e) {
    var idx = +e.currentTarget.dataset.idx;
    this.setData({ ['planRows[' + idx + '].remindTime']: e.detail.value || '09:00' });
  },

  addPlanRow: function () {
    if (this.data.planRows.length >= mg.MAX_PLANS) {
      wx.showToast({ title: '每盆最多 ' + mg.MAX_PLANS + ' 条', icon: 'none' });
      return;
    }
    this.setData({ planRows: this.data.planRows.concat([{ type: '施肥', intervalDays: 30, remindTime: '09:00' }]) });
  },

  delPlanRow: function (e) {
    var idx = +e.currentTarget.dataset.idx;
    if (this.data.planRows.length <= 1) {
      wx.showToast({ title: '至少保留一条养护计划', icon: 'none' });
      return;
    }
    var rows = this.data.planRows.slice();
    rows.splice(idx, 1);
    this.setData({ planRows: rows });
  },

  saveSheet: function () {
    var name = (this.data.nickname || '').trim();
    if (name === '') {
      this.setData({ nicknameError: true });
      return;
    }
    var plans = this.data.planRows.filter(function (r) { return r.type !== ''; });
    if (plans.length === 0) { wx.showToast({ title: '至少保留一条养护计划', icon: 'none' }); return; }
    var form = {
      id: this.data.editingId,
      name: name,
      species: (this.data.species || '').trim(),
      place: (this.data.place || '').trim(),
      plans: plans
    };
    if (this.data.editingId) {
      mg.updatePlant(form);
      wx.showToast({ title: '已保存', icon: 'success' });
    } else {
      mg.addPlant(form);
      wx.showToast({ title: '已添加 ' + name, icon: 'success' });
    }
    this.closeSheet();
    this.refresh();
  },

  /* ---------- 类型选择器 ---------- */
  openPicker: function (e) {
    this.setData({ pickerVisible: true, pickerIndex: +e.currentTarget.dataset.idx, customType: '' });
  },
  closePicker: function () { this.setData({ pickerVisible: false }); },
  applyPreset: function (e) {
    var type = e.currentTarget.dataset.type;
    this.setData({ ['planRows[' + this.data.pickerIndex + '].type']: type, pickerVisible: false });
  },
  onCustomInput: function (e) { this.setData({ customType: e.detail.value }); },
  applyCustom: function () {
    var name = (this.data.customType || '').trim();
    if (name === '') { wx.showToast({ title: '请输入养护类型名称', icon: 'none' }); return; }
    if (name.length > 8) { wx.showToast({ title: '类型名称不要超过 8 个字', icon: 'none' }); return; }
    this.setData({ ['planRows[' + this.data.pickerIndex + '].type']: name, pickerVisible: false });
  },

  /* ---------- 列表操作 ---------- */
  onArchive: function (e) {
    mg.setArchived(+e.currentTarget.dataset.id, true);
    this.refresh();
    wx.showToast({ title: '已归档', icon: 'success' });
  },
  onRestore: function (e) {
    mg.setArchived(+e.currentTarget.dataset.id, false);
    this.refresh();
    wx.showToast({ title: '已恢复养护', icon: 'success' });
  },
  onDelete: function (e) {
    var id = +e.currentTarget.dataset.id;
    var p = mg.plantById(id);
    var that = this;
    wx.showModal({
      title: '删除植物',
      content: '确定删除「' + (p ? p.name : '') + '」？将同时删除它的养护计划与记录，无法恢复。',
      confirmColor: '#C25B5B',
      success: function (res) {
        if (res.confirm) {
          mg.deletePlant(id);
          that.refresh();
          wx.showToast({ title: '已删除', icon: 'success' });
        }
      }
    });
  }
});
