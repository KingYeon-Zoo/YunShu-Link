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
          <el-dropdown-item class="language-submenu">
            <span>{{ $t('user.language') }}</span>
            <el-dropdown trigger="hover" placement="left-start" @command="handleLangCommand">
              <span class="language-arrow"><i class="el-icon-arrow-right"></i></span>
              <el-dropdown-menu slot="dropdown">
                <el-dropdown-item command="zh_CN">{{ $t('language.zhCN') }}</el-dropdown-item>
                <el-dropdown-item command="zh_TW">{{ $t('language.zhTW') }}</el-dropdown-item>
                <el-dropdown-item command="en">{{ $t('language.en') }}</el-dropdown-item>
                <el-dropdown-item command="de">{{ $t('language.de') }}</el-dropdown-item>
                <el-dropdown-item command="vi">{{ $t('language.vi') }}</el-dropdown-item>
                <el-dropdown-item command="pt_BR">{{ $t('language.ptBR') }}</el-dropdown-item>
              </el-dropdown-menu>
            </el-dropdown>
          </el-dropdown-item>
          <el-dropdown-item divided command="password">{{ $t('user.changePassword') }}</el-dropdown-item>
          <el-dropdown-item command="logout">{{ $t('user.logout') }}</el-dropdown-item>
        </el-dropdown-menu>
      </el-dropdown>
    </div>
  </header>
</template>

<script>
import { mapState } from 'vuex';
import { changeLanguage } from '@/i18n';

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
        this.$store.dispatch('logout');
      } else if (cmd === 'password') {
        this.$emit('change-password');
      }
    },
    handleLangCommand(lang) {
      changeLanguage(lang);
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.breadcrumb-bar {
  position: fixed;
  top: 0;
  left: var(--sidebar-width, 220px);
  right: 0;
  height: 48px;
  background: rgba(4, 11, 23, .9);
  border-bottom: 1px solid $color-hairline-soft;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 26px;
  z-index: 9;
  backdrop-filter: blur(18px);
  box-shadow: 0 10px 34px rgba(0, 0, 0, .14);
  transition: left 300ms $ease-out-expo;

  &__crumb {
    font-size: 12px;

    ::v-deep .el-breadcrumb__inner { color: $color-steel; font-weight: 400; }
    ::v-deep .el-breadcrumb__item:last-child .el-breadcrumb__inner { color: $color-charcoal; }
    ::v-deep .el-breadcrumb__separator { color: #3e4d65; }
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
        background: rgba($color-primary, .1);
      }
    }

    .user-name {
      font-size: 14px;
      color: $color-ink-deep;
    }
  }
}

@media (max-width: 920px) {
  .breadcrumb-bar { left: 68px; }
}
</style>
