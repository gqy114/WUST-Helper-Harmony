# WUST Helper · HarmonyOS 版
![](https://img.shields.io/badge/Platform-HarmonyOS-0A59F7?logo=harmonyos&logoColor=white)
![](https://img.shields.io/badge/Language-ArkTS%2FTypeScript-3178C6?logo=typescript&logoColor=white)
![](https://img.shields.io/badge/DevEco%20Studio-5.0+-black?logo=harmonyos&logoColor=white)
![](https://img.shields.io/badge/License-MIT-green)
武汉科技大学校园助手 —— 基于鸿蒙（HarmonyOS）开发的校园服务 App。

> 📱 为武科大学生打造的一站式校园工具，课程表、成绩查询、空教室、校园资讯，一个 App 搞定。

---

## ✨ 功能特性

- 📚 **课程表**：自动导入本学期课表，支持周次切换、课程提醒
- 📊 **成绩查询**：对接教务系统，随时查看期末成绩与绩点
- 🏫 **空教室查询**：实时查看教学楼空闲教室，自习找座更方便
- 📰 **校园资讯**：校内通知、教务处公告聚合推送
- 🎨 **原生鸿蒙体验**：基于 ArkTS 开发，流畅的动效与深色模式支持

---

## 🛠 技术栈

| 类别 | 技术 |
|------|------|
| 开发框架 | HarmonyOS Stage Model |
| 开发语言 | ArkTS / TypeScript |
| 构建工具 | HVigor |
| 开发工具 | DevEco Studio |

---

## 📂 项目结构

WustHelper/
├── AppScope/              # 应用全局配置
├── entry/                 # 主模块
│   └── src/main/
│       ├── ets/           # ArkTS 源码
│       ├── resources/    # 字符串、颜色、图片资源
│       └── mock/          # Mock 测试数据
├── build-profile.json5    # 工程编译配置
├── hvigorfile.ts          # 构建脚本
└── oh-package.json5       # 依赖管理

---

## 🚀 开发环境要求

1. **DevEco Studio**：建议 5.0 及以上版本
2. **HarmonyOS SDK**：API 12 及以上
3. 配置好鸿蒙开发环境与签名

### 本地运行

```bash
# 克隆项目
git clone https://github.com/gqy114/WUST-Helper-Harmony.git

# 用 DevEco Studio 打开项目根目录
# 等待依赖下载完成后，点击 Run 即可运行到模拟器/真机
