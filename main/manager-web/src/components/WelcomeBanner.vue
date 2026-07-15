<template>
  <section class="welcome-banner fade-in-up">
    <div class="welcome-banner__content">
      <h2 class="welcome-banner__greeting">{{ greeting }}</h2>
      <p class="welcome-banner__summary">{{ summary }}</p>
    </div>
    <div class="welcome-banner__blobs" aria-hidden="true">
      <div v-for="i in 3" :key="i" class="welcome-banner__blob"></div>
    </div>
  </section>
</template>

<script>
import { formatGreeting } from '@/utils/greeting';

export default {
  name: 'WelcomeBanner',
  props: {
    username: { type: String, default: 'Admin' },
    summary: { type: String, default: '' }
  },
  computed: {
    greeting() {
      return formatGreeting(this.$t.bind(this), this.username);
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.welcome-banner {
  position: relative;
  height: 180px;
  border-radius: $rounded-xxxl;
  background: linear-gradient(135deg, $color-primary-deep 0%, $color-primary-soft 100%);
  color: $color-on-primary;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 $spacing-xxl;
  overflow: hidden;
  margin-bottom: $spacing-xl;

  &__content {
    position: relative;
    z-index: 1;
  }

  &__greeting {
    font: $font-heading-lg;
    margin: 0 0 $spacing-sm;
  }

  &__summary {
    font: $font-body-md;
    opacity: 0.9;
    margin: 0;
  }

  &__blobs {
    position: absolute;
    inset: 0;
    pointer-events: none;
  }

  &__blob {
    position: absolute;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.25);
    filter: blur(40px);
    animation: banner-blob-float 14s ease-in-out infinite;

    &:nth-child(1) {
      width: 180px;
      height: 180px;
      top: -40px;
      right: 80px;
      animation-delay: -2s;
    }

    &:nth-child(2) {
      width: 140px;
      height: 140px;
      bottom: -30px;
      right: 200px;
      animation-delay: -5s;
    }

    &:nth-child(3) {
      width: 100px;
      height: 100px;
      top: 50%;
      right: 40px;
      animation-delay: -8s;
    }
  }
}

@keyframes banner-blob-float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(30px, -30px) scale(1.1); }
}

@media (prefers-reduced-motion: reduce) {
  .welcome-banner,
  .welcome-banner__blob {
    animation: none;
  }
}
</style>
