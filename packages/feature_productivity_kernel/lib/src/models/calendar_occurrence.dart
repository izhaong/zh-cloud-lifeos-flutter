import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'calendar_event.dart';

/// occurrence 来源（契约 §5.1；Scheduled Reminders 投影与节假日投影复用同一形状）。
enum OccurrenceSource {
  /// 日程（主记录/例外展开）。
  event,

  /// 提醒事项投影（F-15 Scheduled Reminders）。
  reminder,

  /// 节假日投影。
  holiday;

  String get id => switch (this) {
        OccurrenceSource.event => 'EVENT',
        OccurrenceSource.reminder => 'REMINDER',
        OccurrenceSource.holiday => 'HOLIDAY',
      };

  static OccurrenceSource? fromId(String? id) {
    if (id == null) return null;
    for (final s in OccurrenceSource.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// 出现实例（**不持久化**；由展开纯函数或服务端按时间窗计算，契约 §1/§5.1）。
@immutable
final class CalendarOccurrence extends Equatable {
  const CalendarOccurrence({
    required this.eventId,
    required this.masterEventId,
    required this.calendarId,
    required this.colorArgb,
    required this.title,
    this.location,
    required this.allDay,
    required this.start,
    required this.end,
    required this.isRecurring,
    required this.isException,
    this.status = EventStatus.confirmed,
    this.source = OccurrenceSource.event,
    this.reminderId,
    this.completed = false,
  });

  /// 承载本次的行 id：主记录次 = 主记录 id；例外次 = 例外行 id。
  final String eventId;

  /// 所属重复系列/事件的主记录 id（单次事件 = 自身 id）。
  final String masterEventId;
  final String calendarId;
  final int colorArgb;
  final String title;
  final String? location;
  final bool allDay;

  /// 开始（UTC）。
  final DateTime start;

  /// 结束（UTC，排他）。
  final DateTime end;

  /// 来自重复主记录（含例外次）。
  final bool isRecurring;

  /// 本次是例外行（时间/标题等被单独改过）。
  final bool isException;
  final EventStatus status;
  final OccurrenceSource source;

  /// `source=reminder` 时的提醒条目 id（F-15 投影）。
  final String? reminderId;

  /// `source=reminder` 时是否已完成（UI 灰显；KR-404）。
  final bool completed;

  @override
  List<Object?> get props => [
        eventId,
        masterEventId,
        calendarId,
        colorArgb,
        title,
        location,
        allDay,
        start,
        end,
        isRecurring,
        isException,
        status,
        source,
        reminderId,
        completed,
      ];
}
