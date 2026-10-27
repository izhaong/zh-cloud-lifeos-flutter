import 'package:app_core/app_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Material 岛主色与 Cupertino 主色一致（不回退 M3 灰蓝）', () {
    expect(LifeTokens.cupertino().primaryColor.toARGB32(), 0xFF007AFF);
    expect(LifeTokens.materialIsland().colorScheme.primary.toARGB32(),
        0xFF007AFF);
    expect(LifeTokens.materialIsland().colorScheme.primary.toARGB32(),
        isNot(0xFF445E91));
  });
}
