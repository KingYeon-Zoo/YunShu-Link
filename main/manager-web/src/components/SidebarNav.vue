<template>
  <aside class="sidebar-nav">
    <div class="sidebar-nav__logo" @click="goHome">
      <img v-if="logoUrl" :src="logoUrl" alt="logo" />
      <i v-else class="el-icon-s-home"></i>
    </div>
    <nav v-if="initialized" class="sidebar-nav__menu">
      <el-tooltip
        v-for="item in visibleItems"
        :key="item.key"
        effect="dark"
        :content="$t(item.titleKey)"
        placement="right"
      >
        <div
          :class="['sidebar-nav__item', { 'is-active': isActive(item) }]"
          @click="handleClick(item)"
        >
          <i :class="item.icon"></i>
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
  data() {
    return {
      initialized: false,
      featureStatus: {},
      items: navItems,
      logoUrl: null
    };
  },
  computed: {
    ...mapState(['userInfo']),
    visibleItems() {
      return this.items.filter(item => this.isVisible(item));
    }
  },
  async created() {
    try {
      this.logoUrl = require('@/assets/xiaozhi-logo.png');
    } catch (error) {
      this.logoUrl = null;
    }

    try {
      await featureManager.waitForInitialization();
      this.featureStatus = featureManager.getConfig();
    } catch (error) {
      console.warn('SidebarNav: featureManager initialization failed', error);
      this.featureStatus = {};
    } finally {
      this.initialized = true;
    }
  },
  methods: {
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
  width: 56px;
  height: 100vh;
  background: $color-canvas;
  border-right: 1px solid $color-hairline-soft;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: $spacing-md;
  z-index: 10;

  &__logo {
    width: 32px;
    height: 32px;
    border-radius: 8px;
    overflow: hidden;
    margin-bottom: $spacing-xl;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: $color-steel;
    font-size: 20px;

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__menu {
    display: flex;
    flex-direction: column;
    gap: 12px;
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
    width: 36px;
    height: 36px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: $color-steel;
    font-size: 18px;
    cursor: pointer;
    transition: background-color 150ms ease, color 150ms ease;

    &:hover {
      background: $color-surface-soft;
    }

    &.is-active {
      background: $color-primary;
      color: $color-on-primary;
    }
  }
}
</style>
