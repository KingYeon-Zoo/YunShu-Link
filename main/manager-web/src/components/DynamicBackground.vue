<template>
  <div class="dynamic-background" :class="`dynamic-background--${variant}`" aria-hidden="true">
    <div class="blob blob-1"></div>
    <div class="blob blob-2"></div>
    <div class="blob blob-3"></div>
    <div v-if="variant === 'login'" class="blob blob-4"></div>
    <Particles
      v-if="motionProfile.enabled"
      :class="`particles--${variant}`"
      :particle-count="motionProfile.particleCount"
      :particle-spread="motionProfile.particleSpread"
      :speed="motionProfile.speed"
      :particle-base-size="motionProfile.particleBaseSize"
      :size-randomness="motionProfile.sizeRandomness"
      :move-particles-on-hover="motionProfile.moveParticlesOnHover"
      :particle-hover-factor="motionProfile.particleHoverFactor"
      :alpha-particles="motionProfile.alphaParticles"
      :camera-distance="motionProfile.cameraDistance"
      :particle-colors="particleColors"
    />
    <FlowingParticles
      v-if="motionProfile.enabled"
      class="dynamic-background__flow"
      :count="variant === 'login' ? 360 : 500"
      :speed="variant === 'login' ? 0.045 : 0.055"
      :point-size="variant === 'login' ? 25 : 30"
    />
  </div>
</template>

<script>
import Particles from './Particles.vue';
import FlowingParticles from './FlowingParticles.vue';
const { getMotionProfile } = require('@/utils/motionProfile');

export default {
  name: 'DynamicBackground',
  components: {
    Particles,
    FlowingParticles
  },
  props: {
    variant: {
      type: String,
      default: 'management',
      validator: value => ['login', 'management'].includes(value)
    }
  },
  computed: {
    motionProfile() {
      return getMotionProfile(this.variant, false);
    },
    particleColors() {
      return this.variant === 'login'
        ? ['#23cfff', '#356cff', '#8a4dff', '#d9f8ff']
        : ['#1fa9ff', '#496dff', '#7447ff', '#5de0ff'];
    }
  }
};
</script>

<style lang="scss" scoped>
.dynamic-background {
  position: fixed;
  inset: 0;
  z-index: 0;
  overflow: hidden;
  background: #030812;

  &::before,
  &::after {
    content: '';
    position: absolute;
    inset: 0;
    pointer-events: none;
  }

  &::before {
    z-index: 1;
    background-image:
      linear-gradient(rgba(63, 122, 219, .035) 1px, transparent 1px),
      linear-gradient(90deg, rgba(63, 122, 219, .035) 1px, transparent 1px);
    background-size: 54px 54px;
    mask-image: radial-gradient(ellipse at 50% 50%, #000 12%, transparent 72%);
  }

  &::after {
    z-index: 2;
    background: radial-gradient(ellipse at center, transparent 42%, rgba(0, 3, 10, .72) 100%);
  }

  .blob {
    position: absolute;
    border-radius: 50%;
    filter: blur(110px);
    will-change: transform;
  }
}

.particles--login {
  z-index: 2;
  opacity: .66;
}

.particles--management {
  z-index: 2;
  opacity: .28;
}

.dynamic-background__flow {
  z-index: 2;
}

.dynamic-background--login {
  background:
    radial-gradient(circle at 19% 47%, rgba(17, 71, 166, .25), transparent 32%),
    radial-gradient(circle at 76% 24%, rgba(90, 40, 183, .12), transparent 27%),
    linear-gradient(132deg, #020711 0%, #050c1b 50%, #02060f 100%);

  .blob-1 {
    width: 44vw; height: 44vw;
    background: rgba(0, 124, 255, .17);
    top: 14%; left: -18%;
    animation: blob-float 19s ease-in-out infinite;
  }

  .blob-2 {
    width: 35vw; height: 35vw;
    background: rgba(95, 36, 255, .13);
    bottom: -20%; right: -8%;
    animation: blob-float 24s ease-in-out -7s infinite;
  }

  .blob-3 {
    width: 28vw; height: 28vw;
    background: rgba(0, 191, 255, .09);
    top: -14%; left: 42%;
    animation: blob-float 17s ease-in-out -3s infinite reverse;
  }

  .blob-4 {
    width: 24vw; height: 24vw;
    background: rgba(120, 48, 255, .1);
    top: 36%; left: 44%;
    animation: blob-float 21s ease-in-out -10s infinite;
  }
}

.dynamic-background--management {
  background:
    radial-gradient(circle at 72% 6%, rgba(12, 94, 192, .12), transparent 31%),
    linear-gradient(145deg, #030812 0%, #06101f 52%, #020711 100%);

  .blob-1 {
    width: 42vw; height: 42vw;
    background: rgba(0, 125, 255, .08);
    top: -20%; right: -12%;
    animation: blob-float 22s ease-in-out infinite;
  }

  .blob-2 {
    width: 32vw; height: 32vw;
    background: rgba(84, 48, 255, .075);
    bottom: -16%; left: 25%;
    animation: blob-float 26s ease-in-out -8s infinite;
  }

  .blob-3 {
    width: 28vw; height: 28vw;
    background: rgba(0, 207, 255, .055);
    top: 45%; left: 68%;
    animation: blob-float 20s ease-in-out -4s infinite reverse;
  }
}

@keyframes blob-float {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(45px, -36px) scale(1.08); }
  66% { transform: translate(-34px, 30px) scale(.95); }
}

@media (prefers-reduced-motion: reduce) {
  .dynamic-background .blob {
    animation: none;
    will-change: auto;
  }

  .particles--login,
  .particles--management {
    display: none;
  }
}
</style>
