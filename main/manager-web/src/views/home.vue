<template>
  <div class="welcome">
    <DynamicBackground variant="management" />
    <!-- 公共头部 -->
    <HeaderBar :devices="devices" style="position: relative; z-index: 1;" />
    <el-main style="padding: 20px; position: relative; z-index: 1; display: flex; flex-direction: column;">
      <div>
        <!-- 首页内容 -->
        <div class="add-device">
          <div class="add-device-bg">
            <div class="hellow-text" style="padding-top: 30px;">
              {{ $t('home.greeting') }}
            </div>
            <div class="hellow-text">
              {{ $t('home.wish') }}
            </div>
            <div class="hi-hint">
              let's have a wonderful day!
            </div>
            <div class="add-device-options">
            <div class="search-container">
              <div class="search-wrapper">
                  <el-input
                    v-model="search"
                    :placeholder="$t('header.searchPlaceholder')"
                    class="custom-search-input"
                    @keyup.enter.native="handleSearch"
                    @clear="handleSearchReset"
                    clearable
                    ref="searchInput"
                    @focus="showSearchHistory"
                    @blur="hideSearchHistory"
                  >
                    <i slot="suffix" class="el-icon-search search-icon" @click="handleSearch"></i>
                  </el-input>
                  <!-- 搜索历史下拉框 -->
                  <div v-if="showHistory && searchHistory.length > 0" class="search-history-dropdown">
                    <div class="search-history-header">
                      <span>{{ $t("header.searchHistory") }}</span>
                      <el-button type="text" size="small" class="clear-history-btn" @click="clearSearchHistory">
                        {{ $t("header.clearHistory") }}
                      </el-button>
                    </div>
                    <div class="search-history-list">
                      <div v-for="(item, index) in searchHistory" :key="index" class="search-history-item"
                        @click.stop="selectSearchHistory(item)">
                        <span class="history-text">{{ item }}</span>
                        <i class="el-icon-close clear-item-icon" @click.stop="removeSearchHistory(index)"></i>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <el-button icon="el-icon-plus" type="primary" class="add-device-btn" @click="showAddDialog">{{ $t('home.addAgent') }}</el-button>
            </div>
          </div>
        </div>
        <div class="device-list-container">
          <template v-if="isLoading">
            <div v-for="i in skeletonCount" :key="'skeleton-' + i" class="skeleton-item">
              <div class="skeleton-image"></div>
              <div class="skeleton-content">
                <div class="skeleton-line"></div>
                <div class="skeleton-line-short"></div>
              </div>
            </div>
          </template>

          <template v-else>
            <DeviceItem v-for="(item, index) in devices" :key="index" :device="item" :feature-status="featureStatus" 
              @configure="goToRoleConfig" @deviceManage="handleDeviceManage" @delete="handleDeleteAgent" 
              @chat-history="handleShowChatHistory" />
          </template>
        </div>
      </div>
      <AddWisdomBodyDialog :visible.sync="addDeviceDialogVisible" @confirm="handleWisdomBodyAdded" />
    </el-main>
    <el-footer style="position: relative; z-index: 1;">
      <version-footer />
    </el-footer>
    <chat-history-dialog :visible.sync="showChatHistory" :agent-id="currentAgentId" :agent-name="currentAgentName" />
  </div>

</template>

<script>
import Api from '@/apis/api';
import { mapState } from "vuex";
import AddWisdomBodyDialog from '@/components/AddWisdomBodyDialog.vue';
import DynamicBackground from '@/components/DynamicBackground.vue';
import ChatHistoryDialog from '@/components/ChatHistoryDialog.vue';
import DeviceItem from '@/components/DeviceItem.vue';
import HeaderBar from '@/components/HeaderBar.vue';
import VersionFooter from '@/components/VersionFooter.vue';
import featureManager from '@/utils/featureManager';

export default {
  name: 'HomePage',
  components: { DeviceItem, AddWisdomBodyDialog, DynamicBackground, HeaderBar, VersionFooter, ChatHistoryDialog },
  data() {
    return {
      addDeviceDialogVisible: false,
      devices: [],
      originalDevices: [],
      isSearching: false,
      searchRegex: null,
      isLoading: true,
      skeletonCount: localStorage.getItem('skeletonCount') || 8,
      showChatHistory: false,
      currentAgentId: '',
      currentAgentName: '',
      // 功能状态
      featureStatus: {
        voiceprintRecognition: false,
        voiceClone: false,
        knowledgeBase: false
      },
      search: "",
      showHistory: false,
      searchHistory: [],
    }
  },

  computed: {
    ...mapState({
      userInfo: (state) => state.userInfo,
    }),
  },

  async mounted() {
    this.fetchAgentList();
    await this.loadFeatureStatus();
    // 从localStorage加载搜索历史
    this.loadSearchHistory();
  },

  methods: {
    // 加载功能状态
    async loadFeatureStatus() {
      await featureManager.waitForInitialization();
      const config = featureManager.getConfig();
      this.featureStatus = {
        voiceprintRecognition: config.voiceprintRecognition,
        voiceClone: config.voiceClone,
        knowledgeBase: config.knowledgeBase
      };
    },
    
    showAddDialog() {
      this.addDeviceDialogVisible = true
    },
    goToRoleConfig() {
      // 点击配置角色后跳转到角色配置页
      this.$router.push('/role-config')
    },
    handleWisdomBodyAdded(res) {
      this.fetchAgentList();
      this.addDeviceDialogVisible = false;
    },
    handleDeviceManage() {
      this.$router.push('/device-management');
    },
    handleSearchReset() {
      this.isSearching = false;
      // 直接将原始设备列表赋值给显示设备列表，避免重新加载数据
      this.devices = [...this.originalDevices];
    },

    // 搜索更新智能体列表
    handleSearchResult(filteredList) {
      this.devices = filteredList; // 更新设备列表
    },
    // 获取智能体列表
    fetchAgentList() {
      this.isLoading = true;
      Api.agent.getAgentList(({ data }) => {
        if (data?.data) {
          this.originalDevices = data.data.map(item => ({
            ...item,
            agentId: item.id
          }));

          // 动态设置骨架屏数量（可选）
          this.skeletonCount = Math.min(
            Math.max(this.originalDevices.length, 3), // 最少3个
            10 // 最多10个
          );

          this.handleSearchReset();
        }
        this.isLoading = false;
      }, (error) => {
        console.error('Failed to fetch agent list:', error);
        this.isLoading = false;
      });
    },
    // 删除智能体
    handleDeleteAgent(agentId) {
      this.$confirm(this.$t('home.confirmDeleteAgent'), '提示', {
        confirmButtonText: this.$t('button.ok'),
        cancelButtonText: this.$t('button.cancel'),
        type: 'warning'
      }).then(() => {
        Api.agent.deleteAgent(agentId, (res) => {
          if (res.data.code === 0) {
            this.$message.success({
              message: this.$t('home.deleteSuccess'),
              showClose: true
            });
            this.fetchAgentList(); // 刷新列表
          } else {
            this.$message.error({
              message: res.data.msg || this.$t('home.deleteFailed'),
              showClose: true
            });
          }
        });
      }).catch(() => { });
    },
    handleShowChatHistory({ agentId, agentName }) {
      this.currentAgentId = agentId;
      this.currentAgentName = agentName;
      this.showChatHistory = true;
    },
    // 处理搜索
    handleSearch() {
      const searchValue = this.search.trim();

      // 如果搜索内容为空，触发重置事件
      if (!searchValue) {
        this.handleSearchReset();
        return;
      }

      // 保存搜索历史
      this.saveSearchHistory(searchValue);

      // 搜索完成后让输入框失去焦点，从而触发blur事件隐藏搜索历史
      if (this.$refs.searchInput) {
        this.$refs.searchInput.blur();
      }

      this.isSearching = true;
      this.isLoading = true;
      // 检测MAC地址格式：包含4个冒号
      const isMac = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(searchValue)
      const searchType = isMac ? 'mac' : 'name';
      Api.agent.searchAgent(searchValue, searchType, ({ data }) => {
        if (data?.data) {
          this.devices = data.data.map(item => ({
            ...item,
            agentId: item.id
          }));
        }
        this.isLoading = false;
      }, (error) => {
        console.error('搜索智能体失败:', error);
        this.isLoading = false;
        this.$message.error(this.$t('message.searchFailed'));
      });
    },

    // 显示搜索历史
    showSearchHistory() {
      this.showHistory = true;
    },

    // 隐藏搜索历史
    hideSearchHistory() {
      // 延迟隐藏，以便点击事件能够执行
      setTimeout(() => {
        this.showHistory = false;
      }, 200);
    },

    // 加载搜索历史
    loadSearchHistory() {
      try {
        const history = localStorage.getItem(this.SEARCH_HISTORY_KEY);
        if (history) {
          this.searchHistory = JSON.parse(history);
        }
      } catch (error) {
        console.error("加载搜索历史失败:", error);
        this.searchHistory = [];
      }
    },

    // 保存搜索历史
    saveSearchHistory(keyword) {
      if (!keyword || this.searchHistory.includes(keyword)) {
        return;
      }

      // 添加到历史记录开头
      this.searchHistory.unshift(keyword);

      // 限制历史记录数量
      if (this.searchHistory.length > this.MAX_HISTORY_COUNT) {
        this.searchHistory = this.searchHistory.slice(0, this.MAX_HISTORY_COUNT);
      }

      // 保存到localStorage
      try {
        localStorage.setItem(this.SEARCH_HISTORY_KEY, JSON.stringify(this.searchHistory));
      } catch (error) {
        console.error("保存搜索历史失败:", error);
      }
    },

    // 选择搜索历史项
    selectSearchHistory(keyword) {
      this.search = keyword;
      this.handleSearch();
    },

    // 移除单个搜索历史项
    removeSearchHistory(index) {
      this.searchHistory.splice(index, 1);
      try {
        localStorage.setItem(this.SEARCH_HISTORY_KEY, JSON.stringify(this.searchHistory));
      } catch (error) {
        console.error("更新搜索历史失败:", error);
      }
    },

    // 清空所有搜索历史
    clearSearchHistory() {
      this.searchHistory = [];
      try {
        localStorage.removeItem(this.SEARCH_HISTORY_KEY);
      } catch (error) {
        console.error("清空搜索历史失败:", error);
      }
    },
  }
}
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.welcome {
  min-width: 900px;
  min-height: 506px;
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: transparent;
}

.add-device {
  height: auto;
  border-radius: $rounded-xxxl;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  padding: $spacing-section;
}

.add-device-bg {
  width: 100%;
  height: 100%;
  text-align: left;
  background: transparent;
  box-sizing: border-box;

  .hellow-text {
    margin-left: 0;
    font: $font-heading-lg;
    color: $color-ink-deep;
  }

  .hi-hint {
    font: $font-body-sm;
    color: $color-steel;
    margin-left: 0;
    margin-top: $spacing-xs;
  }
}

.add-device-options {
  display: flex;
  margin-top: $spacing-lg;
  margin-left: 0;
  align-items: center;
}

.add-device-btn {
  margin-left: $spacing-sm;
}

.search-container {
  width: 360px;
}

.search-wrapper {
  position: relative;
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

  &::v-deep .el-input__suffix {
    right: 10px;
  }

  &::v-deep .el-input__suffix-inner {
    display: flex;
    align-items: center;
    height: 100%;
    cursor: pointer;
  }

  .search-icon {
    font-size: 14px;
  }
}

.search-history-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: $color-canvas;
  border: 1px solid $color-hairline-soft;
  border-radius: $rounded-xl;
  box-shadow: $shadow-dialog;
  z-index: 1000;
  margin-top: 6px;
}

.search-history-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: $spacing-xs $spacing-md;
  border-bottom: 1px solid $color-hairline-soft;
  font: $font-caption;
  color: $color-steel;
}

.clear-history-btn {
  color: $color-steel;
  font: $font-caption;
  padding: 0;
  height: auto;

  &:hover {
    color: $color-charcoal;
  }
}

.search-history-list {
  max-height: 200px;
  overflow-y: auto;
}

.search-history-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: $spacing-xs $spacing-md;
  cursor: pointer;
  font: $font-caption;
  color: $color-charcoal;

  &:hover {
    background-color: $color-surface-soft;

    .clear-item-icon {
      visibility: visible;
    }
  }
}

.clear-item-icon {
  font-size: 10px;
  color: $color-steel;
  visibility: hidden;

  &:hover {
    color: $color-critical;
  }
}

.device-list-container {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
  gap: $spacing-xl;
  padding: $spacing-xl 0;
}

.footer {
  font: $font-caption;
  margin-top: auto;
  padding-top: $spacing-section-sm;
  color: $color-stone;
  text-align: center;
}

/* 骨架屏 */
@keyframes shimmer {
  100% {
    transform: translateX(100%);
  }
}

.skeleton-item {
  background: $color-glass-bg;
  border: 1px solid $color-glass-border;
  border-radius: $rounded-xl;
  padding: $spacing-xl;
  height: 120px;
  position: relative;
  overflow: hidden;
  margin-bottom: $spacing-xl;
}

.skeleton-image {
  width: 80px;
  height: 80px;
  background: $color-surface-soft;
  border-radius: $rounded-md;
  float: left;
  position: relative;
  overflow: hidden;
}

.skeleton-content {
  margin-left: 100px;
}

.skeleton-line {
  height: 16px;
  background: $color-surface-soft;
  border-radius: $rounded-md;
  margin-bottom: $spacing-md;
  width: 70%;
  position: relative;
  overflow: hidden;
}

.skeleton-line-short {
  height: 12px;
  background: $color-surface-soft;
  border-radius: $rounded-md;
  width: 50%;
}

.skeleton-item::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 50%;
  height: 100%;
  background: linear-gradient(90deg,
      rgba(255, 255, 255, 0),
      rgba(255, 255, 255, 0.3),
      rgba(255, 255, 255, 0));
  animation: shimmer 1.5s infinite;
}

@media (prefers-reduced-motion: reduce) {
  .skeleton-item::after {
    animation: none;
  }
}
</style>
