<template>
  <div class="glass-card-container" :class="{ 'glass-card-container--hoverable': hoverable, [`glass-card-container--${size}`]: true }">
    <slot></slot>
  </div>
</template>

<script>
export default {
  name: 'GlassCard',
  props: {
    hoverable: {
      type: Boolean,
      default: true
    },
    size: {
      type: String,
      default: 'large', // 'large' | 'small'
      validator: value => ['large', 'small'].includes(value)
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.glass-card-container {
  position: relative;
  z-index: 1;
  background: $color-glass-bg;
  backdrop-filter: blur($glass-blur);
  -webkit-backdrop-filter: blur($glass-blur);
  border: 1px solid $color-glass-border;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  transition: background 0.2s ease, box-shadow 0.2s ease;

  &--large {
    border-radius: $rounded-xxxl;
    padding: $spacing-xxl;
  }

  &--small {
    border-radius: $rounded-xl;
    padding: $spacing-xl;
  }

  &--hoverable:hover {
    background: $color-glass-bg-hover;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
  }
}

@supports not (backdrop-filter: blur($glass-blur)) {
  .glass-card-container {
    background: $color-canvas;
  }
}
</style>
