<template>
  <section class="welcome-banner fade-in-up">
    <div class="welcome-banner__content">
      <h2 class="welcome-banner__greeting">{{ greeting }}</h2>
      <p class="welcome-banner__summary">{{ summary }}</p>
    </div>
    <div class="welcome-banner__signal" aria-hidden="true">
      <svg viewBox="0 0 760 90" preserveAspectRatio="none">
        <path d="M0 54 C90 54 108 23 182 34 S280 76 350 50 448 14 530 40 630 72 760 27" />
        <path d="M0 61 C104 57 134 42 212 48 S320 68 398 54 490 37 568 49 665 63 760 43" />
      </svg>
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
  height: 108px;
  border-radius: 12px;
  border: 1px solid $color-hairline-soft;
  background: linear-gradient(112deg, rgba(8, 21, 41, .92), rgba(8, 18, 34, .58));
  color: $color-on-primary;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 22px;
  overflow: hidden;
  margin-bottom: $spacing-xl;

  &__content {
    position: relative;
    z-index: 1;
  }

  &__greeting {
    font: 600 26px/1.2 $font-family-base;
    margin: 0 0 8px;
  }

  &__summary {
    font: $font-body-sm;
    color: $color-steel;
    margin: 0;
  }

  &__signal {
    position: absolute;
    inset: 0;
    pointer-events: none;
    left: 42%;
    opacity: .7;

    svg { width: 100%; height: 100%; }
    path {
      fill: none;
      stroke: #27bfff;
      stroke-width: 1;
      filter: drop-shadow(0 0 6px rgba(33, 187, 255, .8));
      stroke-dasharray: 12 7;
      animation: signal-flow 12s linear infinite;
      &:last-child { stroke: #604cff; opacity: .58; animation-direction: reverse; }
    }
  }
}

@keyframes signal-flow { to { stroke-dashoffset: -190; } }

@media (prefers-reduced-motion: reduce) {
  .welcome-banner,
  .welcome-banner__signal path {
    animation: none;
  }
}
</style>
