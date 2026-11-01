import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/list_query.dart';
import '../models/permissions.dart';
import '../repositories/entity_repository.dart';
import '../repositories/repos.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/form_fields.dart';

/// Столбец таблицы; в карточке показывается как «подпись: значение».
class ColumnSpec<T> {
  final String label;
  final String Function(T) value;
  final bool numeric;
  final bool inCard;
  final Widget Function(BuildContext, T)? cell;

  const ColumnSpec(
    this.label,
    this.value, {
    this.numeric = false,
    this.inCard = true,
    this.cell,
  });
}

/// Всё, что отличает одну сущность от другой на типовых экранах: список,
/// карточка, форма. Сами экраны одни на все сущности.
class EntityConfig<T extends Entity> {
  /// Адрес раздела, например `/cars`; карточка — `/cars/<id>`, форма — `/cars/new`.
  final String path;
  final String title;
  final String singular;
  final String key;
  final EntityRepository<T> Function(Repos) repo;
  final List<ColumnSpec<T>> columns;

  /// Варианты сортировки; первый — сортировка по умолчанию.
  final List<(String, String)> sorts;
  final List<FieldSpec> fields;

  /// Право на создание, изменение и логическое удаление; null — только чтение.
  final Permission? manage;

  /// Право на восстановление и физическое удаление.
  final Permission? purge;
  final String Function(T) cardTitle;
  final String Function(T) cardSubtitle;
  final List<(String, String Function(T))> details;
  final Widget Function(BuildContext, T, VoidCallback reload)? detailExtra;
  final Map<String, dynamic> Function(Map<String, dynamic> json, bool isNew)?
  prepare;

  /// Справочники, которые нужно перечитать после изменения этой сущности.
  final List<String> lookups;
  final bool hasDetail;
  final bool hasForm;

  /// Можно ли изменять созданную запись (сделки и договоры — нет).
  final bool canEdit;

  const EntityConfig({
    required this.key,
    required this.path,
    required this.title,
    required this.singular,
    required this.repo,
    required this.columns,
    required this.sorts,
    required this.cardTitle,
    required this.cardSubtitle,
    this.fields = const [],
    this.manage,
    this.purge = Permission.viewTrash,
    this.details = const [],
    this.detailExtra,
    this.prepare,
    this.lookups = const [],
    this.hasDetail = true,
    this.hasForm = true,
    this.canEdit = true,
  });

  /// Та же сущность в разделе клиента: только просмотр своих записей.
  EntityConfig<T> asClientView(String newPath, String newTitle) =>
      EntityConfig<T>(
        key: 'my-$key',
        path: newPath,
        title: newTitle,
        singular: singular,
        repo: repo,
        columns: columns,
        sorts: sorts,
        cardTitle: cardTitle,
        cardSubtitle: cardSubtitle,
        details: details,
        detailExtra: detailExtra,
        purge: null,
        hasForm: false,
      );

  /// Список удалённых записей этой сущности (раздел «Корзина»).
  Widget trashView({
    required ListQuery query,
    required ValueChanged<ListQuery> onQuery,
  }) => EntityListView<T>(
    key: ValueKey('trash-$key'),
    config: this,
    query: query,
    onQuery: onQuery,
    trash: true,
  );

  String get newPath => '$path/new';
  String detailPath(T e) => '$path/${e.id}';
  String editPath(T e) => '$path/${e.id}/edit';
}
