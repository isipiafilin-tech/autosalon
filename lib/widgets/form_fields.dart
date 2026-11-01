import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/json_read.dart';
import '../state/lookup_notifier.dart';
import '../validation/validators.dart';
import 'connection_widgets.dart';

enum FieldKind {
  text,
  multiline,
  password,
  integer,
  decimal,
  select,
  relation,
  relationMulti,
  date,
  dateTime,
}

/// Описание поля формы: по нему строится виджет, проверка и значение для JSON.
class FieldSpec {
  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final List<Validator> validators;
  final List<(String, String)> options;
  final String? lookup;
  final String? hint;
  final bool createOnly;
  final bool editOnly;

  const FieldSpec(
    this.key,
    this.label,
    this.kind, {
    this.required = false,
    this.validators = const [],
    this.options = const [],
    this.lookup,
    this.hint,
    this.createOnly = false,
    this.editOnly = false,
  });

  bool get isTextual => switch (kind) {
    FieldKind.text ||
    FieldKind.multiline ||
    FieldKind.password ||
    FieldKind.integer ||
    FieldKind.decimal => true,
    _ => false,
  };

  /// Ошибка значения или null. Для текстовых полей значение — строка.
  String? validate(Object? value) {
    if (isTextual) {
      final text = (value ?? '').toString();
      return firstError(text, [
        if (required) _requiredText,
        if (kind == FieldKind.integer) intRange(-2147483648, 2147483647),
        if (kind == FieldKind.decimal) numRange(-1e12, 1e12),
        ...validators,
      ]);
    }
    if (!required) return null;
    final empty =
        value == null ||
        (value is String && value.isEmpty) ||
        (value is List && value.isEmpty);
    if (!empty) return null;
    return kind == FieldKind.relation || kind == FieldKind.select
        ? 'Выберите значение'
        : 'Заполните поле';
  }

  /// Значение в виде, пригодном для JSON запроса.
  Object? toJson(Object? value) {
    switch (kind) {
      case FieldKind.integer:
        final t = '${value ?? ''}'.trim();
        return t.isEmpty ? null : int.tryParse(t);
      case FieldKind.decimal:
        final t = '${value ?? ''}'.trim().replaceAll(',', '.');
        return t.isEmpty ? null : double.tryParse(t);
      case FieldKind.date:
      case FieldKind.dateTime:
        return value is DateTime ? pbDate(value) : '';
      case FieldKind.relationMulti:
        return value is List ? value : const <String>[];
      case FieldKind.select:
      case FieldKind.relation:
        return value ?? '';
      default:
        return (value ?? '').toString().trim();
    }
  }
}

String? _requiredText(String? v) => notEmpty()(v);

/// Значения формы и ошибки, пришедшие с сервера.
class FormController extends ChangeNotifier {
  final Map<String, Object?> values;
  final Map<String, String> serverErrors = {};

  FormController([Map<String, Object?>? initial]) : values = {...?initial};

  void set(String key, Object? value) {
    values[key] = value;
    serverErrors.remove(key);
    notifyListeners();
  }

  void setServerErrors(Map<String, String> errors) {
    serverErrors
      ..clear()
      ..addAll(errors);
    notifyListeners();
  }

  /// Значения полей [fields] в виде JSON запроса.
  Map<String, dynamic> toJson(List<FieldSpec> fields) => {
    for (final f in fields) f.key: f.toJson(values[f.key]),
  };
}

/// Поля формы по списку описаний. Ошибки показываются у своих полей:
/// и найденные на клиенте, и пришедшие с сервера.
class FormFieldsView extends StatefulWidget {
  final FormController controller;
  final List<FieldSpec> fields;

  const FormFieldsView({
    super.key,
    required this.controller,
    required this.fields,
  });

  @override
  State<FormFieldsView> createState() => _FormFieldsViewState();
}

class _FormFieldsViewState extends State<FormFieldsView> {
  final Map<String, TextEditingController> _texts = {};

  FormController get c => widget.controller;

  TextEditingController _textFor(FieldSpec f) {
    return _texts.putIfAbsent(f.key, () {
      final v = c.values[f.key];
      return TextEditingController(text: _initialText(f, v));
    });
  }

  String _initialText(FieldSpec f, Object? v) {
    if (v == null) return '';
    if (f.kind == FieldKind.date && v is DateTime) return formatDate(v);
    if (f.kind == FieldKind.dateTime && v is DateTime) return formatDateTime(v);
    if (v is num && v == v.roundToDouble() && f.kind != FieldKind.decimal) {
      return v.round().toString();
    }
    if (v is double && v == v.roundToDouble()) return v.round().toString();
    return '$v';
  }

  @override
  void initState() {
    super.initState();
    c.addListener(_sync);
  }

  /// Если значение изменили снаружи (пересчёт, подстановка), поле обновляется.
  void _sync() {
    for (final f in widget.fields) {
      final t = _texts[f.key];
      if (t == null) continue;
      final expected = _initialText(f, c.values[f.key]);
      if (f.isTextual) {
        final current = t.text;
        if (c.values[f.key] is! String && current != expected) {
          t.text = expected;
        }
      } else if (t.text != expected) {
        t.text = expected;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    for (final t in _texts.values) {
      t.dispose();
    }
    super.dispose();
  }

  String? _check(FieldSpec f, Object? value) =>
      f.validate(value) ?? c.serverErrors[f.key];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in widget.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _field(context, f),
          ),
      ],
    );
  }

  Widget _field(BuildContext context, FieldSpec f) {
    switch (f.kind) {
      case FieldKind.select:
        return DropdownButtonFormField<String>(
          value: _validOption(f, c.values[f.key] as String?),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
          ),
          items: [
            if (!f.required)
              const DropdownMenuItem(value: '', child: Text('— не выбрано —')),
            for (final (value, label) in f.options)
              DropdownMenuItem(value: value, child: Text(label)),
          ],
          validator: (v) => _check(f, v),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (v) => c.set(f.key, v),
        );
      case FieldKind.relation:
        return _RelationField(
          spec: f,
          value: c.values[f.key] as String?,
          validator: (v) => _check(f, v),
          onChanged: (v) => c.set(f.key, v),
        );
      case FieldKind.relationMulti:
        return _MultiField(
          spec: f,
          value: [for (final x in (c.values[f.key] as List? ?? const [])) '$x'],
          validator: (v) => _check(f, v),
          onChanged: (v) => c.set(f.key, v),
        );
      case FieldKind.date:
      case FieldKind.dateTime:
        return _DateField(
          spec: f,
          controller: _textFor(f),
          value: c.values[f.key] as DateTime?,
          validator: (v) => _check(f, c.values[f.key]),
          onChanged: (v) => c.set(f.key, v),
        );
      default:
        return TextFormField(
          controller: _textFor(f),
          obscureText: f.kind == FieldKind.password,
          minLines: f.kind == FieldKind.multiline ? 3 : 1,
          maxLines: f.kind == FieldKind.multiline ? 5 : 1,
          keyboardType: switch (f.kind) {
            FieldKind.integer => TextInputType.number,
            FieldKind.decimal => const TextInputType.numberWithOptions(
              decimal: true,
            ),
            FieldKind.multiline => TextInputType.multiline,
            _ => TextInputType.text,
          },
          inputFormatters: [
            if (f.kind == FieldKind.integer)
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
            if (f.kind == FieldKind.decimal)
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
          ],
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) => _check(f, v),
          onChanged: (v) => c.set(f.key, v),
        );
    }
  }

  String? _validOption(FieldSpec f, String? v) {
    if (v == null) return f.required ? null : '';
    return f.options.any((o) => o.$1 == v) || v.isEmpty ? v : null;
  }
}

class _RelationField extends StatefulWidget {
  final FieldSpec spec;
  final String? value;
  final String? Function(String?) validator;
  final ValueChanged<String?> onChanged;

  const _RelationField({
    required this.spec,
    required this.value,
    required this.validator,
    required this.onChanged,
  });

  @override
  State<_RelationField> createState() => _RelationFieldState();
}

class _RelationFieldState extends State<_RelationField> {
  late Future<List<LookupItem>> _future = _load();

  Future<List<LookupItem>> _load() =>
      context.read<LookupNotifier>().items(widget.spec.lookup!);

  void _retry() => setState(() {
    context.read<LookupNotifier>().invalidate(widget.spec.lookup);
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    final f = widget.spec;
    return ReconnectListener(
      onReconnect: _retry,
      child: FutureBuilder<List<LookupItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return InputDecorator(
              decoration: InputDecoration(
                labelText: f.label,
                errorText: 'Не удалось загрузить список',
                suffixIcon: IconButton(
                  tooltip: 'Повторить',
                  icon: const Icon(Icons.refresh),
                  onPressed: _retry,
                ),
              ),
              child: const SizedBox(height: 20),
            );
          }
          if (!snap.hasData) {
            return InputDecorator(
              decoration: InputDecoration(labelText: f.label),
              child: const SizedBox(
                height: 20,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            );
          }
          final items = snap.data!;
          final known = items.any((i) => i.id == widget.value);
          return DropdownButtonFormField<String>(
            value: known ? widget.value : (f.required ? null : ''),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: f.label + (f.required ? ' *' : ''),
            ),
            items: [
              if (!f.required)
                const DropdownMenuItem(
                  value: '',
                  child: Text('— не выбрано —'),
                ),
              for (final i in items)
                DropdownMenuItem(
                  value: i.id,
                  child: Text(i.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: widget.validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: widget.onChanged,
          );
        },
      ),
    );
  }
}

class _MultiField extends StatefulWidget {
  final FieldSpec spec;
  final List<String> value;
  final String? Function(List<String>?) validator;
  final ValueChanged<List<String>> onChanged;

  const _MultiField({
    required this.spec,
    required this.value,
    required this.validator,
    required this.onChanged,
  });

  @override
  State<_MultiField> createState() => _MultiFieldState();
}

class _MultiFieldState extends State<_MultiField> {
  late Future<List<LookupItem>> _future = _load();

  Future<List<LookupItem>> _load() =>
      context.read<LookupNotifier>().items(widget.spec.lookup!);

  Future<void> _pick(List<LookupItem> items) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiPickDialog(
        title: widget.spec.label,
        items: items,
        selected: widget.value,
      ),
    );
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.spec;
    return FutureBuilder<List<LookupItem>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const <LookupItem>[];
        final names = {for (final i in items) i.id: i.label};
        return FormField<List<String>>(
          initialValue: widget.value,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
              labelText: f.label + (f.required ? ' *' : ''),
              errorText: state.errorText,
              suffixIcon: snap.hasError
                  ? IconButton(
                      tooltip: 'Повторить',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() {
                        context.read<LookupNotifier>().invalidate(f.lookup);
                        _future = _load();
                      }),
                    )
                  : IconButton(
                      tooltip: 'Выбрать',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: snap.hasData ? () => _pick(items) : null,
                    ),
            ),
            child: widget.value.isEmpty
                ? const Text('Ничего не выбрано')
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final id in widget.value)
                        Chip(
                          label: Text(
                            names[id] ?? '…',
                            overflow: TextOverflow.ellipsis,
                          ),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => widget.onChanged([
                            for (final x in widget.value)
                              if (x != id) x,
                          ]),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _MultiPickDialog extends StatefulWidget {
  final String title;
  final List<LookupItem> items;
  final List<String> selected;

  const _MultiPickDialog({
    required this.title,
    required this.items,
    required this.selected,
  });

  @override
  State<_MultiPickDialog> createState() => _MultiPickDialogState();
}

class _MultiPickDialogState extends State<_MultiPickDialog> {
  late final Set<String> _chosen = {...widget.selected};
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final i in widget.items)
        if (i.label.toLowerCase().contains(_filter.toLowerCase())) i,
    ];
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск',
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final i in shown)
                    CheckboxListTile(
                      dense: true,
                      value: _chosen.contains(i.id),
                      title: Text(i.label),
                      onChanged: (on) => setState(() {
                        on == true ? _chosen.add(i.id) : _chosen.remove(i.id);
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _chosen.toList()),
          child: Text('Выбрать (${_chosen.length})'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final FieldSpec spec;
  final TextEditingController controller;
  final DateTime? value;
  final String? Function(String?) validator;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.spec,
    required this.controller,
    required this.value,
    required this.validator,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) return;
    if (spec.kind == FieldKind.date) {
      onChanged(date);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: spec.label + (spec.required ? ' *' : ''),
        hintText: spec.kind == FieldKind.date
            ? 'дд.мм.гггг'
            : 'дд.мм.гггг чч:мм',
        suffixIcon: value != null && !spec.required
            ? IconButton(
                tooltip: 'Очистить',
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.calendar_today_outlined),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      onTap: () => _pick(context),
    );
  }
}
