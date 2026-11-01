import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';
import 'adaptive.dart';

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String text,
  String action = 'Удалить',
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => BoundedDialog(
      child: AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final scheme = Theme.of(context).colorScheme;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        text,
        style: error ? TextStyle(color: scheme.onErrorContainer) : null,
      ),
      backgroundColor: error ? scheme.errorContainer : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showError(BuildContext context, Object error) => showMessage(
  context,
  error is ApiException ? error.message : 'Не удалось выполнить операцию.',
  error: true,
);

/// Цветная метка состояния.
class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusChip(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: base.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: base,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
