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
  border-radius: $rounded-full;

  &--default {
    width: fit-content;
    background: $color-primary;
    color: $color-on-primary;
    border: none;
    transition: all 0.2s $ease-out-expo;

    &:hover,
    &:focus {
      background: lighten($color-primary, 6%);
      color: $color-on-primary;
      border-color: transparent;
      box-shadow: 0 2px 8px rgba($color-primary, 0.2);
      transform: translateY(-2px);
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-text;
      color: $color-canvas;
      border-color: transparent;
      box-shadow: none;
      transform: none;
      cursor: not-allowed;
    }
  }

  &--confirm {
    width: fit-content;
    background: $color-primary;
    color: $color-on-primary;
    border: none;
    transition: all 0.2s $ease-out-expo;

    &:hover,
    &:focus {
      background: lighten($color-primary, 6%);
      color: $color-on-primary;
      border-color: transparent;
      box-shadow: 0 2px 8px rgba($color-primary, 0.3);
      transform: translateY(-2px);
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-text;
      color: rgba($color-canvas, 0.8);
      border-color: transparent;
      box-shadow: none;
      transform: none;
      cursor: not-allowed;
    }
  }

  &--delete {
    width: fit-content;
    background: $color-critical;
    color: $color-on-primary;
    border: none;
    transition: all 0.2s $ease-out-expo;

    &:hover,
    &:focus {
      background: lighten($color-critical, 6%);
      color: $color-on-primary;
      border-color: transparent;
      box-shadow: 0 2px 8px rgba($color-critical, 0.3);
      transform: translateY(-2px);
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-text;
      color: rgba($color-canvas, 0.8);
      border-color: transparent;
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
      transform: translateY(-2px);
    }

    &.is-disabled,
    &.is-disabled:hover {
      background: $color-disabled-text;
      color: rgba($color-canvas, 0.8);
      border-color: transparent;
      box-shadow: none;
      transform: none;
      cursor: not-allowed;
    }
  }
}
</style>
