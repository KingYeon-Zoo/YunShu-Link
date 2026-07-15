<template>
  <div class="main-layout">
    <DynamicBackground variant="management" aria-hidden="true" />
    <SidebarNav />
    <BreadcrumbBar @change-password="showChangePasswordDialog = true" />
    <main class="main-layout__content">
      <router-view />
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
      showChangePasswordDialog: false
    };
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.main-layout {
  min-height: 100vh;
  position: relative;

  &__content {
    position: relative;
    z-index: 1;
    margin-left: 56px;
    margin-top: 48px;
    min-height: calc(100vh - 48px);
    padding: $spacing-xl;
    overflow-y: auto;
    text-align: left;
  }
}
</style>
