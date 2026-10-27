import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_sync_models.dart';

/// 同步会话（null = 未登录；契约 §6 未登录零请求）。
class NoteSyncSessionNotifier extends Notifier<NoteSyncSession?> {
  @override
  NoteSyncSession? build() => null;

  void signIn(NoteSyncSession session) => state = session;

  void signOut() => state = null;
}

final noteSyncSessionProvider =
    NotifierProvider<NoteSyncSessionNotifier, NoteSyncSession?>(
        NoteSyncSessionNotifier.new);
