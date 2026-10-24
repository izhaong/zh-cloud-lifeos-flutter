import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_port.dart';
import 'sync/sync_port.dart';

/// AuthPort 契约 Provider：默认 Noop；真实现（feature_task_cloud.RestAuthPort）
/// 由组合根 overrideWithValue 注入（F1：开源仓只见端口）。
final authPortProvider = Provider<AuthPort>((ref) => const NoopAuthPort());

/// SyncPort 契约 Provider：默认 Noop；真实现同上注入。
final syncPortProvider = Provider<SyncPort>((ref) => const NoopSyncPort());
