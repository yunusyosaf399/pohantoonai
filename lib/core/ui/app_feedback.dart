import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'adaptive_layout.dart';

enum NoticeKind { information, warning, error, success }

class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.title,
    required this.message,
    this.kind = NoticeKind.information,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final NoticeKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (kind) {
      NoticeKind.warning => (
          AppColors.warningSoft,
          AppColors.warning,
          Icons.warning_amber_rounded,
        ),
      NoticeKind.error => (
          AppColors.errorSoft,
          AppColors.error,
          Icons.error_outline_rounded,
        ),
      NoticeKind.success => (
          AppColors.primarySoft,
          AppColors.primary,
          Icons.check_circle_outline,
        ),
      NoticeKind.information => (
          AppColors.informationSoft,
          AppColors.information,
          Icons.info_outline_rounded,
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  )),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(
                    color: AppColors.ink,
                    height: 1.45,
                  )),
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message = 'Loading organization data…'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: true,
            label: message,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppSurface(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: AppColors.muted),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (action != null) ...[
                  const SizedBox(height: 18),
                  action!,
                ],
              ],
            ),
          ),
        ),
      );
}

void showAppMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : null,
    ),
  );
}
