import 'package:cupertino_ui/cupertino_ui.dart';

/// 日视图右侧提醒栏（契约 §5.4；Key `day_reminder_lane`）。
///
/// Scheduled Reminders 投影随 F-15 填充；本卡只保证槽位 Key 存在。
class DayReminderLane extends StatelessWidget {
  const DayReminderLane({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(key: Key('day_reminder_lane'));
  }
}
