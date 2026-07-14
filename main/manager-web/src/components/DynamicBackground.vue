<template>
  <div class="dynamic-background" :class="`dynamic-background--${variant}`">
    <div class="blob blob-1"></div>
    <div class="blob blob-2"></div>
    <div v-if="variant === 'login'" class="blob blob-3"></div>
  </div>
</template>

<script>
export default {
  name: 'DynamicBackground',
  props: {
    variant: {
      type: String,
      default: 'management',
      validator: value => ['login', 'management'].includes(value)
    }
  }
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.dynamic-background {
  position: fixed;
  inset: 0;
  z-index: 0;
  overflow: hidden;

  .blob {
    position: absolute;
    border-radius: 50%;
  }
}

.dynamic-background--login {
  background: linear-gradient(
    135deg,
    #e0e6fd 0%,
    #cce7ff 25%,
    #d3d3fe 50%,
    #e0e6fd 75%,
    #cce7ff 100%
  );
  background-size: 400% 400%;
  animation: aurora-flow 10s ease infinite;

  .blob {
    filter: blur(50px);
  }

  .blob-1 {
    width: 400px;
    height: 400px;
    background: rgba($color-primary, 0.35);
    top: -100px;
    left: -100px;
    animation: blob-float 12s ease-in-out infinite;
  }

  .blob-2 {
    width: 350px;
    height: 350px;
    background: rgba($color-primary-soft, 0.3);
    bottom: -80px;
    right: -80px;
    animation: blob-float 14s ease-in-out infinite;
    animation-delay: -4s;
  }

  .blob-3 {
    width: 300px;
    height: 300px;
    background: rgba($color-primary-deep, 0.2);
    top: 50%;
    left: 50%;
    animation: blob-float 16s ease-in-out infinite reverse;
  }
}

.dynamic-background--management {
  background: linear-gradient(
    135deg,
    $color-canvas 0%,
    $color-surface-soft 50%,
    $color-canvas 100%
  );
  background-size: 300% 300%;
  animation: aurora-flow 20s ease infinite;

  .blob {
    filter: blur(60px);
  }

  .blob-1 {
    width: 500px;
    height: 500px;
    background: rgba($color-primary, 0.5);
    top: -150px;
    right: -150px;
    opacity: 0.06;
    animation: blob-float 25s ease-in-out infinite;
  }

  .blob-2 {
    width: 400px;
    height: 400px;
    background: rgba($color-primary-soft, 0.4);
    bottom: -100px;
    left: -100px;
    opacity: 0.06;
    animation: blob-float 28s ease-in-out infinite;
    animation-delay: -8s;
  }
}

@keyframes aurora-flow {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

@keyframes blob-float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(60px, -60px) scale(1.1); }
  66% { transform: translate(-40px, 40px) scale(0.95); }
}

@media (prefers-reduced-motion: reduce) {
  .dynamic-background,
  .dynamic-background .blob {
    animation: none;
  }
}
</style>
