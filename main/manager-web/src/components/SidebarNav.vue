<template>
  <aside class="sidebar-nav" :class="{ 'is-collapsed': collapsed }">
    <div class="sidebar-nav__logo" @click="goHome">
      <img v-if="activeLogoUrl" :src="activeLogoUrl" :alt="collapsed ? '云枢' : '云枢 YunShu Link'" />
      <i v-else class="el-icon-s-home"></i>
    </div>
    <button
      type="button"
      class="sidebar-nav__toggle"
      :aria-label="collapsed ? '展开导航栏' : '折叠导航栏'"
      :title="collapsed ? '展开导航栏' : '折叠导航栏'"
      @click="toggleSidebar"
    >
      <i :class="collapsed ? 'el-icon-arrow-right' : 'el-icon-arrow-left'"></i>
    </button>
    <nav v-if="initialized" class="sidebar-nav__menu">
      <el-tooltip
        v-for="item in visibleItems"
        :key="item.key"
        effect="dark"
        :content="$t(item.titleKey)"
        placement="right"
        :disabled="!collapsed"
      >
        <div
          :class="['sidebar-nav__item', { 'is-active': isActive(item) }]"
          @click="handleClick(item)"
        >
          <i :class="item.icon"></i>
          <span>{{ $t(item.titleKey) }}</span>
        </div>
      </el-tooltip>
    </nav>
    <div v-else class="sidebar-nav__loading">
      <i class="el-icon-loading"></i>
    </div>
  </aside>
</template>

<script>
import { mapState } from 'vuex';
import { navItems } from '@/config/nav.config';
import featureManager from '@/utils/featureManager';

export default {
  name: 'SidebarNav',
  props: {
    collapsed: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      initialized: false,
      featureStatus: {},
      items: navItems,
      logoUrl: null,
      compactLogoUrl: null
    };
  },
  computed: {
    ...mapState(['userInfo']),
    activeLogoUrl() {
      return this.collapsed ? this.compactLogoUrl : this.logoUrl;
    },
    visibleItems() {
      return this.items.filter(item => this.isVisible(item));
    }
  },
  async created() {
    try {
      this.logoUrl = require('@/assets/brand/yunshu-link-logo.png');
      this.compactLogoUrl = require('@/assets/brand/yunshu-link-icon.png');
    } catch (error) {
      this.logoUrl = null;
      this.compactLogoUrl = null;
    }

    // 基础导航无需等待远程功能配置，避免侧栏长期只显示加载图标。
    this.initialized = true;
    try {
      await featureManager.waitForInitialization();
      this.featureStatus = featureManager.getConfig();
    } catch (error) {
      console.warn('SidebarNav: featureManager initialization failed', error);
      this.featureStatus = {};
    }
  },
  methods: {
    toggleSidebar() {
      this.$emit('toggle', !this.collapsed);
    },
    isVisible(item) {
      if (item.requiresSuperAdmin && !this.userInfo?.superAdmin) return false;
      if (item.featureKey && !this.featureStatus?.[item.featureKey]) return false;
      return true;
    },
    isActive(item) {
      if (item.children && item.children.length) {
        return item.children.some(child => child.routeName === this.$route.name);
      }
      return item.routeName === this.$route.name;
    },
    handleClick(item) {
      if (item.children && item.children.length) {
        const firstRoute = item.children[0]?.routeName;
        if (firstRoute) {
          this.$router.push({ name: firstRoute });
        }
      } else if (item.routeName) {
        this.$router.push({ name: item.routeName });
      }
    },
    goHome() {
      this.$router.push({ name: 'home' });
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.sidebar-nav {
  position: fixed;
  top: 0;
  left: 0;
  width: var(--sidebar-width, 220px);
  height: 100vh;
  background: rgba(3, 9, 20, .94);
  border-right: 1px solid $color-hairline-soft;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  padding: 14px 10px 18px;
  z-index: 10;
  box-shadow: 18px 0 52px rgba(0, 0, 0, .16);
  backdrop-filter: blur(20px);
  transition: width 300ms $ease-out-expo;

  &__logo {
    width: 100%;
    height: 60px;
    margin: 0 auto 20px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: $color-steel;
    font-size: 20px;

    img {
      width: 172px;
      max-width: 88%;
      height: auto;
      object-fit: contain;
      filter: brightness(0) invert(1) drop-shadow(0 0 13px rgba(44, 153, 255, .24));
    }
  }

  &__toggle {
    position: absolute;
    top: 72px;
    right: -13px;
    z-index: 2;
    width: 26px;
    height: 26px;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    border: 1px solid rgba(77, 150, 255, .34);
    border-radius: 7px;
    background: linear-gradient(145deg, #10233f, #071325);
    color: #79cfff;
    font-size: 12px;
    cursor: pointer;
    box-shadow: 0 6px 18px rgba(0, 0, 0, .36), 0 0 16px rgba(35, 138, 255, .12);
    transition: color 180ms ease, border-color 180ms ease, transform 180ms ease;

    &:hover {
      color: #fff;
      border-color: #37bfff;
      transform: scale(1.07);
    }
  }

  &__menu {
    display: flex;
    flex-direction: column;
    gap: 6px;
    overflow-y: auto;
    overflow-x: hidden;
    scrollbar-width: thin;
    scrollbar-color: rgba($color-primary, .32) transparent;

    &::-webkit-scrollbar {
      width: 4px;
      height: 0;
    }

    &::-webkit-scrollbar-track {
      background: transparent;
    }

    &::-webkit-scrollbar-thumb {
      border-radius: 999px;
      background: rgba($color-primary, .32);
    }
  }

  &__loading {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    color: $color-steel;
    font-size: 20px;
  }

  &__item {
    position: relative;
    width: 100%;
    height: 42px;
    padding: 0 12px;
    border-radius: 7px;
    display: flex;
    align-items: center;
    justify-content: flex-start;
    gap: 11px;
    color: $color-steel;
    font-size: 15px;
    cursor: pointer;
    transition: background-color 180ms ease, color 180ms ease, transform 180ms ease, box-shadow 180ms ease;

    span { font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

    &:hover {
      color: #eaf3ff;
      background: rgba($color-primary, .1);
      transform: translateX(2px);
    }

    &.is-active {
      color: #f6fbff;
      background: linear-gradient(90deg, rgba(28, 112, 255, .38), rgba(54, 68, 178, .28));
      box-shadow: inset 2px 0 #31b7ff, 0 8px 22px rgba(31, 91, 218, .12);

      &::after {
        content: '';
        position: absolute;
        right: 10px;
        width: 4px;
        height: 4px;
        border-radius: 50%;
        background: #48dbff;
        box-shadow: 0 0 10px #37c9ff;
      }
    }
  }

  &.is-collapsed {
    padding-inline: 10px;

    .sidebar-nav__logo {
      width: 48px;
      height: 54px;

      img {
        width: 42px;
        max-width: none;
        height: 42px;
        object-fit: contain;
      }
    }

    .sidebar-nav__item {
      width: 46px;
      padding: 0;
      justify-content: center;

      span { display: none; }
    }
  }
}

@media (max-width: 920px) {
  .sidebar-nav {
    width: 68px;
    padding-inline: 10px;

    .sidebar-nav__logo { width: 48px; img { width: 42px; height: 42px; object-fit: contain; } }
    .sidebar-nav__item { width: 46px; justify-content: center; padding: 0; span { display: none; } }
    .sidebar-nav__toggle { display: none; }
  }
}
</style>
