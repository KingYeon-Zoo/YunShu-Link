<template>
  <div class="auth-page">
    <DynamicBackground variant="login" aria-hidden="true" />

    <div class="auth-page__container">
      <div class="auth-card" @keyup.enter="login">
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

        <!-- 右侧：登录输入区 -->
        <div class="auth-card__form">
          <div class="form-wrapper">
            <div class="card-header">
              <img loading="lazy" alt="" src="@/assets/login/hi.png" class="card-header__icon" />
              <div class="card-header__titles">
                <h2 class="card-title">{{ $t('login.title') }}</h2>
                <p class="card-subtitle">{{ $t('login.welcomeBack') }}</p>
              </div>
              <el-dropdown trigger="click" class="card-header__lang" @visible-change="handleLanguageDropdownVisibleChange">
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

            <div class="login-form" style="padding: 0;">
              <!-- 手机号/用户名输入框切换 -->
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

              <!-- 密码输入框 -->
              <div class="input-box">
                <img loading="lazy" alt="" class="input-icon" src="@/assets/login/password.png" />
                <el-input v-model="form.password" :placeholder="$t('login.passwordPlaceholder')" type="password"
                  show-password />
              </div>

              <!-- 图形验证码 -->
              <div class="input-row">
                <div class="input-box">
                  <img loading="lazy" alt="" class="input-icon" src="@/assets/login/shield.png" />
                  <el-input v-model="form.captcha" :placeholder="$t('login.captchaPlaceholder')" />
                </div>
                <img loading="lazy" v-if="captchaUrl" :src="captchaUrl" alt="验证码" class="captcha-img"
                  @click="fetchCaptcha" />
              </div>
            </div>

            <div class="form-actions">
              <span class="form-actions__link" @click="goToRegister">{{ $t('login.registerAccount') }}</span>
              <span class="form-actions__link" @click="goToForgetPassword">{{ $t('login.forgetPassword') }}</span>
            </div>

            <button class="submit-btn" @click="login">{{ $t('login.login') }}</button>

            <!-- 登录方式切换图标 -->
            <div class="login-types" v-if="enableMobileRegister">
              <el-tooltip :content="$t('login.mobileLogin')" placement="bottom">
                <el-button :type="isMobileLogin ? 'primary' : 'default'" icon="el-icon-mobile" circle
                  @click="switchLoginType('mobile')"></el-button>
              </el-tooltip>
              <el-tooltip :content="$t('login.usernameLogin')" placement="bottom">
                <el-button :type="!isMobileLogin ? 'primary' : 'default'" icon="el-icon-user" circle
                  @click="switchLoginType('username')"></el-button>
              </el-tooltip>
            </div>

            <div class="agreement-declaration">
              {{ $t('login.agreeTo') }}
              <span class="agreement-declaration__link" @click="openPage('/user-agreement.html')">{{ $t('login.userAgreement') }}</span>
              {{ $t('login.and') }}
              <span class="agreement-declaration__link" @click="openPage('/privacy-policy.html')">{{ $t('login.privacyPolicy') }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Api from "@/apis/api";
import DynamicBackground from "@/components/DynamicBackground.vue";
import VoiceEnergyCore from "@/components/VoiceEnergyCore.vue";
import i18n, { changeLanguage } from "@/i18n";
import { getUUID, goToPage, showDanger, showSuccess, sm2Encrypt, validateMobile } from "@/utils";
import { mapState } from "vuex";

export default {
  name: "login",
  components: {
    DynamicBackground,
    VoiceEnergyCore,
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
@import "./auth-shared";
</style>
