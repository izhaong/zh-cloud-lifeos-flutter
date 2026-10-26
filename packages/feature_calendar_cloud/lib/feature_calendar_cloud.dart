/// feature_calendar_cloud：日历私有云侧（F-17）。
///
/// - RestCalendarSyncPort（/app-api/lifeos/calendar/sync/pull|push）
/// - CalendarSyncCoordinator（本地 Drift ⇄ 云端；冲突最多 3 次重推）
/// - 收件箱 / 共享 / 导入导出页（经组合根挂到壳）
/// 开源 `feature_calendar` 不 import 本包。
library;

export 'src/collab/rest_calendar_collab_port.dart';
export 'src/sync/calendar_sync_coordinator.dart';
export 'src/sync/calendar_sync_models.dart';
export 'src/sync/rest_calendar_sync_port.dart';
export 'src/ui/calendar_cloud_page.dart';
