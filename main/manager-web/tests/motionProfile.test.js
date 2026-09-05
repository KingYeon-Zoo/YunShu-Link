const assert = require('assert');

const {
  getMotionProfile,
  getSafePixelRatio,
  shouldAnimate
} = require('../src/utils/motionProfile');

const login = getMotionProfile('login', false);
assert.strictEqual(login.enabled, true);
assert.strictEqual(login.particleCount, 220);
assert.strictEqual(login.moveParticlesOnHover, false);
assert.strictEqual(login.particleHoverFactor, 0);

const management = getMotionProfile('management', false);
assert.strictEqual(management.enabled, true);
assert.strictEqual(management.particleCount, 72);
assert.strictEqual(management.moveParticlesOnHover, false);
assert.ok(management.speed < login.speed);

const reduced = getMotionProfile('login', true);
assert.strictEqual(reduced.enabled, false);
assert.strictEqual(reduced.particleCount, 0);

assert.strictEqual(getSafePixelRatio(3), 1.75);
assert.strictEqual(getSafePixelRatio(0), 1);
assert.strictEqual(shouldAnimate({ reducedMotion: false, hidden: false }), true);
assert.strictEqual(shouldAnimate({ reducedMotion: true, hidden: false }), false);
assert.strictEqual(shouldAnimate({ reducedMotion: false, hidden: true }), false);

console.log('motionProfile tests passed');
