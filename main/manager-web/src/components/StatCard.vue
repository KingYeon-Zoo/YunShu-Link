<template>
  <div class="surface-card stat-card fade-in-up" :class="`stagger-${index}`">
    <div class="stat-card__icon">
      <i :class="icon"></i>
    </div>
    <div class="stat-card__body">
      <div class="stat-card__value">{{ value }}</div>
      <div class="stat-card__label">{{ label }}</div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'StatCard',
  props: {
    icon: { type: String, required: true },
    value: { type: [String, Number], required: true },
    label: { type: String, required: true },
    index: { type: Number, default: 1 }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.stat-card {
  display: flex;
  align-items: center;
  gap: $spacing-md;
  padding: $spacing-lg $spacing-xl;

  &__icon {
    width: 40px;
    height: 40px;
    border-radius: $rounded-lg;
    background: $color-surface-soft;
    color: $color-primary;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
  }

  &__value {
    font-size: 24px;
    font-weight: 700;
    color: $color-ink-deep;
    line-height: 1.2;
  }

  &__label {
    font-size: 14px;
    color: $color-steel;
  }
}
</style>
