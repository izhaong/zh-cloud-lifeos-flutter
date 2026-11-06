import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #660：搜索结果列表高亮匹配词（矩阵 N-高亮面）。
///
/// 三件事各自有反证：① 命中段确实带底色（不是「只是换成 Text.rich」）；
/// ② 大小写不同也能命中（标题 `Milk` vs 摘要 `milk`）；
/// ③ 清空搜索词后回普通 [Text]——golden 基线逐字节不变的前提。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('splitNoteMatches', () {
    test('大小写不敏感切分，命中段标 hit', () {
      expect(splitNoteMatches('Buy Milk today', 'milk'), [
        (text: 'Buy ', hit: false),
        (text: 'Milk', hit: true),
        (text: ' today', hit: false),
      ]);
    });

    test('多处命中逐段切开', () {
      expect(splitNoteMatches('aXbXc', 'x'), [
        (text: 'a', hit: false),
        (text: 'X', hit: true),
        (text: 'b', hit: false),
        (text: 'X', hit: true),
        (text: 'c', hit: false),
      ]);
    });

    test('空查询、纯空白、未命中都不切', () {
      expect(splitNoteMatches('购物清单', ''), isNull);
      expect(splitNoteMatches('购物清单', '   '), isNull);
      expect(splitNoteMatches('购物清单', '面包'), isNull);
      expect(splitNoteMatches('', '购物'), isNull);
    });
  });

  Future<InMemoryNoteRepository> seed() async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: 'Buy Milk',
        bodyDelta: '{"ops":[{"insert":"milk 与面包\\n"}]}',
      ),
    );
    return repo;
  }

  Future<void> pump(WidgetTester tester, NoteRepository repo) async {
    // 560 宽 < 600 断点：单栏列表，不挂编辑栏，屏上文案只有列表自己那两处。
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(560, 1200)
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

  /// 屏上（或 [within] 内）唯一含 [needle] 的 [Text]。
  /// 先量「恰有一处」，否则拿到的可能是旁侧文案，断言就成了恒真。
  Text onlyText(WidgetTester tester, String needle, {Finder? within}) {
    final found = tester
        .widgetList<Text>(
          within == null
              ? find.byType(Text)
              : find.descendant(of: within, matching: find.byType(Text)),
        )
        .where(
          (t) => (t.data ?? t.textSpan?.toPlainText() ?? '').contains(needle),
        )
        .toList();
    expect(found.length, 1, reason: '含「$needle」的文案应恰有一处，实际 ${found.length} 处');
    return found.single;
  }

  /// 高亮片段（Text.rich 的子段）；普通 Text 没有子段，返回空。
  List<InlineSpan> spansOf(Text text) {
    final span = text.textSpan;
    if (span is! TextSpan) return const <InlineSpan>[];
    return span.children ?? const <InlineSpan>[];
  }

  /// 带底色的片段文案（即高亮命中的部分）。
  List<String> hits(Text text) => [
    for (final s in spansOf(text))
      if (s.style?.backgroundColor != null) s.toPlainText(),
  ];

  Future<void> search(WidgetTester tester, String value) async {
    await tester.enterText(
      find.byKey(const ValueKey('note_search_field')),
      value,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('列表行：标题与摘要各自高亮命中词，清空后回普通文本', (tester) async {
    final repo = await seed();
    await pump(tester, repo);

    // 反向对照（搜索态之前）：无搜索词时两处都是普通 Text。
    expect(onlyText(tester, 'Milk').textSpan, isNull);
    expect(onlyText(tester, 'milk').textSpan, isNull);

    await search(tester, 'Milk');

    expect(
      onlyText(tester, 'Milk').textSpan,
      isNotNull,
      reason: '标题命中改走 Text.rich',
    );
    expect(hits(onlyText(tester, 'Milk')), ['Milk'], reason: '标题里被加底色的是「Milk」');
    // 摘要里是小写 milk：搜索靠标题命中，高亮仍按大小写不敏感把 milk 标出来。
    expect(hits(onlyText(tester, 'milk')), [
      'milk',
    ], reason: '摘要中的小写 milk 同样高亮 ⇒ 大小写不敏感');
    final body = onlyText(tester, 'milk');
    expect(body.data, isNull, reason: '高亮走 textSpan，不再填 data');
    expect(body.textSpan!.style?.fontSize, 13, reason: '摘要基础字号仍挂在父段：命中段不吞掉原样式');

    await search(tester, '');
    expect(
      onlyText(tester, 'Milk').textSpan,
      isNull,
      reason: '清空搜索词 ⇒ 回普通 Text，golden 基线不受影响',
    );
    expect(onlyText(tester, 'milk').textSpan, isNull);
  });

  testWidgets('画廊卡片：标题与摘要同样高亮', (tester) async {
    final repo = await seed();
    await pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('note_view_toggle')));
    await tester.pumpAndSettle();
    final grid = find.byKey(const ValueKey('note_gallery_grid'));
    expect(grid, findsOneWidget, reason: '先证明画廊卡片真的渲染了');

    await search(tester, 'Milk');

    expect(hits(onlyText(tester, 'Milk', within: grid)), ['Milk']);
    expect(hits(onlyText(tester, 'milk', within: grid)), ['milk']);
  });
}
