import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 日历种类（契约 §2.1 `kind`；对齐 Apple 侧栏分组语义，不绑定任何云端账户）。
enum CalendarKind {
  /// 本地日历（自有，可写）。
  local,

  /// 外部 .ics 订阅（只读，定时刷新）。
  subscription,

  /// 节假日日历（只读，首期地区 CN）。
  holiday,

  /// 他人共享给我的影子日历（写权限见 [CalendarPermission]）。
  shared;

  /// 服务端/本地存储值（契约 §2.1 大写枚举）。
  String get id => switch (this) {
        CalendarKind.local => 'LOCAL',
        CalendarKind.subscription => 'SUBSCRIPTION',
        CalendarKind.holiday => 'HOLIDAY',
        CalendarKind.shared => 'SHARED',
      };

  static CalendarKind? fromId(String? id) {
    if (id == null) return null;
    for (final k in CalendarKind.values) {
      if (k.id == id) return k;
    }
    return null;
  }
}

/// 日历权限（契约 §2.5 `permission`；owner=自有，edit/view=共享获得）。
enum CalendarPermission {
  owner,
  edit,
  view;

  String get id => switch (this) {
        CalendarPermission.owner => 'OWNER',
        CalendarPermission.edit => 'EDIT',
        CalendarPermission.view => 'VIEW',
      };

  static CalendarPermission? fromId(String? id) {
    if (id == null) return null;
    for (final p in CalendarPermission.values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// 日历（Apple 侧栏中的一条；颜色/可见性/默认落点）。
@immutable
final class Calendar extends Equatable {
  const Calendar({
    required this.id,
    this.remoteId,
    required this.title,
    required this.colorArgb,
    this.kind = CalendarKind.local,
    this.groupName,
    this.isVisible = true,
    this.isDefault = false,
    this.sortOrder = 0,
    this.ignoreAlerts = false,
    this.sourceUrl,
    this.refreshMinutes,
    this.holidayRegion,
    this.permission = CalendarPermission.owner,
    this.revision = 1,
    this.deletedAt,
  });

  /// 本地 UUID（服务端 id 存 [remoteId]）。
  final String id;

  final String? remoteId;
  final String title;

  /// 0xFFRRGGBB（契约 §8.1 Apple 预设 7 色）。
  final int colorArgb;
  final CalendarKind kind;

  /// 日历组（Apple 仅 On My Mac 有组；本平台所有本地日历可分组）。
  final String? groupName;

  /// 侧栏勾选（勾掉后主视图不显示该日历日程）。
  final bool isVisible;

  /// 新建日程默认落点；每用户唯一（服务端 §2.1 `is_default`）。
  final bool isDefault;

  /// 侧栏顺序（sortOrder asc）。
  final int sortOrder;

  /// 忽略该日历所有提醒（Apple Ignore alerts）。
  final bool ignoreAlerts;

  /// `kind=subscription` 的 .ics 地址。
  final String? sourceUrl;

  /// 订阅自动刷新间隔分钟（契约 §2.1：NULL(手动)/5/15/60/1440/10080）。
  final int? refreshMinutes;

  /// `kind=holiday` 的地区码（首期 `CN`）。
  final String? holidayRegion;
  final CalendarPermission permission;

  /// 同步乐观锁。
  final int revision;

  /// 软删时间（null = 在用）。
  final DateTime? deletedAt;

  @override
  List<Object?> get props => [
        id,
        remoteId,
        title,
        colorArgb,
        kind,
        groupName,
        isVisible,
        isDefault,
        sortOrder,
        ignoreAlerts,
        sourceUrl,
        refreshMinutes,
        holidayRegion,
        permission,
        revision,
        deletedAt,
      ];
}
