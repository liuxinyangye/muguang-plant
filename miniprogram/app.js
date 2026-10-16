// 沐光小程序入口：启动时初始化数据层（无数据则写演示种子）
require('./utils/mg.js');

App({
  onLaunch: function () {
    // 数据层在 require 时已完成初始化（load or seed）
  }
});
