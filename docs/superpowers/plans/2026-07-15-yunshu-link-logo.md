# 云枢 YunShu Link Logo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使用 AI 生图生成云枢横版组合 Logo 与方形纯图标，并交付经过透明化和像素级验证的 PNG 文件。

**Architecture:** 使用内置 AI 生图分别生成横版组合标和方形图标，背景固定为纯色 `#00FF00`；随后使用 imagegen 技能自带的色键移除脚本输出透明 PNG。最终通过 Pillow 检查尺寸、RGBA 模式、透明角点和主体覆盖率，不修改或覆盖现有品牌资源。

**Tech Stack:** 内置 AI 生图工具、Python 3、Pillow、imagegen `remove_chroma_key.py`

## Global Constraints

- 中文主标必须准确写作 `云枢`，英文副标必须准确写作 `YunShu Link`。
- 品牌主色为钴蓝 `#3375FD`，辅色使用少量蓝紫色。
- 不使用书本、机器人、传统麦克风、具象云朵、复杂电路板、3D 吉祥物、摄影质感或水印。
- 最终交付透明背景 PNG，不覆盖 `main/manager-web/src/assets/xiaozhi-logo.png`。
- 图形必须在 32×32 px 下仍能辨识中心枢纽与主要连接流线。

---

### Task 1: 生成横版组合 Logo 与方形图标源图

**Files:**
- Create: `main/manager-web/src/assets/brand/yunshu-link-logo-chroma.png`
- Create: `main/manager-web/src/assets/brand/yunshu-link-icon-chroma.png`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-15-yunshu-link-logo-design.md` 中的品牌定位、构图和文字规范。
- Produces: 两张背景为统一 `#00FF00` 的不透明 PNG 源图，供 Task 2 色键透明化。

- [ ] **Step 1: 生成横版组合 Logo**

使用内置 AI 生图工具，提示词固定为：

```text
Use case: logo-brand
Asset type: 云枢 YunShu Link 官网、管理控制台和 README 的横版品牌 Logo
Primary request: 为面向 ESP32 智能语音硬件的 AI 后端与设备管理平台“云枢”设计现代科技品牌标志。图标表现一个清晰的中心枢纽节点，三条简洁流线汇入中心再向外连接，隐喻 ASR → LLM → TTS，并形成抽象语音波形与字母 Y 的结构；少量外围圆点表现 ESP32、云端 AI、IoT 工具和管理控制台之间的连接。
Scene/backdrop: 完全平坦、均匀的纯色 #00FF00 色键背景，不得有阴影、渐变、纹理、反射、地面或光照变化
Style/medium: 简洁扁平、几何清晰、矢量友好的专业科技公司 Logo，圆润但不幼稚
Composition/framing: 横向构图，左侧图标，右侧中文主标，下方英文副标；四周留出充足安全边距
Color palette: 图形使用钴蓝 #3375FD 与少量蓝紫渐变，文字使用深蓝黑；主体中禁止出现 #00FF00
Text (verbatim): 中文“云枢”；英文“YunShu Link”
Constraints: 中文必须准确为两个字“云枢”，英文必须逐字准确为“YunShu Link”；中文视觉层级高于英文；边缘清晰；无投影、无反射、无接触阴影
Avoid: 书本、机器人、传统麦克风、具象云朵、复杂电路板、3D 吉祥物、摄影质感、额外文字、标语、水印、mockup 场景
```

Expected: 横版源图中的图标和两行品牌文字完整、无裁切，色键背景均匀。

- [ ] **Step 2: 生成方形纯图标**

使用内置 AI 生图工具，提示词固定为：

```text
Use case: logo-brand
Asset type: 云枢 YunShu Link 的应用图标、控制台侧边栏图标和 favicon 源图
Primary request: 设计与云枢横版 Logo 同一品牌语言的独立符号：一个清晰的中心枢纽节点，三条简洁流线汇入中心再向外连接，形成抽象语音波形与字母 Y 的结构；少量外围圆点表现 ESP32、云端 AI、IoT 工具和管理控制台之间的连接。
Scene/backdrop: 完全平坦、均匀的纯色 #00FF00 色键背景，不得有阴影、渐变、纹理、反射、地面或光照变化
Style/medium: 简洁扁平、几何清晰、矢量友好的专业科技公司图标，圆润但不幼稚
Composition/framing: 1:1 方形画布，符号居中，主体约占画布 72%，四周留出一致安全边距
Color palette: 钴蓝 #3375FD 与少量蓝紫渐变，主体中禁止出现 #00FF00
Text (verbatim): 无文字
Constraints: 单一独立符号；高对比；边缘清晰；缩小至 32×32 px 仍能辨识中心节点和三条主流线；无投影、无反射、无接触阴影
Avoid: 任何文字、字母排版、书本、机器人、传统麦克风、具象云朵、复杂电路板、3D 吉祥物、摄影质感、水印、mockup 场景
```

Expected: 1:1 方形源图，无文字、无裁切，色键背景均匀。

### Task 2: 透明化、验证并交付 PNG

**Files:**
- Create: `main/manager-web/src/assets/brand/yunshu-link-logo.png`
- Create: `main/manager-web/src/assets/brand/yunshu-link-icon.png`
- Delete after validation: `main/manager-web/src/assets/brand/yunshu-link-logo-chroma.png`
- Delete after validation: `main/manager-web/src/assets/brand/yunshu-link-icon-chroma.png`

**Interfaces:**
- Consumes: Task 1 的两张纯色背景 PNG。
- Produces: 两张可直接被 Web、移动端和文档引用的透明 RGBA PNG。

- [ ] **Step 1: 移除两张源图的色键背景**

Run:

```bash
python /Users/zoo/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py --input main/manager-web/src/assets/brand/yunshu-link-logo-chroma.png --out main/manager-web/src/assets/brand/yunshu-link-logo.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
python /Users/zoo/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py --input main/manager-web/src/assets/brand/yunshu-link-icon-chroma.png --out main/manager-web/src/assets/brand/yunshu-link-icon.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

Expected: 两条命令退出码均为 0，并生成带 Alpha 通道的两个最终 PNG。

- [ ] **Step 2: 验证透明度与主体覆盖率**

Run:

```bash
python - <<'PY'
from pathlib import Path
from PIL import Image

for path in [
    Path("main/manager-web/src/assets/brand/yunshu-link-logo.png"),
    Path("main/manager-web/src/assets/brand/yunshu-link-icon.png"),
]:
    image = Image.open(path)
    assert image.mode == "RGBA", (path, image.mode)
    alpha = image.getchannel("A")
    corners = [
        alpha.getpixel((0, 0)),
        alpha.getpixel((image.width - 1, 0)),
        alpha.getpixel((0, image.height - 1)),
        alpha.getpixel((image.width - 1, image.height - 1)),
    ]
    coverage = sum(value > 16 for value in alpha.getdata()) / (image.width * image.height)
    assert corners == [0, 0, 0, 0], (path, corners)
    assert 0.03 < coverage < 0.80, (path, coverage)
    print(path, image.size, image.mode, f"coverage={coverage:.3f}")
PY
```

Expected: 两个文件均输出 `RGBA`，四角 Alpha 为 0，主体覆盖率在 3%–80% 之间。

- [ ] **Step 3: 视觉检查完整尺寸与 32×32 缩略图**

使用图像查看工具检查两张最终 PNG，并将方形图标缩放预览至 32×32 px。Expected: 中心节点、三条主流线和整体外轮廓清楚，横版文字准确为“云枢”和“YunShu Link”，不存在绿色残边。

- [ ] **Step 4: 删除色键源图并提交最终资源**

Run:

```bash
rm main/manager-web/src/assets/brand/yunshu-link-logo-chroma.png main/manager-web/src/assets/brand/yunshu-link-icon-chroma.png
git add main/manager-web/src/assets/brand/yunshu-link-logo.png main/manager-web/src/assets/brand/yunshu-link-icon.png
git commit -m "feat: add YunShu Link brand assets"
```

Expected: 提交仅包含两张最终透明 PNG 品牌资源。
