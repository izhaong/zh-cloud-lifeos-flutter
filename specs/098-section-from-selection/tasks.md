# 098 · tasks

- [x] T-1 kernel：`ReminderRepository.createSectionWithTasks`（抽象 + InMemory，空集抛错、跨列表抛错）
- [x] T-2 drift：单事务实现（先验归属后写，回滚可被裸表读量到）
- [x] T-3 UI：长按进入选择态 + 勾选靶（`select_<id>`）+ ⋯ 菜单「用所选项目新建分区」置灰与派发
- [x] T-4 弹层：`showNewSectionDialog(taskIds:)` 走一次原子写，不退化成 N 次写
- [x] T-5 shell：`LifeMenuAction.createSectionFromSelection` + ⌃⌘N 菜单项
- [x] T-6 判据：`section_from_selection_test.dart`（TC-KR-122）/ `..._drift_test.dart` / `..._ui_test.dart`（TC-UI-321）
- [x] T-7 反向探针：先写后验、不置灰、退化成多次写 ⇒ 三处各自当场判红
