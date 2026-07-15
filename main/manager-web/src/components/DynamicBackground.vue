<template>
  <div class="dynamic-background" :class="`dynamic-background--${variant}`">
    <div class="blob blob-1"></div>
    <div class="blob blob-2"></div>
    <div class="blob blob-3"></div>
    <div v-if="variant === 'login'" class="blob blob-4"></div>
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
  background: linear-gradient(135deg, #e0e6fd, #cce7ff, #d3d3fe, #e0e6fd);
  background-size: 400% 400%;
  animation: aurora-flow 20s ease infinite;

  .blob {
    filter: blur(60px);
  }

  .blob-1 {
    width: 40vw;
    height: 40vw;
    min-width: 320px;
    min-height: 320px;
    background: rgba($color-primary, 0.42);
    top: -8%;
    left: -6%;
    animation: blob-float 18s ease-in-out infinite;
  }

  .blob-2 {
    width: 35vw;
    height: 35vw;
    min-width: 280px;
    min-height: 280px;
    background: rgba($color-primary-soft, 0.36);
    bottom: -10%;
    right: -5%;
    animation: blob-float 22s ease-in-out infinite;
    animation-delay: -6s;
  }

  .blob-3 {
    width: 30vw;
    height: 30vw;
    min-width: 240px;
    min-height: 240px;
    background: rgba($color-primary-deep, 0.3);
    top: 45%;
    left: 55%;
    animation: blob-float 15s ease-in-out infinite reverse;
    animation-delay: -3s;
  }

  .blob-4 {
    width: 32vw;
    height: 32vw;
    min-width: 260px;
    min-height: 260px;
    background: rgba($color-primary, 0.28);
    top: 10%;
    left: 30%;
    animation: blob-float 20s ease-in-out infinite;
    animation-delay: -10s;
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
    width: 45vw;
    height: 45vw;
    min-width: 360px;
    min-height: 360px;
    background: rgba($color-primary, 0.5);
    top: -10%;
    right: -8%;
    opacity: 0.08;
    animation: blob-float 20s ease-in-out infinite;
  }

  .blob-2 {
    width: 38vw;
    height: 38vw;
    min-width: 300px;
    min-height: 300px;
    background: rgba($color-primary-soft, 0.4);
    bottom: -8%;
    left: -6%;
    opacity: 0.06;
    animation: blob-float 24s ease-in-out infinite;
    animation-delay: -8s;
  }

  .blob-3 {
    width: 32vw;
    height: 32vw;
    min-width: 260px;
    min-height: 260px;
    background: rgba($color-primary, 0.35);
    top: 55%;
    left: 45%;
    opacity: 0.06;
    animation: blob-float 22s ease-in-out infinite reverse;
    animation-delay: -4s;
  }
}

@keyframes aurora-flow {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

@keyframes blob-float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(60px, -60px) scale(1.08); }
  66% { transform: translate(-40px, 40px) scale(0.96); }
}

@media (prefers-reduced-motion: reduce) {
  .dynamic-background,
  .dynamic-background .blob {
    animation: none;
  }
}
</style>
