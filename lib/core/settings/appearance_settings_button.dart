import 'package:flutter/material.dart';

/// In-app Appearance settings. System follows the device theme.
class AppearanceSettingsButton extends StatelessWidget {
  const AppearanceSettingsButton({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ThemeMode mode;
  final Future<void> Function(ThemeMode mode) onChanged;

  Future<void> _showSettings(BuildContext context) async {
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final color = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Appearance settings',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Choose how Pohantoon AI looks on this device.',
                    style: TextStyle(color: color.onSurfaceVariant)),
                const SizedBox(height: 20),
                for (final item in const [
                  (ThemeMode.system, Icons.settings_suggest_outlined,
                      'System default', 'Follow your device setting'),
                  (ThemeMode.light, Icons.light_mode_outlined,
                      'Light', 'Bright and airy appearance'),
                  (ThemeMode.dark, Icons.dark_mode_outlined,
                      'Dark', 'Comfortable in low light'),
                ])
                  ListTile(
                    key: Key('theme-option-${item.$1.name}'),
                    leading: Icon(item.$2, color: color.primary),
                    title: Text(item.$3),
                    subtitle: Text(item.$4),
                    trailing: mode == item.$1
                        ? Icon(Icons.check_circle, color: color.primary)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, item.$1),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || choice == mode || !context.mounted) return;
    try {
      await onChanged(choice);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Appearance updated on this device. '
              'Account synchronization will retry when connected.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        key: const Key('appearance-settings'),
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => _showSettings(context),
        tooltip: 'Appearance settings',
      );
}
