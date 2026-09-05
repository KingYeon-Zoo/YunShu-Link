const PROFILES = {
  login: {
    enabled: true,
    particleCount: 220,
    particleSpread: 11,
    speed: 0.08,
    particleBaseSize: 140,
    sizeRandomness: 1,
    moveParticlesOnHover: false,
    particleHoverFactor: 0,
    alphaParticles: true,
    cameraDistance: 20
  },
  management: {
    enabled: true,
    particleCount: 72,
    particleSpread: 13,
    speed: 0.025,
    particleBaseSize: 72,
    sizeRandomness: 0.8,
    moveParticlesOnHover: false,
    particleHoverFactor: 0,
    alphaParticles: true,
    cameraDistance: 22
  }
};

function getMotionProfile(variant = 'management', reducedMotion = false) {
  if (reducedMotion) {
    return {
      ...PROFILES[variant] || PROFILES.management,
      enabled: false,
      particleCount: 0
    };
  }

  return { ...(PROFILES[variant] || PROFILES.management) };
}

function getSafePixelRatio(value) {
  const ratio = Number(value);
  if (!Number.isFinite(ratio) || ratio <= 0) return 1;
  return Math.min(ratio, 1.75);
}

function shouldAnimate({ reducedMotion = false, hidden = false } = {}) {
  return !reducedMotion && !hidden;
}

module.exports = {
  getMotionProfile,
  getSafePixelRatio,
  shouldAnimate
};
