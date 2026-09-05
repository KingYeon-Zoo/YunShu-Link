# Web 管理后台（manager-web）Kimi 风格视觉重构设计规格

> 参考 [Kimi AI 对话首页](https://www.kimi.com/) 的极简、留白、胶囊化设计语言，以及现代管理系统的侧边栏 + 内容区布局，对 YunShu-Link Web 管理后台进行全面视觉重构。本文档是本轮 redesign 的权威设计规格，目标是在不替换 Element UI 的前提下，让界面更现代、更轻盈、更具高级感，并通过系统化动效提升交互体验。

---

## 1. 项目背景与目标

### 1.1 当前状态

`main/manager-web` 是 YunShu-Link 的 Web 管理后台，技术栈为：

- Vue 2.7
- Element UI 2.15
- Vue Router 3
- Vuex 3
- vue-i18n（支持 zh_CN / zh_TW / en / de / vi / pt_BR）

当前界面仍以 Element UI 默认视觉为主，顶部导航 + 卡片表格的布局较为传统，品牌感与高级感不足，动效较少。

### 1.2 设计目标

1. **借鉴 Kimi 首页**：采用大量留白、居中焦点、胶囊按钮、柔和阴影、极简配色的设计语言。
2. **借鉴管理系统布局**：引入左侧侧边栏 + 顶部迷你工具栏 + 主内容区的经典管理后台结构。
3. **品牌升级**：在保持功能完整的前提下，通过圆角、阴影、字体层级、动效打造高端感。
4. **统一组件**：建立一套覆盖认证页、首页、列表页、详情页的可复用组件与布局框架。
5. **系统化动效**：所有交互元素都有清晰、克制的过渡动画，避免生硬跳转。
6. **最小侵入**：保留 Element UI 组件，通过 SCSS token、全局覆盖和封装层实现视觉升级。

---

## 2. 设计灵感与参考

### 2.1 Kimi AI 对话首页

- **布局**：超大留白，内容居中，视觉焦点集中在一个大型搜索/输入条上。
- **色彩**：几乎纯白背景，黑色 logo，深灰文字，浅灰边框，极低的色彩饱和度。
- **形态**：大圆角输入框（接近药丸形），底部工具按钮，一排胶囊能力标签。
- **动效**：输入框聚焦时轻微放大/发光，按钮悬浮时有细腻反馈。

### 2.2 现代管理系统

- **布局**：左侧固定侧边栏（Logo + 导航菜单 + 用户信息），右侧主内容区滚动。
- **色彩**：浅色侧边栏 `#f7f8fa`，白色内容区，蓝色/黑色作为主操作色。
- **组件**：页面标题栏、搜索过滤栏、白色圆角卡片、数据表格、分页、操作按钮组。
- **动效**：侧边栏折叠展开、卡片悬浮提升、页面切换淡入、表格行 hover 高亮。

### 2.3 融合方向

- 用 Kimi 的极简美学做首页和认证页。
- 用管理系统的侧边栏 + 卡片表格做管理页。
- 全局统一圆角、阴影、间距、动效语言。

---

## 3. 设计原则

| 原则 | 说明 |
|------|------|
| **极简留白** | 大量留白让核心操作更突出，避免信息堆砌。 |
| **居中焦点** | 认证页、首页的核心表单/搜索采用居中构图。 |
| **胶囊形态** | 按钮、标签、搜索框优先使用大圆角或全圆角。 |
| **柔和层级** | 通过浅色背景、细边框、微阴影区分层级，避免重色块。 |
| **细腻动效** | 所有状态变化都有 150–300ms 的过渡，使用 `transform` 和 `opacity`。 |
| **一致 token** | 所有颜色、字号、间距、圆角、阴影统一使用 SCSS token。 |

---

## 4. 范围与阶段

### 4.1 本次范围

| 模块 | 内容 | 说明 |
|------|------|------|
| 设计 Token | `styles/_tokens.scss` | 全新色彩、字体、间距、圆角、阴影、缓动 |
| 全局样式 | `styles/_globals.scss` / `index.scss` | reset、滚动条、工具类、动画工具 |
| Element UI 覆盖 | `styles/_element-override.scss` | 按钮、输入框、表格、分页、标签、弹窗 |
| 布局框架 | `components/AppLayout.vue` | 侧边栏 + 顶部栏 + 主内容区 |
| 侧边栏 | `components/AppSidebar.vue` | Logo、菜单、折叠、用户信息 |
| 顶部栏 | `components/AppTopbar.vue` | 面包屑、页面标题、快捷操作、用户入口 |
| 搜索组件 | `components/SearchBar.vue` | Kimi 风格大圆角搜索条 |
| 统计卡片 | `components/StatCard.vue` | 首页/管理页顶部数据概览 |
| 内容卡片 | `components/ContentCard.vue` | 白色圆角卡片容器 |
| 数据表格 | `components/DataTable.vue` | 封装 Element 表格，统一行高、hover、空态 |
| 过滤栏 | `components/FilterBar.vue` | 搜索 + 筛选 + 主操作按钮组 |
| 操作标签 | `components/ActionPills.vue` | 胶囊形快捷操作标签 |
| 空状态 | `components/EmptyState.vue` | 统一空数据插画与文案 |
| 骨架屏 | `components/SkeletonGrid.vue` | 列表/卡片加载占位 |
| 认证页 | `login.vue` / `register.vue` / `retrievePassword.vue` | 居中极简玻璃卡片 |
| 首页 | `home.vue` | 居中搜索 + 快捷操作 + 统计 + 最近动态 |
| 管理页 | 设备/用户/模型/参数/知识库/服务端/OTA/音色等 | 侧边栏布局 + 卡片表格 |

### 4.2 不在本次范围

- 替换 Element UI 为其他组件库。
- 暗色模式。
- 移动端响应式大规模重构（保持桌面优先，侧边栏可折叠）。
- 后端接口改动。
- 复杂详情页（角色配置、音色克隆等）的深度交互重设计，仅统一视觉外壳。

---

## 5. 设计决策摘要

| 问题 | 决策 |
|------|------|
| 参考风格 | Kimi AI 首页极简美学 + 现代管理系统侧边栏布局 |
| 布局框架 | 左侧固定侧边栏（200–220px）+ 顶部 56px 工具栏 + 主内容区 |
| 主色调 | 黑/白/灰为主，蓝色 `#3375fd` 作为链接与主操作强调色 |
| 字体 | 系统字体栈，中文优先 `PingFang SC` / `Microsoft YaHei` |
| 圆角 | 卡片 12px，输入框 10px，按钮/标签/搜索条 999px（胶囊） |
| 阴影 | 极淡的投影，主要用于卡片悬浮和弹窗 |
| 动效 | 统一 200ms `ease-out`，使用 `transform` 和 `opacity` |

---

## 6. 设计 Token

### 6.1 颜色 Token

```scss
// 背景
$bg-page: #f7f8fa;           // 页面底层背景
$bg-sidebar: #ffffff;        // 侧边栏背景
$bg-card: #ffffff;           // 卡片背景
$bg-hover: #f2f3f5;          // 悬浮背景
$bg-active: #eef2ff;         // 激活/选中背景（淡蓝）

// 文字
$text-primary: #1a1a1a;      // 主标题/正文
$text-secondary: #4b5563;    // 次要文字
$text-tertiary: #9ca3af;     // 辅助/占位文字
$text-disabled: #c1c5cb;     // 禁用文字

// 边框
$border-light: #f3f4f6;      // 极浅分隔线
$border-default: #e5e7eb;    // 默认边框
$border-strong: #d1d5db;     // 聚焦/强边框

// 主色
$color-primary: #3375fd;
$color-primary-soft: #5778ff;
$color-primary-deep: #1d5ee6;
$color-on-primary: #ffffff;

// 强调色
$color-ink: #1a1a1a;         // 黑色主按钮
$color-on-ink: #ffffff;
$color-success: #10b981;
$color-warning: #f59e0b;
$color-danger: #ef4444;

// 阴影
$shadow-card: 0 1px 3px rgba(0, 0, 0, 0.04), 0 4px 12px rgba(0, 0, 0, 0.04);
$shadow-card-hover: 0 4px 12px rgba(0, 0, 0, 0.06), 0 12px 24px rgba(0, 0, 0, 0.06);
$shadow-dialog: 0 8px 30px rgba(0, 0, 0, 0.12);
$shadow-input-focus: 0 0 0 3px rgba(51, 117, 253, 0.12);
```

### 6.2 字体 Token

```scss
$font-family-base: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;

$font-display: 600 40px/1.2 $font-family-base;      // 首页大标题
$font-title: 600 24px/1.3 $font-family-base;         // 页面标题
$font-subtitle: 500 18px/1.4 $font-family-base;      // 卡片标题
$font-body: 400 14px/1.5 $font-family-base;          // 正文
$font-body-bold: 600 14px/1.5 $font-family-base;     // 正文强调
$font-caption: 400 12px/1.5 $font-family-base;       // 辅助文字
```

### 6.3 间距 Token

```scss
$space-xs: 4px;
$space-sm: 8px;
$space-md: 12px;
$space-base: 16px;
$space-lg: 24px;
$space-xl: 32px;
$space-2xl: 48px;
$space-3xl: 64px;

// 布局
$sidebar-width: 220px;
$sidebar-collapsed-width: 64px;
$topbar-height: 56px;
$content-padding: $space-xl;
```

### 6.4 圆角 Token

```scss
$radius-sm: 6px;
$radius-md: 10px;
$radius-lg: 12px;
$radius-xl: 16px;
$radius-pill: 999px;
```

### 6.5 缓动 Token

```scss
$ease-out: cubic-bezier(0.22, 1, 0.36, 1);
$transition-fast: 150ms $ease-out;
$transition-base: 200ms $ease-out;
$transition-slow: 300ms $ease-out;
```

---

## 7. 布局系统

### 7.1 总体框架 `AppLayout.vue`

所有管理页统一使用 `AppLayout` 作为外壳：

```
+------------------------------------------+
| AppSidebar | AppTopbar                   |
|            +------------------------------+
|            | 主内容区（router-view）       |
|            |  ┌──────────────────────┐   |
|            |  │ ContentCard / DataTable|   |
|            |  └──────────────────────┘   |
|            +------------------------------+
+------------------------------------------+
```

**结构**

```vue
<template>
  <div class="app-layout">
    <AppSidebar :collapsed="sidebarCollapsed" @toggle="sidebarCollapsed = !sidebarCollapsed" />
    <div class="app-layout__main" :class="{ 'is-collapsed': sidebarCollapsed }">
      <AppTopbar :title="pageTitle" :breadcrumb="breadcrumb" />
      <main class="app-layout__content">
        <transition name="page-fade" mode="out-in">
          <router-view />
        </transition>
      </main>
    </div>
  </div>
</template>
```

**行为**

- 侧边栏默认展开（220px），点击折叠按钮收起为 64px 图标模式。
- 主内容区宽度 = `100vw - sidebar-width`。
- 内容区可滚动，侧边栏和顶部栏固定。
- 页面切换使用 `page-fade` 过渡动画。

### 7.2 侧边栏 `AppSidebar.vue`

**结构**

- **顶部**：Logo + 品牌名（折叠后仅显示 Logo）。
- **中部**：导航菜单，分组展示。
- **底部**：用户信息（头像 + 名称）、设置/退出、折叠按钮。

**导航分组**

```
概览
  └─ 首页 /home

智能体
  ├─ 智能体管理 /home
  ├─ 角色配置 /role-config
  ├─ 设备管理 /device-management
  └─ 语音印花 /voice-print

系统
  ├─ 模型配置 /model-config
  ├─ 参数管理 /params-management
  ├─ 知识库管理 /knowledge-base-management
  ├─ 服务端管理 /server-side-management
  ├─ OTA 管理 /ota-management
  ├─ 字典管理 /dict-management
  └─ 用户管理 /user-management

高级（根据 featureStatus 显示）
  ├─ 音色克隆 /voice-clone-management
  ├─ 音色资源 /voice-resource-management
  └─ 通讯录 /address-book-management
```

**视觉**

- 背景 `$bg-sidebar`。
- 菜单项：高度 44px，圆角 8px，左右内边距 12px。
- 未选中：黑色图标 + `$text-secondary` 文字。
- 悬浮：背景 `$bg-hover`。
- 选中：背景 `$bg-active`，文字 `$color-primary`，图标主色。
- 折叠后：仅显示图标，悬浮显示 tooltip。

### 7.3 顶部栏 `AppTopbar.vue`

**结构**

- 左侧：面包屑 + 当前页面标题。
- 中部（可选）：全局搜索入口。
- 右侧：通知、语言切换、帮助、用户头像下拉。

**视觉**

- 高度 56px，背景白色，底部 1px `$border-light`。
- 页面标题 18px/600。
- 右侧图标按钮 32px 圆形，悬浮背景 `$bg-hover`。

---

## 8. 组件规范

### 8.1 搜索条 `SearchBar.vue`

**用途**：首页核心搜索、管理页顶部搜索、全局命令入口。

**灵感来源**：Kimi 首页中央大输入条。

**Props**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `placeholder` | `String` | `"搜索..."` | 占位文案 |
| `size` | `'large' | 'default'` | `'default'` | 尺寸 |
| `showTools` | `Boolean` | `true` | 是否显示底部工具区 |
| `clearable` | `Boolean` | `true` | 是否可清空 |

**视觉**

```scss
.search-bar {
  background: $bg-card;
  border: 1px solid $border-default;
  border-radius: $radius-pill;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  transition: border-color $transition-base, box-shadow $transition-base;

  &:hover,
  &:focus-within {
    border-color: $color-primary-soft;
    box-shadow: $shadow-input-focus, 0 4px 12px rgba(0, 0, 0, 0.05);
  }

  &__input {
    border: none;
    background: transparent;
    font-size: 16px;
    padding: $space-md $space-lg;

    &::placeholder {
      color: $text-tertiary;
    }
  }

  &__tools {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: $space-sm $space-md;
    border-top: 1px solid $border-light;
  }
}
```

**大型变体**（首页使用）

- 宽度 680px，居中。
- 输入区高度 72px。
- 字体 18px。

### 8.2 快捷操作标签 `ActionPills.vue`

**用途**：首页能力入口、管理页快捷筛选。

**Props**

| 属性 | 类型 | 说明 |
|------|------|------|
| `items` | `Array<{icon, label, value, color?}>` | 标签列表 |
| `value` | `String / Number` | 当前选中值 |

**视觉**

- 胶囊形按钮，高度 36px。
- 未选中：白底，灰色边框，深灰文字。
- 悬浮：边框变蓝。
- 选中：蓝底或黑底，白色文字。
- 切换时 150ms 背景色过渡。

### 8.3 统计卡片 `StatCard.vue`

**用途**：首页/管理页顶部数据概览。

**Props**

| 属性 | 类型 | 说明 |
|------|------|------|
| `title` | `String` | 指标名称 |
| `value` | `String / Number` | 指标值 |
| `trend` | `Number` | 环比变化（可选） |
| `icon` | `String` | 图标类名 |

**视觉**

- 白色圆角卡片（12px），内边距 20px。
- 左侧/顶部图标，40px 圆形淡蓝背景。
- 数值 28px/600 黑色。
- 趋势正绿负红，胶囊标签展示。

### 8.4 内容卡片 `ContentCard.vue`

**用途**：所有管理页的内容容器。

**Props**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `title` | `String` | `""` | 卡片标题 |
| `subtitle` | `String` | `""` | 副标题 |
| `padding` | `String` | `"24px"` | 内边距 |
| `shadow` | `Boolean` | `true` | 是否显示阴影 |

**视觉**

```scss
.content-card {
  background: $bg-card;
  border-radius: $radius-lg;
  border: 1px solid $border-light;
  box-shadow: $shadow-card;
  overflow: hidden;

  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: $space-lg;
    border-bottom: 1px solid $border-light;
  }

  &__title {
    font: $font-subtitle;
    color: $text-primary;
  }

  &__body {
    padding: $space-lg;
  }
}
```

### 8.5 过滤栏 `FilterBar.vue`

**用途**：管理页顶部搜索 + 筛选 + 主操作按钮组合。

**结构**

```
+--------------------------------------------------+
| [搜索框] [筛选 A ▼] [筛选 B ▼]        [+ 新增]   |
+--------------------------------------------------+
```

**视觉**

- 背景透明，下方与内容卡片保持间距。
- 搜索框为胶囊形，宽度 240px。
- 筛选器使用 `el-select`，圆角 8px。
- 主操作按钮为黑色胶囊（`color-ink`），右侧带 `+` 图标。

### 8.6 数据表格 `DataTable.vue`

**用途**：统一封装 Element UI `el-table`。

**Props**

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `data` | `Array` | `[]` | 数据 |
| `columns` | `Array` | `[]` | 列配置 |
| `loading` | `Boolean` | `false` | 加载状态 |
| `pagination` | `Object` | `null` | 分页配置 |
| `selection` | `Boolean` | `false` | 是否显示多选 |

**视觉**

- 表头背景 `$bg-page`，文字 `$text-secondary`，字体 12px/600，字母大写。
- 行高 56px。
- 行 hover 背景 `$bg-hover`。
- 选中行背景 `$bg-active`。
- 空状态使用 `EmptyState` 组件。
- 分页居右，胶囊形页码。

### 8.7 空状态 `EmptyState.vue`

**用途**：表格/列表无数据时的统一展示。

**视觉**

- 居中布局，插画 + 标题 + 描述 + 可选操作按钮。
- 插画使用轻量级 SVG，色调与品牌一致。
- 标题 16px/500，描述 14px/400 `$text-tertiary`。

### 8.8 骨架屏 `SkeletonGrid.vue` / `SkeletonList.vue`

**用途**：卡片列表/表格加载占位。

**视觉**

- 使用 `el-skeleton` 自定义样式。
- 动画 shimmer 颜色 `$bg-hover`。
- 卡片骨架：圆角 12px，高度 120px。
- 列表骨架：行高 56px，模拟表格行。

---

## 9. 页面设计

### 9.1 认证页（登录 / 注册 / 找回密码）

**设计方向**

- 参考 Kimi 首页：超大留白、居中构图、视觉焦点集中。
- 放弃左右分栏插画，改用纯净背景 + 居中大卡片。

**布局**

```
+----------------------------------+
|                                  |
|         [Logo / 品牌名]           |
|                                  |
|    ┌──────────────────────┐     |
|    │                      │     |
|    │   标题 / 副标题       │     |
|    │                      │     |
|    │   ┌────────────────┐ │     |
|    │   │ 输入框          │ │     |
|    │   └────────────────┘ │     |
|    │   ...                │     |
|    │                      │     |
|    │   [   主按钮   ]     │     |
|    │                      │     |
|    │   辅助链接           │     |
|    │                      │     |
|    └──────────────────────┘     |
|                                  |
|         [语言切换]               |
|                                  |
+----------------------------------+
```

**视觉**

- 背景：极浅灰色 `#f7f8fa` 或纯白，可加入非常淡的动态渐变（可选）。
- 品牌 Logo：顶部居中，48–64px。
- 卡片：白色背景，12px 圆角，柔和阴影，宽度 420px。
- 标题：28px/600 `$text-primary`。
- 副标题：14px/400 `$text-tertiary`。
- 输入框：44px 高，10px 圆角，聚焦时蓝色边框 + 外发光。
- 主按钮：48px 高，全宽，胶囊圆角，黑色背景 `#1a1a1a`，白色文字。
- 辅助链接：14px `$color-primary`。

**动效**

- 页面加载时卡片从下方淡入上移（`translateY(20px) → 0`，400ms）。
- 输入框聚焦时轻微放大或边框发光。
- 按钮悬浮时上移 2px + 阴影加深。

### 9.2 首页 `home.vue`

**设计方向**

- 参考 Kimi 对话首页：中央大搜索条 + 能力标签。
- 同时加入管理系统常见的统计概览与最近动态。

**布局**

```
+------------------------------------------+
| AppSidebar | AppTopbar                   |
|            +------------------------------+
|            | 首页                         |
|            |  ┌──────────────────────┐   |
|            |  │  欢迎语 + 日期        │   |
|            |  └──────────────────────┘   |
|            |                              |
|            |      ┌────────────────┐     |
|            |      │   搜索条        │     |
|            |      │  [工具按钮]      │     |
|            |      └────────────────┘     |
|            |                              |
|            |   [Pill][Pill][Pill]...     |
|            |                              |
|            |  ┌────┐ ┌────┐ ┌────┐      |
|            |  │统计│ │统计│ │统计│      |
|            |  └────┘ └────┘ └────┘      |
|            |                              |
|            |  ┌──────────────────────┐   |
|            |  │ 最近智能体 / 设备      │   |
|            |  └──────────────────────┘   |
|            +------------------------------+
+------------------------------------------+
```

**视觉**

- 主内容区背景 `$bg-page`。
- 欢迎语 24px/600，日期 14px `$text-tertiary`。
- 中央搜索条使用 `SearchBar` 大型变体，宽度 680px。
- 快捷操作标签一排居中展示：添加设备、角色配置、知识库、音色克隆、OTA 等。
- 统计卡片 3–4 列，展示智能体总数、在线设备、今日对话、待处理 OTA 等。
- 最近动态卡片：白色圆角卡片，内部列表展示最近操作或设备。

**动效**

- 进入页面时各区块 staggered fade-up（依次延迟 80ms）。
- 搜索条聚焦时轻微放大。
- 快捷标签 hover 时边框变蓝。
- 统计卡片 hover 时上浮 4px + 阴影加深。

### 9.3 管理列表页（设备 / 用户 / 模型 / 参数等）

**设计方向**

- 标准管理系统布局：侧边栏 + 顶部栏 + 内容卡片 + 数据表格。
- 保持现有功能（搜索、筛选、分页、批量操作、行内操作）。

**布局**

```
+------------------------------------------+
| AppSidebar | AppTopbar                   |
|            |  页面标题 / 面包屑          |
|            +------------------------------+
|            |  [FilterBar]                 |
|            |                              |
|            |  ┌──────────────────────┐   |
|            |  │ ContentCard          │   |
|            |  │  ┌────────────────┐  │   |
|            |  │  │ DataTable      │  │   |
|            |  │  └────────────────┘  │   |
|            |  │  [分页]              │   |
|            |  └──────────────────────┘   |
|            +------------------------------+
+------------------------------------------+
```

**视觉**

- 页面标题 24px/600，面包屑 12px `$text-tertiary`。
- `FilterBar` 位于卡片上方，与卡片间距 16px。
- `ContentCard` 承载表格。
- 表格行 hover 背景 `$bg-hover`。
- 状态标签使用 `el-tag` 但圆角改为 6px。
- 行内操作按钮为文字链接或小型胶囊按钮。

**批量操作**

- 选中行后，表格顶部出现浮动批量操作条（黑色胶囊背景）。
- 包含：全选/取消、批量删除、批量导出等。

### 9.4 详情/配置页（角色配置、知识库详情等）

**设计方向**

- 侧边栏布局 + 表单卡片 + 步骤/标签页。
- 保持现有表单逻辑，仅统一视觉外壳。

**布局**

```
+------------------------------------------+
| AppSidebar | AppTopbar                   |
|            |  页面标题 / 返回 / 保存      |
|            +------------------------------+
|            |  ┌──────────────────────┐   |
|            |  │ ContentCard          │   |
|            |  │  [Form / Tabs]       │   |
|            |  └──────────────────────┘   |
|            +------------------------------+
+------------------------------------------+
```

**视觉**

- 页面标题区右侧放置主要操作按钮（保存、返回）。
- 表单分组使用 12px 圆角白色卡片。
- 表单标签 14px/500 `$text-secondary`。
- 输入框、选择器统一使用 10px 圆角。
- 底部固定操作栏（可选）：保存 + 取消。

---

## 10. 动效规范

### 10.1 通用原则

- 所有动效仅使用 `transform` 和 `opacity`，避免触发重排。
- 统一缓动 `$ease-out`。
- 动画时长控制在 150–400ms 之间，避免拖沓。

### 10.2 页面过渡

```scss
.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 200ms $ease-out, transform 200ms $ease-out;
}

.page-fade-enter,
.page-fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
```

### 10.3 元素进入动画

首页/认证页各区块使用 `fade-up`：

```scss
@keyframes fade-up {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-up {
  animation: fade-up 400ms $ease-out both;
}
```

列表项使用 staggered 进入，每项延迟 40–80ms。

### 10.4 悬浮与焦点

| 元素 | hover / focus 效果 |
|------|-------------------|
| 按钮 | 上移 2px，阴影加深，背景变浅 |
| 卡片 | 上浮 4px，阴影变为 `$shadow-card-hover` |
| 表格行 | 背景变为 `$bg-hover` |
| 菜单项 | 背景变为 `$bg-hover`；选中为 `$bg-active` |
| 输入框 | 边框变蓝，外发光 `$shadow-input-focus` |
| 图标按钮 | 背景变为 `$bg-hover`，缩放 1.05 |

### 10.5 加载状态

- 表格/列表加载时使用骨架屏，shimmer 动画。
- 按钮 loading 状态使用 `el-button` 自带 loading，但颜色保持主题。
- 页面初始加载可显示全屏 Logo + 进度条（可选）。

### 10.6 侧边栏折叠

```scss
.app-sidebar {
  transition: width $transition-slow $ease-out;
}
```

折叠时图标居中，tooltip 延迟显示。

---

## 11. Element UI 覆盖策略

在 `styles/_element-override.scss` 中统一覆盖：

```scss
// 按钮：统一圆角与字重
.el-button {
  border-radius: $radius-pill !important;
  font-weight: 600;

  &--primary {
    background-color: $color-ink;
    border-color: $color-ink;

    &:hover {
      background-color: lighten($color-ink, 15%);
      border-color: lighten($color-ink, 15%);
    }
  }
}

// 输入框
.el-input__inner {
  height: 44px;
  border-radius: $radius-md;
  border-color: $border-default;

  &:focus {
    border-color: $color-primary;
    box-shadow: $shadow-input-focus;
  }
}

// 表格
.el-table {
  th {
    background-color: $bg-page;
    color: $text-secondary;
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
  }

  tr:hover > td {
    background-color: $bg-hover !important;
  }
}

// 分页
.el-pagination {
  .el-pager li {
    border-radius: $radius-pill;

    &.active {
      background-color: $color-ink;
      color: $color-on-ink;
    }
  }
}

// 标签
.el-tag {
  border-radius: 6px;
}

// 弹窗
.el-dialog {
  border-radius: $radius-lg;
  box-shadow: $shadow-dialog;
}
```

---

## 12. 响应式与可访问性

### 12.1 断点

- 桌面优先，默认最小宽度 1200px。
- 侧边栏在 1280px 以下可自动折叠为图标模式。
- 小屏保持横向滚动，不做移动端适配。

### 12.2 触控目标

- 按钮高度 ≥ 36px，主按钮 ≥ 44px。
- 侧边栏菜单项高度 44px。
- 表格行内操作按钮间距 ≥ 8px。

### 12.3 对比度

- 主文字 `#1a1a1a` 在白色背景满足 WCAG AA。
- 辅助文字 `#4b5563`、占位文字 `#9ca3af` 分级使用。

### 12.4 动画降级

- `prefers-reduced-motion` 下禁用所有非必要动画。
- 保持功能可用，仅去除位移/透明度过渡。

---

## 13. 文件结构

```
main/manager-web/src/
├── styles/
│   ├── _tokens.scss           # 色彩 / 字体 / 间距 / 圆角 / 阴影 / 缓动
│   ├── _globals.scss          # reset、滚动条、动画工具类
│   ├── _element-override.scss # Element UI 主题覆盖
│   └── index.scss             # 统一入口
├── components/
│   ├── AppLayout.vue          # 侧边栏 + 顶部栏 + 主内容区框架
│   ├── AppSidebar.vue         # 侧边栏导航
│   ├── AppTopbar.vue          # 顶部工具栏
│   ├── SearchBar.vue          # Kimi 风格搜索条
│   ├── ActionPills.vue        # 胶囊快捷标签
│   ├── StatCard.vue           # 统计卡片
│   ├── ContentCard.vue        # 内容卡片容器
│   ├── FilterBar.vue          # 搜索筛选操作栏
│   ├── DataTable.vue          # 封装数据表格
│   ├── EmptyState.vue         # 空状态
│   ├── SkeletonGrid.vue       # 卡片骨架屏
│   └── SkeletonList.vue       # 列表骨架屏
├── views/
│   ├── login.vue              # 登录页（居中极简）
│   ├── register.vue           # 注册页（居中极简）
│   ├── retrievePassword.vue   # 找回密码页（居中极简）
│   ├── home.vue               # 首页（Kimi 风格指挥中心）
│   ├── DeviceManagement.vue   # 设备管理（侧边栏 + 表格）
│   ├── UserManagement.vue     # 用户管理
│   ├── ModelConfig.vue        # 模型配置
│   ├── ParamsManagement.vue   # 参数管理
│   ├── KnowledgeBaseManagement.vue
│   ├── ServerSideManager.vue
│   ├── OtaManagement.vue
│   ├── VoiceCloneManagement.vue
│   ├── VoiceResourceManagement.vue
│   └── DictManagement.vue
├── App.vue
└── main.js                    # 引入 styles/index.scss
```

---

## 14. 分阶段实施计划

### 第一阶段：基础设施（1–2 天）

1. 更新 `styles/_tokens.scss` 为 Kimi 风格配色与圆角。
2. 重写 `styles/_globals.scss` 和 `_element-override.scss`。
3. 在 `main.js` 中确认 `index.scss` 引入顺序正确。
4. 创建 `AppLayout.vue`、`AppSidebar.vue`、`AppTopbar.vue`。

### 第二阶段：公共组件（2–3 天）

1. 实现 `SearchBar`、`ActionPills`、`StatCard`、`ContentCard`。
2. 实现 `FilterBar`、`DataTable`、`EmptyState`、骨架屏组件。
3. 为所有管理页统一套用 `AppLayout` + `ContentCard` + `FilterBar` + `DataTable`。

### 第三阶段：核心页面（2–3 天）

1. 重构 `login.vue` / `register.vue` / `retrievePassword.vue` 为居中极简卡片。
2. 重构 `home.vue` 为 Kimi 风格指挥中心。
3. 统一首页/管理页动效。

### 第四阶段：回归与验证（1–2 天）

1. 运行 `npm run serve`，逐页检查视觉一致性。
2. 运行 `npm run build`，确认构建无报错。
3. 验证 6 种语言切换下的布局与文案。
4. 验证 `prefers-reduced-motion` 与旧版浏览器降级。

---

## 15. 测试策略

1. **视觉回归**：对登录页、首页、设备管理页做前后截图对比。
2. **功能回归**：登录、注册、找回密码、首页搜索、新增/编辑/删除设备、分页、筛选、批量操作。
3. **交互测试**：按钮悬浮、卡片悬浮、输入框聚焦、侧边栏折叠、页面切换动画。
4. **构建验证**：`npm run build` 无样式或资源错误。
5. **多语言验证**：切换 6 种语言，检查布局是否错乱。
6. **无障碍验证**：`prefers-reduced-motion` 下动画停止，键盘可操作导航。

---

## 16. 风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| Element UI 默认样式与 Kimi 风格冲突 | 中 | 通过 `_element-override.scss` + `::v-deep` 系统性覆盖 |
| 管理页数量多，统一改造成本高 | 中 | 先完成 `AppLayout` + `ContentCard` + `DataTable` 封装，再批量替换 |
| 侧边栏折叠后 tooltip 体验不佳 | 低 | 使用 `el-tooltip`，延迟显示，确保可访问 |
| 动画在低配设备卡顿 | 低 | 使用 `transform`/`opacity`，提供 `prefers-reduced-motion` 降级 |
| 多语言文案长度导致布局错乱 | 中 | 关键区域预留弹性宽度，按钮使用 `min-width` |
| 旧用户不适应新布局 | 低 | 保持核心交互路径不变，仅视觉与动效升级 |

---

## 17. 修订记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-07-15 | v2.0 | 参考 Kimi AI 首页与现代管理系统布局，重新组织页面组件布局，新增系统化动效与组件规范 |
