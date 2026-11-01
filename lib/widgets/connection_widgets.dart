import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/connection_notifier.dart';

/// Полоса над приложением на время потери связи с сервером.
class ConnectionBanner extends StatelessWidget {
  final Widget child;

  const ConnectionBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectionNotifier>().online;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (!online)
          Semantics(
            liveRegion: true,
            child: Material(
              color: scheme.errorContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: scheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Нет соединения с сервером. Данные загрузятся сами, '
                          'как только связь восстановится.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

/// Вызывает [onReconnect], когда связь с сервером восстановилась.
class ReconnectListener extends StatefulWidget {
  final VoidCallback onReconnect;
  final Widget child;

  const ReconnectListener({
    super.key,
    required this.onReconnect,
    required this.child,
  });

  @override
  State<ReconnectListener> createState() => _ReconnectListenerState();
}

class _ReconnectListenerState extends State<ReconnectListener> {
  late final ConnectionNotifier _connection = context
      .read<ConnectionNotifier>();
  late bool _online = _connection.online;

  @override
  void initState() {
    super.initState();
    _connection.addListener(_changed);
  }

  void _changed() {
    if (!_online && _connection.online) widget.onReconnect();
    _online = _connection.online;
  }

  @override
  void dispose() {
    _connection.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Сообщение об ошибке загрузки с кнопкой повтора.
class RetryMessage extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const RetryMessage({super.key, required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: scheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
