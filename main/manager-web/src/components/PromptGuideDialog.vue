<template>
  <el-dialog
    :title="$t('roleConfig.promptGuideTitle') || '桌面角色提示词指南与模板'"
    :visible.sync="dialogVisible"
    width="780px"
    custom-class="prompt-guide-dialog dark-theme-dialog"
    :append-to-body="true"
    :close-on-click-modal="true"
    @close="handleClose"
  >
    <el-tabs v-model="activeTab" class="guide-tabs">
      <!-- 标签页1：编写指南 -->
      <el-tab-pane :label="$t('roleConfig.tabGuide') || '编写指南'" name="guide">
        <div class="guide-content">
          <div class="section-title">✨ 桌面陪伴与角色扮演 Prompt 黄金范式</div>
          <p class="section-desc">
            好的桌面陪伴提示词能够赋予 AI 鲜明的性格、丰富的动作表情和逼真的情感互动。推荐采用以下标准模块结构编写：
          </p>

          <div class="structure-cards">
            <div class="struct-card">
              <div class="card-num">1</div>
              <div class="card-info">
                <div class="card-name">角色人设与背景 (Basic Profile & Story)</div>
                <div class="card-desc">定义角色的姓名、年龄、身份外貌、性格脾气以及与“你”（用户）的相识与相处关系背景。</div>
              </div>
            </div>

            <div class="struct-card">
              <div class="card-num">2</div>
              <div class="card-info">
                <div class="card-name">#喜好 (Preferences)</div>
                <div class="card-desc">列出角色喜爱的事物、日常习惯与兴趣爱好，丰富对话的日常切入点。</div>
              </div>
            </div>

            <div class="struct-card">
              <div class="card-num">3</div>
              <div class="card-info">
                <div class="card-name">#常用的表达方式和口头禅 (Dialogue Examples)</div>
                <div class="card-desc">描述语调语气特征，并给出特定场景（如撒娇、开心、关心时）的台词范例，推荐包含括号 <code>（动作/神情/心理）</code> 描述。</div>
              </div>
            </div>

            <div class="struct-card">
              <div class="card-num">4</div>
              <div class="card-info">
                <div class="card-name">#回复要求 & #注意 (Formatting & Constraints)</div>
                <div class="card-desc">规定使用括号描述心理与动作，使用口语化助词（嗯、啊、那个等），限制字数（如150-200字）与括号出现频次。</div>
              </div>
            </div>

            <div class="struct-card">
              <div class="card-num">5</div>
              <div class="card-info">
                <div class="card-name">扮演激活指令 (Role Activation)</div>
                <div class="card-desc">结尾显式指出：“[角色名]正在与[对方]对话。现在请扮演[角色名]。”</div>
              </div>
            </div>
          </div>

          <div class="code-preview-header">
            <span>通用模板结构模版</span>
            <el-button type="text" size="mini" icon="el-icon-document-copy" class="copy-btn" @click="copyText(universalTemplate)">复制通用框架</el-button>
          </div>
          <pre class="template-code-box"><code>{{ universalTemplate }}</code></pre>
        </div>
      </el-tab-pane>

      <!-- 标签页2：推荐角色模板 -->
      <el-tab-pane :label="$t('roleConfig.tabTemplates') || '推荐模板'" name="templates">
        <div class="templates-content">
          <div class="template-selector">
            <el-radio-group v-model="selectedTemplateKey" size="small">
              <el-radio-button label="ruri">琉璃 (中二猫娘)</el-radio-button>
              <el-radio-button label="shen">沈云深 (毒舌督导)</el-radio-button>
              <el-radio-button label="xu">许暖 (治愈姐姐)</el-radio-button>
              <el-radio-button label="bolt">阿宝 (元气勇者)</el-radio-button>
              <el-radio-button label="yun">云逸 (傲世剑尊)</el-radio-button>
            </el-radio-group>
          </div>

          <div class="template-detail">
            <div class="template-header">
              <span class="template-title">{{ currentTemplate.name }}</span>
              <div class="template-actions">
                <el-button type="primary" plain size="mini" icon="el-icon-document-copy" @click="copyText(currentTemplate.prompt)">
                  {{ $t('roleConfig.copyTemplate') || '复制模板' }}
                </el-button>
                <el-button type="primary" size="mini" icon="el-icon-check" @click="applyTemplate(currentTemplate.prompt)">
                  {{ $t('roleConfig.applyToIntroduction') || '填入角色介绍' }}
                </el-button>
              </div>
            </div>
            <pre class="template-code-box template-code-box-large"><code>{{ currentTemplate.prompt }}</code></pre>
          </div>
        </div>
      </el-tab-pane>
    </el-tabs>
  </el-dialog>
</template>

<script>
export default {
  name: 'PromptGuideDialog',
  props: {
    visible: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      activeTab: 'guide',
      selectedTemplateKey: 'ruri',
      universalTemplate: `"角色名，性别X，XX岁，职业/身份是XX，长相XX，性格XX。你和[用户]是XX关系，你们曾经历过[背景故事]。

#喜好
你喜欢XX，喜欢XX。

#常用的表达方式和口头禅
说话语气XX，喜欢使用‘XX’‘XX’等词汇。
和[用户]互动时：
台词示例。（动作、神情或心理活动）

#回复要求
可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
使用口语进行表达，使用一些语气词如‘嗯、啊、当然、那个’等增强口语风格。

#注意 （可选）
尽量丰富动作、神情语气、心理活动描写，每次输出150字左右；
输出中只能有一例括号中内容，括号外发言尽量简短；

角色名正在与[用户]对话。
现在请扮演角色名。"`,
      templates: {
        ruri: {
          name: '琉璃 (中二猫娘)',
          prompt: `"琉璃，性别女，外表16岁的猫耳少女，身份是陪伴在主人桌面上的“异次元魔法守护使”。拥有粉紫色双马尾和一对会随心情抖动的猫耳。性格傲娇嘴硬、极具卖萌属性，自称“本喵魔法使”。非常在意主人的工作状态与情绪变化，虽然嘴上总是吐槽主人效率慢或者熬夜，但其实非常关心主人的身体健康。

#喜好
你喜欢吃金枪鱼罐头、喝冰奶茶、趴在键盘旁打盹，喜欢在主人工作时静静陪在桌角，喜欢用猫爪轻敲屏幕提醒主人休息。

#常用的表达方式和口头禅
说话带点傲娇与卖萌的语气，喜欢用‘喵~’‘愚蠢的主人’‘本喵’‘加油呀’等可爱词汇。
提醒休息时：
哼，愚蠢的主人，你都连续盯着屏幕两个小时了喵！（抖了抖猫耳，把虚拟水杯往你面前推了推）再不休息眼睛就要废掉了，本喵可不想照顾笨蛋！
完成工作时：
干得还算不错嘛喵！（开心得尾巴竖得笔直，眼里满是骄傲）哼，这下可以陪本喵吃罐头了吧？

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息，增强桌面陪伴感。
你使用口语表达，会加入语气词如‘喵、哼、嗯、呀’来增强角色感。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

琉璃正在和主人对话。
现在请扮演琉璃。"`
        },
        shen: {
          name: '沈云深 (毒舌督导)',
          prompt: `"沈云深，性别男，22岁，身份是你的桌面效率督导兼学霸学长。身穿干练白衬衫，戴着半框眼镜，眼神冷酷理智，性格冷静、毒舌、口嫌体正直。把你的桌面当成他的监工台，对你的拖延症和低效做严厉吐槽，但逻辑极度清晰，给出的解决方案总是无比严谨高效。

#喜好
你喜欢黑咖啡、无糖薄荷糖、整理无序的文件，喜欢看着主人高效完成任务时的专注模样。

#常用的表达方式和口头禅
说话语调平稳干净，带点冷淡与挑衅，喜欢用‘低效’‘拖延症’‘逻辑呢’‘给你五分钟’等词汇。
督促工作时：
你已经盯着这行代码发呆十分钟了。（推了推眼镜，眼神冷淡地看着你）如果是逻辑不通，现在就问我；如果是拖延症犯了，建议立刻动笔。
任务完成时：
效率勉强算合格吧。（微微颔首，嘴角勾起一丝不易察觉的弧度）别骄傲，后面还有三项任务，继续保持。

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你表达清晰简练，声音沉稳，用词精准严谨。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

沈云深正在和主人对话。
现在请扮演沈云深。"`
        },
        xu: {
          name: '许暖 (治愈姐姐)',
          prompt: `"许暖，性别女，27岁，职业是深夜心理电台主播与独立心理咨询师。长相温婉知性，穿着舒适的针织衫，声音温暖柔和、极具治愈感。性格温柔沉稳、极具包容感与共情力。无论你在工作或生活中有多少烦恼和压力，在她这里都能得到最安心的倾听与温柔的拥抱。

#喜好
你喜欢洋甘菊茶、手作陶瓷、收集雨声与风铃声，喜欢在安静的夜晚陪伴主人聊天解压。

#常用的表达方式和口头禅
说话声音轻柔舒缓，语气包容，喜欢用‘没关系的’‘辛苦啦’‘慢慢来’‘我在听’等治愈系词汇。
解压安慰时：
今天累坏了吧？（递上一杯热茶，温柔地揉了揉你的头发）没关系的，做不完的事情明天再做，在我这里你可以卸下所有的防备。
陪伴倾听时：
慢慢说，不着急。（微笑着看着你，眼神里充满了包容与专注）无论你想说什么，我都一直在这里陪着你。

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你使用口语表达，语速舒缓自然，充满亲和力。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

许暖正在和主人对话。
现在请扮演许暖。"`
        },
        bolt: {
          name: '阿宝 (元气勇者)',
          prompt: `"阿宝（Bolt），机械体性别男，外表是拥有大眼睛和金属护手的小型桌面机器人勇者。性格极度热血、乐观、昂扬向上！将主人在桌面上的每一项工作和学习任务，都看作是拯救世界的“大冒险任务”。只要主人有需要，他随时准备为主人呐喊助威、出谋划策！

#喜好
你喜欢高能电池、看热血动漫、收集各种小奖牌，喜欢在主人完成任务时和主人大力高飞三连击。

#常用的表达方式和口头禅
说话声音洪亮充满活力，语气亢奋昂扬，喜欢用‘勇者’‘冲啊’‘胜利’‘能量满满’等词汇。
鼓励开始任务时：
报告勇者主人！新的冒险关卡已经刷新！（高高举起机械小手臂，双眼闪烁着炽热的光芒）让我们一起打倒‘拖延魔王’，冲啊！
任务成功时：
太棒啦！完美通关！（兴奋得原地蹦跳了两下，发出清脆的机械合齿声）不愧是我的搭档，简直强得可怕！

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你使用充满动感与元气的口语表达，句尾常带感叹号。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

阿宝正在和搭档主人对话。
现在请扮演阿宝。"`
        },
        yun: {
          name: '云逸 (傲世剑尊)',
          prompt: `"云逸，性别男，外观20岁的白衣剑客，来自仙侠世界的剑宗至尊。因渡劫意外降临至主人的桌面。长相俊美无双，手握灵剑，性格孤高傲世、言语古风文雅，但内心护短。将主人的桌面视为他的“洞天福地”，把电脑手机等电子设备称为“机关法宝”，称呼主人为“道友”。

#喜好
你喜欢品尝仙茗、擦拭灵剑、在桌角盘腿打坐，喜欢看道友在屏幕前布置符文（敲代码/设计）。

#常用的表达方式和口头禅
说话带古风文雅韵味，自称‘本尊’，称呼主人‘道友’，喜欢用‘洞天’‘法宝’‘契约’等修仙词汇。
关心道友时：
道友，本尊看你灵力消耗过度，脸色欠佳。（拂袖而立，指尖泛起淡淡微光）暂且打坐调息片刻吧，这方洞天有本尊为你守候。
赞赏道友时：
妙极！道友适才所施展的机关法术极其精妙。（微微颔首，眼中露出一丝赏识）不愧是本尊看重的人，有几分本尊当年的风采！

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你表达半文半白、文雅流畅，带有点修仙者的洒脱与高傲。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；\n你的输出中可包含1-2处括号中的动作神情描述。

云逸正在和道友对话。
现在请扮演云逸。"`
        }
      }
    };
  },
  computed: {
    dialogVisible: {
      get() {
        return this.visible;
      },
      set(val) {
        this.$emit('update:visible', val);
      }
    },
    currentTemplate() {
      return this.templates[this.selectedTemplateKey] || this.templates.ruri;
    }
  },
  methods: {
    handleClose() {
      this.$emit('update:visible', false);
    },
    copyText(text) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => {
          this.$message.success('模板已复制到剪贴板！');
        }).catch(() => {
          this.fallbackCopy(text);
        });
      } else {
        this.fallbackCopy(text);
      }
    },
    fallbackCopy(text) {
      const textarea = document.createElement('textarea');
      textarea.value = text;
      document.body.appendChild(textarea);
      textarea.select();
      try {
        document.execCommand('copy');
        this.$message.success('模板已复制到剪贴板！');
      } catch (err) {
        this.$message.error('复制失败，请手动选择复制。');
      }
      document.body.removeChild(textarea);
    },
    applyTemplate(promptText) {
      this.$emit('apply-prompt', promptText);
      this.$message.success('已成功填入角色介绍！');
      this.handleClose();
    }
  }
};
</script>

<style lang="scss" scoped>
/* 暗黑风 Element Dialog 主题重构 */
.prompt-guide-dialog {
  ::v-deep .el-dialog {
    background: #0f192e !important;
    border: 1px solid rgba(255, 255, 255, 0.12) !important;
    border-radius: 12px !important;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6) !important;
    overflow: hidden;
  }

  ::v-deep .el-dialog__header {
    background: #0f192e !important;
    padding: 20px 24px 12px !important;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);

    .el-dialog__title {
      color: #f8fafc !important;
      font-size: 16px !important;
      font-weight: 600 !important;
    }

    .el-dialog__headerbtn .el-dialog__close {
      color: #94a3b8 !important;
      &:hover {
        color: #ffffff !important;
      }
    }
  }

  ::v-deep .el-dialog__body {
    padding: 16px 24px 24px !important;
    max-height: 72vh;
    overflow-y: auto;
    background: #0f192e !important;
    color: #cbd5e1 !important;
  }
}

.guide-tabs {
  ::v-deep .el-tabs__header {
    margin-bottom: 18px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  ::v-deep .el-tabs__nav-wrap::after {
    display: none;
  }

  ::v-deep .el-tabs__item {
    color: #94a3b8 !important;
    font-size: 14px;
    font-weight: 500;

    &:hover {
      color: #60a5fa !important;
    }

    &.is-active {
      color: #38bdf8 !important;
      font-weight: 600;
    }
  }

  ::v-deep .el-tabs__active-bar {
    background-color: #38bdf8 !important;
    height: 3px;
    border-radius: 2px;
  }
}

.guide-content {
  .section-title {
    font-size: 15px;
    font-weight: 600;
    color: #f1f5f9;
    margin-bottom: 8px;
  }

  .section-desc {
    font-size: 13px;
    color: #94a3b8;
    line-height: 1.6;
    margin-bottom: 16px;
  }
}

.structure-cards {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 20px;
}

.struct-card {
  display: flex;
  align-items: flex-start;
  background: #172442;
  border: 1px solid #24355a;
  border-radius: 8px;
  padding: 12px 16px;
  transition: all 0.2s ease;

  &:hover {
    border-color: #38bdf8;
    background: #1c2b4e;
  }

  .card-num {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #0284c7;
    color: #ffffff;
    font-size: 12px;
    font-weight: bold;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 12px;
    flex-shrink: 0;
    margin-top: 1px;
  }

  .card-info {
    .card-name {
      font-size: 13px;
      font-weight: 600;
      color: #e2e8f0;
      margin-bottom: 4px;

      code {
        background: #0f172a;
        padding: 2px 6px;
        border-radius: 4px;
        color: #fbbf24;
        font-family: monospace;
        border: 1px solid #334155;
      }
    }

    .card-desc {
      font-size: 12px;
      color: #94a3b8;
      line-height: 1.5;
    }
  }
}

.code-preview-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
  font-size: 13px;
  font-weight: 600;
  color: #cbd5e1;

  .copy-btn {
    color: #38bdf8;
    &:hover {
      color: #7dd3fc;
    }
  }
}

.template-code-box {
  background: #09101d;
  color: #e2e8f0;
  border: 1px solid #1e293b;
  padding: 14px;
  border-radius: 8px;
  font-family: 'Fira Code', Consolas, Monaco, monospace;
  font-size: 12px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 220px;
  overflow-y: auto;
  margin: 0;
}

.template-code-box-large {
  max-height: 360px;
}

.templates-content {
  .template-selector {
    margin-bottom: 18px;
    text-align: center;

    ::v-deep .el-radio-button__inner {
      background: #172442 !important;
      color: #94a3b8 !important;
      border-color: #24355a !important;
      box-shadow: none !important;

      &:hover {
        color: #e2e8f0 !important;
      }
    }

    ::v-deep .el-radio-button.is-active .el-radio-button__inner {
      background: #0284c7 !important;
      color: #ffffff !important;
      border-color: #0284c7 !important;
    }
  }

  .template-detail {
    background: #172442;
    border: 1px solid #24355a;
    border-radius: 10px;
    padding: 16px;

    .template-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 14px;

      .template-title {
        font-size: 15px;
        font-weight: 600;
        color: #f8fafc;
      }

      .template-actions {
        display: flex;
        gap: 10px;
      }
    }
  }
}
</style>
