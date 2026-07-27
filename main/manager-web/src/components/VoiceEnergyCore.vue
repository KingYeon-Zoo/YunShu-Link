<template>
  <div class="voice-energy-core" @mousemove="handlePointer" @mouseleave="resetPointer">
    <canvas ref="canvas" class="voice-energy-core__canvas" aria-hidden="true"></canvas>
    <div class="voice-energy-core__halo" aria-hidden="true"></div>
    <div class="voice-energy-core__wave" aria-hidden="true">
      <span v-for="index in 27" :key="index" :style="{ '--bar': index }"></span>
    </div>
  </div>
</template>

<script>
export default {
  name: 'VoiceEnergyCore',
  data() {
    return {
      frame: 0,
      resizeObserver: null,
      pointerX: 0,
      pointerY: 0,
      targetX: 0,
      targetY: 0,
      reducedMotion: false,
      particles: []
    };
  },
  mounted() {
    this.reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.createParticles();
    this.resizeObserver = new ResizeObserver(this.resize);
    this.resizeObserver.observe(this.$el);
    this.resize();
    this.draw(0);
  },
  beforeDestroy() {
    cancelAnimationFrame(this.frame);
    if (this.resizeObserver) this.resizeObserver.disconnect();
  },
  methods: {
    createParticles() {
      this.particles = Array.from({ length: 230 }, (_, index) => {
        const y = 1 - (index / 229) * 2;
        const radius = Math.sqrt(1 - y * y);
        const theta = Math.PI * (3 - Math.sqrt(5)) * index;
        return {
          x: Math.cos(theta) * radius,
          y,
          z: Math.sin(theta) * radius,
          size: 0.45 + ((index * 17) % 11) / 10,
          phase: (index % 23) / 23 * Math.PI * 2
        };
      });
    },
    resize() {
      const canvas = this.$refs.canvas;
      if (!canvas) return;
      const rect = this.$el.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.max(1, Math.floor(rect.width * dpr));
      canvas.height = Math.max(1, Math.floor(rect.height * dpr));
      canvas.style.width = `${rect.width}px`;
      canvas.style.height = `${rect.height}px`;
      const context = canvas.getContext('2d');
      context.setTransform(dpr, 0, 0, dpr, 0, 0);
      this.width = rect.width;
      this.height = rect.height;
    },
    handlePointer(event) {
      const rect = this.$el.getBoundingClientRect();
      this.targetX = ((event.clientX - rect.left) / rect.width - 0.5) * 0.34;
      this.targetY = ((event.clientY - rect.top) / rect.height - 0.5) * 0.22;
    },
    resetPointer() {
      this.targetX = 0;
      this.targetY = 0;
    },
    project(x, y, z, scale, centerX, centerY) {
      const perspective = 1 / (1.31 - z * 0.24);
      return {
        x: centerX + x * scale * perspective,
        y: centerY + y * scale * perspective,
        depth: perspective
      };
    },
    rotatePoint(point, ax, ay) {
      const cosY = Math.cos(ay);
      const sinY = Math.sin(ay);
      const x1 = point.x * cosY - point.z * sinY;
      const z1 = point.x * sinY + point.z * cosY;
      const cosX = Math.cos(ax);
      const sinX = Math.sin(ax);
      return {
        x: x1,
        y: point.y * cosX - z1 * sinX,
        z: point.y * sinX + z1 * cosX
      };
    },
    drawRibbon(context, time, color, phase, tilt, scale, centerX, centerY) {
      context.beginPath();
      const steps = 170;
      for (let i = 0; i <= steps; i += 1) {
        const angle = (i / steps) * Math.PI * 2;
        const wobble = 1 + Math.sin(angle * 3 + time * 0.0013 + phase) * 0.075;
        const point = this.rotatePoint({
          x: Math.cos(angle) * 1.13 * wobble,
          y: Math.sin(angle) * 0.56 * wobble,
          z: Math.sin(angle * 2 + phase) * 0.28
        }, tilt + this.pointerY, time * 0.00012 + phase + this.pointerX);
        const projected = this.project(point.x, point.y, point.z, scale, centerX, centerY);
        if (i === 0) context.moveTo(projected.x, projected.y);
        else context.lineTo(projected.x, projected.y);
      }
      context.strokeStyle = color;
      context.lineWidth = 1.15;
      context.shadowColor = color;
      context.shadowBlur = 13;
      context.stroke();
      context.shadowBlur = 0;
    },
    draw(timestamp) {
      const canvas = this.$refs.canvas;
      if (!canvas || !this.width || !this.height) return;
      const context = canvas.getContext('2d');
      context.clearRect(0, 0, this.width, this.height);
      context.globalCompositeOperation = 'lighter';

      const time = this.reducedMotion ? 1800 : timestamp;
      this.pointerX += (this.targetX - this.pointerX) * 0.04;
      this.pointerY += (this.targetY - this.pointerY) * 0.04;
      const centerX = this.width * 0.5;
      const centerY = this.height * 0.49;
      const scale = Math.min(this.width, this.height) * 0.49;

      const glow = context.createRadialGradient(centerX, centerY, 0, centerX, centerY, scale * 1.08);
      glow.addColorStop(0, 'rgba(40, 188, 255, 0.22)');
      glow.addColorStop(0.35, 'rgba(83, 69, 255, 0.13)');
      glow.addColorStop(0.72, 'rgba(123, 45, 255, 0.05)');
      glow.addColorStop(1, 'rgba(0, 0, 0, 0)');
      context.fillStyle = glow;
      context.fillRect(centerX - scale * 1.2, centerY - scale * 1.2, scale * 2.4, scale * 2.4);

      const trailGradient = context.createLinearGradient(centerX - scale * 1.9, centerY, centerX + scale * .4, centerY);
      trailGradient.addColorStop(0, 'rgba(28, 111, 255, 0)');
      trailGradient.addColorStop(.42, 'rgba(26, 156, 255, .18)');
      trailGradient.addColorStop(.82, 'rgba(51, 211, 255, .7)');
      trailGradient.addColorStop(1, 'rgba(112, 75, 255, .14)');
      for (let trail = 0; trail < 5; trail += 1) {
        context.beginPath();
        context.moveTo(centerX - scale * 1.95, centerY + scale * (.86 + trail * .045));
        context.bezierCurveTo(
          centerX - scale * 1.22,
          centerY + scale * (1.12 - trail * .08),
          centerX - scale * .74,
          centerY + scale * (.28 + trail * .035),
          centerX - scale * .08,
          centerY + scale * (.06 - trail * .022)
        );
        context.strokeStyle = trailGradient;
        context.lineWidth = .55 + trail * .18;
        context.shadowColor = trail % 2 ? '#624dff' : '#20bfff';
        context.shadowBlur = 10;
        context.stroke();
      }
      context.shadowBlur = 0;

      this.drawRibbon(context, time, 'rgba(52, 207, 255, .82)', 0.15, -0.36, scale, centerX, centerY);
      this.drawRibbon(context, time, 'rgba(112, 82, 255, .68)', 2.1, 0.47, scale * 1.04, centerX, centerY);
      this.drawRibbon(context, time, 'rgba(210, 69, 255, .58)', 4.25, -0.72, scale * 0.96, centerX, centerY);

      const rotation = time * 0.00008 + this.pointerX;
      this.particles.forEach((particle) => {
        const point = this.rotatePoint(particle, -0.12 + this.pointerY, rotation);
        const projected = this.project(point.x, point.y, point.z, scale * 0.88, centerX, centerY);
        const pulse = 0.55 + Math.sin(time * 0.0018 + particle.phase) * 0.3;
        const alpha = Math.max(0.12, (point.z + 1.1) * 0.34) * pulse;
        context.beginPath();
        context.arc(projected.x, projected.y, particle.size * projected.depth, 0, Math.PI * 2);
        context.fillStyle = point.z > 0.12
          ? `rgba(79, 219, 255, ${alpha})`
          : `rgba(145, 86, 255, ${alpha * 0.72})`;
        context.fill();
      });

      const core = context.createRadialGradient(centerX, centerY, 0, centerX, centerY, scale * 0.34);
      core.addColorStop(0, 'rgba(226, 250, 255, .95)');
      core.addColorStop(0.08, 'rgba(52, 213, 255, .72)');
      core.addColorStop(0.34, 'rgba(45, 100, 255, .25)');
      core.addColorStop(1, 'rgba(63, 45, 255, 0)');
      context.fillStyle = core;
      context.beginPath();
      context.arc(centerX, centerY, scale * 0.38, 0, Math.PI * 2);
      context.fill();

      context.globalCompositeOperation = 'source-over';
      if (!this.reducedMotion) this.frame = requestAnimationFrame(this.draw);
    }
  }
};
</script>

<style lang="scss" scoped>
.voice-energy-core {
  position: relative;
  width: min(45vw, 620px);
  aspect-ratio: 1.1;
  max-height: 62vh;
  isolation: isolate;
  filter: saturate(1.16);

  &__canvas,
  &__halo {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
  }

  &__halo {
    inset: 15%;
    width: 70%;
    height: 70%;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(35, 196, 255, .16), rgba(67, 50, 255, .06) 48%, transparent 72%);
    filter: blur(34px);
    animation: energy-breathe 4.6s ease-in-out infinite;
    z-index: -1;
  }

  &__wave {
    position: absolute;
    top: 50%;
    left: 50%;
    display: flex;
    align-items: center;
    gap: 4px;
    height: 82px;
    transform: translate(-50%, -50%);
    filter: drop-shadow(0 0 8px #23d3ff) drop-shadow(0 0 18px rgba(87, 73, 255, .75));

    span {
      width: 2px;
      height: 34px;
      max-height: 66px;
      border-radius: 4px;
      background: linear-gradient(180deg, #d8fbff, #22d7ff 48%, #7857ff);
      animation: energy-wave 1.46s ease-in-out infinite alternate;
      animation-delay: -.42s;
      opacity: .86;

      &:nth-child(3n) { height: 54px; animation-duration: 1.18s; }
      &:nth-child(4n) { height: 22px; animation-duration: 1.72s; }
      &:nth-child(5n) { height: 66px; animation-delay: -.85s; }
      &:nth-child(7n) { height: 42px; animation-duration: 1.31s; }
    }
  }
}

@keyframes energy-wave {
  from { transform: scaleY(.32); opacity: .5; }
  to { transform: scaleY(1); opacity: 1; }
}

@keyframes energy-breathe {
  50% { transform: scale(1.13); opacity: .75; }
}

@media (prefers-reduced-motion: reduce) {
  .voice-energy-core__halo,
  .voice-energy-core__wave span { animation: none; }
}
</style>
