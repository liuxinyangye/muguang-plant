# 沐光 · 植物养护助手

> 基于 HarmonyOS 的植物养护管理应用 —— 养护计划周期提醒、打卡记录与完成率统计

## 项目简介

沐光是一款面向家庭植物养护场景的鸿蒙原生应用。为每一盆植物建立养护计划（浇水 / 施肥 / 修剪 / 换盆，支持自定义类型与周期），应用按周期规则自动生成每日待办，打卡后自动顺延下一次应做日期，并以分组卡片与统计图表呈现养护完成情况。

- **参考 App（A 轨差异化改进）**：多肉花草成长日记（AppGallery C104865253）——差异化定位：面向「怕忘记浇水」的上班族/学生，以「周期提醒 + 养护记录」为核心，界面更轻、交互更简
- **开发模式**：AI + 人工协作开发（WorkBuddy 全程参与需求分析、代码生成、测试与文档；架构与业务规则人工主导，AI 代码人工审查测试后合入）

## 功能特性

- **植物档案管理**：新增 / 编辑 / 归档，记录品种、位置、加入日期
- **养护计划自定义**：预设 4 类 + 自定义类型名（1~8 字，同盆不重复），周期（每 N 天）与提醒时刻可配，每盆最多 10 条
- **周期到期引擎**：按「上次完成日 + 周期天数」自动计算每日待办；植物加入家之前不产生任何任务
- **今日待办**：按植物分组卡片展示，卡片内显示小进度；养护项超过 3 项自动折叠，展开后看全
- **打卡 / 撤销**：点击圆圈即时打卡，当天完成项留在清单显示"已做"，可再点撤销
- **完成率统计**：近 7 / 30 天应做、已完成、漏做与完成率，与清单逐条对得上
- **到点提醒**：进入今日页检查到点未做项，发汇总通知（Notification Kit），全部完成即撤销
- **数据管理**：本地关系型数据库持久化；设置页支持一键清空（二次确认）

## 技术栈

| 项 | 内容 |
|---|---|
| 系统 / 框架 | HarmonyOS（API 26）· ArkTS + ArkUI 声明式 UI |
| 数据存储 | 关系型数据库 RelationalStore（plant / care_plan / care_record 三表） |
| 系统能力 | Notification Kit（到点汇总提醒） |
| 开发工具 | DevEco Studio 26.0.0.851 · Compatible SDK 6.1.1(24) |
| 工程架构 | 分层结构：model（数据层）/ service（业务层）/ views + pages（视图层） |

## 目录结构

```
entry/src/main/ets/
├── common/       Constants · DateUtil · DataVersion · EditTarget
├── model/        Types · DbHelper · PlantDao · RecordDao
├── service/      PlantService · CareService（周期到期规则）· Notifier（通知）
├── views/        TodayView · GardenView · RecordView
├── pages/        Index · PlantEdit · Settings
└── entryability/ EntryAbility（数据库初始化）
```

## 文档

- `AGENTS.md` —— 工程协作说明（AI 协作开发的工作约定）
- `memory-bank/` —— PRD / DESIGN / ARCHITECTURE / DATA_MODEL / TECH_STACK / TASKS / PROGRESS 七份工程文档
- `docs/` —— **web 可交互版**（与 App 同数据模型、同交互逻辑；sm/md/lg 三档断点响应式；localStorage 持久化）

## 三端形态

| 端 | 入口 | 说明 |
|---|---|---|
| HarmonyOS App | DevEco Studio 运行 `entry` | 主交付物，RelationalStore 持久化 + Notification Kit 提醒 |
| 微信小程序 | 微信开发者工具导入 `miniprogram/` | 第二移动端形态：四页面 + wx.Storage，与 App 同数据模型 |
| web 版 | 仓库 `docs/` 目录，已部署 GitHub Pages：https://liu-xinyangye.github.io/muguang-plant | 同一产品的 web 端实现：周期到期规则、打卡、统计口径与 `CareService.ets` 逐行对应；数据存浏览器本地 |

> 注：本仓库同时镜像至 Gitee（https://gitee.com/liu-xinyangye/muguang-plant）。Gitee Pages 已于 2026 年对个人用户停服，故线上部署以 GitHub Pages 为准；代码仓库以 Gitee 为主（国内访问快），两处内容保持一致。

三端共用同一套业务规则：某类养护"应做" ⟺ 不早于植物加入日，且（从未完成 或 最近完成日 + 周期 ≤ 当天）；完成率 = 已做 / 应做，与记录页清单同源。

## 运行方式

1. 用 DevEco Studio 打开本工程
2. 连接真机，或启动模拟器 / 打开预览器
3. `Run > Run 'entry'`

> 数据库不可用的运行环境（如部分预览场景）会自动降级为内存模式，界面功能不受影响。

## 测试

功能测试用例 13 条全部通过，运行期缺陷记录（含三例 ArkUI 渲染机制缺陷的发现与修复）见课程《测试报告》。

## 分支与版本

- 当前版本：v1.0.0（植物养护版，debug 签名包可安装可运行）
- 主分支：`master`
