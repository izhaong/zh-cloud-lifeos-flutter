// #463：Apple「默认文本大小」滑块——设置必须真的作用到正文渲染。
//
// 这条判据的重点是**消费者**：设置页存一个数不算完成，#418/#444 被判掉的
// 正是「存了不消费」的死控件。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements NoteRepository {
  @override
  Stream<List<Note>> watchNotes({String? folderId, String? query}) =>
      Stream.value(const []);

  @override
  Stream<List<NoteFolder>> watchFolders() => Stream.value(const [
        NoteFolder(id: 'f1', name: '笔记'),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpEditor(WidgetTester tester, {required int size}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [noteRepositoryProvider.overrideWithValue(_Repo())],
      child: const CupertinoApp(
        home: NoteEditorPage(note: null, folderId: 'f1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // 通过 notifier 直接设定（设置页的滑块在另一个用例里测）
  final element = tester.element(find.byType(NoteEditorPage));
  ProviderScope.containerOf(element)
      .read(noteSettingsProvider.notifier)
      .setDefaultTextSize(size);
  await tester.pumpAndSettle();
}

double? _paragraphFontSize(WidgetTester tester) {
  final editor = tester.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
  final styles = editor.config.customStyles;
  return styles?.paragraph?.style.fontSize;
}

void main() {
  testWidgets('#463 默认 16 磅：正文段落字号 = 16', (tester) async {
    await _pumpEditor(tester, size: 16);
    // 16 不在五档里 → 索引取最近档（15），但配置直接吃设置值
    expect(_paragraphFontSize(tester), 16.0);
  });

  testWidgets('#463 改成 24 磅：正文段落字号跟着变（真的有消费者）', (tester) async {
    await _pumpEditor(tester, size: 24);
    expect(_paragraphFontSize(tester), 24.0);
  });

  testWidgets('#463 越界值不写库（夹到 13..24）', (tester) async {
    await _pumpEditor(tester, size: 16);
    final element = tester.element(find.byType(NoteEditorPage));
    final notifier =
        ProviderScope.containerOf(element).read(noteSettingsProvider.notifier);

    notifier.setDefaultTextSize(99);
    await tester.pumpAndSettle();
    expect(_paragraphFontSize(tester), 16.0, reason: '越界值应被忽略');

    notifier.setDefaultTextSize(20);
    await tester.pumpAndSettle();
    expect(_paragraphFontSize(tester), 20.0);
  });

  testWidgets('#463 设置页有滑块与当前值展示', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(_Repo())],
        child: const CupertinoApp(home: NoteSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('note_default_text_size_slider')),
      120,
    );
    expect(find.byKey(const ValueKey('note_default_text_size')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('note_default_text_size_slider')),
      findsOneWidget,
    );
  });
}
