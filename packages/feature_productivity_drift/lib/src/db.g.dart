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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sectionsJsonMeta = const VerificationMeta(
    'sectionsJson',
  );
  @override
  late final GeneratedColumn<String> sectionsJson = GeneratedColumn<String>(
    'sections_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listTypeMeta = const VerificationMeta(
    'listType',
  );
  @override
  late final GeneratedColumn<String> listType = GeneratedColumn<String>(
    'list_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smartFilterMeta = const VerificationMeta(
    'smartFilter',
  );
  @override
  late final GeneratedColumn<String> smartFilter = GeneratedColumn<String>(
    'smart_filter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    colorArgb,
    isSmart,
    sortOrder,
    sectionsJson,
    groupName,
    listType,
    smartFilter,
  ];
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
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sections_json')) {
      context.handle(
        _sectionsJsonMeta,
        sectionsJson.isAcceptableOrUnknown(
          data['sections_json']!,
          _sectionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('list_type')) {
      context.handle(
        _listTypeMeta,
        listType.isAcceptableOrUnknown(data['list_type']!, _listTypeMeta),
      );
    }
    if (data.containsKey('smart_filter')) {
      context.handle(
        _smartFilterMeta,
        smartFilter.isAcceptableOrUnknown(
          data['smart_filter']!,
          _smartFilterMeta,
        ),
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
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      sectionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sections_json'],
      ),
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      listType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_type'],
      ),
      smartFilter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smart_filter'],
      ),
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
  final int sortOrder;

  /// 手动分区元数据 JSON（[{id,title,sortOrder}]；TC-KR-118）。
  /// nullable：V3→V4 增列时旧行为 NULL，读取侧兜底空分区。
  final String? sectionsJson;

  /// 列表分组名（TC-UI-118；NULL = 不分组）。
  final String? groupName;

  /// 清单类型（TC-UI-115；NULL/standard=标准；grocery=采购）。
  final String? listType;

  /// 自定义智能列表条件 JSON（TC-UI-116；NULL = 非自定义智能列表）。
  final String? smartFilter;
  const ReminderList({
    required this.id,
    required this.title,
    required this.colorArgb,
    required this.isSmart,
    required this.sortOrder,
    this.sectionsJson,
    this.groupName,
    this.listType,
    this.smartFilter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['color_argb'] = Variable<int>(colorArgb);
    map['is_smart'] = Variable<bool>(isSmart);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || sectionsJson != null) {
      map['sections_json'] = Variable<String>(sectionsJson);
    }
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    if (!nullToAbsent || listType != null) {
      map['list_type'] = Variable<String>(listType);
    }
    if (!nullToAbsent || smartFilter != null) {
      map['smart_filter'] = Variable<String>(smartFilter);
    }
    return map;
  }

  ReminderListsCompanion toCompanion(bool nullToAbsent) {
    return ReminderListsCompanion(
      id: Value(id),
      title: Value(title),
      colorArgb: Value(colorArgb),
      isSmart: Value(isSmart),
      sortOrder: Value(sortOrder),
      sectionsJson: sectionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionsJson),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      listType: listType == null && nullToAbsent
          ? const Value.absent()
          : Value(listType),
      smartFilter: smartFilter == null && nullToAbsent
          ? const Value.absent()
          : Value(smartFilter),
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
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      sectionsJson: serializer.fromJson<String?>(json['sectionsJson']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      listType: serializer.fromJson<String?>(json['listType']),
      smartFilter: serializer.fromJson<String?>(json['smartFilter']),
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
      'sortOrder': serializer.toJson<int>(sortOrder),
      'sectionsJson': serializer.toJson<String?>(sectionsJson),
      'groupName': serializer.toJson<String?>(groupName),
      'listType': serializer.toJson<String?>(listType),
      'smartFilter': serializer.toJson<String?>(smartFilter),
    };
  }

  ReminderList copyWith({
    String? id,
    String? title,
    int? colorArgb,
    bool? isSmart,
    int? sortOrder,
    Value<String?> sectionsJson = const Value.absent(),
    Value<String?> groupName = const Value.absent(),
    Value<String?> listType = const Value.absent(),
    Value<String?> smartFilter = const Value.absent(),
  }) => ReminderList(
    id: id ?? this.id,
    title: title ?? this.title,
    colorArgb: colorArgb ?? this.colorArgb,
    isSmart: isSmart ?? this.isSmart,
    sortOrder: sortOrder ?? this.sortOrder,
    sectionsJson: sectionsJson.present ? sectionsJson.value : this.sectionsJson,
    groupName: groupName.present ? groupName.value : this.groupName,
    listType: listType.present ? listType.value : this.listType,
    smartFilter: smartFilter.present ? smartFilter.value : this.smartFilter,
  );
  ReminderList copyWithCompanion(ReminderListsCompanion data) {
    return ReminderList(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      isSmart: data.isSmart.present ? data.isSmart.value : this.isSmart,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      sectionsJson: data.sectionsJson.present
          ? data.sectionsJson.value
          : this.sectionsJson,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      listType: data.listType.present ? data.listType.value : this.listType,
      smartFilter: data.smartFilter.present
          ? data.smartFilter.value
          : this.smartFilter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderList(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('isSmart: $isSmart, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sectionsJson: $sectionsJson, ')
          ..write('groupName: $groupName, ')
          ..write('listType: $listType, ')
          ..write('smartFilter: $smartFilter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    colorArgb,
    isSmart,
    sortOrder,
    sectionsJson,
    groupName,
    listType,
    smartFilter,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderList &&
          other.id == this.id &&
          other.title == this.title &&
          other.colorArgb == this.colorArgb &&
          other.isSmart == this.isSmart &&
          other.sortOrder == this.sortOrder &&
          other.sectionsJson == this.sectionsJson &&
          other.groupName == this.groupName &&
          other.listType == this.listType &&
          other.smartFilter == this.smartFilter);
}

class ReminderListsCompanion extends UpdateCompanion<ReminderList> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> colorArgb;
  final Value<bool> isSmart;
  final Value<int> sortOrder;
  final Value<String?> sectionsJson;
  final Value<String?> groupName;
  final Value<String?> listType;
  final Value<String?> smartFilter;
  final Value<int> rowid;
  const ReminderListsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sectionsJson = const Value.absent(),
    this.groupName = const Value.absent(),
    this.listType = const Value.absent(),
    this.smartFilter = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderListsCompanion.insert({
    required String id,
    required String title,
    this.colorArgb = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sectionsJson = const Value.absent(),
    this.groupName = const Value.absent(),
    this.listType = const Value.absent(),
    this.smartFilter = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<ReminderList> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? colorArgb,
    Expression<bool>? isSmart,
    Expression<int>? sortOrder,
    Expression<String>? sectionsJson,
    Expression<String>? groupName,
    Expression<String>? listType,
    Expression<String>? smartFilter,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (isSmart != null) 'is_smart': isSmart,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (sectionsJson != null) 'sections_json': sectionsJson,
      if (groupName != null) 'group_name': groupName,
      if (listType != null) 'list_type': listType,
      if (smartFilter != null) 'smart_filter': smartFilter,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderListsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? colorArgb,
    Value<bool>? isSmart,
    Value<int>? sortOrder,
    Value<String?>? sectionsJson,
    Value<String?>? groupName,
    Value<String?>? listType,
    Value<String?>? smartFilter,
    Value<int>? rowid,
  }) {
    return ReminderListsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      colorArgb: colorArgb ?? this.colorArgb,
      isSmart: isSmart ?? this.isSmart,
      sortOrder: sortOrder ?? this.sortOrder,
      sectionsJson: sectionsJson ?? this.sectionsJson,
      groupName: groupName ?? this.groupName,
      listType: listType ?? this.listType,
      smartFilter: smartFilter ?? this.smartFilter,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (sectionsJson.present) {
      map['sections_json'] = Variable<String>(sectionsJson.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (listType.present) {
      map['list_type'] = Variable<String>(listType.value);
    }
    if (smartFilter.present) {
      map['smart_filter'] = Variable<String>(smartFilter.value);
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
          ..write('sortOrder: $sortOrder, ')
          ..write('sectionsJson: $sectionsJson, ')
          ..write('groupName: $groupName, ')
          ..write('listType: $listType, ')
          ..write('smartFilter: $smartFilter, ')
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
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceUntilMeta = const VerificationMeta(
    'recurrenceUntil',
  );
  @override
  late final GeneratedColumn<DateTime> recurrenceUntil =
      GeneratedColumn<DateTime>(
        'recurrence_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    tags,
    recurrence,
    recurrenceUntil,
    parentId,
    sortOrder,
    remoteId,
    completedAt,
    sectionId,
    deletedAt,
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
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    if (data.containsKey('recurrence_until')) {
      context.handle(
        _recurrenceUntilMeta,
        recurrenceUntil.isAcceptableOrUnknown(
          data['recurrence_until']!,
          _recurrenceUntilMeta,
        ),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      ),
      recurrenceUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recurrence_until'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
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

  /// 标签（JSON 数组文本，如 '["工作","设计"]'；空数组存 '[]'）。
  final String tags;

  /// 重复规则 id（见 kernel Recurrence；null = 不重复）。
  final String? recurrence;

  /// T-04：重复结束日期（本地日期；null = 永不结束）。
  final DateTime? recurrenceUntil;

  /// 子任务的父提醒 id；null = 顶层。
  final String? parentId;

  /// 同层排序键。
  final int sortOrder;

  /// 服务端实体 ID（Spec 028；null = 纯本地未同步）。V3（Issue #3）。
  final String? remoteId;

  /// 完成时间（服务端 completedAt 对齐）。V3（Issue #3）。
  final DateTime? completedAt;

  /// 列表内手动分区 id（A15；跨列表移动时清空）。V3（Issue #3）。
  final String? sectionId;

  /// 进入最近删除的时间（A10 本地回收窗；null = 未删）。V3（Issue #3）。
  final DateTime? deletedAt;
  const ReminderItem({
    required this.id,
    required this.listId,
    required this.title,
    this.notes,
    required this.isCompleted,
    required this.isFlagged,
    this.dueAt,
    required this.priority,
    required this.tags,
    this.recurrence,
    this.recurrenceUntil,
    this.parentId,
    required this.sortOrder,
    this.remoteId,
    this.completedAt,
    this.sectionId,
    this.deletedAt,
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
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || recurrence != null) {
      map['recurrence'] = Variable<String>(recurrence);
    }
    if (!nullToAbsent || recurrenceUntil != null) {
      map['recurrence_until'] = Variable<DateTime>(recurrenceUntil);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || sectionId != null) {
      map['section_id'] = Variable<String>(sectionId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
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
      tags: Value(tags),
      recurrence: recurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrence),
      recurrenceUntil: recurrenceUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceUntil),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sortOrder: Value(sortOrder),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      sectionId: sectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sectionId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
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
      tags: serializer.fromJson<String>(json['tags']),
      recurrence: serializer.fromJson<String?>(json['recurrence']),
      recurrenceUntil: serializer.fromJson<DateTime?>(json['recurrenceUntil']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      sectionId: serializer.fromJson<String?>(json['sectionId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
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
      'tags': serializer.toJson<String>(tags),
      'recurrence': serializer.toJson<String?>(recurrence),
      'recurrenceUntil': serializer.toJson<DateTime?>(recurrenceUntil),
      'parentId': serializer.toJson<String?>(parentId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'remoteId': serializer.toJson<String?>(remoteId),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'sectionId': serializer.toJson<String?>(sectionId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
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
    String? tags,
    Value<String?> recurrence = const Value.absent(),
    Value<DateTime?> recurrenceUntil = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    int? sortOrder,
    Value<String?> remoteId = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> sectionId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ReminderItem(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    isCompleted: isCompleted ?? this.isCompleted,
    isFlagged: isFlagged ?? this.isFlagged,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    priority: priority ?? this.priority,
    tags: tags ?? this.tags,
    recurrence: recurrence.present ? recurrence.value : this.recurrence,
    recurrenceUntil: recurrenceUntil.present
        ? recurrenceUntil.value
        : this.recurrenceUntil,
    parentId: parentId.present ? parentId.value : this.parentId,
    sortOrder: sortOrder ?? this.sortOrder,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    sectionId: sectionId.present ? sectionId.value : this.sectionId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
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
      tags: data.tags.present ? data.tags.value : this.tags,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      recurrenceUntil: data.recurrenceUntil.present
          ? data.recurrenceUntil.value
          : this.recurrenceUntil,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
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
          ..write('priority: $priority, ')
          ..write('tags: $tags, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceUntil: $recurrenceUntil, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('remoteId: $remoteId, ')
          ..write('completedAt: $completedAt, ')
          ..write('sectionId: $sectionId, ')
          ..write('deletedAt: $deletedAt')
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
    tags,
    recurrence,
    recurrenceUntil,
    parentId,
    sortOrder,
    remoteId,
    completedAt,
    sectionId,
    deletedAt,
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
          other.priority == this.priority &&
          other.tags == this.tags &&
          other.recurrence == this.recurrence &&
          other.recurrenceUntil == this.recurrenceUntil &&
          other.parentId == this.parentId &&
          other.sortOrder == this.sortOrder &&
          other.remoteId == this.remoteId &&
          other.completedAt == this.completedAt &&
          other.sectionId == this.sectionId &&
          other.deletedAt == this.deletedAt);
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
  final Value<String> tags;
  final Value<String?> recurrence;
  final Value<DateTime?> recurrenceUntil;
  final Value<String?> parentId;
  final Value<int> sortOrder;
  final Value<String?> remoteId;
  final Value<DateTime?> completedAt;
  final Value<String?> sectionId;
  final Value<DateTime?> deletedAt;
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
    this.tags = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.recurrenceUntil = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.deletedAt = const Value.absent(),
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
    this.tags = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.recurrenceUntil = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.deletedAt = const Value.absent(),
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
    Expression<String>? tags,
    Expression<String>? recurrence,
    Expression<DateTime>? recurrenceUntil,
    Expression<String>? parentId,
    Expression<int>? sortOrder,
    Expression<String>? remoteId,
    Expression<DateTime>? completedAt,
    Expression<String>? sectionId,
    Expression<DateTime>? deletedAt,
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
      if (tags != null) 'tags': tags,
      if (recurrence != null) 'recurrence': recurrence,
      if (recurrenceUntil != null) 'recurrence_until': recurrenceUntil,
      if (parentId != null) 'parent_id': parentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (remoteId != null) 'remote_id': remoteId,
      if (completedAt != null) 'completed_at': completedAt,
      if (sectionId != null) 'section_id': sectionId,
      if (deletedAt != null) 'deleted_at': deletedAt,
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
    Value<String>? tags,
    Value<String?>? recurrence,
    Value<DateTime?>? recurrenceUntil,
    Value<String?>? parentId,
    Value<int>? sortOrder,
    Value<String?>? remoteId,
    Value<DateTime?>? completedAt,
    Value<String?>? sectionId,
    Value<DateTime?>? deletedAt,
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
      tags: tags ?? this.tags,
      recurrence: recurrence ?? this.recurrence,
      recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      remoteId: remoteId ?? this.remoteId,
      completedAt: completedAt ?? this.completedAt,
      sectionId: sectionId ?? this.sectionId,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (recurrenceUntil.present) {
      map['recurrence_until'] = Variable<DateTime>(recurrenceUntil.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
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
          ..write('tags: $tags, ')
          ..write('recurrence: $recurrence, ')
          ..write('recurrenceUntil: $recurrenceUntil, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('remoteId: $remoteId, ')
          ..write('completedAt: $completedAt, ')
          ..write('sectionId: $sectionId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarsTable extends Calendars
    with TableInfo<$CalendarsTable, Calendar> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('LOCAL'),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isVisibleMeta = const VerificationMeta(
    'isVisible',
  );
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
    'is_visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ignoreAlertsMeta = const VerificationMeta(
    'ignoreAlerts',
  );
  @override
  late final GeneratedColumn<bool> ignoreAlerts = GeneratedColumn<bool>(
    'ignore_alerts',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ignore_alerts" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refreshMinutesMeta = const VerificationMeta(
    'refreshMinutes',
  );
  @override
  late final GeneratedColumn<int> refreshMinutes = GeneratedColumn<int>(
    'refresh_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holidayRegionMeta = const VerificationMeta(
    'holidayRegion',
  );
  @override
  late final GeneratedColumn<String> holidayRegion = GeneratedColumn<String>(
    'holiday_region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRefreshErrorMeta = const VerificationMeta(
    'lastRefreshError',
  );
  @override
  late final GeneratedColumn<String> lastRefreshError = GeneratedColumn<String>(
    'last_refresh_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _permissionMeta = const VerificationMeta(
    'permission',
  );
  @override
  late final GeneratedColumn<String> permission = GeneratedColumn<String>(
    'permission',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('OWNER'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
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
    lastRefreshError,
    permission,
    revision,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendars';
  @override
  VerificationContext validateIntegrity(
    Insertable<Calendar> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
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
    } else if (isInserting) {
      context.missing(_colorArgbMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('is_visible')) {
      context.handle(
        _isVisibleMeta,
        isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('ignore_alerts')) {
      context.handle(
        _ignoreAlertsMeta,
        ignoreAlerts.isAcceptableOrUnknown(
          data['ignore_alerts']!,
          _ignoreAlertsMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('refresh_minutes')) {
      context.handle(
        _refreshMinutesMeta,
        refreshMinutes.isAcceptableOrUnknown(
          data['refresh_minutes']!,
          _refreshMinutesMeta,
        ),
      );
    }
    if (data.containsKey('holiday_region')) {
      context.handle(
        _holidayRegionMeta,
        holidayRegion.isAcceptableOrUnknown(
          data['holiday_region']!,
          _holidayRegionMeta,
        ),
      );
    }
    if (data.containsKey('last_refresh_error')) {
      context.handle(
        _lastRefreshErrorMeta,
        lastRefreshError.isAcceptableOrUnknown(
          data['last_refresh_error']!,
          _lastRefreshErrorMeta,
        ),
      );
    }
    if (data.containsKey('permission')) {
      context.handle(
        _permissionMeta,
        permission.isAcceptableOrUnknown(data['permission']!, _permissionMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Calendar map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Calendar(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      isVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_visible'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      ignoreAlerts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ignore_alerts'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      refreshMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refresh_minutes'],
      ),
      holidayRegion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holiday_region'],
      ),
      lastRefreshError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_refresh_error'],
      ),
      permission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CalendarsTable createAlias(String alias) {
    return $CalendarsTable(attachedDatabase, alias);
  }
}

class Calendar extends DataClass implements Insertable<Calendar> {
  final String id;

  /// 服务端实体 ID（null = 纯本地未同步）。
  final String? remoteId;
  final String title;
  final int colorArgb;

  /// LOCAL / SUBSCRIPTION / HOLIDAY / SHARED（服务端大写枚举 id）。
  final String kind;
  final String? groupName;
  final bool isVisible;
  final bool isDefault;
  final int sortOrder;
  final bool ignoreAlerts;

  /// kind=subscription 的 .ics 地址。
  final String? sourceUrl;

  /// 订阅刷新间隔分钟（NULL=手动）。
  final int? refreshMinutes;

  /// kind=holiday 的地区码（首期 CN）。
  final String? holidayRegion;

  /// 上次订阅刷新失败的错误信息（NULL=正常；契约 §2.6 last_refresh_error）。
  final String? lastRefreshError;

  /// OWNER / EDIT / VIEW。
  final String permission;
  final int revision;
  final DateTime? deletedAt;
  const Calendar({
    required this.id,
    this.remoteId,
    required this.title,
    required this.colorArgb,
    required this.kind,
    this.groupName,
    required this.isVisible,
    required this.isDefault,
    required this.sortOrder,
    required this.ignoreAlerts,
    this.sourceUrl,
    this.refreshMinutes,
    this.holidayRegion,
    this.lastRefreshError,
    required this.permission,
    required this.revision,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['title'] = Variable<String>(title);
    map['color_argb'] = Variable<int>(colorArgb);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    map['is_visible'] = Variable<bool>(isVisible);
    map['is_default'] = Variable<bool>(isDefault);
    map['sort_order'] = Variable<int>(sortOrder);
    map['ignore_alerts'] = Variable<bool>(ignoreAlerts);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || refreshMinutes != null) {
      map['refresh_minutes'] = Variable<int>(refreshMinutes);
    }
    if (!nullToAbsent || holidayRegion != null) {
      map['holiday_region'] = Variable<String>(holidayRegion);
    }
    if (!nullToAbsent || lastRefreshError != null) {
      map['last_refresh_error'] = Variable<String>(lastRefreshError);
    }
    map['permission'] = Variable<String>(permission);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CalendarsCompanion toCompanion(bool nullToAbsent) {
    return CalendarsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      title: Value(title),
      colorArgb: Value(colorArgb),
      kind: Value(kind),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      isVisible: Value(isVisible),
      isDefault: Value(isDefault),
      sortOrder: Value(sortOrder),
      ignoreAlerts: Value(ignoreAlerts),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      refreshMinutes: refreshMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(refreshMinutes),
      holidayRegion: holidayRegion == null && nullToAbsent
          ? const Value.absent()
          : Value(holidayRegion),
      lastRefreshError: lastRefreshError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRefreshError),
      permission: Value(permission),
      revision: Value(revision),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Calendar.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Calendar(
      id: serializer.fromJson<String>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      title: serializer.fromJson<String>(json['title']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      kind: serializer.fromJson<String>(json['kind']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      ignoreAlerts: serializer.fromJson<bool>(json['ignoreAlerts']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      refreshMinutes: serializer.fromJson<int?>(json['refreshMinutes']),
      holidayRegion: serializer.fromJson<String?>(json['holidayRegion']),
      lastRefreshError: serializer.fromJson<String?>(json['lastRefreshError']),
      permission: serializer.fromJson<String>(json['permission']),
      revision: serializer.fromJson<int>(json['revision']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'title': serializer.toJson<String>(title),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'kind': serializer.toJson<String>(kind),
      'groupName': serializer.toJson<String?>(groupName),
      'isVisible': serializer.toJson<bool>(isVisible),
      'isDefault': serializer.toJson<bool>(isDefault),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'ignoreAlerts': serializer.toJson<bool>(ignoreAlerts),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'refreshMinutes': serializer.toJson<int?>(refreshMinutes),
      'holidayRegion': serializer.toJson<String?>(holidayRegion),
      'lastRefreshError': serializer.toJson<String?>(lastRefreshError),
      'permission': serializer.toJson<String>(permission),
      'revision': serializer.toJson<int>(revision),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Calendar copyWith({
    String? id,
    Value<String?> remoteId = const Value.absent(),
    String? title,
    int? colorArgb,
    String? kind,
    Value<String?> groupName = const Value.absent(),
    bool? isVisible,
    bool? isDefault,
    int? sortOrder,
    bool? ignoreAlerts,
    Value<String?> sourceUrl = const Value.absent(),
    Value<int?> refreshMinutes = const Value.absent(),
    Value<String?> holidayRegion = const Value.absent(),
    Value<String?> lastRefreshError = const Value.absent(),
    String? permission,
    int? revision,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Calendar(
    id: id ?? this.id,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    title: title ?? this.title,
    colorArgb: colorArgb ?? this.colorArgb,
    kind: kind ?? this.kind,
    groupName: groupName.present ? groupName.value : this.groupName,
    isVisible: isVisible ?? this.isVisible,
    isDefault: isDefault ?? this.isDefault,
    sortOrder: sortOrder ?? this.sortOrder,
    ignoreAlerts: ignoreAlerts ?? this.ignoreAlerts,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    refreshMinutes: refreshMinutes.present
        ? refreshMinutes.value
        : this.refreshMinutes,
    holidayRegion: holidayRegion.present
        ? holidayRegion.value
        : this.holidayRegion,
    lastRefreshError: lastRefreshError.present
        ? lastRefreshError.value
        : this.lastRefreshError,
    permission: permission ?? this.permission,
    revision: revision ?? this.revision,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Calendar copyWithCompanion(CalendarsCompanion data) {
    return Calendar(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      title: data.title.present ? data.title.value : this.title,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      kind: data.kind.present ? data.kind.value : this.kind,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      ignoreAlerts: data.ignoreAlerts.present
          ? data.ignoreAlerts.value
          : this.ignoreAlerts,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      refreshMinutes: data.refreshMinutes.present
          ? data.refreshMinutes.value
          : this.refreshMinutes,
      holidayRegion: data.holidayRegion.present
          ? data.holidayRegion.value
          : this.holidayRegion,
      lastRefreshError: data.lastRefreshError.present
          ? data.lastRefreshError.value
          : this.lastRefreshError,
      permission: data.permission.present
          ? data.permission.value
          : this.permission,
      revision: data.revision.present ? data.revision.value : this.revision,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Calendar(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('kind: $kind, ')
          ..write('groupName: $groupName, ')
          ..write('isVisible: $isVisible, ')
          ..write('isDefault: $isDefault, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('ignoreAlerts: $ignoreAlerts, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('refreshMinutes: $refreshMinutes, ')
          ..write('holidayRegion: $holidayRegion, ')
          ..write('lastRefreshError: $lastRefreshError, ')
          ..write('permission: $permission, ')
          ..write('revision: $revision, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
    lastRefreshError,
    permission,
    revision,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Calendar &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.title == this.title &&
          other.colorArgb == this.colorArgb &&
          other.kind == this.kind &&
          other.groupName == this.groupName &&
          other.isVisible == this.isVisible &&
          other.isDefault == this.isDefault &&
          other.sortOrder == this.sortOrder &&
          other.ignoreAlerts == this.ignoreAlerts &&
          other.sourceUrl == this.sourceUrl &&
          other.refreshMinutes == this.refreshMinutes &&
          other.holidayRegion == this.holidayRegion &&
          other.lastRefreshError == this.lastRefreshError &&
          other.permission == this.permission &&
          other.revision == this.revision &&
          other.deletedAt == this.deletedAt);
}

class CalendarsCompanion extends UpdateCompanion<Calendar> {
  final Value<String> id;
  final Value<String?> remoteId;
  final Value<String> title;
  final Value<int> colorArgb;
  final Value<String> kind;
  final Value<String?> groupName;
  final Value<bool> isVisible;
  final Value<bool> isDefault;
  final Value<int> sortOrder;
  final Value<bool> ignoreAlerts;
  final Value<String?> sourceUrl;
  final Value<int?> refreshMinutes;
  final Value<String?> holidayRegion;
  final Value<String?> lastRefreshError;
  final Value<String> permission;
  final Value<int> revision;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CalendarsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.title = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.kind = const Value.absent(),
    this.groupName = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.ignoreAlerts = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.refreshMinutes = const Value.absent(),
    this.holidayRegion = const Value.absent(),
    this.lastRefreshError = const Value.absent(),
    this.permission = const Value.absent(),
    this.revision = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarsCompanion.insert({
    required String id,
    this.remoteId = const Value.absent(),
    required String title,
    required int colorArgb,
    this.kind = const Value.absent(),
    this.groupName = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.ignoreAlerts = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.refreshMinutes = const Value.absent(),
    this.holidayRegion = const Value.absent(),
    this.lastRefreshError = const Value.absent(),
    this.permission = const Value.absent(),
    this.revision = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       colorArgb = Value(colorArgb);
  static Insertable<Calendar> custom({
    Expression<String>? id,
    Expression<String>? remoteId,
    Expression<String>? title,
    Expression<int>? colorArgb,
    Expression<String>? kind,
    Expression<String>? groupName,
    Expression<bool>? isVisible,
    Expression<bool>? isDefault,
    Expression<int>? sortOrder,
    Expression<bool>? ignoreAlerts,
    Expression<String>? sourceUrl,
    Expression<int>? refreshMinutes,
    Expression<String>? holidayRegion,
    Expression<String>? lastRefreshError,
    Expression<String>? permission,
    Expression<int>? revision,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (title != null) 'title': title,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (kind != null) 'kind': kind,
      if (groupName != null) 'group_name': groupName,
      if (isVisible != null) 'is_visible': isVisible,
      if (isDefault != null) 'is_default': isDefault,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (ignoreAlerts != null) 'ignore_alerts': ignoreAlerts,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (refreshMinutes != null) 'refresh_minutes': refreshMinutes,
      if (holidayRegion != null) 'holiday_region': holidayRegion,
      if (lastRefreshError != null) 'last_refresh_error': lastRefreshError,
      if (permission != null) 'permission': permission,
      if (revision != null) 'revision': revision,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarsCompanion copyWith({
    Value<String>? id,
    Value<String?>? remoteId,
    Value<String>? title,
    Value<int>? colorArgb,
    Value<String>? kind,
    Value<String?>? groupName,
    Value<bool>? isVisible,
    Value<bool>? isDefault,
    Value<int>? sortOrder,
    Value<bool>? ignoreAlerts,
    Value<String?>? sourceUrl,
    Value<int?>? refreshMinutes,
    Value<String?>? holidayRegion,
    Value<String?>? lastRefreshError,
    Value<String>? permission,
    Value<int>? revision,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CalendarsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      colorArgb: colorArgb ?? this.colorArgb,
      kind: kind ?? this.kind,
      groupName: groupName ?? this.groupName,
      isVisible: isVisible ?? this.isVisible,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      ignoreAlerts: ignoreAlerts ?? this.ignoreAlerts,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
      holidayRegion: holidayRegion ?? this.holidayRegion,
      lastRefreshError: lastRefreshError ?? this.lastRefreshError,
      permission: permission ?? this.permission,
      revision: revision ?? this.revision,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (ignoreAlerts.present) {
      map['ignore_alerts'] = Variable<bool>(ignoreAlerts.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (refreshMinutes.present) {
      map['refresh_minutes'] = Variable<int>(refreshMinutes.value);
    }
    if (holidayRegion.present) {
      map['holiday_region'] = Variable<String>(holidayRegion.value);
    }
    if (lastRefreshError.present) {
      map['last_refresh_error'] = Variable<String>(lastRefreshError.value);
    }
    if (permission.present) {
      map['permission'] = Variable<String>(permission.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('kind: $kind, ')
          ..write('groupName: $groupName, ')
          ..write('isVisible: $isVisible, ')
          ..write('isDefault: $isDefault, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('ignoreAlerts: $ignoreAlerts, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('refreshMinutes: $refreshMinutes, ')
          ..write('holidayRegion: $holidayRegion, ')
          ..write('lastRefreshError: $lastRefreshError, ')
          ..write('permission: $permission, ')
          ..write('revision: $revision, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventsTable extends CalendarEvents
    with TableInfo<$CalendarEventsTable, CalendarEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
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
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFloatingMeta = const VerificationMeta(
    'isFloating',
  );
  @override
  late final GeneratedColumn<bool> isFloating = GeneratedColumn<bool>(
    'is_floating',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_floating" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rruleMeta = const VerificationMeta('rrule');
  @override
  late final GeneratedColumn<String> rrule = GeneratedColumn<String>(
    'rrule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exdatesJsonMeta = const VerificationMeta(
    'exdatesJson',
  );
  @override
  late final GeneratedColumn<String> exdatesJson = GeneratedColumn<String>(
    'exdates_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _parentEventIdMeta = const VerificationMeta(
    'parentEventId',
  );
  @override
  late final GeneratedColumn<String> parentEventId = GeneratedColumn<String>(
    'parent_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalStartAtMeta = const VerificationMeta(
    'originalStartAt',
  );
  @override
  late final GeneratedColumn<DateTime> originalStartAt =
      GeneratedColumn<DateTime>(
        'original_start_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CONFIRMED'),
  );
  static const VerificationMeta _availabilityMeta = const VerificationMeta(
    'availability',
  );
  @override
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('BUSY'),
  );
  static const VerificationMeta _travelMinutesMeta = const VerificationMeta(
    'travelMinutes',
  );
  @override
  late final GeneratedColumn<int> travelMinutes = GeneratedColumn<int>(
    'travel_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrivateMeta = const VerificationMeta(
    'isPrivate',
  );
  @override
  late final GeneratedColumn<bool> isPrivate = GeneratedColumn<bool>(
    'is_private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _alertsJsonMeta = const VerificationMeta(
    'alertsJson',
  );
  @override
  late final GeneratedColumn<String> alertsJson = GeneratedColumn<String>(
    'alerts_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _inviteesJsonMeta = const VerificationMeta(
    'inviteesJson',
  );
  @override
  late final GeneratedColumn<String> inviteesJson = GeneratedColumn<String>(
    'invitees_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
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
    exdatesJson,
    parentEventId,
    originalStartAt,
    status,
    availability,
    travelMinutes,
    isPrivate,
    alertsJson,
    inviteesJson,
    sequence,
    revision,
    deletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('is_floating')) {
      context.handle(
        _isFloatingMeta,
        isFloating.isAcceptableOrUnknown(data['is_floating']!, _isFloatingMeta),
      );
    }
    if (data.containsKey('rrule')) {
      context.handle(
        _rruleMeta,
        rrule.isAcceptableOrUnknown(data['rrule']!, _rruleMeta),
      );
    }
    if (data.containsKey('exdates_json')) {
      context.handle(
        _exdatesJsonMeta,
        exdatesJson.isAcceptableOrUnknown(
          data['exdates_json']!,
          _exdatesJsonMeta,
        ),
      );
    }
    if (data.containsKey('parent_event_id')) {
      context.handle(
        _parentEventIdMeta,
        parentEventId.isAcceptableOrUnknown(
          data['parent_event_id']!,
          _parentEventIdMeta,
        ),
      );
    }
    if (data.containsKey('original_start_at')) {
      context.handle(
        _originalStartAtMeta,
        originalStartAt.isAcceptableOrUnknown(
          data['original_start_at']!,
          _originalStartAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('availability')) {
      context.handle(
        _availabilityMeta,
        availability.isAcceptableOrUnknown(
          data['availability']!,
          _availabilityMeta,
        ),
      );
    }
    if (data.containsKey('travel_minutes')) {
      context.handle(
        _travelMinutesMeta,
        travelMinutes.isAcceptableOrUnknown(
          data['travel_minutes']!,
          _travelMinutesMeta,
        ),
      );
    }
    if (data.containsKey('is_private')) {
      context.handle(
        _isPrivateMeta,
        isPrivate.isAcceptableOrUnknown(data['is_private']!, _isPrivateMeta),
      );
    }
    if (data.containsKey('alerts_json')) {
      context.handle(
        _alertsJsonMeta,
        alertsJson.isAcceptableOrUnknown(data['alerts_json']!, _alertsJsonMeta),
      );
    }
    if (data.containsKey('invitees_json')) {
      context.handle(
        _inviteesJsonMeta,
        inviteesJson.isAcceptableOrUnknown(
          data['invitees_json']!,
          _inviteesJsonMeta,
        ),
      );
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      isFloating: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_floating'],
      )!,
      rrule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rrule'],
      ),
      exdatesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exdates_json'],
      )!,
      parentEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_event_id'],
      ),
      originalStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}original_start_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      availability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability'],
      )!,
      travelMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}travel_minutes'],
      ),
      isPrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_private'],
      )!,
      alertsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alerts_json'],
      )!,
      inviteesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invitees_json'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CalendarEventsTable createAlias(String alias) {
    return $CalendarEventsTable(attachedDatabase, alias);
  }
}

class CalendarEvent extends DataClass implements Insertable<CalendarEvent> {
  final String id;
  final String? remoteId;
  final String calendarId;
  final String uid;
  final String title;
  final String? location;
  final String? url;
  final String? notes;

  /// UTC；全天事件存该日 00:00 创建时区对应 UTC。
  final DateTime startAt;

  /// UTC 排他；全天事件为次日 00:00。
  final DateTime endAt;
  final bool allDay;
  final String timeZone;
  final bool isFloating;

  /// RFC 5545 RRULE（不含 `RRULE:` 前缀）；NULL = 不重复。
  final String? rrule;

  /// 已删除单次出现（ISO UTC 数组文本，如 '["2026-11-03T09:00:00Z"]'）。
  final String exdatesJson;

  /// 非空 = 本行是某重复事件的例外实例。
  final String? parentEventId;
  final DateTime? originalStartAt;

  /// CONFIRMED / TENTATIVE / CANCELLED。
  final String status;

  /// BUSY / FREE（Apple「显示为」）。
  final String availability;
  final int? travelMinutes;
  final bool isPrivate;

  /// 提醒 JSON：[{offsetMinutes?,allDayOffsetDays?,allDayTime?}]。
  final String alertsJson;

  /// 受邀者 JSON：[{memberUserId,displayName,role,partstat,comment,...}]。
  final String inviteesJson;
  final int sequence;
  final int revision;
  final DateTime? deletedAt;
  final DateTime updatedAt;
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
    required this.allDay,
    required this.timeZone,
    required this.isFloating,
    this.rrule,
    required this.exdatesJson,
    this.parentEventId,
    this.originalStartAt,
    required this.status,
    required this.availability,
    this.travelMinutes,
    required this.isPrivate,
    required this.alertsJson,
    required this.inviteesJson,
    required this.sequence,
    required this.revision,
    this.deletedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['calendar_id'] = Variable<String>(calendarId);
    map['uid'] = Variable<String>(uid);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['all_day'] = Variable<bool>(allDay);
    map['time_zone'] = Variable<String>(timeZone);
    map['is_floating'] = Variable<bool>(isFloating);
    if (!nullToAbsent || rrule != null) {
      map['rrule'] = Variable<String>(rrule);
    }
    map['exdates_json'] = Variable<String>(exdatesJson);
    if (!nullToAbsent || parentEventId != null) {
      map['parent_event_id'] = Variable<String>(parentEventId);
    }
    if (!nullToAbsent || originalStartAt != null) {
      map['original_start_at'] = Variable<DateTime>(originalStartAt);
    }
    map['status'] = Variable<String>(status);
    map['availability'] = Variable<String>(availability);
    if (!nullToAbsent || travelMinutes != null) {
      map['travel_minutes'] = Variable<int>(travelMinutes);
    }
    map['is_private'] = Variable<bool>(isPrivate);
    map['alerts_json'] = Variable<String>(alertsJson);
    map['invitees_json'] = Variable<String>(inviteesJson);
    map['sequence'] = Variable<int>(sequence);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CalendarEventsCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      calendarId: Value(calendarId),
      uid: Value(uid),
      title: Value(title),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      startAt: Value(startAt),
      endAt: Value(endAt),
      allDay: Value(allDay),
      timeZone: Value(timeZone),
      isFloating: Value(isFloating),
      rrule: rrule == null && nullToAbsent
          ? const Value.absent()
          : Value(rrule),
      exdatesJson: Value(exdatesJson),
      parentEventId: parentEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentEventId),
      originalStartAt: originalStartAt == null && nullToAbsent
          ? const Value.absent()
          : Value(originalStartAt),
      status: Value(status),
      availability: Value(availability),
      travelMinutes: travelMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(travelMinutes),
      isPrivate: Value(isPrivate),
      alertsJson: Value(alertsJson),
      inviteesJson: Value(inviteesJson),
      sequence: Value(sequence),
      revision: Value(revision),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CalendarEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEvent(
      id: serializer.fromJson<String>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      calendarId: serializer.fromJson<String>(json['calendarId']),
      uid: serializer.fromJson<String>(json['uid']),
      title: serializer.fromJson<String>(json['title']),
      location: serializer.fromJson<String?>(json['location']),
      url: serializer.fromJson<String?>(json['url']),
      notes: serializer.fromJson<String?>(json['notes']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      isFloating: serializer.fromJson<bool>(json['isFloating']),
      rrule: serializer.fromJson<String?>(json['rrule']),
      exdatesJson: serializer.fromJson<String>(json['exdatesJson']),
      parentEventId: serializer.fromJson<String?>(json['parentEventId']),
      originalStartAt: serializer.fromJson<DateTime?>(json['originalStartAt']),
      status: serializer.fromJson<String>(json['status']),
      availability: serializer.fromJson<String>(json['availability']),
      travelMinutes: serializer.fromJson<int?>(json['travelMinutes']),
      isPrivate: serializer.fromJson<bool>(json['isPrivate']),
      alertsJson: serializer.fromJson<String>(json['alertsJson']),
      inviteesJson: serializer.fromJson<String>(json['inviteesJson']),
      sequence: serializer.fromJson<int>(json['sequence']),
      revision: serializer.fromJson<int>(json['revision']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'calendarId': serializer.toJson<String>(calendarId),
      'uid': serializer.toJson<String>(uid),
      'title': serializer.toJson<String>(title),
      'location': serializer.toJson<String?>(location),
      'url': serializer.toJson<String?>(url),
      'notes': serializer.toJson<String?>(notes),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'allDay': serializer.toJson<bool>(allDay),
      'timeZone': serializer.toJson<String>(timeZone),
      'isFloating': serializer.toJson<bool>(isFloating),
      'rrule': serializer.toJson<String?>(rrule),
      'exdatesJson': serializer.toJson<String>(exdatesJson),
      'parentEventId': serializer.toJson<String?>(parentEventId),
      'originalStartAt': serializer.toJson<DateTime?>(originalStartAt),
      'status': serializer.toJson<String>(status),
      'availability': serializer.toJson<String>(availability),
      'travelMinutes': serializer.toJson<int?>(travelMinutes),
      'isPrivate': serializer.toJson<bool>(isPrivate),
      'alertsJson': serializer.toJson<String>(alertsJson),
      'inviteesJson': serializer.toJson<String>(inviteesJson),
      'sequence': serializer.toJson<int>(sequence),
      'revision': serializer.toJson<int>(revision),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CalendarEvent copyWith({
    String? id,
    Value<String?> remoteId = const Value.absent(),
    String? calendarId,
    String? uid,
    String? title,
    Value<String?> location = const Value.absent(),
    Value<String?> url = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    String? timeZone,
    bool? isFloating,
    Value<String?> rrule = const Value.absent(),
    String? exdatesJson,
    Value<String?> parentEventId = const Value.absent(),
    Value<DateTime?> originalStartAt = const Value.absent(),
    String? status,
    String? availability,
    Value<int?> travelMinutes = const Value.absent(),
    bool? isPrivate,
    String? alertsJson,
    String? inviteesJson,
    int? sequence,
    int? revision,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => CalendarEvent(
    id: id ?? this.id,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    calendarId: calendarId ?? this.calendarId,
    uid: uid ?? this.uid,
    title: title ?? this.title,
    location: location.present ? location.value : this.location,
    url: url.present ? url.value : this.url,
    notes: notes.present ? notes.value : this.notes,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    allDay: allDay ?? this.allDay,
    timeZone: timeZone ?? this.timeZone,
    isFloating: isFloating ?? this.isFloating,
    rrule: rrule.present ? rrule.value : this.rrule,
    exdatesJson: exdatesJson ?? this.exdatesJson,
    parentEventId: parentEventId.present
        ? parentEventId.value
        : this.parentEventId,
    originalStartAt: originalStartAt.present
        ? originalStartAt.value
        : this.originalStartAt,
    status: status ?? this.status,
    availability: availability ?? this.availability,
    travelMinutes: travelMinutes.present
        ? travelMinutes.value
        : this.travelMinutes,
    isPrivate: isPrivate ?? this.isPrivate,
    alertsJson: alertsJson ?? this.alertsJson,
    inviteesJson: inviteesJson ?? this.inviteesJson,
    sequence: sequence ?? this.sequence,
    revision: revision ?? this.revision,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CalendarEvent copyWithCompanion(CalendarEventsCompanion data) {
    return CalendarEvent(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      uid: data.uid.present ? data.uid.value : this.uid,
      title: data.title.present ? data.title.value : this.title,
      location: data.location.present ? data.location.value : this.location,
      url: data.url.present ? data.url.value : this.url,
      notes: data.notes.present ? data.notes.value : this.notes,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      isFloating: data.isFloating.present
          ? data.isFloating.value
          : this.isFloating,
      rrule: data.rrule.present ? data.rrule.value : this.rrule,
      exdatesJson: data.exdatesJson.present
          ? data.exdatesJson.value
          : this.exdatesJson,
      parentEventId: data.parentEventId.present
          ? data.parentEventId.value
          : this.parentEventId,
      originalStartAt: data.originalStartAt.present
          ? data.originalStartAt.value
          : this.originalStartAt,
      status: data.status.present ? data.status.value : this.status,
      availability: data.availability.present
          ? data.availability.value
          : this.availability,
      travelMinutes: data.travelMinutes.present
          ? data.travelMinutes.value
          : this.travelMinutes,
      isPrivate: data.isPrivate.present ? data.isPrivate.value : this.isPrivate,
      alertsJson: data.alertsJson.present
          ? data.alertsJson.value
          : this.alertsJson,
      inviteesJson: data.inviteesJson.present
          ? data.inviteesJson.value
          : this.inviteesJson,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      revision: data.revision.present ? data.revision.value : this.revision,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEvent(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('calendarId: $calendarId, ')
          ..write('uid: $uid, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('url: $url, ')
          ..write('notes: $notes, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('timeZone: $timeZone, ')
          ..write('isFloating: $isFloating, ')
          ..write('rrule: $rrule, ')
          ..write('exdatesJson: $exdatesJson, ')
          ..write('parentEventId: $parentEventId, ')
          ..write('originalStartAt: $originalStartAt, ')
          ..write('status: $status, ')
          ..write('availability: $availability, ')
          ..write('travelMinutes: $travelMinutes, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('alertsJson: $alertsJson, ')
          ..write('inviteesJson: $inviteesJson, ')
          ..write('sequence: $sequence, ')
          ..write('revision: $revision, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    exdatesJson,
    parentEventId,
    originalStartAt,
    status,
    availability,
    travelMinutes,
    isPrivate,
    alertsJson,
    inviteesJson,
    sequence,
    revision,
    deletedAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEvent &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.calendarId == this.calendarId &&
          other.uid == this.uid &&
          other.title == this.title &&
          other.location == this.location &&
          other.url == this.url &&
          other.notes == this.notes &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.allDay == this.allDay &&
          other.timeZone == this.timeZone &&
          other.isFloating == this.isFloating &&
          other.rrule == this.rrule &&
          other.exdatesJson == this.exdatesJson &&
          other.parentEventId == this.parentEventId &&
          other.originalStartAt == this.originalStartAt &&
          other.status == this.status &&
          other.availability == this.availability &&
          other.travelMinutes == this.travelMinutes &&
          other.isPrivate == this.isPrivate &&
          other.alertsJson == this.alertsJson &&
          other.inviteesJson == this.inviteesJson &&
          other.sequence == this.sequence &&
          other.revision == this.revision &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class CalendarEventsCompanion extends UpdateCompanion<CalendarEvent> {
  final Value<String> id;
  final Value<String?> remoteId;
  final Value<String> calendarId;
  final Value<String> uid;
  final Value<String> title;
  final Value<String?> location;
  final Value<String?> url;
  final Value<String?> notes;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<bool> allDay;
  final Value<String> timeZone;
  final Value<bool> isFloating;
  final Value<String?> rrule;
  final Value<String> exdatesJson;
  final Value<String?> parentEventId;
  final Value<DateTime?> originalStartAt;
  final Value<String> status;
  final Value<String> availability;
  final Value<int?> travelMinutes;
  final Value<bool> isPrivate;
  final Value<String> alertsJson;
  final Value<String> inviteesJson;
  final Value<int> sequence;
  final Value<int> revision;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CalendarEventsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.uid = const Value.absent(),
    this.title = const Value.absent(),
    this.location = const Value.absent(),
    this.url = const Value.absent(),
    this.notes = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.isFloating = const Value.absent(),
    this.rrule = const Value.absent(),
    this.exdatesJson = const Value.absent(),
    this.parentEventId = const Value.absent(),
    this.originalStartAt = const Value.absent(),
    this.status = const Value.absent(),
    this.availability = const Value.absent(),
    this.travelMinutes = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.alertsJson = const Value.absent(),
    this.inviteesJson = const Value.absent(),
    this.sequence = const Value.absent(),
    this.revision = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventsCompanion.insert({
    required String id,
    this.remoteId = const Value.absent(),
    required String calendarId,
    required String uid,
    required String title,
    this.location = const Value.absent(),
    this.url = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    this.allDay = const Value.absent(),
    required String timeZone,
    this.isFloating = const Value.absent(),
    this.rrule = const Value.absent(),
    this.exdatesJson = const Value.absent(),
    this.parentEventId = const Value.absent(),
    this.originalStartAt = const Value.absent(),
    this.status = const Value.absent(),
    this.availability = const Value.absent(),
    this.travelMinutes = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.alertsJson = const Value.absent(),
    this.inviteesJson = const Value.absent(),
    this.sequence = const Value.absent(),
    this.revision = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarId = Value(calendarId),
       uid = Value(uid),
       title = Value(title),
       startAt = Value(startAt),
       endAt = Value(endAt),
       timeZone = Value(timeZone),
       updatedAt = Value(updatedAt);
  static Insertable<CalendarEvent> custom({
    Expression<String>? id,
    Expression<String>? remoteId,
    Expression<String>? calendarId,
    Expression<String>? uid,
    Expression<String>? title,
    Expression<String>? location,
    Expression<String>? url,
    Expression<String>? notes,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<bool>? allDay,
    Expression<String>? timeZone,
    Expression<bool>? isFloating,
    Expression<String>? rrule,
    Expression<String>? exdatesJson,
    Expression<String>? parentEventId,
    Expression<DateTime>? originalStartAt,
    Expression<String>? status,
    Expression<String>? availability,
    Expression<int>? travelMinutes,
    Expression<bool>? isPrivate,
    Expression<String>? alertsJson,
    Expression<String>? inviteesJson,
    Expression<int>? sequence,
    Expression<int>? revision,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (calendarId != null) 'calendar_id': calendarId,
      if (uid != null) 'uid': uid,
      if (title != null) 'title': title,
      if (location != null) 'location': location,
      if (url != null) 'url': url,
      if (notes != null) 'notes': notes,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (allDay != null) 'all_day': allDay,
      if (timeZone != null) 'time_zone': timeZone,
      if (isFloating != null) 'is_floating': isFloating,
      if (rrule != null) 'rrule': rrule,
      if (exdatesJson != null) 'exdates_json': exdatesJson,
      if (parentEventId != null) 'parent_event_id': parentEventId,
      if (originalStartAt != null) 'original_start_at': originalStartAt,
      if (status != null) 'status': status,
      if (availability != null) 'availability': availability,
      if (travelMinutes != null) 'travel_minutes': travelMinutes,
      if (isPrivate != null) 'is_private': isPrivate,
      if (alertsJson != null) 'alerts_json': alertsJson,
      if (inviteesJson != null) 'invitees_json': inviteesJson,
      if (sequence != null) 'sequence': sequence,
      if (revision != null) 'revision': revision,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventsCompanion copyWith({
    Value<String>? id,
    Value<String?>? remoteId,
    Value<String>? calendarId,
    Value<String>? uid,
    Value<String>? title,
    Value<String?>? location,
    Value<String?>? url,
    Value<String?>? notes,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<bool>? allDay,
    Value<String>? timeZone,
    Value<bool>? isFloating,
    Value<String?>? rrule,
    Value<String>? exdatesJson,
    Value<String?>? parentEventId,
    Value<DateTime?>? originalStartAt,
    Value<String>? status,
    Value<String>? availability,
    Value<int?>? travelMinutes,
    Value<bool>? isPrivate,
    Value<String>? alertsJson,
    Value<String>? inviteesJson,
    Value<int>? sequence,
    Value<int>? revision,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CalendarEventsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      calendarId: calendarId ?? this.calendarId,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      location: location ?? this.location,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      timeZone: timeZone ?? this.timeZone,
      isFloating: isFloating ?? this.isFloating,
      rrule: rrule ?? this.rrule,
      exdatesJson: exdatesJson ?? this.exdatesJson,
      parentEventId: parentEventId ?? this.parentEventId,
      originalStartAt: originalStartAt ?? this.originalStartAt,
      status: status ?? this.status,
      availability: availability ?? this.availability,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      isPrivate: isPrivate ?? this.isPrivate,
      alertsJson: alertsJson ?? this.alertsJson,
      inviteesJson: inviteesJson ?? this.inviteesJson,
      sequence: sequence ?? this.sequence,
      revision: revision ?? this.revision,
      deletedAt: deletedAt ?? this.deletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (isFloating.present) {
      map['is_floating'] = Variable<bool>(isFloating.value);
    }
    if (rrule.present) {
      map['rrule'] = Variable<String>(rrule.value);
    }
    if (exdatesJson.present) {
      map['exdates_json'] = Variable<String>(exdatesJson.value);
    }
    if (parentEventId.present) {
      map['parent_event_id'] = Variable<String>(parentEventId.value);
    }
    if (originalStartAt.present) {
      map['original_start_at'] = Variable<DateTime>(originalStartAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    if (travelMinutes.present) {
      map['travel_minutes'] = Variable<int>(travelMinutes.value);
    }
    if (isPrivate.present) {
      map['is_private'] = Variable<bool>(isPrivate.value);
    }
    if (alertsJson.present) {
      map['alerts_json'] = Variable<String>(alertsJson.value);
    }
    if (inviteesJson.present) {
      map['invitees_json'] = Variable<String>(inviteesJson.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('calendarId: $calendarId, ')
          ..write('uid: $uid, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('url: $url, ')
          ..write('notes: $notes, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('timeZone: $timeZone, ')
          ..write('isFloating: $isFloating, ')
          ..write('rrule: $rrule, ')
          ..write('exdatesJson: $exdatesJson, ')
          ..write('parentEventId: $parentEventId, ')
          ..write('originalStartAt: $originalStartAt, ')
          ..write('status: $status, ')
          ..write('availability: $availability, ')
          ..write('travelMinutes: $travelMinutes, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('alertsJson: $alertsJson, ')
          ..write('inviteesJson: $inviteesJson, ')
          ..write('sequence: $sequence, ')
          ..write('revision: $revision, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarPreferencesTable extends CalendarPreferences
    with TableInfo<$CalendarPreferencesTable, CalendarPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userKeyMeta = const VerificationMeta(
    'userKey',
  );
  @override
  late final GeneratedColumn<String> userKey = GeneratedColumn<String>(
    'user_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultCalendarIdMeta = const VerificationMeta(
    'defaultCalendarId',
  );
  @override
  late final GeneratedColumn<String> defaultCalendarId =
      GeneratedColumn<String>(
        'default_calendar_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _startWeekOnMeta = const VerificationMeta(
    'startWeekOn',
  );
  @override
  late final GeneratedColumn<int> startWeekOn = GeneratedColumn<int>(
    'start_week_on',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _weekViewDaysMeta = const VerificationMeta(
    'weekViewDays',
  );
  @override
  late final GeneratedColumn<int> weekViewDays = GeneratedColumn<int>(
    'week_view_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7),
  );
  static const VerificationMeta _dayStartHourMeta = const VerificationMeta(
    'dayStartHour',
  );
  @override
  late final GeneratedColumn<int> dayStartHour = GeneratedColumn<int>(
    'day_start_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8),
  );
  static const VerificationMeta _dayEndHourMeta = const VerificationMeta(
    'dayEndHour',
  );
  @override
  late final GeneratedColumn<int> dayEndHour = GeneratedColumn<int>(
    'day_end_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(18),
  );
  static const VerificationMeta _hoursShownMeta = const VerificationMeta(
    'hoursShown',
  );
  @override
  late final GeneratedColumn<int> hoursShown = GeneratedColumn<int>(
    'hours_shown',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _showDeclinedEventsMeta =
      const VerificationMeta('showDeclinedEvents');
  @override
  late final GeneratedColumn<bool> showDeclinedEvents = GeneratedColumn<bool>(
    'show_declined_events',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_declined_events" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timeZoneSupportMeta = const VerificationMeta(
    'timeZoneSupport',
  );
  @override
  late final GeneratedColumn<bool> timeZoneSupport = GeneratedColumn<bool>(
    'time_zone_support',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("time_zone_support" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _displayTimeZoneMeta = const VerificationMeta(
    'displayTimeZone',
  );
  @override
  late final GeneratedColumn<String> displayTimeZone = GeneratedColumn<String>(
    'display_time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultAlertTimedMinutesMeta =
      const VerificationMeta('defaultAlertTimedMinutes');
  @override
  late final GeneratedColumn<int> defaultAlertTimedMinutes =
      GeneratedColumn<int>(
        'default_alert_timed_minutes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _defaultAlertAllDayDaysMeta =
      const VerificationMeta('defaultAlertAllDayDays');
  @override
  late final GeneratedColumn<int> defaultAlertAllDayDays = GeneratedColumn<int>(
    'default_alert_all_day_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultAlertAllDayTimeMeta =
      const VerificationMeta('defaultAlertAllDayTime');
  @override
  late final GeneratedColumn<String> defaultAlertAllDayTime =
      GeneratedColumn<String>(
        'default_alert_all_day_time',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('09:00'),
      );
  static const VerificationMeta _defaultDurationMinutesMeta =
      const VerificationMeta('defaultDurationMinutes');
  @override
  late final GeneratedColumn<int> defaultDurationMinutes = GeneratedColumn<int>(
    'default_duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _alternateCalendarMeta = const VerificationMeta(
    'alternateCalendar',
  );
  @override
  late final GeneratedColumn<String> alternateCalendar =
      GeneratedColumn<String>(
        'alternate_calendar',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('NONE'),
      );
  static const VerificationMeta _showWeekNumbersMeta = const VerificationMeta(
    'showWeekNumbers',
  );
  @override
  late final GeneratedColumn<bool> showWeekNumbers = GeneratedColumn<bool>(
    'show_week_numbers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_week_numbers" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _weekViewStartsTodayMeta =
      const VerificationMeta('weekViewStartsToday');
  @override
  late final GeneratedColumn<bool> weekViewStartsToday = GeneratedColumn<bool>(
    'week_view_starts_today',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("week_view_starts_today" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showHolidaysMeta = const VerificationMeta(
    'showHolidays',
  );
  @override
  late final GeneratedColumn<bool> showHolidays = GeneratedColumn<bool>(
    'show_holidays',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_holidays" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _openEventsInWindowMeta =
      const VerificationMeta('openEventsInWindow');
  @override
  late final GeneratedColumn<bool> openEventsInWindow = GeneratedColumn<bool>(
    'open_events_in_window',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("open_events_in_window" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    userKey,
    defaultCalendarId,
    startWeekOn,
    weekViewDays,
    dayStartHour,
    dayEndHour,
    hoursShown,
    showDeclinedEvents,
    timeZoneSupport,
    displayTimeZone,
    defaultAlertTimedMinutes,
    defaultAlertAllDayDays,
    defaultAlertAllDayTime,
    defaultDurationMinutes,
    alternateCalendar,
    showWeekNumbers,
    weekViewStartsToday,
    showHolidays,
    openEventsInWindow,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_key')) {
      context.handle(
        _userKeyMeta,
        userKey.isAcceptableOrUnknown(data['user_key']!, _userKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_userKeyMeta);
    }
    if (data.containsKey('default_calendar_id')) {
      context.handle(
        _defaultCalendarIdMeta,
        defaultCalendarId.isAcceptableOrUnknown(
          data['default_calendar_id']!,
          _defaultCalendarIdMeta,
        ),
      );
    }
    if (data.containsKey('start_week_on')) {
      context.handle(
        _startWeekOnMeta,
        startWeekOn.isAcceptableOrUnknown(
          data['start_week_on']!,
          _startWeekOnMeta,
        ),
      );
    }
    if (data.containsKey('week_view_days')) {
      context.handle(
        _weekViewDaysMeta,
        weekViewDays.isAcceptableOrUnknown(
          data['week_view_days']!,
          _weekViewDaysMeta,
        ),
      );
    }
    if (data.containsKey('day_start_hour')) {
      context.handle(
        _dayStartHourMeta,
        dayStartHour.isAcceptableOrUnknown(
          data['day_start_hour']!,
          _dayStartHourMeta,
        ),
      );
    }
    if (data.containsKey('day_end_hour')) {
      context.handle(
        _dayEndHourMeta,
        dayEndHour.isAcceptableOrUnknown(
          data['day_end_hour']!,
          _dayEndHourMeta,
        ),
      );
    }
    if (data.containsKey('hours_shown')) {
      context.handle(
        _hoursShownMeta,
        hoursShown.isAcceptableOrUnknown(data['hours_shown']!, _hoursShownMeta),
      );
    }
    if (data.containsKey('show_declined_events')) {
      context.handle(
        _showDeclinedEventsMeta,
        showDeclinedEvents.isAcceptableOrUnknown(
          data['show_declined_events']!,
          _showDeclinedEventsMeta,
        ),
      );
    }
    if (data.containsKey('time_zone_support')) {
      context.handle(
        _timeZoneSupportMeta,
        timeZoneSupport.isAcceptableOrUnknown(
          data['time_zone_support']!,
          _timeZoneSupportMeta,
        ),
      );
    }
    if (data.containsKey('display_time_zone')) {
      context.handle(
        _displayTimeZoneMeta,
        displayTimeZone.isAcceptableOrUnknown(
          data['display_time_zone']!,
          _displayTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('default_alert_timed_minutes')) {
      context.handle(
        _defaultAlertTimedMinutesMeta,
        defaultAlertTimedMinutes.isAcceptableOrUnknown(
          data['default_alert_timed_minutes']!,
          _defaultAlertTimedMinutesMeta,
        ),
      );
    }
    if (data.containsKey('default_alert_all_day_days')) {
      context.handle(
        _defaultAlertAllDayDaysMeta,
        defaultAlertAllDayDays.isAcceptableOrUnknown(
          data['default_alert_all_day_days']!,
          _defaultAlertAllDayDaysMeta,
        ),
      );
    }
    if (data.containsKey('default_alert_all_day_time')) {
      context.handle(
        _defaultAlertAllDayTimeMeta,
        defaultAlertAllDayTime.isAcceptableOrUnknown(
          data['default_alert_all_day_time']!,
          _defaultAlertAllDayTimeMeta,
        ),
      );
    }
    if (data.containsKey('default_duration_minutes')) {
      context.handle(
        _defaultDurationMinutesMeta,
        defaultDurationMinutes.isAcceptableOrUnknown(
          data['default_duration_minutes']!,
          _defaultDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('alternate_calendar')) {
      context.handle(
        _alternateCalendarMeta,
        alternateCalendar.isAcceptableOrUnknown(
          data['alternate_calendar']!,
          _alternateCalendarMeta,
        ),
      );
    }
    if (data.containsKey('show_week_numbers')) {
      context.handle(
        _showWeekNumbersMeta,
        showWeekNumbers.isAcceptableOrUnknown(
          data['show_week_numbers']!,
          _showWeekNumbersMeta,
        ),
      );
    }
    if (data.containsKey('week_view_starts_today')) {
      context.handle(
        _weekViewStartsTodayMeta,
        weekViewStartsToday.isAcceptableOrUnknown(
          data['week_view_starts_today']!,
          _weekViewStartsTodayMeta,
        ),
      );
    }
    if (data.containsKey('show_holidays')) {
      context.handle(
        _showHolidaysMeta,
        showHolidays.isAcceptableOrUnknown(
          data['show_holidays']!,
          _showHolidaysMeta,
        ),
      );
    }
    if (data.containsKey('open_events_in_window')) {
      context.handle(
        _openEventsInWindowMeta,
        openEventsInWindow.isAcceptableOrUnknown(
          data['open_events_in_window']!,
          _openEventsInWindowMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userKey};
  @override
  CalendarPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarPreference(
      userKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_key'],
      )!,
      defaultCalendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_calendar_id'],
      ),
      startWeekOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_week_on'],
      )!,
      weekViewDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week_view_days'],
      )!,
      dayStartHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_start_hour'],
      )!,
      dayEndHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_end_hour'],
      )!,
      hoursShown: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hours_shown'],
      )!,
      showDeclinedEvents: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_declined_events'],
      )!,
      timeZoneSupport: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}time_zone_support'],
      )!,
      displayTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_time_zone'],
      ),
      defaultAlertTimedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_alert_timed_minutes'],
      ),
      defaultAlertAllDayDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_alert_all_day_days'],
      ),
      defaultAlertAllDayTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_alert_all_day_time'],
      )!,
      defaultDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_duration_minutes'],
      )!,
      alternateCalendar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternate_calendar'],
      )!,
      showWeekNumbers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_week_numbers'],
      )!,
      weekViewStartsToday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}week_view_starts_today'],
      )!,
      showHolidays: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_holidays'],
      )!,
      openEventsInWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}open_events_in_window'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $CalendarPreferencesTable createAlias(String alias) {
    return $CalendarPreferencesTable(attachedDatabase, alias);
  }
}

class CalendarPreference extends DataClass
    implements Insertable<CalendarPreference> {
  final String userKey;
  final String? defaultCalendarId;
  final int startWeekOn;
  final int weekViewDays;
  final int dayStartHour;
  final int dayEndHour;
  final int hoursShown;
  final bool showDeclinedEvents;
  final bool timeZoneSupport;
  final String? displayTimeZone;
  final int? defaultAlertTimedMinutes;
  final int? defaultAlertAllDayDays;
  final String defaultAlertAllDayTime;
  final int defaultDurationMinutes;
  final String alternateCalendar;
  final bool showWeekNumbers;
  final bool weekViewStartsToday;
  final bool showHolidays;
  final bool openEventsInWindow;
  final int revision;
  const CalendarPreference({
    required this.userKey,
    this.defaultCalendarId,
    required this.startWeekOn,
    required this.weekViewDays,
    required this.dayStartHour,
    required this.dayEndHour,
    required this.hoursShown,
    required this.showDeclinedEvents,
    required this.timeZoneSupport,
    this.displayTimeZone,
    this.defaultAlertTimedMinutes,
    this.defaultAlertAllDayDays,
    required this.defaultAlertAllDayTime,
    required this.defaultDurationMinutes,
    required this.alternateCalendar,
    required this.showWeekNumbers,
    required this.weekViewStartsToday,
    required this.showHolidays,
    required this.openEventsInWindow,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_key'] = Variable<String>(userKey);
    if (!nullToAbsent || defaultCalendarId != null) {
      map['default_calendar_id'] = Variable<String>(defaultCalendarId);
    }
    map['start_week_on'] = Variable<int>(startWeekOn);
    map['week_view_days'] = Variable<int>(weekViewDays);
    map['day_start_hour'] = Variable<int>(dayStartHour);
    map['day_end_hour'] = Variable<int>(dayEndHour);
    map['hours_shown'] = Variable<int>(hoursShown);
    map['show_declined_events'] = Variable<bool>(showDeclinedEvents);
    map['time_zone_support'] = Variable<bool>(timeZoneSupport);
    if (!nullToAbsent || displayTimeZone != null) {
      map['display_time_zone'] = Variable<String>(displayTimeZone);
    }
    if (!nullToAbsent || defaultAlertTimedMinutes != null) {
      map['default_alert_timed_minutes'] = Variable<int>(
        defaultAlertTimedMinutes,
      );
    }
    if (!nullToAbsent || defaultAlertAllDayDays != null) {
      map['default_alert_all_day_days'] = Variable<int>(defaultAlertAllDayDays);
    }
    map['default_alert_all_day_time'] = Variable<String>(
      defaultAlertAllDayTime,
    );
    map['default_duration_minutes'] = Variable<int>(defaultDurationMinutes);
    map['alternate_calendar'] = Variable<String>(alternateCalendar);
    map['show_week_numbers'] = Variable<bool>(showWeekNumbers);
    map['week_view_starts_today'] = Variable<bool>(weekViewStartsToday);
    map['show_holidays'] = Variable<bool>(showHolidays);
    map['open_events_in_window'] = Variable<bool>(openEventsInWindow);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  CalendarPreferencesCompanion toCompanion(bool nullToAbsent) {
    return CalendarPreferencesCompanion(
      userKey: Value(userKey),
      defaultCalendarId: defaultCalendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultCalendarId),
      startWeekOn: Value(startWeekOn),
      weekViewDays: Value(weekViewDays),
      dayStartHour: Value(dayStartHour),
      dayEndHour: Value(dayEndHour),
      hoursShown: Value(hoursShown),
      showDeclinedEvents: Value(showDeclinedEvents),
      timeZoneSupport: Value(timeZoneSupport),
      displayTimeZone: displayTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(displayTimeZone),
      defaultAlertTimedMinutes: defaultAlertTimedMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAlertTimedMinutes),
      defaultAlertAllDayDays: defaultAlertAllDayDays == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAlertAllDayDays),
      defaultAlertAllDayTime: Value(defaultAlertAllDayTime),
      defaultDurationMinutes: Value(defaultDurationMinutes),
      alternateCalendar: Value(alternateCalendar),
      showWeekNumbers: Value(showWeekNumbers),
      weekViewStartsToday: Value(weekViewStartsToday),
      showHolidays: Value(showHolidays),
      openEventsInWindow: Value(openEventsInWindow),
      revision: Value(revision),
    );
  }

  factory CalendarPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarPreference(
      userKey: serializer.fromJson<String>(json['userKey']),
      defaultCalendarId: serializer.fromJson<String?>(
        json['defaultCalendarId'],
      ),
      startWeekOn: serializer.fromJson<int>(json['startWeekOn']),
      weekViewDays: serializer.fromJson<int>(json['weekViewDays']),
      dayStartHour: serializer.fromJson<int>(json['dayStartHour']),
      dayEndHour: serializer.fromJson<int>(json['dayEndHour']),
      hoursShown: serializer.fromJson<int>(json['hoursShown']),
      showDeclinedEvents: serializer.fromJson<bool>(json['showDeclinedEvents']),
      timeZoneSupport: serializer.fromJson<bool>(json['timeZoneSupport']),
      displayTimeZone: serializer.fromJson<String?>(json['displayTimeZone']),
      defaultAlertTimedMinutes: serializer.fromJson<int?>(
        json['defaultAlertTimedMinutes'],
      ),
      defaultAlertAllDayDays: serializer.fromJson<int?>(
        json['defaultAlertAllDayDays'],
      ),
      defaultAlertAllDayTime: serializer.fromJson<String>(
        json['defaultAlertAllDayTime'],
      ),
      defaultDurationMinutes: serializer.fromJson<int>(
        json['defaultDurationMinutes'],
      ),
      alternateCalendar: serializer.fromJson<String>(json['alternateCalendar']),
      showWeekNumbers: serializer.fromJson<bool>(json['showWeekNumbers']),
      weekViewStartsToday: serializer.fromJson<bool>(
        json['weekViewStartsToday'],
      ),
      showHolidays: serializer.fromJson<bool>(json['showHolidays']),
      openEventsInWindow: serializer.fromJson<bool>(json['openEventsInWindow']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userKey': serializer.toJson<String>(userKey),
      'defaultCalendarId': serializer.toJson<String?>(defaultCalendarId),
      'startWeekOn': serializer.toJson<int>(startWeekOn),
      'weekViewDays': serializer.toJson<int>(weekViewDays),
      'dayStartHour': serializer.toJson<int>(dayStartHour),
      'dayEndHour': serializer.toJson<int>(dayEndHour),
      'hoursShown': serializer.toJson<int>(hoursShown),
      'showDeclinedEvents': serializer.toJson<bool>(showDeclinedEvents),
      'timeZoneSupport': serializer.toJson<bool>(timeZoneSupport),
      'displayTimeZone': serializer.toJson<String?>(displayTimeZone),
      'defaultAlertTimedMinutes': serializer.toJson<int?>(
        defaultAlertTimedMinutes,
      ),
      'defaultAlertAllDayDays': serializer.toJson<int?>(defaultAlertAllDayDays),
      'defaultAlertAllDayTime': serializer.toJson<String>(
        defaultAlertAllDayTime,
      ),
      'defaultDurationMinutes': serializer.toJson<int>(defaultDurationMinutes),
      'alternateCalendar': serializer.toJson<String>(alternateCalendar),
      'showWeekNumbers': serializer.toJson<bool>(showWeekNumbers),
      'weekViewStartsToday': serializer.toJson<bool>(weekViewStartsToday),
      'showHolidays': serializer.toJson<bool>(showHolidays),
      'openEventsInWindow': serializer.toJson<bool>(openEventsInWindow),
      'revision': serializer.toJson<int>(revision),
    };
  }

  CalendarPreference copyWith({
    String? userKey,
    Value<String?> defaultCalendarId = const Value.absent(),
    int? startWeekOn,
    int? weekViewDays,
    int? dayStartHour,
    int? dayEndHour,
    int? hoursShown,
    bool? showDeclinedEvents,
    bool? timeZoneSupport,
    Value<String?> displayTimeZone = const Value.absent(),
    Value<int?> defaultAlertTimedMinutes = const Value.absent(),
    Value<int?> defaultAlertAllDayDays = const Value.absent(),
    String? defaultAlertAllDayTime,
    int? defaultDurationMinutes,
    String? alternateCalendar,
    bool? showWeekNumbers,
    bool? weekViewStartsToday,
    bool? showHolidays,
    bool? openEventsInWindow,
    int? revision,
  }) => CalendarPreference(
    userKey: userKey ?? this.userKey,
    defaultCalendarId: defaultCalendarId.present
        ? defaultCalendarId.value
        : this.defaultCalendarId,
    startWeekOn: startWeekOn ?? this.startWeekOn,
    weekViewDays: weekViewDays ?? this.weekViewDays,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    dayEndHour: dayEndHour ?? this.dayEndHour,
    hoursShown: hoursShown ?? this.hoursShown,
    showDeclinedEvents: showDeclinedEvents ?? this.showDeclinedEvents,
    timeZoneSupport: timeZoneSupport ?? this.timeZoneSupport,
    displayTimeZone: displayTimeZone.present
        ? displayTimeZone.value
        : this.displayTimeZone,
    defaultAlertTimedMinutes: defaultAlertTimedMinutes.present
        ? defaultAlertTimedMinutes.value
        : this.defaultAlertTimedMinutes,
    defaultAlertAllDayDays: defaultAlertAllDayDays.present
        ? defaultAlertAllDayDays.value
        : this.defaultAlertAllDayDays,
    defaultAlertAllDayTime:
        defaultAlertAllDayTime ?? this.defaultAlertAllDayTime,
    defaultDurationMinutes:
        defaultDurationMinutes ?? this.defaultDurationMinutes,
    alternateCalendar: alternateCalendar ?? this.alternateCalendar,
    showWeekNumbers: showWeekNumbers ?? this.showWeekNumbers,
    weekViewStartsToday: weekViewStartsToday ?? this.weekViewStartsToday,
    showHolidays: showHolidays ?? this.showHolidays,
    openEventsInWindow: openEventsInWindow ?? this.openEventsInWindow,
    revision: revision ?? this.revision,
  );
  CalendarPreference copyWithCompanion(CalendarPreferencesCompanion data) {
    return CalendarPreference(
      userKey: data.userKey.present ? data.userKey.value : this.userKey,
      defaultCalendarId: data.defaultCalendarId.present
          ? data.defaultCalendarId.value
          : this.defaultCalendarId,
      startWeekOn: data.startWeekOn.present
          ? data.startWeekOn.value
          : this.startWeekOn,
      weekViewDays: data.weekViewDays.present
          ? data.weekViewDays.value
          : this.weekViewDays,
      dayStartHour: data.dayStartHour.present
          ? data.dayStartHour.value
          : this.dayStartHour,
      dayEndHour: data.dayEndHour.present
          ? data.dayEndHour.value
          : this.dayEndHour,
      hoursShown: data.hoursShown.present
          ? data.hoursShown.value
          : this.hoursShown,
      showDeclinedEvents: data.showDeclinedEvents.present
          ? data.showDeclinedEvents.value
          : this.showDeclinedEvents,
      timeZoneSupport: data.timeZoneSupport.present
          ? data.timeZoneSupport.value
          : this.timeZoneSupport,
      displayTimeZone: data.displayTimeZone.present
          ? data.displayTimeZone.value
          : this.displayTimeZone,
      defaultAlertTimedMinutes: data.defaultAlertTimedMinutes.present
          ? data.defaultAlertTimedMinutes.value
          : this.defaultAlertTimedMinutes,
      defaultAlertAllDayDays: data.defaultAlertAllDayDays.present
          ? data.defaultAlertAllDayDays.value
          : this.defaultAlertAllDayDays,
      defaultAlertAllDayTime: data.defaultAlertAllDayTime.present
          ? data.defaultAlertAllDayTime.value
          : this.defaultAlertAllDayTime,
      defaultDurationMinutes: data.defaultDurationMinutes.present
          ? data.defaultDurationMinutes.value
          : this.defaultDurationMinutes,
      alternateCalendar: data.alternateCalendar.present
          ? data.alternateCalendar.value
          : this.alternateCalendar,
      showWeekNumbers: data.showWeekNumbers.present
          ? data.showWeekNumbers.value
          : this.showWeekNumbers,
      weekViewStartsToday: data.weekViewStartsToday.present
          ? data.weekViewStartsToday.value
          : this.weekViewStartsToday,
      showHolidays: data.showHolidays.present
          ? data.showHolidays.value
          : this.showHolidays,
      openEventsInWindow: data.openEventsInWindow.present
          ? data.openEventsInWindow.value
          : this.openEventsInWindow,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarPreference(')
          ..write('userKey: $userKey, ')
          ..write('defaultCalendarId: $defaultCalendarId, ')
          ..write('startWeekOn: $startWeekOn, ')
          ..write('weekViewDays: $weekViewDays, ')
          ..write('dayStartHour: $dayStartHour, ')
          ..write('dayEndHour: $dayEndHour, ')
          ..write('hoursShown: $hoursShown, ')
          ..write('showDeclinedEvents: $showDeclinedEvents, ')
          ..write('timeZoneSupport: $timeZoneSupport, ')
          ..write('displayTimeZone: $displayTimeZone, ')
          ..write('defaultAlertTimedMinutes: $defaultAlertTimedMinutes, ')
          ..write('defaultAlertAllDayDays: $defaultAlertAllDayDays, ')
          ..write('defaultAlertAllDayTime: $defaultAlertAllDayTime, ')
          ..write('defaultDurationMinutes: $defaultDurationMinutes, ')
          ..write('alternateCalendar: $alternateCalendar, ')
          ..write('showWeekNumbers: $showWeekNumbers, ')
          ..write('weekViewStartsToday: $weekViewStartsToday, ')
          ..write('showHolidays: $showHolidays, ')
          ..write('openEventsInWindow: $openEventsInWindow, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userKey,
    defaultCalendarId,
    startWeekOn,
    weekViewDays,
    dayStartHour,
    dayEndHour,
    hoursShown,
    showDeclinedEvents,
    timeZoneSupport,
    displayTimeZone,
    defaultAlertTimedMinutes,
    defaultAlertAllDayDays,
    defaultAlertAllDayTime,
    defaultDurationMinutes,
    alternateCalendar,
    showWeekNumbers,
    weekViewStartsToday,
    showHolidays,
    openEventsInWindow,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarPreference &&
          other.userKey == this.userKey &&
          other.defaultCalendarId == this.defaultCalendarId &&
          other.startWeekOn == this.startWeekOn &&
          other.weekViewDays == this.weekViewDays &&
          other.dayStartHour == this.dayStartHour &&
          other.dayEndHour == this.dayEndHour &&
          other.hoursShown == this.hoursShown &&
          other.showDeclinedEvents == this.showDeclinedEvents &&
          other.timeZoneSupport == this.timeZoneSupport &&
          other.displayTimeZone == this.displayTimeZone &&
          other.defaultAlertTimedMinutes == this.defaultAlertTimedMinutes &&
          other.defaultAlertAllDayDays == this.defaultAlertAllDayDays &&
          other.defaultAlertAllDayTime == this.defaultAlertAllDayTime &&
          other.defaultDurationMinutes == this.defaultDurationMinutes &&
          other.alternateCalendar == this.alternateCalendar &&
          other.showWeekNumbers == this.showWeekNumbers &&
          other.weekViewStartsToday == this.weekViewStartsToday &&
          other.showHolidays == this.showHolidays &&
          other.openEventsInWindow == this.openEventsInWindow &&
          other.revision == this.revision);
}

class CalendarPreferencesCompanion extends UpdateCompanion<CalendarPreference> {
  final Value<String> userKey;
  final Value<String?> defaultCalendarId;
  final Value<int> startWeekOn;
  final Value<int> weekViewDays;
  final Value<int> dayStartHour;
  final Value<int> dayEndHour;
  final Value<int> hoursShown;
  final Value<bool> showDeclinedEvents;
  final Value<bool> timeZoneSupport;
  final Value<String?> displayTimeZone;
  final Value<int?> defaultAlertTimedMinutes;
  final Value<int?> defaultAlertAllDayDays;
  final Value<String> defaultAlertAllDayTime;
  final Value<int> defaultDurationMinutes;
  final Value<String> alternateCalendar;
  final Value<bool> showWeekNumbers;
  final Value<bool> weekViewStartsToday;
  final Value<bool> showHolidays;
  final Value<bool> openEventsInWindow;
  final Value<int> revision;
  final Value<int> rowid;
  const CalendarPreferencesCompanion({
    this.userKey = const Value.absent(),
    this.defaultCalendarId = const Value.absent(),
    this.startWeekOn = const Value.absent(),
    this.weekViewDays = const Value.absent(),
    this.dayStartHour = const Value.absent(),
    this.dayEndHour = const Value.absent(),
    this.hoursShown = const Value.absent(),
    this.showDeclinedEvents = const Value.absent(),
    this.timeZoneSupport = const Value.absent(),
    this.displayTimeZone = const Value.absent(),
    this.defaultAlertTimedMinutes = const Value.absent(),
    this.defaultAlertAllDayDays = const Value.absent(),
    this.defaultAlertAllDayTime = const Value.absent(),
    this.defaultDurationMinutes = const Value.absent(),
    this.alternateCalendar = const Value.absent(),
    this.showWeekNumbers = const Value.absent(),
    this.weekViewStartsToday = const Value.absent(),
    this.showHolidays = const Value.absent(),
    this.openEventsInWindow = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarPreferencesCompanion.insert({
    required String userKey,
    this.defaultCalendarId = const Value.absent(),
    this.startWeekOn = const Value.absent(),
    this.weekViewDays = const Value.absent(),
    this.dayStartHour = const Value.absent(),
    this.dayEndHour = const Value.absent(),
    this.hoursShown = const Value.absent(),
    this.showDeclinedEvents = const Value.absent(),
    this.timeZoneSupport = const Value.absent(),
    this.displayTimeZone = const Value.absent(),
    this.defaultAlertTimedMinutes = const Value.absent(),
    this.defaultAlertAllDayDays = const Value.absent(),
    this.defaultAlertAllDayTime = const Value.absent(),
    this.defaultDurationMinutes = const Value.absent(),
    this.alternateCalendar = const Value.absent(),
    this.showWeekNumbers = const Value.absent(),
    this.weekViewStartsToday = const Value.absent(),
    this.showHolidays = const Value.absent(),
    this.openEventsInWindow = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userKey = Value(userKey);
  static Insertable<CalendarPreference> custom({
    Expression<String>? userKey,
    Expression<String>? defaultCalendarId,
    Expression<int>? startWeekOn,
    Expression<int>? weekViewDays,
    Expression<int>? dayStartHour,
    Expression<int>? dayEndHour,
    Expression<int>? hoursShown,
    Expression<bool>? showDeclinedEvents,
    Expression<bool>? timeZoneSupport,
    Expression<String>? displayTimeZone,
    Expression<int>? defaultAlertTimedMinutes,
    Expression<int>? defaultAlertAllDayDays,
    Expression<String>? defaultAlertAllDayTime,
    Expression<int>? defaultDurationMinutes,
    Expression<String>? alternateCalendar,
    Expression<bool>? showWeekNumbers,
    Expression<bool>? weekViewStartsToday,
    Expression<bool>? showHolidays,
    Expression<bool>? openEventsInWindow,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userKey != null) 'user_key': userKey,
      if (defaultCalendarId != null) 'default_calendar_id': defaultCalendarId,
      if (startWeekOn != null) 'start_week_on': startWeekOn,
      if (weekViewDays != null) 'week_view_days': weekViewDays,
      if (dayStartHour != null) 'day_start_hour': dayStartHour,
      if (dayEndHour != null) 'day_end_hour': dayEndHour,
      if (hoursShown != null) 'hours_shown': hoursShown,
      if (showDeclinedEvents != null)
        'show_declined_events': showDeclinedEvents,
      if (timeZoneSupport != null) 'time_zone_support': timeZoneSupport,
      if (displayTimeZone != null) 'display_time_zone': displayTimeZone,
      if (defaultAlertTimedMinutes != null)
        'default_alert_timed_minutes': defaultAlertTimedMinutes,
      if (defaultAlertAllDayDays != null)
        'default_alert_all_day_days': defaultAlertAllDayDays,
      if (defaultAlertAllDayTime != null)
        'default_alert_all_day_time': defaultAlertAllDayTime,
      if (defaultDurationMinutes != null)
        'default_duration_minutes': defaultDurationMinutes,
      if (alternateCalendar != null) 'alternate_calendar': alternateCalendar,
      if (showWeekNumbers != null) 'show_week_numbers': showWeekNumbers,
      if (weekViewStartsToday != null)
        'week_view_starts_today': weekViewStartsToday,
      if (showHolidays != null) 'show_holidays': showHolidays,
      if (openEventsInWindow != null)
        'open_events_in_window': openEventsInWindow,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarPreferencesCompanion copyWith({
    Value<String>? userKey,
    Value<String?>? defaultCalendarId,
    Value<int>? startWeekOn,
    Value<int>? weekViewDays,
    Value<int>? dayStartHour,
    Value<int>? dayEndHour,
    Value<int>? hoursShown,
    Value<bool>? showDeclinedEvents,
    Value<bool>? timeZoneSupport,
    Value<String?>? displayTimeZone,
    Value<int?>? defaultAlertTimedMinutes,
    Value<int?>? defaultAlertAllDayDays,
    Value<String>? defaultAlertAllDayTime,
    Value<int>? defaultDurationMinutes,
    Value<String>? alternateCalendar,
    Value<bool>? showWeekNumbers,
    Value<bool>? weekViewStartsToday,
    Value<bool>? showHolidays,
    Value<bool>? openEventsInWindow,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return CalendarPreferencesCompanion(
      userKey: userKey ?? this.userKey,
      defaultCalendarId: defaultCalendarId ?? this.defaultCalendarId,
      startWeekOn: startWeekOn ?? this.startWeekOn,
      weekViewDays: weekViewDays ?? this.weekViewDays,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      dayEndHour: dayEndHour ?? this.dayEndHour,
      hoursShown: hoursShown ?? this.hoursShown,
      showDeclinedEvents: showDeclinedEvents ?? this.showDeclinedEvents,
      timeZoneSupport: timeZoneSupport ?? this.timeZoneSupport,
      displayTimeZone: displayTimeZone ?? this.displayTimeZone,
      defaultAlertTimedMinutes:
          defaultAlertTimedMinutes ?? this.defaultAlertTimedMinutes,
      defaultAlertAllDayDays:
          defaultAlertAllDayDays ?? this.defaultAlertAllDayDays,
      defaultAlertAllDayTime:
          defaultAlertAllDayTime ?? this.defaultAlertAllDayTime,
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      alternateCalendar: alternateCalendar ?? this.alternateCalendar,
      showWeekNumbers: showWeekNumbers ?? this.showWeekNumbers,
      weekViewStartsToday: weekViewStartsToday ?? this.weekViewStartsToday,
      showHolidays: showHolidays ?? this.showHolidays,
      openEventsInWindow: openEventsInWindow ?? this.openEventsInWindow,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userKey.present) {
      map['user_key'] = Variable<String>(userKey.value);
    }
    if (defaultCalendarId.present) {
      map['default_calendar_id'] = Variable<String>(defaultCalendarId.value);
    }
    if (startWeekOn.present) {
      map['start_week_on'] = Variable<int>(startWeekOn.value);
    }
    if (weekViewDays.present) {
      map['week_view_days'] = Variable<int>(weekViewDays.value);
    }
    if (dayStartHour.present) {
      map['day_start_hour'] = Variable<int>(dayStartHour.value);
    }
    if (dayEndHour.present) {
      map['day_end_hour'] = Variable<int>(dayEndHour.value);
    }
    if (hoursShown.present) {
      map['hours_shown'] = Variable<int>(hoursShown.value);
    }
    if (showDeclinedEvents.present) {
      map['show_declined_events'] = Variable<bool>(showDeclinedEvents.value);
    }
    if (timeZoneSupport.present) {
      map['time_zone_support'] = Variable<bool>(timeZoneSupport.value);
    }
    if (displayTimeZone.present) {
      map['display_time_zone'] = Variable<String>(displayTimeZone.value);
    }
    if (defaultAlertTimedMinutes.present) {
      map['default_alert_timed_minutes'] = Variable<int>(
        defaultAlertTimedMinutes.value,
      );
    }
    if (defaultAlertAllDayDays.present) {
      map['default_alert_all_day_days'] = Variable<int>(
        defaultAlertAllDayDays.value,
      );
    }
    if (defaultAlertAllDayTime.present) {
      map['default_alert_all_day_time'] = Variable<String>(
        defaultAlertAllDayTime.value,
      );
    }
    if (defaultDurationMinutes.present) {
      map['default_duration_minutes'] = Variable<int>(
        defaultDurationMinutes.value,
      );
    }
    if (alternateCalendar.present) {
      map['alternate_calendar'] = Variable<String>(alternateCalendar.value);
    }
    if (showWeekNumbers.present) {
      map['show_week_numbers'] = Variable<bool>(showWeekNumbers.value);
    }
    if (weekViewStartsToday.present) {
      map['week_view_starts_today'] = Variable<bool>(weekViewStartsToday.value);
    }
    if (showHolidays.present) {
      map['show_holidays'] = Variable<bool>(showHolidays.value);
    }
    if (openEventsInWindow.present) {
      map['open_events_in_window'] = Variable<bool>(openEventsInWindow.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarPreferencesCompanion(')
          ..write('userKey: $userKey, ')
          ..write('defaultCalendarId: $defaultCalendarId, ')
          ..write('startWeekOn: $startWeekOn, ')
          ..write('weekViewDays: $weekViewDays, ')
          ..write('dayStartHour: $dayStartHour, ')
          ..write('dayEndHour: $dayEndHour, ')
          ..write('hoursShown: $hoursShown, ')
          ..write('showDeclinedEvents: $showDeclinedEvents, ')
          ..write('timeZoneSupport: $timeZoneSupport, ')
          ..write('displayTimeZone: $displayTimeZone, ')
          ..write('defaultAlertTimedMinutes: $defaultAlertTimedMinutes, ')
          ..write('defaultAlertAllDayDays: $defaultAlertAllDayDays, ')
          ..write('defaultAlertAllDayTime: $defaultAlertAllDayTime, ')
          ..write('defaultDurationMinutes: $defaultDurationMinutes, ')
          ..write('alternateCalendar: $alternateCalendar, ')
          ..write('showWeekNumbers: $showWeekNumbers, ')
          ..write('weekViewStartsToday: $weekViewStartsToday, ')
          ..write('showHolidays: $showHolidays, ')
          ..write('openEventsInWindow: $openEventsInWindow, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteFoldersTable extends NoteFolders
    with TableInfo<$NoteFoldersTable, NoteFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _smartMeta = const VerificationMeta('smart');
  @override
  late final GeneratedColumn<bool> smart = GeneratedColumn<bool>(
    'smart',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("smart" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _filterJsonMeta = const VerificationMeta(
    'filterJson',
  );
  @override
  late final GeneratedColumn<String> filterJson = GeneratedColumn<String>(
    'filter_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    remoteId,
    parentId,
    name,
    smart,
    filterJson,
    sortOrder,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('smart')) {
      context.handle(
        _smartMeta,
        smart.isAcceptableOrUnknown(data['smart']!, _smartMeta),
      );
    }
    if (data.containsKey('filter_json')) {
      context.handle(
        _filterJsonMeta,
        filterJson.isAcceptableOrUnknown(data['filter_json']!, _filterJsonMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      smart: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}smart'],
      )!,
      filterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_json'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $NoteFoldersTable createAlias(String alias) {
    return $NoteFoldersTable(attachedDatabase, alias);
  }
}

class NoteFolder extends DataClass implements Insertable<NoteFolder> {
  final String id;

  /// 服务端实体 ID（null = 纯本地未同步）。
  final String? remoteId;

  /// 父文件夹 id；null = 根。
  final String? parentId;
  final String name;

  /// 是否智能文件夹。
  final bool smart;

  /// 智能文件夹条件 JSON（仅 smart=true；键见契约 §1）。
  final String? filterJson;
  final int sortOrder;
  final DateTime? deletedAt;
  const NoteFolder({
    required this.id,
    this.remoteId,
    this.parentId,
    required this.name,
    required this.smart,
    this.filterJson,
    required this.sortOrder,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['smart'] = Variable<bool>(smart);
    if (!nullToAbsent || filterJson != null) {
      map['filter_json'] = Variable<String>(filterJson);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  NoteFoldersCompanion toCompanion(bool nullToAbsent) {
    return NoteFoldersCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      smart: Value(smart),
      filterJson: filterJson == null && nullToAbsent
          ? const Value.absent()
          : Value(filterJson),
      sortOrder: Value(sortOrder),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory NoteFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteFolder(
      id: serializer.fromJson<String>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      smart: serializer.fromJson<bool>(json['smart']),
      filterJson: serializer.fromJson<String?>(json['filterJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'smart': serializer.toJson<bool>(smart),
      'filterJson': serializer.toJson<String?>(filterJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  NoteFolder copyWith({
    String? id,
    Value<String?> remoteId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    String? name,
    bool? smart,
    Value<String?> filterJson = const Value.absent(),
    int? sortOrder,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => NoteFolder(
    id: id ?? this.id,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    smart: smart ?? this.smart,
    filterJson: filterJson.present ? filterJson.value : this.filterJson,
    sortOrder: sortOrder ?? this.sortOrder,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  NoteFolder copyWithCompanion(NoteFoldersCompanion data) {
    return NoteFolder(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      smart: data.smart.present ? data.smart.value : this.smart,
      filterJson: data.filterJson.present
          ? data.filterJson.value
          : this.filterJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteFolder(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('smart: $smart, ')
          ..write('filterJson: $filterJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    remoteId,
    parentId,
    name,
    smart,
    filterJson,
    sortOrder,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteFolder &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.smart == this.smart &&
          other.filterJson == this.filterJson &&
          other.sortOrder == this.sortOrder &&
          other.deletedAt == this.deletedAt);
}

class NoteFoldersCompanion extends UpdateCompanion<NoteFolder> {
  final Value<String> id;
  final Value<String?> remoteId;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<bool> smart;
  final Value<String?> filterJson;
  final Value<int> sortOrder;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const NoteFoldersCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.smart = const Value.absent(),
    this.filterJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteFoldersCompanion.insert({
    required String id,
    this.remoteId = const Value.absent(),
    this.parentId = const Value.absent(),
    required String name,
    this.smart = const Value.absent(),
    this.filterJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<NoteFolder> custom({
    Expression<String>? id,
    Expression<String>? remoteId,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<bool>? smart,
    Expression<String>? filterJson,
    Expression<int>? sortOrder,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (smart != null) 'smart': smart,
      if (filterJson != null) 'filter_json': filterJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteFoldersCompanion copyWith({
    Value<String>? id,
    Value<String?>? remoteId,
    Value<String?>? parentId,
    Value<String>? name,
    Value<bool>? smart,
    Value<String?>? filterJson,
    Value<int>? sortOrder,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return NoteFoldersCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      smart: smart ?? this.smart,
      filterJson: filterJson ?? this.filterJson,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (smart.present) {
      map['smart'] = Variable<bool>(smart.value);
    }
    if (filterJson.present) {
      map['filter_json'] = Variable<String>(filterJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteFoldersCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('smart: $smart, ')
          ..write('filterJson: $filterJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
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
  static const VerificationMeta _bodyDeltaMeta = const VerificationMeta(
    'bodyDelta',
  );
  @override
  late final GeneratedColumn<String> bodyDelta = GeneratedColumn<String>(
    'body_delta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyTextMeta = const VerificationMeta(
    'bodyText',
  );
  @override
  late final GeneratedColumn<String> bodyText = GeneratedColumn<String>(
    'body_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _checklistTotalMeta = const VerificationMeta(
    'checklistTotal',
  );
  @override
  late final GeneratedColumn<int> checklistTotal = GeneratedColumn<int>(
    'checklist_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _checklistDoneMeta = const VerificationMeta(
    'checklistDone',
  );
  @override
  late final GeneratedColumn<int> checklistDone = GeneratedColumn<int>(
    'checklist_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tagNamesMeta = const VerificationMeta(
    'tagNames',
  );
  @override
  late final GeneratedColumn<String> tagNames = GeneratedColumn<String>(
    'tag_names',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> clientUpdatedAt = GeneratedColumn<int>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    remoteId,
    folderId,
    title,
    bodyDelta,
    bodyText,
    pinned,
    locked,
    checklistTotal,
    checklistDone,
    tagNames,
    sortOrder,
    deletedAt,
    clientUpdatedAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body_delta')) {
      context.handle(
        _bodyDeltaMeta,
        bodyDelta.isAcceptableOrUnknown(data['body_delta']!, _bodyDeltaMeta),
      );
    }
    if (data.containsKey('body_text')) {
      context.handle(
        _bodyTextMeta,
        bodyText.isAcceptableOrUnknown(data['body_text']!, _bodyTextMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('checklist_total')) {
      context.handle(
        _checklistTotalMeta,
        checklistTotal.isAcceptableOrUnknown(
          data['checklist_total']!,
          _checklistTotalMeta,
        ),
      );
    }
    if (data.containsKey('checklist_done')) {
      context.handle(
        _checklistDoneMeta,
        checklistDone.isAcceptableOrUnknown(
          data['checklist_done']!,
          _checklistDoneMeta,
        ),
      );
    }
    if (data.containsKey('tag_names')) {
      context.handle(
        _tagNamesMeta,
        tagNames.isAcceptableOrUnknown(data['tag_names']!, _tagNamesMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      bodyDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_delta'],
      )!,
      bodyText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_text'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      checklistTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checklist_total'],
      )!,
      checklistDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checklist_done'],
      )!,
      tagNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_names'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_updated_at'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;

  /// 服务端实体 ID（null = 纯本地未同步）。
  final String? remoteId;
  final String folderId;
  final String title;
  final String bodyDelta;
  final String bodyText;
  final bool pinned;
  final bool locked;
  final int checklistTotal;
  final int checklistDone;

  /// 标签 JSON 数组文本（如 '["工作"]'；空存 '[]'）。
  final String tagNames;
  final int sortOrder;
  final DateTime? deletedAt;

  /// 客户端更新时间戳（毫秒）。
  final int clientUpdatedAt;

  /// 乐观锁版本。
  final int revision;
  const Note({
    required this.id,
    this.remoteId,
    required this.folderId,
    required this.title,
    required this.bodyDelta,
    required this.bodyText,
    required this.pinned,
    required this.locked,
    required this.checklistTotal,
    required this.checklistDone,
    required this.tagNames,
    required this.sortOrder,
    this.deletedAt,
    required this.clientUpdatedAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['folder_id'] = Variable<String>(folderId);
    map['title'] = Variable<String>(title);
    map['body_delta'] = Variable<String>(bodyDelta);
    map['body_text'] = Variable<String>(bodyText);
    map['pinned'] = Variable<bool>(pinned);
    map['locked'] = Variable<bool>(locked);
    map['checklist_total'] = Variable<int>(checklistTotal);
    map['checklist_done'] = Variable<int>(checklistDone);
    map['tag_names'] = Variable<String>(tagNames);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['client_updated_at'] = Variable<int>(clientUpdatedAt);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      folderId: Value(folderId),
      title: Value(title),
      bodyDelta: Value(bodyDelta),
      bodyText: Value(bodyText),
      pinned: Value(pinned),
      locked: Value(locked),
      checklistTotal: Value(checklistTotal),
      checklistDone: Value(checklistDone),
      tagNames: Value(tagNames),
      sortOrder: Value(sortOrder),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      clientUpdatedAt: Value(clientUpdatedAt),
      revision: Value(revision),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      folderId: serializer.fromJson<String>(json['folderId']),
      title: serializer.fromJson<String>(json['title']),
      bodyDelta: serializer.fromJson<String>(json['bodyDelta']),
      bodyText: serializer.fromJson<String>(json['bodyText']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      locked: serializer.fromJson<bool>(json['locked']),
      checklistTotal: serializer.fromJson<int>(json['checklistTotal']),
      checklistDone: serializer.fromJson<int>(json['checklistDone']),
      tagNames: serializer.fromJson<String>(json['tagNames']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      clientUpdatedAt: serializer.fromJson<int>(json['clientUpdatedAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'folderId': serializer.toJson<String>(folderId),
      'title': serializer.toJson<String>(title),
      'bodyDelta': serializer.toJson<String>(bodyDelta),
      'bodyText': serializer.toJson<String>(bodyText),
      'pinned': serializer.toJson<bool>(pinned),
      'locked': serializer.toJson<bool>(locked),
      'checklistTotal': serializer.toJson<int>(checklistTotal),
      'checklistDone': serializer.toJson<int>(checklistDone),
      'tagNames': serializer.toJson<String>(tagNames),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'clientUpdatedAt': serializer.toJson<int>(clientUpdatedAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  Note copyWith({
    String? id,
    Value<String?> remoteId = const Value.absent(),
    String? folderId,
    String? title,
    String? bodyDelta,
    String? bodyText,
    bool? pinned,
    bool? locked,
    int? checklistTotal,
    int? checklistDone,
    String? tagNames,
    int? sortOrder,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? clientUpdatedAt,
    int? revision,
  }) => Note(
    id: id ?? this.id,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    folderId: folderId ?? this.folderId,
    title: title ?? this.title,
    bodyDelta: bodyDelta ?? this.bodyDelta,
    bodyText: bodyText ?? this.bodyText,
    pinned: pinned ?? this.pinned,
    locked: locked ?? this.locked,
    checklistTotal: checklistTotal ?? this.checklistTotal,
    checklistDone: checklistDone ?? this.checklistDone,
    tagNames: tagNames ?? this.tagNames,
    sortOrder: sortOrder ?? this.sortOrder,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    revision: revision ?? this.revision,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      title: data.title.present ? data.title.value : this.title,
      bodyDelta: data.bodyDelta.present ? data.bodyDelta.value : this.bodyDelta,
      bodyText: data.bodyText.present ? data.bodyText.value : this.bodyText,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      locked: data.locked.present ? data.locked.value : this.locked,
      checklistTotal: data.checklistTotal.present
          ? data.checklistTotal.value
          : this.checklistTotal,
      checklistDone: data.checklistDone.present
          ? data.checklistDone.value
          : this.checklistDone,
      tagNames: data.tagNames.present ? data.tagNames.value : this.tagNames,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('bodyDelta: $bodyDelta, ')
          ..write('bodyText: $bodyText, ')
          ..write('pinned: $pinned, ')
          ..write('locked: $locked, ')
          ..write('checklistTotal: $checklistTotal, ')
          ..write('checklistDone: $checklistDone, ')
          ..write('tagNames: $tagNames, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    remoteId,
    folderId,
    title,
    bodyDelta,
    bodyText,
    pinned,
    locked,
    checklistTotal,
    checklistDone,
    tagNames,
    sortOrder,
    deletedAt,
    clientUpdatedAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.folderId == this.folderId &&
          other.title == this.title &&
          other.bodyDelta == this.bodyDelta &&
          other.bodyText == this.bodyText &&
          other.pinned == this.pinned &&
          other.locked == this.locked &&
          other.checklistTotal == this.checklistTotal &&
          other.checklistDone == this.checklistDone &&
          other.tagNames == this.tagNames &&
          other.sortOrder == this.sortOrder &&
          other.deletedAt == this.deletedAt &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.revision == this.revision);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String?> remoteId;
  final Value<String> folderId;
  final Value<String> title;
  final Value<String> bodyDelta;
  final Value<String> bodyText;
  final Value<bool> pinned;
  final Value<bool> locked;
  final Value<int> checklistTotal;
  final Value<int> checklistDone;
  final Value<String> tagNames;
  final Value<int> sortOrder;
  final Value<DateTime?> deletedAt;
  final Value<int> clientUpdatedAt;
  final Value<int> revision;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.title = const Value.absent(),
    this.bodyDelta = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.pinned = const Value.absent(),
    this.locked = const Value.absent(),
    this.checklistTotal = const Value.absent(),
    this.checklistDone = const Value.absent(),
    this.tagNames = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    this.remoteId = const Value.absent(),
    required String folderId,
    required String title,
    this.bodyDelta = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.pinned = const Value.absent(),
    this.locked = const Value.absent(),
    this.checklistTotal = const Value.absent(),
    this.checklistDone = const Value.absent(),
    this.tagNames = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       folderId = Value(folderId),
       title = Value(title);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? remoteId,
    Expression<String>? folderId,
    Expression<String>? title,
    Expression<String>? bodyDelta,
    Expression<String>? bodyText,
    Expression<bool>? pinned,
    Expression<bool>? locked,
    Expression<int>? checklistTotal,
    Expression<int>? checklistDone,
    Expression<String>? tagNames,
    Expression<int>? sortOrder,
    Expression<DateTime>? deletedAt,
    Expression<int>? clientUpdatedAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (folderId != null) 'folder_id': folderId,
      if (title != null) 'title': title,
      if (bodyDelta != null) 'body_delta': bodyDelta,
      if (bodyText != null) 'body_text': bodyText,
      if (pinned != null) 'pinned': pinned,
      if (locked != null) 'locked': locked,
      if (checklistTotal != null) 'checklist_total': checklistTotal,
      if (checklistDone != null) 'checklist_done': checklistDone,
      if (tagNames != null) 'tag_names': tagNames,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String?>? remoteId,
    Value<String>? folderId,
    Value<String>? title,
    Value<String>? bodyDelta,
    Value<String>? bodyText,
    Value<bool>? pinned,
    Value<bool>? locked,
    Value<int>? checklistTotal,
    Value<int>? checklistDone,
    Value<String>? tagNames,
    Value<int>? sortOrder,
    Value<DateTime?>? deletedAt,
    Value<int>? clientUpdatedAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      bodyDelta: bodyDelta ?? this.bodyDelta,
      bodyText: bodyText ?? this.bodyText,
      pinned: pinned ?? this.pinned,
      locked: locked ?? this.locked,
      checklistTotal: checklistTotal ?? this.checklistTotal,
      checklistDone: checklistDone ?? this.checklistDone,
      tagNames: tagNames ?? this.tagNames,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: deletedAt ?? this.deletedAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (bodyDelta.present) {
      map['body_delta'] = Variable<String>(bodyDelta.value);
    }
    if (bodyText.present) {
      map['body_text'] = Variable<String>(bodyText.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (checklistTotal.present) {
      map['checklist_total'] = Variable<int>(checklistTotal.value);
    }
    if (checklistDone.present) {
      map['checklist_done'] = Variable<int>(checklistDone.value);
    }
    if (tagNames.present) {
      map['tag_names'] = Variable<String>(tagNames.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<int>(clientUpdatedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('bodyDelta: $bodyDelta, ')
          ..write('bodyText: $bodyText, ')
          ..write('pinned: $pinned, ')
          ..write('locked: $locked, ')
          ..write('checklistTotal: $checklistTotal, ')
          ..write('checklistDone: $checklistDone, ')
          ..write('tagNames: $tagNames, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('revision: $revision, ')
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
  late final $CalendarsTable calendars = $CalendarsTable(this);
  late final $CalendarEventsTable calendarEvents = $CalendarEventsTable(this);
  late final $CalendarPreferencesTable calendarPreferences =
      $CalendarPreferencesTable(this);
  late final $NoteFoldersTable noteFolders = $NoteFoldersTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final Index idxCalendarEventsCalStart = Index(
    'idx_calendar_events_cal_start',
    'CREATE INDEX idx_calendar_events_cal_start ON calendar_events (calendar_id, start_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    reminderLists,
    reminderItems,
    calendars,
    calendarEvents,
    calendarPreferences,
    noteFolders,
    notes,
    idxCalendarEventsCalStart,
  ];
}

typedef $$ReminderListsTableCreateCompanionBuilder =
    ReminderListsCompanion Function({
      required String id,
      required String title,
      Value<int> colorArgb,
      Value<bool> isSmart,
      Value<int> sortOrder,
      Value<String?> sectionsJson,
      Value<String?> groupName,
      Value<String?> listType,
      Value<String?> smartFilter,
      Value<int> rowid,
    });
typedef $$ReminderListsTableUpdateCompanionBuilder =
    ReminderListsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> colorArgb,
      Value<bool> isSmart,
      Value<int> sortOrder,
      Value<String?> sectionsJson,
      Value<String?> groupName,
      Value<String?> listType,
      Value<String?> smartFilter,
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionsJson => $composableBuilder(
    column: $table.sectionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listType => $composableBuilder(
    column: $table.listType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smartFilter => $composableBuilder(
    column: $table.smartFilter,
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionsJson => $composableBuilder(
    column: $table.sectionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listType => $composableBuilder(
    column: $table.listType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smartFilter => $composableBuilder(
    column: $table.smartFilter,
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get sectionsJson => $composableBuilder(
    column: $table.sectionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get listType =>
      $composableBuilder(column: $table.listType, builder: (column) => column);

  GeneratedColumn<String> get smartFilter => $composableBuilder(
    column: $table.smartFilter,
    builder: (column) => column,
  );
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
                Value<int> sortOrder = const Value.absent(),
                Value<String?> sectionsJson = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String?> listType = const Value.absent(),
                Value<String?> smartFilter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderListsCompanion(
                id: id,
                title: title,
                colorArgb: colorArgb,
                isSmart: isSmart,
                sortOrder: sortOrder,
                sectionsJson: sectionsJson,
                groupName: groupName,
                listType: listType,
                smartFilter: smartFilter,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<int> colorArgb = const Value.absent(),
                Value<bool> isSmart = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> sectionsJson = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String?> listType = const Value.absent(),
                Value<String?> smartFilter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderListsCompanion.insert(
                id: id,
                title: title,
                colorArgb: colorArgb,
                isSmart: isSmart,
                sortOrder: sortOrder,
                sectionsJson: sectionsJson,
                groupName: groupName,
                listType: listType,
                smartFilter: smartFilter,
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
      Value<String> tags,
      Value<String?> recurrence,
      Value<DateTime?> recurrenceUntil,
      Value<String?> parentId,
      Value<int> sortOrder,
      Value<String?> remoteId,
      Value<DateTime?> completedAt,
      Value<String?> sectionId,
      Value<DateTime?> deletedAt,
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
      Value<String> tags,
      Value<String?> recurrence,
      Value<DateTime?> recurrenceUntil,
      Value<String?> parentId,
      Value<int> sortOrder,
      Value<String?> remoteId,
      Value<DateTime?> completedAt,
      Value<String?> sectionId,
      Value<DateTime?> deletedAt,
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

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
                Value<String> tags = const Value.absent(),
                Value<String?> recurrence = const Value.absent(),
                Value<DateTime?> recurrenceUntil = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
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
                tags: tags,
                recurrence: recurrence,
                recurrenceUntil: recurrenceUntil,
                parentId: parentId,
                sortOrder: sortOrder,
                remoteId: remoteId,
                completedAt: completedAt,
                sectionId: sectionId,
                deletedAt: deletedAt,
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
                Value<String> tags = const Value.absent(),
                Value<String?> recurrence = const Value.absent(),
                Value<DateTime?> recurrenceUntil = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> sectionId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
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
                tags: tags,
                recurrence: recurrence,
                recurrenceUntil: recurrenceUntil,
                parentId: parentId,
                sortOrder: sortOrder,
                remoteId: remoteId,
                completedAt: completedAt,
                sectionId: sectionId,
                deletedAt: deletedAt,
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
typedef $$CalendarsTableCreateCompanionBuilder =
    CalendarsCompanion Function({
      required String id,
      Value<String?> remoteId,
      required String title,
      required int colorArgb,
      Value<String> kind,
      Value<String?> groupName,
      Value<bool> isVisible,
      Value<bool> isDefault,
      Value<int> sortOrder,
      Value<bool> ignoreAlerts,
      Value<String?> sourceUrl,
      Value<int?> refreshMinutes,
      Value<String?> holidayRegion,
      Value<String?> lastRefreshError,
      Value<String> permission,
      Value<int> revision,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CalendarsTableUpdateCompanionBuilder =
    CalendarsCompanion Function({
      Value<String> id,
      Value<String?> remoteId,
      Value<String> title,
      Value<int> colorArgb,
      Value<String> kind,
      Value<String?> groupName,
      Value<bool> isVisible,
      Value<bool> isDefault,
      Value<int> sortOrder,
      Value<bool> ignoreAlerts,
      Value<String?> sourceUrl,
      Value<int?> refreshMinutes,
      Value<String?> holidayRegion,
      Value<String?> lastRefreshError,
      Value<String> permission,
      Value<int> revision,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CalendarsTableFilterComposer
    extends Composer<_$LifeProductivityDb, $CalendarsTable> {
  $$CalendarsTableFilterComposer({
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

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ignoreAlerts => $composableBuilder(
    column: $table.ignoreAlerts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refreshMinutes => $composableBuilder(
    column: $table.refreshMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holidayRegion => $composableBuilder(
    column: $table.holidayRegion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRefreshError => $composableBuilder(
    column: $table.lastRefreshError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarsTableOrderingComposer
    extends Composer<_$LifeProductivityDb, $CalendarsTable> {
  $$CalendarsTableOrderingComposer({
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

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ignoreAlerts => $composableBuilder(
    column: $table.ignoreAlerts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refreshMinutes => $composableBuilder(
    column: $table.refreshMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holidayRegion => $composableBuilder(
    column: $table.holidayRegion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRefreshError => $composableBuilder(
    column: $table.lastRefreshError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarsTableAnnotationComposer
    extends Composer<_$LifeProductivityDb, $CalendarsTable> {
  $$CalendarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<bool> get isVisible =>
      $composableBuilder(column: $table.isVisible, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get ignoreAlerts => $composableBuilder(
    column: $table.ignoreAlerts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<int> get refreshMinutes => $composableBuilder(
    column: $table.refreshMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get holidayRegion => $composableBuilder(
    column: $table.holidayRegion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastRefreshError => $composableBuilder(
    column: $table.lastRefreshError,
    builder: (column) => column,
  );

  GeneratedColumn<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CalendarsTableTableManager
    extends
        RootTableManager<
          _$LifeProductivityDb,
          $CalendarsTable,
          Calendar,
          $$CalendarsTableFilterComposer,
          $$CalendarsTableOrderingComposer,
          $$CalendarsTableAnnotationComposer,
          $$CalendarsTableCreateCompanionBuilder,
          $$CalendarsTableUpdateCompanionBuilder,
          (
            Calendar,
            BaseReferences<_$LifeProductivityDb, $CalendarsTable, Calendar>,
          ),
          Calendar,
          PrefetchHooks Function()
        > {
  $$CalendarsTableTableManager(_$LifeProductivityDb db, $CalendarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> colorArgb = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> ignoreAlerts = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<int?> refreshMinutes = const Value.absent(),
                Value<String?> holidayRegion = const Value.absent(),
                Value<String?> lastRefreshError = const Value.absent(),
                Value<String> permission = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarsCompanion(
                id: id,
                remoteId: remoteId,
                title: title,
                colorArgb: colorArgb,
                kind: kind,
                groupName: groupName,
                isVisible: isVisible,
                isDefault: isDefault,
                sortOrder: sortOrder,
                ignoreAlerts: ignoreAlerts,
                sourceUrl: sourceUrl,
                refreshMinutes: refreshMinutes,
                holidayRegion: holidayRegion,
                lastRefreshError: lastRefreshError,
                permission: permission,
                revision: revision,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> remoteId = const Value.absent(),
                required String title,
                required int colorArgb,
                Value<String> kind = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> ignoreAlerts = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<int?> refreshMinutes = const Value.absent(),
                Value<String?> holidayRegion = const Value.absent(),
                Value<String?> lastRefreshError = const Value.absent(),
                Value<String> permission = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarsCompanion.insert(
                id: id,
                remoteId: remoteId,
                title: title,
                colorArgb: colorArgb,
                kind: kind,
                groupName: groupName,
                isVisible: isVisible,
                isDefault: isDefault,
                sortOrder: sortOrder,
                ignoreAlerts: ignoreAlerts,
                sourceUrl: sourceUrl,
                refreshMinutes: refreshMinutes,
                holidayRegion: holidayRegion,
                lastRefreshError: lastRefreshError,
                permission: permission,
                revision: revision,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalendarsTable, Calendar>(table),
                  BaseReferences<
                    _$LifeProductivityDb,
                    $CalendarsTable,
                    Calendar
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarsTableProcessedTableManager =
    ProcessedTableManager<
      _$LifeProductivityDb,
      $CalendarsTable,
      Calendar,
      $$CalendarsTableFilterComposer,
      $$CalendarsTableOrderingComposer,
      $$CalendarsTableAnnotationComposer,
      $$CalendarsTableCreateCompanionBuilder,
      $$CalendarsTableUpdateCompanionBuilder,
      (
        Calendar,
        BaseReferences<_$LifeProductivityDb, $CalendarsTable, Calendar>,
      ),
      Calendar,
      PrefetchHooks Function()
    >;
typedef $$CalendarEventsTableCreateCompanionBuilder =
    CalendarEventsCompanion Function({
      required String id,
      Value<String?> remoteId,
      required String calendarId,
      required String uid,
      required String title,
      Value<String?> location,
      Value<String?> url,
      Value<String?> notes,
      required DateTime startAt,
      required DateTime endAt,
      Value<bool> allDay,
      required String timeZone,
      Value<bool> isFloating,
      Value<String?> rrule,
      Value<String> exdatesJson,
      Value<String?> parentEventId,
      Value<DateTime?> originalStartAt,
      Value<String> status,
      Value<String> availability,
      Value<int?> travelMinutes,
      Value<bool> isPrivate,
      Value<String> alertsJson,
      Value<String> inviteesJson,
      Value<int> sequence,
      Value<int> revision,
      Value<DateTime?> deletedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CalendarEventsTableUpdateCompanionBuilder =
    CalendarEventsCompanion Function({
      Value<String> id,
      Value<String?> remoteId,
      Value<String> calendarId,
      Value<String> uid,
      Value<String> title,
      Value<String?> location,
      Value<String?> url,
      Value<String?> notes,
      Value<DateTime> startAt,
      Value<DateTime> endAt,
      Value<bool> allDay,
      Value<String> timeZone,
      Value<bool> isFloating,
      Value<String?> rrule,
      Value<String> exdatesJson,
      Value<String?> parentEventId,
      Value<DateTime?> originalStartAt,
      Value<String> status,
      Value<String> availability,
      Value<int?> travelMinutes,
      Value<bool> isPrivate,
      Value<String> alertsJson,
      Value<String> inviteesJson,
      Value<int> sequence,
      Value<int> revision,
      Value<DateTime?> deletedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CalendarEventsTableFilterComposer
    extends Composer<_$LifeProductivityDb, $CalendarEventsTable> {
  $$CalendarEventsTableFilterComposer({
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

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFloating => $composableBuilder(
    column: $table.isFloating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rrule => $composableBuilder(
    column: $table.rrule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exdatesJson => $composableBuilder(
    column: $table.exdatesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentEventId => $composableBuilder(
    column: $table.parentEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get originalStartAt => $composableBuilder(
    column: $table.originalStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get travelMinutes => $composableBuilder(
    column: $table.travelMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alertsJson => $composableBuilder(
    column: $table.alertsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inviteesJson => $composableBuilder(
    column: $table.inviteesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarEventsTableOrderingComposer
    extends Composer<_$LifeProductivityDb, $CalendarEventsTable> {
  $$CalendarEventsTableOrderingComposer({
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

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFloating => $composableBuilder(
    column: $table.isFloating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rrule => $composableBuilder(
    column: $table.rrule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exdatesJson => $composableBuilder(
    column: $table.exdatesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentEventId => $composableBuilder(
    column: $table.parentEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get originalStartAt => $composableBuilder(
    column: $table.originalStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get travelMinutes => $composableBuilder(
    column: $table.travelMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alertsJson => $composableBuilder(
    column: $table.alertsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inviteesJson => $composableBuilder(
    column: $table.inviteesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarEventsTableAnnotationComposer
    extends Composer<_$LifeProductivityDb, $CalendarEventsTable> {
  $$CalendarEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<bool> get isFloating => $composableBuilder(
    column: $table.isFloating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rrule =>
      $composableBuilder(column: $table.rrule, builder: (column) => column);

  GeneratedColumn<String> get exdatesJson => $composableBuilder(
    column: $table.exdatesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentEventId => $composableBuilder(
    column: $table.parentEventId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get originalStartAt => $composableBuilder(
    column: $table.originalStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => column,
  );

  GeneratedColumn<int> get travelMinutes => $composableBuilder(
    column: $table.travelMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrivate =>
      $composableBuilder(column: $table.isPrivate, builder: (column) => column);

  GeneratedColumn<String> get alertsJson => $composableBuilder(
    column: $table.alertsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inviteesJson => $composableBuilder(
    column: $table.inviteesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CalendarEventsTableTableManager
    extends
        RootTableManager<
          _$LifeProductivityDb,
          $CalendarEventsTable,
          CalendarEvent,
          $$CalendarEventsTableFilterComposer,
          $$CalendarEventsTableOrderingComposer,
          $$CalendarEventsTableAnnotationComposer,
          $$CalendarEventsTableCreateCompanionBuilder,
          $$CalendarEventsTableUpdateCompanionBuilder,
          (
            CalendarEvent,
            BaseReferences<
              _$LifeProductivityDb,
              $CalendarEventsTable,
              CalendarEvent
            >,
          ),
          CalendarEvent,
          PrefetchHooks Function()
        > {
  $$CalendarEventsTableTableManager(
    _$LifeProductivityDb db,
    $CalendarEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String> calendarId = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<bool> isFloating = const Value.absent(),
                Value<String?> rrule = const Value.absent(),
                Value<String> exdatesJson = const Value.absent(),
                Value<String?> parentEventId = const Value.absent(),
                Value<DateTime?> originalStartAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<int?> travelMinutes = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<String> alertsJson = const Value.absent(),
                Value<String> inviteesJson = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventsCompanion(
                id: id,
                remoteId: remoteId,
                calendarId: calendarId,
                uid: uid,
                title: title,
                location: location,
                url: url,
                notes: notes,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                timeZone: timeZone,
                isFloating: isFloating,
                rrule: rrule,
                exdatesJson: exdatesJson,
                parentEventId: parentEventId,
                originalStartAt: originalStartAt,
                status: status,
                availability: availability,
                travelMinutes: travelMinutes,
                isPrivate: isPrivate,
                alertsJson: alertsJson,
                inviteesJson: inviteesJson,
                sequence: sequence,
                revision: revision,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> remoteId = const Value.absent(),
                required String calendarId,
                required String uid,
                required String title,
                Value<String?> location = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime startAt,
                required DateTime endAt,
                Value<bool> allDay = const Value.absent(),
                required String timeZone,
                Value<bool> isFloating = const Value.absent(),
                Value<String?> rrule = const Value.absent(),
                Value<String> exdatesJson = const Value.absent(),
                Value<String?> parentEventId = const Value.absent(),
                Value<DateTime?> originalStartAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<int?> travelMinutes = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<String> alertsJson = const Value.absent(),
                Value<String> inviteesJson = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventsCompanion.insert(
                id: id,
                remoteId: remoteId,
                calendarId: calendarId,
                uid: uid,
                title: title,
                location: location,
                url: url,
                notes: notes,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                timeZone: timeZone,
                isFloating: isFloating,
                rrule: rrule,
                exdatesJson: exdatesJson,
                parentEventId: parentEventId,
                originalStartAt: originalStartAt,
                status: status,
                availability: availability,
                travelMinutes: travelMinutes,
                isPrivate: isPrivate,
                alertsJson: alertsJson,
                inviteesJson: inviteesJson,
                sequence: sequence,
                revision: revision,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalendarEventsTable, CalendarEvent>(table),
                  BaseReferences<
                    _$LifeProductivityDb,
                    $CalendarEventsTable,
                    CalendarEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$LifeProductivityDb,
      $CalendarEventsTable,
      CalendarEvent,
      $$CalendarEventsTableFilterComposer,
      $$CalendarEventsTableOrderingComposer,
      $$CalendarEventsTableAnnotationComposer,
      $$CalendarEventsTableCreateCompanionBuilder,
      $$CalendarEventsTableUpdateCompanionBuilder,
      (
        CalendarEvent,
        BaseReferences<
          _$LifeProductivityDb,
          $CalendarEventsTable,
          CalendarEvent
        >,
      ),
      CalendarEvent,
      PrefetchHooks Function()
    >;
typedef $$CalendarPreferencesTableCreateCompanionBuilder =
    CalendarPreferencesCompanion Function({
      required String userKey,
      Value<String?> defaultCalendarId,
      Value<int> startWeekOn,
      Value<int> weekViewDays,
      Value<int> dayStartHour,
      Value<int> dayEndHour,
      Value<int> hoursShown,
      Value<bool> showDeclinedEvents,
      Value<bool> timeZoneSupport,
      Value<String?> displayTimeZone,
      Value<int?> defaultAlertTimedMinutes,
      Value<int?> defaultAlertAllDayDays,
      Value<String> defaultAlertAllDayTime,
      Value<int> defaultDurationMinutes,
      Value<String> alternateCalendar,
      Value<bool> showWeekNumbers,
      Value<bool> weekViewStartsToday,
      Value<bool> showHolidays,
      Value<bool> openEventsInWindow,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$CalendarPreferencesTableUpdateCompanionBuilder =
    CalendarPreferencesCompanion Function({
      Value<String> userKey,
      Value<String?> defaultCalendarId,
      Value<int> startWeekOn,
      Value<int> weekViewDays,
      Value<int> dayStartHour,
      Value<int> dayEndHour,
      Value<int> hoursShown,
      Value<bool> showDeclinedEvents,
      Value<bool> timeZoneSupport,
      Value<String?> displayTimeZone,
      Value<int?> defaultAlertTimedMinutes,
      Value<int?> defaultAlertAllDayDays,
      Value<String> defaultAlertAllDayTime,
      Value<int> defaultDurationMinutes,
      Value<String> alternateCalendar,
      Value<bool> showWeekNumbers,
      Value<bool> weekViewStartsToday,
      Value<bool> showHolidays,
      Value<bool> openEventsInWindow,
      Value<int> revision,
      Value<int> rowid,
    });

class $$CalendarPreferencesTableFilterComposer
    extends Composer<_$LifeProductivityDb, $CalendarPreferencesTable> {
  $$CalendarPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userKey => $composableBuilder(
    column: $table.userKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultCalendarId => $composableBuilder(
    column: $table.defaultCalendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startWeekOn => $composableBuilder(
    column: $table.startWeekOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekViewDays => $composableBuilder(
    column: $table.weekViewDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayStartHour => $composableBuilder(
    column: $table.dayStartHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayEndHour => $composableBuilder(
    column: $table.dayEndHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hoursShown => $composableBuilder(
    column: $table.hoursShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showDeclinedEvents => $composableBuilder(
    column: $table.showDeclinedEvents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get timeZoneSupport => $composableBuilder(
    column: $table.timeZoneSupport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayTimeZone => $composableBuilder(
    column: $table.displayTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultAlertTimedMinutes => $composableBuilder(
    column: $table.defaultAlertTimedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultAlertAllDayDays => $composableBuilder(
    column: $table.defaultAlertAllDayDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultAlertAllDayTime => $composableBuilder(
    column: $table.defaultAlertAllDayTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultDurationMinutes => $composableBuilder(
    column: $table.defaultDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternateCalendar => $composableBuilder(
    column: $table.alternateCalendar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showWeekNumbers => $composableBuilder(
    column: $table.showWeekNumbers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get weekViewStartsToday => $composableBuilder(
    column: $table.weekViewStartsToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showHolidays => $composableBuilder(
    column: $table.showHolidays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get openEventsInWindow => $composableBuilder(
    column: $table.openEventsInWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarPreferencesTableOrderingComposer
    extends Composer<_$LifeProductivityDb, $CalendarPreferencesTable> {
  $$CalendarPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userKey => $composableBuilder(
    column: $table.userKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCalendarId => $composableBuilder(
    column: $table.defaultCalendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startWeekOn => $composableBuilder(
    column: $table.startWeekOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekViewDays => $composableBuilder(
    column: $table.weekViewDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayStartHour => $composableBuilder(
    column: $table.dayStartHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayEndHour => $composableBuilder(
    column: $table.dayEndHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hoursShown => $composableBuilder(
    column: $table.hoursShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showDeclinedEvents => $composableBuilder(
    column: $table.showDeclinedEvents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get timeZoneSupport => $composableBuilder(
    column: $table.timeZoneSupport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayTimeZone => $composableBuilder(
    column: $table.displayTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultAlertTimedMinutes => $composableBuilder(
    column: $table.defaultAlertTimedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultAlertAllDayDays => $composableBuilder(
    column: $table.defaultAlertAllDayDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultAlertAllDayTime => $composableBuilder(
    column: $table.defaultAlertAllDayTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultDurationMinutes => $composableBuilder(
    column: $table.defaultDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternateCalendar => $composableBuilder(
    column: $table.alternateCalendar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showWeekNumbers => $composableBuilder(
    column: $table.showWeekNumbers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get weekViewStartsToday => $composableBuilder(
    column: $table.weekViewStartsToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showHolidays => $composableBuilder(
    column: $table.showHolidays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get openEventsInWindow => $composableBuilder(
    column: $table.openEventsInWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarPreferencesTableAnnotationComposer
    extends Composer<_$LifeProductivityDb, $CalendarPreferencesTable> {
  $$CalendarPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userKey =>
      $composableBuilder(column: $table.userKey, builder: (column) => column);

  GeneratedColumn<String> get defaultCalendarId => $composableBuilder(
    column: $table.defaultCalendarId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startWeekOn => $composableBuilder(
    column: $table.startWeekOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekViewDays => $composableBuilder(
    column: $table.weekViewDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayStartHour => $composableBuilder(
    column: $table.dayStartHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayEndHour => $composableBuilder(
    column: $table.dayEndHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hoursShown => $composableBuilder(
    column: $table.hoursShown,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showDeclinedEvents => $composableBuilder(
    column: $table.showDeclinedEvents,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get timeZoneSupport => $composableBuilder(
    column: $table.timeZoneSupport,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayTimeZone => $composableBuilder(
    column: $table.displayTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultAlertTimedMinutes => $composableBuilder(
    column: $table.defaultAlertTimedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultAlertAllDayDays => $composableBuilder(
    column: $table.defaultAlertAllDayDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultAlertAllDayTime => $composableBuilder(
    column: $table.defaultAlertAllDayTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultDurationMinutes => $composableBuilder(
    column: $table.defaultDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alternateCalendar => $composableBuilder(
    column: $table.alternateCalendar,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showWeekNumbers => $composableBuilder(
    column: $table.showWeekNumbers,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get weekViewStartsToday => $composableBuilder(
    column: $table.weekViewStartsToday,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showHolidays => $composableBuilder(
    column: $table.showHolidays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get openEventsInWindow => $composableBuilder(
    column: $table.openEventsInWindow,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$CalendarPreferencesTableTableManager
    extends
        RootTableManager<
          _$LifeProductivityDb,
          $CalendarPreferencesTable,
          CalendarPreference,
          $$CalendarPreferencesTableFilterComposer,
          $$CalendarPreferencesTableOrderingComposer,
          $$CalendarPreferencesTableAnnotationComposer,
          $$CalendarPreferencesTableCreateCompanionBuilder,
          $$CalendarPreferencesTableUpdateCompanionBuilder,
          (
            CalendarPreference,
            BaseReferences<
              _$LifeProductivityDb,
              $CalendarPreferencesTable,
              CalendarPreference
            >,
          ),
          CalendarPreference,
          PrefetchHooks Function()
        > {
  $$CalendarPreferencesTableTableManager(
    _$LifeProductivityDb db,
    $CalendarPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalendarPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userKey = const Value.absent(),
                Value<String?> defaultCalendarId = const Value.absent(),
                Value<int> startWeekOn = const Value.absent(),
                Value<int> weekViewDays = const Value.absent(),
                Value<int> dayStartHour = const Value.absent(),
                Value<int> dayEndHour = const Value.absent(),
                Value<int> hoursShown = const Value.absent(),
                Value<bool> showDeclinedEvents = const Value.absent(),
                Value<bool> timeZoneSupport = const Value.absent(),
                Value<String?> displayTimeZone = const Value.absent(),
                Value<int?> defaultAlertTimedMinutes = const Value.absent(),
                Value<int?> defaultAlertAllDayDays = const Value.absent(),
                Value<String> defaultAlertAllDayTime = const Value.absent(),
                Value<int> defaultDurationMinutes = const Value.absent(),
                Value<String> alternateCalendar = const Value.absent(),
                Value<bool> showWeekNumbers = const Value.absent(),
                Value<bool> weekViewStartsToday = const Value.absent(),
                Value<bool> showHolidays = const Value.absent(),
                Value<bool> openEventsInWindow = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarPreferencesCompanion(
                userKey: userKey,
                defaultCalendarId: defaultCalendarId,
                startWeekOn: startWeekOn,
                weekViewDays: weekViewDays,
                dayStartHour: dayStartHour,
                dayEndHour: dayEndHour,
                hoursShown: hoursShown,
                showDeclinedEvents: showDeclinedEvents,
                timeZoneSupport: timeZoneSupport,
                displayTimeZone: displayTimeZone,
                defaultAlertTimedMinutes: defaultAlertTimedMinutes,
                defaultAlertAllDayDays: defaultAlertAllDayDays,
                defaultAlertAllDayTime: defaultAlertAllDayTime,
                defaultDurationMinutes: defaultDurationMinutes,
                alternateCalendar: alternateCalendar,
                showWeekNumbers: showWeekNumbers,
                weekViewStartsToday: weekViewStartsToday,
                showHolidays: showHolidays,
                openEventsInWindow: openEventsInWindow,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userKey,
                Value<String?> defaultCalendarId = const Value.absent(),
                Value<int> startWeekOn = const Value.absent(),
                Value<int> weekViewDays = const Value.absent(),
                Value<int> dayStartHour = const Value.absent(),
                Value<int> dayEndHour = const Value.absent(),
                Value<int> hoursShown = const Value.absent(),
                Value<bool> showDeclinedEvents = const Value.absent(),
                Value<bool> timeZoneSupport = const Value.absent(),
                Value<String?> displayTimeZone = const Value.absent(),
                Value<int?> defaultAlertTimedMinutes = const Value.absent(),
                Value<int?> defaultAlertAllDayDays = const Value.absent(),
                Value<String> defaultAlertAllDayTime = const Value.absent(),
                Value<int> defaultDurationMinutes = const Value.absent(),
                Value<String> alternateCalendar = const Value.absent(),
                Value<bool> showWeekNumbers = const Value.absent(),
                Value<bool> weekViewStartsToday = const Value.absent(),
                Value<bool> showHolidays = const Value.absent(),
                Value<bool> openEventsInWindow = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarPreferencesCompanion.insert(
                userKey: userKey,
                defaultCalendarId: defaultCalendarId,
                startWeekOn: startWeekOn,
                weekViewDays: weekViewDays,
                dayStartHour: dayStartHour,
                dayEndHour: dayEndHour,
                hoursShown: hoursShown,
                showDeclinedEvents: showDeclinedEvents,
                timeZoneSupport: timeZoneSupport,
                displayTimeZone: displayTimeZone,
                defaultAlertTimedMinutes: defaultAlertTimedMinutes,
                defaultAlertAllDayDays: defaultAlertAllDayDays,
                defaultAlertAllDayTime: defaultAlertAllDayTime,
                defaultDurationMinutes: defaultDurationMinutes,
                alternateCalendar: alternateCalendar,
                showWeekNumbers: showWeekNumbers,
                weekViewStartsToday: weekViewStartsToday,
                showHolidays: showHolidays,
                openEventsInWindow: openEventsInWindow,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalendarPreferencesTable, CalendarPreference>(
                    table,
                  ),
                  BaseReferences<
                    _$LifeProductivityDb,
                    $CalendarPreferencesTable,
                    CalendarPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$LifeProductivityDb,
      $CalendarPreferencesTable,
      CalendarPreference,
      $$CalendarPreferencesTableFilterComposer,
      $$CalendarPreferencesTableOrderingComposer,
      $$CalendarPreferencesTableAnnotationComposer,
      $$CalendarPreferencesTableCreateCompanionBuilder,
      $$CalendarPreferencesTableUpdateCompanionBuilder,
      (
        CalendarPreference,
        BaseReferences<
          _$LifeProductivityDb,
          $CalendarPreferencesTable,
          CalendarPreference
        >,
      ),
      CalendarPreference,
      PrefetchHooks Function()
    >;
typedef $$NoteFoldersTableCreateCompanionBuilder =
    NoteFoldersCompanion Function({
      required String id,
      Value<String?> remoteId,
      Value<String?> parentId,
      required String name,
      Value<bool> smart,
      Value<String?> filterJson,
      Value<int> sortOrder,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$NoteFoldersTableUpdateCompanionBuilder =
    NoteFoldersCompanion Function({
      Value<String> id,
      Value<String?> remoteId,
      Value<String?> parentId,
      Value<String> name,
      Value<bool> smart,
      Value<String?> filterJson,
      Value<int> sortOrder,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$NoteFoldersTableFilterComposer
    extends Composer<_$LifeProductivityDb, $NoteFoldersTable> {
  $$NoteFoldersTableFilterComposer({
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

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get smart => $composableBuilder(
    column: $table.smart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteFoldersTableOrderingComposer
    extends Composer<_$LifeProductivityDb, $NoteFoldersTable> {
  $$NoteFoldersTableOrderingComposer({
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

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get smart => $composableBuilder(
    column: $table.smart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteFoldersTableAnnotationComposer
    extends Composer<_$LifeProductivityDb, $NoteFoldersTable> {
  $$NoteFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get smart =>
      $composableBuilder(column: $table.smart, builder: (column) => column);

  GeneratedColumn<String> get filterJson => $composableBuilder(
    column: $table.filterJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$NoteFoldersTableTableManager
    extends
        RootTableManager<
          _$LifeProductivityDb,
          $NoteFoldersTable,
          NoteFolder,
          $$NoteFoldersTableFilterComposer,
          $$NoteFoldersTableOrderingComposer,
          $$NoteFoldersTableAnnotationComposer,
          $$NoteFoldersTableCreateCompanionBuilder,
          $$NoteFoldersTableUpdateCompanionBuilder,
          (
            NoteFolder,
            BaseReferences<_$LifeProductivityDb, $NoteFoldersTable, NoteFolder>,
          ),
          NoteFolder,
          PrefetchHooks Function()
        > {
  $$NoteFoldersTableTableManager(
    _$LifeProductivityDb db,
    $NoteFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> smart = const Value.absent(),
                Value<String?> filterJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteFoldersCompanion(
                id: id,
                remoteId: remoteId,
                parentId: parentId,
                name: name,
                smart: smart,
                filterJson: filterJson,
                sortOrder: sortOrder,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> remoteId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<bool> smart = const Value.absent(),
                Value<String?> filterJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteFoldersCompanion.insert(
                id: id,
                remoteId: remoteId,
                parentId: parentId,
                name: name,
                smart: smart,
                filterJson: filterJson,
                sortOrder: sortOrder,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteFoldersTable, NoteFolder>(table),
                  BaseReferences<
                    _$LifeProductivityDb,
                    $NoteFoldersTable,
                    NoteFolder
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$LifeProductivityDb,
      $NoteFoldersTable,
      NoteFolder,
      $$NoteFoldersTableFilterComposer,
      $$NoteFoldersTableOrderingComposer,
      $$NoteFoldersTableAnnotationComposer,
      $$NoteFoldersTableCreateCompanionBuilder,
      $$NoteFoldersTableUpdateCompanionBuilder,
      (
        NoteFolder,
        BaseReferences<_$LifeProductivityDb, $NoteFoldersTable, NoteFolder>,
      ),
      NoteFolder,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      Value<String?> remoteId,
      required String folderId,
      required String title,
      Value<String> bodyDelta,
      Value<String> bodyText,
      Value<bool> pinned,
      Value<bool> locked,
      Value<int> checklistTotal,
      Value<int> checklistDone,
      Value<String> tagNames,
      Value<int> sortOrder,
      Value<DateTime?> deletedAt,
      Value<int> clientUpdatedAt,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String?> remoteId,
      Value<String> folderId,
      Value<String> title,
      Value<String> bodyDelta,
      Value<String> bodyText,
      Value<bool> pinned,
      Value<bool> locked,
      Value<int> checklistTotal,
      Value<int> checklistDone,
      Value<String> tagNames,
      Value<int> sortOrder,
      Value<DateTime?> deletedAt,
      Value<int> clientUpdatedAt,
      Value<int> revision,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer
    extends Composer<_$LifeProductivityDb, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyDelta => $composableBuilder(
    column: $table.bodyDelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checklistTotal => $composableBuilder(
    column: $table.checklistTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checklistDone => $composableBuilder(
    column: $table.checklistDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagNames => $composableBuilder(
    column: $table.tagNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$LifeProductivityDb, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyDelta => $composableBuilder(
    column: $table.bodyDelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checklistTotal => $composableBuilder(
    column: $table.checklistTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checklistDone => $composableBuilder(
    column: $table.checklistDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagNames => $composableBuilder(
    column: $table.tagNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$LifeProductivityDb, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get bodyDelta =>
      $composableBuilder(column: $table.bodyDelta, builder: (column) => column);

  GeneratedColumn<String> get bodyText =>
      $composableBuilder(column: $table.bodyText, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<int> get checklistTotal => $composableBuilder(
    column: $table.checklistTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get checklistDone => $composableBuilder(
    column: $table.checklistDone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagNames =>
      $composableBuilder(column: $table.tagNames, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$LifeProductivityDb,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$LifeProductivityDb, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$LifeProductivityDb db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String> folderId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> bodyDelta = const Value.absent(),
                Value<String> bodyText = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<int> checklistTotal = const Value.absent(),
                Value<int> checklistDone = const Value.absent(),
                Value<String> tagNames = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> clientUpdatedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                remoteId: remoteId,
                folderId: folderId,
                title: title,
                bodyDelta: bodyDelta,
                bodyText: bodyText,
                pinned: pinned,
                locked: locked,
                checklistTotal: checklistTotal,
                checklistDone: checklistDone,
                tagNames: tagNames,
                sortOrder: sortOrder,
                deletedAt: deletedAt,
                clientUpdatedAt: clientUpdatedAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> remoteId = const Value.absent(),
                required String folderId,
                required String title,
                Value<String> bodyDelta = const Value.absent(),
                Value<String> bodyText = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<int> checklistTotal = const Value.absent(),
                Value<int> checklistDone = const Value.absent(),
                Value<String> tagNames = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> clientUpdatedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                remoteId: remoteId,
                folderId: folderId,
                title: title,
                bodyDelta: bodyDelta,
                bodyText: bodyText,
                pinned: pinned,
                locked: locked,
                checklistTotal: checklistTotal,
                checklistDone: checklistDone,
                tagNames: tagNames,
                sortOrder: sortOrder,
                deletedAt: deletedAt,
                clientUpdatedAt: clientUpdatedAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, Note>(table),
                  BaseReferences<_$LifeProductivityDb, $NotesTable, Note>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$LifeProductivityDb,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$LifeProductivityDb, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;

class $LifeProductivityDbManager {
  final _$LifeProductivityDb _db;
  $LifeProductivityDbManager(this._db);
  $$ReminderListsTableTableManager get reminderLists =>
      $$ReminderListsTableTableManager(_db, _db.reminderLists);
  $$ReminderItemsTableTableManager get reminderItems =>
      $$ReminderItemsTableTableManager(_db, _db.reminderItems);
  $$CalendarsTableTableManager get calendars =>
      $$CalendarsTableTableManager(_db, _db.calendars);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(_db, _db.calendarEvents);
  $$CalendarPreferencesTableTableManager get calendarPreferences =>
      $$CalendarPreferencesTableTableManager(_db, _db.calendarPreferences);
  $$NoteFoldersTableTableManager get noteFolders =>
      $$NoteFoldersTableTableManager(_db, _db.noteFolders);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
}
