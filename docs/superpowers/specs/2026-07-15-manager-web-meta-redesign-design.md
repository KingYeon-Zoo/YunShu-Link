# Web 管理后台（manager-web）Meta 设计语言视觉重构设计规格

> 基于 `main/manager-web/DESIGN-meta.md` 的设计系统，对现有管理后台进行“借鉴适配”式视觉重构。本文档替代/补充 2026-07-14 的 Kimi 玻璃拟态方案，方向更贴近 Meta 的电商/硬件产品视觉语言。

---

## 1. 项目背景与目标

### 1.1 当前状态

`main/manager-web` 是 YunShu-Link 的 Web 管理后台，技术栈为：

- Vue 2.6
- Element UI 2.15
- Vue Router 3
- Vuex 3
- vue-i18n（支持 zh_CN / zh_TW / en / de / vi / pt_BR）

现有界面采用 Element UI 默认风格，顶部导航（`HeaderBar.vue`）、卡片/表格布局，配色以蓝紫渐变为主，组件样式较为传统，缺少统一的现代视觉语言。

### 1.2 设计目标

参考 `DESIGN-meta.md` 中 Meta 的设计系统，对 Web 管理后台进行视觉重构：

1. **借鉴适配**：保留 Element UI 组件，不引入新的组件库或大规模重写。
2. **核心页面优先**：登录页、首页、顶部导航、通用组件优先改造；管理表格页仅继承全局 token，不改动布局。
3. **品牌蓝调**：在 Meta 的形态语言（胶囊按钮、大圆角、开阔留白）基础上，保留现有品牌蓝色系。
4. **浅色唯一**：本次仅支持浅色模式，不引入暗色 token。
5. **动态背景**：登录页使用大胆流动的极光渐变背景；管理页使用极淡的全局动态背景；内容卡片采用玻璃亚克力模糊，确保文字可读。
6. **最小侵入**：通过 SCSS token + Element UI 变量覆盖实现，降低迁移风险和开发周期。

---

## 2. 范围与阶段

### 2.1 本次范围

| 模块 | 内容 | 说明 |
|------|------|------|
| 设计 Token | `styles/_tokens.scss` | 颜色、字体、圆角、间距、阴影 |
| Element UI 主题覆盖 | `styles/_element-override.scss` | 按钮、输入框、弹窗、表格、分页等 |
| 全局样式 | `styles/_global.scss` / `index.scss` | 字体、滚动条、autofill、工具类 |
| 登录页 | `views/login.vue` | 视觉重构：白底大圆角卡片、胶囊按钮 |
| 首页 | `views/home.vue` | 视觉重构：大圆角卡片、开阔留白、胶囊搜索 |
| 顶部导航 | `components/HeaderBar.vue` | 胶囊 tab、白色背景、简化视觉 |
| 通用组件 | `CustomButton.vue`、`CustomDialog.vue` 等 | 统一按钮、弹窗形态 |
| 玻璃卡片 | `GlassCard.vue` | 全局复用的亚克力模糊卡片容器 |
| 动态背景 | `DynamicBackground.vue` | 登录页/管理页动态极光渐变背景 |
| 管理列表页 | 设备/用户/模型/OTA/字典/参数等 | 不动布局，继承全局 token、表格样式和玻璃卡片 |

### 2.2 不在本次范围

- 替换 Element UI 为其他组件库。
- 暗色模式。
- 复杂配置/详情页（角色配置、知识库、音色克隆等）的深度视觉重绘，仅继承全局 token。
- 移动端响应式大规模重构（保持现有 `min-width: 900px` 桌面优先）。
- 后端接口改动。

---

## 3. 设计决策摘要

| 问题 | 决策 |
|------|------|
| 改造哪些前端项目？ | 仅 `manager-web`（Web 管理后台） |
| 参考设计系统？ | `main/manager-web/DESIGN-meta.md`（Meta 设计系统） |
| 实现策略？ | 借鉴适配：保留 Element UI，用 SCSS token 和全局覆盖引入 Meta 视觉语言 |
| 范围？ | 核心页面（登录、首页、导航、通用组件）；表格页只改全局 token |
| 主色方向？ | 品牌蓝调：保留 #3375fd / #5778ff，形态贴近 Meta |
| 字体？ | Inter + Noto Sans SC |
| 颜色模式？ | 仅浅色模式 |
| 圆角风格？ | 胶囊按钮（100px）、大卡片 32px、输入框 8px |
| 动态背景？ | 极光渐变流动，登录页鲜明，管理页 subtle |
| 卡片质感？ | 玻璃亚克力模糊，保证动态背景下的可读性 |

---

## 4. 设计 Token

### 4.1 颜色 Token

```scss
// 品牌主色（保留现有蓝色，向 Meta 钴蓝靠近）
$color-primary: #3375fd;
$color-primary-soft: #5778ff;
$color-primary-deep: #0064e0;
$color-on-primary: #ffffff;

// 强调与按钮
$color-ink-button: #000000;
$color-on-ink-button: #ffffff;

// 背景与表面
$color-canvas: #ffffff;
$color-surface-soft: #f1f4f7;

// 玻璃亚克力
$color-glass-bg: rgba(255, 255, 255, 0.72);
$color-glass-bg-hover: rgba(255, 255, 255, 0.85);
$color-glass-border: rgba(255, 255, 255, 0.6);
$color-glass-border-strong: rgba(255, 255, 255, 0.85);
$glass-blur: 16px;

// 文字
$color-ink-deep: #0a1317;
$color-ink: #1c1e21;
$color-charcoal: #444950;
$color-slate: #4b4c4f;
$color-steel: #5d6c7b;
$color-stone: #8595a4;

// 边框与分隔
$color-hairline: #ced0d4;
$color-hairline-soft: #dee3e9;
$color-disabled-text: #bcc0c4;

// 语义色
$color-success: #31a24c;
$color-attention: #f2a918;
$color-warning: #f7b928;
$color-critical: #e41e3f;
$color-critical-strong: #f0284a;
```

### 4.2 字体 Token

```scss
$font-family-base: "Inter", "Noto Sans SC", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;

// 字号 / 字重 / 行高
$font-display-lg: 500 48px/1.17 $font-family-base;      // 登录页大标题
$font-heading-lg: 500 36px/1.28 $font-family-base;      // 首页欢迎语
$font-heading-sm: 500 24px/1.25 $font-family-base;      // 卡片标题
$font-subtitle-lg: 700 18px/1.44 $font-family-base;     // 弹窗标题 / FAQ 问题
$font-body-md: 400 16px/1.5 $font-family-base;          // 正文
$font-body-md-bold: 700 16px/1.5 $font-family-base;     // 正文强调
$font-body-sm: 400 14px/1.43 $font-family-base;         // 辅助文字 / 按钮
$font-body-sm-bold: 700 14px/1.43 $font-family-base;    // 按钮 / 小标题
$font-caption: 400 12px/1.33 $font-family-base;         // 标签 / 时间戳
$font-caption-bold: 700 12px/1.33 $font-family-base;    // 徽标
```

### 4.3 间距 Token

```scss
$spacing-xxs: 4px;
$spacing-xs: 8px;
$spacing-sm: 10px;
$spacing-md: 12px;
$spacing-base: 16px;
$spacing-lg: 20px;
$spacing-xl: 24px;
$spacing-xxl: 32px;
$spacing-xxxl: 40px;
$spacing-section-sm: 48px;
$spacing-section: 64px;
$spacing-section-lg: 80px;
```

### 4.4 圆角 Token

```scss
$rounded-xs: 2px;
$rounded-sm: 4px;
$rounded-md: 6px;
$rounded-lg: 8px;
$rounded-xl: 16px;
$rounded-xxl: 24px;
$rounded-xxxl: 32px;
$rounded-full: 100px;
$rounded-circle: 50%;
```

### 4.5 阴影 Token

```scss
$shadow-flat: none;
$shadow-subtle: rgba(0, 0, 0, 0.2) 1px 1px 0px 0px;
$shadow-sticky: rgba(20, 22, 26, 0.3) 0px 1px 4px 0px;
$shadow-dialog: 0 4px 24px rgba(0, 0, 0, 0.12);
```

---

## 5. 文件结构

```
main/manager-web/src/
├── styles/
│   ├── _tokens.scss          # 颜色 / 字体 / 间距 / 圆角 / 阴影 token
│   ├── _element-override.scss # Element UI 变量覆盖与全局覆盖
│   ├── _global.scss          # 全局工具样式、滚动条、autofill
│   └── index.scss            # 统一入口，在 main.js 引入
├── views/
│   ├── login.vue             # 登录页视觉重构
│   ├── home.vue              # 首页视觉重构
│   └── *.vue                 # 表格页继承全局 token，不动布局
├── components/
│   ├── HeaderBar.vue           # 顶部导航视觉重构（若当前版本已移除，可跳过）
│   ├── DynamicBackground.vue   # 登录页/管理页动态极光背景
│   ├── GlassCard.vue           # 玻璃亚克力卡片容器
│   ├── CustomButton.vue        # 可选：统一按钮封装
│   └── CustomDialog.vue        # 弹窗圆角/间距统一
└── App.vue                     # 全局字体、背景、公共样式
```

---

## 6. Element UI 主题覆盖策略

### 6.1 覆盖方式

1. **SCSS 变量覆盖**：在 `_element-override.scss` 中重新定义 Element UI 的 SCSS 变量（如 `$--color-primary`）。
2. **全局选择器覆盖**：对 Element UI 生成的 DOM 结构使用全局 CSS 覆盖圆角、间距、阴影。
3. **Scoped 深度覆盖**：在个别组件中使用 `:deep()` 处理特殊场景。

### 6.2 关键覆盖项

| Element 组件 | 覆盖内容 |
|-------------|---------|
| `el-button` | 所有按钮圆角改为 `$rounded-full`；primary 背景 `$color-primary`；large 按钮高度 44px |
| `el-input` | 高度 44px，圆角 `$rounded-lg`，边框 `$color-hairline`，focus 边框 `$color-primary-soft` |
| `el-dialog` | 圆角 `$rounded-xxl`（24px），标题 18px/700，底部按钮右对齐 |
| `el-card` | 圆角 `$rounded-xxxl`（32px），边框 `$color-hairline-soft`，默认无阴影 |
| `el-table` | 表头文字 14px/700，行高 48px，hover 背景 `$color-surface-soft` |
| `el-pagination` | 按钮圆角 `$rounded-full`，active 背景 `$color-primary` |
| `el-dropdown` / `el-select` | 圆角 `$rounded-lg`，选项 hover 背景 `$color-surface-soft` |
| `el-message` | 顶部偏移 70px，圆角 `$rounded-xl` |

---

## 7. 组件规范

### 7.1 按钮 Button

**Primary（主要操作）**

```scss
background: $color-primary;
color: $color-on-primary;
border-radius: $rounded-full;
padding: 14px 30px;
font: $font-body-sm-bold;
height: 44px;

&:hover { background: lighten($color-primary, 6%); }
&:active { background: $color-primary-deep; }
&:disabled { background: $color-disabled-text; }
```

**Secondary（次要操作）**

```scss
background: transparent;
color: $color-ink-deep;
border: 2px solid $color-ink-deep;
border-radius: $rounded-full;
padding: 12px 28px;
font: $font-body-sm-bold;
```

**Ghost（低优先级）**

```scss
background: transparent;
color: $color-ink-deep;
border: 2px solid rgba(10, 19, 23, 0.12);
border-radius: $rounded-full;
padding: 10px 22px;
font: $font-body-sm-bold;
```

### 7.2 输入框 Input

```scss
height: 44px;
background: $color-canvas;
color: $color-ink;
border: 1px solid $color-hairline;
border-radius: $rounded-lg;
padding: $spacing-md;
font: $font-body-md;

&:focus { border: 2px solid $color-primary-soft; }
&.error { border: 1px solid $color-critical-strong; }
```

### 7.3 卡片 Card

所有内容卡片统一采用玻璃亚克力质感，以在动态背景下保持文字清晰可读。

**大卡片（设备卡片、首页区块）**

```scss
background: $color-glass-bg;
backdrop-filter: blur($glass-blur);
-webkit-backdrop-filter: blur($glass-blur);
border-radius: $rounded-xxxl; // 32px
padding: $spacing-xxl; // 32px
border: 1px solid $color-glass-border;
box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);

transition: background 0.2s ease, box-shadow 0.2s ease;

&:hover {
  background: $color-glass-bg-hover;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
}
```

**小卡片（特性/信息块）**

```scss
background: $color-glass-bg;
backdrop-filter: blur($glass-blur);
border-radius: $rounded-xl; // 16px
padding: $spacing-xl; // 24px
border: 1px solid $color-glass-border;
```

**降级处理**

对于不支持 `backdrop-filter` 的浏览器，使用纯白背景替代：

```scss
@supports not (backdrop-filter: blur($glass-blur)) {
  .glass-card {
    background: $color-canvas;
  }
}
```

### 7.4 弹窗 Dialog

```scss
background: $color-glass-bg;
backdrop-filter: blur($glass-blur);
border-radius: $rounded-xxl; // 24px
padding: $spacing-xl;
box-shadow: $shadow-dialog;
border: 1px solid $color-glass-border-strong;

.title { font: $font-subtitle-lg; color: $color-ink-deep; }
.footer { display: flex; justify-content: flex-end; gap: $spacing-base; }
```

### 7.5 表格 Table

表格页不动布局，仅继承全局 token：

```scss
.el-table {
  th { font: $font-body-sm-bold; color: $color-ink; background: $color-surface-soft; }
  td { height: 48px; color: $color-charcoal; }
  tr:hover td { background: $color-surface-soft; }
}
```

### 7.6 徽标 Badge

```scss
border-radius: $rounded-full;
padding: 4px 10px;
font: $font-caption-bold;

&.success { background: $color-success; color: $color-on-primary; }
&.warning { background: $color-warning; color: $color-ink-deep; }
&.critical { background: $color-critical; color: $color-on-primary; }
```

---

## 7.7 动态背景系统 DynamicBackground

### 7.7.1 设计原则

- **纯 CSS 实现**：使用 `linear-gradient` + `animation` + `filter: blur()`，不引入 Canvas/WebGL，保证性能。
- **分层渲染**：底层渐变流动 + 中层模糊色块浮动 + 顶层玻璃卡片。
- **两档强度**：登录页鲜明流动，管理页极淡 subtle。
- **可降级**：支持 `prefers-reduced-motion` 和 `backdrop-filter` 降级。

### 7.7.2 登录页背景（鲜明）

```scss
.login-background {
  position: fixed;
  inset: 0;
  z-index: 0;
  background: linear-gradient(
    135deg,
    #e0e6fd 0%,
    #cce7ff 25%,
    #d3d3fe 50%,
    #e0e6fd 75%,
    #cce7ff 100%
  );
  background-size: 400% 400%;
  animation: aurora-flow 10s ease infinite;

  .blob {
    position: absolute;
    border-radius: 50%;
    filter: blur(50px);
    opacity: 0.3;
    animation: blob-float 12s ease-in-out infinite;
  }

  .blob-1 {
    width: 400px;
    height: 400px;
    background: rgba(51, 117, 253, 0.35);
    top: -100px;
    left: -100px;
  }

  .blob-2 {
    width: 350px;
    height: 350px;
    background: rgba(87, 120, 255, 0.3);
    bottom: -80px;
    right: -80px;
    animation-delay: -4s;
  }
}

@keyframes aurora-flow {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

@keyframes blob-float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(60px, -60px) scale(1.1); }
  66% { transform: translate(-40px, 40px) scale(0.95); }
}
```

### 7.7.3 管理页背景（subtle）

```scss
.mgmt-background {
  position: fixed;
  inset: 0;
  z-index: 0;
  background: linear-gradient(
    135deg,
    #ffffff 0%,
    #f1f4f7 50%,
    #ffffff 100%
  );
  background-size: 300% 300%;
  animation: aurora-flow 20s ease infinite;

  .blob {
    position: absolute;
    border-radius: 50%;
    filter: blur(60px);
    opacity: 0.06;
    animation: blob-float 25s ease-in-out infinite;
  }

  .blob-1 {
    width: 500px;
    height: 500px;
    background: rgba(51, 117, 253, 0.5);
    top: -150px;
    right: -150px;
  }

  .blob-2 {
    width: 400px;
    height: 400px;
    background: rgba(87, 120, 255, 0.4);
    bottom: -100px;
    left: -100px;
    animation-delay: -8s;
  }
}
```

### 7.7.4 组件封装

```vue
<!-- components/DynamicBackground.vue -->
<template>
  <div class="dynamic-background" :class="`dynamic-background--${variant}`">
    <div class="blob blob-1"></div>
    <div class="blob blob-2"></div>
    <div class="blob blob-3" v-if="variant === 'login'"></div>
  </div>
</template>

<script>
export default {
  name: 'DynamicBackground',
  props: {
    variant: {
      type: String,
      default: 'management', // 'login' | 'management'
      validator: value => ['login', 'management'].includes(value)
    }
  }
}
</script>
```

### 7.7.5 无障碍与性能

```scss
@media (prefers-reduced-motion: reduce) {
  .dynamic-background,
  .dynamic-background .blob {
    animation: none;
  }
}
```

- 动画仅使用 `transform`、`opacity`、`background-position`，不触发重排。
- 色块使用 `filter: blur()` 生成柔和边缘，避免使用大量 DOM 节点。
- 背景层 `z-index: 0`，内容层 `z-index: 1` 及以上，确保事件正常响应。

---

## 8. 页面设计

### 8.1 登录页 `login.vue`

#### 8.1.1 结构

保留现有左右分栏或居中卡片布局，在底层叠加动态极光背景：

- 底层：`<DynamicBackground variant="login" />` 全屏固定。
- 左侧：可保留现有人物插画，或简化为品牌 Logo + 大标题。
- 右侧：登录表单改为玻璃亚克力大圆角卡片。

#### 8.1.2 登录卡片

```scss
.login-card {
  position: relative;
  z-index: 1;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border-radius: $rounded-xxxl; // 32px
  padding: $spacing-xxl;
  border: 1px solid $color-glass-border-strong;
  box-shadow: $shadow-dialog;
}
```

#### 8.1.3 元素规格

- 页面大标题：48px/500，颜色 `$color-ink-deep`
- 副标题：16px/400，颜色 `$color-steel`
- 输入框：高度 44px，圆角 8px
- 登录按钮：primary，胶囊，宽度 100%
- 链接：16px/700，`$color-primary-soft`
- 语言切换：保持现有下拉，样式改为胶囊形选择器

### 8.2 首页 `home.vue`

#### 8.2.1 结构

```
+----------------------------------+
| 动态背景（subtle）                |
+----------------------------------+
| 顶部导航 HeaderBar（若存在）      |
+----------------------------------+
| Hero 区（问候 + 搜索 + 添加）     |
+----------------------------------+
| 智能体卡片网格                    |
+----------------------------------+
| Footer                            |
+----------------------------------+
```

- 底层：`<DynamicBackground variant="management" />` 全屏固定。
- 所有内容卡片使用玻璃亚克力质感。

#### 8.2.2 Hero 区

```scss
.hero {
  position: relative;
  z-index: 1;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  border-radius: $rounded-xxxl;
  border: 1px solid $color-glass-border;
  padding: $spacing-section;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
}

.hero-title { font: $font-heading-lg; color: $color-ink-deep; }
.hero-hint { font: $font-body-sm; color: $color-steel; }
```

取消原蓝紫渐变横幅，改用玻璃亚克力大圆角卡片 + 品牌蓝按钮。

#### 8.2.3 搜索框

```scss
.search-pill {
  background: rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(8px);
  border-radius: $rounded-full;
  height: 40px;
  padding: $spacing-md $spacing-lg;
  color: $color-steel;
  border: 1px solid $color-glass-border;
}
```

#### 8.2.4 设备卡片

```scss
.device-card {
  position: relative;
  z-index: 1;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  border-radius: $rounded-xxxl;
  border: 1px solid $color-glass-border;
  padding: $spacing-xxl;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  transition: background 0.2s ease, box-shadow 0.2s ease;

  &:hover {
    background: $color-glass-bg-hover;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
  }
}
```

卡片内部：名称（18px/700）+ 状态徽标 + 辅助信息（14px/400，`$color-steel`）+ 操作按钮（ghost 或 link）。

### 8.3 顶部导航 `HeaderBar.vue`

> **注意**：若当前版本已移除顶部导航，本章节可跳过。

#### 8.3.1 结构

```scss
.header {
  background: $color-canvas;
  border-bottom: 1px solid $color-hairline-soft;
  height: 64px;
}
```

#### 8.3.2 导航 Tab

```scss
.nav-pill {
  background: $color-canvas;
  border: 1px solid $color-hairline;
  border-radius: $rounded-full;
  padding: 8px 16px;
  font: $font-body-sm-bold;
  color: $color-ink;

  &.active {
    background: $color-ink-deep;
    color: $color-canvas;
    border-color: transparent;
  }
}
```

取消原蓝紫渐变背景和发光 active 态，改为白色底 + 胶囊 tab。

#### 8.3.3 用户区

- 头像：40px 圆形
- 用户名：14px/400，`$color-ink`
- 下拉菜单：圆角 16px，选项 hover 背景 `$color-surface-soft`

---

## 9. 响应式与可访问性

### 9.1 断点

保持现有桌面优先策略：

- 默认：`min-width: 900px`
- 小于 900px：保持横向滚动，不做移动端适配

### 9.2 触控目标

- 按钮有效高度 ≥ 44px
- 输入框高度 44px
- 图标按钮 40×40px（必要时扩展至 44×44px）
- 胶囊 tab 内边距保证可点击区域

### 9.3 对比度

- 主文字 `$color-ink` 在 `$color-canvas` 上满足 WCAG AA
- 辅助文字 `$color-steel` 仅用于非关键信息
- 错误文字 `$color-critical-strong` 保持高对比

---

## 10. 动效规范

### 10.1 原则

- 仅使用 `transform` 和 `opacity`，避免触发重排。
- 统一缓动：`ease-out` 或 `cubic-bezier(0.22, 1, 0.36, 1)`。

### 10.2 时长

| 场景 | 时长 |
|------|------|
| 按钮/输入框状态切换 | 150–200ms |
| 卡片悬浮 | 200–300ms |
| 弹窗出现 | 250ms |
| 页面/内容入场 | 300–400ms |

### 10.3 具体效果

- 按钮 hover：背景色加深，轻微上移 1–2px
- 卡片 hover：阴影加深，轻微上移 2–4px
- 输入框 focus：边框颜色过渡
- 弹窗出现：`opacity 0→1` + `scale 0.96→1`
- 骨架屏：保留现有 shimmer 效果，颜色改为 `$color-surface-soft`

---

## 11. 文件与目录变更

### 11.1 新增文件

```
main/manager-web/src/
├── styles/
│   ├── _tokens.scss
│   ├── _element-override.scss
│   ├── _global.scss
│   └── index.scss
```

### 11.2 修改文件

```
main/manager-web/src/
├── App.vue                  # 引入 index.scss，设置全局字体/背景
├── main.js                  # 引入新的样式入口
├── views/login.vue          # 登录页视觉重构
├── views/home.vue           # 首页视觉重构
├── components/HeaderBar.vue         # 顶部导航视觉重构（若存在）
├── components/DynamicBackground.vue # 新增动态背景组件
├── components/GlassCard.vue         # 新增玻璃卡片组件
├── components/CustomButton.vue      # 统一按钮样式（可选）
├── components/CustomDialog.vue      # 统一弹窗样式（可选）
└── styles/global.scss               # 合并或迁移到新的 _global.scss
```

---

## 12. 错误处理与边界情况

- **Element UI 样式冲突**：通过提高选择器权重、使用 `!important` 最小化策略、或在 scoped 中使用 `:deep()` 处理。
- **字体加载失败**：`Inter` / `Noto Sans SC` 后设置系统字体 fallback，确保降级可读。
- **表格页样式异常**：表格页不动布局，仅覆盖全局 token，逐个页面验证无异常覆盖。
- **i18n 文案**：所有新增或修改文案通过 `vue-i18n` 接入，保持 6 种语言支持。
- **浏览器兼容性**：圆角、阴影、flexbox 均为现代浏览器基础支持；玻璃亚克力使用 `backdrop-filter`，对不支持浏览器降级为纯白背景。
- **动态背景降级**：`prefers-reduced-motion` 媒体查询下停止背景动画；不支持 `backdrop-filter` 的浏览器使用纯白卡片背景。
- **暗色模式**：本次不支持，所有 token 仅定义浅色值。

---

## 13. 测试策略

1. **视觉回归**：对比登录页、首页、设备管理页改造前后截图。
2. **功能回归**：
   - 登录流程（用户名/密码/验证码）正常。
   - 首页搜索、新增智能体、删除智能体正常。
   - 导航跳转（若存在 HeaderBar）正常。
   - 弹窗、表单、分页交互正常。
3. **交互测试**：
   - 按钮悬浮、输入框聚焦、卡片悬浮效果正常。
   - 弹窗出现/关闭动画流畅。
4. **构建验证**：`npm run build` 无样式或资源错误。
5. **多语言验证**：切换 6 种语言，确认布局不因文字长度错乱。

---

## 14. 风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| Element UI 样式覆盖不完全 | 中 | 使用 SCSS 变量 + 全局覆盖 + `:deep()` 三层策略 |
| 品牌蓝与 Meta 形态融合不佳 | 中 | 先以登录页/首页做试点，确认后再扩展 |
| 字体加载影响首屏 | 低 | 使用 font-display: swap，设置系统字体 fallback |
| 表格页全局覆盖影响其他页面 | 低 | 限制覆盖范围为通用表格样式，逐个页面验证 |
| 动态背景导致可读性下降 | 中 | 所有内容卡片使用玻璃亚克力模糊，并验证对比度 |
| `backdrop-filter` 兼容性问题 | 低 | 提供 `@supports` 降级为纯白背景 |
| `prefers-reduced-motion` 未处理 | 低 | 动态背景组件内置媒体查询停止动画 |
| i18n 文案遗漏 | 低 | 新增文案统一走 `$t()`，对照现有语言文件补充 |

---

## 15. 后续规划（第二阶段）

1. 复杂详情页（角色配置、知识库、音色克隆）的视觉重绘。
2. 表格页进一步自定义（行内操作按钮、批量操作、筛选区）。
3. 可选：暗色模式 token 定义与切换。
4. 可选：引入更丰富的数据可视化首页。


---

## 16. 分阶段实施计划

### 16.1 第一阶段：基础设施（1–2 天）

1. 创建 `styles/_tokens.scss`、`styles/_element-override.scss`、`styles/_global.scss`、`styles/index.scss`。
2. 在 `main.js` 中引入 `styles/index.scss`。
3. 调整 `vue.config.js` 确保 SCSS 全局变量可被所有组件使用（通过 `css.loaderOptions.scss` 注入 token）。
4. 验证 Element UI 主题色已被覆盖，按钮、输入框形态正确。

### 16.2 第二阶段：公共组件与布局（1–2 天）

1. 调整 `App.vue` 全局字体、背景色。
2. 创建 `DynamicBackground.vue` 并实现登录/管理两种变体。
3. 创建 `GlassCard.vue` 玻璃亚克力卡片组件。
4. 调整 `HeaderBar.vue`（若存在）：白色背景、胶囊 tab、简化用户区。
5. 统一 `CustomButton.vue` / `CustomDialog.vue` 等通用组件形态。
6. 验证所有管理页继承新的表格、分页、弹窗样式。

### 16.3 第三阶段：核心页面（2–3 天）

1. 重构 `views/login.vue`：白底大圆角卡片、胶囊按钮、更新字体层级。
2. 重构 `views/home.vue`：Hero 区卡片化、设备卡片大圆角、搜索条胶囊化。
3. 保持功能与交互不变，仅调整视觉。

### 16.4 第四阶段：回归与验证（1–2 天）

1. 运行 `npm run serve`，逐页检查视觉一致性。
2. 运行 `npm run build`，确认构建无报错。
3. 对照测试策略做功能回归。

---

## 17. Element UI 覆盖示例

### 17.1 SCSS 变量覆盖

```scss
// styles/_element-override.scss

// 主色
$--color-primary: $color-primary;
$--color-success: $color-success;
$--color-warning: $color-warning;
$--color-danger: $color-critical;

// 文字
$--color-text-primary: $color-ink;
$--color-text-regular: $color-charcoal;
$--color-text-secondary: $color-steel;
$--color-text-placeholder: $color-stone;

// 边框
$--border-color-base: $color-hairline;
$--border-color-light: $color-hairline-soft;

// 背景
$--background-color-base: $color-surface-soft;

// 字体
$--font-path: '~element-ui/lib/theme-chalk/fonts';
@import "~element-ui/packages/theme-chalk/src/index";
```

### 17.2 按钮全局覆盖

```scss
// 让所有 Element 按钮变为胶囊
.el-button {
  border-radius: $rounded-full !important;
  font: $font-body-sm-bold;

  &--primary {
    background-color: $color-primary;
    border-color: $color-primary;

    &:hover,
    &:focus {
      background-color: lighten($color-primary, 6%);
      border-color: lighten($color-primary, 6%);
    }

    &:active {
      background-color: $color-primary-deep;
      border-color: $color-primary-deep;
    }
  }

  &--default {
    &:hover {
      color: $color-primary;
      border-color: rgba($color-primary, 0.3);
      background-color: rgba($color-primary, 0.05);
    }
  }

  &.is-disabled {
    background-color: $color-disabled-text;
    border-color: $color-disabled-text;
    color: $color-canvas;
  }
}
```

### 17.3 输入框全局覆盖

```scss
.el-input__inner {
  height: 44px;
  border-radius: $rounded-lg;
  border: 1px solid $color-hairline;
  font: $font-body-md;

  &:focus {
    border-color: $color-primary-soft;
    box-shadow: 0 0 0 3px rgba($color-primary-soft, 0.12);
  }
}

.el-input.is-error .el-input__inner {
  border-color: $color-critical-strong;
}
```

### 17.4 弹窗全局覆盖

```scss
.el-dialog {
  border-radius: $rounded-xxl;
  box-shadow: $shadow-dialog;

  &__header {
    padding: $spacing-xl;
    padding-bottom: $spacing-base;
  }

  &__title {
    font: $font-subtitle-lg;
    color: $color-ink-deep;
  }

  &__body {
    padding: $spacing-xl;
    color: $color-charcoal;
  }

  &__footer {
    padding: $spacing-base $spacing-xl $spacing-xl;
    display: flex;
    justify-content: flex-end;
    gap: $spacing-base;
  }
}
```

### 17.5 表格全局覆盖

```scss
.el-table {
  th {
    background-color: $color-surface-soft;
    color: $color-ink;
    font: $font-body-sm-bold;
    height: 48px;
  }

  td {
    color: $color-charcoal;
    height: 48px;
  }

  tr:hover > td {
    background-color: $color-surface-soft;
  }
}
```

---

## 18. 页面级修改清单

### 18.1 登录页 `login.vue`

- [ ] 移除或简化蓝紫渐变横幅，改用白底大圆角卡片。
- [ ] 登录卡片：`background: $color-canvas`、`border-radius: $rounded-xxxl`、`padding: $spacing-xxl`。
- [ ] 标题：使用 `$font-display-lg`（中文环境可适当降至 36–40px 避免过大）。
- [ ] 输入框：统一 44px 高度、8px 圆角。
- [ ] 登录按钮：primary、胶囊、100% 宽度。
- [ ] 链接文字：使用 `$color-primary-soft`、`font-body-md-bold`。
- [ ] 语言切换：改为胶囊形选择器或保持下拉但应用 token。
- [ ] 保留验证码、手机号登录等现有逻辑。

### 18.2 首页 `home.vue`

- [ ] 背景色改为 `$color-canvas` 或极浅灰 `$color-surface-soft`。
- [ ] Hero 区改为白底大圆角卡片，内边距 `$spacing-section`。
- [ ] 欢迎语：`$font-heading-lg`，副标题 `$font-body-md` `$color-steel`。
- [ ] 搜索框改为胶囊形，背景 `$color-surface-soft`。
- [ ] “添加智能体”按钮改为 primary 胶囊按钮。
- [ ] 设备卡片改为 32px 圆角、32px 内边距、细边框。
- [ ] 骨架屏颜色更新为 `$color-surface-soft`。
- [ ] 保留搜索历史下拉功能，样式应用 token。

### 18.3 顶部导航 `HeaderBar.vue`（若存在）

- [ ] 背景改为 `$color-canvas`，底部 1px `$color-hairline-soft` 边框。
- [ ] 导航 tab 改为胶囊形，inactive 为白底细边框，active 为深色填充。
- [ ] 移除蓝紫渐变和发光效果。
- [ ] 用户区头像改为 40px 圆形，用户名使用 `$font-body-sm`。

---

## 19. 字体加载策略

### 19.1 方案

使用 Google Fonts 在线加载 Inter 和 Noto Sans SC：

```html
<!-- public/index.html -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700&family=Noto+Sans+SC:wght@400;500;700&display=swap" rel="stylesheet">
```

### 19.2 降级

```scss
body {
  font-family: "Inter", "Noto Sans SC", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}
```

### 19.3 离线环境

若部署环境无法访问 Google Fonts，需将字体文件放入 `public/fonts/` 并通过 `@font-face` 引入。此步骤可作为第二阶段优化。

---

## 20. 验收标准

### 20.1 视觉验收

- [ ] 登录页、首页、Header（若存在）无 Element UI 默认风格残留。
- [ ] 所有按钮为胶囊形，主按钮为品牌蓝。
- [ ] 所有卡片圆角 ≥ 16px，核心卡片为 32px。
- [ ] 输入框高度 44px，圆角 8px。
- [ ] 弹窗圆角 24px，标题 18px/700。
- [ ] 表格页表头、行高、hover 背景符合 token。

### 20.2 功能验收

- [ ] 登录流程正常（用户名、密码、验证码、手机号登录）。
- [ ] 首页搜索、新增、删除智能体正常。
- [ ] 弹窗、表单、分页、下拉菜单交互正常。
- [ ] 多语言切换后布局无错位。

### 20.3 构建验收

- [ ] `npm run build` 成功。
- [ ] 无未使用变量导致的 SCSS 警告。
- [ ] 生产包体积无异常增大（字体按需加载）。

---

## 21. 与 2026-07-14 Kimi 玻璃拟态方案的关系

本文档是独立的视觉方向，基于 `DESIGN-meta.md` 而非 Kimi 首页。两者区别：

| 维度 | 本方案（Meta 借鉴适配） | 2026-07-14 方案（Kimi 玻璃拟态） |
|------|------------------------|--------------------------------|
| 参考来源 | Meta 电商/硬件设计系统 | Kimi AI 首页 |
| 核心视觉 | 极光动态背景 + 玻璃亚克力卡片 + 大圆角 + 胶囊按钮 | 玻璃拟态、侧边栏布局、光晕卡片 |
| 改动范围 | 核心页面 + 全局 token | 全局布局替换 + 首页/登录页重点美化 |
| 侵入性 | 低 | 中（新增 AppLayout、AppSidebar） |
| 主色 | 品牌蓝 #3375fd / #5778ff | #1a73e8 |
| 组件库 | 保留 Element UI | 保留 Element UI |

**建议**：如果团队希望快速落地且保持现有顶部导航结构，采用本方案；如果希望彻底改为现代 admin 侧边栏布局，可参考 2026-07-14 方案。两者不可混合执行，需选定一个方向。
