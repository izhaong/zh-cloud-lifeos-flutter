// #410：老「锁定」备忘录（正文是明文）升级后必须能救回来。
//
// 背景：#395 之前「锁定」只写 `locked: true`，正文仍是明文 JSON。升级后
// `NoteLockCodec.open()` 对明文必然抛错——用户**永久打不开自己的备忘录**，
// 而且提示永远是「密码错误」。本卡改走「设置新密码并就地加密」。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _legacyDelta = '{"ops":[{"insert":"旧明文正文\\n"}]}';

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester, InMemoryNoteRepository repo) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('#410 旧锁定备忘录：提示「此前未加密」并可设置密码加密', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(const Note(
      id: 'legacy',
      folderId: 'f1',
      title: '旧日记',
      bodyDelta: _legacyDelta,
      locked: true,
    ));
    await pump(tester, repo);

    await tester.tap(find.text('旧日记'));
    await tester.pumpAndSettle();

    // 走的是迁移对话框，而不是「解锁备忘录」（后者必然失败）
    expect(find.byKey(const ValueKey('note_lock_migration_notice')),
        findsOneWidget);
    expect(find.textContaining('此前只有「锁定」标记'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('note_lock_migration_password')),
      'newpass',
    );
    await tester.tap(find.byKey(const ValueKey('note_lock_migration_confirm')));
    await tester.pumpAndSettle();

    final saved = (await repo.watchNotes().first).single;
    expect(NoteLockCodec.isSealed(saved.bodyDelta), isTrue,
        reason: '迁移后必须是密文');
    expect(saved.bodyDelta.contains('旧明文正文'), isFalse);
    expect(saved.bodyText, isEmpty);
    expect(NoteLockCodec.open(saved.bodyDelta, 'newpass'), _legacyDelta,
        reason: '用新密码要能解回原文（否则内容等于丢了）');
  });

  testWidgets('#410 已加密的备忘录不会被误判成旧数据', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(Note(
      id: 'sealed',
      folderId: 'f1',
      title: '新日记',
      bodyDelta: NoteLockCodec.seal(_legacyDelta, 'old'),
      locked: true,
    ));
    await pump(tester, repo);

    await tester.tap(find.text('新日记'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note_unlock_password')), findsOneWidget,
        reason: '已加密的行应走正常解锁流程');
    expect(find.byKey(const ValueKey('note_lock_migration_notice')),
        findsNothing);

    final untouched = (await repo.watchNotes().first).single;
    expect(untouched.bodyDelta.contains('旧明文正文'), isFalse,
        reason: '打开对话框不应改动数据');
  });

  testWidgets('#410 取消迁移不丢数据、不改变行状态', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(const Note(
      id: 'legacy2',
      folderId: 'f1',
      title: '旧日记二',
      bodyDelta: _legacyDelta,
      locked: true,
    ));
    await pump(tester, repo);

    await tester.tap(find.text('旧日记二'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final row = (await repo.watchNotes().first).single;
    expect(row.bodyDelta, _legacyDelta, reason: '取消不能把明文丢掉');
    expect(row.locked, isTrue);
  });
}
