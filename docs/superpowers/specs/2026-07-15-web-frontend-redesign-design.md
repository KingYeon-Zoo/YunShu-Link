# Web 控制台前端美化改造设计规格

**日期：** 2026-07-15  
**主题：** manager-web 登录页、首页及全局导航框架视觉升级  
**状态：** 待实现  

## 1. 概述

### 1.1 背景

YunShu-Link 的 Web 控制台（`main/manager-web`，Vue 2 + Element UI）已完成一轮 Meta 设计系统的基础改造：引入了 token 化样式、玻璃拟态卡片、极光 blob 动态背景等。但当前页面仍存在以下可优化点：

- 顶部 pill 导航在页面增多后显得拥挤，不够符合管理后台心智模型。
- 首页信息层级不够清晰，缺少仪表盘常见的统计概览。
- 登录页视觉表现力可进一步提升，与品牌首屏表达结合更紧密。
- 动态背景较为简单，可升级为更细腻、更具品牌感的极光流体效果。

### 1.2 目标

- 将 `manager-web` 升级为**现代 SaaS 管理后台**视觉风格。
- 参考 Kimi AI 首页的简洁大卡片/大留白语言，同时保留管理系统的信息结构。
- 整体遵循 `docs/superpowers/DESIGN-meta.md` 的 Meta 设计系统。
- 增加精致、克制的动效，提升品质感而不干扰操作。

### 1.3 范围

| 范围项 | 包含 | 不包含 |
|---|---|---|
| 前端项目 | `main/manager-web` | `main/manager-mobile` |
| 页面 | 登录页（`login.vue`）<br>首页（`home.vue`） | 注册页、找回密码页（保持现有风格，不主动降级） |
| 全局框架 | 左侧浅色边栏导航<br>顶部面包屑<br>用户菜单 | 移动端适配重构 |
| 视觉系统 | 极光流体动态背景<br>玻璃拟态卡片<br>Meta 圆角/字体/间距 | 深色模式 |
| 动效 | 背景流动、卡片入场、按钮/链接反馈、页面过渡 | 复杂 3D、视频背景 |

### 1.4 用户决策摘要

| 决策点 | 选择 |
|---|---|
| 改造前端 | A. 只改造 `manager-web` |
| 改造页面 | B. 登录页 + 首页 + 全局导航框架 |
| 首页定位 | B. 管理系统风格仪表盘 |
| 全局导航 | B. 左侧浅色边栏 + 内容区面包屑 |
| 动态背景 | A. 极光流体（柔和渐变 blob 缓慢流动、融合） |
| 首页布局 | C. 极简门户：大面积动态欢迎横幅 + 统计卡片 + 设备网格 |
| 登录页布局 | C 变体：左半屏动态视觉区 + 右半屏玻璃登录表单 |

## 2. 设计原则

1. **白色画布 + 钴蓝强调**：页面背景以 `{colors.canvas}` 白色为主，主色 `$color-primary: #3375fd` 用于关键操作和动态视觉区；严格遵循 Meta 系统中"钴蓝只用于 buy-now/关键 CTA"的克制用法。
2. **大圆角 + 柔和阴影**：卡片统一使用 `$rounded-xxxl`（32px）或 `$rounded-xl`（16px）；阴影使用 `$shadow-dialog` 或更 subtle 的 `0 2px 8px rgba(0,0,0,0.04)`。
3. **玻璃拟态**：登录页表单区、部分卡片使用 `backdrop-filter: blur(16px)` 配合半透明白色背景。
4. **动效克制**：所有动画使用 `prefers-reduced-motion` 降级；背景动画周期 15–25s，UI 反馈 150–250ms。
5. **信息层级清晰**：首页通过"欢迎横幅 → 统计卡片 → 设备网格"三层结构，让管理员快速获取状态。

## 3. 全局视觉系统

### 3.1 颜色

沿用 `main/manager-web/src/styles/_tokens.scss` 中的 token，关键值：

| Token | 值 | 用途 |
|---|---|---|
| `$color-primary` | `#3375fd` | 主按钮、动态视觉区渐变起点 |
| `$color-primary-soft` | `#5778ff` | 视觉区渐变中间色 |
| `$color-primary-deep` | `#0064e0` | 按下态、强调 |
| `$color-canvas` | `#ffffff` | 页面背景、卡片表面 |
| `$color-surface-soft` | `#f1f4f7` | 侧边栏、统计卡片图标背景 |
| `$color-glass-bg` | `rgba(255,255,255,0.72)` | 玻璃卡片背景 |
| `$color-glass-border` | `rgba(255,255,255,0.6)` | 玻璃边框 |
| `$color-ink-deep` | `#0a1317` | 主标题、深色按钮 |
| `$color-steel` | `#5d6c7b` | 辅助文字 |

### 3.2 字体

沿用 `$font-family-base: "Inter", "Noto Sans SC", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`。

| 用途 | Token | 示例 |
|---|---|---|
| 登录页品牌大标题 | `$font-display-lg` | "智能语音硬件管理平台" |
| 首页欢迎语 | `$font-heading-lg` | "早安，Admin" |
| 卡片标题 | `$font-subtitle-lg` | 设备名称 |
| 正文/标签 | `$font-body-md` / `$font-body-sm` | 统计数字、辅助说明 |
| 按钮 | `$font-body-sm-bold` | 胶囊按钮 |

### 3.3 间距与圆角

- 页面内边距：`$spacing-xl`（24px）
- 卡片内边距：`$spacing-xxl`（32px）
- 卡片间隙：`$spacing-xl`（24px）
- 圆角：大卡片 `$rounded-xxxl`（32px），小卡片/按钮 `$rounded-xl`（16px）/ `$rounded-full`（100px）

### 3.4 玻璃拟态

```scss
.glass-card {
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  border-radius: $rounded-xxxl;
  box-shadow: $shadow-dialog;
}
```

不支持 `backdrop-filter` 的浏览器回退到 `$color-canvas`。

## 4. 动态背景：极光流体

### 4.1 设计描述

全站共享一个 `DynamicBackground` 组件，渲染在 `z-index: 0`，页面内容置于 `z-index: 1`。

- 基础背景：柔和的蓝紫渐变，使用 `linear-gradient(135deg, #e0e6fd, #cce7ff, #d3d3fe, #e0e6fd)`。
- 背景动画：`background-size: 400% 400%`，`animation: aurora-flow 20s ease infinite`，模拟极光缓慢流动。
- 浮动 blob：3–4 个大型半透明白色/浅蓝色圆形，使用 `filter: blur(60px)`，以 15–25s 周期缓慢位移、缩放。
- 页面区分：
  - `variant="login"`：渐变饱和度稍高，blob 更明显，配合登录页分屏视觉区。
  - `variant="management"`：渐变更淡，blob 透明度更低（0.06–0.1），避免干扰管理内容阅读。

### 4.2 动画参数

```scss
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
```

### 4.3 可访问性

```scss
@media (prefers-reduced-motion: reduce) {
  .dynamic-background,
  .dynamic-background .blob {
    animation: none;
  }
}
```

## 5. 全局导航框架

### 5.1 布局结构

所有受保护的内页统一使用以下布局：

```
┌─────────────────────────────────────────┐
│  面包屑栏（高 48px，白色，底部 1px 分隔线） │
├────────┬────────────────────────────────┤
│        │                                │
│  左侧   │           内容区                │
│  边栏   │         （可滚动）               │
│ 56px   │                                │
│        │                                │
└────────┴────────────────────────────────┘
```

### 5.2 左侧边栏

- 宽度：56px（图标 only），可扩展为 200px（图标 + 文字）作为未来增强，本次实现固定 56px。
- 背景：白色（`$color-canvas`），右侧 1px `$color-hairline-soft` 分隔线。
- 内容：
  - 顶部：Logo 图标（32×32px，圆角 8px）。
  - 中部：导航图标按钮，垂直排列，间距 12px。
  - 底部：折叠/展开切换（可选，本次不做）。
- 图标状态：
  - 默认：36×36px，圆角 10px，背景透明，图标色 `$color-steel`。
  - Hover：背景 `$color-surface-soft`。
  - Active：背景 `$color-primary`，图标白色。

### 5.3 顶部面包屑

- 高度：48px。
- 背景：白色，底部 1px `$color-hairline-soft`。
- 左侧：面包屑路径，如 `首页 / 仪表盘`，当前页使用 `$color-ink-deep`，父级使用 `$color-steel`。
- 右侧：用户头像 + 用户名下拉（从当前 HeaderBar 迁移）。

### 5.4 受影响的页面

通过全局布局组件包裹以下路由页面，使其自动继承新框架：

`home`, `RoleConfig`, `DeviceManagement`, `UserManagement`, `ModelConfig`, `KnowledgeBaseManagement`, `ServerSideManager`, `OtaManagement`, `VoiceResourceManagement`, `VoiceCloneManagement`, `DictManagement`, `ProviderManagement`, `AgentTemplateManagement`, `TemplateQuickConfig`, `FeatureManagement`, `ReplacementWordManagement`, `AddressBookManagement`, `VoicePrint`

登录页、注册页、找回密码页不使用该框架，保持全屏背景。

## 6. 登录页（`login.vue`）

### 6.1 布局

- 全屏动态背景（`DynamicBackground variant="login"`）。
- 页面主体为左右分屏，占满可视区域：
  - 左侧：动态视觉区（55–60% 宽度），展示品牌 Logo + 品牌标题 + Slogan。
  - 右侧：玻璃拟态登录表单（40–45% 宽度），居中垂直对齐。
- 顶部：品牌 Logo（与动态视觉区 Logo 不重复，可省略或仅保留在视觉区）。
- 底部：版本信息（`VersionFooter`）。

### 6.2 左侧动态视觉区

- 背景：在全局极光背景之上叠加一层从 `$color-primary` 到 `$color-primary-soft` 的半透明渐变，增强品牌色。
- 浮动元素：2–3 个白色/浅蓝色半透明 blob，使用 `filter: blur(20–40px)`，缓慢缩放和位移。
- 文字：
  - Logo：32×32px 图标 + "云枢" 文字。
  - 主标题：`$font-display-lg`，"智能语音硬件管理平台"。
  - 副标题：`$font-body-md`，"连接设备、配置智能体、管理模型，一句话掌控全局。"

### 6.3 右侧登录表单

- 容器：`glass-card`，最大宽度 420px，内边距 `$spacing-xxl`。
- 标题区：
  - 欢迎图标（`hi.png`）+ "登录" 标题 + "欢迎回来" 副标题。
  - 语言切换下拉保留。
- 输入框：
  - 统一高度 48px，圆角 `$rounded-lg`。
  - 背景 `rgba(255,255,255,0.6)`，边框 `$color-hairline`。
  - Focus：边框 `$color-primary`（40% 透明度）+ 外发光 `0 0 0 3px rgba($color-primary, 0.08)`。
- 登录按钮：
  - 高度 48px，背景 `$color-ink-button`，文字白色。
  - 圆角 `$rounded-full`，全宽。
  - Hover：`transform: translateY(-1px)` + 阴影加深。
- 底部：注册/忘记密码链接 + 用户协议。

### 6.4 动效

- 页面加载：左侧文字从下方淡入（`translateY(20px) → 0`，600ms，ease-out）。
- 右侧表单从右侧淡入（`translateX(20px) → 0`，500ms，delay 100ms）。
- 背景 blob 持续缓慢流动。

## 7. 首页 / 仪表盘（`home.vue`）

### 7.1 布局

在全局框架的内容区内：

```
┌──────────────────────────────────────┐
│  面包屑：首页 / 仪表盘                  │
├──────────────────────────────────────┤
│                                      │
│  动态欢迎横幅（高度 ~160–200px）        │
│                                      │
├──────────────────────────────────────┤
│  [统计卡1] [统计卡2] [统计卡3] [统计卡4] │
├──────────────────────────────────────┤
│  我的智能体（标题 + 添加按钮）           │
│  ┌────────┐  ┌────────┐              │
│  │ 设备卡片 │  │ 设备卡片 │  ...        │
│  └────────┘  └────────┘              │
│                                      │
└──────────────────────────────────────┘
```

### 7.2 动态欢迎横幅

- 背景：渐变 `linear-gradient(135deg, $color-primary-deep 0%, $color-primary-soft 100%)`。
- 圆角：`$rounded-xxxl`（32px）。
- 高度：160–200px（响应式）。
- 内容：
  - 左侧：问候语（"早安，Admin"，`$font-heading-lg`，白色）+ 状态摘要（"今日 3 台设备在线，2 个智能体活跃"，`$font-body-md`，白色 90% 透明度）。
  - 右侧：装饰性动态 blob（白色半透明，filter blur，缓慢缩放/漂浮）。
- 动态效果：
  - 背景 blob：3 个白色半透明圆形，周期 12–18s，缩放 0.95–1.1，位移 ±30px。
  - 文字入场：加载时从左侧淡入（400ms）。
  - 时间问候：根据当前时间自动切换"早安/下午好/晚上好"。

### 7.3 统计卡片

- 4 列网格，间隙 `$spacing-xl`。
- 卡片样式：白色背景，`$rounded-xl`（16px），细微阴影 `0 2px 8px rgba(0,0,0,0.04)`。
- 每个卡片：
  - 左侧：图标容器，40×40px，圆角 `$rounded-lg`，背景 `$color-surface-soft`，图标色 `$color-primary`。
  - 右侧：数字（`$font-heading-sm`）+ 标签（`$font-body-sm`，`$color-steel`）。
- 统计项：智能体数量、设备数量、在线设备数、模型配置数。
- 动效：页面加载时 stagger 入场（每个延迟 80ms，从下方淡入）。

### 7.4 设备卡片网格

- 标题行："我的智能体"（`$font-heading-sm`）+ "+ 新增智能体" 胶囊按钮（黑色主按钮）。
- 网格：`grid-template-columns: repeat(auto-fill, minmax(360px, 1fr))`，间隙 `$spacing-xl`。
- 卡片：沿用现有 `DeviceItem` 玻璃卡片样式，但微调：
  - 圆角从当前 `$rounded-xxxl` 保持。
  - 增加加载入场 stagger 动画。
  - Hover：轻微上浮 `translateY(-2px)` + 阴影加深。
- 空状态：当没有智能体时显示插画 + "暂无智能体，点击添加" 提示 + CTA 按钮。

### 7.5 搜索框

- 位置：从首页当前位置迁移到顶部面包屑右侧或欢迎横幅内，本次改造中保留在首页标题区下方作为辅助搜索。
- 样式：胶囊搜索框，高度 40px，背景 `$color-surface-soft`，圆角 `$rounded-full`。

## 8. 组件规范

### 8.1 按钮

| 类型 | 背景 | 文字 | 圆角 | 高度 | Hover |
|---|---|---|---|---|---|
| Primary | `$color-ink-button` | 白色 | `$rounded-full` | 44–48px | 背景变亮，轻微上浮 |
| Secondary | 透明 | `$color-ink-deep` | `$rounded-full` | 40–44px | 背景 `$color-surface-soft` |
| Icon Button | `$color-surface-soft` | `$color-steel` | `$rounded-lg` | 36–40px | 背景 `$color-hairline-soft` |

### 8.2 卡片

| 类型 | 背景 | 圆角 | 阴影 | 用途 |
|---|---|---|---|---|
| Glass Card | `$color-glass-bg` + blur | `$rounded-xxxl` | `$shadow-dialog` | 登录表单、部分浮层 |
| Surface Card | `$color-canvas` | `$rounded-xl` | `0 2px 8px rgba(0,0,0,0.04)` | 统计卡片 |
| Elevated Card | `$color-canvas` | `$rounded-xxxl` | `0 8px 32px rgba(0,0,0,0.08)` | 设备卡片 |

### 8.3 输入框

- 高度 44–48px，圆角 `$rounded-lg`。
- 背景 `rgba(255,255,255,0.6)` 或 `$color-canvas`。
- 边框 `$color-hairline`。
- Focus：`border-color: rgba($color-primary, 0.4)` + `box-shadow: 0 0 0 3px rgba($color-primary, 0.08)`。

## 9. 动效规范

### 9.1 背景动效

| 元素 | 动画 | 周期 | 缓动 |
|---|---|---|---|
| 极光渐变 | background-position 循环 | 20s | ease |
| Blob 1 | translate + scale | 18s | ease-in-out |
| Blob 2 | translate + scale | 22s | ease-in-out |
| Blob 3 | translate + scale | 15s | ease-in-out |

### 9.2 UI 动效

| 场景 | 动画 | 时长 | 缓动 |
|---|---|---|---|
| 页面加载淡入 | opacity + translateY(12px → 0) | 400ms | `$ease-out-expo` |
| 统计卡片 stagger | opacity + translateY(16px → 0) | 300ms | `$ease-out-expo`，延迟 80ms |
| 设备卡片 stagger | opacity + translateY(16px → 0) | 350ms | `$ease-out-expo`，延迟 60ms |
| 卡片 Hover | translateY(-2px) + shadow | 200ms | ease-out |
| 按钮 Hover | translateY(-1px) + shadow | 150ms | ease-out |
| 侧边栏图标 Hover | background-color | 150ms | ease |
| 输入框 Focus | border + box-shadow | 200ms | ease |

### 9.3 页面过渡

Vue Router 切换时，内容区使用淡出淡入（opacity 0 → 1，200ms）。

## 10. 数据流与交互

### 10.1 首页数据

首页需要以下数据：

| 数据 | 来源 | 用途 |
|---|---|---|
| 智能体列表 | `Api.agent.getAgentList` | 设备网格 |
| 设备统计 | 从智能体列表派生（`deviceCount` 聚合） | 统计卡片 |
| 在线设备数 | 从智能体列表派生：优先使用 `device.online` 字段；若不存在，则使用最近 24 小时内有连接记录的设备数作为近似值 | 统计卡片 |
| 模型配置数 | 从智能体列表中 `llmModelName` / `ttsModelName` 去重计数 | 统计卡片 |
| 用户信息 | Vuex `userInfo` | 欢迎语 |

### 10.2 导航数据

侧边栏导航项从当前 `HeaderBar` 的路由映射中提取，按权限/功能开关渲染：

- 首页（所有用户）
- 音色克隆（`featureStatus.voiceClone`）
- 模型配置（超管）
- 知识库（`featureStatus.knowledgeBase`）
- 通讯录（`featureStatus.addressBook`）
- 系统管理（超管，聚合参数、用户、OTA、字典、提供者等）

### 10.3 面包屑

基于当前 `$route.path` 映射为中文标签。静态映射表即可，无需动态路由解析。

## 11. 错误处理

- 动态背景加载失败不影响功能，使用纯色背景回退。
- `backdrop-filter` 不支持时回退到不透明 `$color-canvas`。
- 首页数据加载失败时显示错误提示和重试按钮。
- 侧边栏权限数据未就绪时显示骨架屏或禁用导航。

## 12. 响应式策略

本次改造以桌面端为主，但需保证基本可用性：

- 最小宽度：保持现有 `min-width: 900px`（与当前一致）。
- 统计卡片：在 1024px 以下变为 2 列。
- 设备网格：`minmax(320px, 1fr)`，自动换行。
- 登录页：在 1024px 以下左侧面板隐藏 Slogan，仅保留 Logo；表单区保持可用。

## 13. 实现边界与约束

- **不改动后端 API**：仅使用现有接口。
- **不改动路由结构**：仅增加布局包装器。
- **不引入新依赖**：动画使用 CSS + Vue transition，不使用 GSAP/Three.js。
- **保持 Element UI**：输入框、下拉、弹窗继续使用 Element UI，但样式覆盖。
- **多语言兼容**：所有新增文案通过 `i18n` 注入，至少补充 `zh_CN` 和 `en`。
- **可访问性**：支持 `prefers-reduced-motion`；保持足够的颜色对比度。

## 14. 验收标准

- [ ] 登录页呈现左半屏动态视觉区 + 右半屏玻璃登录表单，背景极光流动。
- [ ] 首页呈现左侧浅色边栏、顶部面包屑、动态欢迎横幅、4 个统计卡片、设备网格。
- [ ] 所有内页继承新的全局导航框架（侧边栏 + 面包屑）。
- [ ] 动态背景组件支持 `login` / `management` 两种变体，且支持 reduced motion。
- [ ] 所有新增/修改组件在 Chrome、Edge、Firefox 最新版正常显示。
- [ ] 页面加载时无 layout shift，动画流畅（60fps）。
- [ ] 多语言文案完整，无硬编码中文。
- [ ] `npm run build` 无新增错误和严重警告。

## 15. 文件变更预期

### 15.1 新增文件

- `main/manager-web/src/layouts/MainLayout.vue`：全局侧边栏 + 面包屑布局
- `main/manager-web/src/components/SidebarNav.vue`：侧边栏导航
- `main/manager-web/src/components/BreadcrumbBar.vue`：面包屑 + 用户菜单
- `main/manager-web/src/components/StatCard.vue`：统计卡片
- `main/manager-web/src/components/WelcomeBanner.vue`：动态欢迎横幅
- `main/manager-web/src/components/EmptyAgentState.vue`：空状态

### 15.2 修改文件

- `main/manager-web/src/App.vue`：可能调整根布局
- `main/manager-web/src/router/index.js`：路由使用 MainLayout 包装
- `main/manager-web/src/views/login.vue`：分屏布局 + 玻璃表单
- `main/manager-web/src/views/home.vue`：仪表盘布局
- `main/manager-web/src/components/DynamicBackground.vue`：升级极光流体
- `main/manager-web/src/components/DeviceItem.vue`：微调入场动画
- `main/manager-web/src/components/HeaderBar.vue`：功能迁移到 BreadcrumbBar/SidebarNav 后移除或降级
- `main/manager-web/src/styles/_tokens.scss`：如有缺失 token 则补充
- `main/manager-web/src/i18n/zh_CN.js`、`en.js` 等：新增文案

## 16. 风险与注意事项

1. **HeaderBar 重构**：当前 HeaderBar 包含大量路由和权限逻辑，迁移到 SidebarNav + BreadcrumbBar 时需小心保留所有功能。
2. **Element UI 样式覆盖**：升级输入框、按钮样式时避免影响弹窗和其他页面。
3. **性能**：动态背景使用 `filter: blur()` 和大型 blob，在低端设备上可能影响性能，需测试并提供降级。
4. **向后兼容**：所有内页自动继承新布局，需验证每个页面在新布局下无样式冲突。
