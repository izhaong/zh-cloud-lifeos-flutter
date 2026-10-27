import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Theme;

import 'life_tokens.dart';

/// Material 岛：只允许 kalender / flutter_quill 等第三方内核进入。
class LifeMaterialIsland extends StatelessWidget {
  const LifeMaterialIsland({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: LifeTokens.materialIsland(),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
