/// LifeOS 日历（Apple Calendar 对等；开源包，仅依赖 kernel，无 HTTP）。
library;

export 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

export 'src/calendar_scaffold.dart';
export 'src/calendar_tab_entry.dart';
export 'src/providers.dart';
export 'src/calendar_view_callbacks.dart';
export 'src/logic/lunar_label.dart';
export 'src/logic/event_time.dart';
export 'src/logic/recurrence_ui.dart';
export 'src/logic/alert_triggers.dart';
export 'src/alerts/calendar_alert_scheduler.dart';
export 'src/views/day_view.dart';
export 'src/views/month_view.dart';
export 'src/views/year_view.dart';
export 'src/views/day_reminder_lane.dart';
export 'src/widgets/calendar_sidebar.dart';
export 'src/widgets/event_form_fields.dart';
export 'src/widgets/event_inspector_pane.dart';
export 'src/widgets/calendar_toolbar.dart';
export 'src/widgets/mini_month.dart';
