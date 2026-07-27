"""豆包端到端实时语音大模型（S2S）接入层。

分三层：
- protocol.py：二进制帧编解码与事件常量
- client.py：WebSocket 连接与会话生命周期
- session_config.py：云枢智能体配置 → StartSession payload

设备侧协议不变，编排入口在 core/providers/asr/doubao_realtime.py。
"""
