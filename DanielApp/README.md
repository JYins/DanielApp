# 但以理和他的朋友们 (Daniel & Friends) iOS App

这是一个简洁的圣经经文应用，旨在每日提供灵感。它具有优雅的界面设计、多语言支持（中文、英文、韩文），并包含配套的 iOS 主屏幕和锁屏小组件。

## 项目结构

### 核心文件 & 数据管理
- **`DanielAppApp.swift`**: 应用程序入口点。
- **`MainTabView.swift`**: 管理底部标签栏和三个主要视图 (`ContentView`, `SettingsView`, `ConnectView`) 的切换。
- **`ContentView.swift`**: 主视图，根据设置显示每日经文或用户手动选择的经文。包含交互按钮（切换、固定等）。
- **`SettingsView.swift`**: 用户设置页面，用于配置更新模式（自动/手动）、应用和小组件语言、推送通知等。
- **`ConnectView.swift`**: 提供与社区或开发者联系的链接（如社交媒体）。
- **`VerseData.swift`**: 负责加载和管理来自本地 JSON 文件的经文数据。
- **`SharedModels/`**: 包含共享的数据模型（如 `Verse` 结构体）和工具函数，供主应用和小组件共同使用。
- **`StyleConstants.swift`**: 定义全局样式，如颜色、字体，确保应用和部分小组件视觉一致性。
- **`verses_merged.json`**: 包含完整的圣经经文数据（多语言）。
- **`verse_index_list.json`**: 精选的经文引用列表，用于自动模式下的每日经文选择。

### 小组件 (Widgets) - 位于 `VerseWidgets/` 目录
- **`VerseWidgetBundle.swift`**: Widget 的主入口点 (`@main`)，声明所有可用的小组件类型。
- **`MainVerseWidget.swift`**: 实现主屏幕（Home Screen）小组件，特别是 `.systemLarge` 尺寸，显示带插图的每日/当前经文。
- **`LockScreenVerseWidget.swift`**: 实现锁屏（Lock Screen）小组件（例如 `.accessoryRectangular`, `.accessoryInline` 等），简洁显示经文引用或短句。
- **`VerseWidgetSettingsManager.swift`**: 使用 App Groups 和 UserDefaults 管理应用与小组件之间的共享设置（如语言、当前经文引用）。
- *(需要将 `verses_merged.json` 和 `verse_index_list.json` 也设置为 Widget Target 的成员)*
- *(需要将 `jesus_icon.png` 等资源包含在 Widget Target 中)*

## 设计风格

### 🎨 **颜色方案**:
- **主要背景**: 深蓝色渐变（LinearGradient from `#002366` to `#1E2A5A`）或纯深蓝色 `#002366`。
- **主要文字/标题**: 浅金色 `#D4AF37`，适用于章节引用如 `John 3:16`。
- **正文内容文字**: 更柔和的金米色 `#F5E8B7`，用于圣经经文内容部分。
- **锁屏 Widget 背景**: 使用系统默认半透明材质（Material 背景，无需自定义颜色）。

---

### 🔤 **字体风格**:
- **经文引用（如 John 3:16）**: Serif 字体（推荐 `Georgia` 或 `Times New Roman`）。
- **主要经文内容**: 同样使用 Serif 字体，适当时可切换为更现代的 Sans-serif（如 `San Francisco`）以增强可读性。
- **UI 按钮和设定项**: 使用系统字体 `San Francisco`，简洁现代。

---

### **界面元素布局**:

#### `.systemLarge` Widget 结构：

- **左侧区域 (~35–40%)**:
  - 插图资源：`jesus_icon.png`
  - 尺寸比例：占整个 Widget 宽度约 1/3，等比缩放，不遮挡文字
  - 风格：Q版耶稣插图，带金色光环，温柔微笑、双臂张开
  - 位置：垂直居中，靠左或偏左上

- **右侧区域 (~60–65%)**:
  - **经文内容**：最多显示 2–3 行完整句子，字号 `.title3` 或 `.body`
  - **章节引用**：位于右下角，使用 `.footnote` 字体
  - **排版结构**：`HStack` 左图右文，`VStack` 控制文字布局，文字右对齐或居中
  - **内边距**：左右边距不小于 12pt，避免内容贴边

---

### 资源说明:
- 图像：`jesus_icon.png` 为透明背景 PNG
- 经文数据来源：
 主app里目前展示的哪句

---

### 设计理念:
Widget 风格简约温暖，以「每日灵修」为核心。通过插图陪伴 + 金句启发，打造温柔、敬虔又现代的灵性工具。

## 功能实现

- **多语言经文**: 支持中文 (cn)、英文 (en)、韩文 (kr) 显示，用户可在设置中切换，应用和小组件同步更新语言。
- **数据来源**: 从本地 `verses_merged.json` (全量) 和 `verse_index_list.json` (精选索引) 加载经文。
- **更新模式**:
    - **自动模式**:
        - 每日根据日期从 `verse_index_list.json` 中确定性地选择一条经文（年内尽量不重复）。
        - `ContentView` 显示每日经文，并提供 "Switch Verse"（临时切换到另一随机经文）和 "Set Fixed Verse"（将当前经文固定，暂停每日更新，按钮变为 "Unfix"）功能。
    - **手动模式**:
        - `ContentView` 界面变化，允许用户通过文本输入或 Book/Chapter/Verse 选择器指定经文。
        - 用户选定的经文将固定显示。
- **小组件 (Widgets)**:
    - **主屏幕**: 提供 `.systemLarge` 尺寸的小组件，显示当前（每日、固定或手动选择的）经文、引用和插图，背景为深蓝渐变，文字为浅金色。
    - **锁屏**: 提供适配锁屏的小组件（如矩形、内联），简洁显示当前经文引用。
    - 小组件内容和语言会根据应用内的设置自动更新。
- **推送通知**: （根据设置）可配置为自动发送每日经文或手动触发。
- **社交链接**: 在 `ConnectView` 提供 Instagram、YouTube 等链接。

## 使用指南

1.  打开 App，在第一个标签页 (`ContentView`) 查看当前经文。根据设置中的模式（自动/手动）与经文进行交互（切换、固定、选择）。
2.  前往第二个标签页 (`SettingsView`) 调整应用和小组件的语言、经文更新模式（自动/手动）以及通知设置。
3.  前往第三个标签页 (`ConnectView`) 访问相关社交媒体链接。
4.  在 iOS 主屏幕或锁屏编辑模式下，从 Widget Gallery 中添加 "Daniel & Friends" 的小组件。

---

## 后续开发计划

- 添加完整的圣经阅读功能（按卷、章导航）。
- 增加用户笔记或收藏经文功能。
- 探索社区互动可能性（如分享灵修感悟）。
- 支持更多语言版本。
- 实现应用内经文搜索功能。
- 提供更多小组件尺寸和自定义选项。
- 优化性能和数据加载。