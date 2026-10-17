// 今日页：按植物分组的待办，点击圆圈打卡/撤销（写 wx.Storage）
var mg = require('../../utils/mg.js');

Page({
  data: {
    dateLabel: '',
    groups: [],          // 按植物分组的待办
    expanded: {},        // 植物 id -> 是否展开（默认收起第 4 项起）
    done: 0,
    total: 0,
    rate: 0,
    passed: 0,
    streak: 0,
    plantTotal: 0,
    empty: false
  },

  onShow: function () {
    this.refresh();
  },

  refresh: function () {
    var groups = mg.planGrouped(mg.todayStr());
    var items = mg.planOf(mg.todayStr());
    var done = 0, passed = 0;
    items.forEach(function (it) {
      if (it.status === mg.ST.DONE) { done++; }
      if (it.passed) { passed++; }
    });
    var total = items.length;
    var ov = mg.overview();
    this.setData({
      dateLabel: mg.fmtDateFullCN(mg.todayStr()),
      groups: groups,
      done: done,
      total: total,
      rate: total > 0 ? Math.round(done * 100 / total) : 0,
      passed: passed,
      streak: ov.streak,
      plantTotal: ov.plantTotal,
      empty: groups.length === 0
    });
  },

  onToggleTask: function (e) {
    var plantId = e.currentTarget.dataset.plant;
    var type = e.currentTarget.dataset.type;
    var intervalDays = e.currentTarget.dataset.interval;
    mg.toggle(plantId, type, intervalDays, mg.todayStr());
    this.refresh();
  },

  onToggleFold: function (e) {
    var plantId = e.currentTarget.dataset.plant;
    var key = 'expanded.' + plantId;
    this.setData({ [key]: !this.data.expanded[plantId] });
  },

  onCheckAll: function () {
    mg.planOf(mg.todayStr()).forEach(function (it) {
      if (it.status !== mg.ST.DONE) { mg.toggle(it.plantId, it.type, it.intervalDays, mg.todayStr()); }
    });
    this.refresh();
    wx.showToast({ title: '已全部打卡', icon: 'success' });
  },

  onReset: function () {
    var that = this;
    wx.showModal({
      title: '恢复演示数据',
      content: '将清空当前数据并恢复三盆示例植物，确定吗？',
      success: function (res) {
        if (res.confirm) {
          mg.resetDemo();
          that.setData({ expanded: {} });
          that.refresh();
          wx.showToast({ title: '已恢复', icon: 'success' });
        }
      }
    });
  },

  goGarden: function () {
    // 一步到位：先置全局信号，花园页 onShow 会自动弹出添加弹层（不用用户再点一次「＋ 添加」）
    getApp().globalData.pendingAddPlant = true;
    wx.switchTab({ url: '/pages/garden/garden' });
  }
});
