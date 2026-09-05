<template>
  <div class="surface-card stat-card fade-in-up" :class="`stagger-${index}`">
    <div class="stat-card__icon">
      <i :class="icon"></i>
    </div>
    <div class="stat-card__body">
      <div class="stat-card__label">{{ label }}</div>
      <div class="stat-card__value">{{ value }}</div>
    </div>
    <svg class="stat-card__spark" viewBox="0 0 112 36" preserveAspectRatio="none" aria-hidden="true">
      <defs>
        <linearGradient :id="`spark-${index}`" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stop-color="currentColor" stop-opacity=".32" />
          <stop offset="1" stop-color="currentColor" stop-opacity="0" />
        </linearGradient>
      </defs>
      <path class="stat-card__area" d="M0 29 C16 27 18 11 34 15 S52 31 67 21 86 7 112 14 V36 H0 Z" :fill="`url(#spark-${index})`" />
      <path d="M0 29 C16 27 18 11 34 15 S52 31 67 21 86 7 112 14" />
    </svg>
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
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 118px;
  padding: 18px;
  overflow: hidden;
  border: 1px solid $color-hairline-soft;
  background: linear-gradient(145deg, rgba(10, 23, 43, .92), rgba(6, 15, 29, .76));
  box-shadow: 0 16px 38px rgba(0, 0, 0, .2);

  &__icon {
    width: 40px;
    height: 40px;
    align-self: flex-start;
    width: 34px;
    height: 34px;
    border-radius: 8px;
    background: rgba($color-primary, .12);
    color: #48bfff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 17px;
    box-shadow: inset 0 0 0 1px rgba(71, 170, 255, .16);
  }

  &__value {
    margin-top: 9px;
    font-size: 28px;
    font-weight: 650;
    color: $color-ink-deep;
    line-height: 1.2;
  }

  &__label {
    font-size: 12px;
    color: $color-steel;
  }

  &__spark {
    position: absolute;
    right: 10px;
    bottom: 12px;
    width: 47%;
    height: 34px;
    color: #397dff;
    opacity: .85;

    path:not(.stat-card__area) { fill: none; stroke: currentColor; stroke-width: 1.4; filter: drop-shadow(0 0 4px currentColor); }
  }

  &:nth-child(2) .stat-card__spark { color: #15c8ff; }
  &:nth-child(3) .stat-card__spark { color: #21d39b; }
  &:nth-child(4) .stat-card__spark { color: #824dff; }
}
</style>
