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
        <div class="agent-section__tools">
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
          <div v-if="showHistory && searchHistory.length > 0" class="search-history-dropdown">
            <div class="search-history-header">
              <span>{{ $t('header.searchHistory') }}</span>
              <el-button type="text" size="small" class="clear-history-btn" @click="clearSearchHistory">
                {{ $t('header.clearHistory') }}
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
          <button class="primary-btn" @click="showAddDialog">
            <i class="el-icon-plus"></i> {{ $t('home.addAgent') }}
          </button>
        </div>
      </div>

      <EmptyAgentState v-if="!isLoading && devices.length === 0" @add="showAddDialog" />

      <div v-else class="device-list-container">
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
          <DeviceItem
            v-for="(item, index) in devices"
            :key="index"
            :device="item"
            :feature-status="featureStatus"
            class="fade-in-up"
            :style="{ animationDelay: `${index * 60}ms` }"
            @configure="goToRoleConfig"
            @deviceManage="handleDeviceManage"
            @delete="handleDeleteAgent"
            @chat-history="handleShowChatHistory"
          />
        </template>
      </div>
    </section>

    <AddWisdomBodyDialog :visible.sync="addDeviceDialogVisible" @confirm="handleWisdomBodyAdded" />
    <chat-history-dialog :visible.sync="showChatHistory" :agent-id="currentAgentId" :agent-name="currentAgentName" />
  </div>
</template>

<script>
import Api from '@/apis/api';
import { mapState } from "vuex";
import AddWisdomBodyDialog from '@/components/AddWisdomBodyDialog.vue';
import ChatHistoryDialog from '@/components/ChatHistoryDialog.vue';
import DeviceItem from '@/components/DeviceItem.vue';
import EmptyAgentState from '@/components/EmptyAgentState.vue';
import StatCard from '@/components/StatCard.vue';
import WelcomeBanner from '@/components/WelcomeBanner.vue';
import featureManager from '@/utils/featureManager';

export default {
  name: 'HomePage',
  components: { DeviceItem, AddWisdomBodyDialog, ChatHistoryDialog, EmptyAgentState, StatCard, WelcomeBanner },
  data() {
    return {
      addDeviceDialogVisible: false,
      devices: [],
      originalDevices: [],
      isSearching: false,
      isLoading: true,
      skeletonCount: localStorage.getItem('skeletonCount') || 8,
      showChatHistory: false,
      currentAgentId: '',
      currentAgentName: '',
      featureStatus: {
        voiceprintRecognition: false,
        voiceClone: false,
        knowledgeBase: false
      },
      search: "",
      showHistory: false,
      searchHistory: [],
      SEARCH_HISTORY_KEY: 'home_agent_search_history',
      MAX_HISTORY_COUNT: 10
    }
  },

  computed: {
    ...mapState({
      userInfo: (state) => state.userInfo,
    }),
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
      const online = this.stats.find(s => s.key === 'online').value;
      const active = this.stats.find(s => s.key === 'agents').value;
      return this.$t('home.statusSummary', { online, active });
    }
  },

  async mounted() {
    this.fetchAgentList();
    await this.loadFeatureStatus();
    this.loadSearchHistory();
  },

  methods: {
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
      this.devices = [...this.originalDevices];
    },

    fetchAgentList() {
      this.isLoading = true;
      Api.agent.getAgentList(({ data }) => {
        if (data?.data) {
          this.originalDevices = data.data.map(item => ({
            ...item,
            agentId: item.id
          }));

          this.skeletonCount = Math.min(
            Math.max(this.originalDevices.length, 3),
            10
          );

          this.handleSearchReset();
        }
        this.isLoading = false;
      }, (error) => {
        console.error('Failed to fetch agent list:', error);
        this.$message.error(this.$t('message.loadFailed'));
        this.isLoading = false;
      });
    },

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
            this.fetchAgentList();
          } else {
            this.$message.error({
              message: res.data.msg || this.$t('home.deleteFailed'),
              showClose: true
            });
          }
        });
      }).catch(() => { });
    },

    handleShowChatHistory(payload, legacyAgentName) {
      const payloadIsObject = payload && typeof payload === 'object';
      const agentId = payloadIsObject ? payload.agentId : payload;
      const matchedAgent = this.devices.find(item =>
        item.agentId === agentId || item.id === agentId
      );

      this.currentAgentId = agentId || matchedAgent?.agentId || matchedAgent?.id || '';
      this.currentAgentName = (
        payloadIsObject ? payload.agentName : legacyAgentName
      ) || matchedAgent?.agentName || '';
      this.showChatHistory = true;
    },

    handleSearch() {
      const searchValue = this.search.trim();

      if (!searchValue) {
        this.handleSearchReset();
        return;
      }

      this.saveSearchHistory(searchValue);

      if (this.$refs.searchInput) {
        this.$refs.searchInput.blur();
      }

      this.isSearching = true;
      this.isLoading = true;
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

    showSearchHistory() {
      this.showHistory = true;
    },

    hideSearchHistory() {
      setTimeout(() => {
        this.showHistory = false;
      }, 200);
    },

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

    saveSearchHistory(keyword) {
      if (!keyword || this.searchHistory.includes(keyword)) {
        return;
      }

      this.searchHistory.unshift(keyword);

      if (this.searchHistory.length > this.MAX_HISTORY_COUNT) {
        this.searchHistory = this.searchHistory.slice(0, this.MAX_HISTORY_COUNT);
      }

      try {
        localStorage.setItem(this.SEARCH_HISTORY_KEY, JSON.stringify(this.searchHistory));
      } catch (error) {
        console.error("保存搜索历史失败:", error);
      }
    },

    selectSearchHistory(keyword) {
      this.search = keyword;
      this.handleSearch();
    },

    removeSearchHistory(index) {
      this.searchHistory.splice(index, 1);
      try {
        localStorage.setItem(this.SEARCH_HISTORY_KEY, JSON.stringify(this.searchHistory));
      } catch (error) {
        console.error("更新搜索历史失败:", error);
      }
    },

    clearSearchHistory() {
      this.searchHistory = [];
      try {
        localStorage.removeItem(this.SEARCH_HISTORY_KEY);
      } catch (error) {
        console.error("清空搜索历史失败:", error);
      }
    }
  }
}
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.home-page {
  max-width: 1460px;
  margin: 0 auto;
}

.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
  margin-bottom: 16px;

  @media (max-width: 1024px) {
    grid-template-columns: repeat(2, 1fr);
  }
}

.agent-section {
  padding: 18px;
  border: 1px solid $color-hairline-soft;
  border-radius: 12px;
  background: rgba(6, 15, 29, .74);
  box-shadow: 0 20px 54px rgba(0, 0, 0, .2);

  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 14px;

    h3 {
      font: 600 18px/1.3 $font-family-base;
      color: $color-ink-deep;
      margin: 0;
    }
  }

  &__tools { display: flex; align-items: center; gap: 10px; }
}

.search-bar {
  margin-bottom: $spacing-lg;

  .search-wrapper {
    position: relative;
    width: 360px;
  }
}

.custom-search-input {
  &::v-deep .el-input__inner {
    height: 38px;
    background: rgba(7, 17, 32, .88);
    border-radius: 7px;
    border: 1px solid $color-hairline-soft;
    padding-left: 16px;
    padding-right: 36px;
  }

  &::v-deep .el-input__suffix {
    right: 10px;
  }

  &::v-deep .el-input__suffix-inner {
    display: flex;
    align-items: center;
    height: 100%;
  }

  .search-icon {
    font-size: 14px;
    color: $color-steel;
    cursor: pointer;
  }
}

.search-history-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: rgba(7, 17, 32, .98);
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
  grid-template-columns: 1fr;
  gap: 8px;
  padding: 0;
}

.primary-btn {
  height: 40px;
  padding: 0 $spacing-lg;
  border-radius: 7px;
  background: linear-gradient(100deg, #267dff, #4f5cff 65%, #4f5cff);
  color: $color-on-primary;
  border: none;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font: $font-body-sm-bold;
  transition: transform 150ms ease, box-shadow 150ms ease;

  &:hover {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px rgba(33, 93, 255, .28);
  }
}

/* 骨架屏 */
@keyframes shimmer {
  100% {
    transform: translateX(100%);
  }
}

.skeleton-item {
  background: $color-canvas;
  border: 1px solid $color-hairline-soft;
  border-radius: $rounded-xl;
  padding: $spacing-xl;
  height: 120px;
  position: relative;
  overflow: hidden;
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

@media (max-width: 760px) {
  .stat-grid { grid-template-columns: 1fr 1fr; }
  .agent-section__header { align-items: flex-start; gap: 12px; }
  .agent-section__tools { width: 100%; flex-wrap: wrap; }
  .search-wrapper { width: 100%; }
}
</style>
