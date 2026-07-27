const assert = require('assert');
const fs = require('fs');
const path = require('path');

const source = fs.readFileSync(
  path.join(__dirname, '../src/components/Particles.vue'),
  'utf8'
);

// Vue 2 会观察 data 中的 Array 子类，导致 OGL Vec3 的原型方法丢失。
assert.ok(!source.includes('camera: null'));
assert.ok(!source.includes('renderer: null'));
assert.ok(source.includes('this._camera.position.set'));

console.log('Particles Vue 2 compatibility tests passed');
