<template>
  <div
    class="main-layout"
    :class="{ 'main-layout--collapsed': sidebarCollapsed }"
    :style="{ '--sidebar-width': sidebarCollapsed ? '68px' : '220px' }"
  >
    <DynamicBackground variant="management" aria-hidden="true" />
    <SidebarNav :collapsed="sidebarCollapsed" @toggle="handleSidebarToggle" />
    <BreadcrumbBar @change-password="showChangePasswordDialog = true" />
    <main class="main-layout__content">
      <transition name="route-motion" mode="out-in">
        <router-view :key="$route.fullPath" />
      </transition>
    </main>
    <ChangePasswordDialog v-model="showChangePasswordDialog" />
  </div>
</template>

<script>
import DynamicBackground from '@/components/DynamicBackground.vue';
import SidebarNav from '@/components/SidebarNav.vue';
import BreadcrumbBar from '@/components/BreadcrumbBar.vue';
import ChangePasswordDialog from '@/components/ChangePasswordDialog.vue';

export default {
  name: 'MainLayout',
  components: {
    DynamicBackground,
    SidebarNav,
    BreadcrumbBar,
    ChangePasswordDialog
  },
  data() {
    return {
      showChangePasswordDialog: false,
      sidebarCollapsed: localStorage.getItem('managerSidebarCollapsed') === 'true'
    };
  },
  methods: {
    handleSidebarToggle(collapsed) {
      this.sidebarCollapsed = collapsed;
      localStorage.setItem('managerSidebarCollapsed', String(collapsed));
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.main-layout {
  min-height: 100vh;
  position: relative;
  background: #030812;

  &__content {
    position: relative;
    z-index: 1;
    margin-left: var(--sidebar-width, 220px);
    margin-top: 48px;
    min-height: calc(100vh - 48px);
    padding: 24px 28px 36px;
    overflow-y: auto;
    text-align: left;
    transition: margin-left 300ms $ease-out-expo;
  }
}

@media (max-width: 920px) {
  .main-layout { --sidebar-width: 68px !important; }
  .main-layout__content { padding: 20px; }
}

.route-motion-enter-active,
.route-motion-leave-active {
  transition:
    opacity 280ms $ease-out-expo,
    transform 340ms $ease-out-expo,
    filter 280ms ease;
}

.route-motion-enter {
  opacity: 0;
  transform: translateY(14px) scale(0.992);
  filter: blur(7px);
}

.route-motion-leave-to {
  opacity: 0;
  transform: translateY(-6px) scale(0.996);
  filter: blur(4px);
}

@media (prefers-reduced-motion: reduce) {
  .route-motion-enter-active,
  .route-motion-leave-active {
    transition: opacity 1ms linear;
  }

  .route-motion-enter,
  .route-motion-leave-to {
    transform: none;
    filter: none;
  }
}
</style>
