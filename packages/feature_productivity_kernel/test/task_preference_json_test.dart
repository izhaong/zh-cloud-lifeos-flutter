import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// #577：设置辅助窗口用全量 JSON 快照跨 engine 传偏好。
/// 字段一漏，窗口里就会「改了又弹回」或把默认值写回主窗口。
void main() {
  test('TaskPreference JSON 往返不丢字段', () {
    const preference = TaskPreference(
      defaultListId: 'list.work',
      allDayNotify: false,
      markComplete: true,
      suggestLists: false,
      badgeIncludesTodayDue: false,
      allDayRemindersOverdue: true,
      todayNotifyTime: '08:30',
      manualTimeZone: 'Asia/Shanghai',
      showCompleted: true,
      sortMode: 'dueDate',
      sidebarVisible: false,
      collapsedKeys: ['list.work|采购', 'group:今天'],
      viewOptionsJson: '{"groupByTime":true}',
      revision: 7,
    );

    final back = TaskPreference.fromJson(preference.toJson());

    expect(back, preference);
  });

  test('缺键按契约默认（旧窗口/最小载荷）', () {
    final back = TaskPreference.fromJson(const <String, Object?>{});

    expect(back, TaskPreference.defaults);
  });
}
