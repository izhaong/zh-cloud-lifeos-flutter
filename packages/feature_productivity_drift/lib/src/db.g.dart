// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $ReminderListsTable extends ReminderLists
    with TableInfo<$ReminderListsTable, ReminderList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF007AFF),
  );
  static const VerificationMeta _isSmartMeta = const VerificationMeta(
    'isSmart',
  );
  @override
  late final GeneratedColumn<bool> isSmart = GeneratedColumn<bool>(
    'is_smart',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_smart" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, colorArgb, isSmart];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    }
    if (data.containsKey('is_smart')) {
      context.handle(
        _isSmartMeta,
        isSmart.isAcceptableOrUnknown(data['is_smart']!, _isSmartMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
      isSmart: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_smart'],
      )!,
    );
  }

  @override
  $ReminderListsTable createAlias(String alias) {
    return $ReminderListsTable(attachedDatabase, alias);
  }
}

class ReminderList extends DataClass implements Insertable<ReminderList> {
  final String id;
  final String title;
  final int colorArgb;
  final bool isSmart;
  const ReminderList({
    required this.id,
    required this.title,
    required this.colorArgb,
    required this.isSmart,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['color_argb'] = Variable<int>(colorArgb);
    map['is_smart'] = Variable<bool>(isSmart);
    return map;
  }

  ReminderListsCompanion toCompanion(bool nullToAbsent) {
    return ReminderListsCompanion(
      id: Value(id),
      title: Value(title),
      colorArgb: Value(colorArgb),
      isSmart: Value(isSmart),
    );
  }

  factory ReminderList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderList(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      isSmart: serializer.fromJson<bool>(json['isSmart']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'isSmart': serializer.toJson<bool>(isSmart),
    };
  }

  ReminderList copyWith({
    String? id,
    String? title,
    int? colorArgb,
    bool? isSmart,
  }) => ReminderList(
    id: id ?? this.id,
    title: title ?? this.title,
    colorArgb: colorArgb ?? this.colorArgb,
    isSmart: isSmart ?? this.isSmart,
  );
  ReminderList copyWithCompanion(ReminderListsCompanion data) {
    return ReminderList(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      isSmart: data.isSmart.present ? data.isSmart.value : this.isSmart,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderList(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('isSmart: $isSmart')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, colorArgb, isSmart);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderList &&
          other.id == this.id &&
          other.title == this.title &&
          other.colorArgb == this.colorArgb &&
          other.isSmart == this.isSmart);
}

class ReminderListsCompanion extends UpdateCompanion<ReminderList> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> colorArgb;
  final Value<bool> isSmart;
  final Value<int> rowid;
  const ReminderListsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderListsCompanion.insert({
    required String id,
    required String title,
    this.colorArgb = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<ReminderList> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? colorArgb,
    Expression<bool>? isSmart,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (isSmart != null) 'is_smart': isSmart,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderListsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? colorArgb,
    Value<bool>? isSmart,
    Value<int>? rowid,
  }) {
    return ReminderListsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      colorArgb: colorArgb ?? this.colorArgb,
      isSmart: isSmart ?? this.isSmart,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (isSmart.present) {
      map['is_smart'] = Variable<bool>(isSmart.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderListsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('isSmart: $isSmart, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderItemsTable extends ReminderItems
    with TableInfo<$ReminderItemsTable, ReminderItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFlaggedMeta = const VerificationMeta(
    'isFlagged',
  );
  @override
  late final GeneratedColumn<bool> isFlagged = GeneratedColumn<bool>(
    'is_flagged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_flagged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    title,
    notes,
    isCompleted,
    isFlagged,
    dueAt,
    priority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('is_flagged')) {
      context.handle(
        _isFlaggedMeta,
        isFlagged.isAcceptableOrUnknown(data['is_flagged']!, _isFlaggedMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      isFlagged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_flagged'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
    );
  }

  @override
  $ReminderItemsTable createAlias(String alias) {
    return $ReminderItemsTable(attachedDatabase, alias);
  }
}

class ReminderItem extends DataClass implements Insertable<ReminderItem> {
  final String id;
  final String listId;
  final String title;
  final String? notes;
  final bool isCompleted;
  final bool isFlagged;
  final DateTime? dueAt;
  final int priority;
  const ReminderItem({
    required this.id,
    required this.listId,
    required this.title,
    this.notes,
    required this.isCompleted,
    required this.isFlagged,
    this.dueAt,
    required this.priority,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['list_id'] = Variable<String>(listId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    map['is_flagged'] = Variable<bool>(isFlagged);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['priority'] = Variable<int>(priority);
    return map;
  }

  ReminderItemsCompanion toCompanion(bool nullToAbsent) {
    return ReminderItemsCompanion(
      id: Value(id),
      listId: Value(listId),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isCompleted: Value(isCompleted),
      isFlagged: Value(isFlagged),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      priority: Value(priority),
    );
  }

  factory ReminderItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderItem(
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      isFlagged: serializer.fromJson<bool>(json['isFlagged']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      priority: serializer.fromJson<int>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String>(listId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'isFlagged': serializer.toJson<bool>(isFlagged),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'priority': serializer.toJson<int>(priority),
    };
  }

  ReminderItem copyWith({
    String? id,
    String? listId,
    String? title,
    Value<String?> notes = const Value.absent(),
    bool? isCompleted,
    bool? isFlagged,
    Value<DateTime?> dueAt = const Value.absent(),
    int? priority,
  }) => ReminderItem(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    isCompleted: isCompleted ?? this.isCompleted,
    isFlagged: isFlagged ?? this.isFlagged,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    priority: priority ?? this.priority,
  );
  ReminderItem copyWithCompanion(ReminderItemsCompanion data) {
    return ReminderItem(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      isFlagged: data.isFlagged.present ? data.isFlagged.value : this.isFlagged,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderItem(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('isFlagged: $isFlagged, ')
          ..write('dueAt: $dueAt, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listId,
    title,
    notes,
    isCompleted,
    isFlagged,
    dueAt,
    priority,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderItem &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.isCompleted == this.isCompleted &&
          other.isFlagged == this.isFlagged &&
          other.dueAt == this.dueAt &&
          other.priority == this.priority);
}

class ReminderItemsCompanion extends UpdateCompanion<ReminderItem> {
  final Value<String> id;
  final Value<String> listId;
  final Value<String> title;
  final Value<String?> notes;
  final Value<bool> isCompleted;
  final Value<bool> isFlagged;
  final Value<DateTime?> dueAt;
  final Value<int> priority;
  final Value<int> rowid;
  const ReminderItemsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.isFlagged = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderItemsCompanion.insert({
    required String id,
    required String listId,
    required String title,
    this.notes = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.isFlagged = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       listId = Value(listId),
       title = Value(title);
  static Insertable<ReminderItem> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<bool>? isCompleted,
    Expression<bool>? isFlagged,
    Expression<DateTime>? dueAt,
    Expression<int>? priority,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (isFlagged != null) 'is_flagged': isFlagged,
      if (dueAt != null) 'due_at': dueAt,
      if (priority != null) 'priority': priority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? listId,
    Value<String>? title,
    Value<String?>? notes,
    Value<bool>? isCompleted,
    Value<bool>? isFlagged,
    Value<DateTime?>? dueAt,
    Value<int>? priority,
    Value<int>? rowid,
  }) {
    return ReminderItemsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      isFlagged: isFlagged ?? this.isFlagged,
      dueAt: dueAt ?? this.dueAt,
      priority: priority ?? this.priority,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (isFlagged.present) {
      map['is_flagged'] = Variable<bool>(isFlagged.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderItemsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('isFlagged: $isFlagged, ')
          ..write('dueAt: $dueAt, ')
          ..write('priority: $priority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LifeProductivityDb extends GeneratedDatabase {
  _$LifeProductivityDb(QueryExecutor e) : super(e);
  $LifeProductivityDbManager get managers => $LifeProductivityDbManager(this);
  late final $ReminderListsTable reminderLists = $ReminderListsTable(this);
  late final $ReminderItemsTable reminderItems = $ReminderItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    reminderLists,
    reminderItems,
  ];
}

typedef $$ReminderListsTableCreateCompanionBuilder =
    ReminderListsCompanion Function({
      required String id,
      required String title,
      Value<int> colorArgb,
      Value<bool> isSmart,
      Value<int> rowid,
    });
typedef $$ReminderListsTableUpdateCompanionBuilder =
    ReminderListsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> colorArgb,
      Value<bool> isSmart,
      Value<int> rowid,
    });

class $$ReminderListsTableFilterComposer
    extends Composer<_$LifeProductivityDb, $ReminderListsTable> {
  $$ReminderListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSmart => $composableBuilder(
    column: $table.isSmart,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderListsTableOrderingComposer
    extends Composer<_$LifeProductivityDb, $ReminderListsTable> {
  $$ReminderListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSmart => $composableBuilder(
    column: $table.isSmart,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderListsTableAnnotationComposer
    extends Composer<_$LifeProductivityDb, $ReminderListsTable> {
  $$ReminderListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<bool> get isSmart =>
      $composableBuilder(column: $table.isSmart, builder: (column) => column);
}

class $$ReminderListsTableTableManager
    extends
        RootTableManager<
          _$LifeProductivityDb,
          $ReminderListsTable,
          ReminderList,
          $$ReminderListsTableFilterComposer,
          $$ReminderListsTableOrderingComposer,
          $$ReminderListsTableAnnotationComposer,
          $$ReminderListsTableCreateCompanionBuilder,
          $$ReminderListsTableUpdateCompanionBuilder,
          (
            ReminderList,
            BaseReferences<
              _$LifeProductivityDb,
              $ReminderListsTable,
              ReminderList
            >,
          ),
          ReminderList,
          PrefetchHooks Function()
        > {
  $$ReminderListsTableTableManager(
    _$LifeProductivityDb db,
    $ReminderListsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> colorArgb = const Value.absent(),
                Value<bool> isSmart = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderListsCompanion(
                id: id,
                title: title,
                colorArgb: colorArgb,
                isSmart: isSmart,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<int> colorArgb = const Value.absent(),
                Value<bool> isSmart = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderListsCompanion.insert(
                id: id,
                title: title,
                colorArgb: colorArgb,
                isSmart: isSmart,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderListsTable, ReminderList>(table),
                  BaseReferences<
                    _$LifeProductivityDb,
                    $ReminderListsTable,
                    ReminderList
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderListsTableProcessedTableManager =
    ProcessedTableManager<
      _$LifeProductivityDb,
      $ReminderListsTable,
      ReminderList,
      $$ReminderListsTableFilterComposer,
      $$ReminderListsTableOrderingComposer,
      $$ReminderListsTableAnnotationComposer,
      $$ReminderListsTableCreateCompanionBuilder,
      $$ReminderListsTableUpdateCompanionBuilder,
      (
        ReminderList,
        BaseReferences<_$LifeProductivityDb, $ReminderListsTable, ReminderList>,
      ),
      ReminderList,
      PrefetchHooks Function()
    >;
typedef $$ReminderItemsTableCreateCompanionBuilder =
    ReminderItemsCompanion Function({
      required String id,
      required String listId,
      required String title,
      Value<String?> notes,
      Value<bool> isCompleted,
      Value<bool> isFlagged,
      Value<DateTime?> dueAt,
      Value<int> priority,
      Value<int> rowid,
    });
typedef $$ReminderItemsTableUpdateCompanionBuilder =
    ReminderItemsCompanion Function({
      Value<String> id,
      Value<String> listId,
      Value<String> title,
      Value<String?> notes,
      Value<bool> isCompleted,
      Value<bool> isFlagged,
      Value<DateTime?> dueAt,
      Value<int> priority,
      Value<int> rowid,
    });

class $$ReminderItemsTableFilterComposer
    extends Composer<_$LifeProductivityDb, $ReminderItemsTable> {
  $$ReminderItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFlagged => $composableBuilder(
    column: $table.isFlagged,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderItemsTableOrderingComposer
    extends Composer<_$LifeProductivityDb, $ReminderItemsTable> {
  $$ReminderItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFlagged => $composableBuilder(
    column: $table.isFlagged,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderItemsTableAnnotationComposer
    extends Composer<_$LifeProductivityDb, $ReminderItemsTable> {
  $$ReminderItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFlagged =>
      $composableBuilder(column: $table.isFlagged, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);
}

class $$ReminderItemsTableTableManager
    extends
        RootTableManager<
          _$LifeProductivityDb,
          $ReminderItemsTable,
          ReminderItem,
          $$ReminderItemsTableFilterComposer,
          $$ReminderItemsTableOrderingComposer,
          $$ReminderItemsTableAnnotationComposer,
          $$ReminderItemsTableCreateCompanionBuilder,
          $$ReminderItemsTableUpdateCompanionBuilder,
          (
            ReminderItem,
            BaseReferences<
              _$LifeProductivityDb,
              $ReminderItemsTable,
              ReminderItem
            >,
          ),
          ReminderItem,
          PrefetchHooks Function()
        > {
  $$ReminderItemsTableTableManager(
    _$LifeProductivityDb db,
    $ReminderItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<bool> isFlagged = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderItemsCompanion(
                id: id,
                listId: listId,
                title: title,
                notes: notes,
                isCompleted: isCompleted,
                isFlagged: isFlagged,
                dueAt: dueAt,
                priority: priority,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String listId,
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<bool> isFlagged = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderItemsCompanion.insert(
                id: id,
                listId: listId,
                title: title,
                notes: notes,
                isCompleted: isCompleted,
                isFlagged: isFlagged,
                dueAt: dueAt,
                priority: priority,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderItemsTable, ReminderItem>(table),
                  BaseReferences<
                    _$LifeProductivityDb,
                    $ReminderItemsTable,
                    ReminderItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$LifeProductivityDb,
      $ReminderItemsTable,
      ReminderItem,
      $$ReminderItemsTableFilterComposer,
      $$ReminderItemsTableOrderingComposer,
      $$ReminderItemsTableAnnotationComposer,
      $$ReminderItemsTableCreateCompanionBuilder,
      $$ReminderItemsTableUpdateCompanionBuilder,
      (
        ReminderItem,
        BaseReferences<_$LifeProductivityDb, $ReminderItemsTable, ReminderItem>,
      ),
      ReminderItem,
      PrefetchHooks Function()
    >;

class $LifeProductivityDbManager {
  final _$LifeProductivityDb _db;
  $LifeProductivityDbManager(this._db);
  $$ReminderListsTableTableManager get reminderLists =>
      $$ReminderListsTableTableManager(_db, _db.reminderLists);
  $$ReminderItemsTableTableManager get reminderItems =>
      $$ReminderItemsTableTableManager(_db, _db.reminderItems);
}
