<template>
    <CustomDialog
        :title="$t('chatHistory.with') + agentName + $t('chatHistory.dialogTitle')"
        :visible.sync="dialogVisible"
        width="80%"
        :footer="false"
        :close-on-click-modal="false"
        custom-class="chat-history-dialog">
        <template v-slot:title>
            <span class="dialog-title-header">
                {{ $t('chatHistory.with') + agentName + $t('chatHistory.dialogTitle') }}
                <template v-if="currentMacAddress">
                    <span class="mac-badge">[<MacAddressMask :macAddress="currentMacAddress" />]</span>
                </template>
            </span>
        </template>
        <div class="chat-dialog-body">
            <div class="chat-container">
                <div class="session-list" @scroll="handleScroll">
                    <div v-for="session in sessions" :key="session.sessionId" class="session-item"
                        :class="{ active: currentSessionId === session.sessionId }" @click="selectSession(session)">
                        <img :src="getUserAvatar(session.sessionId)" class="avatar" />
                        <div class="session-info">
                            <div class="session-time">{{ session.title || formatTime(session.createdAt) }}</div>
                            <div class="message-count">{{ session.chatCount > 99 ? '99' : session.chatCount }}</div>
                        </div>
                    </div>
                    <div v-if="loading" class="loading">{{ $t('chatHistory.loading') }}</div>
                    <div v-if="!hasMore" class="no-more">{{ $t('chatHistory.noMoreRecords') }}</div>
                </div>
                <div class="chat-content">
                    <div v-if="currentSessionId" class="messages">
                        <div v-for="(message, index) in messagesWithTime" :key="message.id">
                            <div v-if="message.type === 'time'" class="time-divider">
                                {{ message.content }}
                            </div>
                            <div v-else class="message-item" :class="{ 'user-message': message.chatType === 1, 'tool-message': message.chatType === 3 }">
                                <img :src="message.chatType === 1 ? getUserAvatar(currentSessionId) : require('@/assets/brand/yunshu-link-icon.png')"
                                    class="avatar" />
                                <div class="message-content">
                                    <template v-if="Array.isArray(extractContentFromString(message.content))">
                                        <div class="content-wrapper">
                                            <div v-for="(item, idx) in extractContentFromString(message.content)" :key="idx">
                                                <div v-if="item.type === 'text'" class="text-content">{{ item.text }}</div>
                                                <div v-else-if="item.type === 'tool'" class="tool-call-text">{{ item.text }}</div>
                                                <div v-else-if="item.type === 'tool_result'" class="tool-call-text">
                                                    <div v-if="item.text && item.text.length > 80" class="tool-result-wrapper">
                                                        <div v-if="isToolResultCollapsed(index, idx)" class="tool-result-collapsed">
                                                            {{ getFirstLineText(item.text) }}
                                                        </div>
                                                        <div v-else class="tool-result-expanded">
                                                            {{ item.text }}
                                                        </div>
                                                        <span class="tool-toggle-btn" @click="toggleToolResult(index, idx)">
                                                            <i :class="isToolResultCollapsed(index, idx) ? 'el-icon-arrow-down' : 'el-icon-arrow-up'"></i>
                                                        </span>
                                                    </div>
                                                    <div v-else>{{ item.text }}</div>
                                                </div>
                                            </div>
                                        </div>
                                    </template>
                                    <template v-else>
                                        {{ extractContentFromString(message.content) }}
                                    </template>
                                    <i v-if="message.audioId" :class="getAudioIconClass(message)"
                                        @click="playAudio(message)" class="audio-icon"></i>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div v-else class="no-session-selected">
                        {{ $t('chatHistory.selectSession') }}
                    </div>
                </div>
            </div>
            <div v-if="currentSessionId" class="download-buttons">
                <el-button type="primary" plain size="small" @click="downloadCurrentSessionWithPrevious">
                    {{ $t('chatHistory.downloadCurrentWithPreviousSessions') }}
                </el-button>
                <el-button type="primary" plain size="small" @click="downloadCurrentSession">
                    {{ $t('chatHistory.downloadCurrentSession') }}
                </el-button>
            </div>
        </div>
    </CustomDialog>
</template>

<script>
import { debounce } from '@/utils'
import Api from '@/apis/api';
import CustomDialog from '@/components/CustomDialog.vue';
import MacAddressMask from '@/components/MacAddressMask.vue';

export default {
    name: 'ChatHistoryDialog',
    props: {
        visible: {
            type: Boolean,
            default: false
        },
        agentId: {
            type: String,
            required: true
        },
        agentName: {
            type: String,
            required: true
        }
    },
    data() {
        return {
            dialogVisible: false,
            sessions: [],
            messages: [],
            currentSessionId: '',
            currentMacAddress: '',
            page: 1,
            limit: 20,
            loading: false,
            hasMore: true,
            scrollTimer: null,
            isFirstLoad: true,
            playingAudioId: null,
            audioElement: null,
            expandedToolResults: {} // 跟踪工具结果的展开状态
        };
    },
    components: {
        CustomDialog,
        MacAddressMask,
    },
    watch: {
        visible(val) {
            this.dialogVisible = val;
            if (val) {
                this.resetData();
                this.loadSessions();
            } else {
                this.audioElement?.pause();
                this.audioElement = null;
                this.playingAudioId = null;
            }
        },
        dialogVisible(val) {
            if (!val) {
                this.$emit('update:visible', false);
            }
        }
    },
    computed: {
        messagesWithTime() {
            if (!this.messages || this.messages.length === 0) return [];

            const result = [];
            const TIME_INTERVAL = 60 * 1000; // 1分钟的时间间隔（毫秒）

            // 添加第一条消息的时间标记
            if (this.messages[0]) {
                result.push({
                    type: 'time',
                    content: this.formatTime(this.messages[this.messages.length - 1].createdAt),
                    id: `time-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
                });
            }

            // 处理消息列表
            for (let i = 0; i < this.messages.length; i++) {
                const currentMessage = this.messages[i];
                result.push(currentMessage);

                // 检查是否需要添加时间标记
                if (i < this.messages.length - 1) {
                    const currentTime = new Date(currentMessage.createdAt).getTime();
                    const nextTime = new Date(this.messages[i + 1].createdAt).getTime();

                    if (nextTime - currentTime > TIME_INTERVAL) {
                        result.push({
                            type: 'time',
                            content: this.formatTime(this.messages[i + 1].createdAt),
                            id: `time-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
                        });
                    }
                }
            }

            return result;
        }
    },
    methods: {
        extractContentFromString(content) {
            if (!content || content.trim() === '') {
                return content;
            }

            try {
                const jsonObj = JSON.parse(content);

                if (Array.isArray(jsonObj)) {
                    return jsonObj;
                }

                if (jsonObj && typeof jsonObj === 'object' && jsonObj.content) {
                    return jsonObj.content;
                }
            } catch (e) {
                // 原字串
            }

            return content;
        },
        toggleToolResult(messageIndex, itemIndex) {
            const key = `${messageIndex}-${itemIndex}`;
            this.$set(this.expandedToolResults, key, !this.expandedToolResults[key]);
        },
        isToolResultCollapsed(messageIndex, itemIndex) {
            const key = `${messageIndex}-${itemIndex}`;
            return !this.expandedToolResults[key];
        },
        getFirstLineText(text) {
            if (!text) return '';
            const firstLine = text.split('\n')[0];
            return firstLine.length < text.length ? firstLine + '...' : text;
        },
        resetData() {
            this.sessions = [];
            this.messages = [];
            this.currentSessionId = '';
            this.currentMacAddress = '';
            this.page = 1;
            this.loading = false;
            this.hasMore = true;
            this.isFirstLoad = true;
            this.expandedToolResults = {};
        },
        loadSessions() {
            if (this.loading || (!this.isFirstLoad && !this.hasMore)) {
                return;
            }

            this.loading = true;
            const params = {
                page: this.page,
                limit: this.limit
            };

            Api.agent.getAgentSessions(this.agentId, params, (res) => {
                if (res.data && res.data.data && Array.isArray(res.data.data.list)) {
                    const list = res.data.data.list;
                    this.hasMore = list.length === this.limit;

                    this.sessions = [...this.sessions, ...list];
                    this.page++;

                    if (this.sessions.length > 0 && !this.currentSessionId) {
                        this.selectSession(this.sessions[0]);
                    }
                }
                this.loading = false;
                this.isFirstLoad = false;
            });
        },
        selectSession(session) {
            this.currentSessionId = session.sessionId;
            Api.agent.getAgentChatHistory(this.agentId, session.sessionId, (res) => {
                if (res.data && res.data.data) {
                    this.messages = res.data.data;
                    if (this.messages.length > 0 && this.messages[0].macAddress) {
                        this.currentMacAddress = this.messages[0].macAddress;
                    }
                    this.sessions = this.sessions.map(item => {
                        if (item.sessionId === session.sessionId) {
                            item.chatCount = this.messages.length;
                        }
                        return item;
                    })
                }
            });
        },
        handleScroll(e) {
            if (this.scrollTimer) {
                clearTimeout(this.scrollTimer);
            }

            this.scrollTimer = setTimeout(() => {
                const { scrollTop, scrollHeight, clientHeight } = e.target;
                if (scrollHeight - scrollTop <= clientHeight + 50) {
                    this.loadSessions();
                }
            }, 200);
        },
        formatTime(timestamp) {
            const date = new Date(timestamp);
            const now = new Date();
            const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            const yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);

            const hours = date.getHours().toString().padStart(2, '0');
            const minutes = date.getMinutes().toString().padStart(2, '0');

            if (date >= today) {
                return `${this.$t('chatHistory.today')} ${hours}:${minutes}`;
            } else if (date >= yesterday) {
                return `${this.$t('chatHistory.yesterday')} ${hours}:${minutes}`;
            } else {
                const year = date.getFullYear();
                const month = (date.getMonth() + 1).toString().padStart(2, '0');
                const day = date.getDate().toString().padStart(2, '0');
                return `${year}-${month}-${day} ${hours}:${minutes}`;
            }
        },
        getAudioIconClass(message) {
            if (this.playingAudioId === message.audioId) {
                return 'el-icon-loading';
            }
            return 'el-icon-video-play';
        },
        playAudio: debounce(function(message) {
            if (this.playingAudioId === message.audioId) {
                if (this.audioElement) {
                    this.audioElement.pause();
                    this.audioElement = null;
                }
                this.playingAudioId = null;
                return;
            }

            if (this.audioElement) {
                this.audioElement.pause();
                this.audioElement = null;
            }

            this.playingAudioId = message.audioId;
            Api.agent.getAudioId(message.audioId, (res) => {
                if (res.data && res.data.data) {
                    if (!this.audioElement) {
                        this.audioElement = new Audio();
                    }
                    
                    this.audioElement.src = Api.getServiceUrl() + `/agent/play/${res.data.data}`;
                    this.audioElement.onended = () => {
                        this.playingAudioId = null;
                        this.audioElement = null;
                    };

                    this.audioElement.play();
                }
            });
        }, 300),
        getUserAvatar(sessionId) {
            const numbers = sessionId.match(/\d+/g);
            if (!numbers) return require('@/assets/user-avatar1.png');

            const sum = numbers.reduce((acc, num) => acc + parseInt(num), 0);
            const avatarIndex = (sum % 5) + 1;

            return require(`@/assets/user-avatar${avatarIndex}.png`);
        },
        downloadCurrentSession() {
            Api.agent.getDownloadUrl(this.agentId, this.currentSessionId, (res) => {
                if (res && res.data && res.data.code === 0 && res.data.data) {
                    const uuid = res.data.data;
                    window.open(`${Api.getServiceUrl()}/agent/chat-history/download/${uuid}/current`, '_blank');
                } else {
                    this.$message.error(this.$t('chatHistory.downloadLinkFailed'));
                }
            });
        },
        downloadCurrentSessionWithPrevious() {
            Api.agent.getDownloadUrl(this.agentId, this.currentSessionId, (res) => {
                if (res && res.data && res.data.code === 0 && res.data.data) {
                    const uuid = res.data.data;
                    window.open(`${Api.getServiceUrl()}/agent/chat-history/download/${uuid}/previous`, '_blank');
                } else {
                    this.$message.error(this.$t('chatHistory.downloadLinkFailed'));
                }
            });
        }
    }
};
</script>

<style scoped>
.dialog-title-header {
    font-size: 17px;
    font-weight: 600;
    color: #f8fafc;
    display: inline-flex;
    align-items: center;
}

.mac-badge {
    color: #60a5fa;
    font-size: 14px;
    margin-left: 8px;
    font-family: monospace;
}

.chat-dialog-body {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    background-color: #0b1329;
}

.chat-container {
    display: flex;
    flex: 1;
    min-height: 0;
    overflow: hidden;
}

/* 左侧会话列表 */
.session-list {
    width: 260px;
    border-right: 1px solid rgba(255, 255, 255, 0.08);
    overflow-y: auto;
    padding: 12px;
    background: rgba(15, 23, 42, 0.4);
}

.session-item {
    display: flex;
    align-items: center;
    padding: 10px 12px;
    cursor: pointer;
    border-radius: 10px;
    margin-bottom: 8px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    border: 1px solid transparent;
}

.session-item:hover {
    background-color: rgba(255, 255, 255, 0.05);
}

.session-item.active {
    background: linear-gradient(90deg, rgba(37, 99, 235, 0.25) 0%, rgba(37, 99, 235, 0.1) 100%);
    border: 1px solid rgba(59, 130, 246, 0.4);
    box-shadow: 0 2px 10px rgba(37, 99, 235, 0.15);
}

.avatar {
    width: 38px;
    height: 38px;
    border-radius: 50%;
    margin-right: 10px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    flex-shrink: 0;
}

.session-info {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.session-time {
    font-size: 13px;
    color: rgba(241, 245, 249, 0.85);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    line-height: 20px;
    font-weight: 400;
}

.session-item.active .session-time {
    color: #ffffff;
    font-weight: 600;
}

.message-count {
    font-size: 11px;
    color: #93c5fd;
    background-color: rgba(37, 99, 235, 0.3);
    border: 1px solid rgba(96, 165, 250, 0.3);
    border-radius: 10px;
    padding: 0 6px;
    min-width: 20px;
    height: 18px;
    line-height: 16px;
    text-align: center;
    font-weight: 500;
    margin-left: 6px;
}

/* 右侧聊天内容 */
.chat-content {
    flex: 1;
    padding: 20px;
    overflow-y: auto;
    background: rgba(11, 23, 42, 0.2);
}

.message-item {
    display: flex;
    margin-bottom: 20px;
    align-items: flex-start;
}

.message-item.user-message {
    flex-direction: row-reverse;
}

.message-content {
    max-width: 70%;
    padding: 12px 16px;
    border-radius: 14px;
    border-top-left-radius: 2px;
    background-color: rgba(30, 41, 59, 0.9);
    border: 1px solid rgba(255, 255, 255, 0.08);
    color: #f1f5f9;
    box-shadow: 0 4px 14px rgba(0, 0, 0, 0.15);
    margin: 0 12px;
    line-height: 1.5;
    font-size: 14px;
    position: relative;
    display: flex;
    align-items: center;
    word-break: break-word;
}

.user-message .message-content {
    border-top-left-radius: 14px;
    border-top-right-radius: 2px;
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    border: 1px solid rgba(96, 165, 250, 0.3);
    color: #ffffff;
    box-shadow: 0 4px 14px rgba(37, 99, 235, 0.3);
    flex-direction: row-reverse;
}

.tool-message .message-content {
    background-color: rgba(15, 23, 42, 0.85);
    border: 1px dashed rgba(56, 189, 248, 0.4);
    color: #e2e8f0;
}

.audio-icon {
    font-size: 20px;
    cursor: pointer;
    margin: 0 6px;
    color: #60a5fa;
    transition: transform 0.2s ease, color 0.2s ease;
}

.audio-icon:hover {
    transform: scale(1.15);
    color: #93c5fd;
}

.user-message .audio-icon {
    color: #ffffff;
}

.content-wrapper {
    width: 100%;
}

.text-content {
    display: block;
    margin-bottom: 4px;
}

.tool-call-text {
    color: #38bdf8;
    font-family: 'Fira Code', Consolas, Monaco, monospace;
    font-weight: 500;
    font-size: 12px;
    background: rgba(0, 0, 0, 0.25);
    padding: 6px 10px;
    border-radius: 6px;
    margin-top: 6px;
    word-break: break-all;
    display: block;
}

.user-message .tool-call-text {
    color: #e0f2fe;
    background: rgba(0, 0, 0, 0.2);
}

.tool-result-wrapper {
    position: relative;
    padding-right: 22px;
}

.tool-result-collapsed {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.tool-toggle-btn {
    position: absolute;
    right: 0;
    top: 0;
    cursor: pointer;
    color: #38bdf8;
    font-size: 13px;
    transition: color 0.2s ease;
}

.tool-toggle-btn:hover {
    color: #7dd3fc;
}

.loading,
.no-more {
    text-align: center;
    padding: 12px 10px 24px 10px;
    color: rgba(255, 255, 255, 0.45);
    font-size: 12px;
}

.no-session-selected {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100%;
    color: rgba(255, 255, 255, 0.45);
    font-size: 14px;
}

.time-divider {
    text-align: center;
    margin: 16px 0;
    color: rgba(255, 255, 255, 0.45);
    font-size: 12px;
}

.time-divider::before,
.time-divider::after {
    content: '';
    display: inline-block;
    width: 25%;
    height: 1px;
    background-color: rgba(255, 255, 255, 0.08);
    vertical-align: middle;
    margin: 0 12px;
}

/* 底部下载按钮区 */
.download-buttons {
    padding: 12px 20px;
    display: flex;
    gap: 12px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
    background-color: rgba(15, 23, 42, 0.95);
    backdrop-filter: blur(10px);
    flex-shrink: 0;
}

.download-buttons .el-button {
    flex: 1;
    height: 38px;
    border-radius: 8px;
    font-weight: 500;
    background: rgba(30, 41, 59, 0.8) !important;
    border: 1px solid rgba(59, 130, 246, 0.35) !important;
    color: #60a5fa !important;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

.download-buttons .el-button:hover {
    background: rgba(37, 99, 235, 0.25) !important;
    border-color: #60a5fa !important;
    color: #ffffff !important;
    box-shadow: 0 4px 12px rgba(37, 99, 235, 0.25) !important;
}

/* 滚动条细致优化 */
.session-list::-webkit-scrollbar,
.chat-content::-webkit-scrollbar {
    width: 5px;
}

.session-list::-webkit-scrollbar-thumb,
.chat-content::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.15);
    border-radius: 4px;
}

.session-list::-webkit-scrollbar-thumb:hover,
.chat-content::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.3);
}
</style>

<style>
.dialog-fade-enter-active .chat-history-dialog {
    animation: chat-history-dialog-in 220ms cubic-bezier(0.22, 1, 0.36, 1) both !important;
}

@keyframes chat-history-dialog-in {
    from {
        opacity: 0;
        transform: translate(-50%, -50%) scale(0.97);
    }

    to {
        opacity: 1;
        transform: translate(-50%, -50%) scale(1);
    }
}

.chat-history-dialog {
    display: flex;
    flex-direction: column;
    min-width: 700px;
    margin: 0 !important;
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    height: 90vh;
    max-height: 850px;
    max-width: 85vw;
    border-radius: 16px;
    overflow: hidden;
    background-color: #0b1329 !important;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.5) !important;
}

.chat-history-dialog .el-dialog__header {
    background: rgba(15, 23, 42, 0.7);
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding: 16px 24px;
}

.chat-history-dialog .el-dialog__body {
    padding: 0;
    overflow: hidden;
    flex: 1;
    height: calc(100% - 54px);
}
</style>
