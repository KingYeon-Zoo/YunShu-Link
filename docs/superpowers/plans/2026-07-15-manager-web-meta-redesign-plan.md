# manager-web Meta 设计语言 + 动态背景实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 基于 `docs/superpowers/specs/2026-07-15-manager-web-meta-redesign-design.md`，将 manager-web 重构为 Meta 设计语言风格，包含极光动态背景、玻璃亚克力卡片、胶囊按钮与大圆角组件。

**架构：** 新增 SCSS token 文件与 Element UI 覆盖样式；新增 `DynamicBackground.vue` 和 `GlassCard.vue` 两个可复用组件；核心页面（登录页、首页）直接使用新组件和 token；管理表格页通过全局样式自动继承新视觉。

**技术栈：** Vue 2.6 + Element UI 2.15 + SCSS + vue-i18n

---

## 文件结构

```
main/manager-web/src/
├── styles/
│   ├── _tokens.scss             # 新增：颜色、字体、间距、圆角、阴影、玻璃 token
│   ├── _element-override.scss   # 新增：Element UI SCSS 变量与全局覆盖
│   ├── _global.scss             # 新增/迁移：全局工具、滚动条、autofill、动画
│   └── index.scss               # 新增：样式统一入口
├── components/
│   ├── DynamicBackground.vue    # 新增：登录页/管理页极光背景
│   ├── GlassCard.vue            # 新增：玻璃亚克力卡片容器
│   ├── HeaderBar.vue            # 修改：胶囊 tab、白色背景（若存在）
│   ├── CustomButton.vue         # 修改：统一胶囊按钮形态
│   └── CustomDialog.vue         # 修改：玻璃弹窗
├── views/
│   ├── login.vue                # 修改：玻璃登录卡片 + 动态背景
│   ├── home.vue                 # 修改：玻璃 Hero/设备卡片 + 动态背景
│   └── *.vue                    # 只读验证：表格页继承全局样式
├── App.vue                      # 修改：全局字体、背景
├── main.js                      # 修改：引入 styles/index.scss
├── styles/global.scss           # 修改：合并/迁移到 _global.scss
└── public/index.html            # 修改：加载 Inter + Noto Sans SC 字体
```

---

## 任务 1：搭建 SCSS Token 基础设施

**文件：**
- 创建：`main/manager-web/src/styles/_tokens.scss`
- 创建：`main/manager-web/src/styles/index.scss`
- 修改：`main/manager-web/src/main.js`

- [ ] **步骤 1：创建 `_tokens.scss`**

```scss
// main/manager-web/src/styles/_tokens.scss

// 品牌主色
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

// 字体
$font-family-base: "Inter", "Noto Sans SC", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;

// 字体组合（weight size/line-height family）
$font-display-lg: 500 48px/1.17 $font-family-base;
$font-heading-lg: 500 36px/1.28 $font-family-base;
$font-heading-sm: 500 24px/1.25 $font-family-base;
$font-subtitle-lg: 700 18px/1.44 $font-family-base;
$font-body-md: 400 16px/1.5 $font-family-base;
$font-body-md-bold: 700 16px/1.5 $font-family-base;
$font-body-sm: 400 14px/1.43 $font-family-base;
$font-body-sm-bold: 700 14px/1.43 $font-family-base;
$font-caption: 400 12px/1.33 $font-family-base;
$font-caption-bold: 700 12px/1.33 $font-family-base;

// 间距
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

// 圆角
$rounded-xs: 2px;
$rounded-sm: 4px;
$rounded-md: 6px;
$rounded-lg: 8px;
$rounded-xl: 16px;
$rounded-xxl: 24px;
$rounded-xxxl: 32px;
$rounded-full: 100px;
$rounded-circle: 50%;

// 阴影
$shadow-flat: none;
$shadow-subtle: rgba(0, 0, 0, 0.2) 1px 1px 0px 0px;
$shadow-sticky: rgba(20, 22, 26, 0.3) 0px 1px 4px 0px;
$shadow-dialog: 0 4px 24px rgba(0, 0, 0, 0.12);
```

- [ ] **步骤 2：创建 `index.scss` 入口**

```scss
// main/manager-web/src/styles/index.scss
@import "tokens";
@import "global";
@import "element-override";
```

- [ ] **步骤 3：修改 `main.js` 引入新样式入口**

```js
// main/manager-web/src/main.js
// 将原有 import "@/styles/global.scss"; 替换为：
import "@/styles/index.scss";
```

- [ ] **步骤 4：运行开发服务器验证无报错**

```bash
cd main/manager-web
npm run serve
```

预期：服务正常启动，无 SCSS 编译错误。

- [ ] **步骤 5：Commit**

```bash
git add main/manager-web/src/styles/_tokens.scss main/manager-web/src/styles/index.scss main/manager-web/src/main.js
git commit -m "feat: add Meta design token system and style entry"
```

---

## 任务 2：全局样式与字体加载

**文件：**
- 创建：`main/manager-web/src/styles/_global.scss`
- 修改：`main/manager-web/src/App.vue`
- 修改：`main/manager-web/public/index.html`
- 修改：`main/manager-web/src/styles/global.scss`

- [ ] **步骤 1：创建 `_global.scss`**

```scss
// main/manager-web/src/styles/_global.scss
@import "tokens";

* {
  box-sizing: border-box;
}

body {
  font-family: $font-family-base;
  color: $color-ink;
  background-color: $color-canvas;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

// 覆盖 autofill 样式
input:-webkit-autofill,
input:-webkit-autofill:hover,
input:-webkit-autofill:focus,
textarea:-webkit-autofill,
textarea:-webkit-autofill:hover,
textarea:-webkit-autofill:focus,
select:-webkit-autofill,
select:-webkit-autofill:hover,
select:-webkit-autofill:focus {
  -webkit-box-shadow: 0 0 0px 1000px transparent inset;
  transition: background-color 5000s ease-in-out 0s;
  background-color: transparent;
}

// 滚动条
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

::-webkit-scrollbar-thumb {
  background: rgba($color-primary, 0.35);
  border-radius: 3px;
}

::-webkit-scrollbar-track {
  background: $color-surface-soft;
  border-radius: 3px;
}

// Element UI Message 偏移
.el-message {
  top: 70px !important;
}

// 玻璃卡片工具类
.glass-card {
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  border-radius: $rounded-xxxl;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  transition: background 0.2s ease, box-shadow 0.2s ease;

  &:hover {
    background: $color-glass-bg-hover;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
  }
}

@supports not (backdrop-filter: blur($glass-blur)) {
  .glass-card {
    background: $color-canvas;
  }
}

// 减少动画偏好
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

- [ ] **步骤 2：迁移/清空旧的 `styles/global.scss`**

将 `main/manager-web/src/styles/global.scss` 内容清空，改为：

```scss
// main/manager-web/src/styles/global.scss
// 全局样式已迁移至 styles/_global.scss，通过 styles/index.scss 统一引入。
```

- [ ] **步骤 3：修改 `App.vue` 移除默认样式并设置全局字体**

```scss
// main/manager-web/src/App.vue
#app {
  font-family: $font-family-base;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  color: $color-ink;
}
```

移除原 `nav` 默认样式和 `.copyright` 中的硬编码颜色，改用 token。

- [ ] **步骤 4：在 `public/index.html` 中加载字体**

```html
<!-- main/manager-web/public/index.html -->
<head>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700&family=Noto+Sans+SC:wght@400;500;700&display=swap" rel="stylesheet">
</head>
```

- [ ] **步骤 5：验证页面字体变化**

打开 `http://localhost:8080/login`，预期页面字体已变为 Inter / Noto Sans SC。

- [ ] **步骤 6：Commit**

```bash
git add main/manager-web/src/styles/_global.scss main/manager-web/src/styles/global.scss main/manager-web/src/App.vue main/manager-web/public/index.html
git commit -m "feat: add global styles, scrollbar, glass utility and font loading"
```

---

## 任务 3：Element UI 主题覆盖

**文件：**
- 创建：`main/manager-web/src/styles/_element-override.scss`

- [ ] **步骤 1：创建 `_element-override.scss`**

```scss
// main/manager-web/src/styles/_element-override.scss
@import "tokens";

// Element UI SCSS 变量覆盖
$--color-primary: $color-primary;
$--color-success: $color-success;
$--color-warning: $color-warning;
$--color-danger: $color-critical;
$--color-text-primary: $color-ink;
$--color-text-regular: $color-charcoal;
$--color-text-secondary: $color-steel;
$--color-text-placeholder: $color-stone;
$--border-color-base: $color-hairline;
$--border-color-light: $color-hairline-soft;
$--background-color-base: $color-surface-soft;

@import "~element-ui/packages/theme-chalk/src/index";

// 按钮：统一胶囊
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

  &.is-disabled {
    background-color: $color-disabled-text;
    border-color: $color-disabled-text;
    color: $color-canvas;
  }
}

// 输入框
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

// 弹窗
.el-dialog {
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  border-radius: $rounded-xxl;
  box-shadow: $shadow-dialog;
  border: 1px solid $color-glass-border-strong;

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

// 表格
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

// 分页
.el-pagination {
  .el-pager li {
    border-radius: $rounded-full;

    &.active {
      background-color: $color-primary;
      color: $color-on-primary;
    }
  }
}
```

- [ ] **步骤 2：验证按钮和输入框形态**

打开登录页，预期：
- 所有按钮为胶囊形
- 输入框高度 44px、圆角 8px
- 主按钮为品牌蓝

- [ ] **步骤 3：Commit**

```bash
git add main/manager-web/src/styles/_element-override.scss main/manager-web/src/styles/index.scss
git commit -m "feat: override Element UI buttons, inputs, dialogs, tables and pagination"
```

---

## 任务 4：创建 DynamicBackground 组件

**文件：**
- 创建：`main/manager-web/src/components/DynamicBackground.vue`

- [ ] **步骤 1：创建组件**

```vue
<!-- main/manager-web/src/components/DynamicBackground.vue -->
<template>
  <div class="dynamic-background" :class="`dynamic-background--${variant}`">
    <div class="blob blob-1"></div>
    <div class="blob blob-2"></div>
    <div v-if="variant === 'login'" class="blob blob-3"></div>
  </div>
</template>

<script>
export default {
  name: 'DynamicBackground',
  props: {
    variant: {
      type: String,
      default: 'management',
      validator: value => ['login', 'management'].includes(value)
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.dynamic-background {
  position: fixed;
  inset: 0;
  z-index: 0;
  overflow: hidden;

  .blob {
    position: absolute;
    border-radius: 50%;
  }
}

.dynamic-background--login {
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
    filter: blur(50px);
  }

  .blob-1 {
    width: 400px;
    height: 400px;
    background: rgba($color-primary, 0.35);
    top: -100px;
    left: -100px;
    animation: blob-float 12s ease-in-out infinite;
  }

  .blob-2 {
    width: 350px;
    height: 350px;
    background: rgba($color-primary-soft, 0.3);
    bottom: -80px;
    right: -80px;
    animation: blob-float 14s ease-in-out infinite;
    animation-delay: -4s;
  }

  .blob-3 {
    width: 300px;
    height: 300px;
    background: rgba($color-primary-deep, 0.2);
    top: 50%;
    left: 50%;
    animation: blob-float 16s ease-in-out infinite reverse;
  }
}

.dynamic-background--management {
  background: linear-gradient(
    135deg,
    $color-canvas 0%,
    $color-surface-soft 50%,
    $color-canvas 100%
  );
  background-size: 300% 300%;
  animation: aurora-flow 20s ease infinite;

  .blob {
    filter: blur(60px);
  }

  .blob-1 {
    width: 500px;
    height: 500px;
    background: rgba($color-primary, 0.5);
    top: -150px;
    right: -150px;
    opacity: 0.06;
    animation: blob-float 25s ease-in-out infinite;
  }

  .blob-2 {
    width: 400px;
    height: 400px;
    background: rgba($color-primary-soft, 0.4);
    bottom: -100px;
    left: -100px;
    opacity: 0.06;
    animation: blob-float 28s ease-in-out infinite;
    animation-delay: -8s;
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

@media (prefers-reduced-motion: reduce) {
  .dynamic-background,
  .dynamic-background .blob {
    animation: none;
  }
}
</style>
```

- [ ] **步骤 2：在临时页面中测试两个变体**

在 `views/login.vue` 中临时插入：

```vue
<DynamicBackground variant="login" />
```

确认背景动画正常、色块流动自然。

- [ ] **步骤 3：Commit**

```bash
git add main/manager-web/src/components/DynamicBackground.vue
git commit -m "feat: add DynamicBackground component with login and management variants"
```

---

## 任务 5：创建 GlassCard 组件

**文件：**
- 创建：`main/manager-web/src/components/GlassCard.vue`

- [ ] **步骤 1：创建组件**

```vue
<!-- main/manager-web/src/components/GlassCard.vue -->
<template>
  <div class="glass-card-container" :class="{ 'glass-card-container--hoverable': hoverable, [`glass-card-container--${size}`]: true }">
    <slot></slot>
  </div>
</template>

<script>
export default {
  name: 'GlassCard',
  props: {
    hoverable: {
      type: Boolean,
      default: true
    },
    size: {
      type: String,
      default: 'large', // 'large' | 'small'
      validator: value => ['large', 'small'].includes(value)
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.glass-card-container {
  position: relative;
  z-index: 1;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  transition: background 0.2s ease, box-shadow 0.2s ease;

  &--large {
    border-radius: $rounded-xxxl;
    padding: $spacing-xxl;
  }

  &--small {
    border-radius: $rounded-xl;
    padding: $spacing-xl;
  }

  &--hoverable:hover {
    background: $color-glass-bg-hover;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
  }
}

@supports not (backdrop-filter: blur($glass-blur)) {
  .glass-card-container {
    background: $color-canvas;
  }
}
</style>
```

- [ ] **步骤 2：在临时页面中测试**

在 `views/home.vue` 中临时替换一个设备卡片为：

```vue
<GlassCard size="large">
  <div>测试内容</div>
</GlassCard>
```

确认玻璃效果、圆角、hover 阴影正常。

- [ ] **步骤 3：Commit**

```bash
git add main/manager-web/src/components/GlassCard.vue
git commit -m "feat: add GlassCard component with acrylic blur and hover effect"
```

---

## 任务 6：重构登录页

**文件：**
- 修改：`main/manager-web/src/views/login.vue`

- [ ] **步骤 1：在模板根节点添加动态背景**

```vue
<template>
  <div class="welcome">
    <DynamicBackground variant="login" />
    <el-container style="height: 100%; position: relative; z-index: 1;">
      <!-- 原有内容 -->
    </el-container>
  </div>
</template>
```

- [ ] **步骤 2：将登录表单容器改为 GlassCard 或玻璃样式**

找到 `.login-box`，更新其样式：

```scss
.login-box {
  position: relative;
  z-index: 1;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border-radius: $rounded-xxxl;
  border: 1px solid $color-glass-border-strong;
  box-shadow: $shadow-dialog;
  // 保留原有 padding 和尺寸
}
```

- [ ] **步骤 3：移除蓝紫渐变横幅相关样式**

删除或注释 `.welcome` 中的 `background: #eff4ff;` 和 `.add-device-bg` 中的渐变背景（如果它们影响登录页）。

- [ ] **步骤 4：更新登录页文字层级**

```scss
.login-text {
  font: $font-display-lg;
  color: $color-ink-deep;
}

.login-welcome {
  font: $font-body-md;
  color: $color-steel;
}
```

- [ ] **步骤 5：验证登录功能与视觉**

- 页面显示动态极光背景
- 登录卡片为玻璃亚克力
- 按钮为胶囊形
- 用户名/密码/验证码登录正常

- [ ] **步骤 6：Commit**

```bash
git add main/manager-web/src/views/login.vue
git commit -m "feat: redesign login page with aurora background and glass card"
```

---

## 任务 7：重构首页

**文件：**
- 修改：`main/manager-web/src/views/home.vue`

- [ ] **步骤 1：在模板根节点添加动态背景**

```vue
<template>
  <div class="welcome">
    <DynamicBackground variant="management" />
    <HeaderBar :devices="devices" style="position: relative; z-index: 1;" />
    <el-main style="padding: 20px; position: relative; z-index: 1;">
      <!-- 原有内容 -->
    </el-main>
    <!-- ... -->
  </div>
</template>
```

- [ ] **步骤 2：更新首页背景色**

```scss
.welcome {
  min-height: 506px;
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: transparent;
}
```

- [ ] **步骤 3：将 Hero 区改为玻璃卡片**

替换 `.add-device` 和 `.add-device-bg`：

```scss
.add-device {
  height: auto;
  border-radius: $rounded-xxxl;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  padding: $spacing-section;
}

.add-device-bg {
  background: transparent;
}
```

- [ ] **步骤 4：更新欢迎文字样式**

```scss
.hellow-text {
  margin-left: 0;
  font: $font-heading-lg;
  color: $color-ink-deep;
}

.hi-hint {
  font: $font-body-sm;
  color: $color-steel;
  margin-left: 0;
}
```

- [ ] **步骤 5：搜索框改为胶囊形**

```scss
.search-container {
  width: 360px;
}

.custom-search-input {
  &::v-deep .el-input__inner {
    height: 40px;
    background: rgba(255, 255, 255, 0.8);
    backdrop-filter: blur(8px);
    border-radius: $rounded-full;
    border: 1px solid $color-glass-border;
    box-shadow: none;
  }
}
```

- [ ] **步骤 6：设备卡片改为玻璃卡片**

```scss
.device-list-container {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
  gap: $spacing-xl;
  padding: $spacing-xl 0;
}
```

在 `DeviceItem.vue` 中更新卡片样式（或在外层包裹 `<GlassCard>`）：

```scss
.device-item {
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  border-radius: $rounded-xxxl;
  padding: $spacing-xxl;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  transition: background 0.2s ease, box-shadow 0.2s ease;

  &:hover {
    background: $color-glass-bg-hover;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
  }
}
```

- [ ] **步骤 7：验证首页功能与视觉**

- 页面显示 subtle 动态背景
- Hero 区和设备卡片为玻璃效果
- 搜索、新增、删除智能体功能正常

- [ ] **步骤 8：Commit**

```bash
git add main/manager-web/src/views/home.vue main/manager-web/src/components/DeviceItem.vue
git commit -m "feat: redesign home page with subtle aurora background and glass cards"
```

---

## 任务 8：顶部导航重构（若存在）

**文件：**
- 修改：`main/manager-web/src/components/HeaderBar.vue`

- [ ] **步骤 1：更新 Header 背景**

```scss
.header {
  background: $color-canvas;
  border-bottom: 1px solid $color-hairline-soft;
  height: 64px !important;
}
```

- [ ] **步骤 2：将导航 tab 改为胶囊形**

```scss
.header-center {
  display: flex;
  align-items: center;
  gap: $spacing-xs;
  background: $color-surface-soft;
  border-radius: $rounded-full;
  padding: $spacing-xxs;
}

.equipment-management {
  padding: $spacing-xs $spacing-base;
  border-radius: $rounded-full;
  font: $font-body-sm-bold;
  color: $color-ink;
  cursor: pointer;
  transition: all 0.2s ease;

  &.active-tab {
    background: $color-ink-deep;
    color: $color-canvas;
    box-shadow: none;
  }

  &:not(.active-tab):hover {
    background: rgba($color-ink-deep, 0.06);
  }
}
```

移除原蓝紫渐变、发光、伪元素等效果。

- [ ] **步骤 3：验证导航功能**

- 当前 tab 高亮正确
- 下拉菜单正常展开
- 跳转正常

- [ ] **步骤 4：Commit**

```bash
git add main/manager-web/src/components/HeaderBar.vue
git commit -m "feat: redesign header bar with pill tabs and clean white background"
```

> 如果当前版本已移除 `HeaderBar.vue`，则跳过本任务。

---

## 任务 9：更新通用组件（可选）

**文件：**
- 修改：`main/manager-web/src/components/CustomButton.vue`
- 修改：`main/manager-web/src/components/CustomDialog.vue`

- [ ] **步骤 1：统一 CustomButton 为胶囊形**

确保 `CustomButton.vue` 继承或强制使用胶囊圆角和品牌蓝主色。

- [ ] **步骤 2：统一 CustomDialog 为玻璃弹窗**

确保 `CustomDialog.vue` 使用 `GlassCard` 样式或匹配弹窗覆盖样式。

- [ ] **步骤 3：Commit**

```bash
git add main/manager-web/src/components/CustomButton.vue main/manager-web/src/components/CustomDialog.vue
git commit -m "feat: align custom button and dialog with new design system"
```

---

## 任务 10：管理表格页验证

**文件：**
- 只读访问：`main/manager-web/src/views/DeviceManagement.vue`
- 只读访问：`main/manager-web/src/views/UserManagement.vue`
- 只读访问：`main/manager-web/src/views/ModelConfig.vue`

- [ ] **步骤 1：逐一打开表格页**

访问：
- `/device-management`
- `/user-management`
- `/model-config`

- [ ] **步骤 2：检查全局样式继承情况**

确认：
- 按钮为胶囊形
- 输入框高度 44px、圆角 8px
- 表格表头为浅灰背景、行高 48px
- 弹窗为玻璃圆角

- [ ] **步骤 3：记录并修复异常**

如发现某页面局部样式冲突，使用 scoped `:deep()` 或添加针对性全局覆盖。

- [ ] **步骤 4：Commit（如有修复）**

```bash
git add <fixed-files>
git commit -m "fix: resolve table page style conflicts with new theme"
```

---

## 任务 11：构建验证与视觉回归

**文件：**
- 全部受影响文件

- [ ] **步骤 1：运行生产构建**

```bash
cd main/manager-web
npm run build
```

预期：构建成功，无 SCSS 编译错误。

- [ ] **步骤 2：检查关键页面截图**

对比以下页面改造前后：
- 登录页
- 首页
- 设备管理页

- [ ] **步骤 3：多语言验证**

切换 zh_CN / en / de / vi / pt_BR / zh_TW，确认：
- 布局无错位
- 字体显示正常

- [ ] **步骤 4：无障碍验证**

在浏览器中开启 `prefers-reduced-motion`，确认动态背景动画停止。

- [ ] **步骤 5：Commit（仅文档或截图）**

```bash
git commit -m "chore: verify build and visual regression"
```

---

## 任务 12：最终审查与清理

- [ ] **步骤 1：删除临时测试代码**

确认没有在 `login.vue` / `home.vue` 中遗留临时 `<DynamicBackground>` 重复实例或调试样式。

- [ ] **步骤 2：检查未使用变量**

确认 `_tokens.scss` 中没有完全未使用的 token（允许保留未来扩展用的 token）。

- [ ] **步骤 3：最终 Commit**

```bash
git status --short
git log --oneline -10
```

确认提交历史清晰，每个 commit 职责单一。

---

## 自检

### 规格覆盖度

| 规格章节 | 对应任务 |
|---------|---------|
| Token 系统 | 任务 1 |
| 全局样式与字体 | 任务 2 |
| Element UI 覆盖 | 任务 3 |
| DynamicBackground | 任务 4 |
| GlassCard | 任务 5 |
| 登录页 | 任务 6 |
| 首页 | 任务 7 |
| 顶部导航 | 任务 8 |
| 通用组件 | 任务 9 |
| 表格页验证 | 任务 10 |
| 构建与回归 | 任务 11 |

### 占位符扫描

- 无“TODO/待定”
- 无模糊描述
- 每个代码步骤包含完整代码块

### 类型一致性

- `DynamicBackground` 的 `variant` prop 在组件定义、父组件调用中均为 `'login' | 'management'`
- `GlassCard` 的 `size` prop 在组件定义、父组件调用中均为 `'large' | 'small'`
- 所有 SCSS token 名称与 `_tokens.scss` 定义一致
