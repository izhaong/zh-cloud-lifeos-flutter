import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;

import 'life_tokens.dart';

/// Material 岛：只允许 kalender / flutter_quill 等第三方内核进入。
class LifeMaterialIsland extends StatelessWidget {
  const LifeMaterialIsland({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 岛内的 Material 色是静态值，按当前 Cupertino 档位解算，
    // 否则暗色下根主题变暗而岛仍是亮色。
    final brightness = CupertinoTheme.maybeBrightnessOf(context) ?? Brightness.light;
    return Theme(
      data: LifeTokens.materialIsland(brightness),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
