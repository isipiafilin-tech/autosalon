import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Классы ширины окна. Раскладка зависит только от них и перестраивается
/// при изменении размера окна без перезагрузки страницы.
enum WindowSize { compact, medium, expanded }

const compactLimit = 600.0;
const expandedFrom = 1100.0;

/// Наибольшая ширина содержимого: на большом мониторе оно не растягивается.
const contentMaxWidth = 1400.0;

WindowSize windowSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < compactLimit) return WindowSize.compact;
  return width < expandedFrom ? WindowSize.medium : WindowSize.expanded;
}

/// Сетка карточек: одна колонка на узком окне, две на среднем,
/// три-четыре на широком. Карточки одного ряда выравниваются по высоте.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveGrid({super.key, required this.children, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    final size = windowSizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (size) {
          WindowSize.compact => 1,
          WindowSize.medium => 2,
          WindowSize.expanded => math.max(
            3,
            math.min(4, constraints.maxWidth ~/ 300),
          ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += columns)
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = 0; j < columns; j++) ...[
                        if (j > 0) SizedBox(width: spacing),
                        Expanded(
                          child: i + j < children.length
                              ? children[i + j]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Диалог не растягивается на всю ширину монитора.
class BoundedDialog extends StatelessWidget {
  final Widget child;

  const BoundedDialog({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  );
}
