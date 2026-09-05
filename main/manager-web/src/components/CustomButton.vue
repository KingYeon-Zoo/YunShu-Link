<template>
  <el-button
    :class="['custom-button', `custom-button--${type}`]"
    v-bind="$attrs"
    @click="$emit('click', $event)"
  >
    <slot />
  </el-button>
</template>

<script>
export default {
  name: 'CustomButton',
  props: {
    type: {
      type: String,
      default: 'default',
      validator: (val) => ['default', 'confirm', 'delete', 'add'].includes(val)
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.custom-button {
  font: $font-body-sm-bold;
  border-radius: $rounded-lg;

  &--default {
    width: fit-content;
    background: linear-gradient(135deg, $color-primary, $color-primary-soft);
    color: $color-on-primary;
    border: none;
    transition: all 0.2s $ease-out-expo;

    &:hover,
    &:focus {
      background: linear-gradient(135deg, lighten($color-primary, 5%), lighten($color-primary-soft, 5%));
      color: $color-on-primary;
      border-color: transparent;
      box-shadow: 0 2px 8px rgba($color-primary, 0.2);
      transform: none;
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-bg;
      color: $color-disabled-text;
      border-color: transparent;
      box-shadow: none;
      transform: none;
      cursor: not-allowed;
    }
  }

  &--confirm {
    width: fit-content;
    background: linear-gradient(135deg, $color-primary, $color-primary-soft);
    color: $color-on-primary;
    border: none;
    transition: all 0.2s $ease-out-expo;

    &:hover,
    &:focus {
      background: linear-gradient(135deg, lighten($color-primary, 5%), lighten($color-primary-soft, 5%));
      color: $color-on-primary;
      border-color: transparent;
      box-shadow: 0 2px 8px rgba($color-primary, 0.3);
      transform: none;
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-bg;
      color: $color-disabled-text;
      border-color: transparent;
      box-shadow: none;
      transform: none;
      cursor: not-allowed;
    }
  }

  &--delete {
    width: fit-content;
    background: rgba($color-critical, .12);
    color: lighten($color-critical, 6%);
    border: 1px solid rgba($color-critical, .38);
    transition: all 0.2s $ease-out-expo;

    &:hover,
    &:focus {
      background: rgba($color-critical, .2);
      color: lighten($color-critical, 12%);
      border-color: rgba($color-critical, .58);
      box-shadow: 0 2px 8px rgba($color-critical, 0.3);
      transform: none;
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-bg;
      color: $color-disabled-text;
      border-color: rgba(100, 125, 165, .16);
      box-shadow: none;
      transform: none;
      cursor: not-allowed;
    }
  }

  &--add {
    width: fit-content;
    background: $color-success;
    color: $color-on-primary;
    border: none;
    transition: all 0.2s $ease-out-expo;

    &:hover,
    &:focus {
      background: lighten($color-success, 6%);
      color: $color-on-primary;
      border-color: transparent;
      box-shadow: 0 2px 8px rgba($color-success, 0.3);
      transform: none;
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-bg;
      color: $color-disabled-text;
      border-color: transparent;
      box-shadow: none;
      transform: none;
      cursor: not-allowed;
    }
  }
}
</style>
