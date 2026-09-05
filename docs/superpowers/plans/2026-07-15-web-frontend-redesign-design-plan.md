# Web 控制台前端美化改造实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 `main/manager-web` 升级为现代 SaaS 管理后台视觉风格，完成登录页分屏、首页仪表盘、左侧边栏导航、顶部面包屑及极光流体动态背景。

**架构：** 新增统一 `MainLayout` 布局组件包裹所有受保护内页；将 `HeaderBar` 的导航与用户菜单逻辑拆分到 `SidebarNav` 和 `BreadcrumbBar`；登录页与首页分别按分屏/仪表盘规格重写；视觉系统复用并扩展 `_tokens.scss`，所有动画基于 CSS 实现。

**技术栈：** Vue 2 + Element UI + SCSS + vue-router 3 + vue-i18n 8

---

## 文件清单

### 新增文件

| 文件 | 职责 |
|---|---|
| `main/manager-web/src/styles/_utilities.scss` | 全局工具类（`.glass-card`、`.surface-card`、`.elevated-card`、`.fade-in-up` 等） |
| `main/manager-web/src/components/DynamicBackground.vue`（覆盖） | 极光流体动态背景，支持 `login`/`management` 变体与 `prefers-reduced-motion` |
| `main/manager-web/src/layouts/MainLayout.vue` | 全局布局：侧边栏 + 顶部面包屑栏 + 可滚动内容区 |
| `main/manager-web/src/components/SidebarNav.vue` | 56px 左侧浅色边栏导航，迁移 HeaderBar 的权限/功能开关逻辑 |
| `main/manager-web/src/components/BreadcrumbBar.vue` | 顶部 48px 面包屑栏：面包屑路径 + 右侧用户头像/用户名/语言切换/退出 |
| `main/manager-web/src/components/StatCard.vue` | 统计卡片组件 |
| `main/manager-web/src/components/WelcomeBanner.vue` | 首页动态欢迎横幅（含时间问候语） |
| `main/manager-web/src/components/EmptyAgentState.vue` | 无智能体时空状态插画提示 |
| `main/manager-web/src/config/nav.config.js` | 导航项配置与路由映射，供 SidebarNav / BreadcrumbBar 共用 |
| `main/manager-web/src/utils/greeting.js` | 根据当前时间返回早安/下午好/晚上好 |

### 修改文件

| 文件 | 职责 |
|---|---|
| `main/manager-web/src/styles/_tokens.scss` | 补充缺失 token（`$color-hairline-soft` 等） |
| `main/manager-web/src/styles/index.scss` | 引入 `_utilities.scss` |
| `main/manager-web/src/App.vue` | 按路由条件渲染 MainLayout 或原始 router-view |
| `main/manager-web/src/router/index.js` | 用 MainLayout 包装受保护内页；完善路由守卫 |
| `main/manager-web/src/views/login.vue` | 分屏布局 + 玻璃登录表单 |
| `main/manager-web/src/views/home.vue` | 仪表盘布局：WelcomeBanner + StatCard 网格 + 设备网格 |
| `main/manager-web/src/components/DeviceItem.vue` | 增加入场 stagger 动画与 hover 上浮 |
| `main/manager-web/src/components/HeaderBar.vue` | 功能迁移后精简或标记废弃 |
| `main/manager-web/src/i18n/zh_CN.js` | 新增文案 |
| `main/manager-web/src/i18n/en.js` | 新增文案 |

---

## 任务 1：补充设计 Token 与全局工具类

**文件：**
- 修改：`main/manager-web/src/styles/_tokens.scss`
- 新增：`main/manager-web/src/styles/_utilities.scss`
- 修改：`main/manager-web/src/styles/index.scss`
- 测试：无（样式 token），构建通过即可

**规格摘要：**
- 在 `_tokens.scss` 中补充 `$color-hairline-soft: rgba(0, 0, 0, 0.06)`、`$color-ink-button: #0a1317`（如缺失）。
- 新增 `_utilities.scss`，定义以下工具类：
  - `.glass-card`：对应规格 3.4 的代码块。
  - `.surface-card`：白色背景、`$rounded-xl`、阴影 `0 2px 8px rgba(0,0,0,0.04)`。
  - `.elevated-card`：白色背景、`$rounded-xxxl`、阴影 `0 8px 32px rgba(0,0,0,0.08)`。
  - `.fade-in-up`：通用入场动画 `opacity 0 → 1`、`translateY(12px) → 0`、400ms、`$ease-out-expo`。
  - `.stagger-1` 到 `.stagger-6`：用于统计/设备卡片延迟。
- 在 `index.scss` 中 `@import "utilities";`，确保全局可用。
- 使用 `@supports not (backdrop-filter: blur(16px))` 为 `.glass-card` 提供 `$color-canvas` 回退。

**步骤：**

- [ ] **步骤 1：补充 token**

在 `_tokens.scss` 合适位置追加：

```scss
// Hairline
$color-hairline: rgba(0, 0, 0, 0.1);
$color-hairline-soft: rgba(0, 0, 0, 0.06);

// Button
$color-ink-button: #0a1317;
```

- [ ] **步骤 2：创建 `_utilities.scss`**

```scss
@import "tokens";

.glass-card {
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  border-radius: $rounded-xxxl;
  box-shadow: $shadow-dialog;

  @supports not (backdrop-filter: blur(1px)) {
    background: $color-canvas;
  }
}

.surface-card {
  background: $color-canvas;
  border-radius: $rounded-xl;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.elevated-card {
  background: $color-canvas;
  border-radius: $rounded-xxxl;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
}

@keyframes fade-in-up {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.fade-in-up {
  animation: fade-in-up 400ms $ease-out-expo forwards;
}

@for $i from 1 through 6 {
  .stagger-#{$i} {
    animation-delay: #{$i * 80}ms;
  }
}

@media (prefers-reduced-motion: reduce) {
  .fade-in-up,
  .stagger-1,
  .stagger-2,
  .stagger-3,
  .stagger-4,
  .stagger-5,
  .stagger-6 {
    animation: none;
    opacity: 1;
    transform: none;
  }
}
```

- [ ] **步骤 3：引入 utilities**

在 `index.scss` 顶部或合适位置：

```scss
@import "utilities";
```

- [ ] **步骤 4：验证构建**

运行：

```bash
cd main/manager-web && npm run build
```

预期：无新增错误。

- [ ] **步骤 5：Commit**

```bash
git add main/manager-web/src/styles/
git commit -m "feat(web): add utility classes and missing design tokens"
```

---

## 任务 2：极光流体动态背景组件

**文件：**
- 修改：`main/manager-web/src/components/DynamicBackground.vue`
- 测试：视觉审查（Chrome/Edge/Firefox），检查 `prefers-reduced-motion` 是否关闭动画。

**规格摘要：**
- 全屏固定背景，`z-index: 0`。
- `variant` prop 支持 `login`（饱和度更高、blob 更明显）与 `management`（更淡、blob 透明度 0.06–0.1）。
- 基础背景：柔和的蓝紫渐变，`background-size: 400% 400%`，动画 `aurora-flow` 20s ease infinite。
- 3–4 个大型半透明 blob，使用 `filter: blur(60px)`，周期 15–25s 缓慢位移/缩放。
- 支持 `prefers-reduced-motion: reduce` 关闭动画。

**步骤：**

- [ ] **步骤 1：编写组件**

替换 `DynamicBackground.vue` 为：

```vue
<template>
  <div :class="['dynamic-background', `dynamic-background--${variant}`]">
    <div
      v-for="i in blobCount"
      :key="i"
      class="blob"
      :style="blobStyle(i)"
    />
  </div>
</template>

<script>
export default {
  name: 'DynamicBackground',
  props: {
    variant: {
      type: String,
      default: 'management',
      validator: v => ['login', 'management'].includes(v)
    }
  },
  computed: {
    blobCount() {
      return this.variant === 'login' ? 4 : 3;
    }
  },
  methods: {
    blobStyle(i) {
      const positions = [
        { top: '10%', left: '15%', size: '45vw' },
        { top: '55%', left: '65%', size: '38vw' },
        { top: '70%', left: '20%', size: '32vw' },
        { top: '25%', left: '75%', size: '28vw' }
      ];
      const pos = positions[(i - 1) % positions.length];
      const duration = 15 + (i * 3);
      const delay = i * -2;
      const opacity = this.variant === 'login' ? 0.25 + (i * 0.05) : 0.06 + (i * 0.02);
      return {
        top: pos.top,
        left: pos.left,
        width: pos.size,
        height: pos.size,
        opacity,
        animationDuration: `${duration}s`,
        animationDelay: `${delay}s`
      };
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
  background: linear-gradient(135deg, #e0e6fd, #cce7ff, #d3d3fe, #e0e6fd);
  background-size: 400% 400%;
  animation: aurora-flow 20s ease infinite;
  overflow: hidden;

  &--login {
    background: linear-gradient(135deg, #d4dcff, #b8daff, #c9c9ff, #d4dcff);
    background-size: 400% 400%;
  }
}

.blob {
  position: absolute;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.9) 0%, rgba(200, 220, 255, 0.4) 100%);
  filter: blur(60px);
  animation: blob-float ease-in-out infinite;
  pointer-events: none;
}

@keyframes aurora-flow {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

@keyframes blob-float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(60px, -60px) scale(1.08); }
  66% { transform: translate(-40px, 40px) scale(0.96); }
}

@media (prefers-reduced-motion: reduce) {
  .dynamic-background,
  .blob {
    animation: none;
  }
}
</style>
```

- [ ] **步骤 2：验证构建**

```bash
cd main/manager-web && npm run build
```

- [ ] **步骤 3：Commit**

```bash
git add main/manager-web/src/components/DynamicBackground.vue
git commit -m "feat(web): upgrade DynamicBackground to aurora fluid"
```

---

## 任务 3：导航配置与问候语工具

**文件：**
- 新增：`main/manager-web/src/config/nav.config.js`
- 新增：`main/manager-web/src/utils/greeting.js`
- 新增：`main/manager-web/src/utils/greeting.spec.js`（可选，如项目无测试框架则跳过）
- 测试：手动验证导航映射正确，问候语按时间返回。

**规格摘要：**
- 将 `HeaderBar.vue` 中的 `routerPaths` 与菜单项抽取为独立配置 `nav.config.js`。
- 定义导航项数组，每项包含：`key`、`icon`、`titleKey`、`routeName`、`requiresSuperAdmin`、`featureKey`、`children`。
- `featureKey` 可选：`voiceClone`、`knowledgeBase`、`addressBook`。
- `greeting.js` 接收用户名，返回 `"早安，{name}"` / `"下午好，{name}"` / `"晚上好，{name}"`。

**步骤：**

- [ ] **步骤 1：创建 `nav.config.js`**

```js
// main/manager-web/src/config/nav.config.js
export const navItems = [
  { key: 'home', icon: 'el-icon-s-home', titleKey: 'sidebar.home', routeName: 'home' },
  { key: 'roleConfig', icon: 'el-icon-user', titleKey: 'sidebar.roleConfig', routeName: 'RoleConfig' },
  { key: 'deviceManagement', icon: 'el-icon-s-grid', titleKey: 'sidebar.deviceManagement', routeName: 'DeviceManagement' },
  { key: 'voiceClone', icon: 'el-icon-microphone', titleKey: 'sidebar.voiceClone', routeName: 'VoiceCloneManagement', featureKey: 'voiceClone' },
  { key: 'modelConfig', icon: 'el-icon-s-operation', titleKey: 'sidebar.modelConfig', routeName: 'ModelConfig', requiresSuperAdmin: true },
  { key: 'knowledgeBase', icon: 'el-icon-collection', titleKey: 'sidebar.knowledgeBase', routeName: 'KnowledgeBaseManagement', featureKey: 'knowledgeBase' },
  { key: 'addressBook', icon: 'el-icon-notebook-2', titleKey: 'sidebar.addressBook', routeName: 'AddressBookManagement', featureKey: 'addressBook' },
  {
    key: 'system',
    icon: 'el-icon-setting',
    titleKey: 'sidebar.system',
    requiresSuperAdmin: true,
    children: [
      { key: 'params', titleKey: 'sidebar.params', routeName: 'ParamsManagement' },
      { key: 'users', titleKey: 'sidebar.users', routeName: 'UserManagement' },
      { key: 'ota', titleKey: 'sidebar.ota', routeName: 'OtaManagement' },
      { key: 'dict', titleKey: 'sidebar.dict', routeName: 'DictManagement' },
      { key: 'provider', titleKey: 'sidebar.provider', routeName: 'ProviderManagement' },
      { key: 'roleTemplate', titleKey: 'sidebar.roleTemplate', routeName: 'AgentTemplateManagement' },
      { key: 'replacement', titleKey: 'sidebar.replacement', routeName: 'ReplacementWordManagement' },
      { key: 'server', titleKey: 'sidebar.server', routeName: 'ServerSideManager' },
      { key: 'feature', titleKey: 'sidebar.feature', routeName: 'FeatureManagement' }
    ]
  }
];
```

- [ ] **步骤 2：创建 `greeting.js`**

```js
// main/manager-web/src/utils/greeting.js
export function getGreeting(name = '') {
  const hour = new Date().getHours();
  let prefix;
  if (hour < 12) {
    prefix = 'greeting.morning';
  } else if (hour < 18) {
    prefix = 'greeting.afternoon';
  } else {
    prefix = 'greeting.evening';
  }
  return { prefixKey: prefix, name };
}

export function formatGreeting(t, name = '') {
  const { prefixKey } = getGreeting(name);
  return t('greeting.format', { greeting: t(prefixKey), name });
}
```

- [ ] **步骤 3：Commit**

```bash
git add main/manager-web/src/config/nav.config.js main/manager-web/src/utils/greeting.js
git commit -m "feat(web): add nav config and greeting utility"
```

---

## 任务 4：侧边栏导航组件 SidebarNav

**文件：**
- 新增：`main/manager-web/src/components/SidebarNav.vue`
- 测试：视觉审查，验证权限/功能开关过滤正确。

**规格摘要：**
- 宽度 56px，高度 100vh，固定左侧。
- 白色背景，右侧 1px `$color-hairline-soft` 分隔线。
- 顶部 Logo 图标（32×32px，圆角 8px），点击跳转 `/home`。
- 中部导航图标按钮，垂直排列，间距 12px。
- 图标状态：默认 36×36px 圆角 10px 透明背景 `$color-steel` 图标；hover 背景 `$color-surface-soft`；active 背景 `$color-primary` 白色图标。
- 系统管理项 hover 时显示 tooltip 或右侧浮出菜单（本次使用 Element `el-tooltip` 展示子项列表，点击子项跳转）。
- 从 Vuex 读取 `userInfo`、`featureStatus`；调用 `featureManager.waitForInitialization()`。

**步骤：**

- [ ] **步骤 1：创建 `SidebarNav.vue`**

```vue
<template>
  <aside class="sidebar-nav">
    <div class="sidebar-nav__logo" @click="goHome">
      <img src="@/assets/xiaozhi-logo.png" alt="logo" />
    </div>
    <nav class="sidebar-nav__menu">
      <el-tooltip
        v-for="item in visibleItems"
        :key="item.key"
        effect="dark"
        :content="$t(item.titleKey)"
        placement="right"
        :disabled="item.children && item.children.length"
      >
        <div
          :class="['sidebar-nav__item', { 'is-active': isActive(item) }]"
          @click="handleClick(item)"
        >
          <i :class="item.icon"></i>
        </div>
      </el-tooltip>
    </nav>
  </aside>
</template>

<script>
import { mapState } from 'vuex';
import { navItems } from '@/config/nav.config';
import featureManager from '@/utils/featureManager';

export default {
  name: 'SidebarNav',
  data() {
    return {
      initialized: false,
      items: navItems
    };
  },
  computed: {
    ...mapState(['userInfo', 'featureStatus']),
    visibleItems() {
      return this.items.filter(item => this.isVisible(item));
    }
  },
  async created() {
    await featureManager.waitForInitialization();
    this.initialized = true;
  },
  methods: {
    isVisible(item) {
      if (item.requiresSuperAdmin && !this.userInfo?.superAdmin) return false;
      if (item.featureKey && !this.featureStatus?.[item.featureKey]) return false;
      return true;
    },
    isActive(item) {
      if (item.children) {
        return item.children.some(child => child.routeName === this.$route.name);
      }
      return item.routeName === this.$route.name;
    },
    handleClick(item) {
      if (item.children && item.children.length) {
        // 系统管理：默认跳转到第一个子项
        this.$router.push({ name: item.children[0].routeName });
      } else if (item.routeName) {
        this.$router.push({ name: item.routeName });
      }
    },
    goHome() {
      this.$router.push({ name: 'home' });
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.sidebar-nav {
  position: fixed;
  top: 0;
  left: 0;
  width: 56px;
  height: 100vh;
  background: $color-canvas;
  border-right: 1px solid $color-hairline-soft;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: $spacing-md;
  z-index: 10;

  &__logo {
    width: 32px;
    height: 32px;
    border-radius: 8px;
    overflow: hidden;
    margin-bottom: $spacing-xl;
    cursor: pointer;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__menu {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  &__item {
    width: 36px;
    height: 36px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: $color-steel;
    font-size: 18px;
    cursor: pointer;
    transition: background-color 150ms ease, color 150ms ease;

    &:hover {
      background: $color-surface-soft;
    }

    &.is-active {
      background: $color-primary;
      color: $color-on-primary;
    }
  }
}
</style>
```

注意：系统管理子菜单处理可后续在 tooltip 中展示列表，为简化实现先跳转第一个子项。

- [ ] **步骤 2：Commit**

```bash
git add main/manager-web/src/components/SidebarNav.vue
git commit -m "feat(web): add SidebarNav component"
```

---

## 任务 5：面包屑与用户菜单组件 BreadcrumbBar

**文件：**
- 新增：`main/manager-web/src/components/BreadcrumbBar.vue`
- 测试：视觉审查，验证面包屑映射、用户菜单功能。

**规格摘要：**
- 高度 48px，白色背景，底部 1px `$color-hairline-soft` 分隔线。
- 左侧面包屑：基于 `$route.name` 映射为中文标签，静态映射表即可。
- 右侧：用户头像 + 用户名下拉（从 HeaderBar 迁移）。
- 下拉菜单包含：语言切换、修改密码、退出登录。

**步骤：**

- [ ] **步骤 1：创建 `BreadcrumbBar.vue`**

```vue
<template>
  <header class="breadcrumb-bar">
    <el-breadcrumb separator="/" class="breadcrumb-bar__crumb">
      <el-breadcrumb-item :to="{ name: 'home' }">{{ $t('breadcrumb.home') }}</el-breadcrumb-item>
      <el-breadcrumb-item v-if="currentTitle">{{ currentTitle }}</el-breadcrumb-item>
    </el-breadcrumb>

    <div class="breadcrumb-bar__right">
      <el-dropdown trigger="click" @command="handleCommand">
        <div class="user-trigger">
          <el-avatar :size="28" :src="userInfo?.avatar" icon="el-icon-user-solid"></el-avatar>
          <span class="user-name">{{ userInfo?.username || 'Admin' }}</span>
          <i class="el-icon-arrow-down"></i>
        </div>
        <el-dropdown-menu slot="dropdown">
          <el-dropdown-item command="language">{{ $t('user.language') }}</el-dropdown-item>
          <el-dropdown-item command="password">{{ $t('user.changePassword') }}</el-dropdown-item>
          <el-dropdown-item divided command="logout">{{ $t('user.logout') }}</el-dropdown-item>
        </el-dropdown-menu>
      </el-dropdown>
    </div>
  </header>
</template>

<script>
import { mapState } from 'vuex';

const titleMap = {
  home: 'breadcrumb.dashboard',
  RoleConfig: 'breadcrumb.roleConfig',
  DeviceManagement: 'breadcrumb.deviceManagement',
  UserManagement: 'breadcrumb.userManagement',
  ModelConfig: 'breadcrumb.modelConfig',
  KnowledgeBaseManagement: 'breadcrumb.knowledgeBase',
  ServerSideManager: 'breadcrumb.server',
  OtaManagement: 'breadcrumb.ota',
  VoiceResourceManagement: 'breadcrumb.voiceResource',
  VoiceCloneManagement: 'breadcrumb.voiceClone',
  DictManagement: 'breadcrumb.dict',
  ProviderManagement: 'breadcrumb.provider',
  AgentTemplateManagement: 'breadcrumb.roleTemplate',
  TemplateQuickConfig: 'breadcrumb.templateQuickConfig',
  FeatureManagement: 'breadcrumb.feature',
  ReplacementWordManagement: 'breadcrumb.replacement',
  AddressBookManagement: 'breadcrumb.addressBook',
  VoicePrint: 'breadcrumb.voicePrint',
  ParamsManagement: 'breadcrumb.params'
};

export default {
  name: 'BreadcrumbBar',
  computed: {
    ...mapState(['userInfo']),
    currentTitle() {
      const key = titleMap[this.$route.name];
      return key ? this.$t(key) : '';
    }
  },
  methods: {
    handleCommand(cmd) {
      if (cmd === 'logout') {
        this.$confirm(this.$t('user.logoutConfirm'), this.$t('tip'), {
          confirmButtonText: this.$t('button.ok'),
          cancelButtonText: this.$t('button.cancel'),
          type: 'warning'
        }).then(() => {
          localStorage.removeItem('token');
          localStorage.removeItem('userInfo');
          this.$router.push({ name: 'login' });
        });
      } else if (cmd === 'password') {
        this.$emit('change-password');
      } else if (cmd === 'language') {
        this.$emit('change-language');
      }
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.breadcrumb-bar {
  position: fixed;
  top: 0;
  left: 56px;
  right: 0;
  height: 48px;
  background: $color-canvas;
  border-bottom: 1px solid $color-hairline-soft;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 $spacing-xl;
  z-index: 9;

  &__crumb {
    font-size: 14px;
  }

  &__right {
    .user-trigger {
      display: flex;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      padding: 4px 8px;
      border-radius: $rounded-lg;
      transition: background-color 150ms ease;

      &:hover {
        background: $color-surface-soft;
      }
    }

    .user-name {
      font-size: 14px;
      color: $color-ink-deep;
    }
  }
}
</style>
```

- [ ] **步骤 2：Commit**

```bash
git add main/manager-web/src/components/BreadcrumbBar.vue
git commit -m "feat(web): add BreadcrumbBar with user menu"
```

---

## 任务 6：全局布局组件 MainLayout

**文件：**
- 新增：`main/manager-web/src/layouts/MainLayout.vue`
- 修改：`main/manager-web/src/App.vue`
- 测试：构建通过，路由切换后侧边栏/面包屑正确渲染。

**规格摘要：**
- `MainLayout` 组合 `SidebarNav` + `BreadcrumbBar` + `<router-view/>`。
- 内容区位于面包屑下方、侧边栏右侧，可滚动，内边距 `$spacing-xl`。
- `App.vue` 按当前路由决定渲染 `MainLayout` 还是直接渲染 `router-view`（登录/注册/找回密码不使用布局）。

**步骤：**

- [ ] **步骤 1：创建 `MainLayout.vue`**

```vue
<template>
  <div class="main-layout">
    <DynamicBackground variant="management" />
    <SidebarNav />
    <BreadcrumbBar />
    <main class="main-layout__content">
      <router-view />
    </main>
  </div>
</template>

<script>
import DynamicBackground from '@/components/DynamicBackground.vue';
import SidebarNav from '@/components/SidebarNav.vue';
import BreadcrumbBar from '@/components/BreadcrumbBar.vue';

export default {
  name: 'MainLayout',
  components: { DynamicBackground, SidebarNav, BreadcrumbBar }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.main-layout {
  min-height: 100vh;
  position: relative;

  &__content {
    position: relative;
    z-index: 1;
    margin-left: 56px;
    margin-top: 48px;
    min-height: calc(100vh - 48px);
    padding: $spacing-xl;
    overflow-y: auto;
  }
}
</style>
```

- [ ] **步骤 2：修改 `App.vue`**

```vue
<template>
  <div id="app">
    <MainLayout v-if="useLayout" />
    <router-view v-else />
    <cache-viewer v-if="isCDNEnabled" :visible.sync="showCacheViewer" />
  </div>
</template>

<script>
import MainLayout from '@/layouts/MainLayout.vue';

const layoutExcludes = ['login', 'register', 'retrievePassword', 'welcome'];

export default {
  name: 'App',
  components: { MainLayout },
  data() {
    return {
      showCacheViewer: false,
      isCDNEnabled: process.env.VUE_APP_USE_CDN === 'true'
    };
  },
  computed: {
    useLayout() {
      return !layoutExcludes.includes(this.$route.name);
    }
  },
  created() {
    const userInfo = localStorage.getItem('userInfo');
    const pubConfig = localStorage.getItem('pubConfig');
    if (userInfo) {
      this.$store.commit('setUserInfo', JSON.parse(userInfo));
    }
    if (pubConfig) {
      this.$store.commit('setPubConfig', JSON.parse(pubConfig));
    }
    document.addEventListener('keydown', this.handleKeydown);
  },
  beforeDestroy() {
    document.removeEventListener('keydown', this.handleKeydown);
  },
  methods: {
    handleKeydown(e) {
      if (e.altKey && e.key === 'c' && this.isCDNEnabled) {
        this.showCacheViewer = true;
      }
    }
  }
};
</script>
```

保留原有 CDN/cache-viewer 逻辑。

- [ ] **步骤 3：构建验证**

```bash
cd main/manager-web && npm run build
```

- [ ] **步骤 4：Commit**

```bash
git add main/manager-web/src/layouts/MainLayout.vue main/manager-web/src/App.vue
git commit -m "feat(web): add MainLayout and conditional layout rendering"
```

---

## 任务 7：路由改造

**文件：**
- 修改：`main/manager-web/src/router/index.js`
- 测试：运行 `npm run build`，手动验证受保护页面能正常进入。

**规格摘要：**
- 引入 `MainLayout`。
- 将所有受保护内页改为 `MainLayout` 的 children，路径保持不变。
- 路由守卫使用 `meta.requiresAuth` 替代硬编码 `protectedRoutes` 数组（保留兼容）。

**步骤：**

- [ ] **步骤 1：重构路由定义**

示例修改（保留其他路由）：

```js
import Vue from 'vue';
import VueRouter from 'vue-router';
import MainLayout from '@/layouts/MainLayout.vue';

Vue.use(VueRouter);

const routes = [
  { path: '/', redirect: '/login' },
  { path: '/login', name: 'login', component: () => import('@/views/login.vue') },
  { path: '/register', name: 'register', component: () => import('@/views/register.vue') },
  { path: '/retrieve-password', name: 'retrievePassword', component: () => import('@/views/retrievePassword.vue') },
  {
    path: '/home',
    component: MainLayout,
    children: [
      { path: '', name: 'home', component: () => import('@/views/home.vue'), meta: { requiresAuth: true } }
    ]
  },
  {
    path: '/role-config',
    component: MainLayout,
    children: [
      { path: '', name: 'RoleConfig', component: () => import('@/views/roleConfig.vue'), meta: { requiresAuth: true } }
    ]
  },
  {
    path: '/device-management',
    component: MainLayout,
    children: [
      { path: '', name: 'DeviceManagement', component: () => import('@/views/DeviceManagement.vue'), meta: { requiresAuth: true } }
    ]
  },
  // ... 其他受保护路由按同样模式改造
];
```

- [ ] **步骤 2：更新路由守卫**

```js
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token');
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth);
  if (requiresAuth && !token) {
    next({ name: 'login', query: { redirect: to.fullPath } });
  } else if ((to.name === 'login' || to.name === 'register') && token) {
    next({ name: 'home' });
  } else {
    next();
  }
});
```

- [ ] **步骤 3：构建验证**

```bash
cd main/manager-web && npm run build
```

- [ ] **步骤 4：Commit**

```bash
git add main/manager-web/src/router/index.js
git commit -m "feat(web): wrap protected routes with MainLayout"
```

---

## 任务 8：登录页分屏重设计

**文件：**
- 修改：`main/manager-web/src/views/login.vue`
- 修改：`main/manager-web/src/views/auth.scss`（必要时调整，避免破坏注册/找回密码页）
- 测试：视觉审查，验证表单功能（登录、语言切换、链接跳转）。

**规格摘要：**
- 全屏 `DynamicBackground variant="login"`。
- 左右分屏：左侧 55–60% 品牌视觉区，右侧 40–45% 玻璃登录表单。
- 左侧：Logo + "云枢" + "智能语音硬件管理平台" + Slogan + 浮动 blob。
- 右侧：`glass-card`，最大宽度 420px，欢迎图标 + "登录" + "欢迎回来" + 表单。
- 输入框：统一高度 48px，圆角 `$rounded-lg`，背景 rgba(255,255,255,0.6)，focus 边框 + 外发光。
- 登录按钮：48px 高，`$color-ink-button` 背景，白色文字，`$rounded-full`，全宽，hover 上浮。
- 页面加载动画：左侧文字从下方淡入，右侧表单从右侧淡入。

**步骤：**

- [ ] **步骤 1：重写 `login.vue` 模板与样式**

保留原有登录逻辑（data、methods、表单字段），仅调整模板结构和样式。新模板骨架：

```vue
<template>
  <div class="login-page">
    <DynamicBackground variant="login" />
    <div class="login-page__container">
      <section class="login-page__visual">
        <div class="brand">
          <img src="@/assets/xiaozhi-ai.png" class="brand__logo" alt="logo" />
          <span class="brand__name">云枢</span>
        </div>
        <h1 class="brand__title">{{ $t('login.brandTitle') }}</h1>
        <p class="brand__slogan">{{ $t('login.brandSlogan') }}</p>
        <div class="floating-blobs">
          <div v-for="i in 3" :key="i" class="floating-blobs__item"></div>
        </div>
      </section>

      <section class="login-page__form">
        <div class="glass-card login-card">
          <div class="login-card__header">
            <img src="@/assets/hi.png" class="login-card__icon" alt="hi" />
            <div>
              <h2>{{ $t('login.title') }}</h2>
              <p>{{ $t('login.welcomeBack') }}</p>
            </div>
          </div>
          <!-- 保留原有 el-form，但调整 class -->
          <el-form ...>
            ...
          </el-form>
        </div>
      </section>
    </div>
    <VersionFooter />
  </div>
</template>
```

样式关键片段（写在 `<style lang="scss" scoped>`）：

```scss
@import "@/styles/tokens";

.login-page {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;

  &__container {
    position: relative;
    z-index: 1;
    display: flex;
    width: 100%;
    min-height: 100vh;
  }

  &__visual {
    flex: 0 0 58%;
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 0 80px;
    color: $color-on-primary;
    position: relative;
    overflow: hidden;
    animation: slide-up 600ms ease-out forwards;
  }

  &__form {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: $spacing-xl;
    animation: slide-in-right 500ms ease-out 100ms forwards;
    opacity: 0;
  }
}

.login-card {
  width: 100%;
  max-width: 420px;
  padding: $spacing-xxl;
}

@keyframes slide-up {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes slide-in-right {
  from { opacity: 0; transform: translateX(20px); }
  to { opacity: 1; transform: translateX(0); }
}
```

- [ ] **步骤 2：验证注册/找回密码页未被破坏**

```bash
cd main/manager-web && npm run build
```

- [ ] **步骤 3：Commit**

```bash
git add main/manager-web/src/views/login.vue main/manager-web/src/views/auth.scss
git commit -m "feat(web): redesign login page with split-screen layout"
```

---

## 任务 9：统计卡片、欢迎横幅、空状态组件

**文件：**
- 新增：`main/manager-web/src/components/StatCard.vue`
- 新增：`main/manager-web/src/components/WelcomeBanner.vue`
- 新增：`main/manager-web/src/components/EmptyAgentState.vue`
- 测试：视觉审查，验证组件渲染与动效。

**规格摘要：**

`StatCard`：
- 白色背景，`$rounded-xl`，阴影 `0 2px 8px rgba(0,0,0,0.04)`。
- 左侧 40×40px 图标容器，背景 `$color-surface-soft`，图标色 `$color-primary`。
- 右侧数字 + 标签。

`WelcomeBanner`：
- 高度 160–200px，圆角 `$rounded-xxxl`，渐变背景。
- 左侧问候语 + 状态摘要。
- 右侧装饰性 blob。
- 时间问候：使用 `greeting.js`。

`EmptyAgentState`：
- 插画 + "暂无智能体" + CTA 按钮。

**步骤：**

- [ ] **步骤 1：创建 `StatCard.vue`**

```vue
<template>
  <div class="surface-card stat-card fade-in-up" :class="`stagger-${index}`">
    <div class="stat-card__icon">
      <i :class="icon"></i>
    </div>
    <div class="stat-card__body">
      <div class="stat-card__value">{{ value }}</div>
      <div class="stat-card__label">{{ label }}</div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'StatCard',
  props: {
    icon: { type: String, required: true },
    value: { type: [String, Number], required: true },
    label: { type: String, required: true },
    index: { type: Number, default: 1 }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.stat-card {
  display: flex;
  align-items: center;
  gap: $spacing-md;
  padding: $spacing-lg $spacing-xl;

  &__icon {
    width: 40px;
    height: 40px;
    border-radius: $rounded-lg;
    background: $color-surface-soft;
    color: $color-primary;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
  }

  &__value {
    font-size: 24px;
    font-weight: 700;
    color: $color-ink-deep;
    line-height: 1.2;
  }

  &__label {
    font-size: 14px;
    color: $color-steel;
  }
}
</style>
```

- [ ] **步骤 2：创建 `WelcomeBanner.vue`**

```vue
<template>
  <section class="welcome-banner fade-in-up">
    <div class="welcome-banner__content">
      <h2 class="welcome-banner__greeting">{{ greeting }}</h2>
      <p class="welcome-banner__summary">{{ summary }}</p>
    </div>
    <div class="welcome-banner__blobs">
      <div v-for="i in 3" :key="i" class="welcome-banner__blob"></div>
    </div>
  </section>
</template>

<script>
import { formatGreeting } from '@/utils/greeting';

export default {
  name: 'WelcomeBanner',
  props: {
    username: { type: String, default: 'Admin' },
    summary: { type: String, default: '' }
  },
  computed: {
    greeting() {
      return formatGreeting(this.$t.bind(this), this.username);
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.welcome-banner {
  position: relative;
  height: 180px;
  border-radius: $rounded-xxxl;
  background: linear-gradient(135deg, $color-primary-deep 0%, $color-primary-soft 100%);
  color: $color-on-primary;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 $spacing-xxl;
  overflow: hidden;
  margin-bottom: $spacing-xl;

  &__greeting {
    font-size: 28px;
    font-weight: 700;
    margin-bottom: $spacing-sm;
  }

  &__summary {
    font-size: 16px;
    opacity: 0.9;
  }

  &__blob {
    position: absolute;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.25);
    filter: blur(40px);
    animation: banner-blob-float 14s ease-in-out infinite;
  }
}

@keyframes banner-blob-float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(30px, -30px) scale(1.1); }
}
</style>
```

- [ ] **步骤 3：创建 `EmptyAgentState.vue`**

```vue
<template>
  <div class="empty-agent-state">
    <img src="@/assets/empty-device.png" alt="empty" />
    <p>{{ $t('home.emptyAgentTip') }}</p>
    <button class="primary-btn" @click="$emit('add')">{{ $t('home.addAgent') }}</button>
  </div>
</template>

<style lang="scss" scoped>
@import "@/styles/tokens";

.empty-agent-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: $spacing-xxl;
  color: $color-steel;

  img {
    width: 160px;
    margin-bottom: $spacing-lg;
  }

  .primary-btn {
    margin-top: $spacing-lg;
    height: 44px;
    padding: 0 $spacing-xl;
    border-radius: $rounded-full;
    background: $color-ink-button;
    color: $color-on-primary;
    border: none;
    cursor: pointer;
    transition: transform 150ms ease, box-shadow 150ms ease;

    &:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }
  }
}
</style>
```

- [ ] **步骤 4：Commit**

```bash
git add main/manager-web/src/components/StatCard.vue main/manager-web/src/components/WelcomeBanner.vue main/manager-web/src/components/EmptyAgentState.vue
git commit -m "feat(web): add StatCard, WelcomeBanner, EmptyAgentState components"
```

---

## 任务 10：首页仪表盘改造

**文件：**
- 修改：`main/manager-web/src/views/home.vue`
- 修改：`main/manager-web/src/components/DeviceItem.vue`
- 测试：视觉审查，验证统计数据正确、设备列表正常、搜索功能保留。

**规格摘要：**
- 移除 `HeaderBar` 导入。
- 使用 `WelcomeBanner` + 4 列 `StatCard` 网格 + "我的智能体" 标题行 + 设备网格。
- 统计项：智能体数量、设备数量、在线设备数、模型配置数（从 `agentList` 派生）。
- 搜索框保留在首页标题区下方（辅助搜索）。
- `DeviceItem` 增加 stagger 入场动画与 hover 上浮。

**步骤：**

- [ ] **步骤 1：重写 `home.vue` 模板**

```vue
<template>
  <div class="home-page">
    <WelcomeBanner :username="userInfo?.username" :summary="statusSummary" />

    <div class="stat-grid">
      <StatCard
        v-for="(stat, idx) in stats"
        :key="stat.key"
        :icon="stat.icon"
        :value="stat.value"
        :label="stat.label"
        :index="idx + 1"
      />
    </div>

    <section class="agent-section">
      <div class="agent-section__header">
        <h3>{{ $t('home.myAgents') }}</h3>
        <button class="primary-btn" @click="addAgent">
          <i class="el-icon-plus"></i> {{ $t('home.addAgent') }}
        </button>
      </div>

      <div class="search-bar">
        <el-input
          v-model="searchKeyword"
          :placeholder="$t('header.searchPlaceholder')"
          prefix-icon="el-icon-search"
          clearable
          class="search-input"
          @keyup.enter.native="handleSearch"
          @clear="handleSearchReset"
        />
      </div>

      <EmptyAgentState v-if="!loading && devices.length === 0" @add="addAgent" />

      <div v-else class="device-list">
        <DeviceItem
          v-for="(device, idx) in devices"
          :key="device.id"
          :device="device"
          :style="{ animationDelay: `${idx * 60}ms` }"
          class="fade-in-up"
          @configure="handleConfigure"
          @deviceManage="handleDeviceManage"
          @delete="handleDelete"
          @chat-history="handleChatHistory"
        />
      </div>
    </section>
  </div>
</template>
```

- [ ] **步骤 2：修改 script 计算统计**

```js
import WelcomeBanner from '@/components/WelcomeBanner.vue';
import StatCard from '@/components/StatCard.vue';
import EmptyAgentState from '@/components/EmptyAgentState.vue';
import DeviceItem from '@/components/DeviceItem.vue';
import Api from '@/apis/api';

export default {
  name: 'Home',
  components: { WelcomeBanner, StatCard, EmptyAgentState, DeviceItem },
  data() {
    return {
      devices: [],
      originalDevices: [],
      loading: false,
      searchKeyword: ''
    };
  },
  computed: {
    stats() {
      const agentCount = this.devices.length;
      const deviceCount = this.devices.reduce((sum, d) => sum + (d.deviceCount || 0), 0);
      const onlineCount = this.devices.filter(d => {
        if (typeof d.online === 'boolean') return d.online;
        const lastConnect = d.lastConnectedAt ? new Date(d.lastConnectedAt) : null;
        return lastConnect && (Date.now() - lastConnect.getTime()) < 24 * 60 * 60 * 1000;
      }).length;
      const modelSet = new Set();
      this.devices.forEach(d => {
        if (d.llmModelName) modelSet.add(d.llmModelName);
        if (d.ttsModelName) modelSet.add(d.ttsModelName);
      });
      return [
        { key: 'agents', icon: 'el-icon-s-custom', value: agentCount, label: this.$t('home.statAgents') },
        { key: 'devices', icon: 'el-icon-s-grid', value: deviceCount, label: this.$t('home.statDevices') },
        { key: 'online', icon: 'el-icon-success', value: onlineCount, label: this.$t('home.statOnline') },
        { key: 'models', icon: 'el-icon-s-operation', value: modelSet.size, label: this.$t('home.statModels') }
      ];
    },
    statusSummary() {
      return this.$t('home.statusSummary', {
        online: this.stats.find(s => s.key === 'online').value,
        active: this.stats.find(s => s.key === 'agents').value
      });
    }
  },
  // ... 保留 fetchAgentList、handleSearch、handleSearchReset 等方法
};
```

- [ ] **步骤 3：更新样式**

```scss
@import "@/styles/tokens";

.home-page {
  max-width: 1440px;
  margin: 0 auto;
}

.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: $spacing-xl;
  margin-bottom: $spacing-xl;

  @media (max-width: 1024px) {
    grid-template-columns: repeat(2, 1fr);
  }
}

.agent-section {
  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: $spacing-lg;

    h3 {
      font-size: 20px;
      font-weight: 700;
      color: $color-ink-deep;
    }
  }
}

.search-bar {
  margin-bottom: $spacing-lg;

  .search-input {
    width: 360px;
    height: 40px;

    ::v-deep .el-input__inner {
      height: 40px;
      border-radius: $rounded-full;
      background: $color-surface-soft;
      border: none;
      padding-left: 40px;
    }
  }
}

.device-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
  gap: $spacing-xl;
}

.primary-btn {
  height: 40px;
  padding: 0 $spacing-lg;
  border-radius: $rounded-full;
  background: $color-ink-button;
  color: $color-on-primary;
  border: none;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  transition: transform 150ms ease, box-shadow 150ms ease;

  &:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }
}
```

- [ ] **步骤 4：增强 `DeviceItem.vue` 动效**

为 `.device-item` 添加：

```scss
.device-item {
  transition: transform 200ms ease-out, box-shadow 200ms ease-out;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
  }
}
```

并确保 `opacity: 0` 配合 `.fade-in-up` 类工作。

- [ ] **步骤 5：构建验证**

```bash
cd main/manager-web && npm run build
```

- [ ] **步骤 6：Commit**

```bash
git add main/manager-web/src/views/home.vue main/manager-web/src/components/DeviceItem.vue
git commit -m "feat(web): redesign home page as dashboard"
```

---

## 任务 11：i18n 文案补充

**文件：**
- 修改：`main/manager-web/src/i18n/zh_CN.js`
- 修改：`main/manager-web/src/i18n/en.js`
- 可选：`main/manager-web/src/i18n/zh_TW.js`、`de.js`、`vi.js`、`pt_BR.js` 同步添加英文 key 占位
- 测试：构建通过，切换语言后新文案不显示 key。

**规格摘要：**
- 新增 `sidebar.*`、`breadcrumb.*`、`greeting.*`、`login.brandTitle`、`login.brandSlogan`、`login.welcomeBack`、`home.stat*`、`home.myAgents`、`home.emptyAgentTip`、`home.statusSummary`、`user.*` 等 key。
- 所有新增文案至少补充 `zh_CN` 和 `en`。

**步骤：**

- [ ] **步骤 1：在 `zh_CN.js` 中新增**

```js
sidebar: {
  home: '首页',
  voiceClone: '音色克隆',
  modelConfig: '模型配置',
  knowledgeBase: '知识库',
  addressBook: '通讯录',
  system: '系统管理',
  params: '参数管理',
  users: '用户管理',
  ota: 'OTA',
  dict: '字典管理',
  provider: '提供者管理',
  roleTemplate: '角色模板',
  replacement: '替换词',
  server: '服务端管理',
  feature: '功能配置'
},
breadcrumb: {
  home: '首页',
  dashboard: '仪表盘',
  roleConfig: '角色配置',
  deviceManagement: '设备管理',
  userManagement: '用户管理',
  modelConfig: '模型配置',
  knowledgeBase: '知识库',
  server: '服务端管理',
  ota: 'OTA 管理',
  voiceResource: '音色资源',
  voiceClone: '音色克隆',
  dict: '字典管理',
  provider: '提供者管理',
  roleTemplate: '角色模板',
  templateQuickConfig: '快速配置',
  feature: '功能配置',
  replacement: '替换词管理',
  addressBook: '通讯录',
  voicePrint: '声纹管理',
  params: '参数管理'
},
greeting: {
  morning: '早安',
  afternoon: '下午好',
  evening: '晚上好',
  format: '{greeting}，{name}'
},
login: {
  brandTitle: '智能语音硬件管理平台',
  brandSlogan: '连接设备、配置智能体、管理模型，一句话掌控全局。',
  welcomeBack: '欢迎回来'
},
home: {
  myAgents: '我的智能体',
  statAgents: '智能体数量',
  statDevices: '设备数量',
  statOnline: '在线设备',
  statModels: '模型配置',
  statusSummary: '今日 {online} 台设备在线，{active} 个智能体活跃',
  emptyAgentTip: '暂无智能体，点击添加'
},
user: {
  language: '切换语言',
  changePassword: '修改密码',
  logout: '退出登录',
  logoutConfirm: '确定要退出登录吗？'
}
```

- [ ] **步骤 2：在 `en.js` 中新增对应英文翻译**

```js
sidebar: {
  home: 'Home',
  voiceClone: 'Voice Clone',
  modelConfig: 'Model Config',
  knowledgeBase: 'Knowledge Base',
  addressBook: 'Address Book',
  system: 'System',
  params: 'Parameters',
  users: 'Users',
  ota: 'OTA',
  dict: 'Dictionary',
  provider: 'Providers',
  roleTemplate: 'Role Templates',
  replacement: 'Replacement Words',
  server: 'Server',
  feature: 'Features'
},
breadcrumb: {
  home: 'Home',
  dashboard: 'Dashboard',
  roleConfig: 'Role Config',
  deviceManagement: 'Devices',
  userManagement: 'Users',
  modelConfig: 'Model Config',
  knowledgeBase: 'Knowledge Base',
  server: 'Server',
  ota: 'OTA',
  voiceResource: 'Voice Resources',
  voiceClone: 'Voice Clone',
  dict: 'Dictionary',
  provider: 'Providers',
  roleTemplate: 'Role Templates',
  templateQuickConfig: 'Quick Config',
  feature: 'Features',
  replacement: 'Replacement Words',
  addressBook: 'Address Book',
  voicePrint: 'Voice Print',
  params: 'Parameters'
},
greeting: {
  morning: 'Good morning',
  afternoon: 'Good afternoon',
  evening: 'Good evening',
  format: '{greeting}, {name}'
},
login: {
  brandTitle: 'AI Voice Hardware Management Platform',
  brandSlogan: 'Connect devices, configure agents, manage models — all in one sentence.',
  welcomeBack: 'Welcome back'
},
home: {
  myAgents: 'My Agents',
  statAgents: 'Agents',
  statDevices: 'Devices',
  statOnline: 'Online',
  statModels: 'Models',
  statusSummary: '{online} devices online today, {active} agents active',
  emptyAgentTip: 'No agents yet, click to add'
},
user: {
  language: 'Language',
  changePassword: 'Change Password',
  logout: 'Logout',
  logoutConfirm: 'Are you sure you want to logout?'
}
```

- [ ] **步骤 3：构建验证**

```bash
cd main/manager-web && npm run build
```

- [ ] **步骤 4：Commit**

```bash
git add main/manager-web/src/i18n/
git commit -m "feat(web): add i18n strings for new layout and dashboard"
```

---

## 任务 12：移除旧 HeaderBar 并修复内页样式

**文件：**
- 修改：`main/manager-web/src/components/HeaderBar.vue`
- 修改：所有受保护内页（`RoleConfig.vue`、`DeviceManagement.vue`、`UserManagement.vue`、`ModelConfig.vue`、`KnowledgeBaseManagement.vue`、`ServerSideManager.vue`、`OtaManagement.vue`、`VoiceResourceManagement.vue`、`VoiceCloneManagement.vue`、`DictManagement.vue`、`ProviderManagement.vue`、`AgentTemplateManagement.vue`、`TemplateQuickConfig.vue`、`FeatureManagement.vue`、`ReplacementWordManagement.vue`、`AddressBookManagement.vue`、`VoicePrint.vue`、`ParamsManagement.vue` 等）
- 测试：构建通过，每个页面在 MainLayout 中正常显示，无重复导航。

**规格摘要：**
- 将各内页中的 `<HeaderBar />` 导入和模板移除。
- 检查并移除各页面中为 HeaderBar 预留的 `margin-top` 或 `padding-top`。
- `HeaderBar.vue` 暂时保留文件但清空模板/样式或标记为 deprecated，避免其他引用报错；也可在确认无引用后删除。

**步骤：**

- [ ] **步骤 1：批量移除 HeaderBar 引用**

对每个受保护页面执行以下模式替换：

删除：
```js
import HeaderBar from '@/components/HeaderBar.vue';
```

删除组件注册：
```js
components: { HeaderBar, ... }
```

删除模板中的：
```vue
<HeaderBar />
```

- [ ] **步骤 2：调整页面根样式**

如果页面根元素有 `margin-top: 63px` 或类似为旧 HeaderBar 预留的样式，移除或改为 `padding: $spacing-xl`。

- [ ] **步骤 3：处理 HeaderBar.vue**

暂时保留文件，修改内容为：

```vue
<template>
  <!-- HeaderBar has been migrated to SidebarNav + BreadcrumbBar. Kept for backward compatibility. -->
</template>
<script>
export default { name: 'HeaderBar' };
</script>
```

- [ ] **步骤 4：构建验证**

```bash
cd main/manager-web && npm run build
```

- [ ] **步骤 5：Commit**

```bash
git add main/manager-web/src/
git commit -m "feat(web): remove HeaderBar usage and adapt inner pages to MainLayout"
```

---

## 任务 13：最终验证与收尾

**文件：**
- 全部改动文件
- 测试：验收标准检查

**验收标准：**
- [ ] 登录页呈现左半屏动态视觉区 + 右半屏玻璃登录表单，背景极光流动。
- [ ] 首页呈现左侧浅色边栏、顶部面包屑、动态欢迎横幅、4 个统计卡片、设备网格。
- [ ] 所有内页继承新的全局导航框架（侧边栏 + 面包屑）。
- [ ] 动态背景组件支持 `login` / `management` 两种变体，且支持 reduced motion。
- [ ] 所有新增/修改组件在 Chrome、Edge、Firefox 最新版正常显示。
- [ ] 页面加载时无 layout shift，动画流畅（60fps）。
- [ ] 多语言文案完整，无硬编码中文。
- [ ] `npm run build` 无新增错误和严重警告。

**步骤：**

- [ ] **步骤 1：运行生产构建**

```bash
cd main/manager-web && npm run build
```

预期：Build complete，无 ERROR，无新增 warning。

- [ ] **步骤 2：运行开发服务器抽查（可选）**

```bash
cd main/manager-web && npm run serve
```

- [ ] **步骤 3：提交所有剩余变更**

```bash
git add -A
git commit -m "feat(web): complete web frontend redesign"
```

- [ ] **步骤 4：最终代码审查**

派遣代码审查子智能体审查整体实现。

---
