# tasks — 099 清单共享的客户端半面

- [x] T1 kernel 抽象 `TaskCollabPort` + `TaskListMember` / `TaskSharedList` / `TaskCollabException`
- [x] T2 `taskCollabPortProvider`（默认 null）
- [x] T3 `RestTaskCollabPort`（八个方法，业务信封不折空）
- [x] T4 `ListShareSheet`（成员表 / 邀请 / 改角色 / 移除 / 接受 / 退出 + 错误态与无编号态）
- [x] T5 「更多」菜单接「共享…」，智能清单不出这一项
- [x] T6 组合根注入（`apps/life_launcher/lib/main.dart`）
- [x] T7 契约测试 `rest_task_collab_port_test.dart`（10 条）
- [x] T8 界面测试 `list_share_sheet_test.dart`（7 条，含「失败≠空态」「无编号不发网络」）
- [ ] T9 侧栏「与我共享」：等服务端放开清单可见性后接（见 spec「明确没做」）
- [ ] T10 docs 矩阵行 25 的 FL 翻格（由 docs 侧随动，不在本卡顺手改）
