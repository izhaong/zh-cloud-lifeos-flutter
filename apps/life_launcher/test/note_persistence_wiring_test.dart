import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #280 的**防回退**守卫。
///
/// 该 P0 长期存在的原因有两条：组合根接了内存实现，且台账里没有「重启后仍在」
/// 的用例。前者由 `drift_note_repository_test` 的「重开库仍可读」守住，后者由
/// docs 的 TC-NOTE-UI-116 守住；这里再加一条最直接的：**组合根源码里不许再
/// 出现 InMemory 记录仓库**。
void main() {
  test('组合根不再用 InMemoryNoteRepository（记录必须走 Drift 持久化）', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(
      main.contains('InMemoryNoteRepository'),
      isFalse,
      reason: '记录仓库必须由 DriftNoteRepository 承载；换回内存实现＝重启即丢',
    );
    expect(
      main.contains('DriftNoteRepository'),
      isTrue,
      reason: '组合根应显式装配 Drift 记录仓库',
    );
  });
}
