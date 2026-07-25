<template>
  <div class="welcome">
    <div class="operation-bar">
      <h2 class="page-title">{{ $t("modelConfig." + activeTab) }}</h2>
      <div class="action-group">
        <div class="search-group">
          <el-input
            :placeholder="$t('modelConfig.searchPlaceholder')"
            v-model="search"
            class="search-input"
            clearable
            @keyup.enter.native="handleSearch"
            style="width: 240px"
          />
          <el-button class="btn-search" @click="handleSearch">
            {{ $t("modelConfig.search") }}
          </el-button>
        </div>
      </div>
    </div>

    <!-- 主体内容 -->
    <div class="main-wrapper">
      <div class="content-panel">
        <!-- 左侧导航 -->
        <el-menu
          :default-active="activeTab"
          class="nav-panel"
          @select="handleMenuSelect"
        >
          <el-menu-item index="intent">
            <span class="menu-text">{{ $t("modelConfig.intent") }}</span>
          </el-menu-item>
          <el-menu-item index="vad">
            <span class="menu-text">{{ $t("modelConfig.vad") }}</span>
          </el-menu-item>
          <el-menu-item index="asr">
            <span class="menu-text">{{ $t("modelConfig.asr") }}</span>
          </el-menu-item>
          <el-menu-item index="llm">
            <span class="menu-text">{{ $t("modelConfig.llm") }}</span>
          </el-menu-item>
          <el-menu-item index="tts">
            <span class="menu-text">{{ $t("modelConfig.tts") }}</span>
          </el-menu-item>
          <el-menu-item index="memory">
            <span class="menu-text">{{ $t("modelConfig.memory") }}</span>
          </el-menu-item>
          <el-menu-item index="rag">
            <span class="menu-text">{{ $t("modelConfig.rag") }}</span>
          </el-menu-item>
        </el-menu>

        <!-- 右侧内容 -->
        <div class="content-area">
          <el-card class="model-card" shadow="never">
            <el-table
              ref="modelTable"
              style="width: 100%"
              v-loading="loading"
              :element-loading-text="$t('modelConfig.loading')"
              element-loading-spinner="el-icon-loading"
              element-loading-background="rgba(5, 14, 27, 0.82)"
              :header-cell-style="{ background: 'transparent' }"
              :data="modelList"
              class="transparent-table"
              header-row-class-name="table-header"
              :header-cell-class-name="headerCellClassName"
              @selection-change="handleSelectionChange"
            >
              <el-table-column
                type="selection"
                width="55"
                align="center"
                :cell-class-name="selectionCellClassName"
              ></el-table-column>
              <el-table-column
                :label="$t('modelConfig.modelId')"
                prop="id"
                align="center"
              ></el-table-column>
              <el-table-column
                :label="$t('modelConfig.modelName')"
                prop="modelName"
                align="center"
              ></el-table-column>
              <el-table-column :label="$t('modelConfig.provider')" align="center">
                <template slot-scope="scope">
                  {{ scope.row.configJson.type || $t("modelConfig.unknown") }}
                </template>
              </el-table-column>
              <el-table-column :label="$t('modelConfig.isEnabled')" align="center">
                <template slot-scope="scope">
                  <el-tooltip
                    v-if="scope.row.isDefault === 1 && scope.row.isEnabled === 1"
                    :content="$t('modelConfig.defaultModelCannotDisable')"
                    placement="top"
                    effect="light"
                  > 
                    <el-switch
                      v-model="scope.row.isEnabled"
                      active-color="#267dff"
                      inactive-color="#DCDFE6"
                      :active-value="1"
                      :inactive-value="0"
                      disabled
                      @change="handleStatusChange(scope.row)"
                    />
                  </el-tooltip>
                  <el-switch
                    v-else
                    v-model="scope.row.isEnabled"
                    active-color="#267dff"
                    inactive-color="#DCDFE6"
                    :active-value="1"
                    :inactive-value="0"
                    @change="handleStatusChange(scope.row)"
                  />
                </template>
              </el-table-column>
              <el-table-column :label="$t('modelConfig.isDefault')" align="center">
                <template slot-scope="scope">
                  <el-switch
                    v-model="scope.row.isDefault"
                    active-color="#267dff"
                    inactive-color="#DCDFE6"
                    :active-value="1"
                    :inactive-value="0"
                    @change="handleDefaultChange(scope.row)"
                  />
                </template>
              </el-table-column>
              <el-table-column
                v-if="activeTab === 'tts'"
                :label="$t('modelConfig.voiceManagement')"
                align="center"
              >
                <template slot-scope="scope">
                  <el-button
                    type="text"
                    size="mini"
                    @click="openTtsDialog(scope.row)"
                    class="voice-management-btn"
                  >
                    {{ $t("modelConfig.voiceManagement") }}
                  </el-button>
                </template>
              </el-table-column>
              <el-table-column
                :label="$t('modelConfig.action')"
                align="center"
                width="210px"
              >
                <template slot-scope="scope">
                  <el-button
                    type="text"
                    size="mini"
                    @click="editModel(scope.row)"
                    class="edit-btn"
                  >
                    {{ $t("modelConfig.edit") }}
                  </el-button>
                  <el-button
                    type="text"
                    size="mini"
                    @click="duplicateModel(scope.row)"
                    class="edit-btn"
                  >
                    {{ $t("modelConfig.duplicate") }}
                  </el-button>
                  <el-button
                    type="text"
                    size="mini"
                    @click="deleteModel(scope.row)"
                    class="delete-btn"
                  >
                    {{ $t("modelConfig.delete") }}
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
            <div class="table-footer">
              <div class="batch-actions">
                <CustomButton :icon="isAllSelected ? 'el-icon-circle-close' : 'el-icon-circle-check'" type="default" size="small" @click="selectAll">
                  {{
                    isAllSelected
                      ? $t("modelConfig.deselectAll")
                      : $t("modelConfig.selectAll")
                  }}
                </CustomButton>
                <CustomButton icon="el-icon-plus" type="add" size="small" @click="addModel">
                  {{ $t("modelConfig.add") }}
                </CustomButton>
                <CustomButton
                  type="delete"
                  size="small"
                  icon="el-icon-delete"
                  @click="batchDelete"
                >
                  {{ $t("modelConfig.delete") }}
                </CustomButton>
              </div>
              <CustomPagination
                :total="total"
                :current-page="currentPage"
                :page-size="pageSize"
                :page-size-options="pageSizeOptions"
                @size-change="handlePageSizeChange"
                @page-change="handlePageChange"
              />
            </div>
          </el-card>
        </div>
      </div>

      <ModelEditDialog
        :modelType="activeTab"
        :visible.sync="editDialogVisible"
        :modelData="editModelData"
        @save="handleModelSave"
      />
      <TtsModel
        :visible.sync="ttsDialogVisible"
        :ttsModelId="selectedTtsModelId"
        :modelConfig="selectedModelConfig"
      />
      <AddModelDialog
        :modelType="activeTab"
        :visible.sync="addDialogVisible"
        @confirm="handleAddConfirm"
      />
    </div>
    <el-footer>
      <version-footer />
    </el-footer>
  </div>
</template>

<script>
import Api from "@/apis/api";
import AddModelDialog from "@/components/AddModelDialog.vue";
import ModelEditDialog from "@/components/ModelEditDialog.vue";
import TtsModel from "@/components/TtsModel.vue";
import CustomPagination from "@/components/CustomPagination.vue";
import CustomButton from "@/components/CustomButton.vue";
import VersionFooter from "@/components/VersionFooter.vue";
export default {
  components: { ModelEditDialog, TtsModel, AddModelDialog, VersionFooter, CustomPagination, CustomButton },
  data() {
    return {
      addDialogVisible: false,
      activeTab: "intent",
      search: "",
      editDialogVisible: false,
      editModelData: {},
      ttsDialogVisible: false,
      selectedTtsModelId: "",
      modelList: [],
      pageSizeOptions: [10, 20, 50, 100],
      currentPage: 1,
      pageSize: 10,
      total: 0,
      selectedModels: [],
      isAllSelected: false,
      loading: false,
      selectedModelConfig: {},
    };
  },

  created() {
    this.loadData();
  },

  mounted() {
    // 在组件挂载后确保表头翻译文本正确显示
    setTimeout(() => {
      this.updateSelectionHeaderText();
    }, 100);
  },

  updated() {
    // 在组件更新后重新设置表头翻译文本
    this.updateSelectionHeaderText();
  },

  computed: {
    modelTypeText() {
      return (
        this.$t("modelConfig." + this.activeTab) || this.$t("modelConfig.modelConfig")
      );
    },
  },

  methods: {
    // 更新选择列表头翻译文本
    updateSelectionHeaderText() {
      const thElement = document.querySelector(`.el-table__header th:nth-child(1) .cell`);
      if (thElement) {
        thElement.setAttribute("data-content", this.$t("modelConfig.select"));
      }
    },
    handlePageSizeChange(val) {
      this.pageSize = val;
      this.currentPage = 1;
      this.loadData();
    },
    openTtsDialog(row) {
      this.selectedTtsModelId = row.id;
      this.selectedModelConfig = row;
      this.ttsDialogVisible = true;
    },
    headerCellClassName({ column, columnIndex }) {
      if (columnIndex === 0) {
        return "custom-selection-header";
      }
      return "";
    },
    selectionCellClassName({ row, column, rowIndex, columnIndex }) {
      // 只对表头行设置data-content
      if (rowIndex === undefined) {
        // 使用setTimeout确保DOM已经渲染完成
        setTimeout(() => {
          const thElement = document.querySelector(
            `.el-table__header th:nth-child(1) .cell`
          );
          if (thElement) {
            thElement.setAttribute("data-content", this.$t("modelConfig.select"));
          }
        }, 0);
      }
      return "";
    },
    handleMenuSelect(index) {
      this.activeTab = index;
      this.currentPage = 1; // 重置到第一页
      this.pageSize = 10; // 可选：重置每页条数
      this.loadData();
    },
    handleSearch() {
      this.currentPage = 1;
      this.loadData();
    },
    // 批量删除
    batchDelete() {
      if (this.selectedModels.length === 0) {
        this.$message.warning(this.$t("modelConfig.selectModelsFirst"));
        return;
      }

      this.$confirm(this.$t("modelConfig.confirmBatchDelete"), this.$t("message.info"), {
        confirmButtonText: this.$t("common.confirm"),
        cancelButtonText: this.$t("common.cancel"),
        type: "warning",
      })
        .then(() => {
          const deletePromises = this.selectedModels.map(
            (model) =>
              new Promise((resolve) => {
                Api.model.deleteModel(model.id, ({ data }) => resolve(data.code === 0));
              })
          );

          Promise.all(deletePromises).then((results) => {
            if (results.every(Boolean)) {
              this.$message.success({
                message: this.$t("modelConfig.batchDeleteSuccess"),
                showClose: true,
              });
              this.loadData();
            } else {
              this.$message.error({
                message: this.$t("modelConfig.partialDeleteFailed"),
                showClose: true,
              });
            }
          });
        })
        .catch(() => {
          this.$message.info(this.$t("modelConfig.deleteCancelled"));
        });
    },
    addModel() {
      this.addDialogVisible = true;
    },
    editModel(model) {
      this.editModelData = JSON.parse(JSON.stringify(model));
      this.editDialogVisible = true;
    },
    duplicateModel(model) {
      this.editModelData = JSON.parse(JSON.stringify(model));
      this.editModelData.duplicateMode = true;
      this.editDialogVisible = true;
    },
    // 删除单个模型
    deleteModel(model) {
      this.$confirm(this.$t("modelConfig.confirmDelete"), this.$t("message.info"), {
        confirmButtonText: this.$t("common.confirm"),
        cancelButtonText: this.$t("common.cancel"),
        type: "warning",
      })
        .then(() => {
          Api.model.deleteModel(model.id, ({ data }) => {
            if (data.code === 0) {
              this.$message.success({
                message: this.$t("modelConfig.deleteSuccess"),
                showClose: true,
              });
              this.loadData();
            } else {
              this.$message.error({
                message: data.msg || this.$t("modelConfig.deleteFailed"),
                showClose: true,
              });
            }
          });
        })
        .catch(() => {
          this.$message.info(this.$t("modelConfig.deleteCancelled"));
        });
    },
    handlePageChange(page) {
      this.currentPage = page;
      this.loadData();
    },
    handleModelSave({ provideCode, formData, done }) {
      const modelType = this.activeTab;
      const id = formData.id;

      if (this.editModelData.duplicateMode) {
        formData.id = "";
        Api.model.addModel({ modelType, provideCode, formData }, ({ data }) => {
          if (data.code === 0) {
            this.$message.success(this.$t("modelConfig.duplicateSuccess"));
            this.loadData();
            this.editDialogVisible = false;
          } else {
            this.$message.error(data.msg || this.$t("modelConfig.duplicateFailed"));
          }
          done && done(); // 调用done回调关闭加载状态
        });
      } else {
        Api.model.updateModel({ modelType, provideCode, id, formData }, ({ data }) => {
          if (data.code === 0) {
            this.$message.success(this.$t("modelConfig.saveSuccess"));
            this.loadData();
            this.editDialogVisible = false;
          } else {
            this.$message.error(data.msg || this.$t("modelConfig.saveFailed"));
          }
          done && done(); // 调用done回调关闭加载状态
        });
      }
    },
    selectAll() {
      if (this.isAllSelected) {
        this.$refs.modelTable.clearSelection();
      } else {
        this.$refs.modelTable.toggleAllSelection();
      }
    },
    handleSelectionChange(val) {
      this.selectedModels = val;
      this.isAllSelected = val.length === this.modelList.length;
      if (val.length === 0) {
        this.isAllSelected = false;
      }
    },

    // 新增模型配置
    handleAddConfirm(newModel) {
      const params = {
        modelType: this.activeTab,
        provideCode: newModel.provideCode,
        formData: {
          ...newModel,
          isDefault: newModel.isDefault ? 1 : 0,
          isEnabled: newModel.isEnabled ? 1 : 0,
          configJson: newModel.configJson,
        },
      };

      Api.model.addModel(params, ({ data }) => {
        if (data.code === 0) {
          this.$message.success({
            message: this.$t("modelConfig.addSuccess"),
            showClose: true,
          });
          this.loadData();
        } else {
          this.$message.error({
            message: data.msg || this.$t("modelConfig.addFailed"),
            showClose: true,
          });
        }
      });
    },

    // 获取模型配置列表
    loadData() {
      this.loading = true; // 开始加载
      const params = {
        modelType: this.activeTab,
        modelName: this.search,
        page: this.currentPage,
        limit: this.pageSize,
      };

      Api.model.getModelList(params, ({ data }) => {
        this.loading = false; // 结束加载
        if (data.code === 0) {
          const list = data.data.list || [];
          list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
          this.modelList = list;
          this.total = data.data.total;
        } else {
          this.$message.error(data.msg || this.$t("modelConfig.fetchModelsFailed"));
        }
      });
    },
    // 处理启用/禁用状态变更
    handleStatusChange(model) {
      const newStatus = model.isEnabled ? 1 : 0;
      const originalStatus = model.isEnabled;

      model.isEnabled = !model.isEnabled;

      Api.model.updateModelStatus(model.id, newStatus, ({ data }) => {
        if (data.code === 0) {
          this.$message.success(
            newStatus === 1
              ? this.$t("modelConfig.enableSuccess")
              : this.$t("modelConfig.disableSuccess")
          );
          // 保持新状态
          model.isEnabled = newStatus;
          // 刷新表格数据
          this.loadData();
        } else {
          // 操作失败时恢复原状态
          model.isEnabled = originalStatus;
          this.$message.error(data.msg || this.$t("modelConfig.operationFailed"));
        }
      });
    },
    handleDefaultChange(model) {
      Api.model.setDefaultModel(model.id, ({ data }) => {
        if (data.code === 0) {
          this.$message.success(this.$t("modelConfig.setDefaultSuccess"));
          this.loadData();
        }
      });
    },
  },
};
</script>

<style lang="scss" scoped>
.el-switch {
  height: 23px;
}

::v-deep .el-table tr {
  background: transparent;
}

.welcome {
  min-width: 900px;
  min-height: 506px;
  min-height: calc(100vh - 48px);
  display: flex;
  position: relative;
  flex-direction: column;
  background-size: cover;
  background: transparent;
  -webkit-background-size: cover;
  -o-background-size: cover;
}

.main-wrapper {
  // 顶部 63px 底部 35px 查询72px
  height: calc(100vh - 48px - 35px - 72px);
  margin: 0 22px;
  border-radius: 15px;
  position: relative;
}

.operation-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
}

.page-title {
  font-size: 24px;
  margin: 0;
}

.content-panel {
  flex: 1;
  display: flex;
  overflow: hidden;
  height: 100%;
  border-radius: 15px;
  background: transparent;
}

.nav-panel {
  min-width: 176px;
  height: 100%;
  border-right: 1px solid rgba(96, 132, 187, .16);
  background: rgba(5, 14, 28, .76);
  padding: 14px 10px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
}

.nav-panel .el-menu-item {
  height: 50px;
  background: transparent;
  line-height: 50px;
  border-radius: 8px !important;
  transition: all 0.3s;
  display: flex !important;
  justify-content: flex-start;
  padding: 0 14px !important;
  width: 100%;
  margin: 0 0 6px;
}

.nav-panel .el-menu-item.is-active {
  background: rgba(39, 140, 255, .16);
  position: relative;
  padding-left: 14px !important;
  box-shadow: inset 2px 0 #31b7ff;
}

.menu-text {
  font-size: 14px;
  color: #8190a9;
  text-align: left;
  width: 100%;
}

.content-area {
  flex: 1;
  padding: 24px 24px 0;
  height: 100%;
  min-width: 600px;
  overflow: hidden;
  background-color: rgba(5, 14, 28, .78);
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
}

.action-group {
  display: flex;
  align-items: center;
  gap: 16px;
}

.search-group {
  display: flex;
  gap: 10px;
}

.search-input {
  width: 240px;
}

.btn-search {
  background: linear-gradient(135deg, #267dff, #4f5cff);
  border: none;
  color: white;
}

.btn-search:hover {
  opacity: 0.9;
  transform: translateY(-1px);
}

::v-deep .search-input .el-input__inner {
  border-radius: 8px;
  border: 1px solid rgba(104, 139, 190, .28);
  background: rgba(7, 17, 32, .9);
  color: #e7effd;
  transition: border-color 0.2s, box-shadow 0.2s;
}

::v-deep .search-input .el-input__inner::placeholder {
  color: #65738b;
}

::v-deep .search-input .el-input__inner:focus {
  border-color: #267dff;
  box-shadow: 0 0 0 3px rgba(38, 125, 255, .12);
  outline: none;
}

// .data-table {
//   border-radius: 6px;
//   overflow: hidden;
//   background-color: transparent !important;
// }

// .data-table ::v-deep .el-table__row {
//   background-color: transparent !important;
// }

.table-header th {
  background-color: transparent !important;
  color: #606266;
  font-weight: 600;
}

.table-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  // padding: 16px 0;
  width: 100%;
  flex-shrink: 0;
  min-height: 60px;
  background: rgba(7, 17, 32, .94);
  border-top: 1px solid rgba(96, 132, 187, .16);
}

// .batch-actions {
//   display: flex;
//   gap: 8px;
// }

// .batch-actions .el-button {
//   min-width: 72px;
//   height: 32px;
//   padding: 7px 12px 7px 10px;
//   font-size: 12px;
//   border-radius: 4px;
//   line-height: 1;
//   font-weight: 500;
//   border: none;
//   transition: all 0.3s ease;
//   box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
// }

// .batch-actions .el-button:hover {
//   transform: translateY(-1px);
//   box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
// }

// .batch-actions .el-button--primary {
//   background: #267dff !important;
//   color: white;
// }

// .batch-actions .el-button--success {
//   background: #17b890;
//   color: white;
// }

// .batch-actions .el-button--danger {
//   background: #fd5b63;
//   color: white;
// }

// .batch-actions .el-button:first-child {
//   background: linear-gradient(135deg, #267dff, #267dff);
//   border: none;
//   color: white;
// }

// .batch-actions .el-button:first-child:hover {
//   background: linear-gradient(135deg, #3a8ee6, #5a7cff);
// }

.el-table th ::v-deep .el-table__cell {
  overflow: hidden;
  -webkit-user-select: none;
  -moz-user-select: none;
  user-select: none;
  background-color: transparent !important;
}

::v-deep .el-table .custom-selection-header .cell .el-checkbox__inner {
  display: none !important;
}

::v-deep .el-table .custom-selection-header .cell::before {
  content: attr(data-content);
  display: block;
  text-align: center;
  line-height: 32px;
  /* 设置合适的行高，确保文本完整显示 */
  color: #dbe8fb;
  margin-top: 0;
  /* 移除可能导致偏移的上边距 */
  height: 32px;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 100%;
}

.custom-selection-header .cell {
  position: relative;
}

/* 已移除可能影响文本显示的空伪元素 */

::v-deep .el-table__body .el-checkbox__inner {
  display: inline-block !important;
  background: #ffffff;
}

::v-deep .el-table thead th:not(:first-child) .cell {
  color: #dbe8fb !important;
}

::v-deep .nav-panel .el-menu-item.is-active .menu-text {
  color: #fff !important;
}


.el-button img {
  height: 1em;
  vertical-align: middle;
  padding-right: 2px;
  padding-bottom: 2px;
}

::v-deep .el-checkbox__inner {
  border-color: #cfcfcf !important;
  transition: all 0.2s ease-in-out;
}

::v-deep .el-checkbox__input.is-checked .el-checkbox__inner {
  background-color: #267dff;
  border-color: #267dff;
}

.voice-management-btn {
  background: rgba(38, 125, 255, .13);
  border: 1px solid rgba(83, 151, 255, .38);
  color: #79aaff;
  min-width: 68px;
  line-height: 14px;
  white-space: nowrap;
  transition: all 0.3s;
  border-radius: 10px;
}

.voice-management-btn:hover {
  background: rgba(38, 125, 255, .2);
  border-color: rgba(83, 151, 255, .58);
  color: #9bc0ff;
  transform: none;
}

::v-deep .el-table .el-table-column--selection .cell {
  padding-left: 15px !important;
}

::v-deep .el-table .el-table__fixed-right .cell {
  padding-right: 15px !important;
}

.edit-btn,
.delete-btn {
  margin: 0 8px;
  color: #5f98ff !important;
}

::v-deep .el-table .cell {
  padding-left: 10px;
  padding-right: 10px;
}

.model-card {
  background: rgba(7, 17, 32, .76);
  flex: 1;
  display: flex;
  flex-direction: column;
  border: none;
  box-shadow: none;
  overflow: hidden;
}

.model-card ::v-deep .el-card__body {
  padding: 0;
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}
:deep(.transparent-table) {
    background: transparent;
    flex: 1;
    width: 100%;
    display: flex;
    flex-direction: column;

    .el-table__body-wrapper {
        flex: 1;
        overflow-y: auto;
        max-height: none !important;
    }

    .el-table__header-wrapper {
        flex-shrink: 0;
    }

    .el-table__header th {
        background: rgba(13, 29, 51, .96) !important;
        color: #dbe8fb;
        font-weight: 600;
        height: 40px;
        padding: 8px 0;
        font-size: 14px;
        border-bottom: 1px solid rgba(96, 132, 187, .2);
    }

    .el-table__body tr {
        background-color: transparent;

        td {
            background: rgba(7, 16, 30, .68);
            border-top: 1px solid rgba(96, 132, 187, .08);
            border-bottom: 1px solid rgba(96, 132, 187, .16);
            padding: 8px 0;
            height: 40px;
            color: #aebed5;
            font-size: 14px;
        }
    }

    .el-table__row:hover>td {
        background-color: rgba(18, 39, 68, .88) !important;
    }

    &::before {
        display: none;
    }
}


::v-deep .el-loading-mask {
  background-color: rgba(5, 14, 27, .82) !important;
  backdrop-filter: blur(2px);
}

::v-deep .el-table__body-wrapper::-webkit-scrollbar {
  width: 7px;
}

::v-deep .el-table__body-wrapper::-webkit-scrollbar-track {
  background: rgba(6, 15, 29, .92);
}

::v-deep .el-table__body-wrapper::-webkit-scrollbar-thumb {
  background: rgba(83, 151, 255, .28);
  border-radius: 999px;
}

::v-deep .el-loading-spinner .circular {
  width: 28px;
  height: 28px;
}

::v-deep .el-loading-spinner .path {
  stroke: #267dff;
}

::v-deep .el-loading-text {
  color: #267dff !important;
  font-size: 14px;
  margin-top: 8px;
}
</style>
