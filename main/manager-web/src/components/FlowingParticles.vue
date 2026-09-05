<template>
  <div ref="container" class="flowing-particles"></div>
</template>

<script>
import { Camera, Geometry, Mesh, Program, Renderer } from 'ogl';
const { getSafePixelRatio, shouldAnimate } = require('@/utils/motionProfile');

const vertex = /* glsl */ `
  attribute vec3 position;
  attribute vec3 color;
  attribute vec3 random;

  uniform mat4 modelViewMatrix;
  uniform mat4 projectionMatrix;
  uniform float uTime;
  uniform float uSpread;
  uniform float uPointSize;

  varying vec3 vColor;
  varying float vAlpha;

  void main() {
    float x = position.x * uSpread;
    float layer = position.z;
    float drift = uTime * mix(0.18, 0.34, random.x);
    float primaryWave = sin(x * mix(0.48, 0.82, random.y) + drift + layer * 5.8);
    float detailWave = sin(x * 1.55 - drift * 1.7 + random.z * 6.2831) * 0.28;
    float y = mix(-4.9, -2.65, layer) + primaryWave * mix(0.28, 0.76, layer) + detailWave;
    float z = mix(-1.2, 0.8, random.z);

    vec4 mvPosition = modelViewMatrix * vec4(x, y, z, 1.0);
    gl_PointSize = uPointSize * mix(0.55, 1.55, random.y) / max(0.75, length(mvPosition.xyz) * 0.085);
    gl_Position = projectionMatrix * mvPosition;

    vColor = color;
    vAlpha = mix(0.2, 0.82, layer) * mix(0.5, 1.0, random.x);
  }
`;

const fragment = /* glsl */ `
  precision highp float;

  varying vec3 vColor;
  varying float vAlpha;

  void main() {
    float distanceToCenter = length(gl_PointCoord - vec2(0.5));
    float particle = smoothstep(0.5, 0.08, distanceToCenter);
    float glow = smoothstep(0.5, 0.0, distanceToCenter) * 0.32;
    gl_FragColor = vec4(vColor, (particle + glow) * vAlpha);
  }
`;

const hexToRgb = hex => {
  const value = parseInt(hex.replace('#', ''), 16);
  return [((value >> 16) & 255) / 255, ((value >> 8) & 255) / 255, (value & 255) / 255];
};

export default {
  name: 'FlowingParticles',
  props: {
    count: { type: Number, default: 460 },
    speed: { type: Number, default: 0.055 },
    spread: { type: Number, default: 15.5 },
    pointSize: { type: Number, default: 30 },
    colors: {
      type: Array,
      default: () => ['#159DFF', '#28D7FF', '#526DFF', '#8A45FF']
    }
  },
  data() {
    return {
      animationFrameId: null,
      reducedMotion: false,
      pageHidden: false,
      motionMedia: null
    };
  },
  mounted() {
    this.motionMedia = window.matchMedia('(prefers-reduced-motion: reduce)');
    this.reducedMotion = this.motionMedia.matches;
    this.pageHidden = document.hidden;
    this.motionMedia.addEventListener?.('change', this.handleMotionPreference);
    document.addEventListener('visibilitychange', this.handleVisibilityChange);
    if (shouldAnimate({ reducedMotion: this.reducedMotion, hidden: this.pageHidden })) this.init();
  },
  beforeDestroy() {
    this.cleanup();
  },
  methods: {
    init() {
      const container = this.$refs.container;
      if (!container || this._renderer) return;

      this._renderer = new Renderer({
        dpr: getSafePixelRatio(window.devicePixelRatio),
        alpha: true,
        depth: false
      });
      this._gl = this._renderer.gl;
      this._gl.clearColor(0, 0, 0, 0);
      container.appendChild(this._gl.canvas);

      this._camera = new Camera(this._gl, { fov: 36 });
      this._camera.position.set(0, 0, 10);

      const positions = new Float32Array(this.count * 3);
      const randoms = new Float32Array(this.count * 3);
      const colors = new Float32Array(this.count * 3);

      for (let index = 0; index < this.count; index += 1) {
        const layer = Math.random();
        positions.set([Math.random() * 2 - 1, 0, layer], index * 3);
        randoms.set([Math.random(), Math.random(), Math.random()], index * 3);
        colors.set(hexToRgb(this.colors[index % this.colors.length]), index * 3);
      }

      this._geometry = new Geometry(this._gl, {
        position: { size: 3, data: positions },
        random: { size: 3, data: randoms },
        color: { size: 3, data: colors }
      });

      this._program = new Program(this._gl, {
        vertex,
        fragment,
        transparent: true,
        depthTest: false,
        uniforms: {
          uTime: { value: 0 },
          uSpread: { value: this.spread },
          uPointSize: { value: this.pointSize }
        }
      });

      this._mesh = new Mesh(this._gl, {
        mode: this._gl.POINTS,
        geometry: this._geometry,
        program: this._program
      });
      this._startedAt = performance.now();
      window.addEventListener('resize', this.handleResize, { passive: true });
      this.handleResize();
      this.startAnimation();
    },
    startAnimation() {
      if (this.animationFrameId || !this._renderer || this.reducedMotion || this.pageHidden) return;
      this.animationFrameId = requestAnimationFrame(this.renderFrame);
    },
    renderFrame(time) {
      this.animationFrameId = null;
      if (!this._program || this.reducedMotion || this.pageHidden) return;
      this._program.uniforms.uTime.value = (time - this._startedAt) * 0.001 * this.speed * 10;
      this._renderer.render({ scene: this._mesh, camera: this._camera });
      this.startAnimation();
    },
    handleResize() {
      const container = this.$refs.container;
      if (!container || !this._renderer || !this._camera) return;
      const width = container.clientWidth;
      const height = container.clientHeight;
      this._renderer.setSize(width, height);
      this._camera.perspective({ aspect: width / Math.max(height, 1) });
    },
    handleVisibilityChange() {
      this.pageHidden = document.hidden;
      this.pageHidden ? this.stopAnimation() : this.startAnimation();
    },
    handleMotionPreference(event) {
      this.reducedMotion = event.matches;
      this.reducedMotion ? this.stopAnimation() : (this._renderer ? this.startAnimation() : this.init());
    },
    stopAnimation() {
      if (!this.animationFrameId) return;
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    },
    cleanup() {
      this.stopAnimation();
      window.removeEventListener('resize', this.handleResize);
      document.removeEventListener('visibilitychange', this.handleVisibilityChange);
      this.motionMedia?.removeEventListener?.('change', this.handleMotionPreference);
      const canvas = this._gl?.canvas;
      if (canvas && canvas.parentNode) canvas.parentNode.removeChild(canvas);
      this._renderer = null;
      this._gl = null;
      this._camera = null;
      this._geometry = null;
      this._program = null;
      this._mesh = null;
    }
  }
};
</script>

<style scoped>
.flowing-particles {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
  opacity: .78;
  mask-image: linear-gradient(to top, #000 0%, rgba(0, 0, 0, .88) 27%, transparent 68%);
  -webkit-mask-image: linear-gradient(to top, #000 0%, rgba(0, 0, 0, .88) 27%, transparent 68%);
}

::v-deep canvas {
  display: block;
  width: 100% !important;
  height: 100% !important;
}
</style>
