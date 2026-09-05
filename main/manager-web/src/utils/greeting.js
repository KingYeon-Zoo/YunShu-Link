/**
 * 根据当前时间获取问候语信息
 * @param {string} [name='']
 * @returns {{ prefixKey: string, name: string }}
 */
export function getGreeting(name = '') {
  const hour = new Date().getHours();
  let prefixKey;
  if (hour < 12) {
    prefixKey = 'greeting.morning';
  } else if (hour < 18) {
    prefixKey = 'greeting.afternoon';
  } else {
    prefixKey = 'greeting.evening';
  }
  return { prefixKey, name };
}

/**
 * 格式化问候语
 * @param {Function} t - i18n 翻译函数
 * @param {string} [name='']
 * @returns {string}
 */
export function formatGreeting(t, name = '') {
  const { prefixKey } = getGreeting(name);
  return t('greeting.format', { greeting: t(prefixKey), name });
}
