import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/entities.dart';
import '../models/enums.dart';
import '../models/permissions.dart';
import '../repositories/repos.dart';
import '../state/auth_notifier.dart';
import '../widgets/dialogs.dart';

/// Действия на карточке автомобиля. Набор зависит от роли: клиент
/// оставляет заявку и записывается на тест-драйв, сотрудник оформляет
/// сделку и тест-драйв за клиента.
class CarActions extends StatelessWidget {
  final Car car;
  final VoidCallback reload;

  const CarActions({super.key, required this.car, required this.reload});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final free = car.status == CarStatus.available;
    final isClient = auth.can(Permission.clientCabinet);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (isClient && free)
            FilledButton.icon(
              onPressed: () => context.push('/my/deals/new?car=${car.id}'),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Оставить заявку'),
            ),
          if (isClient && free)
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/my/test-drives/new?car=${car.id}'),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Записаться на тест-драйв'),
            ),
          if (auth.can(Permission.manageDeals) && free)
            FilledButton.icon(
              onPressed: () => context.push('/deals/new?car=${car.id}'),
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Оформить сделку'),
            ),
          if (auth.can(Permission.manageTestDrives) && free)
            OutlinedButton.icon(
              onPressed: () => context.push('/test-drives/new?car=${car.id}'),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Запланировать тест-драйв'),
            ),
        ],
      ),
    );
  }
}

/// Переходы статуса сделки. Допустимость проверяет и сервер (ответ 409).
class DealActions extends StatefulWidget {
  final Deal deal;
  final VoidCallback reload;

  const DealActions({super.key, required this.deal, required this.reload});

  @override
  State<DealActions> createState() => _DealActionsState();
}

class _DealActionsState extends State<DealActions> {
  bool _busy = false;

  Future<void> _set(DealStatus status) async {
    setState(() => _busy = true);
    try {
      await context.read<Repos>().deals.update(widget.deal.id, {
        'status': status.value,
      });
      if (!mounted) return;
      showMessage(context, 'Статус изменён: ${status.label}');
      widget.reload();
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.can(Permission.manageDeals)) return const SizedBox.shrink();
    final d = widget.deal;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (d.status == DealStatus.newDeal)
            FilledButton.icon(
              onPressed: _busy ? null : () => _set(DealStatus.approved),
              icon: const Icon(Icons.check),
              label: const Text('Одобрить'),
            ),
          if (d.status == DealStatus.approved)
            FilledButton.icon(
              onPressed: () => context.push('/contracts/new?deal=${d.id}'),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Оформить договор'),
            ),
          if (d.status == DealStatus.newDeal || d.status == DealStatus.approved)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _set(DealStatus.cancelled),
              icon: const Icon(Icons.close),
              label: const Text('Отменить сделку'),
            ),
        ],
      ),
    );
  }
}

/// Отметка о проведении или отмена тест-драйва.
class DriveActions extends StatefulWidget {
  final TestDrive drive;
  final VoidCallback reload;

  const DriveActions({super.key, required this.drive, required this.reload});

  @override
  State<DriveActions> createState() => _DriveActionsState();
}

class _DriveActionsState extends State<DriveActions> {
  bool _busy = false;

  Future<void> _set(DriveStatus status) async {
    setState(() => _busy = true);
    try {
      await context.read<Repos>().testDrives.update(widget.drive.id, {
        'status': status.value,
      });
      if (!mounted) return;
      showMessage(context, 'Статус изменён: ${status.label}');
      widget.reload();
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final d = widget.drive;
    if (d.status != DriveStatus.planned) return const SizedBox.shrink();
    final staff = auth.can(Permission.manageTestDrives);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (staff)
            FilledButton.icon(
              onPressed: _busy ? null : () => _set(DriveStatus.done),
              icon: const Icon(Icons.check),
              label: const Text('Тест-драйв проведён'),
            ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _set(DriveStatus.cancelled),
            icon: const Icon(Icons.close),
            label: const Text('Отменить'),
          ),
        ],
      ),
    );
  }
}
