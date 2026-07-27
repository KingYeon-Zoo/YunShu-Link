# 演示数据库重置

该脚本用于在每次演示前，把数据库恢复为固定、可预测的状态。基线固定为
2026-07-27 当前确认版。

## 写入的内容

固定层（逐字段哈希校验，改动会被 `verify-current-baseline.sql` 发现）：

- 专用演示管理员账号；
- 默认智能体「琉璃」，绑定豆包 LLM / ASR / TTS 全链路；
- `prompt-example/` 下五套角色模板；
- EduLoom 中已验证的 20 个 Seed-TTS 2.0 中文音色；
- 保留全部记忆模型与 RAGFlow 知识库选项，并打开知识库管理入口。

展示层（让控制台各页面不至于空白，只校验规模与引用完整性）：

- 五套角色全部实例化成智能体，配好标签、视觉模型与记忆模型；
- 10 台演示设备，分挂在五个智能体下，型号取自固件字典，最后连接时间覆盖
  「刚刚」「几小时前」「上周」三种状态；
- 6 段历史会话共 36 条对话，可在「聊天记录」弹窗里直接翻；
- 4 个知识库、45 篇真实语料文档（见下节）；
- 多厂商模型目录：豆包 Pro、通义千问、DeepSeek、智谱、Ollama、FunASR、
  Edge TTS 等，让模型配置页每一类都不只有一行。

每次重置都会先备份现有库、重建并等 Liquibase 完成迁移，最后清空 Redis 并重启
管理 API 与语音服务。

## 演示知识库语料

语料来自两个 MIT 协议的开源项目，不含自造内容：

- [pwxcoo/chinese-xinhua](https://github.com/pwxcoo/chinese-xinhua)：成语释义、歇后语
- [chinese-poetry/chinese-poetry](https://github.com/chinese-poetry/chinese-poetry)：论语、元曲、幽梦影

加上本仓库 `docs/` 下的产品文档，切分成四个知识库：国学启蒙语料库、成语典故
词库、民间歇后语与俗语、云枢产品文档库。

正文文件在 `scripts/demo/corpus/`，已提交进仓库，**重置流程本身不需要联网**。
只有更新语料时才需要重跑抓取脚本（需联网）：

```bash
python3 scripts/demo/fetch-demo-corpus.py
```

它会重写 `corpus/` 下的 Markdown 文件，并按真实文件体积重新生成
`seed-demo-knowledge.sql`。之后 `verify-current-baseline.sql` 里的文档条数需要
同步更新。

## 日常使用

先复制并填写环境变量：

```bash
cp .env.demo.example .env
```

然后运行图形化启动器，在菜单中输入 `2`，再输入 `1` 确认：

```bash
./start-dev.sh
```

`reset-demo-db.sh` 的命令行参数仅保留给自动化测试和高级开发场景。

## 演示时的已知限制

这两处靠假数据造不出来，录制时请避开：

- **设备列表的「在线/离线」列**。它不读 `last_connected_at`，而是实时查 MQTT
  网关（系统参数 `server.mqtt_manager_api`）。没有网关时该列根本不渲染。首页
  顶部的「在线设备」统计走的是另一套逻辑，看 `last_connected_at` 是否在 24
  小时内，演示数据能正常撑起这个数字。
- **知识库的写操作与检索测试**。知识库是 RAGFlow 的影子表，演示环境没有
  RAGFlow 服务，因此「检索测试」「查看切片」「上传」「解析」「新增知识库」都
  会报错。只读浏览、搜索、分页、启停开关是安全的。

## 密钥与备份

新版豆包语音识别控制台使用 `X-Api-Key` 和 `X-Api-Resource-Id`。推荐在 `.env`
中写成 `DOUBAO_ASR_API_KEY` 和 `DOUBAO_ASR_RESOURCE_ID`；初始化器也兼容控制台
文档中的原始字段名，不会在日志中显示密钥内容。

ASR 与 Seed-TTS 共用同一个 `X-Api-Key`，因此 `.env` 里只写一份即可，脚本会同时
推导给 `DOUBAO_ASR_API_KEY` 和 `DOUBAO_TTS_API_KEY`。**不要单独再填
`DOUBAO_TTS_API_KEY`**：若它与 ASR 的取值不同，脚本会给出告警，且很可能导致
TTS 合成返回 401（设备表现为完全无声）。当本仓库 `.env` 缺少某个变量时，脚本会
从同级 `EduLoom/.env` 兜底补齐并打印提示 —— 那属于另一个账号的凭据，可能早已
失效，遇到鉴权失败时应优先在本仓库 `.env` 中显式配置。

脚本不会把密钥写进仓库或输出到终端。数据库备份保存在项目根目录的
`.demo-db-backups/`；备份只用于人工回滚，绝不会作为初始化数据源。如果重置
失败，脚本会恢复已停止的容器，并保留备份供手动恢复。登录令牌属于运行时临时
数据，不会写入初始化基线。

## 烧录前的模型自检

只校验字段非空不足以发现失效密钥。重置完成后脚本会自动执行一次真实调用自检，
也可以随时单独运行：

```bash
./start-dev.sh check-models
```

它会用 provider 本体逐个调用控制台里启用的 LLM / TTS / ASR（ASR 用 TTS 合成的
音频做闭环识别），并检查 `server.websocket`、`server.ota` 是否指向设备真正能
访问的局域网地址。日常启动和 `restart-python` 会自动跑一遍快速版（跳过较慢的
ASR 闭环）。

自检只检查被智能体真正绑定的模型，因此展示层里那些没配密钥的第三方模型不会
拖累自检结果。

## 离线自检

不动真实数据库、不需要密钥，在临时库里跑完整套初始化 SQL 并校验引用完整性：

```bash
bash scripts/tests/test-demo-seed.sh
```
