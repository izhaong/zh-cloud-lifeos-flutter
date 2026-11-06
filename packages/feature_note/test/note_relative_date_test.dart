import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #658 / TC-NOTE-UI-117：行内编辑日期按 Apple 备忘录的相对日期口径。
///
/// 时钟固定到 2026-11-06（周五）12:00，断言不随运行当天漂移；每档都带反向
/// 对照（整屏日期文案恰好 N 条、无编辑时间的行确实渲染但不给日期），
/// 免得「findsOneWidget」退化成恒真。
///
/// #659 起日期节头也写「今天 / 昨天」，与行内日期同名，所以全部判据按
/// `note_row_date_*` 这把 Key 精确取行内文案，不再用 find.text / 纯文案正则。
void main() {
  final fixedNow = DateTime(2026, 11, 6, 12);
  final dateLike = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('note_row_date_') &&
        RegExp(
          r'^(今天|昨天|星期[一二三四五六日]|\d{1,2}月\d{1,2}日|\d{4}年\d{1,2}月\d{1,2}日)$',
        ).hasMatch(w.data ?? ''),
  );

  String rowDate(WidgetTester tester, String id) {
    final finder = find.byKey(ValueKey('note_row_date_$id'));
    expect(finder, findsOneWidget, reason: '行 $id 必须真的带日期才能读文案');
    return tester.widget<Text>(finder).data ?? '';
  }

  Note dated(String id, DateTime edited) => Note(
    id: id,
    folderId: 'f1',
    title: '标题_$id',
    bodyDelta: '{"ops":[{"insert":"x\\n"}]}',
    clientUpdatedAt: edited.millisecondsSinceEpoch,
  );

  Future<InMemoryNoteRepository> seed(List<Note> notes) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    for (final note in notes) {
      await repo.upsertNote(note);
    }
    return repo;
  }

  Future<void> pump(
    WidgetTester tester,
    NoteRepository repo, {
    DateTime? now,
  }) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1200, 2000)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          noteClockProvider.overrideWithValue(() => now ?? fixedNow),
        ],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-NOTE-UI-117 行内日期按今天/昨天/星期X/M月d日/yyyy年M月d日分档', (tester) async {
    final repo = await seed([
      dated('today', DateTime(2026, 11, 6, 9)),
      dated('yesterday', DateTime(2026, 11, 5, 9)),
      dated('tue', DateTime(2026, 11, 3, 9)), // 3 天前 ⇒ 星期二
      dated('sat', DateTime(2026, 10, 31, 9)), // 6 天前 ⇒ 星期六
      dated('older', DateTime(2026, 10, 30, 9)), // 7 天前 ⇒ 10月30日
      dated('lastyear', DateTime(2025, 12, 1, 9)), // 跨年 ⇒ 2025年12月1日
      const Note(
        id: 'undated',
        folderId: 'f1',
        title: '标题_undated',
        bodyDelta: '{"ops":[{"insert":"z\\n"}]}',
      ),
    ]);
    await pump(tester, repo);

    expect(rowDate(tester, 'today'), '今天');
    expect(rowDate(tester, 'yesterday'), '昨天');
    expect(rowDate(tester, 'tue'), '星期二');
    expect(rowDate(tester, 'sat'), '星期六');
    expect(rowDate(tester, 'older'), '10月30日');
    expect(rowDate(tester, 'lastyear'), '2025年12月1日');
    // 反向对照：整屏恰好 6 条行内日期文案（节头不计入）；无编辑时间那行确实
    // 渲染但不给日期。
    expect(dateLike, findsNWidgets(6));
    expect(find.text('标题_undated'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('note_row_date_undated')),
      findsNothing,
      reason: '无编辑时间不能摆 1970 假日期',
    );
    // 旧口径彻底退场：不能再出现 2026/11/6 这种斜杠绝对日期。
    expect(find.textContaining('2026/11/6'), findsNothing);
  });

  testWidgets('同一条笔记随时钟前移从「今天」变「昨天」，证明文案不是硬编码', (tester) async {
    final repo = await seed([dated('n1', DateTime(2026, 11, 6, 9))]);
    await pump(tester, repo);
    expect(rowDate(tester, 'n1'), '今天');

    await pump(tester, repo, now: DateTime(2026, 11, 7, 12));
    expect(rowDate(tester, 'n1'), '昨天');
    expect(find.byKey(const ValueKey('note_group_today')), findsNothing);
  });

  testWidgets('未来编辑时间不误写成今天/昨天，按绝对日期兜底', (tester) async {
    final repo = await seed([dated('future', DateTime(2027, 1, 3, 9))]);
    await pump(tester, repo);

    expect(rowDate(tester, 'future'), '2027年1月3日');
    // 未来时间既不进「今天」也不进「昨天」（#659 归「更早」桶）。
    expect(find.byKey(const ValueKey('note_group_today')), findsNothing);
    expect(find.byKey(const ValueKey('note_group_yesterday')), findsNothing);
    expect(find.byKey(const ValueKey('note_group_earlier')), findsOneWidget);
  });
}
