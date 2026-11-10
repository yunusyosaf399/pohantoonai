import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Branch by AVAILABLE window width, not by operating system.
abstract final class AppBreakpoints {
  static const double navigationRail = 720;
  static const double extendedRail = 1250;
  static const double compactContent = 620;

  static int dashboardColumns(double width) {
    if (width < 520) return 1;
    if (width < 1000) return 2;
    return 4;
  }

  static int contentColumns(double width) => width < 680 ? 1 : 2;
}

class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    required this.columnsForWidth,
    this.gap = 16,
  });

  final List<Widget> children;
  final int Function(double) columnsForWidth;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = columnsForWidth(constraints.maxWidth).clamp(1, 6);
          final itemWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox(width: itemWidth, child: child),
            ],
          );
        },
      );
}

/// Reusable white content surface with restrained elevation.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x090D293E),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: child,
      );
}

class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < AppBreakpoints.compactContent;
          final description = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      height: 1.5,
                    ),
              ),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                description,
                if (action != null) ...[
                  const SizedBox(height: 18),
                  action!,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: description),
              if (action != null) ...[
                const SizedBox(width: 18),
                action!,
              ],
            ],
          );
        },
      );
}
