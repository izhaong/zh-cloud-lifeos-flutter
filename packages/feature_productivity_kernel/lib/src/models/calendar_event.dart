import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 日程状态（iCal STATUS；契约 §2.2）。
enum EventStatus {
  confirmed,
  tentative,
  cancelled;

  String get id => switch (this) {
        EventStatus.confirmed => 'CONFIRMED',
        EventStatus.tentative => 'TENTATIVE',
        EventStatus.cancelled => 'CANCELLED',
      };

  static EventStatus? fromId(String? id) {
    if (id == null) return null;
    for (final s in EventStatus.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// 忙闲（Apple「显示为」；iCal TRANSP；契约 §2.2）。
enum EventAvailability {
  busy,
  free;

  String get id => switch (this) {
        EventAvailability.busy => 'BUSY',
        EventAvailability.free => 'FREE',
      };

  static EventAvailability? fromId(String? id) {
    if (id == null) return null;
    for (final a in EventAvailability.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// 受邀者角色（契约 §2.4 `role`）。
enum InviteeRole {
  required,
  optional;

  String get id => switch (this) {
        InviteeRole.required => 'REQUIRED',
        InviteeRole.optional => 'OPTIONAL',
      };

  static InviteeRole? fromId(String? id) {
    if (id == null) return null;
    for (final r in InviteeRole.values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// 受邀者回复状态（iCal PARTSTAT；契约 §2.4）。
enum PartStat {
  needsAction,
  accepted,
  declined,
  tentative;

  String get id => switch (this) {
        PartStat.needsAction => 'NEEDS_ACTION',
        PartStat.accepted => 'ACCEPTED',
        PartStat.declined => 'DECLINED',
        PartStat.tentative => 'TENTATIVE',
      };

  static PartStat? fromId(String? id) {
    if (id == null) return null;
    for (final p in PartStat.values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// 提醒（契约 §2.3；类型只保留 NOTIFICATION，Email/Open file/Time to Leave 剥离）。
@immutable
final class EventAlert extends Equatable {
  const EventAlert({
    this.offsetMinutes,
    this.allDayOffsetDays,
    this.allDayTime,
  });

  /// 定时事件：相对开始的分钟，`0`=当时、`-5`=提前 5 分钟、`-1440`=1 天前…
  final int? offsetMinutes;

  /// 全天事件：`0`(当天)/`1`(前一天)/`2`/`7`。
  final int? allDayOffsetDays;

  /// 全天事件提醒的本地时刻 `HH:mm`（默认 09:00）。
  final String? allDayTime;

  @override
  List<Object?> get props => [offsetMinutes, allDayOffsetDays, allDayTime];
}

/// 受邀者（平台 member；契约 §2.4 / §5.1）。
@immutable
final class EventInvitee extends Equatable {
  const EventInvitee({
    required this.memberUserId,
    this.displayName,
    this.role = InviteeRole.required,
    this.partstat = PartStat.needsAction,
    this.comment,
    this.proposedStartAt,
    this.proposedEndAt,
    this.invitedAt,
  });

  final String memberUserId;
  final String? displayName;
  final InviteeRole role;
  final PartStat partstat;

  /// 回复备注（仅组织者可见，C-108）。
  final String? comment;

  /// 提议新时间（C-106；null = 未提议）。
  final DateTime? proposedStartAt;
  final DateTime? proposedEndAt;

  /// 发送邀请时间；null = 已添加未发送。
  final DateTime? invitedAt;

  @override
  List<Object?> get props => [
        memberUserId,
        displayName,
        role,
        partstat,
        comment,
        proposedStartAt,
        proposedEndAt,
        invitedAt,
      ];
}

/// 日程（单次或重复主记录；例外实例见 [parentEventId]，契约 §2.2 / §5.1）。
@immutable
final class CalendarEvent extends Equatable {
  const CalendarEvent({
    required this.id,
    this.remoteId,
    required this.calendarId,
    required this.uid,
    required this.title,
    this.location,
    this.url,
    this.notes,
    required this.startAt,
    required this.endAt,
    this.allDay = false,
    required this.timeZone,
    this.isFloating = false,
    this.rrule,
    this.exdates = const [],
    this.parentEventId,
    this.originalStartAt,
    this.status = EventStatus.confirmed,
    this.availability = EventAvailability.busy,
    this.travelMinutes,
    this.isPrivate = false,
    this.alerts = const [],
    this.invitees = const [],
    this.sequence = 0,
    this.revision = 1,
    this.deletedAt,
    required this.updatedAt,
  });

  /// 本地 UUID（服务端 id 存 [remoteId]）。
  final String id;

  final String? remoteId;

  /// 所属日历（本地日历 id）。
  final String calendarId;

  /// iCal UID（导入保留，新建用 UUID 字符串；同一重复系列共享）。
  final String uid;
  final String title;

  /// 纯文本地点（无地图匹配，C-072 降级）。
  final String? location;

  /// 网址（FaceTime 降级：放任意会议链接）。
  final String? url;
  final String? notes;

  /// 开始（UTC）；全天事件存该日 00:00 创建时区对应 UTC。
  final DateTime startAt;

  /// 结束（UTC，排他）；全天事件为次日 00:00（与 iCal DTEND 一致）。
  final DateTime endAt;

  /// 全天。
  final bool allDay;

  /// IANA 时区（如 `Asia/Shanghai`）；全天事件仍记录创建时区。
  final String timeZone;

  /// 浮动时间（切换查看时区时墙上时间不动，C-079 Floating）。
  final bool isFloating;

  /// RFC 5545 RRULE，**不含** `RRULE:` 前缀（如 `FREQ=WEEKLY;BYDAY=MO,WE`）；null = 不重复。
  final String? rrule;

  /// 已删除的单次出现（原始 occurrence 开始 UTC；契约 §2.2 `exdates`）。
  final List<DateTime> exdates;

  /// 非空 = 本行是某重复事件的**例外实例**（改了某一次）。
  final String? parentEventId;

  /// 例外对应的原始 occurrence 开始 UTC。
  final DateTime? originalStartAt;
  final EventStatus status;
  final EventAvailability availability;

  /// 行程时间分钟（契约 §2.3：NULL/5/15/30/60/90/120；Maps 降级为纯提醒）。
  final int? travelMinutes;

  /// 私密（共享日历查看者只见「忙」，C-053）。
  final bool isPrivate;

  /// 提醒列表。
  final List<EventAlert> alerts;

  /// 受邀者列表（组织者视角）。
  final List<EventInvitee> invitees;

  /// iCal SEQUENCE，每次改时间 +1（通知受邀者）。
  final int sequence;
  final int revision;

  /// 软删时间（null = 在用）。
  final DateTime? deletedAt;

  final DateTime updatedAt;

  bool get isRecurring => rrule != null;

  bool get isException => parentEventId != null;

  @override
  List<Object?> get props => [
        id,
        remoteId,
        calendarId,
        uid,
        title,
        location,
        url,
        notes,
        startAt,
        endAt,
        allDay,
        timeZone,
        isFloating,
        rrule,
        exdates,
        parentEventId,
        originalStartAt,
        status,
        availability,
        travelMinutes,
        isPrivate,
        alerts,
        invitees,
        sequence,
        revision,
        deletedAt,
        updatedAt,
      ];
}
