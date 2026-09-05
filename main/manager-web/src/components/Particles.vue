<template>
  <div ref="container" class="particles-container"></div>
</template>

<script>
import { Renderer, Camera, Geometry, Program, Mesh } from 'ogl';
const { getSafePixelRatio, shouldAnimate } = require('@/utils/motionProfile');

const defaultColors = ['#ffffff', '#ffffff', '#ffffff'];

const hexToRgb = hex => {
  hex = hex.replace(/^#/, '');
  if (hex.length === 3) {
    hex = hex
      .split('')
      .map(c => c + c)
      .join('');
  }
  const int = parseInt(hex, 16);
  const r = ((int >> 16) & 255) / 255;
  const g = ((int >> 8) & 255) / 255;
  const b = (int & 255) / 255;
  return [r, g, b];
};

const vertex = /* glsl */ `
  attribute vec3 position;
  attribute vec4 random;
  attribute vec3 color;
  
  uniform mat4 modelMatrix;
  uniform mat4 viewMatrix;
  uniform mat4 projectionMatrix;
  uniform float uTime;
  uniform float uSpread;
  uniform float uBaseSize;
  uniform float uSizeRandomness;
  
  varying vec4 vRandom;
  varying vec3 vColor;
  
  void main() {
    vRandom = random;
    vColor = color;
    
    vec3 pos = position * uSpread;
    pos.z *= 10.0;
    
    vec4 mPos = modelMatrix * vec4(pos, 1.0);
    float t = uTime;
    mPos.x += sin(t * random.z + 6.28 * random.w) * mix(0.1, 1.5, random.x);
    mPos.y += sin(t * random.y + 6.28 * random.x) * mix(0.1, 1.5, random.w);
    mPos.z += sin(t * random.w + 6.28 * random.y) * mix(0.1, 1.5, random.z);
    
    vec4 mvPos = viewMatrix * mPos;

    if (uSizeRandomness == 0.0) {
      gl_PointSize = uBaseSize;
    } else {
      gl_PointSize = (uBaseSize * (1.0 + uSizeRandomness * (random.x - 0.5))) / length(mvPos.xyz);
    }

    gl_Position = projectionMatrix * mvPos;
  }
`;

const fragment = /* glsl */ `
  precision highp float;
  
  uniform float uTime;
  uniform float uAlphaParticles;
  varying vec4 vRandom;
  varying vec3 vColor;
  
  void main() {
    vec2 uv = gl_PointCoord.xy;
    float d = length(uv - vec2(0.5));
    
    if(uAlphaParticles < 0.5) {
      if(d > 0.5) {
        discard;
      }
      gl_FragColor = vec4(vColor + 0.2 * sin(uv.yxx + uTime + vRandom.y * 6.28), 1.0);
    } else {
      float circle = smoothstep(0.5, 0.4, d) * 0.8;
      gl_FragColor = vec4(vColor + 0.2 * sin(uv.yxx + uTime + vRandom.y * 6.28), circle);
    }
  }
`;

export default {
  name: 'Particles',
  props: {
    particleCount: { type: Number, default: 220 },
    particleSpread: { type: Number, default: 11 },
    speed: { type: Number, default: 0.08 },
    particleColors: { type: Array, default: () => ['#828cff', '#b382ff', '#87d4ff', '#ffffff'] },
    moveParticlesOnHover: { type: Boolean, default: true },
    particleHoverFactor: { type: Number, default: 1.2 },
    alphaParticles: { type: Boolean, default: true },
    particleBaseSize: { type: Number, default: 140 },
    sizeRandomness: { type: Number, default: 1.0 },
    cameraDistance: { type: Number, default: 20 },
    disableRotation: { type: Boolean, default: false },
    pixelRatio: {
      type: Number,
      default: () => getSafePixelRatio(typeof window === 'undefined' ? 1 : window.devicePixelRatio)
    }
  },
  data() {
    return {
      animationFrameId: null,
      mouse: { x: 0, y: 0 },
      reducedMotion: false,
      pageHidden: false,
      motionMedia: null
    };
  },
  mounted() {
    this.motionMedia = window.matchMedia('(prefers-reduced-motion: reduce)');
    this.reducedMotion = this.motionMedia.matches;
    this.pageHidden = document.hidden;
    if (this.motionMedia.addEventListener) {
      this.motionMedia.addEventListener('change', this.handleMotionPreference);
    } else {
      this.motionMedia.addListener(this.handleMotionPreference);
    }
    document.addEventListener('visibilitychange', this.handleVisibilityChange);

    if (shouldAnimate({ reducedMotion: this.reducedMotion, hidden: this.pageHidden })) {
      this.init();
    }
  },
  beforeDestroy() {
    this.cleanup();
  },
  methods: {
    init() {
      const container = this.$refs.container;
      if (!container) return;

      // 初始化 OGL 渲染器
      // OGL 的 Vec3/Mat4 都是 Array 子类，不能放进 Vue 2 的响应式 data，
      // 否则数组观察器会替换原型并移除 set/copy 等方法。
      this._renderer = new Renderer({
        dpr: getSafePixelRatio(this.pixelRatio),
        depth: false,
        alpha: true
      });
      
      this._gl = this._renderer.gl;
      container.appendChild(this._gl.canvas);
      this._gl.clearColor(0, 0, 0, 0);

      // 设置 3D 相机
      this._camera = new Camera(this._gl, { fov: 15 });
      this._camera.position.set(0, 0, this.cameraDistance);

      window.addEventListener('resize', this.handleResize, false);
      this.handleResize();

      if (this.moveParticlesOnHover) {
        window.addEventListener('mousemove', this.handleMouseMove, { passive: true });
      }

      // 生成粒子顶点数据
      const count = this.particleCount;
      const positions = new Float32Array(count * 3);
      const randoms = new Float32Array(count * 4);
      const colors = new Float32Array(count * 3);
      const palette = this.particleColors && this.particleColors.length > 0 ? this.particleColors : defaultColors;

      for (let i = 0; i < count; i++) {
        let x, y, z, len;
        do {
          x = Math.random() * 2 - 1;
          y = Math.random() * 2 - 1;
          z = Math.random() * 2 - 1;
          len = x * x + y * y + z * z;
        } while (len > 1 || len === 0);
        const r = Math.cbrt(Math.random());
        positions.set([x * r, y * r, z * r], i * 3);
        randoms.set([Math.random(), Math.random(), Math.random(), Math.random()], i * 4);
        const col = hexToRgb(palette[Math.floor(Math.random() * palette.length)]);
        colors.set(col, i * 3);
      }

      this._geometry = new Geometry(this._gl, {
        position: { size: 3, data: positions },
        random: { size: 4, data: randoms },
        color: { size: 3, data: colors }
      });

      // 初始化 Shader Program
      this._program = new Program(this._gl, {
        vertex,
        fragment,
        uniforms: {
          uTime: { value: 0 },
          uSpread: { value: this.particleSpread },
          uBaseSize: { value: this.particleBaseSize * this.pixelRatio },
          uSizeRandomness: { value: this.sizeRandomness },
          uAlphaParticles: { value: this.alphaParticles ? 1 : 0 }
        },
        transparent: true,
        depthTest: false
      });

      this._mesh = new Mesh(this._gl, {
        mode: this._gl.POINTS,
        geometry: this._geometry,
        program: this._program
      });

      this._lastFrameTime = performance.now();
      this._elapsedTime = 0;
      this.startAnimation();
    },
    startAnimation() {
      if (this.animationFrameId || !this._renderer) return;
      if (!shouldAnimate({ reducedMotion: this.reducedMotion, hidden: this.pageHidden })) return;
      this._lastFrameTime = performance.now();
      this.animationFrameId = requestAnimationFrame(this.renderFrame);
    },
    stopAnimation() {
      if (this.animationFrameId) {
        cancelAnimationFrame(this.animationFrameId);
        this.animationFrameId = null;
      }
    },
    renderFrame(time) {
      this.animationFrameId = null;
      if (!this._program || !this._mesh || !this._renderer || !this._camera) return;
      if (!shouldAnimate({ reducedMotion: this.reducedMotion, hidden: this.pageHidden })) return;

      const delta = Math.min(time - this._lastFrameTime, 32);
      this._lastFrameTime = time;
      this._elapsedTime += delta * this.speed;
      const elapsed = this._elapsedTime;
      this._program.uniforms.uTime.value = elapsed * 0.001;

      this._mesh.position.x = this.moveParticlesOnHover ? -this.mouse.x * this.particleHoverFactor : 0;
      this._mesh.position.y = this.moveParticlesOnHover ? -this.mouse.y * this.particleHoverFactor : 0;

      if (!this.disableRotation) {
        this._mesh.rotation.x = Math.sin(elapsed * 0.0002) * 0.1;
        this._mesh.rotation.y = Math.cos(elapsed * 0.0005) * 0.15;
        this._mesh.rotation.z += 0.01 * this.speed;
      }

      this._renderer.render({ scene: this._mesh, camera: this._camera });
      this.animationFrameId = requestAnimationFrame(this.renderFrame);
    },
    handleResize() {
      const container = this.$refs.container;
      if (!container || !this._renderer || !this._camera || !this._gl) return;
      const width = container.clientWidth;
      const height = container.clientHeight;
      this._renderer.setSize(width, height);
      this._camera.perspective({ aspect: width / Math.max(height, 1) });
    },
    handleMouseMove(e) {
      const container = this.$refs.container;
      if (!container) return;
      const x = (e.clientX / window.innerWidth) * 2 - 1;
      const y = -((e.clientY / window.innerHeight) * 2 - 1);
      this.mouse = { x, y };
    },
    handleVisibilityChange() {
      this.pageHidden = document.hidden;
      if (this.pageHidden) {
        this.stopAnimation();
      } else if (!this._renderer && !this.reducedMotion) {
        this.init();
      } else {
        this.startAnimation();
      }
    },
    handleMotionPreference(event) {
      this.reducedMotion = event.matches;
      if (this.reducedMotion) {
        this.stopAnimation();
      } else if (!this._renderer) {
        this.init();
      } else {
        this.startAnimation();
      }
    },
    cleanup() {
      window.removeEventListener('resize', this.handleResize);
      window.removeEventListener('mousemove', this.handleMouseMove);
      document.removeEventListener('visibilitychange', this.handleVisibilityChange);
      if (this.motionMedia) {
        if (this.motionMedia.removeEventListener) {
          this.motionMedia.removeEventListener('change', this.handleMotionPreference);
        } else {
          this.motionMedia.removeListener(this.handleMotionPreference);
        }
      }
      this.stopAnimation();
      const container = this.$refs.container;
      if (container && this._gl && this._gl.canvas && container.contains(this._gl.canvas)) {
        container.removeChild(this._gl.canvas);
      }
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
.particles-container {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
  overflow: hidden;
  pointer-events: none;
}
::v-deep canvas {
  display: block;
  width: 100% !important;
  height: 100% !important;
}
</style>
