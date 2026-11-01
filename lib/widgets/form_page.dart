import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exceptions.dart';
import 'dialogs.dart';
import 'form_fields.dart';

/// Ограничение ширины формы на широком экране.
const formMaxWidth = 640.0;

/// Страница формы: поля, кнопки, сохранение и показ ошибок.
/// Ошибки проверки (400 с описанием полей, 422) и конфликты (409)
/// выводятся у соответствующих полей, остальные — сообщением.
class FormPage extends StatefulWidget {
  final FormController controller;
  final List<FieldSpec> fields;

  /// Отправка данных; ошибки сервера бросаются как [ApiException].
  final Future<void> Function(Map<String, dynamic> json) onSave;

  /// Проверка на клиенте перед отправкой (имя поля → ошибка).
  final Map<String, String> Function()? localErrors;
  final String saveLabel;
  final String savedMessage;
  final Widget? before;
  final Widget? after;

  const FormPage({
    super.key,
    required this.controller,
    required this.fields,
    required this.onSave,
    required this.saveLabel,
    required this.savedMessage,
    this.localErrors,
    this.before,
    this.after,
  });

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  void _showFieldErrors(String message, Map<String, String> fields) {
    final known = {for (final f in widget.fields) f.key};
    widget.controller.setServerErrors({
      for (final e in fields.entries)
        if (known.contains(e.key)) e.key: e.value,
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formKey.currentState?.validate();
    });
    final rest = fields.entries
        .where((e) => !known.contains(e.key))
        .map((e) => e.value)
        .toList();
    showMessage(
      context,
      rest.isEmpty ? message : '$message ${rest.join('; ')}',
      error: true,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    widget.controller.setServerErrors({});
    final local = widget.localErrors?.call() ?? const {};
    if (local.isNotEmpty) {
      _showFieldErrors('Проверьте выделенные поля.', local);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(widget.controller.toJson(widget.fields));
      if (!mounted) return;
      showMessage(context, widget.savedMessage);
      context.pop();
    } on ValidationException catch (e) {
      _showFieldErrors(e.message, e.fields);
    } on ConflictException catch (e) {
      _showFieldErrors(e.message, e.fields);
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.before != null) widget.before!,
                  FormFieldsView(
                    controller: widget.controller,
                    fields: widget.fields,
                  ),
                  if (widget.after != null) widget.after!,
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(widget.saveLabel),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Отмена'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
