<template>
  <div class="empty-agent-state">
    <div class="empty-agent-state__illustration">
      <i class="el-icon-box"></i>
    </div>
    <p class="empty-agent-state__tip">{{ $t('home.emptyAgentTip') }}</p>
    <button class="empty-agent-state__btn" @click="$emit('add')">
      <i class="el-icon-plus"></i> {{ $t('home.addAgent') }}
    </button>
  </div>
</template>

<script>
export default {
  name: 'EmptyAgentState'
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.empty-agent-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: $spacing-xxl;
  color: $color-steel;

  &__illustration {
    width: 120px;
    height: 120px;
    border-radius: $rounded-circle;
    background: $color-surface-soft;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 48px;
    color: $color-stone;
    margin-bottom: $spacing-lg;
  }

  &__tip {
    font-size: 16px;
    margin: 0 0 $spacing-lg;
  }

  &__btn {
    height: 44px;
    padding: 0 $spacing-xl;
    border-radius: $rounded-full;
    background: $color-ink-button;
    color: $color-on-primary;
    border: none;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font: $font-body-sm-bold;
    transition: transform 150ms ease, box-shadow 150ms ease;

    &:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }
  }
}
</style>
