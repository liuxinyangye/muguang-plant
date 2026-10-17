// 沐光小程序入口：启动时初始化数据层（无数据则写演示种子）
require('./utils/mg.js');

App({
  // 跨页面信号：今日页空状态点「添加第一盆植物」时置 true，
  // 花园页 onShow 检测到后自动弹出添加弹层（一步到位，无需再点「＋ 添加」）
  globalData: {
    pendingAddPlant: false
  },

  onLaunch: function () {
    // 数据层在 require 时已完成初始化（load or seed）
  }
});
