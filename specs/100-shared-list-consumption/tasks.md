# 100 任务清单

- [x] T-01 kernel：`TaskSharedItem` 只读视图模型 + `TaskCollabPort.sharedListTasks()`
  + `taskShareRoleLabel()`（与 `ListShareSheet` 共用角色中文）
- [x] T-02 feature_task_cloud：`RestTaskCollabPort.sharedListTasks()`
  接 `/app-api/lifeos/task/task/page`，epoch 毫秒与 ISO 两种日期都要能落；
  信封 `code != 0` 抛错不折空表
- [x] T-03 feature_task：`mySharedListsProvider` / `sharedListTasksProvider`
  / `sharedListByIdProvider`（反向探针挂这条）
- [x] T-04 侧栏「与我共享」一节：`sidebar_shared_<listId>` + 角色副标题；
  端口 null/抛错 ⇒ 整节不显示；`onSelectSharedList` 未注入 ⇒ 不画死行
- [x] T-05 `SharedListPane` 只读内容区：`shared_view_<listId>` /
  `shared_item_<id>` / `shared_readonly_badge`；零可写入口
- [x] T-06 scaffold：`_TwoPane` 与 `_ThreePane` 的 `current == null` 分支
  改走 `_SharedOrEmptyPane`（共享 ⇒ 只读视图，否则维持空态）
- [x] T-07 用例：`shared_list_sidebar_test.dart` 6 条 +
  `rest_task_collab_port_test.dart` 2 条；反向探针对撞验证过（摘掉过滤 ⇒ `+5 -1`）
- [x] T-08 门禁：`flutter analyze --fatal-infos` 与全量 `flutter test`
  （12 个含 test 的包，1135 条）绿
- [ ] T-09 后置（另立卡）：共享清单的**写侧**直连通道——「可编辑」角色当前
  在本视图里也只能看不能写；接写必须绕开 outbox，属新协议面，不在本卡偷渡
