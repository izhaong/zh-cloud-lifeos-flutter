/// feature_task_cloud：任务 App 私有云侧（F1）。
///
/// - AuthPort 真实现（member 登录 + flutter_secure_storage 会话）
/// - SyncPort 真实现（push-pull 增量同步，冲突按拍板「新者胜」整条覆盖重推）
/// - 仅经组合根注入开源仓；`feature_task` 自身只依赖 kernel 端口
library;

export 'src/auth/login_page.dart';
export 'src/auth/rest_auth_port.dart';
export 'src/auth/secure_session_store.dart';
export 'src/sync/rest_sync_port.dart';
export 'src/sync/sync_models.dart';
export 'src/sync/task_sync_coordinator.dart';
