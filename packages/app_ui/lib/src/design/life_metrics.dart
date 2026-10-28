/// 圆角与间距档位（Epic #126 / A2）。
///
/// 取值**就是**改造前散落在各包的裸数字（`BorderRadius.circular(8|10|12)` 等），
/// 所以迁移本身不改变任何像素；目的是把「同一档位」收敛成一个名字，后续要整体
/// 调圆角时只动这里。
///
/// 只放**实际有调用点**的档位——没有使用者的常量不进这里（不加没要求的抽象）。
abstract final class LifeRadius {
  /// 徽标/小色块（原 `circular(4)`）。
  static const double xs = 4;

  /// 图标块/小卡（原 `circular(6)`）。
  static const double sm = 6;

  /// 列表行、输入框（原 `circular(8)`，出现最多）。
  static const double md = 8;

  /// 卡片（原 `circular(10)`）。
  static const double lg = 10;

  /// 浮层/大卡（原 `circular(12)`）。
  static const double xl = 12;
}
