<template>
  <div class="auth-page">
    <DynamicBackground variant="login" aria-hidden="true" />

    <div class="auth-page__container" @keyup.enter="retrievePassword">
      <div class="auth-card">
        <!-- 左侧：语音硬件展示区 -->
        <div class="auth-card__visual">
          <div class="brand-section">
            <img class="brand-logo" src="@/assets/brand/yunshu-link-logo.png" alt="云枢 YunShu Link" />
          </div>

          <VoiceEnergyCore class="voice-wave-container" />

          <div class="slogan-section">
            <h1 class="brand-title">{{ $t('login.brandTitle') }}</h1>
            <p class="brand-slogan">{{ $t('login.brandSlogan') }}</p>
          </div>
        </div>

        <!-- 右侧：找回密码输入区 -->
        <div class="auth-card__form">
          <div class="form-wrapper">
            <div class="card-header">
              <img loading="lazy" alt="" src="@/assets/login/hi.png" class="card-header__icon" />
              <div class="card-header__titles">
                <h2 class="card-title">{{ $t('retrievePassword.title') }}</h2>
                <p class="card-subtitle">{{ $t('retrievePassword.subtitle') }}</p>
              </div>
            </div>

            <div class="login-form" style="padding: 0;">
              <!-- 手机号输入 -->
              <div class="input-box input-box--mobile">
                <el-select v-model="form.areaCode" class="area-select">
                  <el-option v-for="item in mobileAreaList" :key="item.key" :label="`${item.name} (${item.key})`"
                    :value="item.key" />
                </el-select>
                <el-input v-model="form.mobile" :placeholder="$t('retrievePassword.mobilePlaceholder')" />
              </div>

              <!-- 图形验证码 -->
              <div class="input-row">
                <div class="input-box">
                  <img loading="lazy" alt="" class="input-icon" src="@/assets/login/shield.png" />
                  <el-input v-model="form.captcha" :placeholder="$t('retrievePassword.captchaPlaceholder')" />
                </div>
                <img loading="lazy" v-if="captchaUrl" :src="captchaUrl" alt="验证码" class="captcha-img"
                  @click="fetchCaptcha" />
              </div>

              <!-- 手机短信验证码 -->
              <div class="input-row">
                <div class="input-box">
                  <img loading="lazy" alt="" class="input-icon" src="@/assets/login/phone.png" />
                  <el-input v-model="form.mobileCaptcha" :placeholder="$t('retrievePassword.mobileCaptchaPlaceholder')"
                    maxlength="6" />
                </div>
                <el-button type="primary" class="send-captcha-btn" :disabled="!canSendMobileCaptcha"
                  @click="sendMobileCaptcha">
                  <span>
                    {{ countdown > 0 ? `${countdown}${$t('register.secondsLater')}` : $t('retrievePassword.getMobileCaptcha') }}
                  </span>
                </el-button>
              </div>

              <!-- 新密码 -->
              <div class="input-box">
                <img loading="lazy" alt="" class="input-icon" src="@/assets/login/password.png" />
                <el-input v-model="form.newPassword" :placeholder="$t('retrievePassword.newPasswordPlaceholder')"
                  type="password" show-password />
              </div>

              <!-- 确认新密码 -->
              <div class="input-box">
                <img loading="lazy" alt="" class="input-icon" src="@/assets/login/password.png" />
                <el-input v-model="form.confirmPassword" :placeholder="$t('retrievePassword.confirmNewPasswordPlaceholder')"
                  type="password" show-password />
              </div>
            </div>

            <div class="form-actions">
              <span class="form-actions__link" @click="goToLogin">{{ $t('retrievePassword.goToLogin') }}</span>
            </div>

            <button class="submit-btn" @click="retrievePassword">{{ $t('retrievePassword.resetButton') }}</button>

            <div class="agreement-declaration">
              {{ $t('retrievePassword.agreeTo') }}
              <span class="agreement-declaration__link" @click="openPage('/user-agreement.html')">{{ $t('register.userAgreement') }}</span>
              {{ $t('login.and') }}
              <span class="agreement-declaration__link" @click="openPage('/privacy-policy.html')">{{ $t('register.privacyPolicy') }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Api from '@/apis/api';
import DynamicBackground from "@/components/DynamicBackground.vue";
import VoiceEnergyCore from "@/components/VoiceEnergyCore.vue";
import { getUUID, goToPage, showDanger, showSuccess, validateMobile, sm2Encrypt } from '@/utils';
import { mapState } from 'vuex';

export default {
  name: 'retrieve',
  components: {
    DynamicBackground,
    VoiceEnergyCore,
  },
  computed: {
    ...mapState({
      allowUserRegister: state => state.pubConfig.allowUserRegister,
      mobileAreaList: state => state.pubConfig.mobileAreaList,
      sm2PublicKey: state => state.pubConfig.sm2PublicKey
    }),
    canSendMobileCaptcha() {
      return this.countdown === 0 && validateMobile(this.form.mobile, this.form.areaCode);
    }
  },
  data() {
    return {
      form: {
        areaCode: '+86',
        mobile: '',
        captcha: '',
        captchaId: '',
        mobileCaptcha: '',
        newPassword: '',
        confirmPassword: ''
      },
      captchaUrl: '',
      countdown: 0,
      timer: null
    }
  },
  mounted() {
    this.fetchCaptcha();
  },
  methods: {
    openPage(url) {
      const lang = this.$i18n ? this.$i18n.locale : 'zh_CN';
      if (!lang.startsWith('zh')) {
        url = url.replace('.html', '-en.html');
      }
      window.open(url, '_blank');
    },
    fetchCaptcha() {
      this.form.captchaId = getUUID();
      Api.user.getCaptcha(this.form.captchaId, (res) => {
        if (res.status === 200) {
          const blob = new Blob([res.data], { type: res.data.type });
          this.captchaUrl = URL.createObjectURL(blob);
        } else {
          console.error('验证码加载异常:', error);
          showDanger(this.$t('register.captchaLoadFailed'));
        }
      });
    },

    validateInput(input, message) {
      if (!input.trim()) {
        showDanger(message);
        return false;
      }
      return true;
    },

    sendMobileCaptcha() {
      if (!validateMobile(this.form.mobile, this.form.areaCode)) {
        showDanger(this.$t('retrievePassword.inputCorrectMobile'));
        return;
      }

      if (!this.validateInput(this.form.captcha, this.$t('retrievePassword.captchaRequired'))) {
        this.fetchCaptcha();
        return;
      }

      if (this.timer) {
        clearInterval(this.timer);
        this.timer = null;
      }

      this.countdown = 60;
      this.timer = setInterval(() => {
        if (this.countdown > 0) {
          this.countdown--;
        } else {
          clearInterval(this.timer);
          this.timer = null;
        }
      }, 1000);

      Api.user.sendSmsVerification({
        phone: this.form.areaCode + this.form.mobile,
        captcha: this.form.captcha,
        captchaId: this.form.captchaId
      }, (res) => {
        showSuccess(this.$t('retrievePassword.captchaSendSuccess'));
      }, (err) => {
        showDanger(err.data.msg || this.$t('register.captchaSendFailed'));
        this.countdown = 0;
        this.fetchCaptcha();
      });
    },

    retrievePassword() {
      if (!validateMobile(this.form.mobile, this.form.areaCode)) {
        showDanger(this.$t('retrievePassword.inputCorrectMobile'));
        return;
      }
      if (!this.form.captcha) {
        showDanger(this.$t('retrievePassword.captchaRequired'));
        return;
      }
      if (!this.form.mobileCaptcha) {
        showDanger(this.$t('retrievePassword.mobileCaptchaRequired'));
        return;
      }
      if (this.form.newPassword !== this.form.confirmPassword) {
        showDanger(this.$t('retrievePassword.passwordsNotMatch'));
        return;
      }

      let encryptedPassword;
      try {
        const captchaAndPassword = this.form.captcha + this.form.newPassword;
        encryptedPassword = sm2Encrypt(this.sm2PublicKey, captchaAndPassword);
      } catch (error) {
        console.error("密码加密失败:", error);
        showDanger(this.$t('sm2.encryptionFailed'));
        return;
      }

      Api.user.retrievePassword({
        phone: this.form.areaCode + this.form.mobile,
        password: encryptedPassword,
        code: this.form.mobileCaptcha,
        captchaId: this.form.captchaId
      }, (res) => {
        showSuccess(this.$t('retrievePassword.passwordUpdateSuccess'));
        goToPage('/login');
      }, (err) => {
        showDanger(err.data.msg || this.$t('message.error'));
        if (err.data != null && err.data.msg != null && (err.data.msg.indexOf('图形验证码') > -1 || err.data.msg.indexOf('Captcha') > -1)) {
          this.fetchCaptcha()
        }
      });
    },

    goToLogin() {
      goToPage('/login')
    }
  },
  beforeDestroy() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }
}
</script>

<style lang="scss" scoped>
@import "./auth-shared";
</style>
