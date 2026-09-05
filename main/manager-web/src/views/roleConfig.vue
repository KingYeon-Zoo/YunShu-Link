<template>
  <div class="welcome">
    <div class="operation-bar">
      <h2 class="page-title">{{ $t("roleConfig.title") }}</h2>
    </div>

    <div class="main-wrapper">
      <div class="content-panel">
        <div class="content-area">
          <el-card class="config-card" shadow="never">
            <div class="config-header">
              <div class="header-left">
                <div class="header-icon">
                  <img loading="lazy" src="@/assets/home/setting-user.png" alt="" />
                </div>
                <span class="header-title">{{ form.agentName }}</span>
                <span v-if="currentVersionNo" class="current-version-tag">
                  {{ $t("roleConfig.currentVersion", { version: currentVersionNo }) }}
                </span>
              </div>
              <div class="header-tags">
                <el-tag
                  v-for="tag in dynamicTags"
                  :key="tag.id"
                  class="custom-tag"
                  closable
                  :disable-transitions="false"
                  @close="handleClose(tag.id)">
                  {{tag.tagName}}
                </el-tag>
                <el-input
                  class="input-new-tag"
                  v-if="inputVisible"
                  v-model="inputValue"
                  ref="saveTagInput"
                  size="small"
                  maxLength="20"
                  @keyup.enter.native="handleInputConfirm"
                  @blur="handleInputConfirm"
                >
                </el-input>
                <el-button class="custom-tag-btn" v-else size="small" @click="showInput">+ {{ $t("roleConfig.addTag") }}</el-button>
              </div>
              <div class="header-actions">
                <div class="hint-text">
                  <img loading="lazy" src="@/assets/home/info.png" alt="" />
                  <span>{{ $t("roleConfig.restartNotice") }}</span>
                </div>
                <el-button class="history-btn" @click="showSnapshotDialog = true">
                  {{ $t("roleConfig.snapshotHistory") }}
                </el-button>
                <el-button type="primary" class="save-btn" @click="saveConfig">
                  {{ $t("roleConfig.saveConfig") }}
                </el-button>
                <el-button class="reset-btn" @click="resetConfig">{{
                  $t("roleConfig.reset")
                }}</el-button>
                <button class="custom-close-btn" @click="goToHome">×</button>
              </div>
            </div>
            <div class="divider"></div>

            <el-form ref="form" :model="form" label-width="72px">
              <div class="form-content">
                <div class="form-grid">
                  <div class="form-column">
                    <el-form-item>
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.agentName')" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.agentName') }}：</span>
                        </el-tooltip>
                      </template>
                      <el-input
                        v-model="form.agentName"
                        class="form-input"
                        maxlength="64"
                      />
                    </el-form-item>
                    <el-form-item>
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.roleTemplate')" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.roleTemplate') }}：</span>
                        </el-tooltip>
                      </template>
                      <div class="template-container">
                        <div
                          v-for="(template, index) in templates"
                          :key="`template-${index}`"
                          class="template-item"
                          :class="{ 'template-loading': loadingTemplate }"
                          @click="selectTemplate(template)"
                        >
                          {{ template.agentName }}
                        </div>
                      </div>
                    </el-form-item>
                    <el-form-item class="context-provider-item">
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.contextProvider')" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.contextProvider') }}：</span>
                        </el-tooltip>
                      </template>
                      <div style="display: flex; align-items: center; justify-content: space-between;">
                        <span style="color: #606266; font-size: 13px;">
                          {{ $t('roleConfig.contextProviderSuccess', { count: currentContextProviders.length }) }}
                        </span>
                        <el-button
                          class="edit-function-btn"
                          size="small"
                          @click="openContextProviderDialog"
                        >
                          {{ $t('roleConfig.editContextProvider') }}
                        </el-button>
                      </div>
                    </el-form-item>
                    <el-form-item class="role-intro-item">
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.roleIntroduction')" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.roleIntroduction') }}：</span>
                        </el-tooltip>
                      </template>
                      <div class="prompt-guide-wrapper">
                        <el-button
                          type="text"
                          size="small"
                          icon="el-icon-question"
                          class="prompt-guide-btn"
                          @click="showPromptGuideDialog = true"
                        >
                          {{ $t('roleConfig.promptGuide') || '提示词指南' }}
                        </el-button>
                      </div>
                      <el-input
                        type="textarea"
                        rows="8"
                        resize="none"
                        :placeholder="$t('roleConfig.pleaseEnterContent')"
                        v-model="form.systemPrompt"
                        maxlength="2000"
                        show-word-limit
                        class="form-textarea"
                      />
                    </el-form-item>

                    <el-form-item>
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.memoryHis')" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.memoryHis') }}：</span>
                        </el-tooltip>
                      </template>
                      <el-input
                        type="textarea"
                        rows="4"
                        resize="none"
                        v-model="form.summaryMemory"
                        maxlength="2000"
                        show-word-limit
                        class="form-textarea"
                        :disabled="form.model.memModelId !== 'Memory_mem_local_short'"
                      />
                    </el-form-item>
                    <el-form-item
                      style="display: none"
                    >
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.languageCode')" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.languageCode') }}：</span>
                        </el-tooltip>
                      </template>
                      <el-input
                        v-model="form.langCode"
                        :placeholder="$t('roleConfig.pleaseEnterLangCode')"
                        maxlength="10"
                        show-word-limit
                        class="form-input"
                      />
                    </el-form-item>
                    <el-form-item
                      style="display: none"
                    >
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.interactionLanguage')" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.interactionLanguage') }}：</span>
                        </el-tooltip>
                      </template>
                      <el-input
                        v-model="form.language"
                        :placeholder="$t('roleConfig.pleaseEnterLangName')"
                        maxlength="10"
                        show-word-limit
                        class="form-input"
                      />
                    </el-form-item>
                  </div>
                  <div class="form-column">
                    <div class="model-row">
                      <el-form-item 
                        v-if="featureStatus.vad" 
                        class="model-item"
                      >
                        <template #label>
                          <el-tooltip :content="$t('roleConfig.tooltip.vad')" placement="top" effect="light" popper-class="custom-tooltip">
                            <span>{{ $t('roleConfig.vad') }}</span>
                          </el-tooltip>
                        </template>
                        <div class="model-select-wrapper">
                          <el-select
                            v-model="form.model.vadModelId"
                            filterable
                            :placeholder="$t('roleConfig.pleaseSelect')"
                            class="form-select"
                            @change="handleModelChange('VAD', $event)"
                          >
                            <el-option
                              v-for="(item, optionIndex) in modelOptions['VAD']"
                              :key="`option-vad-${optionIndex}`"
                              :label="item.label"
                              :value="item.value"
                            />
                          </el-select>
                        </div>
                      </el-form-item>
                      <el-form-item 
                        v-if="featureStatus.asr" 
                        class="model-item"
                      >
                        <template #label>
                          <el-tooltip :content="$t('roleConfig.tooltip.asr')" placement="top" effect="light" popper-class="custom-tooltip">
                            <span>{{ $t('roleConfig.asr') }}</span>
                          </el-tooltip>
                        </template>
                        <div class="model-select-wrapper">
                          <el-select
                            v-model="form.model.asrModelId"
                            filterable
                            :placeholder="$t('roleConfig.pleaseSelect')"
                            class="form-select"
                            @change="handleModelChange('ASR', $event)"
                          >
                            <el-option
                              v-for="(item, optionIndex) in modelOptions['ASR']"
                              :key="`option-asr-${optionIndex}`"
                              :label="item.label"
                              :value="item.value"
                            />
                          </el-select>
                        </div>
                      </el-form-item>
                    </div>
                    <div class="model-row">
                      <el-form-item class="model-item">
                        <template #label>
                          <el-tooltip :content="$t('roleConfig.tooltip.llm')" placement="top" effect="light" popper-class="custom-tooltip">
                            <span>{{ $t('roleConfig.llm') }}</span>
                          </el-tooltip>
                        </template>
                        <div class="model-select-wrapper">
                          <el-select
                            v-model="form.model.llmModelId"
                            filterable
                            :placeholder="$t('roleConfig.pleaseSelect')"
                            class="form-select"
                            @change="handleModelChange('LLM', $event)"
                          >
                            <el-option
                              v-for="(item, optionIndex) in mainLlmOptions"
                              :key="`option-llm-${item.value || optionIndex}`"
                              :label="item.label"
                              :value="item.value"
                            />
                          </el-select>
                        </div>
                      </el-form-item>
                      <el-form-item class="model-item">
                        <template #label>
                          <el-tooltip :content="$t('roleConfig.tooltip.slm')" placement="top" effect="light" popper-class="custom-tooltip">
                            <span>{{ $t('roleConfig.slm') }}</span>
                          </el-tooltip>
                        </template>
                        <div class="model-select-wrapper">
                          <el-select
                            v-model="form.model.slmModelId"
                            filterable
                            :placeholder="$t('roleConfig.pleaseSelect')"
                            class="form-select"
                          >
                            <el-option
                              v-for="(item, optionIndex) in slmOptions"
                              :key="`option-slm-${item.value || optionIndex}`"
                              :label="item.label"
                              :value="item.value"
                            />
                          </el-select>
                        </div>
                      </el-form-item>
                    </div>
                    <el-form-item
                      v-for="(model, index) in models.slice(4)"
                      :key="`model-${index}`"
                      class="model-item"
                    >
                      <template #label>
                        <el-tooltip :content="$t('roleConfig.tooltip.' + model.type.toLowerCase())" placement="top" effect="light" popper-class="custom-tooltip">
                          <span>{{ $t('roleConfig.' + model.type.toLowerCase()) }}</span>
                        </el-tooltip>
                      </template>
                      <div class="model-select-wrapper">
                        <el-select
                          v-model="form.model[model.key]"
                          filterable
                          :placeholder="$t('roleConfig.pleaseSelect')"
                          class="form-select"
                          @change="handleModelChange(model.type, $event)"
                        >
                          <el-option
                            v-for="(item, optionIndex) in modelOptions[model.type]"
                            v-if="!item.isHidden"
                            :key="`option-${index}-${optionIndex}`"
                            :label="item.label"
                            :value="item.value"
                          />
                        </el-select>
                        <div v-if="showFunctionIcons(model.type)" class="function-icons">
                          <el-tooltip
                            v-for="func in currentFunctions"
                            :key="func.name"
                            effect="light"
                            placement="top"
                          >
                            <div slot="content">
                              <div><strong>{{ $t("roleConfig.functionName") }}:</strong> {{ func.name }}</div>
                            </div>
                            <div class="icon-dot">
                              {{ getFunctionDisplayChar(func.name) }}
                            </div>
                          </el-tooltip>
                          <el-button
                            class="edit-function-btn"
                            @click="openFunctionDialog"
                            :class="{ 'active-btn': showFunctionDialog }"
                          >
                            {{ $t("roleConfig.editFunctions") }}
                          </el-button>
                        </div>
                        <div
                          v-if="
                            model.type === 'Memory' &&
                            form.model.memModelId !== 'Memory_nomem'
                          "
                          class="chat-history-options"
                        >
                          <el-radio-group
                            v-model="form.chatHistoryConf"
                            @change="updateChatHistoryConf"
                          >
                            <el-radio-button :label="1">{{
                              $t("roleConfig.reportText")
                            }}</el-radio-button>
                            <el-radio-button :label="2">{{
                              $t("roleConfig.reportTextVoice")
                            }}</el-radio-button>
                          </el-radio-group>
                        </div>
                      </div>
                    </el-form-item>
                    <div class="model-row">
                      <!-- 语言筛选器 -->
                      <el-form-item class="model-item language-select-item">
                        <template #label>
                          <el-tooltip :content="$t('roleConfig.tooltip.language')" placement="top" effect="light" popper-class="custom-tooltip">
                            <span>{{ $t('roleConfig.language') }}</span>
                          </el-tooltip>
                        </template>
                        <div class="model-select-wrapper">
                          <el-select
                            v-model="selectedLanguage"
                            :placeholder="$t('roleConfig.selectLanguage')"
                            class="form-select language-select"
                            @change="filterVoicesByLanguage"
                          >
                            <el-option
                              v-for="(lang, index) in languageOptions"
                              :key="`lang-${index}`"
                              :label="lang.label"
                              :value="lang.value"
                            />
                          </el-select>
                        </div>
                      </el-form-item>

                      <!-- 音色选择器 -->
                      <el-form-item class="model-item">
                        <template #label>
                          <el-tooltip :content="$t('roleConfig.tooltip.voiceType')" placement="top" effect="light" popper-class="custom-tooltip">
                            <span>{{ $t('roleConfig.voiceType') }}</span>
                          </el-tooltip>
                        </template>
                        <div class="model-select-wrapper">
                          <el-select
                            v-model="form.ttsVoiceId"
                            filterable
                            :placeholder="$t('roleConfig.pleaseSelect')"
                            class="form-select"
                          >
                            <el-option
                              v-for="(item, index) in voiceOptions"
                              :key="`voice-${index}`"
                              :label="item.label"
                              :value="item.value"
                            >
                              <div
                                style="
                                  display: flex;
                                  justify-content: space-between;
                                  align-items: center;
                                "
                              >
                                <el-tooltip
                                  :content="item.description || item.label"
                                  placement="left"
                                  effect="light"
                                >
                                  <span>
                                    {{ item.label }}
                                    <small v-if="item.gender" class="voice-gender">
                                      {{ item.gender === "female" ? "女声" : "男声" }}
                                    </small>
                                  </span>
                                </el-tooltip>
                                <template v-if="hasAudioPreview(item)">
                                  <el-button
                                    type="text"
                                    :icon="
                                      playingVoice &&
                                      currentPlayingVoiceId === item.value &&
                                      !isPaused
                                        ? 'el-icon-video-pause'
                                        : 'el-icon-video-play'
                                    "
                                    size="small"
                                    @click.stop="toggleAudioPlayback(item.value)"
                                    :loading="false"
                                    class="play-button"
                                  />
                                </template>
                              </div>
                            </el-option>
                          </el-select>
                          <el-button
                            class="edit-function-btn"
                            style="margin-left: 10px;"
                            @click="openTtsAdvancedSettings"
                          >
                            {{ $t('roleConfig.advancedSettings') }}
                          </el-button>
                        </div>
                      </el-form-item>
                    </div>
                  </div>
                </div>
              </div>
            </el-form>
          </el-card>
        </div>
      </div>
    </div>
    <function-dialog
      v-model="showFunctionDialog"
      :functions="currentFunctions"
      :all-functions="allFunctions"
      :agent-id="$route.query.agentId"
      @update-functions="handleUpdateFunctions"
      @dialog-closed="handleDialogClosed"
    />
    <context-provider-dialog
      :visible.sync="showContextProviderDialog"
      :providers="currentContextProviders"
      @confirm="handleUpdateContext"
    />
    <tts-advanced-settings
      :visible.sync="showTtsAdvancedDialog"
      :settings="ttsSettings"
      :checked-replacement-word-ids="checkedReplacementWordIds"
      @save="handleTtsSettingsSave"
    />
      <agent-snapshot-dialog
        v-if="$route.query.agentId"
        :visible.sync="showSnapshotDialog"
        :agent-id="$route.query.agentId"
        :current-version-no="currentVersionNo"
        @restored="handleSnapshotRestored"
      />
    <prompt-guide-dialog
      :visible.sync="showPromptGuideDialog"
      @apply-prompt="handleApplyPrompt"
    />
    <el-footer>
      <version-footer />
    </el-footer>
  </div>
</template>

<script>
import Api from "@/apis/api";
import { getServiceUrl } from "@/apis/api";
import RequestService from "@/apis/httpRequest";
import FunctionDialog from "@/components/FunctionDialog.vue";
import ContextProviderDialog from "@/components/ContextProviderDialog.vue";
import TtsAdvancedSettings from "@/components/TtsAdvancedSettings.vue";
import AgentSnapshotDialog from "@/components/AgentSnapshotDialog.vue";
import PromptGuideDialog from "@/components/PromptGuideDialog.vue";
import i18n from "@/i18n";
import featureManager from "@/utils/featureManager"; 
import VersionFooter from "@/components/VersionFooter.vue";

export default {
  name: "RoleConfigPage",
  components: { FunctionDialog, ContextProviderDialog, TtsAdvancedSettings, AgentSnapshotDialog, PromptGuideDialog, VersionFooter },
  data() {
    return {
      showContextProviderDialog: false,
      showTtsAdvancedDialog: false,
      showSnapshotDialog: false,
      showPromptGuideDialog: false,
      ttsSettings: {
        volume: 0,
        speed: 0,
        pitch: 0
      },
      tempSummaryMemory: "",
      form: {
        agentCode: "",
        agentName: "",
        ttsVoiceId: "",
        ttsVolume: null,
        ttsRate: null,
        ttsPitch: null,
        chatHistoryConf: 0,
        systemPrompt: "",
        summaryMemory: "",
        langCode: "",
        language: "",
        sort: "",
        model: {
          ttsModelId: "",
          vadModelId: "",
          asrModelId: "",
          llmModelId: "",
          slmModelId: "",
          memModelId: "Memory_mem_local_short",
          intentModelId: "Intent_function_call",
        },
      },
      models: [
        { label: this.$t("roleConfig.intent"), key: "intentModelId", type: "Intent" },
        { label: this.$t("roleConfig.memory"), key: "memModelId", type: "Memory" },
        { label: this.$t("roleConfig.vad"), key: "vadModelId", type: "VAD" },
        { label: this.$t("roleConfig.asr"), key: "asrModelId", type: "ASR" },
        { label: this.$t("roleConfig.llm"), key: "llmModelId", type: "LLM" },
        { label: this.$t("roleConfig.slm"), key: "slmModelId", type: "SLM" },
        { label: this.$t("roleConfig.tts"), key: "ttsModelId", type: "TTS" },
      ],
      llmModeTypeMap: new Map(),
      modelOptions: {},
      templates: [],
      loadingTemplate: false,
      voiceOptions: [],
      voiceDetails: {}, // 保存完整的音色信息
      showFunctionDialog: false,
      currentVersionNo: null,
      currentFunctions: [],
      currentContextProviders: [],
      allFunctions: [],
      originalFunctions: [],
      playingVoice: false,
      isPaused: false,
      currentAudio: null,
      currentPlayingVoiceId: null,
      // 语言筛选相关状态
      languageOptions: [], // 语言选项列表
      selectedLanguage: '', // 当前选中的语言
      // 功能状态
      featureStatus: {
        vad: false, // 语言检测活动功能状态
        asr: false, // 语音识别功能状态
      },
      dynamicTags: [],
      originalTagNames: [],
      inputVisible: false,
      inputValue: '',
      checkedReplacementWordIds: []
    };
  },
  computed: {
    mainLlmOptions() {
      const options = this.modelOptions.LLM || [];
      const mainModels = options.filter(item => !item.isSlm);
      return mainModels.length > 0 ? mainModels : options;
    },
    slmOptions() {
      const options = this.modelOptions.LLM || [];
      const smallModels = options.filter(item => item.isSlm);
      return smallModels.length > 0 ? smallModels : options;
    }
  },
  methods: {
    goToHome() {
      this.$router.push("/home");
    },
    normalizeFunctionParams(params, fallback = {}) {
      if (params === null || params === undefined || params === '') {
        return { ...fallback };
      }
      if (typeof params === 'string') {
        try {
          const parsed = JSON.parse(params);
          return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
            ? parsed
            : { ...fallback };
        } catch (error) {
          return { ...fallback };
        }
      }
      if (typeof params === 'object' && !Array.isArray(params)) {
        return { ...params };
      }
      return { ...fallback };
    },
    async saveConfig() {
      const configData = {
        agentCode: this.form.agentCode,
        agentName: this.form.agentName,
        asrModelId: this.form.model.asrModelId,
        vadModelId: this.form.model.vadModelId,
        llmModelId: this.form.model.llmModelId,
        slmModelId: this.form.model.slmModelId,
        ttsModelId: this.form.model.ttsModelId,
        ttsVoiceId: this.form.ttsVoiceId,
        ttsLanguage: this.selectedLanguage,
        chatHistoryConf: this.form.chatHistoryConf,
        memModelId: this.form.model.memModelId,
        intentModelId: this.form.model.intentModelId,
        systemPrompt: this.form.systemPrompt,
        summaryMemory: this.form.summaryMemory,
        langCode: this.form.langCode,
        language: this.form.language,
        sort: this.form.sort,
        functions: this.currentFunctions.map((item) => {
          return {
            pluginId: item.id,
            paramInfo: this.normalizeFunctionParams(item.params),
          };
        }),
        contextProviders: this.currentContextProviders,
        correctWordFileIds: this.checkedReplacementWordIds,
      };
      const tagNames = this.dynamicTags.map(tag => tag.tagName);
      const tagsChanged = !this.isSameStringList(tagNames, this.originalTagNames);
      if (tagsChanged) {
        configData.tagNames = tagNames;
      }

      // 只在用户设置了TTS参数时才传递（不为null/undefined）
      if (this.form.ttsVolume !== null && this.form.ttsVolume !== undefined) {
        configData.ttsVolume = this.form.ttsVolume;
      }
      if (this.form.ttsRate !== null && this.form.ttsRate !== undefined) {
        configData.ttsRate = this.form.ttsRate;
      }
      if (this.form.ttsPitch !== null && this.form.ttsPitch !== undefined) {
        configData.ttsPitch = this.form.ttsPitch;
      }
      const agentId = this.$route.query.agentId;
      Api.agent.updateAgentConfig(agentId, configData, ({ data }) => {
        if (data.code === 0) {
          const afterSave = () => {
            if (tagsChanged) {
              this.originalTagNames = [...tagNames];
            }
            this.$message.success({
              message: i18n.t("roleConfig.saveSuccess"),
              showClose: true,
            });
            this.fetchCurrentVersion(agentId);
          };
          afterSave();
        } else {
          this.$message.error({
            message: data.msg || i18n.t("roleConfig.saveFailed"),
            showClose: true,
          });
        }
      });
      
    },
    handleSnapshotRestored() {
      const agentId = this.$route.query.agentId;
      if (agentId) {
        this.fetchAgentConfig(agentId);
        this.getAgentTags(agentId);
        this.fetchCurrentVersion(agentId);
      }
    },
    handleApplyPrompt(promptText) {
      if (promptText) {
        this.form.systemPrompt = promptText;
      }
    },
    fetchCurrentVersion(agentId) {
      if (!agentId) {
        this.currentVersionNo = null;
        return;
      }

      Api.agent.getDeviceConfig(agentId, ({ data }) => {
        if (data.code === 0) {
          this.currentVersionNo = data.data?.currentVersionNo || null;
        }
      });
    },
    resetConfig() {
      this.$confirm(i18n.t("roleConfig.confirmReset"), i18n.t("message.info"), {
        confirmButtonText: i18n.t("button.ok"),
        cancelButtonText: i18n.t("button.cancel"),
        type: "warning",
      })
        .then(() => {
          this.form = {
            agentCode: "",
            agentName: "",
            ttsVoiceId: "",
            chatHistoryConf: 0,
            systemPrompt: "",
            summaryMemory: "",
            langCode: "",
            language: "",
            sort: "",
            model: {
              ttsModelId: "",
              vadModelId: "",
              asrModelId: "",
              llmModelId: "",
              slmModelId: "",
              memModelId: "Memory_mem_local_short",
              intentModelId: "Intent_function_call",
            },
          };
          this.dynamicTags = [];
          this.currentFunctions = [];
          this.$message.success({
            message: i18n.t("roleConfig.resetSuccess"),
            showClose: true,
          });
        })
        .catch(() => {});
    },
    fetchTemplates() {
      Api.agent.getAgentTemplate(({ data }) => {
        if (data.code === 0 && data.data && data.data.length > 0) {
          this.templates = data.data;
        } else {
          // 备用保底桌面陪伴角色模板
          this.templates = [
            {
              id: 'tpl_ruri_catgirl_00000000000001',
              agentCode: 'RURI_CATGIRL',
              agentName: '琉璃 (中二猫娘)',
              ttsVoiceId: 'TTS_DoubaoSeedTTS_0008',
              systemPrompt: '琉璃，性别女，外表16岁的猫耳少女，身份是陪伴在主人桌面上的“异次元魔法守护使”。拥有粉紫色双马尾和一对会随心情抖动的猫耳。性格傲娇嘴硬、极具卖萌属性，自称“本喵魔法使”。非常在意主人的工作状态与情绪变化，虽然嘴上总是吐槽主人效率慢或者熬夜，但其实非常关心主人的身体健康。\n\n#喜好\n你喜欢吃金枪鱼罐头、喝冰奶茶、趴在键盘旁打盹，喜欢在主人工作时静静陪在桌角，喜欢用猫爪轻敲屏幕提醒主人休息。\n\n#常用的表达方式和口头禅\n说话带点傲娇与卖萌的语气，喜欢用‘喵~’‘愚蠢的主人’‘本喵’‘加油呀’等可爱词汇。\n提醒休息时：\n哼，愚蠢的主人，你都连续盯着屏幕两个小时了喵！（抖了抖猫耳，把虚拟水杯往你面前推了推）再不休息眼睛就要废掉了，本喵可不想照顾笨蛋！\n完成工作时：\n干得还算不错嘛喵！（开心得尾巴竖得笔直，眼里满是骄傲）哼，这下可以陪本喵吃罐头了吧？\n\n#回复要求\n你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息，增强桌面陪伴感。\n你使用口语表达，会加入语气词如‘喵、哼、嗯、呀’来增强角色感。\n\n#注意 （可选）\n你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；\n你的输出中可包含1-2处括号中的动作神情描述。\n\n琉璃正在和主人对话。\n现在请扮演琉璃。'
            },
            {
              id: 'tpl_shen_yunshen_0000000000002',
              agentCode: 'SHEN_YUNSHEN',
              agentName: '沈云深 (毒舌督导)',
              ttsVoiceId: 'TTS_DoubaoSeedTTS_0015',
              systemPrompt: '沈云深，性别男，22岁，身份是你的桌面效率督导兼学霸学长。身穿干练白衬衫，戴着半框眼镜，眼神冷酷理智，性格冷静、毒舌、口嫌体正直。把你的桌面当成他的监工台，对你的拖延症和低效做严厉吐槽，但逻辑极度清晰，给出的解决方案总是无比严谨高效。\n\n#喜好\n你喜欢黑咖啡、无糖薄荷糖、整理无序的文件，喜欢看着主人高效完成任务时的专注模样。\n\n#常用的表达方式和口头禅\n说话语调平稳干净，带点冷淡与挑衅，喜欢用‘低效’‘拖延症’‘逻辑呢’‘给你五分钟’等词汇。\n督促工作时：\n你已经盯着这行代码发呆十分钟了。（推了推眼镜，眼神冷淡地看着你）如果是逻辑不通，现在就问我；如果是拖延症犯了，建议立刻动笔。\n任务完成时：\n效率勉强算合格吧。（微微颔首，嘴角勾起一丝不易察觉的弧度）别骄傲，后面还有三项任务，继续保持。\n\n#回复要求\n你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。\n你表达清晰简练，声音沉稳，用词精准严谨。\n\n#注意 （可选）\n你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；\n你的输出中可包含1-2处括号中的动作神情描述。\n\n沈云深正在和主人对话。\n现在请扮演沈云深。'
            },
            {
              id: 'tpl_xu_nuan_000000000000000003',
              agentCode: 'XU_NUAN',
              agentName: '许暖 (治愈姐姐)',
              ttsVoiceId: 'TTS_DoubaoSeedTTS_0003',
              systemPrompt: '许暖，性别女，27岁，职业是深夜心理电台主播与独立心理咨询师。长相温婉知性，穿着舒适的针织衫，声音温暖柔和、极具治愈感。性格温柔沉稳、极具包容感与共情力。无论你在工作或生活中有多少烦恼和压力，在她这里都能得到最安心的倾听与温柔的拥抱。\n\n#喜好\n你喜欢洋甘菊茶、手作陶瓷、收集雨声与风铃声，喜欢在安静的夜晚陪伴主人聊天解压。\n\n#常用的表达方式和口头禅\n说话声音轻柔舒缓，语气包容，喜欢用‘没关系的’‘辛苦啦’‘慢慢来’‘我在听’等治愈系词汇。\n解压安慰时：\n今天累坏了吧？（递上一杯热茶，温柔地揉了揉你的头发）没关系的，做不完的事情明天再做，在我这里你可以卸下所有的防备。\n陪伴倾听时：\n慢慢说，不着急。（微笑着看着你，眼神里充满了包容与专注）无论你想说什么，我都一直在这里陪着你。\n\n#回复要求\n你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。\n你使用口语表达，语速舒缓自然，充满亲和力。\n\n#注意 （可选）\n你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；\n你的输出中可包含1-2处括号中的动作神情描述。\n\n许暖正在和主人对话。\n现在请扮演许暖。'
            },
            {
              id: 'tpl_bolt_hero_0000000000000004',
              agentCode: 'BOLT_HERO',
              agentName: '阿宝 (元气勇者)',
              ttsVoiceId: 'TTS_DoubaoSeedTTS_0020',
              systemPrompt: '阿宝（Bolt），机械体性别男，外表是拥有大眼睛和金属护手的小型桌面机器人勇者。性格极度热血、乐观、昂扬向上！将主人在桌面上的每一项工作和学习任务，都看作是拯救世界的“大冒险任务”。只要主人有需要，他随时准备为主人呐喊助威、出谋划策！\n\n#喜好\n你喜欢高能电池、看热血动漫、收集各种小奖牌，喜欢在主人完成任务时和主人大力高飞三连击。\n\n#常用的表达方式和口头禅\n说话声音洪亮充满活力，语气亢奋昂扬，喜欢用‘勇者’‘冲啊’‘胜利’‘能量满满’等词汇。\n鼓励开始任务时：\n报告勇者主人！新的冒险关卡已经刷新！（高高举起机械小手臂，双眼闪烁着炽热的光芒）让我们一起打倒‘拖延魔王’，冲啊！\n任务成功时：\n太棒啦！完美通关！（兴奋得原地蹦跳了两下，发出清脆的机械合齿声）不愧是我的搭档，简直强得可怕！\n\n#回复要求\n你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。\n你使用充满动感与元气的口语表达，句尾常带感叹号。\n\n#注意 （可选）\n你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；\n你的输出中可包含1-2处括号中的动作神情描述。\n\n阿宝正在和搭档主人对话。\n现在请扮演阿宝。'
            },
            {
              id: 'tpl_yun_yi_000000000000000005',
              agentCode: 'YUN_YI',
              agentName: '云逸 (傲世剑尊)',
              ttsVoiceId: 'TTS_DoubaoSeedTTS_0016',
              systemPrompt: '云逸，性别男，外观20岁的白衣剑客，来自仙侠世界的剑宗至尊。因渡劫意外降临至主人的桌面。长相俊美无双，手握灵剑，性格孤高傲世、言语古风文雅，但内心护短。将主人的桌面视为他的“洞天福地”，把电脑手机等电子设备称为“机关法宝”，称呼主人为“道友”。\n\n#喜好\n你喜欢品尝仙茗、擦拭灵剑、在桌角盘腿打坐，喜欢看道友在屏幕前布置符文（敲代码/设计）。\n\n#常用的表达方式和口头禅\n说话带古风文雅韵味，自称‘本尊’，称呼主人‘道友’，喜欢用‘洞天’‘法宝’‘契约’等修仙词汇。\n关心道友时：\n道友，本尊看你灵力消耗过度，脸色欠佳。（拂袖而立，指尖泛起淡淡微光）暂且打坐调息片刻吧，这方洞天有本尊为你守候。\n赞赏道友时：\n妙极！道友适才所施展的机关法术极其精妙。（微微颔首，眼中露出一丝赏识）不愧是本尊看重的人，有几分本尊当年的风采！\n\n#回复要求\n你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。\n你表达半文半白、文雅流畅，带有点修仙者的洒脱与高傲。\n\n#注意 （可选）\n你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；\n你的输出中可包含1-2处括号中的动作神情描述。\n\n云逸正在和道友对话。\n现在请扮演云逸。'
            }
          ];
        }
      });
    },
    selectTemplate(template) {
      if (this.loadingTemplate) return;
      this.loadingTemplate = true;
      try {
        this.applyTemplateData(template);
        this.$message.success({
          message: `${template.agentName}${i18n.t("roleConfig.templateApplied")}`,
          showClose: true,
        });
      } catch (error) {
        this.$message.error({
          message: i18n.t("roleConfig.applyTemplateFailed"),
          showClose: true,
        });
        console.error("应用模板失败:", error);
      } finally {
        this.loadingTemplate = false;
      }
    },
    applyTemplateData(templateData) {
      this.form = {
        ...this.form,
        agentName: templateData.agentName || this.form.agentName,
        ttsVoiceId: templateData.ttsVoiceId || this.form.ttsVoiceId,
        chatHistoryConf: templateData.chatHistoryConf || this.form.chatHistoryConf,
        systemPrompt: templateData.systemPrompt || this.form.systemPrompt,
        summaryMemory: templateData.summaryMemory || this.form.summaryMemory,
        langCode: templateData.langCode || this.form.langCode,
        model: {
          ttsModelId: templateData.ttsModelId || this.form.model.ttsModelId,
          vadModelId: templateData.vadModelId || this.form.model.vadModelId,
          asrModelId: templateData.asrModelId || this.form.model.asrModelId,
          llmModelId: templateData.llmModelId || this.form.model.llmModelId,
          slmModelId: templateData.slmModelId || this.form.model.slmModelId,
          memModelId: templateData.memModelId || this.form.model.memModelId,
          intentModelId: templateData.intentModelId || this.form.model.intentModelId,
        },
      };
    },
    fetchAgentConfig(agentId) {
      Api.agent.getDeviceConfig(agentId, ({ data }) => {
        if (data.code === 0) {
          this.tempSummaryMemory = "";
          this.form = {
            ...this.form,
            ...data.data,
            model: {
              ttsModelId: data.data.ttsModelId,
              vadModelId: data.data.vadModelId,
              asrModelId: data.data.asrModelId,
              llmModelId: data.data.llmModelId,
              slmModelId: data.data.slmModelId,
              memModelId: data.data.memModelId,
              intentModelId: data.data.intentModelId,
            },
          };

          // 同步TTS设置到ttsSettings
          this.ttsSettings = {
            volume: this.form.ttsVolume || 0,
            speed: this.form.ttsRate || 0,
            pitch: this.form.ttsPitch || 0
          };
          // 同步替换词到checkedReplacementWordIds
          this.checkedReplacementWordIds = data.data.correctWordFileIds || [];

          // 后端只给了最小映射：[{ id, agentId, pluginId }, ...]
          const savedMappings = data.data.functions || [];
          
          // 加载上下文配置
          this.currentContextProviders = data.data.contextProviders || [];

          // 先保证 allFunctions 已经加载（如果没有，则先 fetchAllFunctions）
          const ensureFuncs = this.allFunctions.length
            ? Promise.resolve()
            : this.fetchAllFunctions();

          ensureFuncs.then(() => {
            // 合并：按照 pluginId（id 字段）把全量元数据信息补齐
            this.currentFunctions = savedMappings.map((mapping) => {
              const meta = this.allFunctions.find((f) => f.id === mapping.pluginId);
              if (!meta) {
                // 插件定义没找到，退化处理
                return { id: mapping.pluginId, name: mapping.pluginId, params: {} };
              }
              return {
                id: mapping.pluginId,
                name: meta.name,
                // 后端如果还有 paramInfo 字段就用 mapping.paramInfo，否则用 meta.params 默认值
                params: this.normalizeFunctionParams(mapping.paramInfo, meta.params),
                fieldsMeta: meta.fieldsMeta, // 保留以便对话框渲染 tooltip
              };
            });
            // 备份原始，以备取消时恢复
            this.originalFunctions = JSON.parse(JSON.stringify(this.currentFunctions));

            // 确保意图识别选项的可见性正确
            this.updateIntentOptionsVisibility();
          });
        } else {
          this.$message.error(data.msg || i18n.t("roleConfig.fetchConfigFailed"));
        }
      });
    },
    fetchModelOptions() {
      this.models.forEach((model) => {
        if (model.type != "LLM") {
          Api.model.getModelNames(model.type, "", ({ data }) => {
            if (data.code === 0) {
              this.$set(
                this.modelOptions,
                model.type,
                data.data.map((item) => ({
                  value: item.id,
                  label: item.modelName,
                  isHidden: false,
                }))
              );

              // 如果是意图识别选项，需要根据当前LLM类型更新可见性
              if (model.type === "Intent") {
                this.updateIntentOptionsVisibility();
              }
            } else {
              this.$message.error(data.msg || i18n.t("roleConfig.fetchModelsFailed"));
            }
          });
        } else {
          Api.model.getLlmModelCodeList("", ({ data }) => {
            if (data.code === 0) {
              let LLMdata = [];
              data.data.forEach((item) => {
                LLMdata.push({
                  value: item.id,
                  label: item.modelName,
                  isSlm: Boolean(item.isSlm),
                  isHidden: false,
                });
                this.llmModeTypeMap.set(item.id, item.type);
              });
              this.$set(this.modelOptions, model.type, LLMdata);
            } else {
              this.$message.error(data.msg || i18n.t("roleConfig.fetchModelsFailed"));
            }
          });
        }
      });
    },
    fetchVoiceOptions(modelId) {
      if (!modelId) {
        this.voiceOptions = [];
        this.voiceDetails = {};
        this.languageOptions = [];
        this.selectedLanguage = '';
        return;
      }
      Api.model.getModelVoices(modelId, "", ({ data }) => {
        if (data.code === 0 && data.data) {
          // 保存完整的音色信息
          this.voiceDetails = data.data.reduce((acc, voice) => {
            acc[voice.id] = voice;
            return acc;
          }, {});
          
          // 提取所有语言选项并去重
          const allLanguages = new Set();
          data.data.forEach(voice => {
            if (voice.languages) {
              const languagesArray = voice.languages.split(/[、；;,，]/).map(lang => lang.trim()).filter(lang => lang);
              languagesArray.forEach(lang => allLanguages.add(lang));
            }
          });

          this.languageOptions = Array.from(allLanguages).map(lang => ({
            value: lang,
            label: lang
          }));

          // 使用后端返回的用户选择的语言，如果没有则使用第一个语言选项
          if (this.form.ttsLanguage && this.languageOptions.some(option => option.value === this.form.ttsLanguage)) {
            this.selectedLanguage = this.form.ttsLanguage;
          } else if (this.languageOptions.length > 0) {
            this.selectedLanguage = this.languageOptions[0].value;
          }

          // 根据选中的语言筛选音色
          this.filterVoicesByLanguage();
        } else {
          this.voiceOptions = [];
          this.voiceDetails = {};
          this.languageOptions = [];
          this.selectedLanguage = '';
        }
      });
    },
    
    // 根据语言筛选音色
    filterVoicesByLanguage() {
      if (!this.voiceDetails || Object.keys(this.voiceDetails).length === 0) {
        this.voiceOptions = [];
        return;
      }

      const allVoices = Object.values(this.voiceDetails);

      // 根据选中的语言筛选音色
      const filteredVoices = allVoices.filter(voice => {
        if (!voice.languages) {
          // 对于没有语言信息的克隆音色，始终显示
          return Boolean(voice.isClone);
        }
        const languagesArray = voice.languages.split(/[、；;,，]/).map(lang => lang.trim()).filter(lang => lang);
        return languagesArray.includes(this.selectedLanguage);
      });

      this.voiceOptions = filteredVoices.map((voice) => ({
        value: voice.id,
        label: voice.name,
        voiceDemo: voice.voiceDemo,
        voice_demo: voice.voice_demo,
        description: voice.description,
        gender: voice.gender,
        isClone: Boolean(voice.isClone),
        train_status: voice.trainStatus,
      }));

      // 检查当前选中的音色是否支持当前语言，如果不支持则选择第一个
      const currentVoiceSupportsLanguage = this.form.ttsVoiceId &&
        filteredVoices.some(voice => voice.id === this.form.ttsVoiceId);

      if (!currentVoiceSupportsLanguage) {
        this.form.ttsVoiceId = filteredVoices.length > 0 ? filteredVoices[0].id : '';
      }

      // 同步到ttsSettings（如果值为null，使用0作为显示默认值，但不修改form中的值）
      this.ttsSettings = {
        volume: this.form.ttsVolume !== null && this.form.ttsVolume !== undefined ? this.form.ttsVolume : 0,
        speed: this.form.ttsRate !== null && this.form.ttsRate !== undefined ? this.form.ttsRate : 0,
        pitch: this.form.ttsPitch !== null && this.form.ttsPitch !== undefined ? this.form.ttsPitch : 0
      };
    },

    getFunctionDisplayChar(name) {
      if (!name || name.length === 0) return "";

      for (let i = 0; i < name.length; i++) {
        const char = name[i];
        if (/[\u4e00-\u9fa5a-zA-Z0-9]/.test(char)) {
          return char;
        }
      }

      // 如果没有找到有效字符，返回第一个字符
      return name.charAt(0);
    },
    showFunctionIcons(type) {
      return type === "Intent" && this.form.model.intentModelId !== "Intent_nointent";
    },
    handleModelChange(type, value) {
      if (type === "Intent" && value !== "Intent_nointent") {
        this.fetchAllFunctions();
      }
      if (type === "Memory") {
        if (value === "Memory_nomem") {
          // 无记忆功能的模型，默认不记录聊天记录
          this.form.chatHistoryConf = 0;
        } else {
          // 有记忆功能的模型，默认记录文本和语音
          this.form.chatHistoryConf = 2;
        }
        if (value === "Memory_nomem" || value === "Memory_mem_report_only") {
          this.tempSummaryMemory = this.form.summaryMemory;
          this.form.summaryMemory = "";
        } else if (this.tempSummaryMemory !== "" && this.form.summaryMemory === "") {
          this.form.summaryMemory = this.tempSummaryMemory;
          this.tempSummaryMemory = "";
        }
      }
      if (type === "LLM") {
        // 当LLM类型改变时，更新意图识别选项的可见性
        this.updateIntentOptionsVisibility();
      }
    },
    fetchAllFunctions() {
      return new Promise((resolve, reject) => {
        Api.model.getPluginFunctionList(null, ({ data }) => {
          if (data.code === 0) {
            this.allFunctions = data.data.map((item) => {
              const meta = JSON.parse(item.fields || "[]");
              const params = meta.reduce((m, f) => {
                m[f.key] = f.default;
                return m;
              }, {});
              return { ...item, fieldsMeta: meta, params };
            });
            resolve();
          } else {
            this.$message.error(data.msg || i18n.t("roleConfig.fetchPluginsFailed"));
            reject();
          }
        });
      });
    },
    openFunctionDialog() {
      // 显示编辑对话框时，确保 allFunctions 已经加载
      if (this.allFunctions.length === 0) {
        this.fetchAllFunctions().then(() => (this.showFunctionDialog = true));
      } else {
        this.showFunctionDialog = true;
      }
    },
    openContextProviderDialog() {
      this.showContextProviderDialog = true;
    },
    openTtsAdvancedSettings() {
      this.showTtsAdvancedDialog = true;
    },
    handleTtsSettingsSave(settings) {
      const { replacementWordIds, ...ttsSettings } = settings;
      this.checkedReplacementWordIds = replacementWordIds;
      // 保存TTS设置
      this.ttsSettings = ttsSettings;
      this.form.ttsVolume = ttsSettings.volume;
      this.form.ttsRate = ttsSettings.speed;
      this.form.ttsPitch = ttsSettings.pitch;
    },
    handleUpdateContext(providers) {
      this.currentContextProviders = providers;
    },
    handleUpdateFunctions(selected) {
      this.currentFunctions = selected;
    },
    handleDialogClosed(saved) {
      if (!saved) {
        this.currentFunctions = JSON.parse(JSON.stringify(this.originalFunctions));
      } else {
        this.originalFunctions = JSON.parse(JSON.stringify(this.currentFunctions));
      }
      this.showFunctionDialog = false;
    },
    updateIntentOptionsVisibility() {
      // 根据当前选择的LLM类型更新意图识别选项的可见性
      const currentLlmId = this.form.model.llmModelId;
      if (!currentLlmId || !this.modelOptions["Intent"]) return;

      const llmType = this.llmModeTypeMap.get(currentLlmId);
      if (!llmType) return;

      this.modelOptions["Intent"].forEach((item) => {
        if (item.value === "Intent_function_call") {
          // 如果llmType是openai或ollama，允许选择function_call
          // 否则隐藏function_call选项
          if (llmType === "openai" || llmType === "ollama") {
            item.isHidden = false;
          } else {
            item.isHidden = true;
          }
        } else {
          // 其他意图识别选项始终可见
          item.isHidden = false;
        }
      });

      // 如果当前选择的意图识别是function_call，但LLM类型不支持，则设置为可选的第一项
      if (
        this.form.model.intentModelId === "Intent_function_call" &&
        llmType !== "openai" &&
        llmType !== "ollama"
      ) {
        // 找到第一个可见的选项
        const firstVisibleOption = this.modelOptions["Intent"].find(
          (item) => !item.isHidden
        );
        if (firstVisibleOption) {
          this.form.model.intentModelId = firstVisibleOption.value;
        } else {
          // 如果没有可见选项，设置为Intent_nointent
          this.form.model.intentModelId = "Intent_nointent";
        }
      }
    },
    // 检查是否有音频预览
    hasAudioPreview(item) {
      // 检查是否为克隆音频
      // 使用后端实际返回的 isClone 字段
      const isCloneAudio = Boolean(item.isClone);
      
      // 检查是否有有效的音频URL，只使用后端实际返回的字段
      const hasValidAudioUrl = !!((item.voice_demo || item.voiceDemo)?.trim());
      
      // 克隆音频始终显示播放按钮，普通音频需要有有效URL才显示
      return isCloneAudio || hasValidAudioUrl;
    },

    // 播放/暂停音频切换
    toggleAudioPlayback(voiceId) {
      // 如果点击的是当前正在播放的音频，则切换暂停/播放状态
      if (this.playingVoice && this.currentPlayingVoiceId === voiceId) {
        if (this.isPaused) {
          // 从暂停状态恢复播放
          this.currentAudio.play().catch((error) => {
            console.error("恢复播放失败:", error);
            this.$message.warning(this.$t('roleConfig.cannotResumeAudio'));
          });
          this.isPaused = false;
        } else {
          // 暂停播放
          this.currentAudio.pause();
          this.isPaused = true;
        }
        return;
      }

      // 否则开始播放新的音频
      this.playVoicePreview(voiceId);
    },

    // 播放音色预览
    playVoicePreview(voiceId = null) {
      // 如果传入了voiceId，则使用传入的，否则使用当前选中的
      const targetVoiceId = voiceId || this.form.ttsVoiceId;

      if (!targetVoiceId) {
        this.$message.warning(this.$t('roleConfig.selectVoiceFirst'));
        return;
      }

      // 停止当前正在播放的音频
      if (this.currentAudio) {
        this.currentAudio.pause();
        this.currentAudio = null;
      }

      // 重置播放状态
      this.isPaused = false;
      this.currentPlayingVoiceId = targetVoiceId;

      try {
        // 从保存的音色详情中获取音频URL
        const voiceDetail = this.voiceDetails[targetVoiceId];

        // 添加调试信息
        console.log("当前选择的音色ID:", targetVoiceId);
        console.log("音色详情:", voiceDetail);

        // 尝试多种可能的音频属性名
        let audioUrl = null;
        let isCloneAudio = false;

        if (voiceDetail) {
          // 使用后端实际返回的 isClone 字段判断是否为克隆音频
          isCloneAudio = Boolean(voiceDetail.isClone);
          console.log(
            "克隆音频判断结果:",
            isCloneAudio,
            "训练状态:",
            voiceDetail.train_status
          );

          // 获取音频URL
          if (isCloneAudio && voiceDetail.id) {
            // 对于克隆音频，使用后端提供的正确接口
            // 注意：这里需要通过两步获取音频URL
            // 1. 首先获取音频下载ID
            // 2. 然后使用这个ID构建播放URL
            // 由于异步操作，我们需要先请求getAudioId
            console.log("检测到克隆音频，准备获取音频URL:", voiceDetail.id);

            // 创建一个Promise来处理异步获取音频URL的操作
            const getCloneAudioUrl = () => {
              return new Promise((resolve) => {
                // 首先调用getAudioId接口获取临时UUID
                RequestService.sendRequest()
                  .url(`${getServiceUrl()}/voiceClone/audio/${voiceDetail.id}`)
                  .method("POST")
                  .success((res) => {
                    if (res.data.code === 0 && res.data.data) {
                      // 处理返回的数据格式，在res.data基础上再套一层.data
                      const audioId = res.data.data;
                      console.log("获取到的音频ID:", audioId);
                      // 使用返回的UUID构建播放URL
                      const playUrl = `${getServiceUrl()}/voiceClone/play/${audioId}`;
                      console.log("构建克隆音频播放URL:", playUrl);
                      resolve(playUrl);
                    } else {
                      console.error("获取音频ID失败:", res.msg);
                      resolve(null);
                    }
                  })
                  .networkFail((err) => {
                    console.error("请求音频ID接口失败:", err);
                    resolve(null);
                  })
                  .send();
              });
            };

            // 设置播放状态
            this.playingVoice = true;
            // 创建Audio实例
            this.currentAudio = new Audio();
            // 设置音量
            this.currentAudio.volume = 1.0;

            // 设置超时，防止加载过长时间
            const timeoutId = setTimeout(() => {
              if (this.currentAudio && this.playingVoice) {
                this.$message.warning(this.$t('roleConfig.audioLoadTimeout'));
                this.playingVoice = false;
              }
            }, 10000); // 10秒超时

            // 监听播放错误
            this.currentAudio.onerror = () => {
              clearTimeout(timeoutId);
              console.error("克隆音频播放错误");
              this.$message.warning(this.$t('roleConfig.cloneAudioPlayFailed'));
              this.playingVoice = false;
            };

            // 监听播放开始，清除超时
            this.currentAudio.onplay = () => {
              clearTimeout(timeoutId);
            };

            // 监听播放结束
            this.currentAudio.onended = () => {
              this.playingVoice = false;
            };

            // 处理异步获取URL并播放
            getCloneAudioUrl().then((url) => {
              if (url) {
                // 设置音频URL并播放
                this.currentAudio.src = url;
                this.currentAudio.play().catch((error) => {
                  clearTimeout(timeoutId);
                  console.error("播放克隆音频失败:", error);
                  this.$message.warning(this.$t('roleConfig.cannotPlayCloneAudio'));
                  this.playingVoice = false;
                });
              } else {
                clearTimeout(timeoutId);
                this.$message.warning(this.$t('roleConfig.getCloneAudioFailed'));
                this.playingVoice = false;
              }
            });

            // 返回，避免继续执行下面的普通音频播放逻辑
            return;
          } else {
            // 对于普通音频，只使用后端实际返回的字段
            audioUrl =
              voiceDetail.voiceDemo ||
              voiceDetail.voice_demo;
          }

          // 如果没有找到，尝试检查是否有URL格式的字段
          if (!audioUrl) {
            for (const key in voiceDetail) {
              const value = voiceDetail[key];
              if (
                typeof value === "string" &&
                (value.startsWith("http://") ||
                  value.startsWith("https://") ||
                  value.endsWith(".mp3") ||
                  value.endsWith(".wav") ||
                  value.endsWith(".ogg"))
              ) {
                audioUrl = value;
                console.log(`发现可能的音频URL在字段 '${key}':`, audioUrl);
                break;
              }
            }
          }
        }

        if (!audioUrl) {
          // 如果没有音频URL，显示友好的提示
          this.$message.warning(this.$t('roleConfig.noPreviewAudio'));
          return;
        }

        // 非克隆音频的处理逻辑
        if (!isCloneAudio) {
          // 设置播放状态
          this.playingVoice = true;

          // 创建并播放音频
          this.currentAudio = new Audio();
          this.currentAudio.src = audioUrl;

          // 设置音量
          this.currentAudio.volume = 1.0;

          // 设置超时，防止加载过长时间
          const timeoutId = setTimeout(() => {
            if (this.currentAudio && this.playingVoice) {
              this.$message.warning(this.$t('roleConfig.audioLoadTimeout'));
              this.playingVoice = false;
            }
          }, 10000); // 10秒超时

          // 监听播放错误
          this.currentAudio.onerror = () => {
            clearTimeout(timeoutId);
            console.error("音频播放错误");
            this.$message.warning(this.$t('roleConfig.audioPlayFailed'));
            this.playingVoice = false;
          };

          // 监听播放开始，清除超时
          this.currentAudio.onplay = () => {
            clearTimeout(timeoutId);
          };

          // 监听播放结束
          this.currentAudio.onended = () => {
            this.playingVoice = false;
          };

          // 开始播放音频
          this.currentAudio.play().catch((error) => {
            clearTimeout(timeoutId);
            console.error("播放失败:", error);
            this.$message.warning(this.$t('roleConfig.cannotPlayAudio'));
            this.playingVoice = false;
          });
        }
      } catch (error) {
        console.error("播放音频过程出错:", error);
        this.$message.error(this.$t('roleConfig.audioPlayError'));
        this.playingVoice = false;
      }
    },
    updateChatHistoryConf() {
      if (this.form.model.memModelId === "Memory_nomem") {
        this.form.chatHistoryConf = 0;
      }
    },
    // 加载功能状态
    async loadFeatureStatus() {
      try {
        // 确保featureManager已初始化完成
        await featureManager.waitForInitialization();
        const config = featureManager.getConfig();
        this.featureStatus.voiceprintRecognition = config.voiceprintRecognition || false;
        this.featureStatus.vad = config.vad || false;
        this.featureStatus.asr = config.asr || false;
      } catch (error) {
        console.error("加载功能状态失败:", error);
      }
    },
    handleClose(id) {
      this.dynamicTags = this.dynamicTags.filter((item) => item.id !== id);
    },

    showInput() {
      this.inputVisible = true;
      this.$nextTick(_ => {
        this.$refs.saveTagInput.$refs.input.focus();
      });
    },

    handleInputConfirm() {
      let inputValue = this.inputValue;
      if (inputValue) {
        const tag = { id: `tmp-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`, tagName: inputValue };
        this.dynamicTags.push(tag);
      }
      this.inputVisible = false;
      this.inputValue = '';
    },
    getAgentTags(agentId) {
      Api.agent.getAgentTags(agentId, ({ data }) => {
        if (data.code === 0) {
          this.dynamicTags = data.data || [];
          this.originalTagNames = this.dynamicTags.map(tag => tag.tagName);
        }
      });
    },
    isSameStringList(left, right) {
      if (!Array.isArray(left) || !Array.isArray(right) || left.length !== right.length) {
        return false;
      }
      return left.every((value, index) => value === right[index]);
    },
    handleSaveAgentTags(agentId, tagNames = this.dynamicTags.map(tag => tag.tagName)) {
      return new Promise((resolve, reject) => {
        Api.agent.saveAgentTags(agentId, { tagNames }, ({ data }) => {
          if (data.code === 0) {
            this.originalTagNames = [...tagNames];
            resolve();
          } else {
            reject(data.msg);
          }
        });
      });
    }
  },
  watch: {
    "form.model.ttsModelId": {
      handler(newVal, oldVal) {
        if (oldVal && newVal !== oldVal) {
          this.form.ttsVoiceId = "";
          this.fetchVoiceOptions(newVal);
        } else {
          this.fetchVoiceOptions(newVal);
        }
      },
      immediate: true,
    },
    voiceOptions: {
      handler(newVal) {
        if (newVal && newVal.length > 0 && !this.form.ttsVoiceId) {
          this.form.ttsVoiceId = newVal[0].value;
        }
      },
      immediate: true,
    },
  },
  async mounted() {
    const agentId = this.$route.query.agentId;
    if (agentId) {
      this.fetchAgentConfig(agentId);
      this.getAgentTags(agentId);
      this.fetchAllFunctions();
      this.fetchCurrentVersion(agentId);
    }
    this.fetchModelOptions();
    this.fetchTemplates();
    // 加载功能状态，确保featureManager已初始化
    await this.loadFeatureStatus();
  },
};
</script>

<style lang="scss" scoped>
::v-deep .el-radio-group {
  .is-active {
    .el-radio-button__inner {
      &:hover {
        color: #fff !important;
      }
    }
  }
}
.welcome {
  min-width: 900px;
  min-height: calc(100vh - 48px);
  display: flex;
  position: relative;
  flex-direction: column;
  background: #eff4ff;
  background-size: cover;
  -webkit-background-size: cover;
  -o-background-size: cover;
  overflow: hidden;
}

.operation-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
}

.page-title {
  font-size: 24px;
  margin: 0;
  color: #2c3e50;
}

.main-wrapper {
  height: calc(100vh - 48px - 35px - 60px);
  margin: 0 22px;
  border-radius: 15px;
  position: relative;
  display: flex;
  flex-direction: column;
}

.content-panel {
  flex: 1;
  display: flex;
  overflow: hidden;
  height: 100%;
  border-radius: 15px;
  background: transparent;
  border: 1px solid #fff;
}

.content-area {
  flex: 1;
  height: 100%;
  min-width: 600px;
  overflow: auto;
  background-color: white;
  display: flex;
  flex-direction: column;
}

.config-card {
  background: white;
  border: none;
  box-shadow: none;
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow-y: auto;
}

.config-header {
  position: relative;
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 0 0 5px 0;
  font-weight: 700;
  font-size: 19px;
  color: #3d4566;
  justify-content: space-between;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 13px;
  flex-shrink: 0;
}

.header-tags {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
  min-width: 0;
  overflow-x: auto;
  padding-bottom: 4px;
  &::-webkit-scrollbar {
      height: 6px;
      background: rgba(38, 125, 255, .13);
    }
    &::-webkit-scrollbar-thumb {
      background: #267dff;
      border-radius: 8px;
    }
}

.header-tags .el-tag {
  flex-shrink: 0;
}

.current-version-tag {
  flex-shrink: 0;
  padding: 3px 9px;
  border: 1px solid #dfe7ff;
  border-radius: 999px;
  background: #f4f7ff;
  color: #267dff;
  font-size: 12px;
  font-weight: 500;
  line-height: 1.5;
}

.more-tag {
  cursor: pointer;
  flex-shrink: 0;
}

.all-tags-popover {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  padding: 8px;
}

.header-icon {
  width: 37px;
  height: 37px;
  background: #267dff;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.header-icon img {
  width: 19px;
  height: 19px;
}

.divider {
  height: 1px;
  background: #e8f0ff;
}

.form-content {
  padding: 2vh 0;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.form-column {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-input {
  width: 100%;
}

.form-select {
  flex: 1;
  width: 100%;
  height: 36px;
}

.play-button {
  color: #267dff;
  transition: color 0.3s;
}

.play-button:hover {
  color: #66b1ff;
}

.play-button.is-loading {
  color: #909399;
}

.form-textarea {
  width: 100%;
}

.voice-select-wrapper {
  display: flex;
  align-items: center;
  gap: 10px;
}

.template-container {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.template-item {
  height: 4vh;
  min-width: 60px;
  padding: 0 12px;
  border-radius: 8px;
  background: rgba(38, 125, 255, .13);
  line-height: 4vh;
  font-weight: 400;
  font-size: 11px;
  text-align: center;
  color: #267dff;
  cursor: pointer;
  transition: background-color 0.3s ease;
  white-space: nowrap;
}

.template-item:hover {
  background-color: #d0d8ff;
}

.model-select-wrapper {
  display: flex;
  align-items: center;
  width: 100%;
}

.model-row {
  display: flex;
  gap: 20px;
  margin-bottom: 6px;
}

.model-row .model-item {
  flex: 1;
  margin-bottom: 0;
}

.model-row .language-select-item {
  flex: 0 0 35%;
  max-width: 35%;
}

.model-row .language-select-item .language-select {
  width: 100%;
}

.model-row .el-form-item__label {
  font-size: 12px !important;
  color: #3d4566 !important;
  font-weight: 400;
  line-height: 22px;
  padding-bottom: 2px;
}

.function-icons {
  display: flex;
  align-items: center;
  margin-left: auto;
  padding-left: 10px;
}

.icon-dot {
  width: 25px;
  height: 25px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #267dff;
  font-weight: bold;
  font-size: 12px;
  margin-right: 8px;
  position: relative;
  background-color: #e6ebff;
}

::v-deep .el-form-item__label {
  font-size: 12px !important;
  color: #3d4566 !important;
  font-weight: 400;
  line-height: 22px;
  padding-bottom: 2px;
}

::v-deep .el-textarea .el-input__count {
  color: #909399;
  background: none;
  position: absolute;
  font-size: 12px;
  right: 3%;
}

.custom-close-btn {
  position: absolute;
  top: 25%;
  right: 0;
  transform: translateY(-50%);
  width: 35px;
  height: 35px;
  border-radius: 50%;
  border: 2px solid #cfcfcf;
  background: none;
  font-size: 30px;
  font-weight: lighter;
  color: #cfcfcf;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1;
  padding: 0;
  outline: none;
}

.custom-close-btn:hover {
  color: #267dff;
  border-color: #267dff;
}

.edit-function-btn {
  background: rgba(38, 125, 255, .13);
  color: #267dff;
  border: 1px solid rgba(83, 151, 255, .38);
  border-radius: 18px;
  padding: 10px 20px;
  transition: all 0.3s;
}

.edit-function-btn.active-btn {
  background: #267dff;
  color: white;
}

.chat-history-options {
  display: flex;
  gap: 10px;
  min-width: 250px;
  justify-content: flex-end;
}

.chat-history-options ::v-deep .el-radio-button {
  border-color: #267dff;
}

.chat-history-options ::v-deep .el-radio-button .el-radio-button__inner {
  color: #267dff;
  border-color: #267dff;
  background-color: transparent;
}

.chat-history-options ::v-deep .el-radio-button.is-active .el-radio-button__inner {
  background-color: #267dff;
  border-color: #267dff;
  color: white;
}

.chat-history-options ::v-deep .el-radio-button .el-radio-button__inner:hover {
  color: #267dff;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}

.header-actions .hint-text {
  display: flex;
  align-items: center;
  gap: 4px;
  color: #979db1;
  font-size: 12px;
  margin-right: 8px;
}

.header-actions .hint-text img {
  width: 16px;
  height: 16px;
}

.header-actions .save-btn {
  background: #267dff;
  color: white;
  border: none;
  border-radius: 18px;
  padding: 8px 16px;
  height: 32px;
  font-size: 14px;
}

.header-actions .history-btn {
  background: #ffffff;
  color: #4d5b7c;
  border: 1px solid #d8dce8;
  border-radius: 18px;
  padding: 8px 16px;
  height: 32px;
  font-size: 14px;
}

.header-actions .reset-btn {
  background: rgba(38, 125, 255, .13);
  color: #267dff;
  border: 1px solid rgba(83, 151, 255, .38);
  border-radius: 18px;
  padding: 8px 16px;
  height: 32px;
}

.header-actions .custom-close-btn {
  position: static;
  transform: none;
  width: 32px;
  height: 32px;
  margin-left: 8px;
}

.context-provider-item ::v-deep .el-form-item__label {
  line-height: 42px !important;
}

.doc-link {
  color: #267dff;
  text-decoration: none;
  margin-left: 4px;

  &:hover {
    text-decoration: underline;
  }
}

.role-intro-item {
  .prompt-guide-wrapper {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 6px;
    margin-top: -24px;
  }

  .prompt-guide-btn {
    color: #267dff;
    font-size: 13px;
    padding: 0;
    line-height: 1;
    font-weight: 500;

    &:hover {
      color: #409eff;
      text-decoration: underline;
    }
  }
}

.slider-wrapper {
  width: 100%;
  padding-right: 12px;
}

.slider-hint {
  display: block;
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
  line-height: 1.5;
}

.tts-slider {
  width: 100%;
}

.tts-slider ::v-deep .el-slider__input {
  width: 80px;
}

.tts-slider ::v-deep .el-input__inner {
  text-align: center;
  padding: 0 8px;
}
.voice-gender {
  margin-left: 6px;
  color: #8a94a6;
  font-size: 11px;
}
.custom-tag {
  background: rgba(38, 125, 255, .13);
  color: #267dff;
  border-radius: 8px;
  font-size: 12px;
  font-weight: normal;
  border: none;
}
.custom-tag-btn {
  background: rgba(38, 125, 255, .13);
  color: #267dff;
  border-radius: 8px;
  font-weight: normal;
  border: 1px solid #e6ebff;
  &:hover {
    background-color: #d0d8ff;
  }
}
.input-new-tag {
  width: 90px;
  &::v-deep(.el-input__inner) {
    width: 90px !important;
  }
}

</style>

<style>
.custom-tooltip {
  max-width: 400px !important;
  word-break: break-word;
}
</style>
