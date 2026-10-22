import 'package:flutter_test/flutter_test.dart';
import 'package:life_link/life_link.dart';

void main() {
  test('parses lifeos deep link', () {
    final parsed = LifeLinkUri.tryParse(
      Uri.parse('lifeos://task/open?id=42'),
    );
    expect(parsed, isNotNull);
    expect(parsed!.capability.id, 'task.open');
    expect(parsed.resourceId, '42');
  });
}
