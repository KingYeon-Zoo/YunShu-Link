# 豆包端到端实时语音大模型接入指南

端到端语音（S2S，RealtimeAPI）把「识别 → 对话 → 合成」合成一次模型调用，语音进、语音出。相比 ASR + LLM + TTS 串联，少了两次串行等待，首字延迟明显更低，代价是失去了链路中间的可控点（拿不到完整文本再改写、换不了独立 TTS 音色）。

**设备侧协议完全不变。** 固件、`manager-web`、`manager-mobile` 都不需要任何改动——端到端只是后端换了一种实现，对外仍然是原来的 `stt` / `llm` / `tts` 消息与 Opus 音频流。

## 一、它在架构里的位置

端到端 provider 占用 **ASR 槽位**，因为音频入口就是 `conn.asr.receive_audio`：

```
设备 Opus ──► ConnectionHandler ──► asr.receive_audio ──► 豆包 RealtimeAPI
                     ▲                                          │
                     └── tts.tts_audio_queue ◄── Opus 编码 ◄─────┘
```

模型返回的音频重新塞回 `conn.tts.tts_audio_queue`，因此原有的流控（`AudioRateController`）、字幕下发、情绪消息、聊天记录上报**全部照旧复用**，不需要新的下行通道。

选用端到端后：

- `selected_module.TTS` 不再参与实时链路（音色由端到端模型的 `speaker` 决定）
- `selected_module.LLM` 不参与实时对话，但**仍需保留配置**：记忆总结、聊天标题、以及工具路由都要用它
- VAD 仍在设备侧生效（用于打断），说话结束的判定由服务端 VAD 负责

代码分布：

| 文件 | 职责 |
|------|------|
| `core/providers/s2s/protocol.py` | 二进制帧编解码、事件常量 |
| `core/providers/s2s/client.py` | WebSocket 连接与会话生命周期 |
| `core/providers/s2s/session_config.py` | 智能体配置 → StartSession payload |
| `core/providers/s2s/tool_bridge.py` | 工具调用桥接与闲聊音频闸门 |
| `core/providers/asr/doubao_realtime.py` | 事件编排，翻译成设备侧协议 |

## 二、开通与配置

在[火山语音控制台](https://console.volcengine.com/speech/service/10011)开通「豆包端到端实时语音大模型」，拿到 App ID 与 Access Token。

控制台模式（推荐）：模型管理里选「豆包端到端实时语音大模型」，填入 App ID 与访问令牌，然后把智能体的语音识别模型指向它即可。

本地模式：改 `data/.config.yaml`。

```yaml
selected_module:
  ASR: DoubaoRealtime

ASR:
  DoubaoRealtime:
    type: doubao_realtime
    appid: 你的appid
    access_key: 你的access_token
    model: 1.2.1.1
    speaker: zh_female_vv_jupiter_bigtts
```

### 版本与音色必须匹配

这是最容易踩的坑，配错直接报 `ClientError:InvalidSpeaker`：

| 版本 | `model` | 可用音色 | 特点 |
|------|---------|----------|------|
| O2.0 | `1.2.1.1` | 精品音色 `zh_female_vv_jupiter_bigtts`、`zh_female_xiaohe_jupiter_bigtts`、`zh_male_yunzhou_jupiter_bigtts`、`zh_male_xiaotian_jupiter_bigtts` | 多模态，支持唱歌 |
| SC2.0 | `2.2.0.0` | 克隆音色，`saturn_` 或 `S_` 开头 | 角色扮演，拟人化更强 |

`model` 留空时会按 `speaker` 前缀自动推断，但显式写清楚更省心。

### 人设字段按版本区分

两套字段不通用，配错版本会**静默失效**（不报错，但人设没生效）：

- **O 系列**：`bot_name`（≤20 字符）、`system_role`、`speaking_style`
- **SC 系列**：`character_manifest`

留空时会自动使用所属智能体的提示词，所以 `prompt-example/` 下的角色模板可以直接复用，不必重写。

有一个例外：官方克隆音色（`_tob` 结尾）的角色描述已经在服务端配好了，此时代码不会再覆盖 `character_manifest`，避免破坏音色效果。

## 三、联网搜索

需要在火山控制台额外开通[融合信息搜索](https://www.volcengine.com/docs/85508/1650263)：

```yaml
    enable_websearch: true
    websearch_type: web        # web / web_summary / web_agent
    websearch_api_key: 你的融合搜索密钥
    websearch_result_count: 5  # 上限 10
```

`websearch_api_key` 是必填的，缺了会报 `volc_websearch_api_key is required`。用 `web_agent` 类型时还必须填 `websearch_bot_id`。

搜索由模型自主判断是否触发，命中时 `TTSSentenceStart` 的 `tts_type` 会是 `network`，日志里能看到「本轮回复来自内置联网搜索」。

## 四、工具调用（function call）

**端到端模型本身不支持 function_call**，所以这里用旁路方案：

```
用户语音 ──► 端到端模型 ──► 闲聊音频（先缓存，不下发）
     │                              │
     └──► 旁路 LLM 判断要不要调工具 ──┤
                │                    │
          要调 ─┴─► 执行工具 ─► ChatRAGText 注入 ─► 模型口语化播报
          不调 ─────────────────────► 冲刷缓存，播放原闲聊音频
```

工具结果通过 `ChatRAGText` 事件交回模型，由模型用**当前音色和人设**总结播报，所以听起来和普通对话没有区别，不会出现音色跳变。

这里有一个固有的竞态：`ASREnded` 之后模型立刻开始生成闲聊音频，而工具路由需要几百毫秒。处理办法是先缓存闲聊音频不下发，等判定结果再决定放行还是丢弃。三重兜底保证不会把用户吊死：

- 判定超时（默认 2.5 秒）→ 放行闲聊音频
- 缓存超过约 3 秒音频 → 放行
- 模型本轮已说完而判定仍未回来 → 放行

`plugins_func/functions/` 下的插件全部照常可用，不需要为端到端单独适配。不想用工具就设 `enable_tools: false`，能省掉一次旁路 LLM 调用。

## 五、几个必须知道的行为

**输入模式** `input_mod` 默认 `keep_alive`。设备麦克风静音时无法上传音频，不加这个参数会报 `52000042 DialogAudioIdleTimeoutError`。按键说话的场景改成 `push_to_talk`，此时服务端 VAD 被屏蔽，由设备的 `listen stop` 声明本轮结束。

**说话停止判定** `end_smooth_window_ms` 控制判定用户说完话的静音窗口，取值 `[500, 50000]`，服务端默认 1500ms。调小反应更快，但容易在用户思考停顿时抢话。

**用户退出意图** `enable_user_query_exit` 打开后，模型识别到用户想结束对话时会在 `TTSEnded` 带 `status_code=20000002`，服务端据此设置 `close_after_chat`，走原有的告别流程。

**采样率** 模型固定输出 24kHz PCM。设备通过 `hello` 协商了其他采样率时，代码会用 `audioop.ratecv` 重采样，否则 Opus 编码器会变调。

**上下文** 会话建立时会把云枢已有的对话历史转成 `dialog_context` 注入，只保留成对的问答、最多 20 轮（服务端要求数组长度为偶数且 user/assistant 严格交替，落单的消息会被丢弃而不是补空串）。

**唱歌** `enable_music` 只在 O2.0 生效，配到 SC2.0 会直接报 `42000020`，代码里做了拦截。

## 六、验证

```bash
cd main/xiaozhi-server && python -m unittest discover -s tests -v
```

其中端到端相关的三组：

- `tests.test_doubao_realtime_protocol`：帧编码与官方文档给出的字节数组逐字节比对
- `tests.test_doubao_realtime_session`：StartSession 的各项约束（含各错误码对应的坑）
- `tests.test_doubao_realtime_flow`：完整一轮交互与工具闸门的竞态

## 七、常见错误码

| 错误码 | 关键字 | 原因 |
|--------|--------|------|
| 42000020 | `asr extra is null` / `tts extra is null` | `asr.extra`、`tts.extra` 必须存在，代码已保证 |
| 42000020 | `cant support enable_music` | 唱歌配到了 SC2.0 |
| 42000020 | `volc_websearch_api_key is required` | 开了联网但没填密钥 |
| 52000042 | `DialogAudioIdleTimeoutError` | 静音超时，用 `input_mod: keep_alive` |
| 55000001 | `ClientError:InvalidSpeaker` | 音色与 `model` 版本不匹配 |
| 55000001 | `ContextCanceled` | 没发 `FinishSession` 就断开连接，代码已按顺序发送 |
| 50000000 | `found unknown escape character` | 人设提示词里有非法字符 |
| 45000003 | `Abnormal silence audio` | 超过 10 分钟无交互，服务端主动释放连接 |

遇到 5xx 一律可以重连，代码在事件循环异常时会清理会话状态，下次有声音时自动重建。

上游接口文档：<https://www.volcengine.com/docs/6561/1594356>
