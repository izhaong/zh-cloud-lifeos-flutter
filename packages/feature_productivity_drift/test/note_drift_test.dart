import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:feature_productivity_drift/feature_productivity_drift.dart';

/// F-02（TC-NOTE-KR-101/106 本地半）：note 表 V9 迁移与往返。
void main() {
  test('V8→V9 迁移：note_folders/notes 建表、旧数据保留、可往返', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    // V8 基线 = V1 + D6 + 契约四列 + 分区/分组/类型 + until + 三张日历表
    raw.execute('''
      CREATE TABLE reminder_items (
        id TEXT NOT NULL PRIMARY KEY,
        list_id TEXT NOT NULL,
        title TEXT NOT NULL,
        notes TEXT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_flagged INTEGER NOT NULL DEFAULT 0,
        due_at INTEGER NULL,
        priority INTEGER NOT NULL DEFAULT 0,
        tags TEXT NOT NULL DEFAULT '[]',
        recurrence TEXT NULL,
        parent_id TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT NULL,
        completed_at INTEGER NULL,
        section_id TEXT NULL,
        deleted_at INTEGER NULL,
        recurrence_until INTEGER NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE reminder_lists (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        color_argb INTEGER NOT NULL DEFAULT 4280327039,
        is_smart INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        sections_json TEXT NULL,
        group_name TEXT NULL,
        list_type TEXT NULL,
        smart_filter TEXT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE calendars (
        id TEXT NOT NULL PRIMARY KEY,
        remote_id TEXT NULL,
        title TEXT NOT NULL,
        color_argb INTEGER NOT NULL,
        kind TEXT NOT NULL DEFAULT 'LOCAL',
        group_name TEXT NULL,
        is_visible INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        ignore_alerts INTEGER NOT NULL DEFAULT 0,
        source_url TEXT NULL,
        refresh_minutes INTEGER NULL,
        holiday_region TEXT NULL,
        permission TEXT NOT NULL DEFAULT 'OWNER',
        revision INTEGER NOT NULL DEFAULT 1,
        deleted_at INTEGER NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE calendar_events (
        id TEXT NOT NULL PRIMARY KEY,
        remote_id TEXT NULL,
        calendar_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        location TEXT NULL,
        url TEXT NULL,
        notes TEXT NULL,
        start_at INTEGER NOT NULL,
        end_at INTEGER NOT NULL,
        all_day INTEGER NOT NULL DEFAULT 0,
        time_zone TEXT NOT NULL,
        is_floating INTEGER NOT NULL DEFAULT 0,
        rrule TEXT NULL,
        exdates_json TEXT NOT NULL DEFAULT '[]',
        parent_event_id TEXT NULL,
        original_start_at INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'CONFIRMED',
        availability TEXT NOT NULL DEFAULT 'BUSY',
        travel_minutes INTEGER NULL,
        is_private INTEGER NOT NULL DEFAULT 0,
        alerts_json TEXT NOT NULL DEFAULT '[]',
        invitees_json TEXT NOT NULL DEFAULT '[]',
        sequence INTEGER NOT NULL DEFAULT 0,
        revision INTEGER NOT NULL DEFAULT 1,
        deleted_at INTEGER NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE calendar_preferences (
        user_key TEXT NOT NULL PRIMARY KEY,
        default_calendar_id TEXT NULL,
        start_week_on INTEGER NOT NULL DEFAULT 1,
        week_view_days INTEGER NOT NULL DEFAULT 7,
        day_start_hour INTEGER NOT NULL DEFAULT 8,
        day_end_hour INTEGER NOT NULL DEFAULT 18,
        hours_shown INTEGER NOT NULL DEFAULT 12,
        show_declined_events INTEGER NOT NULL DEFAULT 0,
        time_zone_support INTEGER NOT NULL DEFAULT 0,
        display_time_zone TEXT NULL,
        default_alert_timed_minutes INTEGER NULL,
        default_alert_all_day_days INTEGER NULL,
        default_alert_all_day_time TEXT NOT NULL DEFAULT '09:00',
        default_duration_minutes INTEGER NOT NULL DEFAULT 60,
        alternate_calendar TEXT NOT NULL DEFAULT 'NONE',
        show_week_numbers INTEGER NOT NULL DEFAULT 0,
        week_view_starts_today INTEGER NOT NULL DEFAULT 0,
        show_holidays INTEGER NOT NULL DEFAULT 1,
        open_events_in_window INTEGER NOT NULL DEFAULT 0,
        revision INTEGER NOT NULL DEFAULT 1
      );
    ''');
    raw.execute(
      'INSERT INTO reminder_items (id, list_id, title, recurrence) '
      "VALUES ('v8row', 'list.x', 'V8 条目', 'daily')",
    );
    raw.execute('PRAGMA user_version = 8');

    final db9 = LifeProductivityDb(NativeDatabase.opened(raw));
    // 旧数据保留
    final v8row = (await db9.select(db9.reminderItems).get())
        .singleWhere((e) => e.id == 'v8row');
    expect(v8row.title, 'V8 条目');

    // V9 新表可写可读（notes 往返）
    await db9.into(db9.noteFolders).insert(NoteFoldersCompanion.insert(
          id: 'f1',
          name: '工作',
        ));
    await db9.into(db9.notes).insert(NotesCompanion.insert(
          id: 'n1',
          folderId: 'f1',
          title: '购物清单',
          bodyDelta: const Value('{"ops":[{"insert":"买牛奶"}]}'),
        ));

    final folderRow =
        (await db9.select(db9.noteFolders).get()).singleWhere((f) => f.id == 'f1');
    expect(folderRow.name, '工作');
    expect(folderRow.smart, isFalse, reason: 'V9 smart 默认 false');

    final noteRow =
        (await db9.select(db9.notes).get()).singleWhere((n) => n.id == 'n1');
    expect(noteRow.title, '购物清单');
    expect(noteRow.pinned, isFalse, reason: 'V9 pinned 默认 false');
    expect(noteRow.locked, isFalse);
    expect(noteRow.checklistTotal, 0, reason: 'V9 清单计数默认 0');
    expect(noteRow.revision, 0);

    expect(db9.schemaVersion, 12);
    await db9.close();
  });

  test('V9 全新建库：note 表随 onCreate 建齐', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('note_folders'), isTrue);
    expect(names.contains('notes'), isTrue);
    await db.close();
  });
}
