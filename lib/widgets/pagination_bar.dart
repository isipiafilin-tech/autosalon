import 'package:flutter/material.dart';

import '../core/config.dart';
import '../models/list_query.dart';
import 'adaptive.dart';

/// Переход по страницам и выбор размера страницы.
class PaginationBar extends StatelessWidget {
  final PageResult<Object?> page;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  const PaginationBar({
    super.key,
    required this.page,
    required this.onPage,
    required this.onSize,
  });

  @override
  Widget build(BuildContext context) {
    final compact = windowSizeOf(context) == WindowSize.compact;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          alignment: compact
              ? WrapAlignment.center
              : WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            if (!compact) Text('Всего записей: ${page.total}'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Первая страница',
                  icon: const Icon(Icons.first_page),
                  onPressed: page.hasPrevious ? () => onPage(1) : null,
                ),
                IconButton(
                  tooltip: 'Предыдущая страница',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: page.hasPrevious
                      ? () => onPage(page.page - 1)
                      : null,
                ),
                Text(
                  compact
                      ? '${page.page} из ${page.totalPages}'
                      : 'Страница ${page.page} из ${page.totalPages}',
                ),
                IconButton(
                  tooltip: 'Следующая страница',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: page.hasNext ? () => onPage(page.page + 1) : null,
                ),
                IconButton(
                  tooltip: 'Последняя страница',
                  icon: const Icon(Icons.last_page),
                  onPressed: page.hasNext
                      ? () => onPage(page.totalPages)
                      : null,
                ),
              ],
            ),
            if (!compact)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('На странице: '),
                  DropdownButton<int>(
                    value: pageSizes.contains(page.size)
                        ? page.size
                        : defaultPageSize,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final size in pageSizes)
                        DropdownMenuItem(value: size, child: Text('$size')),
                    ],
                    onChanged: (size) {
                      if (size != null) onSize(size);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
