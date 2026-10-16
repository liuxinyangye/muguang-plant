// 设置页：提醒开关 / 清空数据 / 关于
var mg = require('../../utils/mg.js');

Page({
  data: {
    remind: true,
    plantCount: 0,
    planCount: 0,
    recordCount: 0
  },

  onShow: function () {
    var s = mg.state();
    this.setData({
      remind: !!s.prefs.remind,
      plantCount: s.plants.length,
      planCount: s.plans.length,
      recordCount: s.records.length
    });
  },

  onSwitch: function () {
    var on = !mg.state().prefs.remind;
    mg.setRemind(on);
    this.setData({ remind: on });
    wx.showToast({ title: on ? '养护提醒已开启' : '养护提醒已关闭', icon: 'none' });
  },

  onTestNotif: function () {
    var items = mg.planOf(mg.todayStr()).filter(function (it) { return it.status !== mg.ST.DONE; });
    if (items.length > 0) {
      var it = items[0];
      wx.showModal({
        title: '该给' + it.plantName + it.type + '啦',
        content: '计划时刻 ' + it.planTime + ' · 每 ' + it.intervalDays + ' 天\n（小程序端不发送系统通知，以此弹窗演示；真机通知见鸿蒙端）',
        showCancel: false
      });
    } else {
      wx.showModal({ title: '今天的养护都完成啦', content: '去看看记录页的完成率吧', showCancel: false });
    }
  },

  onClear: function () {
    var that = this;
    wx.showModal({
      title: '清空全部数据？',
      content: '将删除所有植物、养护计划与养护记录，且无法恢复。确定要清空吗？',
      confirmColor: '#C25B5B',
      success: function (res) {
        if (res.confirm) {
          mg.clearAll();
          that.onShow();
          wx.showToast({ title: '已清空全部数据', icon: 'success' });
        }
      }
    });
  }
});
