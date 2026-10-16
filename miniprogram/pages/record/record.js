// 记录页：近 7/30 天完成率 + 按日分组明细
var mg = require('../../utils/mg.js');

Page({
  data: {
    days: 7,
    rate: 0,
    total: 0,
    done: 0,
    missed: 0,
    groups: [],
    checkins: 0,
    topType: '—',
    topPlant: '—',
    streak: 0
  },

  onShow: function () {
    this.refresh();
  },

  refresh: function () {
    var days = this.data.days;
    var a = mg.adherence(days);
    var ov = mg.overview();
    var groups = mg.groupsOf(days).map(function (g) {
      return {
        date: g.date,
        dateLabel: mg.fmtDateCN(g.date) + ' ' + mg.relLabel(g.date) + ' · ' + g.doneCount + '/' + g.totalCount,
        items: g.items.map(function (it) {
          var plant = mg.plantById(it.plantId) || { name: it.plantName };
          var rec = null;
          mg.state().records.forEach(function (x) {
            if (x.plantId === it.plantId && x.type === it.type && x.planDate === g.date) { rec = x; }
          });
          return {
            key: it.plantId + '-' + it.type,
            plantId: it.plantId,
            name: plant.name,
            emoji: mg.emojiFor(plant),
            type: it.type,
            intervalDays: it.intervalDays,
            planTime: it.planTime,
            passed: it.passed,
            status: it.status,
            time: it.status === mg.ST.DONE && rec ? mg.fmtTime(rec.doneAt) : it.planTime
          };
        })
      };
    });
    this.setData({
      rate: a.rate, total: a.total, done: a.done, missed: a.missed,
      groups: groups,
      checkins: ov.checkins, topType: ov.topType, topPlant: ov.topPlant, streak: ov.streak
    });
  },

  onSeg: function (e) {
    this.setData({ days: +e.currentTarget.dataset.days });
    this.refresh();
  }
});
