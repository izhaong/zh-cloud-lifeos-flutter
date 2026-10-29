import 'dart:async';

import '../models/note_preference.dart';

/// 记录偏好端口（TC-NOTE-UI-111 的持久半边）。
///
/// 与 [TaskPreferenceRepository] 同口径：未建行时实现层回
/// [NotePreference.defaults] 且**不写库**（GET 不建行）。
abstract interface class NotePreferenceRepository {
  Stream<NotePreference> watchPreference();

  /// 全量覆盖式保存；`revision` 由实现层递增，调用方传值无效。
  Future<void> savePreference(NotePreference preference);
}

/// 内存实现：开源包单独跑 UI 冒烟时的默认（与 Drift 实现同 revision 口径）。
final class InMemoryNotePreferenceRepository
    implements NotePreferenceRepository {
  NotePreference _p = NotePreference.defaults;
  int _revision = 0;
  final _controller = StreamController<NotePreference>.broadcast();

  @override
  Stream<NotePreference> watchPreference() async* {
    yield _p;
    yield* _controller.stream;
  }

  @override
  Future<void> savePreference(NotePreference preference) async {
    _revision += 1;
    _p = preference.copyWith(revision: _revision);
    _controller.add(_p);
  }
}
