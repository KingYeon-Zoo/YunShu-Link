<template>
  <div class="login-page">
    <DynamicBackground variant="login" aria-hidden="true" />

    <div class="login-page__container">
      <section class="login-page__visual">
        <div class="brand">
          <img class="brand__logo" :src="xiaozhiAiIcon" alt="logo" />
          <span class="brand__name">{{ $t('login.brandName') || '云枢' }}</span>
        </div>
        <h1 class="brand__title">{{ $t('login.brandTitle') }}</h1>
        <p class="brand__slogan">{{ $t('login.brandSlogan') }}</p>
        <div class="floating-blobs" aria-hidden="true">
          <div v-for="i in 3" :key="i" class="floating-blobs__item"></div>
        </div>
      </section>

      <section class="login-page__form">
        <div class="glass-card login-card" @keyup.enter="login">
          <div class="login-card__header">
            <img loading="lazy" alt="" src="@/assets/login/hi.png" class="login-card__icon" />
            <div class="login-card__titles">
              <h2 class="login-card__title">{{ $t('login.title') }}</h2>
              <p class="login-card__subtitle">{{ $t('login.welcomeBack') }}</p>
            </div>
            <el-dropdown trigger="click" class="login-card__lang" @visible-change="handleLanguageDropdownVisibleChange">
              <span class="el-dropdown-link">
                <span class="current-language-text">{{ currentLanguageText }}</span>
                <i class="el-icon-arrow-down el-icon--right" :class="{ 'rotate-down': languageDropdownVisible }"></i>
              </span>
              <el-dropdown-menu slot="dropdown">
                <el-dropdown-item @click.native="changeLanguage('zh_CN')">{{ $t('language.zhCN') }}</el-dropdown-item>
                <el-dropdown-item @click.native="changeLanguage('zh_TW')">{{ $t('language.zhTW') }}</el-dropdown-item>
                <el-dropdown-item @click.native="changeLanguage('en')">{{ $t('language.en') }}</el-dropdown-item>
                <el-dropdown-item @click.native="changeLanguage('de')">{{ $t('language.de') }}</el-dropdown-item>
                <el-dropdown-item @click.native="changeLanguage('vi')">{{ $t('language.vi') }}</el-dropdown-item>
                <el-dropdown-item @click.native="changeLanguage('pt_BR')">{{ $t('language.ptBR') }}</el-dropdown-item>
              </el-dropdown-menu>
            </el-dropdown>
          </div>

          <div class="login-form">
            <template v-if="!isMobileLogin">
              <div class="input-box">
                <img loading="lazy" alt="" class="input-icon" src="@/assets/login/username.png" />
                <el-input v-model="form.username" :placeholder="$t('login.usernamePlaceholder')" />
              </div>
            </template>

            <template v-else>
              <div class="input-box input-box--mobile">
                <el-select v-model="form.areaCode" class="area-select">
                  <el-option v-for="item in mobileAreaList" :key="item.key" :label="`${item.name} (${item.key})`"
                    :value="item.key" />
                </el-select>
                <el-input v-model="form.mobile" :placeholder="$t('login.mobilePlaceholder')" />
              </div>
            </template>

            <div class="input-box">
              <img loading="lazy" alt="" class="input-icon" src="@/assets/login/password.png" />
              <el-input v-model="form.password" :placeholder="$t('login.passwordPlaceholder')" type="password"
                show-password />
            </div>

            <div class="input-row">
              <div class="input-box" style="flex: 1; margin-top: 0">
                <img loading="lazy" alt="" class="input-icon" src="@/assets/login/shield.png" />
                <el-input v-model="form.captcha" :placeholder="$t('login.captchaPlaceholder')" />
              </div>
              <img loading="lazy" v-if="captchaUrl" :src="captchaUrl" alt="验证码" class="captcha-img"
                @click="fetchCaptcha" />
            </div>
          </div>

          <div class="login-actions">
            <span class="login-actions__link" @click="goToRegister">{{ $t('login.registerAccount') }}</span>
            <span class="login-actions__link" @click="goToForgetPassword">{{ $t('login.forgetPassword') }}</span>
          </div>

          <button class="login-btn" @click="login">{{ $t('login.login') }}</button>

          <div class="login-type-container" v-if="enableMobileRegister">
            <el-tooltip :content="$t('login.mobileLogin')" placement="bottom">
              <el-button :type="isMobileLogin ? 'primary' : 'default'" icon="el-icon-mobile" circle
                @click="switchLoginType('mobile')"></el-button>
            </el-tooltip>
            <el-tooltip :content="$t('login.usernameLogin')" placement="bottom">
              <el-button :type="!isMobileLogin ? 'primary' : 'default'" icon="el-icon-user" circle
                @click="switchLoginType('username')"></el-button>
            </el-tooltip>
          </div>

          <div class="auth-agreement">
            {{ $t('login.agreeTo') }}
            <span class="auth-agreement__link" @click="openPage('/user-agreement.html')">{{ $t('login.userAgreement') }}</span>
            {{ $t('login.and') }}
            <span class="auth-agreement__link" @click="openPage('/privacy-policy.html')">{{ $t('login.privacyPolicy') }}</span>
          </div>
        </div>
      </section>
    </div>

    <footer class="login-page__footer">
      <version-footer />
    </footer>
  </div>
</template>

<script>
import Api from "@/apis/api";
import DynamicBackground from "@/components/DynamicBackground.vue";
import VersionFooter from "@/components/VersionFooter.vue";
import i18n, { changeLanguage } from "@/i18n";
import { getUUID, goToPage, showDanger, showSuccess, sm2Encrypt, validateMobile } from "@/utils";
import { mapState } from "vuex";

export default {
  name: "login",
  components: {
    DynamicBackground,
    VersionFooter,
  },
  computed: {
    ...mapState({
      allowUserRegister: (state) => state.pubConfig.allowUserRegister,
      enableMobileRegister: (state) => state.pubConfig.enableMobileRegister,
      mobileAreaList: (state) => state.pubConfig.mobileAreaList,
      sm2PublicKey: (state) => state.pubConfig.sm2PublicKey,
    }),
    currentLanguage() {
      return i18n.locale || "zh_CN";
    },
    currentLanguageText() {
      const currentLang = this.currentLanguage;
      switch (currentLang) {
        case "zh_CN":
          return this.$t("language.zhCN");
        case "zh_TW":
          return this.$t("language.zhTW");
        case "en":
          return this.$t("language.en");
        case "de":
          return this.$t("language.de");
        case "vi":
          return this.$t("language.vi");
        case "pt_BR":
          return this.$t("language.ptBR");
        default:
          return this.$t("language.zhCN");
      }
    },
    xiaozhiAiIcon() {
      const currentLang = this.currentLanguage;
      switch (currentLang) {
        case "zh_TW":
          return require("@/assets/xiaozhi-ai_zh_TW.png");
        case "en":
          return require("@/assets/xiaozhi-ai_en.png");
        case "de":
          return require("@/assets/xiaozhi-ai_de.png");
        case "vi":
          return require("@/assets/xiaozhi-ai_vi.png");
        default:
          return require("@/assets/xiaozhi-ai.png");
      }
    },
  },
  data() {
    return {
      activeName: "username",
      form: {
        username: "",
        password: "",
        captcha: "",
        captchaId: "",
        areaCode: "+86",
        mobile: "",
      },
      captchaUuid: "",
      captchaUrl: "",
      isMobileLogin: false,
      languageDropdownVisible: false,
    };
  },
  mounted() {
    this.fetchCaptcha();
    this.$store.dispatch("fetchPubConfig").then(() => {
      this.isMobileLogin = this.enableMobileRegister;
    });
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
      const token = localStorage.getItem('token')
      if (token) {
        if (this.$route.path !== "/home") {
          this.$router.push("/home");
        }
      } else {
        this.captchaUuid = getUUID();

        Api.user.getCaptcha(this.captchaUuid, (res) => {
          if (res.status === 200) {
            const blob = new Blob([res.data], { type: res.data.type });
            this.captchaUrl = URL.createObjectURL(blob);
          } else {
            showDanger("验证码加载失败，点击刷新");
          }
        });
      }
    },

    handleLanguageDropdownVisibleChange(visible) {
      this.languageDropdownVisible = visible;
    },

    changeLanguage(lang) {
      changeLanguage(lang);
      this.languageDropdownVisible = false;
      this.$message.success({
        message: this.$t("message.success"),
        showClose: true,
      });
    },

    switchLoginType(type) {
      this.isMobileLogin = type === "mobile";
      this.form.username = "";
      this.form.mobile = "";
      this.form.password = "";
      this.form.captcha = "";
      this.fetchCaptcha();
    },

    validateInput(input, messageKey) {
      if (!input.trim()) {
        showDanger(this.$t(messageKey));
        return false;
      }
      return true;
    },

    getUserInfo() {
      Api.user.getUserInfo(({ data }) => {
        if (data.code === 0) {
          this.$store.commit("setUserInfo", data.data);
          goToPage("/home");
        } else {
          showDanger("用户信息获取失败");
        }
      });
    },

    async login() {
      if (this.isMobileLogin) {
        if (!validateMobile(this.form.mobile, this.form.areaCode)) {
          showDanger(this.$t('login.requiredMobile'));
          return;
        }
        this.form.username = this.form.areaCode + this.form.mobile;
      } else {
        if (!this.validateInput(this.form.username, 'login.requiredUsername')) {
          return;
        }
      }

      if (!this.validateInput(this.form.password, 'login.requiredPassword')) {
        return;
      }
      if (!this.validateInput(this.form.captcha, 'login.requiredCaptcha')) {
        return;
      }

      let encryptedPassword;
      try {
        const captchaAndPassword = this.form.captcha + this.form.password;
        encryptedPassword = sm2Encrypt(this.sm2PublicKey, captchaAndPassword);
      } catch (error) {
        console.error("密码加密失败:", error);
        showDanger(this.$t('sm2.encryptionFailed'));
        return;
      }

      const plainUsername = this.form.username;
      this.form.captchaId = this.captchaUuid;

      const loginData = {
        username: plainUsername,
        password: encryptedPassword,
        captchaId: this.form.captchaId
      };

      Api.user.login(
        loginData,
        ({ data }) => {
          showSuccess(this.$t('login.loginSuccess'));
          this.$store.commit("setToken", JSON.stringify(data.data));
          this.getUserInfo();
        },
        (err) => {
          let errorMessage = err.data.msg || "登录失败";
          showDanger(errorMessage);
        }
      );

      setTimeout(() => {
        this.fetchCaptcha();
      }, 1000);
    },

    goToRegister() {
      goToPage("/register");
    },
    goToForgetPassword() {
      goToPage("/retrieve-password");
    }
  },
};
</script>

<style lang="scss" scoped>
@import "@/styles/tokens";

.login-page {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;

  &__container {
    position: relative;
    z-index: 1;
    display: flex;
    width: 100%;
    min-height: 100vh;
  }

  &__visual {
    flex: 0 0 58%;
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 0 80px;
    color: $color-on-primary;
    position: relative;
    overflow: hidden;
    animation: slide-up 600ms ease-out forwards;

    @media (max-width: 1024px) {
      flex: 0 0 45%;
      padding: 0 40px;

      .brand__title,
      .brand__slogan {
        display: none;
      }
    }
  }

  &__form {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: $spacing-xl;
    animation: slide-in-right 500ms ease-out 100ms forwards;
    opacity: 0;
  }

  &__footer {
    position: absolute;
    bottom: 24px;
    left: 0;
    right: 0;
    z-index: 2;
    display: flex;
    justify-content: center;
  }
}

.brand {
  display: flex;
  align-items: center;
  gap: $spacing-md;
  margin-bottom: $spacing-xl;

  &__logo {
    width: 42px;
    height: 42px;
    border-radius: 10px;
  }

  &__name {
    font-size: 24px;
    font-weight: 700;
  }

  &__title {
    font: $font-display-lg;
    margin-bottom: $spacing-md;
    max-width: 520px;
  }

  &__slogan {
    font: $font-body-md;
    opacity: 0.9;
    max-width: 480px;
    line-height: 1.6;
  }
}

.floating-blobs {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: -1;

  &__item {
    position: absolute;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.35);
    filter: blur(40px);
    animation: blob-pulse 12s ease-in-out infinite;

    &:nth-child(1) {
      width: 260px;
      height: 260px;
      top: 15%;
      right: 15%;
      animation-delay: -2s;
    }

    &:nth-child(2) {
      width: 180px;
      height: 180px;
      bottom: 20%;
      left: 10%;
      animation-delay: -5s;
    }

    &:nth-child(3) {
      width: 220px;
      height: 220px;
      bottom: 30%;
      right: 25%;
      animation-delay: -8s;
    }
  }
}

.login-card {
  width: 100%;
  max-width: 420px;
  padding: $spacing-xxl;
  box-sizing: border-box;

  &__header {
    display: flex;
    align-items: center;
    gap: $spacing-md;
    margin-bottom: $spacing-xl;
    position: relative;
  }

  &__icon {
    width: 40px;
    height: 40px;
  }

  &__titles {
    flex: 1;
  }

  &__title {
    font: $font-heading-sm;
    color: $color-ink-deep;
    margin: 0;
  }

  &__subtitle {
    font: $font-body-sm;
    color: $color-steel;
    margin: 4px 0 0;
  }

  &__lang {
    .el-dropdown-link {
      display: flex;
      align-items: center;
      gap: 4px;
      color: $color-steel;
      font-size: 14px;
      cursor: pointer;
    }
  }
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: $spacing-md;

  .input-box {
    display: flex;
    align-items: center;
    gap: $spacing-sm;
    height: 48px;
    padding: 0 $spacing-md;
    background: rgba(255, 255, 255, 0.6);
    border: 1px solid $color-hairline;
    border-radius: $rounded-lg;
    transition: border-color 200ms ease, box-shadow 200ms ease;

    &:focus-within {
      border-color: rgba($color-primary, 0.4);
      box-shadow: 0 0 0 3px rgba($color-primary, 0.08);
    }

    ::v-deep .el-input__inner {
      background: transparent;
      border: none;
      padding: 0;
      height: 46px;
      line-height: 46px;
      color: $color-ink-deep;

      &::placeholder {
        color: $color-steel;
      }
    }

    ::v-deep .el-input {
      flex: 1;
    }

    &--mobile {
      gap: $spacing-sm;
      padding: 0 $spacing-sm 0 $spacing-md;

      .area-select {
        width: 130px;
        flex-shrink: 0;

        ::v-deep .el-input__inner {
          padding-left: 0;
        }
      }
    }
  }

  .input-icon {
    width: 20px;
    height: 20px;
    opacity: 0.6;
  }

  .input-row {
    display: flex;
    align-items: center;
    gap: $spacing-md;

    .input-box {
      flex: 1;
    }
  }

  .captcha-img {
    height: 48px;
    border-radius: $rounded-lg;
    cursor: pointer;
    border: 1px solid $color-hairline;
  }
}

.login-actions {
  display: flex;
  justify-content: space-between;
  margin-top: $spacing-md;

  &__link {
    font-size: 14px;
    color: $color-steel;
    cursor: pointer;
    transition: color 150ms ease;

    &:hover {
      color: $color-primary;
    }
  }
}

.login-btn {
  width: 100%;
  height: 48px;
  margin-top: $spacing-xl;
  border-radius: $rounded-full;
  background: $color-ink-button;
  color: $color-on-primary;
  border: none;
  font: $font-body-sm-bold;
  cursor: pointer;
  transition: transform 150ms ease, box-shadow 150ms ease;

  &:hover {
    transform: translateY(-1px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
  }
}

.login-type-container {
  display: flex;
  justify-content: center;
  gap: $spacing-md;
  margin-top: $spacing-lg;
}

.auth-agreement {
  margin-top: $spacing-lg;
  font-size: 12px;
  color: $color-steel;
  text-align: center;
  line-height: 1.5;

  &__link {
    color: $color-primary;
    cursor: pointer;

    &:hover {
      text-decoration: underline;
    }
  }
}

.rotate-down {
  transform: rotate(180deg);
}

@keyframes slide-up {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes slide-in-right {
  from { opacity: 0; transform: translateX(20px); }
  to { opacity: 1; transform: translateX(0); }
}

@keyframes blob-pulse {
  0%, 100% { transform: scale(1) translate(0, 0); opacity: 0.35; }
  50% { transform: scale(1.1) translate(20px, -20px); opacity: 0.5; }
}

@media (prefers-reduced-motion: reduce) {
  .login-page__visual,
  .login-page__form,
  .floating-blobs__item {
    animation: none;
    opacity: 1;
    transform: none;
  }
}
</style>
