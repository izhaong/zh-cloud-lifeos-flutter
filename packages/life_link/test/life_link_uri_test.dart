import 'package:flutter_test/flutter_test.dart';
import 'package:life_link/life_link.dart';

void main() {
  group('解析', () {
    test('task/open?id=42 → task.open + resourceId', () {
      final parsed = LifeLinkUri.tryParse(
        Uri.parse('lifeos://task/open?id=42'),
      );
      expect(parsed, isNotNull);
      expect(parsed!.capability.id, 'task.open');
      expect(parsed.resourceId, '42');
      expect(parsed.query['id'], '42');
    });

    test('task/openList/list.personal → task.openList + 路径段资源 id', () {
      final parsed = LifeLinkUri.tryParse(
        Uri.parse('lifeos://task/openList/list.personal'),
      );
      expect(parsed!.capability.id, 'task.openList');
      expect(parsed.resourceId, 'list.personal');
    });

    test('calendar/viewDay?date=2026-10-22 → 透传 query', () {
      final parsed = LifeLinkUri.tryParse(
        Uri.parse('lifeos://calendar/viewDay?date=2026-10-22'),
      );
      expect(parsed!.capability.id, 'calendar.viewDay');
      expect(parsed.query['date'], '2026-10-22');
    });

    test('非 lifeos scheme → null（容错硬约束）', () {
      expect(
        LifeLinkUri.tryParse(Uri.parse('https://task/open')),
        isNull,
      );
      expect(
        LifeLinkUri.tryParse(Uri.parse('lifeos://')),
        isNull,
      );
    });
  });

  group('构造（toUri）', () {
    test('解析→构造往返一致（含 query）', () {
      final original = Uri.parse('lifeos://task/open?id=42');
      final parsed = LifeLinkUri.tryParse(original);
      expect(parsed, isNotNull);
      final rebuilt = parsed!.toUri();
      final reparsed = LifeLinkUri.tryParse(rebuilt)!;
      expect(reparsed.capability.id, 'task.open');
      expect(reparsed.resourceId, '42');
      expect(reparsed.query['id'], '42');
    });

    test('构造 path 段资源 id：openList/list.personal', () {
      const link = LifeLinkUri(
        capability: LifeCapability.openTaskList,
        resourceId: 'list.personal',
      );
      final uri = link.toUri();
      final reparsed = LifeLinkUri.tryParse(uri)!;
      expect(reparsed.capability.id, 'task.openList');
      expect(reparsed.resourceId, 'list.personal');
    });

    test('无资源 id 的能力构造后可解析回同能力', () {
      const link = LifeLinkUri(
        capability: LifeCapability.openTask,
        query: {'id': '42'},
      );
      final reparsed = LifeLinkUri.tryParse(link.toUri())!;
      expect(reparsed.capability.id, 'task.open');
      expect(reparsed.resourceId, '42'); // query id 回填
    });
  });

  group('契约一致性（docs/contracts/life-link.md）', () {
    test('静态能力常量与契约表一致', () {
      expect(LifeCapability.openTask.id, 'task.open');
      expect(LifeCapability.openTaskList.id, 'task.openList');
      expect(LifeCapability.viewCalendarDay.id, 'calendar.viewDay');
    });

    test('第三方域 x- 前缀可正常解析（审核校验属目录职责，非解析器）', () {
      final parsed = LifeLinkUri.tryParse(
        Uri.parse('lifeos://x-vendor-notes/open?doc=1'),
      );
      expect(parsed!.capability.id, 'x-vendor-notes.open');
    });
  });
}
